## Prueba del modo desarrollo: activación por teclado y por toques, y acciones del panel.
## La clave de prueba se pasa por variable de entorno para no dejarla escrita en el repositorio.
extends SceneTree

const DevMode := preload("res://scripts/dev.gd")
var fails := 0


func _init() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print("DEV ", "ok   " if ok else "FALLA ", what)
	if not ok:
		fails += 1


func _type(text: String) -> void:
	for c in text:
		var e := InputEventKey.new()
		e.pressed = true
		e.unicode = c.unicode_at(0)
		root.push_input(e)
		await process_frame


func _run() -> void:
	var key := OS.get_environment("DEV_KEY")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://partida.json"))
	Engine.set_meta("dev", false)
	var main = load("res://scenes/main.tscn").instantiate()
	main.transitions = false
	root.add_child(main)
	for i in 5: await process_frame
	_check(not main.btn_dev.visible, "El botón DEV empieza oculto")
	await _type("hola" + "x" + key.substr(0, key.length() - 1))
	_check(not DevMode.active(), "Una clave incompleta no activa nada")
	await _type(key)
	for i in 5: await process_frame
	_check(DevMode.active() and main.btn_dev.visible and main.modal != null, "Escribir la clave abre el panel")
	_check(not DevMode.matches("harem") and DevMode.matches(key.to_upper()), "Solo la clave correcta (sin importar mayúsculas)")
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/capturas/dev_panel.png"))
	var g = main.game
	g.stats["lujuria"] = 60.0
	main.dev._nights(3)
	_check(g.day >= 2, "Saltar noches avanza el día (día %d)" % g.day)
	main.dev._event(g.events[0])
	await process_frame
	_check(not g.pending_event.is_empty(), "Lanzar un evento lo deja pendiente")
	g.pending_event = {}
	main.dev._all_items()
	_check(g.inventory.size() > 2, "Desbloquear objetos llena el inventario")
	main._close_modal()
	# En el celular: 7 toques en la barra de arriba piden la clave.
	Engine.set_meta("dev", false)
	main.refresh_dev()
	for i in 7:
		main.dev.tap()
	await process_frame
	_check(main.modal != null and not DevMode.active(), "Siete toques piden la clave")
	main.dev._ending("evaluacion")
	for i in 5: await process_frame
	_check(g.over, "Lanzar la evaluación termina la partida")
	Engine.set_meta("dev", false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://partida.json"))
	print("DEV resultado: ", "todo ok" if fails == 0 else "%d fallas" % fails)
	quit()
