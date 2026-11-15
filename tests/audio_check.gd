## Comprueba que las pistas de audio/ cargan y quedan en bucle.
extends SceneTree
const Music := preload("res://scripts/music.gd")
func _init() -> void:
	var m = Music.new()
	for t in ["lobby", "tienda", "final_bueno", "final_malo"]:
		var s = m._stream(t)
		print("%-12s %s  %.1f s  bucle=%s" % [t, s.get_class() if s else "NO CARGA", s.get_length() if s else 0.0, s.loop if s else "-"])
	m.free()
	quit()
