## Simulador de equilibrio. Juega miles de partidas con distintas estrategias
## y muestra cuántos días sobreviven.
## Uso: godot --headless --path . -s res://tests/sim.gd
extends SceneTree

const Game := preload("res://scripts/game.gd")
const GAMES := 200
const MAX_DAYS := 1000

var finals := {}
var bonds := []
var parts := {}


func _init() -> void:
	for strategy in (OS.get_environment("SIM_STRATS").split(",") if OS.get_environment("SIM_STRATS") != "" else ["azar", "basica", "experta", "experta:casual", "experta:vestido_blanco", "experta:vestido_lila"]):
		var days := []
		finals.clear()
		bonds.clear()
		parts.clear()
		for i in GAMES:
			days.append(_run(strategy, i))
		days.sort()
		var total := 0
		for d in days:
			total += d
		print("%-8s  media %6.1f  mediana %4d  p10 %4d  p90 %4d  máx %4d  finales %s" % [
			strategy, float(total) / GAMES, days[GAMES / 2], days[GAMES / 10],
			days[GAMES * 9 / 10], days[-1], finals])
		bonds.sort()
		if parts.get("n", 0) > 0:
			var line := "          evaluación media:"
			for k in parts:
				if k != "n":
					line += " %s %.0f" % [k, parts[k] / parts["n"]]
			print(line)
		print("          vínculo final: mediana %d  p90 %d  máx %d" % [bonds[bonds.size() / 2], bonds[bonds.size() * 9 / 10], bonds[-1]])
	quit()


func _run(strategy: String, seed_value: int) -> int:
	var g = Game.new()
	g.quiet = true
	var cid := OS.get_environment("SIM_CHAR") if OS.get_environment("SIM_CHAR") != "" else "slime"
	g.setup("res://data/personajes/%s.json" % cid, seed_value)
	g.event_triggered.connect(func(ev): _resolve(g, ev, strategy))
	g.game_over.connect(func(e):
		var k: String = e["tipo"] + (":" + e["nota"] if e.has("nota") else "")
		finals[k] = finals.get(k, 0) + 1
		bonds.append(g.bond)
		if e.has("puntaje"):
			var ev: Dictionary = g.evaluation()
			parts["n"] = parts.get("n", 0) + 1
			parts["puntaje"] = parts.get("puntaje", 0.0) + float(e["puntaje"])
			for part in ev["partes"]:
				parts[part] = parts.get(part, 0.0) + float(ev["partes"][part]))
	g.start()
	if ":" in strategy:
		g.outfit = strategy.split(":")[1]
		g.outfits.append(g.outfit)
		strategy = "experta"
	while not g.over and g.day < MAX_DAYS:
		_talk(g, strategy)
		var guard := 0
		while g.actions_left > 0 and not g.over and guard < 20:
			guard += 1
			if not _act(g, strategy):
				break
		if not g.over:
			g.sleep()
	return g.day


## Charla diaria: al azar habla la mitad de los días y sin criterio; la básica
## contesta sin criterio; la experta conoce la respuesta buena.
func _talk(g, strategy: String) -> void:
	if not g.can_talk():
		return
	var opts: Array = g.character["charla"]["opciones"].keys()
	if strategy.begins_with("experta"):
		var table: Dictionary = g.character["charla"]["ajuste"][g.talk_key()]
		g.talk(table.find_key("buena"))
	elif strategy == "basica" or g.rng.randf() < 0.5:
		g.talk(opts[g.rng.randi() % opts.size()])


func _resolve(g, ev: Dictionary, strategy: String) -> void:
	var opts: Array = ev["opciones"]
	var best := 0
	if strategy == "azar":
		best = g.rng.randi() % opts.size()
	else:
		var best_score := -INF
		for i in opts.size():
			if not g.option_available(opts[i]) or opts[i].has("final"):
				continue
			var e: Dictionary = opts[i].get("efectos", {})
			var s := -float(e.get("lujuria", 0)) * 2 - float(e.get("tristeza", 0)) + float(e.get("felicidad", 0))
			if s > best_score:
				best_score = s
				best = i
	g.resolve_event(best)


