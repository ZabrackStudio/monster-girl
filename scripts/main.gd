## Pantalla principal. Toda la interfaz se construye en código para que el
## prototipo no dependa del editor; la lógica vive en game.gd.
extends Control

const Game := preload("res://scripts/game.gd")
const Portrait := preload("res://scripts/portrait.gd")
const Music := preload("res://scripts/music.gd")
const Fade := preload("res://scripts/transicion.gd")
const EndingScene := preload("res://scripts/final_escena.gd")
const Progress := preload("res://scripts/progreso.gd")
const DevMode := preload("res://scripts/dev.gd")
const Shopkeeper := preload("res://scripts/shopkeeper.gd")
const MINIGAME_SCRIPTS := {
	"burbujas": preload("res://scripts/minigame_bubbles.gd"),
	"memoria": preload("res://scripts/minigame_memory.gd"),
}
const DEFAULT_CHARACTER := "slime"
const RECORDS_PATH := "user://records.json"
const BAR_STATS := ["salud", "felicidad", "tristeza", "hambre", "vinculo", "higiene"]
const STAT_COLORS := {"salud": "5fd38a", "felicidad": "f07ac0", "tristeza": "8a78f0",
	"hambre": "f0953c", "vinculo": "e85d8a", "higiene": "4fc3f0"}
const BG := Color("141a2a")
const PANEL := Color("1f2835")
const BORDER := Color("5b4a9e")
const TEXT_DIM := Color(1, 1, 1, 0.65)

var game
var bg: ColorRect
var lbl_top: Label
var lbl_level: Label
var level_pill: PanelContainer
var lust_bar: ProgressBar
var lbl_lust: Label
var name_lbl: Label
var lbl_moon: Label
var moon_pill: PanelContainer
var lbl_line: Label
var log_box: RichTextLabel
var portrait: Control
var stat_bars := {}
var action_buttons := {}
var modal: Control
var music
var btn_sound: Button
# Tienda
var shop: Dictionary
var shop_cat := ""
var shop_tabs := {}
var shop_list: VBoxContainer
var shop_money: Label
var shop_said: Label
var shop_keeper
var shop_bought := []
var transitions := true   # las pruebas automáticas las desactivan
var ending_scene: Control
var sleeping := false
var last_poke := -1000
var closing: Control
var closing_frame := -1
var held: Control         # ventana anterior, a la vista mientras se mide la nueva
var dev                   # modo desarrollo (scripts/dev.gd)
var btn_dev: Button


func _ready() -> void:
	game = Game.new()
	# Al continuar manda la partida guardada; si no, la asignada que se eligió en el menú.
	var saved = null
	if Engine.get_meta("continuar", false) and FileAccess.file_exists(Game.SAVE_PATH):
		saved = Game.load_json(Game.SAVE_PATH)
		if saved is Dictionary and saved.has("personaje"):
			Engine.set_meta("personaje", saved["personaje"])
	var cid: String = Engine.get_meta("personaje", DEFAULT_CHARACTER)
	if not FileAccess.file_exists("res://data/personajes/%s.json" % cid):
		cid = DEFAULT_CHARACTER
	game.setup("res://data/personajes/%s.json" % cid)
	# La música vive en un autoload para no cortarse entre pantallas;
	# si no existe (pruebas con -s), se crea aquí.
	music = get_node_or_null("/root/Musica")
	if music == null:
		music = Music.new()
		add_child(music)
	dev = DevMode.new(self)
	add_child(dev)
	_build_ui()
	refresh_dev()
	music.play(lobby_track())
	game.changed.connect(_refresh)
	game.changed.connect(_autosave)
	game.log_message.connect(func(t): log_box.append_text(t + "\n"))
	game.event_triggered.connect(_show_event)
	game.game_over.connect(_show_game_over)
	var loaded := false
	if Engine.get_meta("continuar", false):
		Engine.set_meta("continuar", false)
		loaded = saved is Dictionary and game.from_dict(saved)
	if not loaded:
		game.start(Progress.funds_for(game.character["id"]))
	_refresh()
	if loaded and not game.pending_event.is_empty():
		_show_event(game.pending_event)


## Muestra u oculta el botón del modo desarrollo.
## Cada chica tiene su propia música de casa; si falta, suena la de Reme.
func lobby_track() -> String:
	var own: String = "lobby_" + game.character["id"]
	for ext in ["mp3", "ogg", "wav"]:
		if ResourceLoader.exists("res://audio/%s.%s" % [own, ext]):
			return own
	return "lobby_slime"


