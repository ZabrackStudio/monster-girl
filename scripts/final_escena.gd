## Escena de un final: ilustración a pantalla completa y texto que avanza al tocar.
## «Fundido a negro.» apaga la ilustración y «—» marca el salto de tiempo.
extends Control

signal finished

const CHARS_PER_SEC := 45.0
const HOLD := 2.2         # segundos que la ilustración se ve sola
const CUT := "—"
const BLACKOUT := "Fundido a negro."

var ending: Dictionary
var beats: PackedStringArray
var index := -1
var art: TextureRect
var box: PanelContainer
var text: Label
var hint: Label
var typing: Tween
var hold: Tween
var art_tween: Tween
var blacked_out := false
var done := false


func _init(data: Dictionary = {}) -> void:
	ending = data


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	beats = ending["texto"].split("\n\n", false)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	art = TextureRect.new()
	art.texture = load(ending["imagen"])
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.modulate.a = 0.0
	add_child(art)
	_build_box()
	if ending.get("imagen_tras_corte", false):
		_next()
	else:
		_reveal()


func _build_box() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	box = PanelContainer.new()
	box.size_flags_vertical = Control.SIZE_SHRINK_END
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.modulate.a = 0.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.08, 0.86)
	sb.border_color = Color(1, 1, 1, 0.16)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(20)
	box.add_theme_stylebox_override("panel", sb)
	margin.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	box.add_child(v)
	text = Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 24)
	v.add_child(text)
	hint = Label.new()
	hint.text = "Toca para continuar"
	hint.add_theme_font_size_override("font_size", 18)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.modulate.a = 0.0
	v.add_child(hint)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		advance()


## Un toque salta la espera, completa la frase o pasa a la siguiente.
func advance() -> void:
	if done:
		return
	if hold and hold.is_running():
		hold.kill()
		_next()
	elif typing and typing.is_running():
		typing.kill()
		_typed()
	else:
		_next()


## Muestra la ilustración sola un momento antes de seguir con el texto.
func _reveal() -> void:
	if ending.get("texto_arriba", false):
		box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.modulate.a = 0.0
	_art_to(1.0, 1.0)
	hold = create_tween()
	hold.tween_interval(HOLD)
	hold.tween_callback(_next)


func _art_to(alpha: float, seconds: float) -> void:
	if art_tween:
		art_tween.kill()
	art_tween = create_tween()
	art_tween.tween_property(art, "modulate:a", alpha, seconds)


func _next() -> void:
	index += 1
	if index >= beats.size():
		_finish()
		return
	var beat := beats[index]
	if beat == CUT:
		if ending.get("imagen_tras_corte", false):
			_reveal()
		else:
			if not blacked_out:
				_art_to(0.35, 1.0)
			_next()
		return
	if beat == BLACKOUT:
		blacked_out = true
		_art_to(0.0, 1.4)
	_write(beat)


func _write(beat: String) -> void:
	text.text = beat
	text.visible_ratio = 0.0
	hint.modulate.a = 0.0
	if box.modulate.a < 1.0:
		create_tween().tween_property(box, "modulate:a", 1.0, 0.3)
	typing = create_tween()
	typing.tween_property(text, "visible_ratio", 1.0, beat.length() / CHARS_PER_SEC)
	typing.tween_callback(_typed)


func _typed() -> void:
	text.visible_ratio = 1.0
	hint.modulate.a = 0.55


## La ilustración queda de fondo, atenuada, detrás de los resultados.
func _finish() -> void:
	done = true
	box.visible = false
	_art_to(0.6, 0.6)
	finished.emit()
