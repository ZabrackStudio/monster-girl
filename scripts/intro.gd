## Introducción: la intendente de H.A.R.E.M. explica el Proyecto Waifu.
## Toca para avanzar; el primer toque completa la frase si aún se está escribiendo.
extends Control

const Shopkeeper := preload("res://scripts/shopkeeper.gd")
const Game := preload("res://scripts/game.gd")
const CHARS_PER_SEC := 45.0

var lines: Array = []
var index := -1
var text: Label
var hint: Label
var counter: Label
var tween: Tween


func _ready() -> void:
	var data: Dictionary = Game.load_json("res://data/intro.json")
	lines = data["lineas"]
	var music = get_node_or_null("/root/Musica")
	if music:
		music.play("tienda")
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	var bg := TextureRect.new()
	bg.texture = load("res://ui/tienda_fondo.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.45, 0.45, 0.5)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var keeper := Shopkeeper.new()
	add_child(keeper)
	keeper.fit(size.y * 0.8)
	keeper.position = Vector2(size.x * 0.5 - keeper.size.x * 0.5, size.y * 0.02)

	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.07, 0.94)
	sb.border_color = Color("8a8f5a")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(18)
	box.add_theme_stylebox_override("panel", sb)
	box.position = Vector2(20, size.y * 0.66)
	box.size = Vector2(size.x - 40, size.y * 0.3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var who := _label(data["nombre"], 22)
	who.add_theme_color_override("font_color", Color("d6c46a"))
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(who)
	counter = _label("", 18)
	counter.modulate = Color(1, 1, 1, 0.5)
	head.add_child(counter)
	text = _label("", 24)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(text)
	hint = _label("Toca para continuar", 18)
	hint.modulate = Color(1, 1, 1, 0.55)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(hint)

	var skip := Button.new()
	skip.text = "Saltar"
	skip.add_theme_font_size_override("font_size", 20)
	skip.position = Vector2(size.x - 140, 20)
	skip.size = Vector2(120, 56)
	skip.pressed.connect(_finish)
	add_child(skip)
	_next()


func _label(t: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", font_size)
	return l


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_advance()


func _advance() -> void:
	if tween and tween.is_running():
		tween.kill()
		text.visible_ratio = 1.0
		hint.visible = true
	else:
		_next()


func _next() -> void:
	index += 1
	if index >= lines.size():
		_finish()
		return
	text.text = lines[index]
	counter.text = "%d/%d" % [index + 1, lines.size()]
	text.visible_ratio = 0.0
	hint.visible = false
	tween = create_tween()
	tween.tween_property(text, "visible_ratio", 1.0, lines[index].length() / CHARS_PER_SEC)
	tween.tween_callback(func(): hint.visible = true)


func _finish() -> void:
	# Si se abrió desde Opciones, vuelve al menú; si no, empieza la partida.
	if Engine.get_meta("intro_desde_menu", false):
		Engine.set_meta("intro_desde_menu", false)
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
