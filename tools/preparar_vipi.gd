## Deja los sprites, el cuarto y el ícono de Vipi (dragona) listos para el juego.
## Uso: godot --headless --path . -s res://tools/preparar_vipi.gd
extends SceneTree

const SRC := "../Material/Vipi Lweed/"
const DEST := "res://personajes/dragona/"
const MOODS := ["neutral", "feliz", "triste", "cansada", "inquieta", "alterada", "critica"]
const BODY_H := 880                              # se corta a la altura de la cadera, como las otras
const ROOM_RECT := Rect2i(0, 380, 941, 644)      # franja con la lámpara, la banca, la ventana y el té
const FACE_RECT := Rect2i(420, 90, 330, 330)     # cara y cuernos para el ícono de la barra de lujuria


func _init() -> void:
	var base := ProjectSettings.globalize_path("res://").path_join(SRC)
	var images := []
	for i in MOODS.size():
		var img := Image.load_from_file(base.path_join("%02d_%s.png" % [i + 1, MOODS[i]]))
		images.append(img.get_region(Rect2i(0, 0, img.get_width(), mini(BODY_H, img.get_height()))))
	# Mismo recorte para todas las expresiones, así no saltan al cambiar.
	var rect: Rect2i = images[0].get_used_rect()
	for img in images:
		rect = rect.merge(img.get_used_rect())
	var dir := DEST + "trajes/inicial"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for i in images.size():
		var out: Image = images[i].get_region(rect)
		out.resize(roundi(out.get_width() * 0.6), roundi(out.get_height() * 0.6), Image.INTERPOLATE_LANCZOS)
		out.save_png(ProjectSettings.globalize_path("%s/%s.png" % [dir, MOODS[i]]))
		print("VIPI ", MOODS[i], " ", out.get_size())
	var room := Image.load_from_file(base.path_join("Dormitorio Vipi.png"))
	room = room.get_region(ROOM_RECT)
	room.resize(952, roundi(952.0 * ROOM_RECT.size.y / ROOM_RECT.size.x), Image.INTERPOLATE_LANCZOS)
	room.save_png(ProjectSettings.globalize_path(DEST + "fondo.png"))
	var face := Image.load_from_file(base.path_join("01_neutral.png")).get_region(FACE_RECT)
	face.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	face.save_png(ProjectSettings.globalize_path(DEST + "icono.png"))
	print("VIPI cuarto e ícono listos")
	quit()
