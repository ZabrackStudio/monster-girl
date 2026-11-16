## Simulador de equilibrio. Juega miles de partidas con distintas estrategias
## y muestra cuántos días sobreviven.
## Uso: godot --headless --path . -s res://tests/sim.gd
extends SceneTree

const Game := preload("res://scripts/game.gd")
const GAMES := 200
const MAX_DAYS := 1000

var finals := {}
var bonds := []


func _init() -> void:
	for strategy in (OS.get_environment("SIM_STRATS").split(",") if OS.get_environment("SIM_STRATS") != "" else ["azar", "basica", "experta", "experta:casual", "experta:vestido_blanco", "experta:vestido_lila"]):
		var days := []
		finals.clear()
		bonds.clear()
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
		print("          vínculo final: mediana %d  p90 %d  máx %d" % [bonds[bonds.size() / 2], bonds[bonds.size() * 9 / 10], bonds[-1]])
	quit()


func _run(strategy: String, seed_value: int) -> int:
	var g = Game.new()
	g.quiet = true
	g.setup("res://data/personajes/slime.json", seed_value)
	g.event_triggered.connect(func(ev): _resolve(g, ev, strategy))
	g.game_over.connect(func(e): finals[e["tipo"]] = finals.get(e["tipo"], 0) + 1; bonds.append(g.bond))
	g.start()
	if ":" in strategy:
		g.outfit = strategy.split(":")[1]
		g.outfits.append(g.outfit)
		strategy = "experta"
	while not g.over and g.day < MAX_DAYS:
		var guard := 0
		while g.actions_left > 0 and not g.over and guard < 20:
			guard += 1
			if not _act(g, strategy):
				break
		if not g.over:
			g.sleep()
	return g.day


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
		if s["hambre"] > 50 and g.inventory.get("gelatina", 0) > 0:
			g.use_item("gelatina")
	if expert and _routine(g):
		return true
	if s["hambre"] > 55 and g.can_do("comer"):
		g.do_activity("comer"); return true
	if s["higiene"] < 40 and g.can_do("limpiar"):
		g.do_activity("limpiar"); return true
	if g.money < (60 if expert else 25) and g.can_do("trabajar"):
		g.do_activity("trabajar"); return true
	if g.times_today.get("pasear", 0) == 0 and g.can_do("pasear"):
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
	for id in ["almohada", "pecera", "lampara", "frasco"]:
		if g.items.has(id) and g.can_buy(id) and g.money >= int(g.items[id]["precio"]) + 30:
			g.buy(id)
	if g.inventory.get("manzanilla", 0) < 2 and g.money >= 50:
		g.buy("manzanilla")
	if g.inventory.get("jabon", 0) < 1 and g.money >= 40:
		g.buy("jabon")


## Rutina del vínculo (comer, pasear, jugar, limpiar) evitando las trampas.
func _routine(g) -> bool:
	var seq := ["comer", "pasear", "jugar", "limpiar"]
	var done: Array = g.today
	if done.size() >= seq.size() or done != seq.slice(0, done.size()):
		return false
	var nxt: String = seq[done.size()]
	if nxt == "comer" and g.stats["hambre"] <= 25:
		return false
	if nxt == "pasear" and g.stats["higiene"] <= 35:
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