func refresh_dev() -> void:
	btn_dev.visible = DevMode.active()


## Guarda tras cada cambio; al terminar la partida, la borra.
func _autosave() -> void:
	if game.over:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
		return
	var f := FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(game.to_dict()))


func _to_menu() -> void:
	_autosave()
	Fade.go(get_tree(), "res://scenes/menu.tscn")


func _show_pause() -> void:
	var v := _open_modal("Pausa")
	v.add_child(_button("Seguir jugando", _close_modal))
	var snd := _button(_sound_label(), func(): pass)
	snd.pressed.connect(func():
		music.toggle_mute()
		snd.text = _sound_label())
	v.add_child(snd)
	v.add_child(_volume_row())
	v.add_child(_button("Volver al menú principal", _to_menu))


# ================================================================ construcción

func _build_ui() -> void:
	bg = ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	# Barra superior con botón de sonido
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	root.add_child(top_row)
	var top := _pill(Color("1b2236"), BORDER)
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(top)
	lbl_top = _label("", 24)
	lbl_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(lbl_top)
	top.mouse_filter = Control.MOUSE_FILTER_STOP
	top.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			dev.tap())
	btn_dev = Button.new()
	btn_dev.text = "DEV"
	btn_dev.add_theme_font_size_override("font_size", 18)
	btn_dev.add_theme_color_override("font_color", Color("f2c14e"))
	btn_dev.pressed.connect(func(): dev.open())
	top_row.add_child(btn_dev)
	btn_sound = Button.new()
	btn_sound.add_theme_font_size_override("font_size", 20)
	btn_sound.custom_minimum_size = Vector2(120, 0)
	btn_sound.text = "Menú"
	btn_sound.pressed.connect(_show_pause)
	top_row.add_child(btn_sound)

	# Retrato con fondo y elementos superpuestos
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 380)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.size_flags_stretch_ratio = 3.0
	root.add_child(stage)
	portrait = Portrait.new()
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(portrait)
	portrait.setup(game.character["id"], Color(game.character["color"]))
	portrait.gui_input.connect(_on_portrait_input)
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fsb := StyleBoxFlat.new()
	fsb.draw_center = false
	fsb.border_color = BORDER
	fsb.set_border_width_all(3)
	fsb.set_corner_radius_all(18)
	frame.add_theme_stylebox_override("panel", fsb)
	stage.add_child(frame)

	var over := MarginContainer.new()
	over.set_anchors_preset(Control.PRESET_FULL_RECT)
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		over.add_theme_constant_override("margin_" + side, 12)
	stage.add_child(over)
	var ov := VBoxContainer.new()
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(ov)
	var pills := HBoxContainer.new()
	ov.add_child(pills)
	var name_pill := _pill(Color(0.17, 0.12, 0.3, 0.88), Color("a88bf0"))
	name_lbl = _label("", 26)
	name_pill.add_child(name_lbl)
	pills.add_child(name_pill)
	pills.add_theme_constant_override("separation", 8)
	moon_pill = _pill(Color(0.1, 0.1, 0.22, 0.88), Color("8fa3d9"))
	lbl_moon = _label("", 20)
	moon_pill.add_child(lbl_moon)
	pills.add_child(moon_pill)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pills.add_child(spacer)
	level_pill = _pill(Color("f5c842"), Color("ffe08a"))
	lbl_level = _label("", 24)
	lbl_level.add_theme_color_override("font_color", Color("2a1d3d"))
	level_pill.add_child(lbl_level)
	pills.add_child(level_pill)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(gap)
	var lust_pill := _pill(Color(0.1, 0.08, 0.2, 0.9), BORDER)
	ov.add_child(lust_pill)
	var lust_row := HBoxContainer.new()
	lust_row.add_theme_constant_override("separation", 10)
	lust_pill.add_child(lust_row)
	var drop := TextureRect.new()
	drop.texture = load(game.character.get("icono_lujuria", "res://ui/gota.png"))
	drop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drop.custom_minimum_size = Vector2(44, 40)
	lust_row.add_child(drop)
	lust_row.add_child(_label("Lujuria", 24))
	lust_bar = _bar(Color("d9434f"), 22)
	lust_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lust_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lust_row.add_child(lust_bar)
	lbl_lust = _label("", 24)
	lbl_lust.custom_minimum_size = Vector2(64, 0)
	lbl_lust.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lust_row.add_child(lbl_lust)

	# Bocadillo de diálogo
	var bubble := PanelContainer.new()
	var bsb := StyleBoxTexture.new()
	bsb.texture = load("res://ui/bocadillo.png")
	bsb.texture_margin_left = 34
	bsb.texture_margin_right = 34
	bsb.texture_margin_top = 34
	bsb.texture_margin_bottom = 22
	bsb.content_margin_left = 30
	bsb.content_margin_right = 30
	bsb.content_margin_top = 30
	bsb.content_margin_bottom = 16
	bubble.add_theme_stylebox_override("panel", bsb)
	root.add_child(bubble)
	lbl_line = _label("", 21)
	lbl_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.add_child(lbl_line)

	# Estadísticas
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	root.add_child(grid)
	for s in BAR_STATS:
		var cell := _pill(Color("1b2236"), Color("343d5e"))
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		cell.add_child(row)
		var l := _label("Vínculo" if s == "vinculo" else Game.STAT_NAMES[s], 19)
		l.custom_minimum_size = Vector2(92, 0)
		row.add_child(l)
		var bar := _bar(Color(STAT_COLORS[s]), 14)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		grid.add_child(cell)
		stat_bars[s] = bar

	# Registro dentro del marco del kit
	var log_panel := PanelContainer.new()
	var lsb := StyleBoxTexture.new()
	lsb.texture = load("res://ui/marco.png")
	lsb.set_texture_margin_all(30)
	lsb.set_content_margin_all(22)
	log_panel.add_theme_stylebox_override("panel", lsb)
	log_panel.custom_minimum_size = Vector2(0, 96)
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(log_panel)
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.add_theme_font_size_override("normal_font_size", 18)
	log_box.add_theme_font_size_override("bold_font_size", 18)
	log_panel.add_child(log_box)

	# Acciones con los iconos del kit
	var actions := GridContainer.new()
	actions.columns = 4
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 6)
	root.add_child(actions)
	var defs := [
		["trabajar", "Trabajar"], ["comer", "Comer"], ["pasear", "Pasear"], ["jugar", "Jugar"],
		["limpiar", "Limpiar"], ["tienda", "Tienda"], ["objetos", "Objetos"], ["dormir", "Dormir"],
	]
	for d in defs:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 138)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.icon = load("res://ui/btn_%s.png" % d[0])
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_constant_override("h_separation", 2)
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.3))
		b.add_theme_color_override("icon_pressed_color", Color(0.8, 0.8, 0.9))
		b.add_theme_color_override("icon_hover_color", Color(1.1, 1.1, 1.1))
		b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
		b.pressed.connect(_on_action.bind(d[0]))
		actions.add_child(b)
		action_buttons[d[0]] = [b, d[1]]


