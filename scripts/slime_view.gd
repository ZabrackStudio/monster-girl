## Retrato provisional: un slime dibujado con código que se tambalea según su estado.
## Se sustituye automáticamente por PNG en res://personajes/<id>/expresiones/.
extends Control

var base_color := Color("6fd3c1")
var tint := Color.WHITE        # color del nivel de lujuria
var mood := "neutral"
var level := 0
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.36
	var c := Vector2(size.x / 2, size.y * 0.58)
	var agitation := level * 0.6 + (0.3 if mood == "inquieta" else 0.0)
	var squash := 1.0 + sin(t * (2.0 + agitation * 2.0)) * 0.03
	# Con el nivel pasa de su color natural a un rosa intenso.
	var body := base_color.lerp(Color("f06aa0"), level * 0.22)
	body.a = 0.9

	var pts := PackedVector2Array()
	var n := 64
	for i in n:
		var a := TAU * i / n
		var wob := sin(a * 3 + t * 2.0) * 0.035 + sin(a * 5 - t * (1.5 + agitation * 3)) * 0.025 * (1 + agitation * 1.5)
		var rr := r * (1 + wob)
		var p := Vector2(cos(a) * rr * 1.1 * squash, sin(a) * rr * 0.9 / squash)
		if p.y > 0:
			p.y *= 0.5
		pts.append(c + p)
	draw_colored_polygon(pts, body)
	draw_polyline(pts + PackedVector2Array([pts[0]]), body.darkened(0.25), 3.0, true)
	# Brillo
	draw_circle(c + Vector2(-r * 0.45, -r * 0.45), r * 0.13, Color(1, 1, 1, 0.45))
	draw_circle(c + Vector2(-r * 0.25, -r * 0.6), r * 0.06, Color(1, 1, 1, 0.35))

	var eye_y := -r * 0.12
	var ex := r * 0.32
	var ink := Color(0.12, 0.15, 0.2)
	var eye_col := ink.lerp(Color(0.85, 0.2, 0.45), clampf(level - 1, 0, 2) * 0.4)
	for side in [-1, 1]:
		var e := c + Vector2(ex * side, eye_y)
		match mood:
			"cansada":
				draw_line(e + Vector2(-r * 0.09, 0), e + Vector2(r * 0.09, 0), ink, 4.0, true)
			"feliz":
				draw_arc(e + Vector2(0, r * 0.04), r * 0.09, PI, TAU, 12, ink, 4.0, true)
			_:
				var er := r * (0.08 + level * 0.012)
				draw_circle(e, er, eye_col)
				draw_circle(e + Vector2(-er * 0.35, -er * 0.35), er * 0.35, Color.WHITE)
				if mood == "triste":
					draw_line(e + Vector2(-r * 0.1, -r * 0.16 + side * r * 0.03), e + Vector2(r * 0.1, -r * 0.16 - side * r * 0.03), ink, 3.0, true)
	# Rubor según nivel
	if level >= 1:
		var blush := Color(1, 0.4, 0.55, 0.15 + level * 0.12)
		for side in [-1, 1]:
			draw_circle(c + Vector2(ex * 1.45 * side, eye_y + r * 0.17), r * 0.09, blush)
	# Boca
	var m := c + Vector2(0, r * 0.15)
	match mood:
		"feliz", "neutral":
			draw_arc(m, r * 0.12, 0.2, PI - 0.2, 12, ink, 3.5, true)
		"triste", "cansada":
			draw_arc(m + Vector2(0, r * 0.1), r * 0.1, PI + 0.3, TAU - 0.3, 12, ink, 3.5, true)
		"critica":
			draw_circle(m, r * 0.06, ink)
		_:
			draw_line(m + Vector2(-r * 0.08, 0), m + Vector2(r * 0.08, sin(t * 6) * r * 0.02), ink, 3.5, true)