## Devuelve false si no hace nada (termina el día).
func _act(g, strategy: String) -> bool:
	var s: Dictionary = g.stats
	if strategy == "azar":
		var opts := ["trabajar", "comer", "pasear", "limpiar", "jugar", "dormir"]
		var pick: String = opts[g.rng.randi() % opts.size()]
		if pick == "dormir":
			return false
		if pick == "jugar":
			if g.can_play():
				g.play_minigame(g.minigames[0], g.rng.randf())
				return true
			return false
		if g.can_do(pick):
			g.do_activity(pick)
			return true
		return false

	var expert := strategy == "experta"
	if expert:
		_shop(g)
		if s["lujuria"] > 45 and g.inventory.get("manzanilla", 0) > 0:
			g.use_item("manzanilla")
		if s["higiene"] < 40 and g.inventory.get("jabon", 0) > 0:
			g.use_item("jabon")
		for food in ["gelatina", "queso"]:
			if s["hambre"] > 50 and g.inventory.get(food, 0) > 0:
				g.use_item(food)
	if expert and _routine(g):
		return true
	if s["hambre"] > 55 and g.can_do("comer") and not (expert and _trap(g, "comer")):
		g.do_activity("comer"); return true
	if s["higiene"] < 40 and g.can_do("limpiar") and not (expert and _trap(g, "limpiar")):
		g.do_activity("limpiar"); return true
	if g.money < (60 if expert else 25) and g.can_do("trabajar"):
		g.do_activity("trabajar"); return true
	if g.times_today.get("pasear", 0) == 0 and g.can_do("pasear") and not (expert and _trap(g, "pasear")):
		g.do_activity("pasear"); return true
	if g.can_play() and g.times_today.get("jugar", 0) < 2:
		var mg: String = g.minigames[0]
		if expert:
			var best := -1.0
			for m in g.minigames:
				if g.minigame_affinity(m) > best:
					best = g.minigame_affinity(m); mg = m
		g.play_minigame(mg, g.rng.randf_range(0.5, 0.95) if expert else g.rng.randf_range(0.3, 0.8))
		return true
	if g.can_do("trabajar"):
		g.do_activity("trabajar"); return true
	return false


func _shop(g) -> void:
	for id in ["almohada", "pecera", "lampara", "frasco", "linterna", "tocadiscos"]:
		if g.items.has(id) and g.can_buy(id) and g.money >= int(g.items[id]["precio"]) + 30:
			g.buy(id)
	if g.inventory.get("manzanilla", 0) < 2 and g.money >= 50:
		g.buy("manzanilla")
	if g.inventory.get("jabon", 0) < 1 and g.money >= 40:
		g.buy("jabon")


## ¿Hacer esto ahora dispararía una trampa de su especie?
func _trap(g, id: String) -> bool:
	for r in g._match_reactions(id):
		if float(r["efectos"].get("lujuria", 0)) > 0:
			return true
	return false


## Rutina del vínculo de su especie (la reacción que da vínculo) evitando las trampas.
func _routine(g) -> bool:
	var seq := []
	for r in g.character.get("reacciones", []):
		if r.has("vinculo") and r.has("cadena"):
			seq = r["cadena"]
	var done: Array = g.today
	if done.size() >= seq.size() or done != seq.slice(0, done.size()):
		return false
	var nxt: String = seq[done.size()]
	if _trap(g, nxt):
		return false
	if nxt == "jugar":
		if not g.can_play():
			return false
		var mg: String = g.minigames[0]
		for m in g.minigames:
			if g.minigame_affinity(m) > g.minigame_affinity(mg):
				mg = m
		g.play_minigame(mg, g.rng.randf_range(0.5, 0.95))
		return true
	if not g.can_do(nxt):
		return false
	g.do_activity(nxt)
	return true
