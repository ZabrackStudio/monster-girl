## Corta las imágenes del menú principal y de la selección de modo en piezas (logo y botones).
## Cada pieza es una franja horizontal; los cortes se ponen en las filas más transparentes
## entre una pieza y la siguiente.
## Uso: godot --headless --path . -s res://tools/preparar_menu.gd
extends SceneTree

const SRC := "../Material/"
const SHEETS := {
	"Menú principal Proyecto Waifu.png": ["menu_logo", "menu_nueva", "menu_continuar", "menu_galeria", "menu_opciones", "menu_creditos"],
	"Menú seleccion modo de partida.png": ["modo_titulo", "modo_historia", "modo_casual", "modo_volver"],
}


func _init() -> void:
	var base := ProjectSettings.globalize_path("res://")
	for file in SHEETS:
		var img := Image.load_from_file(base.path_join(SRC + file))
		img.convert(Image.FORMAT_RGBA8)
		var names: Array = SHEETS[file]
		var cuts := _cuts(img, names.size())
		var out := []
		for i in names.size():
			var band := Rect2i(0, cuts[i], img.get_width(), cuts[i + 1] - cuts[i])
			img.get_region(band).save_png(base + "ui/%s.png" % names[i])
			out.append("%s %d-%d" % [names[i], cuts[i], cuts[i + 1]])
		print("MENU ", file, ": ", ", ".join(out))
	quit()


## Divide la imagen en `n` franjas cortando por los valles de opacidad más hondos.
func _cuts(img: Image, n: int) -> Array:
	var w := img.get_width()
	var h := img.get_height()
	var weight := PackedFloat32Array()
	weight.resize(h)
	for y in h:
		var sum := 0.0
		for x in range(0, w, 3):
			sum += img.get_pixel(x, y).a
		weight[y] = sum
	# Suaviza un poco para que el brillo no engañe.
	var smooth := PackedFloat32Array()
	smooth.resize(h)
	for y in h:
		var acc := 0.0
		var c := 0
		for k in range(maxi(0, y - 4), mini(h, y + 5)):
			acc += weight[k]
			c += 1
		smooth[y] = acc / c
	# Candidatos: mínimos locales separados al menos 120 px.
	var cands := []
	for y in range(60, h - 60):
		var is_min := true
		for k in range(y - 40, y + 41):
			if smooth[k] < smooth[y]:
				is_min = false
				break
		if is_min:
			cands.append(y)
	cands.sort_custom(func(a, b): return smooth[a] < smooth[b])
	var chosen := []
	for y in cands:
		var ok := true
		for c in chosen:
			if absi(c - y) < 120:
				ok = false
		if ok:
			chosen.append(y)
		if chosen.size() == n - 1:
			break
	chosen.sort()
	return [0] + chosen + [h]
