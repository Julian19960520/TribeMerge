extends Node
## 程序合成的音效与背景鼓点（autoload: Sfx）

const RATE := 22050
var _streams := {}
var _players: Array = []
var _music: AudioStreamPlayer

const VisualRuntime := preload("res://scripts/resources/VisualRuntime.gd")
const EFFECTS := {"tap": ["_wood", 0.09], "pop": ["_pop", 0.22], "merge": ["_merge", 0.35],
	"coin": ["_coin", 0.3], "whoosh": ["_whoosh", 0.3], "drum": ["_drum", 0.35],
	"fanfare": ["_fanfare", 1.2], "deny": ["_deny", 0.25], "crumble": ["_crumble", 0.32]}
var _enabled := false

func _ready() -> void:
	_enabled = VisualRuntime.enabled() and DisplayServer.get_name() != "headless"
	if _enabled:
		call_deferred("refresh_music")

func _ensure_players() -> void:
	if not _players.is_empty(): return
	for i in 8:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)

func play(name: String, pitch: float = 1.0) -> void:
	if not _enabled or not G.settings.get("sound", true) or not EFFECTS.has(name):
		return
	if not _streams.has(name):
		var spec: Array = EFFECTS[name]
		_streams[name] = _make(Callable(self, str(spec[0])), float(spec[1]))
	_ensure_players()
	for player in _players:
		if not player.playing:
			player.stream = _streams[name]
			player.pitch_scale = pitch
			player.play()
			return

func refresh_music() -> void:
	if not _enabled: return
	if not G.settings.get("music", true):
		if is_instance_valid(_music): _music.stop()
		return
	if not is_instance_valid(_music):
		_music = AudioStreamPlayer.new()
		_music.volume_db = -8.0
		_music.stream = _load_music()
		add_child(_music)
	if _music.stream != null and not _music.playing:
		_music.play()

func _make(fn: Callable, dur: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var v: float = clampf(fn.call(t), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s

static func _env(t: float, a: float, d: float) -> float:
	if t < a:
		return t / a
	return exp(-(t - a) / d)

func _wood(t: float) -> float:
	return (sin(TAU * 820.0 * t) * 0.6 + sin(TAU * 1340.0 * t) * 0.3) * _env(t, 0.002, 0.018)

func _pop(t: float) -> float:
	var f := 380.0 + 900.0 * t
	return sin(TAU * f * t) * _env(t, 0.004, 0.05) * 0.8

func _merge(t: float) -> float:
	var a := sin(TAU * 523.0 * t) * _env(t, 0.003, 0.08)
	var b := sin(TAU * 784.0 * t) * _env(maxf(0.0, t - 0.07), 0.003, 0.12) * float(t > 0.07)
	return (a + b) * 0.55 + _wood(t) * 0.3

func _coin(t: float) -> float:
	var a := sin(TAU * 1568.0 * t) * _env(t, 0.002, 0.06)
	var b := sin(TAU * 2093.0 * t) * _env(maxf(0.0, t - 0.06), 0.002, 0.1) * float(t > 0.06)
	return (a + b) * 0.4

func _whoosh(t: float) -> float:
	return (randf() * 2.0 - 1.0) * sin(PI * t / 0.3) * 0.25

func _drum(t: float) -> float:
	var f := 140.0 * exp(-t * 8.0) + 60.0
	return sin(TAU * f * t) * _env(t, 0.003, 0.12) * 0.9

func _deny(t: float) -> float:
	return sin(TAU * 180.0 * t) * _env(t, 0.003, 0.08) * 0.6

func _crumble(t: float) -> float:
	var f := 70.0 * exp(-t * 16.0) + 36.0
	var thud := sin(TAU * f * t) * _env(t, 0.002, 0.08)
	var grit := (randf() * 2.0 - 1.0) * _env(t, 0.001, 0.09) * 0.65
	var crack := sin(TAU * 960.0 * t) * _env(t, 0.001, 0.015) * 0.4
	return thud * 0.75 + grit + crack

func _kalimba(t: float, f: float) -> float:
	if t < 0.0:
		return 0.0
	return (sin(TAU * f * t) + 0.3 * sin(TAU * f * 5.4 * t) * exp(-t * 30.0)) * _env(t, 0.003, 0.35)

func _fanfare(t: float) -> float:
	var notes := [523.25, 659.25, 783.99, 1046.5]
	var v := 0.0
	for i in 4:
		v += _kalimba(t - float(i) * 0.12, notes[i]) * 0.35
	return v + _drum(t) * 0.4

func _load_music() -> AudioStream:
	var s := load("res://assets/audio/bgm.mp3") as AudioStreamMP3
	if s:
		s.loop = true
	return s
