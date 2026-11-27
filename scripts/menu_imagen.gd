## Arma una pantalla con las piezas de una imagen de menú (ui/<pieza>.png) apiladas y centradas.
## La primera pieza es decorativa; las demás son botones que llaman a `actions[pieza]`.
extends RefCounted

const SRC_W := 941.0
const SRC_H := 1672.0


static func build(parent: Control, pieces: Array, actions: Dictionary) -> Dictionary:
	var k := minf(parent.size.x / SRC_W, parent.size.y / SRC_H)
	var x := (parent.size.x - SRC_W * k) * 0.5
	var y := (parent.size.y - SRC_H * k) * 0.5
	var nodes := {}
	for i in pieces.size():
		var tex: Texture2D = load("res://ui/%s.png" % pieces[i])
		var sz := tex.get_size() * k
		var node: Control
		if i == 0:
			var deco := TextureRect.new()
			deco.texture = tex
			deco.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node = deco
		else:
			var b := TextureButton.new()
			b.texture_normal = tex
			b.ignore_texture_size = true
			b.stretch_mode = TextureButton.STRETCH_SCALE
			b.pivot_offset = sz * 0.5
			b.button_down.connect(func(): b.scale = Vector2(0.96, 0.96))
			b.button_up.connect(func(): b.scale = Vector2.ONE)
			if actions.has(pieces[i]):
				b.pressed.connect(actions[pieces[i]])
			node = b
		node.position = Vector2(x, y)
		node.size = sz
		if node is TextureButton:
			node.pivot_offset = sz * 0.5
		parent.add_child(node)
		nodes[pieces[i]] = node
		y += sz.y
	return nodes


static func disable(b: TextureButton) -> void:
	b.disabled = true
	b.modulate = Color(0.45, 0.45, 0.5, 0.7)