func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	return l


func _panel(color: Color = PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	return p


## Panel en forma de píldora con borde de color.
func _pill(color: Color, border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	return p


func _bar(color: Color, height := 16) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 100
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(height / 2)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.08)
	back.border_color = Color(1, 1, 1, 0.15)
	back.set_border_width_all(1)
	back.set_corner_radius_all(height / 2)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	return bar


# ================================================================ refresco

func _refresh() -> void:
	var info: Dictionary = game.level_info()
	var lv_color := Color(info["color"])
	var day_text := "Día %d/%d" % [mini(game.day, game.term), game.term] if game.term > 0 else "Día %d" % game.day
	lbl_top.text = "%s   ·   Acciones: %d/%d   ·   %d $" % [
		day_text, game.actions_left, int(game.balance["acciones_por_dia"]), game.money]
	lbl_level.text = info["nombre"]
	name_lbl.text = "%s · %s" % [game.character["nombre"], game.attitude()["nombre"]]
	var psb := level_pill.get_theme_stylebox("panel") as StyleBoxFlat
	psb.bg_color = lv_color
	psb.border_color = lv_color.lightened(0.35)
	lbl_level.add_theme_color_override("font_color", Color("1d1530") if game.level() < 3 else Color.WHITE)
	lust_bar.value = game.stats["lujuria"]
	lbl_lust.text = "%d%%" % roundi(game.stats["lujuria"])
	if game.curse_mark > 0:
		lbl_lust.text += "  (mín. %d)" % roundi(game.curse_mark)
	var moon: int = game.moon_in()
	lbl_moon.text = "Luna llena: ¡esta noche!" if moon == 0 else "Luna llena en %d d" % moon
	var msb := moon_pill.get_theme_stylebox("panel") as StyleBoxFlat
	msb.border_color = Color("ef7d86") if moon <= 1 else Color("8fa3d9")
	(lust_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = lv_color
	for s in BAR_STATS:
		if s == "vinculo":
			# En negativo, la barra se llena en rojo hacia la denuncia.
			var negative: bool = game.bond < 0
			stat_bars[s].max_value = -float(game.balance["vinculo"]["molestia"]["denuncia"]) if negative else game.bond_goal()
			stat_bars[s].value = absf(game.bond)
			(stat_bars[s].get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color("d9434f") if negative else Color(STAT_COLORS[s])
		else:
			stat_bars[s].value = game.stats[s]
	lbl_line.text = "«%s»" % game.current_line if game.current_line != "" else ""
	bg.color = BG.lerp(Color("3a1424"), game.level() * 0.18)
	portrait.set_state(game.mood(), game.level(), game.outfit)

	for id in action_buttons:
		var b: Button = action_buttons[id][0]
		var label: String = action_buttons[id][1]
		match id:
			"tienda", "dormir":
				b.text = label
				b.disabled = game.over
			"objetos":
				var n := 0
				for k in game.inventory:
					n += game.inventory[k]
				b.text = "%s (%d)" % [label, n] if n > 0 else label
				b.disabled = game.over
			_:
				b.text = label
				b.disabled = not game.can_do(id)
				b.tooltip_text = game.why_not(id)


# ================================================================ acciones

func _on_action(id: String) -> void:
	match id:
		"tienda": _show_shop()
		"objetos": _show_inventory()
		"jugar": _show_minigame_select()
		"dormir": _night()
		_: game.do_activity(id)


# ================================================================ ventanas

func _open_modal(title: String, dim := 0.65) -> VBoxContainer:
	# La ventana anterior sigue a la vista hasta que la nueva esté medida.
	var just_closed: bool = closing_frame == Engine.get_process_frames() and is_instance_valid(closing)
	if is_instance_valid(held):
		if modal:
			modal.queue_free()
	elif modal:
		held = modal
	elif just_closed:
		held = closing
	modal = null
	if not game.over:
		music.play(lobby_track())
	modal = ColorRect.new()
	modal.color = Color(0, 0, 0, dim)
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.modulate.a = 0.0
	add_child(modal)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 60)
	modal.add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	var panel := _panel(Color("232d3c"))
	panel.custom_minimum_size = Vector2(minf(size.x - 48, 660), 0)
	center.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, minf(size.y - 160, 1000))
	panel.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 12)
	scroll.add_child(v)
	if title != "":
		v.add_child(_label(title, 30))
	_fit_scroll.call_deferred(modal, scroll, v, scroll.custom_minimum_size.y)
	return v


