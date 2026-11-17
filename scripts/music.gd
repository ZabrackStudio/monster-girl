## Música de fondo con fundido entre pistas, volumen y botón de silencio.
## Busca res://audio/<pista>.mp3, .ogg o .wav (Ogg Vorbis; Godot no lee Ogg Opus).
## Si una pista no existe, simplemente no suena nada.
extends Node

const VOLUME_DB := -6.0
const FADE := 0.9
const PREFS_PATH := "user://ajustes.json"

var players: Array[AudioStreamPlayer] = []
var active := 0
var current := ""
var target := ""
var muted := false
var volume := 0.8          # 0..1, volumen general (bus Master)
var tween: Tween
var cache := {}


func _ready() -> void:
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		players.append(p)
	var f := FileAccess.open(PREFS_PATH, FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			muted = bool(d.get("silencio", false))
			volume = clampf(float(d.get("volumen", volume)), 0.0, 1.0)
	AudioServer.set_bus_mute(0, muted)
	_apply_volume()


## Pide una pista. El cambio se aplica al final del frame, así varias
## peticiones seguidas (cerrar y abrir ventanas) no provocan saltos.
func play(track: String) -> void:
	target = track


func toggle_mute() -> bool:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	_save()
	return muted


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	_apply_volume()
	_save()


func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))


func _save() -> void:
	var f := FileAccess.open(PREFS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"silencio": muted, "volumen": volume}))


func _process(_delta: float) -> void:
	if target != current:
		_switch(target)


func _stream(track: String) -> AudioStream:
	if cache.has(track):
		return cache[track]
	var s: AudioStream = null
	for ext in ["mp3", "ogg", "wav"]:
		var path := "res://audio/%s.%s" % [track, ext]
		if ResourceLoader.exists(path):
			s = load(path)
			if s is AudioStreamWAV:
				s.loop_mode = AudioStreamWAV.LOOP_FORWARD
				s.loop_end = int(s.get_length() * s.mix_rate)
			elif "loop" in s:
				s.loop = true
			break
	cache[track] = s
	return s


func _switch(track: String) -> void:
	current = track
	var old := players[active]
	active = 1 - active
	var nw := players[active]
	if tween:
		tween.kill()
	tween = create_tween().set_parallel()
	tween.tween_property(old, "volume_db", -60.0, FADE)
	var s := _stream(track)
	if s:
		nw.stream = s
		nw.volume_db = -40.0
		nw.play()
		tween.tween_property(nw, "volume_db", VOLUME_DB, FADE)
	tween.chain().tween_callback(func():
		if players[active] != old:
			old.stop())
