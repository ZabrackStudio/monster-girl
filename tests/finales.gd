## Recorre los cinco finales: ilustración, texto dentro de pantalla y resultados.
## Con ventana guarda capturas en res://tests/capturas/.
extends SceneTree

var fails := 0


func _init() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print("FINALES ", "ok   " if ok else "FALLA ", what)
	if not ok:
		fails += 1


func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	if img:
		img.save_png(ProjectSettings.globalize_path("res://tests/capturas/f_%s.png" % name))


func _run() -> void:
	for kind in ["poseida", "lucha", "carnal", "denuncia", "marea"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://partida.json"))
		var main = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		for i in 10: await process_frame
		main.game._end(kind)
		await create_timer(2.2).timeout
		var scene = main.ending_scene
		_check(scene != null, kind + ": abre la escena")
		_check(ResourceLoader.exists(main.game.character["finales"][kind]["imagen"]), kind + ": imagen importada")
		var after_cut: bool = scene.ending.get("imagen_tras_corte", false)
		await create_timer(1.2).timeout
		_shot(kind + "_1")
		var fits := true
		var steps := 0
		var seen_art: bool = scene.art.modulate.a > 0.5
		while main.modal == null and steps < 100:
			steps += 1
			scene.advance()
			await create_timer(0.05).timeout
			scene.advance()            # completa la frase
			await create_timer(0.05).timeout
			seen_art = seen_art or scene.art.modulate.a > 0.1
			var r: Rect2 = scene.box.get_global_rect()
			if scene.box.visible and (r.position.y < 0 or r.end.y > scene.size.y):
				fits = false
				print("FINALES medida ", kind, " paso ", steps, " caja ", r, " escena ", scene.size, " texto: ", scene.text.text.left(30))
			if steps == 2:
				await create_timer(1.1).timeout
				_shot(kind + "_2")
		_check(fits, kind + ": el texto cabe en pantalla")
		_check(main.modal != null, kind + ": llega a los resultados (%d toques)" % steps)
		if after_cut:
			_check(seen_art, kind + ": la imagen aparece tras el corte")
		await create_timer(1.0).timeout
		_shot(kind + "_3")
		main.queue_free()
		await process_frame
		await process_frame
	print("FINALES resultado: ", "todo ok" if fails == 0 else "%d fallas" % fails)
	quit()
