## Guarda capturas de la pantalla principal y de un evento en res://tests/capturas/.
extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/capturas"))
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 30: await process_frame
	main._on_action("pasear")
	for i in 30: await process_frame
	_shot("1_principal")
	if main.modal: main._close_modal()
	main.game.stats["lujuria"] = 80
	main.game.changed.emit()
	for i in 20: await process_frame
	_shot("2_critica")
	main._show_shop()
	for i in 10: await process_frame
	_shot("3_tienda")
	main._start_minigame("burbujas")
	await create_timer(4.0).timeout
	_shot("4_burbujas")
	quit()

func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/capturas/%s.png" % name))
