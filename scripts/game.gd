## Lógica pura del juego: estado, reglas y datos. No toca la interfaz,
## así que la usan igual la escena principal y el simulador de equilibrio.
extends RefCounted

signal changed
signal log_message(text: String)
signal event_triggered(event: Dictionary)
signal game_over(ending: Dictionary)

const STATS := ["salud", "felicidad", "tristeza", "hambre", "higiene", "lujuria"]
const STAT_NAMES := {
	"salud": "Salud", "felicidad": "Felicidad", "tristeza": "Tristeza", "hambre": "Hambre",
	"higiene": "Higiene", "lujuria": "Lujuria",
}
## Estadísticas donde subir es bueno; en el resto, bajar es bueno.
const GOOD_UP := ["salud", "felicidad", "higiene"]
## Estadísticas que se saturan: pasarse del tope repitiendo una acción trae consecuencias.
const SATURABLE := ["felicidad", "hambre", "higiene"]

var character: Dictionary
var balance: Dictionary
var items: Dictionary = {}          # id -> item
var item_order: Array = []
var events: Array = []

var stats: Dictionary = {}
var day := 1
var actions_left := 0
var money := 0
var total_money := 0
var inventory: Dictionary = {}      # id -> cantidad
var absent := false               # se escapó mientras trabajabas (Leapy); vuelve de noche
var stash: Dictionary = {}          # lo que ella escondió del inventario (id -> cantidad)
var passives: Array = []            # ids de objetos pasivos comprados
var minigames: Array = []           # ids de minijuegos desbloqueados
var known_affinity: Dictionary = {} # minijuegos ya probados
var events_seen: Dictionary = {}
var times_today: Dictionary = {}
var pending_event: Dictionary = {}
var over := false
var current_line := ""
var rng := RandomNumberGenerator.new()
var quiet := false                  # el simulador lo activa para no generar textos
# La maldición
var tolerance: Dictionary = {}      # remedio -> tolerancia acumulada (se recupera cada noche)
var curse_mark := 0.0               # mínimo permanente de lujuria que dejan las crisis
var marked := false                 # esta crisis ya dejó su marca
# Reacciones de especie (sinergias y trampas)
var today: Array = []               # actividades de hoy, en orden
var discovered: Dictionary = {}     # reacciones ya descubiertas (diario)
# Vestuario (puramente estético)
var outfit := ""
var outfits: Array = []
# Vínculo: lo único que puede salvarla cuando la maldición llegue al máximo.
var bond := 0.0
var talked_today := false           # la charla que cuenta es una al día
var pokes_today := 0                # toques de hoy después de la charla
var warned := false                 # ya amenazó con denunciarte
# Plazo de la asignación y evaluación final de H.A.R.E.M.
var term := 0                       # días de convivencia (0 = sin plazo)
var crises := 0                     # crisis que dejaron marca
var project: Dictionary = {}        # data/proyecto.json
var overflow: Dictionary = {}       # lo que la última acción quiso dar de más


## Estado que se guarda en la partida (todo lo demás sale de los JSON de datos).
const SAVE_FIELDS := ["stats", "day", "actions_left", "money", "total_money", "inventory",
	"passives", "minigames", "known_affinity", "events_seen", "times_today", "pending_event",
	"tolerance", "curse_mark", "marked", "today", "discovered", "outfit", "outfits", "bond",
	"current_line", "talked_today", "pokes_today", "warned", "term", "crises", "stash", "absent"]
const INT_FIELDS := ["day", "actions_left", "money", "total_money", "term", "crises"]
const SAVE_VERSION := 1
const SAVE_PATH := "user://partida.json"


func to_dict() -> Dictionary:
	var d := {"version": SAVE_VERSION, "personaje": character["id"], "rng": str(rng.state)}
	for f in SAVE_FIELDS:
		d[f] = get(f)
	return d


## Restaura una partida guardada. Devuelve false si no es compatible.
func from_dict(d: Dictionary) -> bool:
	if int(d.get("version", 0)) != SAVE_VERSION or d.get("personaje", "") != character["id"]:
		return false
	for f in SAVE_FIELDS:
		if not d.has(f):
			continue
		set(f, int(d[f]) if f in INT_FIELDS else d[f])
	for s in STATS:
		stats[s] = float(stats.get(s, character["stats_iniciales"].get(s, 50)))
	rng.state = int(d.get("rng", "0"))
	if not d.has("term"):
		term = int(assignment().get("dias", 0))   # partidas de antes del plazo
	_log("[b]— Día %d —[/b]" % day)
	changed.emit()
	return true


