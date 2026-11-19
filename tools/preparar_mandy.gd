## Deja los sprites de Mandy (ratona minera) listos para el juego.
## Uso: godot --headless --path . -s res://tools/preparar_mandy.gd
extends SceneTree

const SRC := "../Material/"
const DEST := "res://personajes/ratona/trajes/"
const MOODS := ["neutral", "feliz", "triste", "cansada", "inquieta", "alterada", "critica"]
const CASUAL_H := 640   # recorte del traje casual para que la cabeza mida como en el de minera


func _init() -> void:
	var base := ProjectSettings.globalize_path("res://").path_join(SRC)
	# Minera: sprites sueltos.
	var miner := []
	for i in MOODS.size():
		miner.append(Image.load_from_file(base.path_join("ratona_minera/%02d_%s.png" % [i + 1, MOODS[i]])))
	_save_all(miner, "minera")
	# Casual años 60: viene dentro de un zip.
	var zip := ZIPReader.new()
	if zip.open(base.path_join("ratona_casual_60s_7_expresiones_godot.zip")) != OK:
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
