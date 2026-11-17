## Fundido a negro entre pantallas. Es un autoload: dura entre escenas.
extends CanvasLayer

const OUT := 0.35
const IN := 0.45

var rect: ColorRect
var busy := false


func _ready() -> void:
	layer = 100
	rect = ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	# Al abrir el juego, aparece desde negro.
	_fade_from_black()


## Cambia de escena con fundido. Con path vacío, recarga la actual.
func ir(path: String = "") -> void:
	if busy:
		return
	busy = true
	rect.mouse_filter = Control.MOUSE_FILTER_STOP   # nada de toques a mitad del fundido
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 1.0, OUT)
	await tw.finished
	if path == "":
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	busy = false
	_fade_from_black()


func _fade_from_black() -> void:
	rect.color.a = 1.0
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 0.0, IN)
	tw.tween_callback(func(): rect.mouse_filter = Control.MOUSE_FILTER_IGNORE)


## Cambio de escena desde cualquier script; sin el autoload (pruebas), cambia directo.
static func go(tree: SceneTree, path: String = "") -> void:
	var t = tree.root.get_node_or_null("Transicion")
	if t:
		t.ir(path)
	elif path == "":
		tree.reload_current_scene()
	else:
		tree.change_scene_to_file(path)
