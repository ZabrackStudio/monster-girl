## Retrato del personaje sobre su fondo.
## Busca, por orden: expresiones/<estado>.png, retrato.png y, si no hay nada,
## el slime dibujado con código. Con una sola imagen, el estado se transmite
## con efectos: tinte rosado según la lujuria, respiración y temblor.
extends Control

const SlimeView := preload("res://scripts/slime_view.gd")

var char_id := ""
var mood := "neutral"
var level := 0
var outfit := ""
var has_expression := false
var t := 0.0

var bg: TextureRect
var sprite: TextureRect
var prev: TextureRect      # expresión anterior, que se desvanece encima de la nueva
var prev_tween: Tween
var jelly := 0.0          # temblor de gelatina al tocarla
var fallback: Control
var textures := {}


func setup(id: String, color: Color) -> void:
	char_id = id
	clip_contents = true
	bg = TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var bg_path := "res://personajes/%s/fondo.png" % id
	if ResourceLoader.exists(bg_path):
		bg.texture = load(bg_path)
	else:
		# Sin ilustración de su cuarto: un degradado con su color mientras tanto.
		var grad := Gradient.new()
		grad.set_color(0, color.darkened(0.55))
		grad.set_color(1, color.darkened(0.88))
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill_from = Vector2(0.5, 0.0)
		tex.fill_to = Vector2(0.5, 1.0)
		bg.texture = tex
	add_child(bg)
	sprite = TextureRect.new()
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(sprite)
	prev = TextureRect.new()
	prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prev.visible = false
	add_child(prev)
	fallback = SlimeView.new()
	fallback.base_color = color
	fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fallback)


func set_state(new_mood: String, new_level: int, new_outfit: String = "") -> void:
	mood = new_mood
	level = new_level
	outfit = new_outfit
	var tex := _texture_for(mood)
	if tex != sprite.texture and sprite.texture != null and tex != null and is_inside_tree():
		prev.texture = sprite.texture
		prev.modulate = sprite.modulate
		prev.visible = true
		if prev_tween:
			prev_tween.kill()
		prev_tween = create_tween()
		prev_tween.tween_property(prev, "modulate:a", 0.0, 0.35)
		prev_tween.tween_callback(func(): prev.visible = false)
	sprite.texture = tex
	sprite.visible = tex != null
	fallback.visible = tex == null
	fallback.mood = mood
	fallback.level = level


## ¿El toque ha caído sobre ella?
func hit(pos: Vector2) -> bool:
	return sprite.visible and sprite.get_rect().has_point(pos)


func poke() -> void:
	jelly = 1.0


func _texture_for(m: String) -> Texture2D:
	var key := outfit + "/" + m
	if not textures.has(key):
		var found: Array = [null, false]
		for path in ["res://personajes/%s/trajes/%s/%s.png" % [char_id, outfit, m],
				"res://personajes/%s/expresiones/%s.png" % [char_id, m],
				"res://personajes/%s/retrato.png" % char_id]:
			if ResourceLoader.exists(path):
				found = [load(path), not path.ends_with("retrato.png")]
				break
		textures[key] = found
	has_expression = textures[key][1]
	return textures[key][0]


func _process(delta: float) -> void:
	t += delta
	if not sprite.visible or sprite.texture == null:
		return
	var tex_size := sprite.texture.get_size()
	var h := size.y * 0.97
	var w := h * tex_size.x / tex_size.y
	var breathe := sin(t * (1.6 + level * 0.6)) * (3.0 + level)
	var shake := Vector2.ZERO
	if level >= 3:
		shake = Vector2(randf_range(-2, 2), randf_range(-1, 1))
	jelly = maxf(0.0, jelly - delta * 1.8)
	var wobble := sin(jelly * 18.0) * jelly * 0.05
	sprite.size = Vector2(w, h)
	sprite.pivot_offset = Vector2(w * 0.5, h)
	sprite.scale = Vector2(1.0 + wobble, 1.0 - wobble)
	sprite.position = Vector2((size.x - w) / 2, size.y - h + 6 + breathe) + shake
	if prev.visible:
		prev.size = sprite.size
		prev.position = sprite.position
		prev.pivot_offset = sprite.pivot_offset
		prev.scale = sprite.scale
	# Más lujuria, más rosa; en estado crítico, además, late.
	var pink := Color("ff8fc8")
	var amount := level * 0.14 + (0.08 * (0.5 + 0.5 * sin(t * 4.0)) if level >= 3 else 0.0)
	if has_expression:
		amount *= 0.35   # la ilustración ya muestra el estado; el tinte solo acompaña
	var target := Color.WHITE.lerp(pink, amount)
	if not has_expression and (mood == "triste" or mood == "cansada"):
		target = target.lerp(Color("b8c4e0"), 0.25)
	sprite.modulate = sprite.modulate.lerp(target, clampf(delta * 3.0, 0, 1))
