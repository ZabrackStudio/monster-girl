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
var passives: Array = []            # ids de objetos pasivos comprados
var minigames: Array = []           # ids de minijuegos desbloqueados
var known_affinity: Dictionary = {} # minijuegos ya probados (se muestra la afinidad)
var events_seen: Dictionary = {}
var times_today: Dictionary = {}
var pending_event: Dictionary = {}
var over := false
var current_line := ""
var last_lust_breakdown: Dictionary = {}
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
var annoyed_today := false          # el aviso de molestia sale una vez al día


## Estado que se guarda en la partida (todo lo demás sale de los JSON de datos).
const SAVE_FIELDS := ["stats", "day", "actions_left", "money", "total_money", "inventory",
	"passives", "minigames", "known_affinity", "events_seen", "times_today", "pending_event",
	"tolerance", "curse_mark", "marked", "today", "discovered", "outfit", "outfits", "bond",
	"current_line", "talked_today", "pokes_today", "warned", "annoyed_today"]
const INT_FIELDS := ["day", "actions_left", "money", "total_money"]
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
	_log("Día %d. Partida recuperada." % day)
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
	events = load_json("res://data/eventos.json")
	for it in load_json("res://data/items.json"):
		if it.has("especie") and it["especie"] != character["id"]:
			continue
		items[it["id"]] = it
		item_order.append(it["id"])


func start() -> void:
	for s in STATS:
		stats[s] = float(character["stats_iniciales"].get(s, 50))
	money = int(balance["dinero_inicial"])
	actions_left = int(balance["acciones_por_dia"])
	minigames = [character["minijuego_inicial"]]
	outfit = character.get("traje_inicial", "")
	outfits = [outfit]
	bond = float(balance["vinculo"].get("inicial", 0))
	_say("inicio")
	_log("Día 1. %s (%s) se muda contigo." % [character["nombre"], character["especie"]])
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
	if over or not pending_event.is_empty():
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
	var before := bond
	if attitude_index() <= 2:
		_bond(float(m["vinculo_bajo"]), true, true)
	elif pokes_today > patience * 2:
		_bond(float(m["vinculo_alto"]), true, true)
	if bond < before and not annoyed_today:
		annoyed_today = true
		_log("[color=#ef7d86]%s se está hartando de que la toques: el vínculo baja.[/color]" % character["nombre"])
	if band != "calma":
		apply({"lujuria": m["lujuria_" + band]})
	current_line = _pick(character["charla"]["molesta"][talk_key()])
	if bond <= float(m["denuncia"]):
		_end("denuncia")
		return
	if bond <= float(m["aviso"]) and not warned:
		warned = true
		current_line = character["charla"]["aviso"]
		_log("[color=#ef7d86]%s ha encontrado la tarjeta de H.A.R.E.M. y no le quita ojo.[/color]" % character["nombre"])
	elif bond > float(m["aviso"]):
		warned = false
	_check_consumed()
	changed.emit()


func can_talk() -> bool:
	return not over and pending_event.is_empty() and not talked_today


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
	var real := apply({"lujuria": fx["lujuria"]})
	if quality == "buena" and not discovered.has("charla_" + key):
		discovered["charla_" + key] = true
		_log("[color=#f2c14e](nueva nota en el diario)[/color]")
	if not real.is_empty() and absf(real["lujuria"]) >= 0.5:
		_log("Charla: %s" % _fmt(real))
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
	return true


func why_not(id: String) -> String:
	var act := activity(id)
	if int(act["costo"]) > actions_left: return "No te quedan acciones hoy."
	if money < int(act.get("precio", 0)): return "No tienes dinero suficiente."
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
	var mult := _mult_for(id) * float(character["afinidades"].get(id, 1.0))
	var real := apply(act["efectos"], mult, _tolerance_use(id))
	var extra: Dictionary = character["efectos_extra"].get(id, {})
	if not extra.is_empty():
		real.merge(apply(extra), false)
	_count(id)
	_say(id)
	var msg: String = act["nombre"]
	if earned > 0:
		msg += " (+%d $)" % earned
	_log("%s: %s" % [msg, _fmt(real)])
	today.append(id)
	_apply_reactions(reactions)
	_outfit_effects(id)
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
	var mult := _mult_for("jugar") * minigame_affinity(id)
	var real := apply(eff, mult, _tolerance_use("mj_" + id))
	real.merge(apply(act["efectos"]), false)
	known_affinity[id] = true
	_count("jugar")
	_say("jugar")
	_log("%s (%d%%): %s" % [mg["nombre"], int(score * 100), _fmt(real)])
	if score >= float(balance["vinculo"]["minijuego_min"]):
		_bond(float(balance["vinculo"]["minijuego"]))
	today.append("jugar")
	_apply_reactions(reactions)
	_outfit_effects("jugar")
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
	_log("Compras: %s (-%d $)" % [it["nombre"], int(it["precio"])])
	changed.emit()
	return true


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
	var real := apply(e, effectiveness())
	var name: String = character.get("trajes", {}).get(outfit, outfit)
	_log("[color=#c9b3ff]Con %s:[/color] %s" % [name.to_lower(), _fmt(real)])


func wear(t: String) -> void:
	if over or not outfits.has(t) or t == outfit:
		return
	outfit = t
	_say("vestir")
	_log("%s se pone: %s." % [character["nombre"], character.get("trajes", {}).get(t, t)])
	changed.emit()