## La ventana se ajusta a su contenido, con el alto máximo como tope, y solo entonces se muestra.
func _fit_scroll(window: Control, scroll: ScrollContainer, v: Control, max_h: float) -> void:
	# Espera a que se distribuya: los textos con ajuste de línea se miden con su ancho real.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(window) or window != modal:
		return
	scroll.custom_minimum_size.y = minf(v.get_combined_minimum_size().y, max_h)
	await get_tree().process_frame
	if not is_instance_valid(window) or window != modal:
		return
	if is_instance_valid(held):
		held.queue_free()
		held = null
		window.modulate.a = 1.0
	elif transitions:
		create_tween().tween_property(window, "modulate:a", 1.0, 0.18)
	else:
		window.modulate.a = 1.0


func _close_modal() -> void:
	if is_instance_valid(held):
		_fade_out(held)
		held = null
	if modal:
		var old := modal
		modal = null
		closing = old
		closing_frame = Engine.get_process_frames()
		_fade_out(old)
	if not game.over:
		music.play(lobby_track())


## Tocar a la chica: la charla del día o, si ya hablasteis, solo una frase.
func _on_portrait_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if modal != null or sleeping or game.over or not game.pending_event.is_empty() or not portrait.hit(event.position):
		return
	# Un toque real cada cuarto de segundo: un doble contacto no cuenta como dos.
	var now := Time.get_ticks_msec()
	if now - last_poke < 250:
		return
	last_poke = now
	portrait.poke()
	if game.can_talk():
		_show_talk(game.touch_line())
	else:
		game.poke()


func _show_talk(line: String) -> void:
	var v := _open_modal("")
	v.add_child(_talk_tag())
	v.add_child(_wrap("«%s»" % line, 24))
	var opts: Dictionary = game.character["charla"]["opciones"]
	for id in opts:
		v.add_child(_button(opts[id], _talk_reply.bind(id)))


