## Capturas de las pantallas nuevas: expedientes, informe, Mandy en casa y evaluación.
extends SceneTree

const Progress := preload("res://scripts/progreso.gd")


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/capturas/%s.png" % name))


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Progress.PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://partida.json"))
	change_scene_to_file("res://scenes/expedientes.tscn")
	await create_timer(1.0).timeout
	_shot("x1_expedientes_bloqueado")
	Progress.record_grade("slime", "B")
	change_scene_to_file("res://scenes/expedientes.tscn")
	await create_timer(1.0).timeout
	_shot("x2_expedientes_abierto")
	current_scene._start("ratona")
	await create_timer(3.0).timeout
	_shot("x3_informe_mandy")
	current_scene._finish()
	await create_timer(1.5).timeout
	_shot("x4_mandy_casa")
	var main = current_scene
	main._show_shop()
	await create_timer(0.6).timeout
	main._shop_tab("Vestuario")
	await create_timer(0.4).timeout
	_shot("x5_tienda_mandy")
	main._close_modal()
	main.game.outfits.append("casual60")
	main.game.wear("casual60")
	main.game.stats["lujuria"] = 80
	main.game.changed.emit()
	await create_timer(1.0).timeout
	_shot("x6_mandy_casual_critica")
	main.game.stats["lujuria"] = 20
	main.game.bond = 60
	main.game.day = 30
	main.game.sleep()
	await create_timer(4.5).timeout
	_shot("x7_evaluacion")
	for i in 30:
		if main.modal != null: break
		main.ending_scene.advance()
		await create_timer(0.1).timeout
	await create_timer(1.0).timeout
	_shot("x8_resultado")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Progress.PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://partida.json"))
	quit()
