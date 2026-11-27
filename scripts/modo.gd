## Selección de modo: historia (los expedientes, con plazo y evaluación) o casual (hasta perder).
extends Control

const Fade := preload("res://scripts/transicion.gd")
const Music := preload("res://scripts/music.gd")
const ImageMenu := preload("res://scripts/menu_imagen.gd")


func _ready() -> void:
	var music = get_node_or_null("/root/Musica")
	if music == null:
		music = Music.new()
		add_child(music)
	music.play("menu")
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
	ImageMenu.build(self, ["modo_titulo", "modo_historia", "modo_casual", "modo_volver"], {
		"modo_historia": _pick.bind("historia"),
		"modo_casual": _pick.bind("casual"),
		"modo_volver": func(): Fade.go(get_tree(), "res://scenes/menu.tscn"),
	})


func _pick(mode: String) -> void:
	Engine.set_meta("modo", mode)
	Fade.go(get_tree(), "res://scenes/expedientes.tscn")
