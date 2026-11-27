## Modos historia y casual: partidas separadas, migración de la partida vieja, casual sin plazo,
## continuar cada una y las pantallas nuevas (menú, modo, galería). Con ventana guarda capturas.
extends SceneTree

const Game := preload("res://scripts/game.gd")
var fails := 0
var backup := {}


func _init() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print("MODOS ", "ok   " if ok else "FALLA ", what)
	if not ok:
		fails += 1


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	if img:
		img.save_png(ProjectSettings.globalize_path("res://tests/capturas/m_%s.png" % name))


func _write(path: String, data) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))


func _scene(path: String) -> Node:
	for c in root.get_children():
		if c is Control:
			c.queue_free()
	await process_frame
	var n = load(path).instantiate()
	if "transitions" in n:
		n.transitions = false
	root.add_child(n)
	for i in 12: await process_frame
	return n


func _run() -> void:
	# Se respaldan los archivos del usuario para no pisarlos.
	for p in [Game.LEGACY_SAVE, Game.save_path("historia"), Game.save_path("casual"), "user://records.json", "user://proyecto.json"]:
		if FileAccess.file_exists(p):
			backup[p] = FileAccess.get_file_as_string(p)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

	# Partida vieja (un solo archivo) -> pasa a ser la de historia.
	var g = Game.new()
	g.quiet = true
	g.setup("res://data/personajes/ratona.json", 1)
	g.start()
	g.day = 12
	_write(Game.LEGACY_SAVE, g.to_dict())
	var saves: Array = Game.saved_games()
	_check(saves.size() == 1 and saves[0]["modo"] == "historia" and saves[0]["personaje"] == "ratona", "La partida vieja se recupera como historia")
	_check(not FileAccess.file_exists(Game.LEGACY_SAVE), "El archivo viejo ya no queda suelto")

	# Casual: sin plazo y en su propio archivo.
	var c = Game.new()
	c.quiet = true
	c.mode = "casual"
	c.setup("res://data/personajes/slime.json", 2)
	c.start()
	_check(c.term == 0, "Casual no tiene plazo")
	c.day = 41
	_write(Game.save_path("casual"), c.to_dict())
	saves = Game.saved_games()
	_check(saves.size() == 2, "Hay dos partidas guardadas a la vez")

	# Continuar cada una.
	Engine.set_meta("modo", "casual")
	Engine.set_meta("continuar", true)
	var main = await _scene("res://scenes/main.tscn")
	_check(main.game.character["id"] == "slime" and main.game.day == 41 and main.game.term == 0, "Continuar casual carga a Reme en el día 41")
	main.game.do_activity("limpiar")
	main._show_pause()
	for i in 6: await process_frame
	await _shot("pausa")
	main._close_modal()
	Engine.set_meta("modo", "historia")
	Engine.set_meta("continuar", true)
	main = await _scene("res://scenes/main.tscn")
	_check(main.game.character["id"] == "ratona" and main.game.day == 12 and main.game.term == 30, "Continuar historia carga a Mandy en el día 12 de 30")
	var casual_saved = Game.load_json(Game.save_path("casual"))
	_check(int(casual_saved["day"]) == 41, "Jugar la historia no toca la partida casual")

	# Pantallas nuevas.
	var menu = await _scene("res://scenes/menu.tscn")
	await _shot("menu")
	menu._on_continuar()
	for i in 10: await process_frame
	await _shot("continuar")
	await _scene("res://scenes/modo.tscn")
	await _shot("modo")
	Engine.set_meta("modo", "casual")
	await _scene("res://scenes/expedientes.tscn")
	await _shot("casual")
	_write("user://records.json", {"slime": {"mejor_dias": 22, "finales": ["poseida", "marea", "evaluacion"], "partidas": 3, "dinero_total": 0},
		"ratona": {"mejor_dias": 9, "finales": ["lucha"], "partidas": 1, "dinero_total": 0}})
	_write("user://proyecto.json", {"notas": {"slime": "B"}})
	var gal = await _scene("res://scenes/galeria.tscn")
	await _shot("galeria")
	_check(gal.current == "slime", "La galería abre con la primera chica conocida")
	var tab_names := []
	for b in gal.tabs.get_children():
		tab_names.append(b.text)
	_check(tab_names[1] == "Mandy" and tab_names[3] == "???", "Muestra a las conocidas y tapa al resto (%s)" % ", ".join(tab_names))
	gal._replay(gal._ending(Game.load_json("res://data/personajes/slime.json"), "marea"))
	for i in 40: await process_frame
	await _shot("galeria_final")

	for c2 in root.get_children():
		if c2 is Control:
			c2.queue_free()
	for p in [Game.LEGACY_SAVE, Game.save_path("historia"), Game.save_path("casual"), "user://records.json", "user://proyecto.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		if backup.has(p):
			_write_raw(p, backup[p])
	Engine.set_meta("modo", "historia")
	print("MODOS resultado: ", "todo ok" if fails == 0 else "%d fallas" % fails)
	quit()


func _write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
