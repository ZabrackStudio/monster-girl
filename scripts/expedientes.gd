## Expedientes del Proyecto Waifu: elige a quién cuidar. Cada uno se abre al aprobar el anterior.
extends Control

const Game := preload("res://scripts/game.gd")
const Fade := preload("res://scripts/transicion.gd")
const Progress := preload("res://scripts/progreso.gd")
const Music := preload("res://scripts/music.gd")


func _ready() -> void:
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
	var title := _label("Expedientes", 36)
	title.add_theme_color_override("font_color", Color("d6c46a"))
	v.add_child(title)
	var sub := _label("H.A.R.E.M. · Proyecto Waifu", 20)
	sub.modulate = Color(1, 1, 1, 0.6)
	v.add_child(sub)

	var p := Progress.project()
	var prog := Progress.load_progress()
	for i in p["expedientes"].size():
		v.add_child(_card(p, prog, i))
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(gap)
	var back := Button.new()
	back.text = "Volver"
	back.custom_minimum_size = Vector2(0, 64)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(func(): Fade.go(get_tree(), "res://scenes/menu.tscn"))
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
	info.add_child(_label("Convivencia: %d días" % int(a.get("dias", 0)), 18, 0.6))
	var grade: String = prog["notas"].get(a["personaje"], "")
	var state := ""
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


func _start(character_id: String) -> void:
	Engine.set_meta("personaje", character_id)
	Engine.set_meta("intro_personaje", character_id)
	Fade.go(get_tree(), "res://scenes/intro.tscn")
