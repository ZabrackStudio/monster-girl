## Deja los sprites de Mandy (ratona minera) listos para el juego.
## Uso: godot --headless --path . -s res://tools/preparar_mandy.gd
extends SceneTree

const SRC := "../Material/"
const DEST := "res://personajes/ratona/trajes/"
const MOODS := ["neutral", "feliz", "triste", "cansada", "inquieta", "alterada", "critica"]
const CASUAL_H := 640   # recorte del traje casual para que la cabeza mida como en el de minera
const ROOM_RECT := Rect2i(0, 150, 1024, 700)   # franja del cuarto que se ve detrás de ella


func _init() -> void:
	var base := ProjectSettings.globalize_path("res://").path_join(SRC)
	# Minera: sprites sueltos.
	var miner := []
	for i in MOODS.size():
		miner.append(Image.load_from_file(base.path_join("Mandy/%02d_%s.png" % [i + 1, MOODS[i]])))
	_save_all(miner, "minera")
	# Casual años 60: viene dentro de un zip.
	var zip := ZIPReader.new()
	if zip.open(base.path_join("Mandy/ratona_casual_60s_7_expresiones_godot.zip")) != OK:
		push_error("No se pudo abrir el zip del traje casual")
		quit()
		return
	var casual := []
	for i in MOODS.size():
		var img := Image.new()
		img.load_png_from_buffer(zip.read_file("ratona_casual_60s/%02d_%s.png" % [i + 1, MOODS[i]]))
		casual.append(img.get_region(Rect2i(0, 0, img.get_width(), mini(CASUAL_H, img.get_height()))))
	zip.close()
	_save_all(casual, "casual60")
	# Su cuarto: la ilustración es vertical; se toma la franja con el mapa, la lámpara y los frascos.
	var room := Image.load_from_file(base.path_join("Mandy/Dormitorio Mandy.png"))
	room = room.get_region(ROOM_RECT)
	room.resize(952, roundi(952.0 * ROOM_RECT.size.y / ROOM_RECT.size.x), Image.INTERPOLATE_LANCZOS)
	room.save_png(ProjectSettings.globalize_path("res://personajes/ratona/fondo.png"))
	# Ícono de la barra de lujuria: su cara de ratona, recortada y en un cuadro de 128 px.
	var icon := Image.load_from_file(base.path_join("Mandy/Mandy icono.png"))
	icon.convert(Image.FORMAT_RGBA8)
	var r := Rect2i()
	for y in icon.get_height():
		for x in icon.get_width():
			if icon.get_pixel(x, y).a > 0.5:
				r = Rect2i(x, y, 1, 1) if r.size == Vector2i.ZERO else r.expand(Vector2i(x, y))
	icon = icon.get_region(r.grow(2))
	var side := maxi(icon.get_width(), icon.get_height())
	var square := Image.create(side, side, false, Image.FORMAT_RGBA8)
	square.blit_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), Vector2i((side - icon.get_width()) / 2, (side - icon.get_height()) / 2))
	square.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	square.save_png(ProjectSettings.globalize_path("res://personajes/ratona/icono.png"))
	quit()


## Recorta todas las expresiones con el mismo rectángulo para que no salten al cambiar.
func _save_all(images: Array, outfit: String) -> void:
	var rect: Rect2i = images[0].get_used_rect()
	for img in images:
		rect = rect.merge(img.get_used_rect())
	for i in images.size():
		_save(images[i].get_region(rect), outfit, MOODS[i])


func _save(img: Image, outfit: String, mood: String) -> void:
	var dir := DEST + outfit
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	img.save_png(ProjectSettings.globalize_path("%s/%s.png" % [dir, mood]))
	print("MANDY ", outfit, "/", mood, " ", img.get_size())