func _talk_tag() -> Label:
	var tag := _label("%s · %s" % [game.character["nombre"], game.attitude()["nombre"]], 20)
	tag.add_theme_color_override("font_color", Color("f5a8d8"))
	return tag


func _talk_reply(id: String) -> void:
	var answer: String = game.talk(id)
	if game.over:
		return
	var v := _open_modal("")
	v.add_child(_talk_tag())
	v.add_child(_wrap("«%s»" % answer, 24))
	v.add_child(_button("Seguir", _close_modal))


## Las ventanas aparecen y desaparecen con un fundido corto.
func _fade_in(c: CanvasItem, dur := 0.18, force := false) -> void:
	if not transitions:
		return
	# Si sustituye a otra ventana en el mismo instante (p. ej. al refrescarla), cambio directo.
	if not force and closing_frame == Engine.get_process_frames():
		if is_instance_valid(closing):
			closing.queue_free()
		return
	c.modulate.a = 0.0
	create_tween().tween_property(c, "modulate:a", 1.0, dur)


func _fade_out(c: Control, dur := 0.15) -> void:
	if not transitions:
		c.queue_free()
		return
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(c, "modulate:a", 0.0, dur)
	tw.tween_callback(c.queue_free)


## Paso de la noche: fundido a oscuro, el día cambia a escondidas y vuelve la luz.
func _night() -> void:
	if not transitions:
		game.sleep()
		return
	if sleeping or game.over or not game.pending_event.is_empty():
		return
	sleeping = true
	var shade := ColorRect.new()
	shade.color = Color("05060c")
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.modulate.a = 0.0
	add_child(shade)
	var lbl := _label("Día %d" % (game.day + 1), 44)
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.modulate.a = 0.0
	shade.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(shade, "modulate:a", 1.0, 0.45)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.3)
	await tw.finished
	game.sleep()
	await get_tree().create_timer(0.6).timeout
	tw = create_tween()
	tw.tween_property(shade, "modulate:a", 0.0, 2.0 if game.over else 0.6)
	tw.tween_callback(shade.queue_free)
	sleeping = false


func _sound_label() -> String:
	return "Sonido: no" if music.muted else "Sonido: sí"


