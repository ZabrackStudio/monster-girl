## Modo de desarrollo: ver los números ocultos, ajustar el estado, lanzar eventos y finales
## y saltar días sin jugar la partida entera.
##
## Se activa escribiendo la palabra clave con el teclado durante la partida, o tocando 7 veces
## seguidas la barra de arriba y escribiéndola. La palabra no está en el código: solo su huella
## SHA-256. Para cambiarla, calcula la nueva con:  printf '%s' palabra | sha256sum
## (solo letras y números, en minúsculas) y pégala en KEY_HASH.
## Ojo: en una versión web todo el juego está en el navegador. Esto lo esconde de miradas
## casuales, pero alguien decidido podría saltárselo. No guardes nada sensible detrás.
extends Node

const KEY_HASH := "2fff54867d9ff15a62f13f20c03405e4b40491e9ee2888bc0d4334a1ed231a32"
const MAX_KEY := 24
const TAPS := 7
const Progress := preload("res://scripts/progreso.gd")
const Fade := preload("res://scripts/transicion.gd")
const Game := preload("res://scripts/game.gd")

var main
var typed := ""
var entry := ""
var taps: Array[int] = []


static func active() -> bool:
	return Engine.get_meta("dev", false)


static func matches(word: String) -> bool:
	return word.strip_edges().to_lower().sha256_text() == KEY_HASH


func _init(owner_main) -> void:
	main = owner_main


## Escucha el teclado: compara la huella de cada final de lo escrito con la de la clave.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var ch := char(event.unicode).to_lower()
	if ch.length() != 1 or not (ch.is_valid_identifier() or ch.is_valid_int()):
		return
	typed = (typed + ch).right(MAX_KEY)
	for n in range(3, typed.length() + 1):
		if matches(typed.right(n)):
			typed = ""
			_activate()
			return


## Toques seguidos sobre la barra de arriba (para el celular, que no tiene teclado).
func tap() -> void:
	var now := Time.get_ticks_msec()
	taps.append(now)
	taps = taps.filter(func(t): return now - t < 3000)
	if taps.size() >= TAPS:
		taps.clear()
		if active():
			open()
		else:
			_ask_key()


## Pide la clave con un teclado dibujado en pantalla: en la web del celular el teclado
## del sistema no le llega a Godot, y uno físico ya se escucha en _input.
func _ask_key() -> void:
	var v: VBoxContainer = main._open_modal("Clave")
	entry = ""
	var shown: Label = main._label("", 30)
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shown.custom_minimum_size = Vector2(0, 56)
	v.add_child(shown)
	var show := func(): shown.text = "•".repeat(entry.length()) if entry != "" else "—"
	show.call()
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for ch in "abcdefghijklmnopqrstuvwxyz0123456789":
		var b: Button = main._button(ch.to_upper(), func():
			entry = (entry + ch).right(MAX_KEY)
			show.call())
		b.custom_minimum_size = Vector2(0, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 22)
		grid.add_child(b)
	v.add_child(grid)
	v.add_child(_row([
		["Borrar", func():
			entry = entry.left(-1)
			show.call()],
		["Entrar", func():
			if matches(entry):
				_activate()
			else:
				main._close_modal()],
	]))
	v.add_child(main._button("Cancelar", main._close_modal))


func _activate() -> void:
	Engine.set_meta("dev", true)
	main.refresh_dev()
	open()


# ---------------------------------------------------------------- panel

func open() -> void:
	var g = main.game
	var v: VBoxContainer = main._open_modal("Modo desarrollo", 0.5)
	v.add_child(_section("Estado exacto"))
	v.add_child(main._wrap(_status(g), 17))

	v.add_child(_section("Ajustar"))
	for s in g.STATS:
		v.add_child(_slider(g.STAT_NAMES[s], 0, 100, g.stats[s], func(x): g.stats[s] = x))
	v.add_child(_slider("Vínculo", -25, 100, g.bond, func(x): g.bond = x))
	v.add_child(_slider("Marca de la maldición", 0, 60, g.curse_mark, func(x): g.curse_mark = x))
	v.add_child(_slider("Día", 1, maxi(g.term, 60), g.day, func(x): g.day = int(x)))
	v.add_child(_row([
		["+100 $", func(): g.money += 100; _apply()],
		["+1000 $", func(): g.money += 1000; _apply()],
		["Acciones al máximo", func(): g.actions_left = int(g.balance["acciones_por_dia"]); _apply()],
	]))

	v.add_child(_section("Saltar"))
	v.add_child(_row([
		["1 noche", func(): _nights(1)],
		["5 noches", func(): _nights(5)],
		["Hasta el final del plazo", func(): _nights(999)],
	]))

	v.add_child(_section("Desbloquear"))
	v.add_child(_row([
		["Objetos ×3", _all_items],
		["Diario completo", _all_notes],
	]))
	v.add_child(_row([
		["Todos los expedientes", _all_assignments],
		["Borrar avance", func(): DirAccess.remove_absolute(ProjectSettings.globalize_path(Progress.PATH)); open()],
	]))

	v.add_child(_section("Eventos de %s" % g.character["nombre"]))
	var ev_box := GridContainer.new()
	ev_box.columns = 2
	for ev in g.events:
		var b: Button = main._button(ev["id"], _event.bind(ev))
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ev_box.add_child(b)
	v.add_child(ev_box)

	v.add_child(_section("Finales"))
	var fin_box := GridContainer.new()
	fin_box.columns = 2
	for kind in g.character["finales"]:
		var b: Button = main._button(g.character["finales"][kind]["titulo"].get_slice(": ", 1), _ending.bind(kind))
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fin_box.add_child(b)
	var ev_btn: Button = main._button("Evaluación ahora", _ending.bind("evaluacion"))
	ev_btn.custom_minimum_size = Vector2(0, 48)
	ev_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fin_box.add_child(ev_btn)
	v.add_child(fin_box)

	v.add_child(_section("Asignada (partida nueva)"))
	var ids := []
	for a in Progress.project()["expedientes"]:
		ids.append([Progress.character_name(a["personaje"]), _switch.bind(a["personaje"])])
	v.add_child(_row(ids))

	v.add_child(HSeparator.new())
	v.add_child(main._button("Cerrar", main._close_modal))
	v.add_child(main._button("Salir del modo desarrollo", func():
		Engine.set_meta("dev", false)
		main.refresh_dev()
		main._close_modal()))


