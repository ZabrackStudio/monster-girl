## Menú principal: partida nueva, continuar, opciones y créditos.
extends Control

const Game := preload("res://scripts/game.gd")
const Music := preload("res://scripts/music.gd")
const Fade := preload("res://scripts/transicion.gd")
const RECORDS_PATH := "user://records.json"
const SRC_W := 941.0   # ancho de la imagen original del menú
const PIECES := [["logo", 0], ["nueva", 695], ["continuar", 925], ["opciones", 1146], ["creditos", 1371]]

var music
var modal: Control


func _ready() -> void:
	music = get_node_or_null("/root/Musica")
	if music == null:
		music = Music.new()
		add_child(music)
	music.play("lobby")
	var black := ColorRect.new()
	black.color = Color("0d0b18")
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	var bg := TextureRect.new()
	bg.texture = load("res://personajes/slime/fondo.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.32, 0.28, 0.42)
	add_child(bg)

	var k := size.x / SRC_W
	var top := (size.y - 1610.0 * k) * 0.5
	var has_save := FileAccess.file_exists(Game.SAVE_PATH)
	for p in PIECES:
		var tex: Texture2D = load("res://ui/menu_%s.png" % p[0])
		var pos := Vector2(0, top + p[1] * k)
		var sz := tex.get_size() * k
		if p[0] == "logo":
			var logo := TextureRect.new()
			logo.texture = tex
			logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			logo.position = pos
			logo.size = sz
			add_child(logo)
			continue
		var b := TextureButton.new()
		b.texture_normal = tex
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.position = pos
		b.size = sz
		b.pivot_offset = sz * 0.5
		b.button_down.connect(func(): b.scale = Vector2(0.96, 0.96))
		b.button_up.connect(func(): b.scale = Vector2.ONE)
		b.pressed.connect(Callable(self, "_on_" + p[0]))
		if p[0] == "continuar" and not has_save:
			b.disabled = true
			b.modulate = Color(0.45, 0.45, 0.5, 0.7)
		add_child(b)


# ---------------------------------------------------------------- botones

func _on_nueva() -> void:
	if FileAccess.file_exists(Game.SAVE_PATH):
		var v := _open_modal("¿Partida nueva?")
		v.add_child(_wrap("Tienes una partida en curso. Si empiezas otra, se perderá."))
		v.add_child(_button("Empezar de cero", _start_new))
		v.add_child(_button("Cancelar", _close_modal))
	else:
		_start_new()


func _start_new() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	Fade.go(get_tree(), "res://scenes/intro.tscn")


func _on_continuar() -> void:
	Engine.set_meta("continuar", true)
	Fade.go(get_tree(), "res://scenes/main.tscn")


func _on_opciones() -> void:
	var v := _open_modal("Opciones")
	var snd := _button(_sound_label(), func(): pass)
	snd.pressed.connect(func():
		music.toggle_mute()
		snd.text = _sound_label())
	v.add_child(snd)
	v.add_child(_volume_row())
	v.add_child(_button("Ver la introducción", func():
		Engine.set_meta("intro_desde_menu", true)
		Fade.go(get_tree(), "res://scenes/intro.tscn")))
	v.add_child(HSeparator.new())
	v.add_child(_label("Récords", 24))
	var rec := _records_text()
	var l := _wrap(rec)
	l.modulate = Color(1, 1, 1, 0.75)
	v.add_child(l)
	v.add_child(_button("Borrar partida y récords", _confirm_wipe))
	v.add_child(_button("Volver", _close_modal))


func _confirm_wipe() -> void:
	var v := _open_modal("¿Borrar todo?")
	v.add_child(_wrap("Se borrarán la partida guardada y los récords. No se puede deshacer."))
	v.add_child(_button("Sí, borrar", func():
		for path in [Game.SAVE_PATH, RECORDS_PATH]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		Fade.go(get_tree())))
	v.add_child(_button("Cancelar", _on_opciones))


func _on_creditos() -> void:
	var v := _open_modal("Créditos")
	var data: Dictionary = Game.load_json("res://data/menu.json")
	for pair in data["creditos"]:
		var t := _label(pair[0], 22)
		t.add_theme_color_override("font_color", Color("f5a8d8"))
		v.add_child(t)
		var d := _wrap(pair[1])
		d.modulate = Color(1, 1, 1, 0.8)
		v.add_child(d)
	v.add_child(_button("Volver", _close_modal))


func _records_text() -> String:
	var data = Game.load_json(RECORDS_PATH) if FileAccess.file_exists(RECORDS_PATH) else null
	if not data is Dictionary or data.is_empty():
		return "Todavía no has terminado ninguna partida."
	var out := []
	for cid in data:
		var r: Dictionary = data[cid]
		out.append("%s: mejor marca %d días · %d partidas · finales vistos: %d" % [
			cid.capitalize(), int(r.get("mejor_dias", 0)), int(r.get("partidas", 0)), r.get("finales", []).size()])
	return "\n".join(out)


func _sound_label() -> String:
	return "Sonido: no" if music.muted else "Sonido: sí"


# ---------------------------------------------------------------- ventanas

func _open_modal(title: String) -> VBoxContainer:
	var replacing := modal != null   # de una ventana a otra: cambio directo
	_close_modal(replacing)
	modal = ColorRect.new()
	modal.color = Color(0, 0, 0, 0.7)
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal)
	if not replacing:
		modal.modulate.a = 0.0
		create_tween().tween_property(modal, "modulate:a", 1.0, 0.18)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("231d3a")
	sb.border_color = Color("a88bf0")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(size.x - 80, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(_label(title, 30))
	return v


func _close_modal(instant := false) -> void:
	if modal:
		var old := modal
		modal = null
		if instant:
			old.queue_free()
			return
		old.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw := create_tween()
		tw.tween_property(old, "modulate:a", 0.0, 0.15)
		tw.tween_callback(old.queue_free)


func _label(text: String, font_size := 20) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	return l


func _wrap(text: String, font_size := 20) -> Label:
	var l := _label(text, font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	return b

## Fila de volumen: deslizador 0-100 % que se guarda al soltarlo.
func _volume_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := _label("Volumen", 20)
	row.add_child(l)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = roundi(music.volume * 100)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(0, 48)
	# Pista gruesa y de color, más fácil de ver y de tocar en el móvil.
	var track := StyleBoxFlat.new()
	track.bg_color = Color("343d5e")
	track.set_corner_radius_all(6)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	slider.add_theme_stylebox_override("slider", track)
	var fill := track.duplicate()
	fill.bg_color = Color("f07ac0")
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	row.add_child(slider)
	var pct := _label("%d%%" % slider.value, 20)
	pct.custom_minimum_size = Vector2(64, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(pct)
	slider.value_changed.connect(func(v):
		pct.text = "%d%%" % v
		music.set_volume(v / 100.0))
	return row