func use_item(id: String) -> void:
	if over or inventory.get(id, 0) <= 0 or not pending_event.is_empty():
		return
	inventory[id] -= 1
	if inventory[id] <= 0:
		inventory.erase(id)
	var it: Dictionary = items[id]
	var mult := 1.3 if character["id"] in it.get("favorito", []) else 1.0
	# Usar el mismo objeto varias veces el mismo día rinde cada vez menos.
	var real := apply(it["efectos"], mult * _mult_for("objeto_" + id), _tolerance_use("objeto_" + id))
	_count("objeto_" + id)
	_log("Usas %s: %s" % [it["nombre"], _fmt(real)])
	_check_consumed()
	changed.emit()


func sleep() -> void:
	if over or not pending_event.is_empty():
		return
	var d: Dictionary = balance["dia"]
	var before := stats.duplicate()
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
	for k in tolerance:
		tolerance[k] *= decay
	day += 1
	actions_left = int(balance["acciones_por_dia"])
	times_today.clear()
	today.clear()
	talked_today = false
	pokes_today = 0
	annoyed_today = false
	var diff := {}
	for s in STATS:
		diff[s] = stats[s] - before[s]
	_log("[b]— Día %d —[/b] Durante la noche: %s" % [day, _fmt(diff)])
	if full_moon:
		_log("[color=#ef7d86]Luna llena: la maldición despierta con fuerza.[/color]")
	_log(_explain_lust())
	if _check_consumed():
		return
	if not quiet:
		current_line = touch_line()
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
	last_lust_breakdown = b
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
	for r in list:
		var good: bool = float(r["efectos"].get("lujuria", 0)) < 0
		var real := apply(r["efectos"], effectiveness() if good else 1.0,
			_tolerance_use("reaccion_" + r["id"]) if good else 1.0)
		var first := not discovered.has(r["id"])
		discovered[r["id"]] = true
		var color := "#9fd8ff" if good else "#f2a65a"
		var note := "  [color=#f2c14e](nueva nota en el diario)[/color]" if first else ""
		_log("[color=%s]%s[/color] %s%s" % [color, r["texto"], _fmt(real), note])
		var vb: Dictionary = balance["vinculo"]
		_bond(float(r.get("vinculo", vb["reaccion_buena"] if good else vb["reaccion_trampa"])))


func reactions_total() -> int:
	return character.get("reacciones", []).size()


# ---------------------------------------------------------------- eventos

func option_available(opt: Dictionary) -> bool:
	return money + int(opt.get("efectos", {}).get("dinero", 0)) >= 0


func resolve_event(index: int) -> void:
	if pending_event.is_empty():
		return
	var ev := pending_event
	pending_event = {}
	var opt: Dictionary = ev["opciones"][index]
	if opt.has("final"):
		_end(opt["final"])
		return
	var real := apply(opt.get("efectos", {}), effectiveness())
	var txt: String = opt.get("resultado", "")
	_log("%s %s" % [txt, _fmt(real)])
	_check_consumed()
	changed.emit()


func _try_event(moment: String, prob: float) -> void:
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
	return real


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
		_log("[color=#ef7d86]La maldición deja una marca: la lujuria ya no bajará de %d.[/color]" % roundi(curse_mark))
		_bond(float(balance["vinculo"]["crisis"]))
	elif marked and stats["lujuria"] < float(niveles[2]["min"]):
		marked = false
	if not over and stats["lujuria"] >= 100:
		# Solo un vínculo muy fuerte le deja elegir irse en vez de cazarte.
		# Sin él, cómo acaba depende de cuánto llegó a quererte.
		_end("marea" if bond >= bond_goal() else ("lucha" if attitude_index() >= 3 else "poseida"))
	return over


func _end(kind: String) -> void:
	over = true
	var ending: Dictionary = character["finales"][kind].duplicate()
	ending["tipo"] = kind
	ending["dias"] = day
	ending["vinculo"] = bond
	ending["actitud"] = attitude()["nombre"]
	changed.emit()
	game_over.emit(ending)


## Vínculo necesario para el final bueno.
func bond_goal() -> float:
	return float(balance["vinculo"]["final"])


## Solo molestarla puede dejar el vínculo en negativo; descuidarla lo deja, como mucho, en 0.
func _bond(v: float, can_go_negative := false, silent := false) -> void:
	var before := bond
	var low := -100.0 if can_go_negative else minf(bond, 0.0)
	bond = clampf(bond + v, low, 100.0)
	var real := bond - before
	if absf(real) >= 0.5 and not silent:
		_log("[color=%s]%+d vínculo[/color]" % ["#f07ac0" if real > 0 else "#9a8aa8", roundi(real)])


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


func _fmt(diff: Dictionary) -> String:
	var parts := []
	for k in STATS:
		if diff.has(k) and absf(diff[k]) >= 0.5:
			var v: float = diff[k]
			var good: bool = (v > 0) == (k in GOOD_UP)
			parts.append("[color=%s]%+d %s[/color]" % ["#7ddc9a" if good else "#ef7d86", roundi(v), STAT_NAMES[k].to_lower()])
	return ", ".join(parts) if not parts.is_empty() else "sin cambios"


func _explain_lust() -> String:
	var parts := []
	var total := 0.0
	for k in last_lust_breakdown:
		var v: float = last_lust_breakdown[k]
		total += v
		if absf(v) >= 1.0 and k != "azar":
			parts.append("%s %+.0f" % [k, v])
	return "Lujuria %+.0f esta noche (%s)." % [total, ", ".join(parts)]
