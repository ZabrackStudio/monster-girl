## Pasiva de Mandy: esconde objetos de noche y los eventos del escondite los devuelven o los pierden.
extends SceneTree

const Game := preload("res://scripts/game.gd")
var fails := 0


func _check(ok: bool, what: String) -> void:
	print("ESCONDITE ", "ok   " if ok else "FALLA ", what)
	if not ok:
		fails += 1


func _event(g, id: String) -> Dictionary:
	for ev in g.events:
		if ev["id"] == id:
			return ev
	return {}


func _option(ev: Dictionary, mode: String) -> int:
	for i in ev["opciones"].size():
		if ev["opciones"][i].get("escondite", "") == mode:
			return i
	return -1


func _init() -> void:
	var g = Game.new()
	g.quiet = true
	g.setup("res://data/personajes/ratona.json", 7)
	g.start()
	g.character["esconde"]["prob"] = 1.0
	g.balance["dia"]["prob_evento_noche"] = 0.0
	g.inventory = {"queso": 2, "manzanilla": 1}
	g.sleep()
	_check(g.stash_count() == 1 and g.inventory.values().reduce(func(a, b): return a + b) == 2, "De noche esconde un objeto")
	g.sleep()
	_check(g.stash_count() == 2, "Sigue escondiendo")
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var g2 = Game.new()
	g2.quiet = true
	g2.setup("res://data/personajes/ratona.json", 7)
	g2.from_dict(d)
	_check(g2.stash_count() == 2, "El guardado conserva lo escondido")

	var ev := _event(g, "escondite")
	_check(not ev.is_empty() and g._conditions_ok(ev["condiciones"]), "El evento del escondite aparece cuando hay algo escondido")
	g.pending_event = ev
	g.resolve_event(_option(ev, "devolver"))
	_check(g.stash_count() == 0 and g.inventory.get("queso", 0) + g.inventory.get("manzanilla", 0) == 3, "Recuperar lo tuyo devuelve todo")
	_check(not g._conditions_ok(ev["condiciones"]), "Sin nada escondido no sale el evento")

	g.sleep()
	var acap := _event(g, "acaparar")
	g.pending_event = acap
	g.resolve_event(_option(acap, "perder"))
	_check(g.stash_count() == 0 and g.inventory.values().reduce(func(a, b): return a + b, 0) == 2, "Tirarlo todo lo pierde")

	var reme = Game.new()
	reme.quiet = true
	reme.setup("res://data/personajes/slime.json", 7)
	reme.start()
	reme.inventory = {"jabon": 3}
	for i in 5:
		reme.sleep()
	_check(reme.stash.is_empty(), "Reme no esconde nada")
	print("ESCONDITE resultado: ", "todo ok" if fails == 0 else "%d fallas" % fails)
	quit()
