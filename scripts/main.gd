## Pantalla principal. Toda la interfaz se construye en código para que el
## prototipo no dependa del editor; la lógica vive en game.gd.
extends Control

const Game := preload("res://scripts/game.gd")
const Portrait := preload("res://scripts/portrait.gd")
const Music := preload("res://scripts/music.gd")
const MINIGAME_SCRIPTS := {
	"burbujas": preload("res://scripts/minigame_bubbles.gd"),
	"memoria": preload("res://scripts/minigame_memory.gd"),
}
const CHARACTER := "res://data/personajes/slime.json"
const RECORDS_PATH := "user://records.json"
const BAR_STATS := ["salud", "felicidad", "tristeza", "hambre", "energia", "higiene"]
const STAT_COLORS := {"salud": "5fd38a", "felicidad": "f07ac0", "tristeza": "8a78f0",
	"hambre": "f0953c", "energia": "f5c842", "higiene": "4fc3f0"}
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
var lbl_moon: Label
var moon_pill: PanelContainer
var lbl_line: Label
var log_box: RichTextLabel
var portrait: Control
var stat_bars := {}
var stat_values := {}
var action_buttons := {}
var modal: Control
var music
var btn_sound: Button


func _ready() -> void:
	game = Game.new()
	game.setup(CHARACTER)
	music = Music.new()
	add_child(music)
	_build_ui()
	music.play("lobby")
	game.changed.connect(_refresh)
	game.log_message.connect(func(t): log_box.append_text(t + "\n"))
	game.event_triggered.connect(_show_event)
	game.game_over.connect(_show_game_over)
	game.start()
	_refresh()


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
	btn_sound = Button.new()
	btn_sound.add_theme_font_size_override("font_size", 20)
	btn_sound.custom_minimum_size = Vector2(120, 0)
	btn_sound.text = _sound_label()
	btn_sound.pressed.connect(func():
		music.toggle_mute()
		btn_sound.text = _sound_label())
	top_row.add_child(btn_sound)

	# Retrato con fondo y elementos superpuestos
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 470)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.size_flags_stretch_ratio = 3.0
	root.add_child(stage)
	portrait = Portrait.new()
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(portrait)
	portrait.setup(game.character["id"], Color(game.character["color"]))
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
	var name_lbl := _label("%s · %s" % [game.character["nombre"], game.character["especie"]], 26)
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
	drop.texture = load("res://ui/gota.png")
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
	lbl_line = _label("", 23)
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
		var l := _label(Game.STAT_NAMES[s], 19)
		l.custom_minimum_size = Vector2(92, 0)
		row.add_child(l)
		var bar := _bar(Color(STAT_COLORS[s]), 14)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var v := _label("", 19)
		v.custom_minimum_size = Vector2(52, 0)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(v)
		grid.add_child(cell)
		stat_bars[s] = bar
		stat_values[s] = v

	# Registro dentro del marco del kit
	var log_panel := PanelContainer.new()
	var lsb := StyleBoxTexture.new()
	lsb.texture = load("res://ui/marco.png")
	lsb.set_texture_margin_all(30)
	lsb.set_content_margin_all(22)
	log_panel.add_theme_stylebox_override("panel", lsb)
	log_panel.custom_minimum_size = Vector2(0, 130)
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
		b.custom_minimum_size = Vector2(0, 150)
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
	lbl_top.text = "Día %d   ·   Acciones: %d/%d   ·   %d $" % [
		game.day, game.actions_left, int(game.balance["acciones_por_dia"]), game.money]
	lbl_level.text = info["nombre"]
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
		stat_bars[s].value = game.stats[s]
		stat_values[s].text = "%d%%" % roundi(game.stats[s])
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
				b.text = "%s (%d)" % [label, n]
				b.disabled = game.over
			_:
				var act: Dictionary = game.activity(id)
				b.text = "%s (%d)" % [label, int(act["costo"])]
				b.disabled = not game.can_do(id)
				b.tooltip_text = game.why_not(id)


# ================================================================ acciones

func _on_action(id: String) -> void:
	match id:
		"tienda": _show_shop()
		"objetos": _show_inventory()
		"jugar": _show_minigame_select()
		"dormir": game.sleep()
		_: game.do_activity(id)


# ================================================================ ventanas

func _open_modal(title: String, dim := 0.65) -> VBoxContainer:
	_close_modal()
	modal = ColorRect.new()
	modal.color = Color(0, 0, 0, dim)
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
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
	return v


func _close_modal() -> void:
	if modal:
		modal.queue_free()
		modal = null
	if not game.over:
		music.play("lobby")


func _tolerance_text(f: float) -> String:
	var txt := "Calma la maldición al %d%%" % roundi(f * 100)
	return txt + (" (se ha acostumbrado)" if f < 0.75 else "")


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


