## Expedientes del Proyecto Waifu: elige a quién cuidar. Cada uno se abre al aprobar el anterior.
## En modo casual se elige entre las ya abiertas en la historia, sin plazo ni evaluación.
extends Control

const Game := preload("res://scripts/game.gd")
const Fade := preload("res://scripts/transicion.gd")
const Progress := preload("res://scripts/progreso.gd")
const Music := preload("res://scripts/music.gd")
const RECORDS_PATH := "user://records.json"

var mode := "historia"
var records := {}
var modal: Control


func _ready() -> void:
	mode = Engine.get_meta("modo", "historia")
	if FileAccess.file_exists(RECORDS_PATH):
		var r = Game.load_json(RECORDS_PATH)
		if r is Dictionary:
			records = r
	var music = get_node_or_null("/root/Musica")
	if music == null:
		music = Music.new()
		add_child(music)
	music.play("menu")
	var black := ColorRect.new()
	black.color = Color("0d0b18")
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	var bg := TextureRect.new()
	bg.texture = load("res://ui/tienda_fondo.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.3, 0.3, 0.34)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	margin.add_child(v)
	var title := _label("Expedientes" if mode == "historia" else "Modo casual", 36)
	title.add_theme_color_override("font_color", Color("d6c46a"))
	v.add_child(title)
	var sub := _label("H.A.R.E.M. · Proyecto Waifu" if mode == "historia" else "Sin plazo ni evaluación", 20)
	sub.modulate = Color(1, 1, 1, 0.6)
	v.add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 18)
	scroll.add_child(list)
	var p := Progress.project()
	var prog := Progress.load_progress()
	for i in p["expedientes"].size():
		list.add_child(_card(p, prog, i))
	var back := Button.new()
	back.text = "Volver"
	back.custom_minimum_size = Vector2(0, 64)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(func(): Fade.go(get_tree(), "res://scenes/modo.tscn"))
	v.add_child(back)


func _card(p: Dictionary, prog: Dictionary, i: int) -> Control:
	var a: Dictionary = p["expedientes"][i]
	var ch: Dictionary = Game.load_json("res://data/personajes/%s.json" % a["personaje"])
	var open := Progress.unlocked(p, prog, i)
	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 220)
	card.disabled = not open
	card.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.14, 0.92)
	sb.border_color = Color("8a8f5a") if open else Color(1, 1, 1, 0.15)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		card.add_theme_stylebox_override(state, sb)
	card.pressed.connect(_start.bind(a["personaje"]))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var pic := TextureRect.new()
	var path := "res://personajes/%s/trajes/%s/neutral.png" % [a["personaje"], ch.get("traje_inicial", "")]
	if ResourceLoader.exists(path):
		pic.texture = load(path)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(170, 0)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not open:
		pic.modulate = Color(0, 0, 0, 0.85)   # silueta
	row.add_child(pic)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)
	info.add_child(_label("Expediente %02d" % (i + 1), 18, 0.55))
	info.add_child(_label(ch["nombre"] if open else "Clasificado", 30))
	info.add_child(_label(ch["especie"] if open else "Sin datos", 20, 0.75))
	var grade: String = prog["notas"].get(a["personaje"], "")
	var state := ""
	if mode == "casual":
		var best := int(records.get(a["personaje"], {}).get("mejor_dias", 0))
		if open:
			info.add_child(_label("Mejor marca: %d días" % best if best > 0 else "Sin partidas", 18, 0.6))
		state = "Se abre en la historia" if not open else ""
	else:
		info.add_child(_label("Convivencia: %d días" % int(a.get("dias", 0)), 18, 0.6))
		if not open:
			state = "Requiere aprobar el expediente %02d" % i
		elif grade != "":
			state = "Mejor nota: " + grade
		else:
			state = "Sin evaluar"
	var st := _label(state, 18, 0.85)
	st.add_theme_color_override("font_color", Color("9fe0a8") if grade != "" and Progress.passed(p, prog, i) else Color("f2c14e"))
	info.add_child(st)
	return card


func _label(t: String, font_size: int, alpha := 1.0) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", font_size)
	l.modulate.a = alpha
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Si ya hay una partida de este modo, avisa antes de reemplazarla.
func _start(character_id: String) -> void:
	var saved = Game.load_json(Game.save_path(mode)) if FileAccess.file_exists(Game.save_path(mode)) else null
	if saved is Dictionary and saved.has("personaje"):
		_confirm(saved, character_id)
		return
	_go(character_id)


func _go(character_id: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path(mode)))
	Engine.set_meta("personaje", character_id)
	if mode == "casual":
		Fade.go(get_tree(), "res://scenes/main.tscn")
	else:
		Engine.set_meta("intro_personaje", character_id)
		Fade.go(get_tree(), "res://scenes/intro.tscn")


func _confirm(saved: Dictionary, character_id: String) -> void:
	modal = ColorRect.new()
	modal.color = Color(0, 0, 0, 0.7)
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("231d3a")
	sb.border_color = Color("a88bf0")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(size.x - 80, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(_label("¿Partida nueva?", 30))
	var msg := _label("Ya tienes una partida %s con %s (día %d). Si empiezas otra, se perderá." % [
		Game.MODE_NAMES[mode].to_lower(), Progress.character_name(saved["personaje"]), int(saved.get("day", 1))], 20)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(msg)
	for pair in [["Empezar de cero", _go.bind(character_id)], ["Cancelar", func():
			modal.queue_free()
			modal = null]]:
		var b := Button.new()
		b.text = pair[0]
		b.custom_minimum_size = Vector2(0, 64)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(pair[1])
		v.add_child(b)