static func load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("No se pudo abrir " + path)
		return null
	return JSON.parse_string(f.get_as_text())


func setup(character_path: String, seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	character = load_json(character_path)
	balance = load_json("res://data/balance.json")
	project = load_json("res://data/proyecto.json")
	for ev in load_json("res://data/eventos.json"):
		if ev.get("personaje", character["id"]) == character["id"]:
			events.append(ev)
	for it in load_json("res://data/items.json"):
		if it.has("especie") and it["especie"] != character["id"]:
			continue
		items[it["id"]] = it
		item_order.append(it["id"])


## Empieza la asignación. `extra_money` son los fondos que gana una buena nota anterior.
func start(extra_money := 0) -> void:
	for s in STATS:
		stats[s] = float(character["stats_iniciales"].get(s, 50))
	money = int(balance["dinero_inicial"]) + extra_money
	term = int(assignment().get("dias", 0))
	actions_left = int(balance["acciones_por_dia"])
	minigames = [character["minijuego_inicial"]]
	outfit = character.get("traje_inicial", "")
	outfits = [outfit]
	bond = float(balance["vinculo"].get("inicial", 0))
	_say("inicio")
	_log("[b]— Día 1 —[/b]")
	changed.emit()


# ---------------------------------------------------------------- consultas

func level() -> int:
	var lv := 0
	var niveles: Array = balance["niveles"]
	for i in niveles.size():
		if stats["lujuria"] >= float(niveles[i]["min"]):
			lv = i
	return lv


func level_info() -> Dictionary:
	return balance["niveles"][level()]


func effectiveness() -> float:
	return float(level_info()["efectividad"])


func mood() -> String:
	var lv := level()
	if lv >= 3: return "critica"
	if lv == 2: return "alterada"
	if stats["tristeza"] > 60: return "triste"
	if actions_left == 0 and not over: return "cansada"   # al final del día
	if lv == 1: return "inquieta"
	# Sin maldición a la vista, la cara depende de cómo te trata.
	var att := attitude_index()
	if att <= 1: return "triste"
	if att >= 4 or (att == 3 and stats["felicidad"] > 65): return "feliz"
	return "neutral"


## Actitud actual según el vínculo: de Hostil (peor) a Unida (mejor).
func attitude_index() -> int:
	var list: Array = balance["vinculo"]["actitudes"]
	var out := 0
	for i in list.size():
		if bond >= float(list[i]["min"]):
			out = i
	return out


func attitude() -> Dictionary:
	return balance["vinculo"]["actitudes"][attitude_index()]


## Tramo de la maldición para elegir qué dice: calma, alterada o crítica.
func lust_band() -> String:
	var lv := level()
	return "critica" if lv >= 3 else ("alterada" if lv == 2 else "calma")


## Frase al tocarla, según su actitud y su lujuria.
func touch_line() -> String:
	return _pick(character["charla"]["toque"][attitude()["id"]][lust_band()])


## Tocarla de más: cuánto aguanta depende de su actitud y de la maldición.
func poke() -> void:
	if over or absent or not pending_event.is_empty():
		return
	pokes_today += 1
	var att := attitude()
	var band := lust_band()
	var patience := int(att["paciencia"])
	if band == "alterada":
		patience = mini(patience, 2)
	elif band == "critica":
		patience = mini(patience, 1)
	if pokes_today <= patience:
		current_line = touch_line()
		changed.emit()
		return
	var m: Dictionary = balance["vinculo"]["molestia"]
	# Con poco vínculo se enfada enseguida; con mucho, solo si insistes el doble.
	if attitude_index() <= 2:
		_bond(float(m["vinculo_bajo"]), true)
	elif pokes_today > patience * 2:
		_bond(float(m["vinculo_alto"]), true)
	if band != "calma":
		apply({"lujuria": m["lujuria_" + band]})
	current_line = _pick(character["charla"]["molesta"][talk_key()])
	if bond <= float(m["denuncia"]):
		_end("denuncia")
		return
	if bond <= float(m["aviso"]) and not warned:
		warned = true
		current_line = character["charla"]["aviso"]
	elif bond > float(m["aviso"]):
		warned = false
	_check_consumed()
	changed.emit()


func can_talk() -> bool:
	return not over and pending_event.is_empty() and not talked_today and not absent


## Con la maldición alta manda el estado; si no, manda la actitud.
func talk_key() -> String:
	var band := lust_band()
	return attitude()["id"] if band == "calma" else band


## Responde en la charla del día. Devuelve lo que contesta ella.
func talk(reply: String) -> String:
	if not can_talk():
		return ""
	talked_today = true
	var key := talk_key()
	var quality: String = character["charla"]["ajuste"][key][reply]
	var fx: Dictionary = balance["vinculo"]["charla"][quality]
	_bond(float(fx["vinculo"]))
	apply({"lujuria": fx["lujuria"]})
	if quality == "buena" and not discovered.has("charla_" + key):
		discovered["charla_" + key] = true
		_log("[color=#f2c14e]Nueva nota en el diario.[/color]")
	var line := _pick(character["charla"]["respuestas"][key][quality])
	current_line = line
	_check_consumed()
	changed.emit()
	return line


func activity(id: String) -> Dictionary:
	return balance["actividades"][id]


func can_do(id: String) -> bool:
	if over or not pending_event.is_empty():
		return false
	var act := activity(id)
	if int(act["costo"]) > actions_left:
		return false
	if money < int(act.get("precio", 0)):
		return false
	if absent and id != "trabajar":
		return false
	return true


func why_not(id: String) -> String:
	var act := activity(id)
	if int(act["costo"]) > actions_left: return "No te quedan acciones hoy."
	if money < int(act.get("precio", 0)): return "No tienes dinero suficiente."
	if absent and id != "trabajar": return "No está."
	return ""


func passive_sum(key: String) -> float:
	var total := 0.0
	for id in passives:
		total += float(items[id].get("pasivo", {}).get(key, 0))
	return total


func minigame_affinity(id: String) -> float:
	return float(character["minijuegos"].get(id, 1.0))


# ---------------------------------------------------------------- acciones

func do_activity(id: String) -> void:
	if not can_do(id):
		return
	var act := activity(id)
	actions_left -= int(act["costo"])
	money -= int(act.get("precio", 0))
	var earned := int(act.get("dinero", 0) * (0.8 if level() >= 2 else 1.0))
	money += earned
	total_money += earned
	var reactions := _match_reactions(id)
	overflow.clear()
	var mult := _mult_for(id) * float(character["afinidades"].get(id, 1.0))
	apply(act["efectos"], mult, _tolerance_use(id))
	apply(character["efectos_extra"].get(id, {}))
	# Celos (Vipi): cuanto más te quiere, más le duele que te vayas.
	var jealous: Dictionary = character.get("celos", {})
	if jealous.get("accion", "") == id and bond > 0:
		_add("tristeza", bond * float(jealous["tristeza_por_vinculo"]))
	_count(id)
	_say(id)
	today.append(id)
	if id == "trabajar":
		_maybe_run_away()
	_apply_reactions(reactions)
	_outfit_effects(id)
	_saturate(id)
	_after_action(id, float(act.get("prob_evento", 0)))


func can_play() -> bool:
	return can_do("jugar")


func play_minigame(id: String, score: float) -> void:
	if not can_play():
		return
	score = clampf(score, 0.0, 1.0)
	var act := activity("jugar")
	actions_left -= int(act["costo"])
	var mg: Dictionary = balance["minijuegos"][id]
	var eff := {}
	for k in mg["efectos_base"]:
		eff[k] = float(mg["efectos_base"][k])
	for k in mg["efectos_bonus"]:
		eff[k] = eff.get(k, 0.0) + float(mg["efectos_bonus"][k]) * score
	var reactions := _match_reactions("jugar")
	overflow.clear()
	var mult := _mult_for("jugar") * minigame_affinity(id)
	apply(eff, mult, _tolerance_use("mj_" + id))
	apply(act["efectos"])
	known_affinity[id] = true
	_count("jugar")
	_say("jugar")
	if score >= float(balance["vinculo"]["minijuego_min"]):
		_bond(float(balance["vinculo"]["minijuego"]))
	today.append("jugar")
	_apply_reactions(reactions)
	_outfit_effects("jugar")
	_saturate("jugar")
	_after_action("jugar", float(act.get("prob_evento", 0)))


func buy(id: String) -> bool:
	var it: Dictionary = items[id]
	if over or money < int(it["precio"]) or not can_buy(id):
		return false
	money -= int(it["precio"])
	match it["tipo"]:
		"consumible":
			inventory[id] = inventory.get(id, 0) + 1
		"pasivo":
			passives.append(id)
		"minijuego":
			minigames.append(it["minijuego"])
		"traje":
			outfits.append(it["traje"])
	changed.emit()
	return true


## Descripción del objeto; cada asignada puede tener la suya.
func item_text(id: String) -> String:
	return character.get("objetos", {}).get(id, items[id]["descripcion"])


func can_buy(id: String) -> bool:
	var it: Dictionary = items[id]
	match it["tipo"]:
		"pasivo":
			return not passives.has(id)
		"minijuego":
			return not minigames.has(it["minijuego"])
		"traje":
			return not outfits.has(it["traje"])
	return true


## Cambia de ropa. No afecta a ninguna estadística: es una trampa para el dinero.
## Efectos del traje puesto sobre una actividad (sin tolerancia: la ropa no se gasta).
func outfit_effects(t: String) -> Dictionary:
	return character.get("trajes_efectos", {}).get(t, {})


func _outfit_effects(id: String) -> void:
	var e: Dictionary = outfit_effects(outfit).get(id, {})
	if e.is_empty():
		return
	apply(e, effectiveness())


func wear(t: String) -> void:
	if over or not outfits.has(t) or t == outfit:
		return
	outfit = t
	_say("vestir")
	changed.emit()


func use_item(id: String) -> void:
	if over or absent or inventory.get(id, 0) <= 0 or not pending_event.is_empty():
		return
	inventory[id] -= 1
	if inventory[id] <= 0:
		inventory.erase(id)
	var it: Dictionary = items[id]
	var mult := 1.3 if character["id"] in it.get("favorito", []) else 1.0
	overflow.clear()
	# Usar el mismo objeto varias veces el mismo día rinde cada vez menos.
	apply(it["efectos"], mult * _mult_for("objeto_" + id), _tolerance_use("objeto_" + id))
	_count("objeto_" + id)
	_log("Usas: %s." % it["nombre"])
	_saturate("objeto_" + id)
	_check_consumed()
	changed.emit()


func sleep() -> void:
	if over or not pending_event.is_empty():
		return
	var d: Dictionary = balance["dia"].duplicate()
	d.merge(character.get("dia", {}), true)
	_say("dormir")
	_add("hambre", float(d["hambre_diaria"]))
	_add("higiene", -(float(d["higiene_diaria"]) + passive_sum("higiene_diaria")))
	_add("felicidad", -float(d["felicidad_diaria"]))
	_add("tristeza", passive_sum("tristeza_diaria"))
	# Interacciones entre estadísticas.
	if stats["hambre"] >= float(d["hambre_danina"]):
		_add("salud", -float(d["dano_hambre"]))
	if stats["higiene"] <= float(d["higiene_danina"]):
		_add("salud", -float(d["dano_higiene"]))
		_add("felicidad", -3)
	if stats["hambre"] < 50 and stats["higiene"] > 50:
		_add("salud", float(d["recuperacion_salud"]))
	if stats["felicidad"] <= float(d["felicidad_triste"]):
		_add("tristeza", float(d["tristeza_sube"]))
	elif stats["felicidad"] >= float(d["felicidad_alegre"]):
		_add("tristeza", -float(d["tristeza_baja"]))
	var full_moon := is_full_moon()
	var lust := lust_delta()
	_add("lujuria", lust)
	_night_bond()
	var decay := float(balance["maldicion"]["tolerancia_decay"])
	var combo_decay := float(balance["maldicion"].get("tolerancia_decay_combos", decay))
	for k in tolerance:
		# Los combos se recuperan más lento: repetir siempre el mismo rinde cada vez menos.
		tolerance[k] *= combo_decay if k.begins_with("reaccion_") else decay
	day += 1
	actions_left = int(balance["acciones_por_dia"])
	times_today.clear()
	today.clear()
	talked_today = false
	pokes_today = 0
	_log("[b]— Día %d —[/b]" % day)
	if full_moon:
		_log("[color=#ef7d86]Luna llena.[/color]")
	if _check_consumed():
		return
	if term > 0 and day > term:
		_evaluate()
		return
	_come_back()
	if not quiet:
		current_line = touch_line()
	_hide_item()
	_try_event("noche", float(d["prob_evento_noche"]))
	changed.emit()


func lust_delta() -> float:
	var l: Dictionary = character["lujuria"]
	var b := {}
	b["naturaleza"] = float(l["base"])
	b["tristeza"] = stats["tristeza"] * float(l["por_tristeza"])
	b["hambre"] = maxf(0, stats["hambre"] - 50) * float(l["por_hambre"])
	b["suciedad"] = maxf(0, 50 - stats["higiene"]) * float(l["por_suciedad"])
	b["felicidad"] = -maxf(0, stats["felicidad"] - 50) * float(l["por_felicidad"])
	b["salud"] = -maxf(0, stats["salud"] - 60) * float(l["por_salud"])
	b["días"] = minf(day * float(l["por_dia"]), float(l["max_por_dia"]))
	b["objetos"] = passive_sum("lujuria_diaria")
	var m: Dictionary = balance["maldicion"]
	b["maldición"] = maxf(0, stats["lujuria"] - float(m["umbral"])) * float(m["autoalimentacion"])
	if is_full_moon():
		b["luna llena"] = float(m["luna_base"]) + day * float(m["luna_por_dia"])
	b["azar"] = rng.randf_range(-float(l["ruido"]), float(l["ruido"]))
	var total := 0.0
	for k in b:
		total += b[k]
	return total


# ---------------------------------------------------------------- reacciones

## Reacciones de la especie que provoca esta actividad. Se evalúan antes de
## aplicar sus efectos (por ejemplo, "comer sin hambre" mira el hambre de antes).
func _match_reactions(id: String) -> Array:
	var seq: Array = today + [id]
	var out := []
	for r in character.get("reacciones", []):
		if r["accion"] != id:
			continue
		if r.has("cadena"):
			var c: Array = r["cadena"]
			if seq.size() < c.size() or seq.slice(seq.size() - c.size()) != c:
				continue
		if r.has("no_despues_de") and not today.is_empty() and today[-1] == r["no_despues_de"]:
			continue
		if not _conditions_ok(r.get("condiciones", {})):
			continue
		out.append(r)
	return out


func _apply_reactions(list: Array) -> void:
	var curse: Dictionary = balance["maldicion"]
	for r in list:
		var good: bool = float(r["efectos"].get("lujuria", 0)) < 0
		var key: String = "reaccion_" + r["id"]
		var fresh := tolerance_factor(key)
		var vb: Dictionary = balance["vinculo"]
		# Repetir el mismo combo todos los días termina aburriéndola: ya no calma ni acerca.
		if good and fresh < float(curse.get("rutina_aburre", 0.0)):
			_tolerance_use(key)
			apply(curse.get("rutina_efectos", {}))
			var bored: Array = character.get("rutina", ["%s ya se sabe esta rutina de memoria." % character["nombre"]])
			_log("[color=#c9a0dc]%s[/color]" % _pick(bored))
			continue
		apply(r["efectos"], effectiveness() if good else 1.0, _tolerance_use(key) if good else 1.0)
		var first := not discovered.has(r["id"])
		discovered[r["id"]] = true
		var color := "#9fd8ff" if good else "#f2a65a"
		var note := "  [color=#f2c14e]Nueva nota en el diario.[/color]" if first else ""
		_log("[color=%s]%s[/color]%s" % [color, r["texto"], note])
		var gain := float(r.get("vinculo", vb["reaccion_buena"] if good else vb["reaccion_trampa"]))
		_bond(gain * fresh if good else gain)


# ---------------------------------------------------------------- eventos

func option_available(opt: Dictionary) -> bool:
	if opt.has("requiere") and not has_item(opt["requiere"]):
		return false
	return money + int(opt.get("efectos", {}).get("dinero", 0)) >= 0


## ¿Tiene este objeto, en el inventario o ya instalado en casa?
func has_item(id: String) -> bool:
	return inventory.get(id, 0) > 0 or passives.has(id)


func resolve_event(index: int) -> void:
	if pending_event.is_empty():
		return
	var ev := pending_event
	pending_event = {}
	var opt: Dictionary = ev["opciones"][index]
	if opt.has("final"):
		_end(opt["final"])
		return
	var req: String = opt.get("requiere", "")
	if inventory.get(req, 0) > 0:
		inventory[req] -= 1
		if inventory[req] <= 0:
			inventory.erase(req)
	var eff: Dictionary = opt.get("efectos", {}).duplicate()
	# Algunas especies viven los eventos con más intensidad: lo que altera, altera más.
	if float(eff.get("lujuria", 0)) > 0:
		eff["lujuria"] = float(eff["lujuria"]) * float(character.get("eventos", {}).get("lujuria_mult", 1.0))
	match opt.get("escondite", ""):
		"devolver": _return_stash()
		"perder": stash.clear()
	apply(eff, effectiveness())
	if eff.has("vinculo"):
		_bond(float(eff["vinculo"]))
	if opt.get("resultado", "") != "":
		_log(opt["resultado"])
	_check_consumed()
	changed.emit()


## Pasiva de algunas chicas (Leapy): si el apego es poco, a veces aprovecha que sales a
## trabajar para escaparse. La casa queda vacía hasta la noche. No hay aviso.
func _maybe_run_away() -> void:
	var cfg: Dictionary = character.get("fuga", {})
	if cfg.is_empty() or absent or over or bond >= float(cfg["vinculo_max"]):
		return
	var p := float(cfg["prob"])
	if stats["tristeza"] >= float(cfg.get("tristeza_min", 101)) or stats["felicidad"] <= float(cfg.get("felicidad_max", -1)):
		p += float(cfg.get("prob_extra", 0))
	if rng.randf() >= p:
		return
	absent = true
	current_line = ""
	if not quiet:
		_log("[color=#9aa3b5]%s[/color]" % _pick(cfg.get("ausente", [])))


## Vuelve cuando ya es de noche, con lo que haya hecho afuera encima.
func _come_back() -> void:
	if not absent:
		return
	absent = false
	var cfg: Dictionary = character["fuga"]
	apply(cfg.get("regreso_efectos", {}))
	_log("[color=#9aa3b5]%s[/color]" % _pick(cfg.get("regreso", [])))


## Pasiva de algunas chicas (Mandy): de noche esconde en silencio algo del inventario.
## Lo hace más cuando está triste y menos cuando confía en ti.
func _hide_item() -> void:
	var cfg: Dictionary = character.get("esconde", {})
	if cfg.is_empty() or inventory.is_empty():
		return
	var p := float(cfg["prob"])
	if stats["tristeza"] >= float(cfg.get("tristeza_min", 101)):
		p += float(cfg.get("prob_triste", 0))
	p *= 1.0 - clampf(bond, 0, 100) / 100.0 * float(cfg.get("freno_vinculo", 0))
	if rng.randf() >= p:
		return
	var ids := inventory.keys()
	ids.sort()
	var id: String = ids[rng.randi() % ids.size()]
	inventory[id] -= 1
	if inventory[id] <= 0:
		inventory.erase(id)
	stash[id] = stash.get(id, 0) + 1


func stash_count() -> int:
	var n := 0
	for id in stash:
		n += int(stash[id])
	return n


func _return_stash() -> void:
	if stash.is_empty():
		return
	var names := []
	for id in stash:
		inventory[id] = inventory.get(id, 0) + int(stash[id])
		names.append(items[id]["nombre"] + (" ×%d" % stash[id] if stash[id] > 1 else ""))
	stash.clear()
	_log("Recuperas: %s." % ", ".join(names))


func _try_event(moment: String, prob: float) -> void:
	prob *= float(character.get("eventos", {}).get("prob_mult", 1.0))
	if over or rng.randf() >= prob:
		return
	var pool := []
	var total := 0.0
	for ev in events:
		if moment in ev["momento"] and _conditions_ok(ev.get("condiciones", {})):
			pool.append(ev)
			total += float(ev.get("peso", 1))
	if pool.is_empty():
		return
	var r := rng.randf() * total
	for ev in pool:
		r -= float(ev.get("peso", 1))
		if r <= 0:
			pending_event = ev
			events_seen[ev["id"]] = true
			event_triggered.emit(ev)
			return


func _conditions_ok(cond: Dictionary) -> bool:
	for key in cond:
		var v := float(cond[key])
		var cut: int = key.rfind("_")
		var what: String = key.substr(0, cut)
		var op: String = key.substr(cut + 1)
		var cur: float
		match what:
			"dia": cur = day
			"nivel": cur = level()
			"dinero": cur = money
			"escondidos": cur = stash_count()
			_: cur = stats.get(what, 0.0)
		if op == "min" and cur < v: return false
		if op == "max" and cur > v: return false
	return true


# ---------------------------------------------------------------- utilidades

## Aplica efectos. `mult` solo escala los efectos beneficiosos, así un estado
## alterado o una actividad repetida rinden menos sin suavizar lo negativo.
func apply(effects: Dictionary, mult: float = 1.0, lust_mult: float = 1.0) -> Dictionary:
	var real := {}
	for k in effects:
		var v := float(effects[k])
		if k == "dinero":
			money += int(v)
			if v > 0:
				total_money += int(v)
			continue
		if not stats.has(k):
			continue
		var beneficial: bool = (v > 0) == (k in GOOD_UP)
		if beneficial:
			v *= mult
			if k == "lujuria":
				v *= lust_mult
		var before: float = stats[k]
		stats[k] = clampf(before + v, _floor(k), 100)
		real[k] = stats[k] - before
		# Solo cuenta si ya estaba al tope: es repetir lo mismo cuando ya no hace falta.
		var full: float = before if k in GOOD_UP else 100.0 - before
		if beneficial and k in SATURABLE and full >= float(balance["saturacion"]["desde"]):
			overflow[k] = overflow.get(k, 0.0) + absf(v) - absf(real[k])
	return real


## Pasarse del tope (comer sin hambre, más diversión de la que cabe, bañarla limpia)
## se vuelve en contra: lo que sobra se convierte en efectos negativos.
func _saturate(source: String) -> void:
	var cfg: Dictionary = balance["saturacion"]
	var excess := overflow.duplicate()
	overflow.clear()
	if times_today.get(source, 0) < 2:
		return   # la primera vez en el día no cuenta: hace falta insistir
	for stat in excess:
		if excess[stat] < float(cfg["minimo"]):
			continue
		var eff := {}
		for k in cfg[stat]:
			eff[k] = excess[stat] * float(cfg[stat][k])
		apply(eff)
		overflow.clear()
		var lines: Array = character.get("saturacion", {}).get(stat, [])
		if not lines.is_empty():
			_log("[color=#f2a65a]%s[/color]" % _pick(lines))


func _add(stat: String, v: float) -> void:
	stats[stat] = clampf(stats[stat] + v, _floor(stat), 100)


func _floor(stat: String) -> float:
	return curse_mark if stat == "lujuria" else 0.0


## Días que faltan para la luna llena (0 = esta noche).
func moon_in() -> int:
	var c := int(balance["maldicion"]["ciclo_luna"])
	return (c - day % c) % c


func is_full_moon() -> bool:
	return moon_in() == 0


## Devuelve cuánto rinde ahora un remedio contra la lujuria y suma tolerancia.
func _tolerance_use(source: String) -> float:
	var t: float = tolerance.get(source, 0.0)
	tolerance[source] = t + 1.0
	return 1.0 / (1.0 + t * float(balance["maldicion"]["tolerancia"]))


## Cuánto rendiría ahora un remedio (para mostrarlo en la interfaz).
func tolerance_factor(source: String) -> float:
	return 1.0 / (1.0 + tolerance.get(source, 0.0) * float(balance["maldicion"]["tolerancia"]))


func _mult_for(id: String) -> float:
	return effectiveness() * float(attitude()["efectividad"]) * pow(float(balance["repeticion_mult"]), times_today.get(id, 0))


func _count(id: String) -> void:
	times_today[id] = times_today.get(id, 0) + 1


func _after_action(moment: String, prob: float) -> void:
	if _check_consumed():
		return
	_try_event(moment, prob)
	changed.emit()


func _check_consumed() -> bool:
	var niveles: Array = balance["niveles"]
	# Si ya llega al máximo no hay crisis que marcar: el final se decide con el vínculo que tenía.
	if not marked and stats["lujuria"] >= float(niveles[3]["min"]) and stats["lujuria"] < 100:
		marked = true
		curse_mark = minf(curse_mark + float(balance["maldicion"]["marca"]), float(balance["maldicion"]["marca_max"]))
		_log("[color=#ef7d86]La maldición deja una marca.[/color]")
		crises += 1
		_bond(float(balance["vinculo"]["crisis"]))
	elif marked and stats["lujuria"] < float(niveles[2]["min"]):
		marked = false
	if not over and stats["lujuria"] >= 100:
		# Solo un vínculo muy fuerte le deja elegir irse en vez de cazarte.
		# Sin él, cómo acaba depende de cuánto llegó a quererte.
		_end("marea" if bond >= bond_goal() else ("lucha" if attitude_index() >= 3 else "poseida"))
	return over


func _end(kind: String, ending: Dictionary = {}) -> void:
	over = true
	if ending.is_empty():
		ending = character["finales"][kind].duplicate()
	ending["tipo"] = kind
	ending["dias"] = day
	ending["vinculo"] = bond
	ending["actitud"] = attitude()["nombre"]
	changed.emit()
	game_over.emit(ending)


## Datos de esta asignación en el proyecto (plazo, nota para aprobar…).
func assignment() -> Dictionary:
	for a in project.get("expedientes", []):
		if a["personaje"] == character["id"]:
			return a
	return {}


## Puntaje de la evaluación (0-100) y su desglose.
func evaluation() -> Dictionary:
	var w: Dictionary = project["evaluacion"]
	var parts := {
		"control": 100.0 - stats["lujuria"],
		"vinculo": clampf(bond, 0.0, 100.0),
		"bienestar": (stats["salud"] + stats["felicidad"] + (100.0 - stats["tristeza"])
			+ (100.0 - stats["hambre"]) + stats["higiene"]) / 5.0,
		"estabilidad": maxf(0.0, 100.0 - crises * float(w["por_crisis"])),
	}
	var total := 0.0
	for k in parts:
		total += parts[k] * float(w["pesos"][k])
	return {"puntaje": roundi(total), "partes": parts, "nota": grade_for(roundi(total))}


## Calificación que corresponde a un puntaje.
func grade_for(score: int) -> Dictionary:
	for g in project["calificaciones"]:
		if score >= int(g["min"]):
			return g
	return project["calificaciones"][-1]


## ¿Esta nota alcanza para pasar a la siguiente asignada?
func passes(grade: String) -> bool:
	var order: Array = project["calificaciones"].map(func(g): return g["nota"])
	return order.find(grade) <= order.find(assignment().get("aprobar", order[-2]))


## Se cumplió el plazo: H.A.R.E.M. evalúa la convivencia.
func _evaluate() -> void:
	var ev := evaluation()
	var g: Dictionary = ev["nota"]
	var ok := passes(g["nota"])
	var texts: Dictionary = character.get("evaluacion", {})
	var report := "EXPEDIENTE H.A.R.E.M. · PROYECTO WAIFU\nAsignada: %s\nConvivencia: %d de %d días\nCalificación: %s · %s\n%s" % [
		character["nombre"], term, term, g["nota"], g["nombre"],
		"Resultado: aprobada." if ok else "Resultado: reprobada. Repite la asignación."]
	var ending := {
		"titulo": "Evaluación final",
		"musica": "final_marea" if ok else "final_lucha",
		"imagen": project.get("imagen_evaluacion", ""),
		"texto": texts.get(g["nota"], "") + "\n\n—\n\n" + report,
		"nota": g["nota"],
		"puntaje": ev["puntaje"],
		"aprobada": ok,
	}
	_end("evaluacion", ending)


## Vínculo necesario para el final bueno.
func bond_goal() -> float:
	return float(balance["vinculo"]["final"])


## Solo molestarla puede dejar el vínculo en negativo; descuidarla lo deja, como mucho, en 0.
func _bond(v: float, can_go_negative := false) -> void:
	var low := -100.0 if can_go_negative else minf(bond, 0.0)
	bond = clampf(bond + v, low, 100.0)


## Por la noche: una casa cuidada lo refuerza; la maldición lo erosiona.
func _night_bond() -> void:
	var vb: Dictionary = balance["vinculo"]
	var lv := level()
	if lv >= 3:
		_bond(float(vb["noche_critica"]))
	elif lv >= 2:
		_bond(float(vb["noche_alterada"]))
	elif stats["felicidad"] >= 55 and stats["tristeza"] <= 35 and stats["hambre"] < 60 and stats["higiene"] > 40:
		_bond(float(vb["noche_cuidada"]) + passive_sum("vinculo_noche"))


func _say(key: String) -> void:
	if quiet:
		return
	var lines: Array = character["dialogos"].get(key, [])
	lines = character.get("dialogos_actitud", {}).get(attitude()["id"], {}).get(key, lines)
	if level() >= 2 and key != "inicio":
		lines = character["charla"]["toque"][attitude()["id"]][lust_band()]
	if not lines.is_empty():
		current_line = _pick(lines)


func _pick(arr: Array) -> String:
	return arr[rng.randi() % arr.size()] if not arr.is_empty() else ""


func _log(text: String) -> void:
	if not quiet:
		log_message.emit(text)
