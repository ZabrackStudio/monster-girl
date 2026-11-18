## Deja las ilustraciones de los finales de ../Material listas para el juego (720x1280).
## Uso: godot --headless --path . -s res://tools/preparar_finales.gd
extends SceneTree

const SRC := "../Material/"
const DEST := "res://ui/finales/"
const SIZE := Vector2i(720, 1280)
const IMAGES := {
	"poseida": "Reme final poseida.png",
	"lucha": "Reme lo intento.png",
	"carnal": "Reme disuelto.png",
	"denuncia": "Reme denuncia.png",
	"marea": "Reme marea interior.png",
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST))
	var base := ProjectSettings.globalize_path("res://").path_join(SRC)
	for id in IMAGES:
		var img := Image.load_from_file(base.path_join(IMAGES[id]))
		if img == null or img.is_empty():
			push_error("No se pudo leer " + IMAGES[id])
			continue
		img.convert(Image.FORMAT_RGB8)
		img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
		img.save_png(ProjectSettings.globalize_path(DEST + id + ".png"))
		print("FINAL ", id, " listo")
	quit()
