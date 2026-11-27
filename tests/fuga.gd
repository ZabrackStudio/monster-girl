## Pasiva de Leapy: con poco vínculo, a veces se escapa cuando sales a trabajar y vuelve de noche.
extends SceneTree

const Game := preload("res://scripts/game.gd")
var fails := 0


func _check(ok: bool, what: String) -> void:
	print("FUGA ", "ok   " if ok else "FALLA ", what)
	if not ok:
		fails += 1


func _init() -> void:
	var g = Game.new()
	g.quiet = true
	g.setup("res://data/personajes/leoparda.json", 3)
	g.start()
	g.character["fuga"]["prob"] = 1.0
	g.balance["dia"]["prob_evento_noche"] = 0.0
	g.balance["actividades"]["trabajar"]["prob_evento"] = 0.0
	g.inventory = {"carne_seca": 1}
	g.bond = 10.0
	g.do_activity("trabajar")
	_check(g.absent, "Con poco vínculo se escapa al salir a trabajar")
	_check(not g.can_do("comer") and not g.can_do("pasear") and not g.can_play() and not g.can_talk(), "Sin ella no se puede hacer nada con ella")
	_check(g.can_do("trabajar"), "Trabajar sigue disponible")
	g.use_item("carne_seca")
	_check(g.inventory.get("carne_seca", 0) == 1, "No se le pueden dar objetos")
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var g2 = Game.new()
	g2.quiet = true
	g2.setup("res://data/personajes/leoparda.json", 3)
	g2.from_dict(d)
	_check(g2.absent, "El guardado recuerda que no está")
	var higiene: float = g.stats["higiene"]
	g.sleep()
	_check(not g.absent and g.stats["higiene"] < higiene, "Vuelve de noche, con la calle encima")

	g.bond = 60.0
	g.do_activity("trabajar")
	_check(not g.absent, "Con vínculo alto no se escapa")

	var reme = Game.new()
	reme.quiet = true
	reme.setup("res://data/personajes/slime.json", 3)
	reme.start()
	reme.bond = -5.0
	for i in 5:
		reme.do_activity("trabajar")
		reme.sleep()
	_check(not reme.absent, "Las demás no se escapan")
	print("FUGA resultado: ", "todo ok" if fails == 0 else "%d fallas" % fails)
	quit()
