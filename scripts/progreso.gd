## Avance en el Proyecto Waifu: mejor nota con cada asignada y qué expedientes están abiertos.
## Se guarda aparte de la partida en curso, en user://proyecto.json.
extends RefCounted

const PATH := "user://proyecto.json"
const PROJECT := "res://data/proyecto.json"


static func project() -> Dictionary:
	var f := FileAccess.open(PROJECT, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) if f else {}


static func load_progress() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {"notas": {}}
	var f := FileAccess.open(PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f else null
	return d if d is Dictionary and d.has("notas") else {"notas": {}}


static func grade_rank(p: Dictionary, grade: String) -> int:
	for i in p["calificaciones"].size():
		if p["calificaciones"][i]["nota"] == grade:
			return i
	return 99


## Guarda la nota si mejora la anterior. Devuelve true si es la mejor hasta ahora.
static func record_grade(character_id: String, grade: String) -> bool:
	var p := project()
	var prog := load_progress()
	var old: String = prog["notas"].get(character_id, "")
	if old != "" and grade_rank(p, old) <= grade_rank(p, grade):
		return false
	prog["notas"][character_id] = grade
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(prog, "\t"))
	return true


static func passed(p: Dictionary, prog: Dictionary, index: int) -> bool:
	var a: Dictionary = p["expedientes"][index]
	var g: String = prog["notas"].get(a["personaje"], "")
	return g != "" and grade_rank(p, g) <= grade_rank(p, a.get("aprobar", "C"))


## Un expediente se abre al aprobar el anterior.
static func unlocked(p: Dictionary, prog: Dictionary, index: int) -> bool:
	return index == 0 or passed(p, prog, index - 1)


## Fondos extra al empezar: los gana la mejor nota de la asignación anterior.
static func funds_for(character_id: String) -> int:
	var p := project()
	var prog := load_progress()
	for i in p["expedientes"].size():
		if p["expedientes"][i]["personaje"] == character_id and i > 0:
			var g: String = prog["notas"].get(p["expedientes"][i - 1]["personaje"], "")
			for c in p["calificaciones"]:
				if c["nota"] == g:
					return int(c.get("fondos", 0))
	return 0


## Índice del expediente que sigue a esta asignada, o -1 si es la última.
static func next_index(character_id: String) -> int:
	var p := project()
	for i in p["expedientes"].size():
		if p["expedientes"][i]["personaje"] == character_id:
			return i + 1 if i + 1 < p["expedientes"].size() else -1
	return -1


static func character_name(character_id: String) -> String:
	var f := FileAccess.open("res://data/personajes/%s.json" % character_id, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f else null
	return d["nombre"] if d is Dictionary else character_id.capitalize()
