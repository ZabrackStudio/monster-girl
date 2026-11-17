## Minijuego de parejas: 6 parejas en 40 segundos.
extends VBoxContainer

signal finished(score: float)

const DURATION := 40.0
const WORDS := ["Gota", "Sol", "Luna", "Pez", "Flor", "Nube"]
const COLORS := ["4fb3e8", "f2c14e", "b28dff", "f28b5b", "ef6f9c", "9ad17a"]

var time_left := DURATION
var cards: Array = []      # índice de palabra por carta
var buttons: Array = []
var revealed: Array = []
var matched := 0
var locked := false
var running := true
var hud: Label


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	hud = Label.new()
	hud.add_theme_font_size_override("font_size", 26)
	hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hud)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL   # las cartas llenan la ventana
	add_child(grid)
	for i in WORDS.size():
		cards.append(i)
		cards.append(i)
	cards.shuffle()
	for i in cards.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 28)
		b.text = "?"
		b.pressed.connect(_flip.bind(i))
		grid.add_child(b)
		buttons.append(b)


func _process(delta: float) -> void:
	if not running:
		return
	time_left -= delta
	hud.text = "Tiempo: %d   Parejas: %d/6" % [ceili(maxf(time_left, 0)), matched]
	if time_left <= 0:
		_end()


func _flip(i: int) -> void:
	if locked or not running or i in revealed or buttons[i].disabled:
		return
	_show(i, true)
	revealed.append(i)
	if revealed.size() < 2:
		return
	var a: int = revealed[0]
	var b: int = revealed[1]
	revealed.clear()
	if cards[a] == cards[b]:
		buttons[a].disabled = true
		buttons[b].disabled = true
		matched += 1
		if matched == WORDS.size():
			_end()
	else:
		locked = true
		await get_tree().create_timer(0.6).timeout
		_show(a, false)
		_show(b, false)
		locked = false


func _show(i: int, face_up: bool) -> void:
	var b: Button = buttons[i]
	b.text = WORDS[cards[i]] if face_up else "?"
	var col: Color = Color(COLORS[cards[i]]) if face_up else Color.WHITE
	for s in ["font_color", "font_disabled_color", "font_pressed_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(s, col)


func score() -> float:
	var base := float(matched) / WORDS.size()
	var bonus := 0.2 * (time_left / DURATION) if matched == WORDS.size() else 0.0
	return clampf(base * 0.85 + bonus + (0.15 if matched == WORDS.size() else 0.0), 0.0, 1.0)


func _end() -> void:
	if not running:
		return
	running = false
	hud.text = "¡%d%%!" % int(score() * 100)
	await get_tree().create_timer(1.2).timeout
	finished.emit(score())
