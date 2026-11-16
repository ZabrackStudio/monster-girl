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
## Hojas de expresiones -> carpeta del traje. Columnas en el orden de MOODS.
const SHEETS := {
	"Hoja de expresiones de chica slime ropa inical": "inicial",
	"Hoja de expresiones de chica slime casual 1": "casual",
	"Hoja de expresiones de chica slime vestido 1": "vestido_blanco",
	"Hoja de expresiones de chica slime vestido 2": "vestido_lila",
}
const MOODS := ["neutral", "feliz", "triste", "cansada", "inquieta", "alterada", "critica"]
const CUT := 0.84   # fracción de altura que se conserva (corta a la altura de la cintura)


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

	# Hojas de expresiones: 7 columnas, una por estado, recortadas a la cintura.
	for sheet in SHEETS:
		var src := Image.load_from_file(base + SRC + sheet + ".png")
		var had_alpha := src.detect_alpha() != Image.ALPHA_NONE
		src.convert(Image.FORMAT_RGBA8)
		if not had_alpha:
			_remove_dark_bg(src)
		var dir := "personajes/slime/trajes/%s/" % SHEETS[sheet]
		DirAccess.make_dir_recursive_absolute(base + dir)
		var col_w := src.get_width() / MOODS.size()
		for i in MOODS.size():
			var frame := src.get_region(Rect2i(i * col_w, 0, col_w, int(src.get_height() * CUT)))
			_isolate(frame)
			frame.save_png(base + dir + MOODS[i] + ".png")
		print(dir, " ", MOODS.size(), " expresiones ", col_w, "x", int(src.get_height() * CUT))

	# Tienda: almacén de fondo (ya con los guardias) y la intendente.
	var alm := Image.load_from_file(base + SRC + "almacen.png")
	alm.resize(854, 1280, Image.INTERPOLATE_LANCZOS)
	alm.save_png(base + "ui/tienda_fondo.png")
	var chica_s := Image.load_from_file(base + SRC + "chica soldado.png")
	chica_s.convert(Image.FORMAT_RGBA8)
	_trim_alpha(chica_s, 90, 200)
	_keep_largest(chica_s)
	chica_s = chica_s.get_region(chica_s.get_used_rect())
	_fit_height(chica_s, 900)
	chica_s.save_png(base + "ui/tienda_vendedora.png")
	print("tienda_vendedora ", chica_s.get_size())
	quit()


## Quita el halo semitransparente: lo muy transparente fuera; rampa suave hasta lo opaco.
func _trim_alpha(img: Image, lo: int, hi: int) -> void:
	var data := img.get_data()
	for i in range(3, data.size(), 4):
		var a := data[i]
		data[i] = 0 if a <= lo else (255 if a >= hi else int(255.0 * (a - lo) / (hi - lo)))
	img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data)


## Deja solo la figura más grande (borra motas y restos sueltos).
func _keep_largest(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var label := PackedInt32Array()
	label.resize(w * h)
	var sizes := [0]
	for start in w * h:
		if label[start] != 0 or data[start * 4 + 3] < 20:
			continue
		var id := sizes.size()
		sizes.append(0)
		var stack := PackedInt32Array([start])
		label[start] = id
		while not stack.is_empty():
			var i: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			sizes[id] += 1
			var x := i % w
			for n in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w]:
				if n >= 0 and n < w * h and label[n] == 0 and data[n * 4 + 3] >= 20:
					label[n] = id
					stack.append(n)
	var main := 1
	for id in range(1, sizes.size()):
		if sizes[id] > sizes[main]:
			main = id
	for i in w * h:
		if label[i] != main:
			data[i * 4 + 3] = 0
	img.set_data(w, h, false, Image.FORMAT_RGBA8, data)


func _fit_height(img: Image, h: int) -> void:
	img.resize(int(img.get_width() * float(h) / img.get_height()), h, Image.INTERPOLATE_LANCZOS)


## Quita un fondo oscuro con relleno desde los bordes, para no comerse
## los contornos negros del dibujo.
func _remove_dark_bg(img: Image, lim := 18, soft := 48) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack := PackedInt32Array()
	for x in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)
	while not stack.is_empty():
		var i: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		if seen[i]:
			continue
		seen[i] = 1
		var o := i * 4
		var m := maxi(data[o], maxi(data[o + 1], data[o + 2]))
		if m > soft:
			continue
		data[o + 3] = 0 if m <= lim else int(255.0 * (m - lim) / (soft - lim))
		if m > lim:
			continue
		var x := i % w
		var y := i / w
		if x > 0: stack.append(i - 1)
		if x < w - 1: stack.append(i + 1)
		if y > 0: stack.append(i - w)
		if y < h - 1: stack.append(i + w)
	# Bolsas de fondo encerradas entre mechones: el negro puro también fuera.
	for i in w * h:
		var o := i * 4
		if maxi(data[o], maxi(data[o + 1], data[o + 2])) <= 10:
			data[o + 3] = 0
	img.set_data(w, h, false, Image.FORMAT_RGBA8, data)


## Deja el personaje y borra los trozos de las columnas vecinas: zonas
## opacas que tocan el borde izquierdo o derecho y no son la figura principal.
func _isolate(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var label := PackedInt32Array()
	label.resize(w * h)
	var sizes := [0]
	var edge := [false]
	for start in w * h:
		if label[start] != 0 or data[start * 4 + 3] < 20:
			continue
		var id := sizes.size()
		sizes.append(0)
		edge.append(false)
		var stack := PackedInt32Array([start])
		label[start] = id
		while not stack.is_empty():
			var i: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			sizes[id] += 1
			var x := i % w
			if x == 0 or x == w - 1:
				edge[id] = true
			for n in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w]:
				if n >= 0 and n < w * h and label[n] == 0 and data[n * 4 + 3] >= 20:
					label[n] = id
					stack.append(n)
	var main := 1
	for id in range(1, sizes.size()):
		if sizes[id] > sizes[main]:
			main = id
	for i in w * h:
		var id := label[i]
		if id != 0 and id != main and edge[id]:
			data[i * 4 + 3] = 0
	img.set_data(w, h, false, Image.FORMAT_RGBA8, data)


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
