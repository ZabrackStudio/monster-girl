## Galería: por cada chica, los finales que el jugador ya vio (en cualquier modo).
## Tocar uno lo vuelve a reproducir. Lo que no se ha visto queda tapado.
extends Control

const Game := preload("res://scripts/game.gd")
const Fade := preload("res://scripts/transicion.gd")
const Progress := preload("res://scripts/progreso.gd")
const Music := preload("res://scripts/music.gd")
const EndingScene := preload("res://scripts/final_escena.gd")
const RECORDS_PATH := "user://records.json"
## Orden en que se muestran los finales; la evaluación del día 30 va al final.
const KINDS := ["poseida", "carnal", "lucha", "denuncia", "marea", "evaluacion"]
const GOLD := Color("d6c46a")

var records := {}
var tabs: HBoxContainer
var content: VBoxContainer
var current := ""


func _ready() -> void:
	var music = get_node_or_null("/root/Musica")
	if music == null:
		music = Music.new()
		add_child(music)
	music.play("menu")
	if FileAccess.file_exists(RECORDS_PATH):
		var r = Game.load_json(RECORDS_PATH)
		if r is Dictionary:
			records = r
	var black := ColorRect.new()
	black.color = Color("0d0b18")
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	var bg := TextureRect.new()
	bg.texture = load("res://personajes/slime/fondo.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.22, 0.2, 0.3)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	margin.add_child(v)
	var title := _label("Galería", 36)
	title.add_theme_color_override("font_color", GOLD)
	v.add_child(title)

	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)

	var back := Button.new()
	back.text = "Volver"
	back.custom_minimum_size = Vector2(0, 64)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(func(): Fade.go(get_tree(), "res://scenes/menu.tscn"))
	v.add_child(back)

	var first := ""
	for a in Progress.project()["expedientes"]:
		var cid: String = a["personaje"]
		var known := _known(cid)
		var b := Button.new()
		b.text = Progress.character_name(cid) if known else "???"
		b.disabled = not known
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(_show.bind(cid))
		b.set_meta("cid", cid)
		tabs.add_child(b)
		if known and first == "":
			first = cid
	_show(first)


## Se conoce a una chica si su expediente ya está abierto o si alguna vez se jugó con ella.
func _known(cid: String) -> bool:
	var p := Progress.project()
	for i in p["expedientes"].size():
		if p["expedientes"][i]["personaje"] == cid:
			return Progress.unlocked(p, Progress.load_progress(), i) or records.has(cid)
	return false


func _show(cid: String) -> void:
	current = cid
	for b in tabs.get_children():
		b.button_pressed = b.get_meta("cid") == cid
	for c in content.get_children():
		c.queue_free()
	if cid == "":
		return
	var ch: Dictionary = Game.load_json("res://data/personajes/%s.json" % cid)
	var rec: Dictionary = records.get(cid, {})
	var seen: Array = rec.get("finales", [])

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	content.add_child(head)
	var pic := TextureRect.new()
	var path := "res://personajes/%s/trajes/%s/neutral.png" % [cid, ch.get("traje_inicial", "")]
	if ResourceLoader.exists(path):
		pic.texture = load(path)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(190, 190)
	head.add_child(pic)
	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(info)
	info.add_child(_label(ch["nombre"], 30))
	info.add_child(_label(ch["especie"], 20, 0.75))
	var grade: String = Progress.load_progress()["notas"].get(cid, "")
	info.add_child(_label("Mejor nota: " + (grade if grade != "" else "—"), 18, 0.7))
	info.add_child(_label("Mejor marca: %d días" % int(rec.get("mejor_dias", 0)), 18, 0.7))
	info.add_child(_label("Finales: %d de %d" % [_count_seen(seen), KINDS.size()], 18, 0.7))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)
	var w := (size.x - 48 - 20) / 3.0
	for kind in KINDS:
		grid.add_child(_tile(ch, kind, kind in seen, rec, w))


func _count_seen(seen: Array) -> int:
	var n := 0
	for k in KINDS:
		if k in seen:
			n += 1
	return n


func _ending(ch: Dictionary, kind: String) -> Dictionary:
	if kind != "evaluacion":
		return ch["finales"][kind]
	var grade: String = Progress.load_progress()["notas"].get(ch["id"], "")
	var texts: Dictionary = ch.get("evaluacion", {})
	return {"titulo": "Evaluación final", "imagen": Progress.project().get("imagen_evaluacion", ""),
		"texto": texts.get(grade, texts.get("C", "")), "musica": "final_marea"}


func _tile(ch: Dictionary, kind: String, seen: bool, _rec: Dictionary, w: float) -> Control:
	var ending := _ending(ch, kind)
	var b := Button.new()
	b.custom_minimum_size = Vector2(w, w * 16.0 / 9.0 * 0.62)
	b.disabled = not seen
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	sb.border_color = GOLD if seen else Color(1, 1, 1, 0.12)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, sb)
	if seen and ResourceLoader.exists(ending.get("imagen", "")):
		var art := TextureRect.new()
		art.texture = load(ending["imagen"])
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(art)
	var name_box := PanelContainer.new()
	var nsb := StyleBoxFlat.new()
	nsb.bg_color = Color(0, 0, 0, 0.6)
	nsb.set_content_margin_all(6)
	name_box.add_theme_stylebox_override("panel", nsb)
	name_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := _label(ending["titulo"].get_slice(": ", 1) if ": " in ending["titulo"] else ending["titulo"], 16) if seen else _label("???", 22, 0.5)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_box.add_child(t)
	b.add_child(name_box)
	name_box.anchor_top = 1.0
	name_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if seen:
		b.pressed.connect(_replay.bind(ending))
	return b


## Vuelve a reproducir el final con su texto y su música.
func _replay(ending: Dictionary) -> void:
	var music = get_node_or_null("/root/Musica")
	if music:
		music.play(ending.get("musica", "final_poseida"))
	var scene := EndingScene.new(ending)
	add_child(scene)
	await scene.finished
	scene.queue_free()
	if music:
		music.play("menu")


func _label(t: String, font_size: int, alpha := 1.0) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", font_size)
	l.modulate.a = alpha
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