func _show_shop() -> void:
	var v := _open_modal("Tienda   (%d $)" % game.money)
	music.play("tienda")
	var last_cat := ""
	var order: Array = game.item_order.duplicate()
	var cats := []
	for id in order:
		if not game.items[id]["categoria"] in cats:
			cats.append(game.items[id]["categoria"])
	order.sort_custom(func(x, y): return cats.find(game.items[x]["categoria"]) < cats.find(game.items[y]["categoria"]))
	for id in order:
		var it: Dictionary = game.items[id]
		if it["categoria"] != last_cat:
			last_cat = it["categoria"]
			var c := _label(last_cat, 18)
			c.modulate = TEXT_DIM
			v.add_child(c)
		var row := HBoxContainer.new()
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var owned := ""
		if it["tipo"] == "consumible" and game.inventory.get(id, 0) > 0:
			owned = "  (tienes %d)" % game.inventory[id]
		info.add_child(_label(it["nombre"] + owned, 22))
		var d := _wrap(it["descripcion"], 17)
		d.modulate = TEXT_DIM
		info.add_child(d)
		row.add_child(info)
		var can: bool = game.can_buy(id)
		var b := _button("%d $" % int(it["precio"]) if can else "Comprado",
			_buy.bind(id), not can or game.money < int(it["precio"]))
		b.custom_minimum_size = Vector2(130, 64)
		row.add_child(b)
		v.add_child(row)
	v.add_child(_button("Cerrar", _close_modal))


func _show_inventory() -> void:
	var v := _open_modal("Objetos y diario")
	music.play("tienda")
	if game.inventory.is_empty():
		v.add_child(_wrap("No tienes objetos. Compra algo en la tienda."))
	for id in game.inventory:
		var it: Dictionary = game.items[id]
		var row := HBoxContainer.new()
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(_label("%s ×%d" % [it["nombre"], game.inventory[id]], 22))
		if float(it["efectos"].get("lujuria", 0)) < 0:
			var r := _label(_tolerance_text(game.tolerance_factor("objeto_" + id)), 17)
			r.modulate = TEXT_DIM
			info.add_child(r)
		var d := _wrap(it["descripcion"], 17)
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
	var known := 0
	for r in game.character.get("reacciones", []):
		if not game.discovered.has(r["id"]):
			continue
		known += 1
		var trap: bool = float(r["efectos"].get("lujuria", 0)) > 0
		var l := _wrap(r["nota"], 18)
		l.add_theme_color_override("font_color", Color("f2a65a") if trap else Color("9fd8ff"))
		v.add_child(l)
	var left: int = game.reactions_total() - known
	var hint := _wrap("Quedan %d reacciones por descubrir. Prueba a combinar actividades en distinto orden." % left
		if left > 0 else "Ya lo sabes todo de ella.", 17)
	hint.modulate = TEXT_DIM
	v.add_child(hint)


func _show_minigame_select() -> void:
	var v := _open_modal("¿A qué jugamos?")
	for id in game.minigames:
		var mg: Dictionary = game.balance["minijuegos"][id]
		var aff := "Afinidad: ?"
		if game.known_affinity.has(id):
			var a: float = game.minigame_affinity(id)
			aff = "Le encanta" if a >= 1.2 else ("Le gusta" if a >= 0.95 else "No le entusiasma")
		v.add_child(_label(mg["nombre"], 24))
		var d := _wrap("%s  ·  %s  ·  %s" % [mg["descripcion"], aff,
			_tolerance_text(game.tolerance_factor("mj_" + id))], 17)
		d.modulate = TEXT_DIM
		v.add_child(d)
		v.add_child(_button("Jugar", _start_minigame.bind(id)))
	var hint := _wrap("Puedes comprar más minijuegos en la tienda.", 17)
	hint.modulate = TEXT_DIM
	v.add_child(hint)
	v.add_child(_button("Cancelar", _close_modal))


func _start_minigame(id: String) -> void:
	var v := _open_modal(game.balance["minijuegos"][id]["nombre"], 0.85)
	var mg: Control = MINIGAME_SCRIPTS[id].new()
	mg.custom_minimum_size = Vector2(0, maxf(560, size.y - 300))
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


func _buy(id: String) -> void:
	if game.buy(id):
		_show_shop()


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
		"especie": return "Cosas de slime"
		"critico": return "¡Situación crítica!"
	return "Mientras tanto…"


func _show_game_over(ending: Dictionary) -> void:
	await get_tree().process_frame
	_close_modal()
	music.play(ending.get("musica", "final_malo"))
	var record := _save_record(ending)
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fade)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 1.8)
	await tw.finished
	var v := _open_modal(ending["titulo"], 1.0)
	v.add_child(_wrap(ending["texto"], 21))
	v.add_child(HSeparator.new())
	v.add_child(_label("Días sobrevividos: %d" % ending["dias"], 24))
	var rec := _label("Récord con %s: %d días%s" % [game.character["nombre"], record["mejor_dias"],
		"  ¡Nuevo récord!" if record["nuevo"] else ""], 20)
	rec.modulate = TEXT_DIM
	v.add_child(rec)
	var finals := _label("Finales descubiertos: %d/2" % record["finales"].size(), 20)
	finals.modulate = TEXT_DIM
	v.add_child(finals)
	v.add_child(_button("Nueva partida", get_tree().reload_current_scene))
	fade.queue_free()


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
