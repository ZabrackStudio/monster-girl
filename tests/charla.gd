## Prueba de la charla: toque real sobre el retrato, actitudes y finales.
extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _tap(pos: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		root.push_input(e)
		await process_frame

func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://partida.json"))
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 30: await process_frame
	var g = main.game
	print("CHARLA actitud inicial: ", g.attitude()["nombre"], " vínculo ", g.bond)
	var sprite = main.portrait.sprite
	# Los toques llegan en píxeles de ventana; el juego se dibuja escalado dentro de ella.
	var center: Vector2 = root.get_screen_transform() * root.get_final_transform() * sprite.get_global_rect().get_center()
	print("CHARLA ventana ", root.size, " toque en ", center)
	await create_timer(1.5).timeout   # que termine el fundido de entrada
	main.portrait.gui_input.connect(func(e): if e is InputEventMouseButton: print("CHARLA retrato recibe ", e.position, " hit ", main.portrait.hit(e.position), " rect ", main.portrait.sprite.get_rect()))
	await _tap(center)
	print("CHARLA bajo el dedo: ", root.gui_get_hovered_control())
	for i in 20: await process_frame
	print("CHARLA toque abre ventana: ", main.modal != null)
	_shot("c1_charla")
	var key: String = g.talk_key()
	var best: String = g.character["charla"]["ajuste"][key].find_key("buena")
	var before: float = g.bond
	main._talk_reply(best)
	for i in 20: await process_frame
	print("CHARLA buena: vínculo ", before, " -> ", g.bond)
	_shot("c2_respuesta")
	main._close_modal()
	await create_timer(0.4).timeout
	await _tap(center)
	for i in 10: await process_frame
	print("CHARLA segundo toque sin ventana: ", main.modal == null, " frase: ", g.current_line)
	var d = JSON.parse_string(JSON.stringify(g.to_dict()))
	print("CHARLA guardado conserva charla: ", d["talked_today"])
	for b in [5.0, 15.0, 30.0, 50.0, 80.0]:
		g.bond = b
		g.changed.emit()
		for i in 30: await process_frame
		print("CHARLA vínculo %d: %s, cara %s, frase: %s" % [b, g.attitude()["nombre"], g.mood(), g.touch_line()])
		_shot("c3_actitud_%d" % b)
	for pair in [[5.0, "poseida"], [30.0, "lucha"], [75.0, "lucha"], [76.0, "marea"]]:
		var t = load("res://scripts/game.gd").new()
		t.quiet = true
		t.setup("res://data/personajes/slime.json", 3)
		t.start()
		var got := []
		t.game_over.connect(func(e): got.append(e["tipo"]))
		t.bond = pair[0]
		t.stats["lujuria"] = 100.0
		t._check_consumed()
		print("CHARLA final con vínculo %d: %s (esperado %s)" % [pair[0], got[0], pair[1]])
	quit()

func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/capturas/%s.png" % name))
