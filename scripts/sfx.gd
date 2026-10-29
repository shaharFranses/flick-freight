class_name Sfx
extends Node
## Sound effects pool + looping music. Access through Sfx.play("name").

static var inst: Sfx = null

const SOUNDS = {
	"hit_wood": "res://audio/v2/hit_wood.ogg",
	"hit_wood_light": "res://audio/v2/hit_wood_light.ogg",
	"hit_metal": "res://audio/v2/hit_metal.ogg",
	"break": "res://audio/v2/break.ogg",
	"thud": "res://audio/v2/thud.ogg",
	"rim": "res://audio/v2/rim.ogg",
	"click": "res://audio/v2/click.ogg",
	"deliver": "res://audio/v2/deliver.ogg",
	"fail": "res://audio/v2/fail.ogg",
	"conveyor": "res://audio/v2/conveyor.ogg",
	"win": "res://audio/v2/win.ogg",
	"lose": "res://audio/v2/lose.ogg",
	"truck_full": "res://audio/v2/truck_full.ogg",
	"honk": "res://audio/honk.wav",
	"whoosh": "res://audio/whoosh.wav",
	"snap": "res://audio/snap.wav",
	"boing": "res://audio/v2/boing.wav",
	"splash": "res://audio/v2/splash.wav",
	"pop": "res://audio/v2/pop.wav",
	"rotor": "res://audio/v2/rotor.wav",
}
const MUSIC = "res://audio/v2/music_loop.ogg"
const MUSIC_DB = -15.0

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var music: AudioStreamPlayer
var muted := false


func _ready():
	inst = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in SOUNDS:
		_streams[k] = load(SOUNDS[k])
	for i in 10:
		var p = AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	music = AudioStreamPlayer.new()
	var m = load(MUSIC)
	if m is AudioStreamOggVorbis:
		m.loop = true
	music.stream = m
	music.volume_db = MUSIC_DB
	add_child(music)
	set_muted(SaveData.get_flag("muted", false))


static func play(n: String, vol_db := 0.0, pitch := 1.0):
	if inst == null or not inst._streams.has(n):
		return
	var p = inst._pool[inst._next]
	inst._next = (inst._next + 1) % inst._pool.size()
	p.stream = inst._streams[n]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


## Plays the world's loop (each expansion world has its own; see WORLDS.music).
static func start_music(path := MUSIC):
	if inst == null:
		return
	if inst.music.stream == null or inst.music.stream.resource_path != path:
		var m = load(path)
		if m is AudioStreamOggVorbis:
			m.loop = true
		inst.music.stream = m
		inst.music.play()
	elif not inst.music.playing:
		inst.music.play()


func set_muted(v: bool):
	muted = v
	AudioServer.set_bus_mute(0, v)
	SaveData.set_flag("muted", v)


func toggle_mute() -> bool:
	set_muted(not muted)
	return muted
