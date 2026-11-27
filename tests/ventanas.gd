## Comprueba cuadro por cuadro que las ventanas no saltan de lugar al aparecer.
extends SceneTree

var main
var fails := 0


func _init() -> void:
	_run.call_deferred()


## Sigue la ventana abierta durante unos cuadros mientras se ve en pantalla.
func _watch(what: String) -> void:
	var rects: Array[Rect2] = []
	for i in 16:
		await process_frame
		if main.modal == null or main.modal.modulate.a <= 0.0:
			continue
		var panel: Control = main.modal.get_child(0).get_child(0).get_child(0)
		var r: Rect2 = panel.get_global_rect()
		if rects.is_empty() or rects[-1] != r:
			rects.append(r)
	var ok := rects.size() == 1
	print("VENTANAS ", "ok   " if ok else "FALLA ", what, " ", rects)
	if not ok:
		fails += 1


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://partida_historia.json"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	var g = main.game
	main._show_talk(g.touch_line() if g.has_method("touch_line") else "Hola.")
	await _watch("charla: pregunta")
	var key: String = g.talk_key()
	main._talk_reply(g.character["charla"]["ajuste"][key].keys()[0])
	await _watch("charla: respuesta")
	main._close_modal()
	await create_timer(0.3).timeout
	main._show_pause()
	await _watch("pausa")
	main._close_modal()
	await create_timer(0.3).timeout
	main._show_inventory()
	await _watch("objetos")
	main._show_minigame_select()
	await _watch("objetos a minijuegos (reemplazo directo)")
	main._close_modal()
	main._show_inventory()
	main._show_pause()              # dos ventanas seguidas antes de terminar de medir
	await _watch("dos ventanas seguidas")
	main._close_modal()
	await create_timer(0.4).timeout
	var left := 0
	for c in main.get_children():
		if c is ColorRect and c != main.bg and c.mouse_filter == Control.MOUSE_FILTER_STOP:
			left += 1
	print("VENTANAS ", "ok   " if left == 0 else "FALLA ", "no quedan ventanas abiertas: ", left)
	if left != 0:
		fails += 1
	print("VENTANAS resultado: ", "todo ok" if fails == 0 else "%d fallas" % fails)
	quit()
