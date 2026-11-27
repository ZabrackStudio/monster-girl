## Capturas de Leapy: su vivienda, en crisis y vacía tras escaparse.
extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/capturas/l_%s.png" % name))


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://partida_historia.json"))
	Engine.set_meta("personaje", "leoparda")
	var main = load("res://scenes/main.tscn").instantiate()
	main.transitions = false
	root.add_child(main)
	for i in 20: await process_frame
	await _shot("casa")
	main.game.stats["lujuria"] = 80.0
	main.game.changed.emit()
	for i in 30: await process_frame
	await _shot("critica")
	main.game.stats["lujuria"] = 20.0
	main.game.character["fuga"]["prob"] = 1.0
	main.game.bond = 0.0
	main.game.do_activity("trabajar")
	for i in 60: await process_frame
	await _shot("vacia")
	main.queue_free()
	Engine.set_meta("personaje", "slime")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://partida_historia.json"))
	quit()
