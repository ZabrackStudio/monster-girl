## Capturas del flujo previo al juego: menú, intro, opciones y continuar.
extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/capturas"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://partida.json"))
	change_scene_to_file("res://scenes/menu.tscn")
	for i in 20: await process_frame
	_shot("m1_menu")
	current_scene._on_nueva()
	for i in 20: await process_frame
	await create_timer(2.5).timeout
	_shot("m2_intro")
	for i in 4:
		current_scene._advance()
		current_scene._advance()
	await create_timer(0.3).timeout
	_shot("m3_intro_avanzada")
	current_scene._finish()
	for i in 20: await process_frame
	current_scene.game.do_activity("comer")
	current_scene._show_pause()
	for i in 10: await process_frame
	_shot("m4_pausa")
	current_scene._to_menu()
	for i in 20: await process_frame
	print("MENU guardado existe: ", FileAccess.file_exists("user://partida.json"))
	current_scene._on_opciones()
	for i in 10: await process_frame
	_shot("m5_opciones")
	current_scene._on_continuar()
	for i in 20: await process_frame
	print("MENU continuar: día ", current_scene.game.day, " acciones ", current_scene.game.actions_left)
	_shot("m6_continuar")
	quit()

func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/capturas/%s.png" % name))