func _button(text: String, cb: Callable, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_size_override("font_size", 20)
	b.disabled = disabled
	b.pressed.connect(cb)
	return b


func _wrap(text: String, font_size := 20) -> Label:
	var l := _label(text, font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Tienda: escena fija con la intendente arriba y una ventana con pestañas abajo.
func _show_shop() -> void:
	shop = Game.load_json("res://data/tienda.json")
	shop_bought = []
	_close_modal()
	music.play("tienda")
	modal = Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.clip_contents = true
	add_child(modal)
	_fade_in(modal)
	var scene_h := size.y * 0.47
	modal.add_child(_shop_backdrop(1.0))
	shop_keeper = Shopkeeper.new()
	modal.add_child(shop_keeper)
	shop_keeper.fit(scene_h * 1.12)
	shop_keeper.position = Vector2(size.x * 0.02, scene_h * 0.02)
	# Bocadillo.
	var talk := _pill(Color(0.08, 0.09, 0.07, 0.9), Color("8a8f5a"))
	talk.position = Vector2(size.x * 0.47, scene_h * 0.06)
	var tv := VBoxContainer.new()
	talk.add_child(tv)
	var who := _label(shop["nombre"], 18)
	who.add_theme_color_override("font_color", Color("d6c46a"))
	tv.add_child(who)
	shop_said = _wrap("«%s»" % game._pick(shop["saludo"]), 20)
	shop_said.custom_minimum_size = Vector2(size.x * 0.5 - 40, 0)
	tv.add_child(shop_said)
	modal.add_child(talk)
	# Ventana de artículos.
	var panel := _panel(Color(0.09, 0.1, 0.12, 0.96))
	panel.position = Vector2(12, scene_h)
	panel.size = Vector2(size.x - 24, size.y - scene_h - 12)
	modal.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := _label("Tienda", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	shop_money = _label("", 26)
	shop_money.add_theme_color_override("font_color", Color("f5c842"))
	head.add_child(shop_money)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	col.add_child(tabs)
	shop_tabs.clear()
	for id in game.item_order:
		var cat: String = game.items[id]["categoria"]
		if shop_tabs.has(cat):
			continue
		var b := Button.new()
		b.text = shop["pestanas"].get(cat, cat)
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 54)
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(_shop_tab.bind(cat))
		tabs.add_child(b)
		shop_tabs[cat] = b
	if not shop_tabs.has(shop_cat):
		shop_cat = shop_tabs.keys()[0]
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	shop_list = VBoxContainer.new()
	shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_list.add_theme_constant_override("separation", 12)
	scroll.add_child(shop_list)
	col.add_child(_button("Salir de la tienda", _leave_shop))
	_fill_shop()


func _shop_backdrop(light: float) -> TextureRect:
	var bgt := TextureRect.new()
	bgt.texture = load("res://ui/tienda_fondo.png")
	bgt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bgt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bgt.set_anchors_preset(Control.PRESET_FULL_RECT)
	bgt.modulate = Color(light, light, light)
	return bgt


func _shop_tab(cat: String) -> void:
	shop_cat = cat
	_fill_shop()


func _fill_shop() -> void:
	shop_money.text = "%d $" % game.money
	for cat in shop_tabs:
		shop_tabs[cat].set_pressed_no_signal(cat == shop_cat)
	for c in shop_list.get_children():
		c.queue_free()
	for id in game.item_order:
		var it: Dictionary = game.items[id]
		if it["categoria"] != shop_cat:
			continue
		var row := HBoxContainer.new()
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var owned := ""
		if it["tipo"] == "consumible" and game.inventory.get(id, 0) > 0:
			owned = "  (tienes %d)" % game.inventory[id]
		info.add_child(_label(it["nombre"] + owned, 22))
		var d := _wrap(game.item_text(id), 17)
		d.modulate = TEXT_DIM
		info.add_child(d)
		row.add_child(info)
		var can: bool = game.can_buy(id)
		var b := _button("%d $" % int(it["precio"]) if can else "Comprado",
			_buy.bind(id), not can or game.money < int(it["precio"]))
		b.custom_minimum_size = Vector2(130, 64)
		row.add_child(b)
		shop_list.add_child(row)


func _buy(id: String) -> void:
	if game.buy(id):
		shop_bought.append(id)
		shop_said.text = "«%s»" % game._pick(shop["compra"])
		shop_keeper.react()
	else:
		shop_said.text = "«%s»" % game._pick(shop["sin_dinero"])
	_fill_shop()


## Al salir, la intendente comenta la compra mientras "vuelves a casa".
func _leave_shop() -> void:
	var lines := []
	var seen := []
	for i in range(shop_bought.size() - 1, -1, -1):
		var id: String = shop_bought[i]
		var comments: Dictionary = shop["comentarios"].duplicate()
		comments.merge(shop.get("comentarios_personaje", {}).get(game.character["id"], {}), true)
		if id in seen or not comments.has(id):
			continue
		seen.append(id)
		lines.append(comments[id])
		if lines.size() == 2:
			break
	if lines.is_empty():
		lines.append(game._pick(shop["sin_compra"]))
	lines.append(game._pick(shop["cierre"]))
	_close_modal()
	modal = Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal)
	_fade_in(modal, 0.4, true)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(black)
	modal.add_child(_shop_backdrop(0.35))
	var keeper := Shopkeeper.new()
	modal.add_child(keeper)
	keeper.fit(size.y * 0.78)
	keeper.position = Vector2(size.x * 0.5 - keeper.size.x * 0.5, size.y * 0.02)
	var box := _panel(Color(0.07, 0.08, 0.07, 0.94))
	box.position = Vector2(24, size.y * 0.62)
	box.size = Vector2(size.x - 48, 0)
	modal.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	var who := _label(shop["nombre"], 20)
	who.add_theme_color_override("font_color", Color("d6c46a"))
	v.add_child(who)
	for l in lines:
		v.add_child(_wrap("«%s»" % l, 22))
	var hint := _label("Toca para volver a casa", 18)
	hint.modulate = TEXT_DIM
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.visible = false
	v.add_child(hint)
	var screen := modal
	# Se queda hasta que toques; un instante de margen para no cerrarla sin querer.
	await get_tree().create_timer(0.7).timeout
	if modal == screen:
		hint.visible = true
		screen.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and modal == screen:
				_close_modal())


func _show_inventory() -> void:
	var v := _open_modal("Objetos y diario")
	music.play("tienda")
	if game.inventory.is_empty():
		v.add_child(_wrap("No tienes objetos."))
	for id in game.inventory:
		var it: Dictionary = game.items[id]
		var row := HBoxContainer.new()
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(_label("%s ×%d" % [it["nombre"], game.inventory[id]], 22))
		var d := _wrap(game.item_text(id), 17)
		d.modulate = TEXT_DIM
		info.add_child(d)
		row.add_child(info)
		var b := _button("Usar", _use.bind(id), not game.pending_event.is_empty())
		b.custom_minimum_size = Vector2(110, 64)
		row.add_child(b)
		v.add_child(row)
	if not game.passives.is_empty():
		var names := []
		for id in game.passives:
			names.append(game.items[id]["nombre"])
		var p := _wrap("En casa: " + ", ".join(names), 18)
		p.modulate = TEXT_DIM
		v.add_child(p)
	_add_wardrobe(v)
	_add_diary(v)
	v.add_child(_button("Cerrar", _close_modal))


