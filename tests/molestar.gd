## Prueba de molestarla: paciencia, vínculo negativo, lujuria y final de denuncia.
extends SceneTree
const Game := preload("res://scripts/game.gd")

func _new(bond: float, lust := 5.0):
	var g = Game.new()
	g.quiet = true
	g.setup("res://data/personajes/slime.json", 5)
	g.start()
	g.bond = bond
	g.stats["lujuria"] = lust
	g.talked_today = true
	return g

func _check(name: String, ok: bool) -> void:
	print("%s %s" % ["MOLESTAR ok  " if ok else "MOLESTAR FALLA", name])

func _init() -> void:
	var g = _new(50.0)
	for i in 6: g.poke()
	_check("Cariñosa aguanta 6 toques sin perder vínculo", g.bond == 50.0)
	for i in 6: g.poke()
	_check("Cariñosa no pierde hasta el doble de paciencia", g.bond == 50.0)
	g.poke()
	_check("Cariñosa pierde al insistir de más", g.bond == 49.0)

	g = _new(15.0)
	g.poke(); g.poke()
	_check("Distante aguanta 2 toques", g.bond == 15.0)
	g.poke()
	_check("Distante se molesta al tercero", g.bond == 13.0)

	g = _new(50.0, 60.0)
	g.poke(); g.poke()
	var before: float = g.stats["lujuria"]
	g.poke()
	_check("Alterada: tocarla de más sube la lujuria", g.stats["lujuria"] == before + 2.0)

	g = _new(50.0, 80.0)
	g.marked = true
	g.poke()
	before = g.stats["lujuria"]
	g.poke()
	_check("Crítica: sube más y aguanta menos", g.stats["lujuria"] == before + 3.0)

	g = _new(3.0)
	g._bond(-40.0)
	_check("Descuidarla no baja de 0", g.bond == 0.0)

	g = _new(5.0)
	var ending := []
	g.game_over.connect(func(e): ending.append(e["tipo"]))
	var n := 0
	var saw_hostile := false
	var saw_warning := false
	while not g.over and n < 100:
		n += 1
		g.poke()
		saw_hostile = saw_hostile or g.attitude()["id"] == "hostil"
		saw_warning = saw_warning or g.warned
	_check("Llega a Hostil en negativo", saw_hostile)
	_check("Avisa antes de denunciar", saw_warning)
	_check("Termina en denuncia (%d toques, vínculo %d)" % [n, g.bond], ending == ["denuncia"])

	g = _new(-10.0)
	g.talked_today = false
	g.talk("distancia")
	_check("Se puede recuperar desde negativo", g.bond == -8.0)
	var d = JSON.parse_string(JSON.stringify(g.to_dict()))
	var h = _new(0.0)
	h.from_dict(d)
	_check("El guardado conserva el vínculo negativo", h.bond == -8.0 and h.attitude()["id"] == "hostil")
	quit()
