## Recorta las imágenes generadas de ../Material y las deja listas para el juego.
## Uso: godot --headless --path . -s res://tools/preparar_assets.gd
extends SceneTree

const SRC := "../Material/"

## Recortes del kit de interfaz (coordenadas aproximadas; luego se ajustan al contenido).
const KIT := {
	"btn_trabajar": Rect2i(95, 15, 385, 265),
	"btn_comer": Rect2i(482, 15, 375, 265),
	"btn_pasear": Rect2i(862, 15, 370, 265),
	"btn_jugar": Rect2i(1235, 15, 385, 265),
	"btn_limpiar": Rect2i(95, 282, 385, 280),
	"btn_tienda": Rect2i(478, 282, 380, 280),
	"btn_objetos": Rect2i(858, 282, 378, 280),
	"btn_dormir": Rect2i(1237, 282, 383, 280),
	"bocadillo": Rect2i(45, 568, 950, 222),
	"marco": Rect2i(1000, 575, 640, 350),
	"gota": Rect2i(55, 795, 128, 120),
}
const HALF := ["bocadillo", "marco"]


func _init() -> void:
	var base := ProjectSettings.globalize_path("res://")
	DirAccess.make_dir_recursive_absolute(base + "ui")
	DirAccess.make_dir_recursive_absolute(base + "personajes/slime")

	# Kit de interfaz: recorte, ajuste al contenido y fondo transparente.
	var kit := Image.load_from_file(base + SRC + "Kit de interfaz kawaii con limos brillantes.png")
	kit.convert(Image.FORMAT_RGBA8)
	var bg := _avg(kit, Rect2i(2, 2, 12, 12))
	for name in KIT:
		var img := kit.get_region(KIT[name])
		img = img.get_region(_content(img, bg, 0.12))
		_key(img, bg, 0.05, 0.16)
		if name in HALF:
			img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_LANCZOS)
		img.save_png(base + "ui/%s.png" % name)
		print("ui/%s.png %s" % [name, img.get_size()])

	# Retrato: de la cabeza a debajo de la falda, sin márgenes vacíos.
	var chica := Image.load_from_file(base + SRC + "Chica espíritu de limo esmeralda.png")
	chica.convert(Image.FORMAT_RGBA8)
	var r := chica.get_region(Rect2i(0, 0, chica.get_width(), 880))
	r = r.get_region(r.get_used_rect())
	r.save_png(base + "personajes/slime/retrato.png")
	print("retrato ", r.get_size())

	# Fondo: el dormitorio recortado a la proporción del panel del retrato.
	var cuarto := Image.load_from_file(base + SRC + "Dormitorio acogedor de fantasía slime.png")
	var h := cuarto.get_height()
	var w := int(h * 1.35)
	var f := cuarto.get_region(Rect2i(140, 0, w, h))
	f.resize(int(w * 0.75), int(h * 0.75), Image.INTERPOLATE_LANCZOS)
	f.save_png(base + "personajes/slime/fondo.png")
	print("fondo ", f.get_size())
	quit()


func _avg(img: Image, rect: Rect2i) -> Color:
	var c := Color(0, 0, 0)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			c += img.get_pixel(x, y)
	return c / float(rect.get_area())


func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


## Rectángulo que contiene todo lo que no es fondo.
func _content(img: Image, bg: Color, thr: float) -> Rect2i:
	var minp := Vector2i(img.get_width(), img.get_height())
	var maxp := Vector2i(-1, -1)
	for y in img.get_height():
		for x in img.get_width():
			if _dist(img.get_pixel(x, y), bg) > thr:
				minp = Vector2i(mini(minp.x, x), mini(minp.y, y))
				maxp = Vector2i(maxi(maxp.x, x), maxi(maxp.y, y))
	if maxp.x < 0:
		return Rect2i(Vector2i.ZERO, img.get_size())
	return Rect2i(minp, maxp - minp + Vector2i.ONE).grow(4).intersection(Rect2i(Vector2i.ZERO, img.get_size()))


## Vuelve transparente el fondo con un borde suave.
func _key(img: Image, bg: Color, t0: float, t1: float) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			c.a *= clampf((_dist(c, bg) - t0) / (t1 - t0), 0.0, 1.0)
			img.set_pixel(x, y, c)
