## Minijuego inicial de la slime: revienta burbujas antes de que escapen.
## Las doradas valen doble; las moradas restan.
extends Control

signal finished(score: float)

const DURATION := 15.0
const TARGET := 22.0   # puntos para conseguir el 100 %

var time_left := DURATION
var points := 0
var bubbles: Array = []   # {pos, r, speed, kind, phase}
var spawn_timer := 0.0
var running := true
var font: Font


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = get_theme_default_font()


func _process(delta: float) -> void:
	if not running:
		return
	time_left -= delta
	spawn_timer -= delta
	if spawn_timer <= 0:
		_spawn()
		spawn_timer = randf_range(0.3, 0.6)
	for b in bubbles:
		b["pos"] += Vector2(sin(Time.get_ticks_msec() / 400.0 + b["phase"]) * 0.6, -b["speed"] * delta)
	bubbles = bubbles.filter(func(b): return b.pos.y > -b.r)
	if time_left <= 0:
		_end()
	queue_redraw()


func _spawn() -> void:
	var roll := randf()
	var kind := "normal"
	if roll < 0.12:
		kind = "oro"
	elif roll < 0.27:
		kind = "mala"
	var r := randf_range(26, 46)
	bubbles.append({
		"pos": Vector2(randf_range(r, size.x - r), size.y + r),
		"r": r, "speed": randf_range(120, 220) * (1.3 if kind == "oro" else 1.0),
		"kind": kind, "phase": randf() * TAU,
	})


func _gui_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in range(bubbles.size() - 1, -1, -1):
			var b = bubbles[i]
			if event.position.distance_to(b.pos) <= b.r + 6:
				match b.kind:
					"oro": points += 2
					"mala": points = maxi(0, points - 2)
					_: points += 1
				bubbles.remove_at(i)
				break


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("1c2b3a"))
	for b in bubbles:
		var col := Color("8fe3f5")
		if b.kind == "oro": col = Color("ffd34d")
		elif b.kind == "mala": col = Color("8a4fd1")
		draw_circle(b.pos, b.r, Color(col, 0.35))
		draw_arc(b.pos, b.r, 0, TAU, 32, col, 3.0, true)
		draw_circle(b.pos + Vector2(-b.r * 0.35, -b.r * 0.35), b.r * 0.18, Color(1, 1, 1, 0.6))
	var hud := "Tiempo: %d   Puntos: %d" % [ceili(maxf(time_left, 0)), points]
	draw_string(font, Vector2(16, 36), hud, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
	if not running:
		draw_string(font, Vector2(0, size.y / 2), "¡%d%%!" % int(score() * 100), HORIZONTAL_ALIGNMENT_CENTER, size.x, 64)


func score() -> float:
	return clampf(points / TARGET, 0.0, 1.0)


func _end() -> void:
	running = false
	bubbles.clear()
	queue_redraw()
	await get_tree().create_timer(1.2).timeout
	finished.emit(score())
