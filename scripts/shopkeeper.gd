## La intendente de la tienda: respira, se balancea y reacciona a las compras.
extends TextureRect

var t := randf() * 10.0
var bounce := 0.0


func _ready() -> void:
	texture = load("res://ui/tienda_vendedora.png")
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Ajusta el tamaño a una altura conservando la proporción.
func fit(h: float) -> void:
	var ts: Vector2 = texture.get_size()
	size = Vector2(h * ts.x / ts.y, h)
	pivot_offset = Vector2(size.x * 0.5, size.y)


## Un gesto breve, como un asentimiento.
func react() -> void:
	bounce = 1.0


func _process(delta: float) -> void:
	t += delta
	bounce = maxf(0.0, bounce - delta * 2.5)
	var breathe := sin(t * 1.7) * 0.008
	var nod := sin(bounce * PI) * 0.025
	scale = Vector2(1.0 - breathe * 0.5, 1.0 + breathe - nod)
	# Cambia el peso de pierna de vez en cuando.
	rotation = sin(t * 0.45) * 0.012 + sin(t * 1.1) * 0.003
