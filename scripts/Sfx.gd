extends Node
## 程序合成的音效与背景鼓点（autoload: Sfx）

const RATE := 22050
var _streams := {}
var _players: Array = []
var _music: AudioStreamPlayer

func _ready() -> void:
	_streams["tap"] = _make(_wood, 0.09)
	_streams["pop"] = _make(_pop, 0.22)
	_streams["merge"] = _make(_merge, 0.35)
	_streams["coin"] = _make(_coin, 0.3)
	_streams["whoosh"] = _make(_whoosh, 0.3)
	_streams["drum"] = _make(_drum, 0.35)
	_streams["fanfare"] = _make(_fanfare, 1.2)
	_streams["deny"] = _make(_deny, 0.25)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -8.0
	add_child(_music)
	_music.stream = _load_music()
	call_deferred("refresh_music")

func play(name: String, pitch: float = 1.0) -> void:
	if not G.settings.get("sound", true) or not _streams.has(name):
		return
	for p in _players:
		if not p.playing:
			p.stream = _streams[name]
			p.pitch_scale = pitch
			p.play()
			return

func refresh_music() -> void:
	if G.settings.get("music", true):
		if not _music.playing:
			_music.play()
	else:
		_music.stop()

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
