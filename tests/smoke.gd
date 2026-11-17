## Prueba de humo de la interfaz: carga la escena, pulsa acciones,
## abre todas las ventanas y juega hasta un final.
extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.transitions = false
	root.add_child(main)
	await process_frame
	var g = main.game
	for id in ["trabajar", "comer", "pasear", "limpiar"]:
		main._on_action(id); await process_frame
		if not g.pending_event.is_empty(): main._choose(0); await process_frame
	main._show_shop(); await process_frame
	g.money = 500
	main._buy("mj_memoria"); main._buy("manzanilla"); main._buy("pecera"); await process_frame
	main._show_inventory(); await process_frame
	main._use("manzanilla"); await process_frame
	for mgid in ["burbujas", "memoria"]:
		main._start_minigame(mgid)
		for i in 5: await process_frame
		main._on_minigame_done(0.7, mgid); await process_frame
		if not g.pending_event.is_empty(): main._choose(0); await process_frame
	main._show_minigame_select(); await process_frame
	main._close_modal()
	var guard := 0
	while not g.over and guard < 2000:
		guard += 1
		main._on_action("dormir")
		await process_frame
		if not g.pending_event.is_empty():
			await process_frame
			main._choose(g.pending_event["opciones"].size() - 1)
	print("SMOKE fin: día %d, over=%s, gasto total %d" % [g.day, g.over, g.total_money])
	await create_timer(2.5).timeout   # deja correr el fundido y la pantalla final
	print("SMOKE pantalla final: ", main.modal != null and main.modal.is_inside_tree())
	quit()
