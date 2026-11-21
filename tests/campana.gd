## Prueba la campaña: plazo, evaluación, nota guardada, desbloqueo y fondos de la siguiente asignada.
extends SceneTree

const Game := preload("res://scripts/game.gd")
const Progress := preload("res://scripts/progreso.gd")
var fails := 0
var ending := {}   # las lambdas no pueden reasignar variables locales


func _init() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print("CAMPAÑA ", "ok   " if ok else "FALLA ", what)
	if not ok:
		fails += 1


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Progress.PATH))
	var p := Progress.project()
	_check(not Progress.unlocked(p, Progress.load_progress(), 1), "Mandy empieza bloqueada")
	# Partida de Reme llevada al último día con buen estado.
	var g = Game.new()
	g.quiet = true
	g.setup("res://data/personajes/slime.json", 1)
	g.start()
	_check(g.term == 30, "Reme tiene 30 días de plazo")
	_check(g.events.all(func(e): return e.get("personaje", "slime") == "slime"), "Reme solo ve sus eventos")
	g.game_over.connect(func(e): ending.clear(); ending.merge(e))
	g.day = 30
	g.bond = 100
	for s in g.stats:
		g.stats[s] = 0.0 if s in ["lujuria", "tristeza", "hambre"] else 100.0
	g.sleep()
	_check(g.over and ending.get("tipo") == "evaluacion", "Al pasar el día 30 llega la evaluación")
	_check(ending.get("nota") == "A" and ending.get("aprobada"), "Buen estado da A y aprueba (nota %s, %s pts)" % [ending.get("nota"), ending.get("puntaje")])
	_check("Calificación: A" in ending.get("texto", ""), "El informe muestra la nota")
	Progress.record_grade("slime", ending["nota"])
	_check(Progress.unlocked(p, Progress.load_progress(), 1), "Aprobar a Reme abre a Mandy")
	_check(Progress.funds_for("ratona") == 60, "Una A da 60 $ extra a la siguiente")
	_check(not Progress.record_grade("slime", "C"), "Una nota peor no pisa la mejor")
	# Mala nota.
	var g2 = Game.new()
	g2.quiet = true
	g2.setup("res://data/personajes/slime.json", 2)
	g2.start()
	g2.game_over.connect(func(e): ending.clear(); ending.merge(e))
	g2.day = 30
	g2.bond = 5
	g2.stats["lujuria"] = 70.0
	g2.crises = 2
	g2.sleep()
	_check(ending.get("nota") == "D" and not ending.get("aprobada"), "Mal estado da D y reprueba (nota %s)" % ending.get("nota"))
	# Mandy.
	var m = Game.new()
	m.quiet = true
	m.setup("res://data/personajes/ratona.json", 3)
	m.start(Progress.funds_for("ratona"))
	_check(m.money == 100, "Mandy empieza con los fondos extra (%d $)" % m.money)
	_check(m.events.all(func(e): return e.get("personaje", "ratona") == "ratona"), "Mandy solo ve sus eventos")
	_check(m.items.has("queso") and not m.items.has("frasco"), "La tienda de Mandy tiene sus objetos")
	_check(m.item_text("queso") == "Su comida favorita." and not m.items.has("gelatina") and m.items.has("nido"), "Tienda y descripciones propias de Mandy")
	# Saturación: con la felicidad al tope, jugar otra vez le sube la lujuria.
	m.stats["hambre"] = 30.0
	var drops := []
	for i in 2:
		m.stats["felicidad"] = 100.0
		m.stats["lujuria"] = 30.0
		m.tolerance.clear()
		m.play_minigame("memoria", 1.0)
		drops.append(30.0 - m.stats["lujuria"])
	_check(drops[1] < drops[0] - 3.0, "Repetir el juego con la felicidad al tope se vuelve en contra (baja %.1f y luego %.1f)" % drops)
	# Respuesta que pide un objeto.
	var ev: Dictionary = m.events.filter(func(e): return e["id"] == "trampa")[0]
	_check(not m.option_available(ev["opciones"][0]), "Sin queso no se puede elegir la respuesta buena")
	m.inventory["queso"] = 1
	_check(m.option_available(ev["opciones"][0]), "Con queso sí")
	m.pending_event = ev
	m.resolve_event(0)
	_check(not m.inventory.has("queso"), "La respuesta gasta el queso")
	for key in ["trabajar", "comer", "pasear", "limpiar", "jugar", "dormir", "inicio", "vestir"]:
		if m.character["dialogos"].get(key, []).is_empty():
			_check(false, "Mandy tiene diálogo de " + key)
	for att in m.balance["vinculo"]["actitudes"]:
		var id: String = att["id"]
		_check(m.character["charla"]["toque"].has(id) and m.character["charla"]["ajuste"].has(id), "Charla de Mandy para actitud " + id)
	for k in ["carnal", "marea", "poseida", "lucha", "denuncia"]:
		_check(m.character["finales"].has(k), "Mandy tiene final " + k)
	var d = JSON.parse_string(JSON.stringify(m.to_dict()))
	var m2 = Game.new()
	m2.setup("res://data/personajes/ratona.json", 4)
	_check(m2.from_dict(d) and m2.term == 30 and m2.character["id"] == "ratona", "El guardado conserva asignada y plazo")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Progress.PATH))
	print("CAMPAÑA resultado: ", "todo ok" if fails == 0 else "%d fallas" % fails)
	quit()
