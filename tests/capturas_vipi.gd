## Capturas de Vipi: su casa, su tienda y la ficha del expediente.
extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/capturas/v_%s.png" % name))


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://partida.json"))
	Engine.set_meta("personaje", "dragona")
	var main = load("res://scenes/main.tscn").instantiate()
	main.transitions = false
	root.add_child(main)
	for i in 20: await process_frame
	await _shot("casa")
	main.game.stats["lujuria"] = 80.0
	main.game.changed.emit()
	for i in 30: await process_frame
	await _shot("critica")
	main._show_shop()
	for i in 20: await process_frame
	main._shop_tab("Cuidado personal")
	for i in 20: await process_frame
	await _shot("tienda")
	main.queue_free()
	Engine.set_meta("personaje", "slime")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://partida.json"))
	quit()
