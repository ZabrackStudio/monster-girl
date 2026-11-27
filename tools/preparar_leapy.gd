## Deja los sprites, el cuarto y el ícono de Leapy (leoparda de las nieves) listos para el juego.
## Uso: godot --headless --path . -s res://tools/preparar_leapy.gd
extends SceneTree

const SRC := "../Material/Leapy/"
const DEST := "res://personajes/leoparda/"
const MOODS := ["neutral", "feliz", "triste", "cansada", "inquieta", "alterada", "critica"]
const CANVAS := Vector2i(1087, 1447)             # lienzo de casi todas las expresiones
const BODY_H := 900                              # se corta a la altura del cinturón, como las otras
const ROOM_RECT := Rect2i(0, 370, 941, 644)      # franja con los pósteres, el sofá y el tocadiscos
const FACE_RECT := Rect2i(475, 135, 290, 290)    # cara y orejas para el ícono de la barra de lujuria


func _init() -> void:
	var base := ProjectSettings.globalize_path("res://").path_join(SRC)
	var images := []
	for i in MOODS.size():
		var img := Image.load_from_file(base.path_join("%02d_%s.png" % [i + 1, MOODS[i]]))
		images.append(_fit(img).get_region(Rect2i(0, 0, CANVAS.x, BODY_H)))
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
		print("LEAPY ", MOODS[i], " ", out.get_size())
	var room := Image.load_from_file(base.path_join("Dormitorio Leapy.png"))
	room = room.get_region(ROOM_RECT)
	room.resize(952, roundi(952.0 * ROOM_RECT.size.y / ROOM_RECT.size.x), Image.INTERPOLATE_LANCZOS)
	room.save_png(ProjectSettings.globalize_path(DEST + "fondo.png"))
	var face := Image.load_from_file(base.path_join("01_neutral.png")).get_region(FACE_RECT)
	face.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	face.save_png(ProjectSettings.globalize_path(DEST + "icono.png"))
	print("LEAPY cuarto e ícono listos")
	quit()


## Algunas expresiones vienen en otro lienzo: se escalan al ancho común y se alinean por arriba.
func _fit(img: Image) -> Image:
	img.convert(Image.FORMAT_RGBA8)
	if img.get_size() == CANVAS:
		return img
	var h := roundi(float(img.get_height()) * CANVAS.x / img.get_width())
	img.resize(CANVAS.x, h, Image.INTERPOLATE_LANCZOS)
	var out := Image.create(CANVAS.x, CANVAS.y, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, Rect2i(0, 0, CANVAS.x, mini(h, CANVAS.y)), Vector2i.ZERO)
	return out