func _status(g) -> String:
	var lines := []
	var nums := []
	for s in g.STATS:
		nums.append("%s %.0f" % [g.STAT_NAMES[s], g.stats[s]])
	lines.append(" · ".join(nums))
	lines.append("Vínculo %.1f (%s) · meta del final bueno %d" % [g.bond, g.attitude()["nombre"], g.bond_goal()])
	lines.append("Día %d de %d · %d acciones · %d $ · marca %.0f · crisis %d" % [
		g.day, g.term, g.actions_left, g.money, g.curse_mark, g.crises])
	# Cuánto subiría la lujuria esta noche (sin gastar el azar de la partida).
	var state: int = g.rng.state
	var tonight: float = g.lust_delta()
	g.rng.state = state
	lines.append("Lujuria esta noche: %+.1f (con azar)" % tonight)
	var ev: Dictionary = g.evaluation()
	lines.append("Si la evaluaran hoy: %d puntos, nota %s" % [ev["puntaje"], ev["nota"]["nota"]])
	if not g.stash.is_empty():
		var hidden := []
		for id in g.stash:
			hidden.append("%s ×%d" % [g.items[id]["nombre"], g.stash[id]])
		lines.append("Escondido por ella: " + ", ".join(hidden))
	var tol := []
	for k in g.tolerance:
		if g.tolerance[k] > 0.3:
			tol.append("%s %d%%" % [k, roundi(g.tolerance_factor(k) * 100)])
	if not tol.is_empty():
		lines.append("Rinden ahora: " + ", ".join(tol))
	return "\n".join(lines)


func _section(t: String) -> Label:
	var l: Label = main._label(t, 22)
	l.add_theme_color_override("font_color", Color("f2c14e"))
	return l


func _row(buttons: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for pair in buttons:
		var b: Button = main._button(pair[0], pair[1])
		b.custom_minimum_size = Vector2(0, 52)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 17)
		row.add_child(b)
	return row


func _slider(title: String, lo: float, hi: float, value: float, setter: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l: Label = main._label(title, 17)
	l.custom_minimum_size = Vector2(170, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(0, 40)
	row.add_child(s)
	var n: Label = main._label("%d" % value, 17)
	n.custom_minimum_size = Vector2(48, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(n)
	s.value_changed.connect(func(x):
		n.text = "%d" % x
		setter.call(x)
		main.game.changed.emit())
	return row


func _apply() -> void:
	main.game.changed.emit()
	open()


func _nights(n: int) -> void:
	var g = main.game
	main._close_modal()
	for i in n:
		if g.over or not g.pending_event.is_empty():
			break
		g.sleep()
		if g.term > 0 and g.day >= g.term and n == 999:
			break
	if not g.over and g.pending_event.is_empty():
		open()


func _event(ev: Dictionary) -> void:
	main._close_modal()
	main.game.pending_event = ev
	main.game.event_triggered.emit(ev)


func _ending(kind: String) -> void:
	main._close_modal()
	if kind == "evaluacion":
		main.game._evaluate()
	else:
		main.game._end(kind)


func _all_items() -> void:
	var g = main.game
	for id in g.item_order:
		var it: Dictionary = g.items[id]
		if it["tipo"] == "consumible":
			g.inventory[id] = g.inventory.get(id, 0) + 3
		elif g.can_buy(id):
			g.money += int(it["precio"])
			g.buy(id)
	_apply()


func _all_notes() -> void:
	var g = main.game
	for r in g.character.get("reacciones", []):
		g.discovered[r["id"]] = true
	for key in g.character["charla"]["notas"]:
		g.discovered["charla_" + key] = true
	_apply()


func _all_assignments() -> void:
	for a in Progress.project()["expedientes"]:
		Progress.record_grade(a["personaje"], "A")
	open()


func _switch(character_id: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	Engine.set_meta("personaje", character_id)
	Fade.go(main.get_tree(), "res://scenes/main.tscn")
