## Capturas del flujo previo al juego: menú, intro, opciones y continuar.
extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/capturas"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://partida_historia.json"))
	change_scene_to_file("res://scenes/menu.tscn")
	await create_timer(1.0).timeout
	_shot("m1_menu")
	current_scene._on_nueva()
	await create_timer(1.2).timeout
	current_scene._pick("historia")
	await create_timer(1.2).timeout
	current_scene._start("slime")
	await create_timer(3.0).timeout
	_shot("m2_intro")
	for i in 4:
		current_scene._advance()
		current_scene._advance()
	await create_timer(0.3).timeout
	_shot("m3_intro_avanzada")
	current_scene._finish()
	await create_timer(1.2).timeout
	current_scene.game.do_activity("comer")
	current_scene._show_pause()
	await create_timer(0.4).timeout
	_shot("m4_pausa")
	current_scene._close_modal()
	current_scene._start_minigame("burbujas")
	await create_timer(4.0).timeout
	_shot("m4b_burbujas")
	current_scene._close_modal()
	await create_timer(0.3).timeout
	current_scene._start_minigame("memoria")
	await create_timer(0.5).timeout
	_shot("m4c_memoria")
	current_scene._close_modal()
	current_scene._to_menu()
	await create_timer(1.2).timeout
	print("MENU guardado existe: ", FileAccess.file_exists("user://partida_historia.json"))
	current_scene._on_opciones()
	await create_timer(0.4).timeout
	_shot("m5_opciones")
	current_scene._on_continuar()
	await create_timer(0.4).timeout
	current_scene._continue("historia")
	await create_timer(1.2).timeout
	print("MENU continuar: día ", current_scene.game.day, " acciones ", current_scene.game.actions_left)
	_shot("m6_continuar")
	current_scene._on_action("dormir")
	await create_timer(0.9).timeout
	_shot("m7_noche")
	await create_timer(1.5).timeout
	_shot("m8_dia_siguiente")
	quit()

func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/capturas/%s.png" % name))
