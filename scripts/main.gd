## Pantalla principal. Toda la interfaz se construye en código para que el
## prototipo no dependa del editor; la lógica vive en game.gd.
extends Control

const Game := preload("res://scripts/game.gd")
const SlimeView := preload("res://scripts/slime_view.gd")
const MINIGAME_SCRIPTS := {
	"burbujas": preload("res://scripts/minigame_bubbles.gd"),
	"memoria": preload("res://scripts/minigame_memory.gd"),
}
const CHARACTER := "res://data/personajes/slime.json"
const RECORDS_PATH := "user://records.json"
const BAR_STATS := ["salud", "felicidad", "tristeza", "hambre", "energia", "higiene"]
const BG := Color("141a24")
const PANEL := Color("1f2835")
const TEXT_DIM := Color(1, 1, 1, 0.65)

var game
var bg: ColorRect
var lbl_top: Label
var lbl_name: Label
var lbl_level: Label
var lust_bar: ProgressBar
var lbl_line: Label
var log_box: RichTextLabel
var portrait_holder: Control
var slime_view: Control
var portrait_tex: TextureRect
var stat_bars := {}
var action_buttons := {}
var modal: Control


func _ready() -> void:
	game = Game.new()
	game.setup(CHARACTER)
	_build_ui()
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
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	lbl_top = _label("", 24)
	root.add_child(lbl_top)

	# Retrato
	var portrait_panel := _panel()
	portrait_panel.custom_minimum_size = Vector2(0, 360)
	root.add_child(portrait_panel)
	var pv := VBoxContainer.new()
	portrait_panel.add_child(pv)
	var name_row := HBoxContainer.new()
	pv.add_child(name_row)
	lbl_name = _label("%s · %s" % [game.character["nombre"], game.character["especie"]], 26)
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(lbl_name)
	lbl_level = _label("", 24)
	name_row.add_child(lbl_level)
	portrait_holder = Control.new()
	portrait_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv.add_child(portrait_holder)
	slime_view = SlimeView.new()
	slime_view.base_color = Color(game.character["color"])
	slime_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_holder.add_child(slime_view)
	portrait_tex = TextureRect.new()
	portrait_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_tex.visible = false
	portrait_holder.add_child(portrait_tex)
	var lust_row := HBoxContainer.new()
	pv.add_child(lust_row)
	lust_row.add_child(_label("Lujuria", 22))
	lust_bar = _bar(Color("d9434f"))
	lust_bar.custom_minimum_size = Vector2(0, 26)
	lust_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lust_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lust_row.add_child(lust_bar)

	# Diálogo
	var line_panel := _panel(Color("2a2236"))
	root.add_child(line_panel)
	lbl_line = _label("", 22)
	lbl_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_panel.add_child(lbl_line)

	# Estadísticas
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	root.add_child(grid)
	var colors := {"salud": "6fcf7f", "felicidad": "f2c14e", "tristeza": "6f8fd9",
		"hambre": "e8893a", "energia": "4fb3e8", "higiene": "8fe3f5"}
	for s in BAR_STATS:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 0)
		var l := _label(Game.STAT_NAMES[s], 18)
		l.modulate = TEXT_DIM
		box.add_child(l)
		var bar := _bar(Color(colors[s]))
		box.add_child(bar)
		grid.add_child(box)
		stat_bars[s] = bar

	# Registro
	var log_panel := _panel()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(log_panel)
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.add_theme_font_size_override("normal_font_size", 18)
	log_box.add_theme_font_size_override("bold_font_size", 18)
	log_panel.add_child(log_box)

	# Acciones
	var actions := GridContainer.new()
	actions.columns = 4
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	root.add_child(actions)
	var defs := [
		["trabajar", "Trabajar"], ["comer", "Comer"], ["pasear", "Pasear"], ["jugar", "Jugar"],
		["limpiar", "Limpiar"], ["tienda", "Tienda"], ["objetos", "Objetos"], ["dormir", "Dormir"],
	]
	for d in defs:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 76)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 20)
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


func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 100
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(6)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.08)
	back.set_corner_radius_all(6)
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
	lbl_level.add_theme_color_override("font_color", lv_color)
	lust_bar.value = game.stats["lujuria"]
	(lust_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = lv_color
	for s in BAR_STATS:
		stat_bars[s].value = game.stats[s]
	lbl_line.text = "«%s»" % game.current_line if game.current_line != "" else ""
	bg.color = BG.lerp(Color("3a1424"), game.level() * 0.18)

	var mood: String = game.mood()
	slime_view.mood = mood
	slime_view.level = game.level()
	slime_view.tint = lv_color
	var tex_path := "res://personajes/%s/expresiones/%s.png" % [game.character["id"], mood]
	if ResourceLoader.exists(tex_path):
		portrait_tex.texture = load(tex_path)
		portrait_tex.visible = true
		slime_view.visible = false
	else:
		portrait_tex.visible = false
		slime_view.visible = true

	for id in action_buttons:
		var b: Button = action_buttons[id][0]
		var label: String = action_buttons[id][1]
		match id:
			"tienda", "objetos", "dormir":
				b.text = label
				b.disabled = game.over
			_:
				var act: Dictionary = game.activity(id)
				b.text = "%s\n%d acc." % [label, int(act["costo"])]
				b.disabled = not game.can_do(id)
				b.tooltip_text = game.why_not(id)
	var obj_count := 0
	for k in game.inventory:
		obj_count += game.inventory[k]
	action_buttons["objetos"][0].text = "Objetos\n(%d)" % obj_count
	action_buttons["dormir"][0].text = "Dormir\nfin del día"


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
	var v := _open_modal("Objetos")
	if game.inventory.is_empty():
		v.add_child(_wrap("No tienes objetos. Compra algo en la tienda."))
	for id in game.inventory:
		var it: Dictionary = game.items[id]
		var row := HBoxContainer.new()
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(_label("%s ×%d" % [it["nombre"], game.inventory[id]], 22))
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
	v.add_child(_button("Cerrar", _close_modal))


func _show_minigame_select() -> void:
	var v := _open_modal("¿A qué jugamos?")
	for id in game.minigames:
		var mg: Dictionary = game.balance["minijuegos"][id]
		var aff := "Afinidad: ?"
		if game.known_affinity.has(id):
			var a: float = game.minigame_affinity(id)
			aff = "Le encanta" if a >= 1.2 else ("Le gusta" if a >= 0.95 else "No le entusiasma")
		v.add_child(_label(mg["nombre"], 24))
		var d := _wrap("%s  ·  %s" % [mg["descripcion"], aff], 17)
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