func _add_wardrobe(v: VBoxContainer) -> void:
	if game.outfits.size() < 2:
		return
	v.add_child(HSeparator.new())
	v.add_child(_label("Vestuario", 24))
	var names: Dictionary = game.character.get("trajes", {})
	for t in game.outfits:
		var row := HBoxContainer.new()
		var l := _label(names.get(t, t), 20)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var worn: bool = t == game.outfit
		var b := _button("Puesto" if worn else "Vestir", _wear.bind(t), worn)
		b.custom_minimum_size = Vector2(130, 56)
		row.add_child(b)
		v.add_child(row)


func _wear(t: String) -> void:
	game.wear(t)
	_show_inventory()


## Lo que el jugador ha aprendido de las reacciones de su compañera.
func _add_diary(v: VBoxContainer) -> void:
	v.add_child(HSeparator.new())
	v.add_child(_label("Diario de %s" % game.character["nombre"], 24))
	for r in game.character.get("reacciones", []):
		if not game.discovered.has(r["id"]):
			continue
		var trap: bool = float(r["efectos"].get("lujuria", 0)) > 0
		var l := _wrap(r["nota"], 18)
		l.add_theme_color_override("font_color", Color("f2a65a") if trap else Color("9fd8ff"))
		v.add_child(l)
	for key in game.character["charla"]["notas"]:
		if game.discovered.has("charla_" + key):
			var note := _wrap(game.character["charla"]["notas"][key], 18)
			note.add_theme_color_override("font_color", Color("f5a8d8"))
			v.add_child(note)


func _show_minigame_select() -> void:
	var v := _open_modal("¿A qué jugamos?")
	for id in game.minigames:
		var mg: Dictionary = game.balance["minijuegos"][id]
		v.add_child(_button(mg["nombre"], _start_minigame.bind(id)))
	v.add_child(_button("Cancelar", _close_modal))


func _start_minigame(id: String) -> void:
	var v := _open_modal(game.balance["minijuegos"][id]["nombre"], 0.85)
	var mg: Control = MINIGAME_SCRIPTS[id].new()
	# Cabe justo en la ventana: alto de la zona con scroll menos el título.
	mg.custom_minimum_size = Vector2(0, minf(size.y - 160, 1000) - 64)
	mg.clip_contents = true
	mg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(mg)
	mg.finished.connect(_on_minigame_done.bind(id))


func _show_event(ev: Dictionary) -> void:
	# Se difiere un frame: el evento puede llegar mientras se cierra otra ventana.
	await get_tree().process_frame
	var v := _open_modal("")
	var tag := _label(_event_tag(ev["tipo"]), 18)
	tag.modulate = TEXT_DIM
	v.add_child(tag)
	v.add_child(_wrap(ev["texto"], 22))
	for i in ev["opciones"].size():
		var opt: Dictionary = ev["opciones"][i]
		var b := _button(opt["texto"], _choose.bind(i), not game.option_available(opt))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(b)


func _use(id: String) -> void:
	game.use_item(id)
	if not game.over:
		_show_inventory()


func _on_minigame_done(score: float, id: String) -> void:
	_close_modal()
	game.play_minigame(id, score)


func _choose(i: int) -> void:
	_close_modal()
	game.resolve_event(i)


func _event_tag(kind: String) -> String:
	match kind:
		"positivo": return "Algo bueno"
		"negativo": return "Un contratiempo"
		"especie": return game.character.get("etiqueta_especie", "Cosas de " + game.character["especie"].to_lower())
		"critico": return "¡Situación crítica!"
	return "Mientras tanto…"


func _show_game_over(ending: Dictionary) -> void:
	await get_tree().process_frame
	_close_modal()
	music.play(ending.get("musica", "final_poseida"))
	var record := _save_record(ending)
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fade)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 1.8)
	await tw.finished
	ending_scene = EndingScene.new(ending)
	add_child(ending_scene)
	fade.queue_free()
	await ending_scene.finished
	var v := _open_modal(ending["titulo"], 0.45)
	if ending.has("nota"):
		_evaluation_results(v, ending)
		return
	v.add_child(_label("Días sobrevividos: %d de %d" % [mini(ending["dias"], game.term), game.term] if game.term > 0 else "Días sobrevividos: %d" % ending["dias"], 24))
	v.add_child(_label("Actitud final: %s" % ending["actitud"], 20))
	var rec := _label("Récord con %s: %d días%s" % [game.character["nombre"], record["mejor_dias"],
		"  ¡Nuevo récord!" if record["nuevo"] else ""], 20)
	rec.modulate = TEXT_DIM
	v.add_child(rec)
	var finals := _label("Finales descubiertos: %d/%d" % [record["finales"].size(), game.character["finales"].size() + 1], 20)
	finals.modulate = TEXT_DIM
	v.add_child(finals)
	v.add_child(_button("Repetir la asignación", func(): Fade.go(get_tree())))
	v.add_child(_button("Menú principal", _to_menu))


## Resultados de la evaluación del día final: nota, actitud y, si aprobó, la siguiente asignada.
func _evaluation_results(v: VBoxContainer, ending: Dictionary) -> void:
	Progress.record_grade(game.character["id"], ending["nota"])
	var grade := _label("Calificación: %s · %s" % [ending["nota"], game.grade_for(ending["puntaje"])["nombre"]], 26)
	grade.add_theme_color_override("font_color", Color("9fe0a8") if ending["aprobada"] else Color("ef7d86"))
	v.add_child(grade)
	v.add_child(_label("Actitud final: %s" % ending["actitud"], 20))
	var funds: int = int(game.grade_for(ending["puntaje"]).get("fondos", 0))
	var nxt := Progress.next_index(game.character["id"])
	if ending["aprobada"] and nxt >= 0:
		var next_id: String = Progress.project()["expedientes"][nxt]["personaje"]
		var line := "Siguiente asignada: %s" % Progress.character_name(next_id)
		if funds > 0:
			line += "\nFondos extra para la próxima asignación: %d $" % funds
		var l := _wrap(line, 20)
		l.modulate = TEXT_DIM
		v.add_child(l)
		v.add_child(_button("Siguiente expediente", func():
			Engine.set_meta("personaje", next_id)
			Engine.set_meta("intro_personaje", next_id)
			Fade.go(get_tree(), "res://scenes/intro.tscn")))
	elif ending["aprobada"]:
		var l := _wrap("No hay más asignadas por ahora. El proyecto sigue en desarrollo.", 20)
		l.modulate = TEXT_DIM
		v.add_child(l)
	v.add_child(_button("Repetir la asignación", func(): Fade.go(get_tree())))
	v.add_child(_button("Menú principal", _to_menu))


func _save_record(ending: Dictionary) -> Dictionary:
	var data := {}
	if FileAccess.file_exists(RECORDS_PATH):
		var parsed = Game.load_json(RECORDS_PATH)
		if parsed is Dictionary:
			data = parsed
	var cid: String = game.character["id"]
	var r: Dictionary = data.get(cid, {"mejor_dias": 0, "finales": [], "dinero_total": 0, "partidas": 0})
	var nuevo: bool = ending["dias"] > int(r["mejor_dias"])
	r["mejor_dias"] = maxi(int(r["mejor_dias"]), ending["dias"])
	if not ending["tipo"] in r["finales"]:
		r["finales"].append(ending["tipo"])
	r["dinero_total"] = int(r["dinero_total"]) + game.total_money
	r["partidas"] = int(r["partidas"]) + 1
	data[cid] = r
	var f := FileAccess.open(RECORDS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
	var out := r.duplicate()
	out["nuevo"] = nuevo
	return out

## Fila de volumen: deslizador 0-100 % que se guarda al soltarlo.
func _volume_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := _label("Volumen", 20)
	row.add_child(l)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = roundi(music.volume * 100)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(0, 48)
	# Pista gruesa y de color, más fácil de ver y de tocar en el móvil.
	var track := StyleBoxFlat.new()
	track.bg_color = Color("343d5e")
	track.set_corner_radius_all(6)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	slider.add_theme_stylebox_override("slider", track)
	var fill := track.duplicate()
	fill.bg_color = Color("f07ac0")
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	row.add_child(slider)
	var pct := _label("%d%%" % slider.value, 20)
	pct.custom_minimum_size = Vector2(64, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(pct)
	slider.value_changed.connect(func(v):
		pct.text = "%d%%" % v
		music.set_volume(v / 100.0))
	return row
