extends SceneTree
## 统一演算：先填参数，再开真实游戏画面——
## 新手引导机器人（GuideBot）点界面走完引导，接着策略机器人（PlayerBot）按作息上下线玩到目标等级。
## 全程不改真实存档：bat 传入临时 --save 等路径，策略阶段 Replay 以 worker 方式运行不写日志。
## 也可以选「后台批量」：不开画面，选中的几档强度各跑一局（AutoplayBatch.gd），跑完出对比表。
## 结果写到 tools/sim/results/<文件夹>/report.json，view.py 能打开时间轴。

const PARAMS_PATH := "user://autoplay/params.json"
const RESULTS := "res://tools/sim/results"
## 每次上线都不限时，体力用完才下线；只有「什么时候上线」不同
const INTENSITY := [
	["每天两次（8点、20点）", {"mode": "times", "times": ["08:00", "20:00"]}],
	["每天三次（8点、13点、20点）", {"mode": "times", "times": ["08:00", "13:00", "20:00"]}],
	["体力满就上线（8点到23点醒着）", {"mode": "full", "awake": ["08:00", "23:00"]}],
]
## [名字, 引导每步秒数, 引导自由阶段秒数, 策略每步秒数, 策略每帧步数]
const SPEEDS := [
	["慢：看清每一步", 0.4, 0.15, 0.25, 1],
	["正常", 0.12, 0.03, 0.0, 1],
	["快", 0.05, 0.0, 0.0, 8],
	["极速", 0.02, 0.0, 0.0, 60],
]

var params := {"mode": 0, "target": 30, "intensity": 0, "days": 60, "seed": 20261107, "events": true, "storage": true, "speed": 1,
	"kinds": 7, "detail": false}
## 种子不让填：每次开跑随机取一个（批量里各档用同一个），结果页会写出来
## 后台批量里的一局：不建界面以外的东西，结果写进这个文件夹（绝对路径）
var job_dir := ""
var out_path := ""
var form: CanvasLayer
var fields := {}
var hud: CanvasLayer
var hud_text: Label
var pause_btn: Button
var speed_btn: Button
var main
var guide_bot
var player_bot
var phase := "参数"
var t0 := 0
## 测试用：--autoplay-shots=DIR 时把参数界面、演算中、结果页各截一张
var shots := ""

func _shot(name: String) -> void:
	if shots == "": return
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(shots + "/" + name + ".png")

## 演算不放背景音乐（音效照常）；只改这次临时存档里的设置
func _mute_music() -> void:
	root.get_node("G").settings["music"] = false
	root.get_node("Sfx").refresh_music()

func _initialize() -> void:
	_mute_music.call_deferred()
	preload("res://scripts/ui/WindowFit.gd").fit.call_deferred(root)
	_load_params()
	# 测试用：--p:target=8 之类覆盖参数，--autostart 跳过参数界面
	var auto := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--autostart": auto = true
		elif arg.begins_with("--autoplay-shots="): shots = arg.trim_prefix("--autoplay-shots=")
		elif arg.begins_with("--job-dir="): job_dir = arg.trim_prefix("--job-dir=")
		elif arg.begins_with("--p:") and arg.contains("="):
			var k := arg.trim_prefix("--p:").get_slice("=", 0)
			var v := arg.get_slice("=", 1)
			if params.has(k): params[k] = (v == "true") if params[k] is bool else int(v)
	if job_dir != "": params["mode"] = 0
	if auto or job_dir != "": _launch.call_deferred()
	else: _show_form.call_deferred()

func _launch() -> void:
	# 批量里的一局由父进程传种子；其余每次随机
	var given := false
	for arg in OS.get_cmdline_user_args(): given = given or arg.begins_with("--p:seed=")
	if not given:
		randomize()
		params["seed"] = randi_range(1, 999999999)
	if int(params["mode"]) == 1:
		var batch = load("res://tools/sim/AutoplayBatch.gd").new()
		batch.params = params.duplicate(true)
		batch.theme = _theme()
		root.add_child(batch)
	else:
		_play()

# ---------------------------------------------------------------- 参数界面

func _load_params() -> void:
	if not FileAccess.file_exists(PARAMS_PATH): return
	var saved = JSON.parse_string(FileAccess.get_file_as_string(PARAMS_PATH))
	if saved is Dictionary:
		for k in saved: if params.has(k): params[k] = saved[k]

func _save_params() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PARAMS_PATH.get_base_dir()))
	var f := FileAccess.open(PARAMS_PATH, FileAccess.WRITE)
	if f != null: f.store_string(JSON.stringify(params, "\t")); f.close()

func _theme() -> Theme:
	var t := Theme.new()
	var g = root.get_node("G")
	if g.font_body != null: t.default_font = g.font_body
	t.default_font_size = 30
	for state in [["normal", "6b4a26"], ["hover", "84602f"], ["pressed", "4f3519"], ["focus", "6b4a26"]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(state[1])
		sb.border_color = Color("e0b060")
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 12; sb.content_margin_right = 12
		t.set_stylebox(state[0], "Button", sb)
		t.set_stylebox(state[0], "OptionButton", sb)
	t.set_color("font_color", "Button", Color("fff2d0"))
	return t

const GOLD := Color("ffd36a")
const INK := Color("2a1c0e")
const MUTED := Color("a8957a")

func _sb(bg: Color, radius := 16, border := Color(0, 0, 0, 0), width := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.content_margin_left = 14; sb.content_margin_right = 14
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	return sb

## 可按下的圆角块：未选中是深色描边，选中是金色
func _chip(text: String, size := 30, height := 76) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", _sb(Color("3b2e22"), 18, Color("5c4a37"), 2))
	b.add_theme_stylebox_override("hover", _sb(Color("47382a"), 18, Color("7a6248"), 2))
	b.add_theme_stylebox_override("pressed", _sb(Color("f2b84b"), 18, Color("ffe08a"), 2))
	b.add_theme_stylebox_override("hover_pressed", _sb(Color("f7c55e"), 18, Color("ffe8a0"), 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color("d9c7a6"))
	b.add_theme_color_override("font_hover_color", Color("f0e0c0"))
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_hover_pressed_color", INK)
	return b

func _round_btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(76, 76)
	b.add_theme_font_size_override("font_size", 40)
	b.add_theme_stylebox_override("normal", _sb(Color("4a3a2b"), 38, Color("7a6248"), 2))
	b.add_theme_stylebox_override("hover", _sb(Color("5a4733"), 38, Color("9a7d58"), 2))
	b.add_theme_stylebox_override("pressed", _sb(Color("f2b84b"), 38, Color("ffe08a"), 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", GOLD)
	b.add_theme_color_override("font_pressed_color", INK)
	return b

## 一张卡片：小标题 + 内容
func _card(parent: Control, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	var sb := _sb(Color("32271d"), 24, Color("4a3b2c"), 2)
	sb.content_margin_left = 24; sb.content_margin_right = 24; sb.content_margin_top = 18; sb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	if title != "":
		var l := Label.new()
		l.text = title
		l.add_theme_font_size_override("font_size", 26)
		l.add_theme_color_override("font_color", MUTED)
		box.add_child(l)
	fields["card_" + title] = panel
	return box

## 数字步进：名字  [−] 值 [+] 单位；按住连续变
func _stepper(parent: Control, label: String, key: String, lo: int, hi: int, unit: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var name := Label.new()
	name.text = label
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_font_size_override("font_size", 32)
	name.add_theme_color_override("font_color", Color("f0e2c4"))
	row.add_child(name)
	var minus := _round_btn("−")
	var value := Label.new()
	value.custom_minimum_size = Vector2(110, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 48)
	value.add_theme_color_override("font_color", GOLD)
	var plus := _round_btn("+")
	var tail := Label.new()
	tail.text = unit
	tail.custom_minimum_size = Vector2(36, 0)
	tail.add_theme_font_size_override("font_size", 28)
	tail.add_theme_color_override("font_color", MUTED)
	for n in [minus, value, plus, tail]: row.add_child(n)
	var show := func(): value.text = str(int(params[key]))
	show.call()
	for pair in [[minus, -1], [plus, 1]]:
		var btn: Button = pair[0]
		var dir: int = pair[1]
		var bump := func(): params[key] = clampi(int(params[key]) + dir, lo, hi); show.call()
		var timer := Timer.new()
		btn.add_child(timer)
		timer.timeout.connect(func(): bump.call(); timer.wait_time = 0.06)
		btn.button_down.connect(func(): bump.call(); timer.wait_time = 0.4; timer.start())
		btn.button_up.connect(func(): timer.stop())

func _refresh_form() -> void:
	var batch := int(params["mode"]) == 1
	fields["mode0"].set_pressed_no_signal(not batch)
	fields["mode1"].set_pressed_no_signal(batch)
	for i in INTENSITY.size():
		var on: bool = (int(params["kinds"]) & (1 << i) != 0) if batch else int(params["intensity"]) == i
		fields["kind%d" % i].set_pressed_no_signal(on)
	fields["intensity_hint"].text = "可多选，各跑一局对比" if batch else "每次玩到体力用完才下线"
	for k in ["events", "storage", "detail"]: fields[k].set_pressed_no_signal(bool(params[k]))
	fields["detail"].visible = batch
	fields["card_播放速度"].visible = not batch
	for i in SPEEDS.size(): fields["speed%d" % i].set_pressed_no_signal(int(params["speed"]) == i)

func _show_form() -> void:
	form = CanvasLayer.new()
	root.add_child(form)
	var bg := ColorRect.new()
	bg.color = Color("221a12")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.theme = _theme()
	form.add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 36; scroll.offset_right = -36; scroll.offset_top = 56; scroll.offset_bottom = -170
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bg.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size.x = 648
	box.add_theme_constant_override("separation", 20)
	scroll.add_child(box)
	var title := Label.new()
	title.text = "统一演算"
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_color_override("font_color", GOLD)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "机器人自动玩，看几天能到几级"
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", MUTED)
	box.add_child(sub)

	var mode := HBoxContainer.new()
	mode.add_theme_constant_override("separation", 12)
	_card(box, "").add_child(mode)
	for i in 2:
		var b := _chip(["看画面", "后台批量"][i], 32, 84)
		b.pressed.connect(func(): params["mode"] = i; _refresh_form())
		mode.add_child(b)
		fields["mode%d" % i] = b

	var goal := _card(box, "目标")
	_stepper(goal, "等级", "target", 6, 80, "级")
	_stepper(goal, "最多演算", "days", 1, 180, "天")

	var who := _card(box, "玩家")
	var kinds := HBoxContainer.new()
	kinds.add_theme_constant_override("separation", 12)
	who.add_child(kinds)
	var names := ["每天2次\n8·20点", "每天3次\n8·13·20点", "体力满就上\n8~23点"]
	for i in INTENSITY.size():
		var b := _chip(names[i], 26, 104)
		b.pressed.connect(func():
			if int(params["mode"]) == 1:
				var k := int(params["kinds"]) ^ (1 << i)
				params["kinds"] = k if k != 0 else int(params["kinds"])
			else:
				params["intensity"] = i
			_refresh_form())
		kinds.add_child(b)
		fields["kind%d" % i] = b
	var hint := Label.new()
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", MUTED)
	who.add_child(hint)
	fields["intensity_hint"] = hint

	var opts := HBoxContainer.new()
	opts.add_theme_constant_override("separation", 12)
	_card(box, "选项").add_child(opts)
	for pair in [["events", "活动"], ["storage", "储物洞"], ["detail", "时间轴"]]:
		var key: String = pair[0]
		var b := _chip(pair[1], 28, 72)
		b.pressed.connect(func(): params[key] = not bool(params[key]); _refresh_form())
		opts.add_child(b)
		fields[key] = b

	var speed := HBoxContainer.new()
	speed.add_theme_constant_override("separation", 10)
	_card(box, "播放速度").add_child(speed)
	for i in SPEEDS.size():
		var b := _chip(["慢", "正常", "快", "极速"][i], 28, 72)
		b.pressed.connect(func(): params["speed"] = i; _refresh_form())
		speed.add_child(b)
		fields["speed%d" % i] = b

	var go := Button.new()
	go.text = "开始"
	go.focus_mode = Control.FOCUS_NONE
	go.anchor_left = 0; go.anchor_right = 1; go.anchor_top = 1; go.anchor_bottom = 1
	go.offset_left = 36; go.offset_right = -36; go.offset_top = -146; go.offset_bottom = -40
	go.add_theme_font_size_override("font_size", 48)
	go.add_theme_stylebox_override("normal", _sb(Color("f2b84b"), 30, Color("ffe08a"), 3))
	go.add_theme_stylebox_override("hover", _sb(Color("f8c862"), 30, Color("fff0b0"), 3))
	go.add_theme_stylebox_override("pressed", _sb(Color("d99a2e"), 30, Color("ffe08a"), 3))
	go.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color"]: go.add_theme_color_override(c, INK)
	go.pressed.connect(_start)
	bg.add_child(go)
	_refresh_form()
	if shots != "":
		await create_timer(1.0).timeout
		await _shot("form")
		_start()

func _start() -> void:
	_save_params()
	form.queue_free()
	_launch()

# ---------------------------------------------------------------- 演算配置

func _sim_config() -> Dictionary:
	var cfg: Dictionary = {}
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://tools/sim/config.json"))
	if raw is Dictionary: cfg = raw
	cfg["runs"] = 1
	cfg["seed"] = int(params["seed"])
	cfg["stop_level"] = int(params["target"])
	cfg["cycle_days"] = int(params["days"])
	cfg["max_actions"] = 5000000
	cfg["play_events"] = bool(params["events"])
	cfg["use_storage"] = bool(params["storage"])
	cfg["start_snapshot"] = ""
	cfg["summary_only"] = job_dir != "" and not bool(params["detail"])
	cfg["schedule"] = {}
	cfg["login"] = (INTENSITY[clampi(int(params["intensity"]), 0, INTENSITY.size() - 1)][1] as Dictionary).duplicate(true)
	return cfg

## 第一天第一次上线的时刻（北京时间），新手引导从这时开始
func _first_session(cfg: Dictionary) -> int:
	var midnight := int(Time.get_unix_time_from_datetime_string(str(cfg.get("start_utc", "2026-11-02T00:00:00")))) - 28800
	midnight -= posmod(midnight + 28800, 86400)
	var login: Dictionary = cfg.get("login", {})
	var first := str((login.get("times", login.get("awake", ["08:00"])) as Array)[0]).split(":")
	return midnight + (int(first[0]) * 60 + int(first[1])) * 60

# ---------------------------------------------------------------- 演算

func _play() -> void:
	var game = root.get_node("G"); var replay = root.get_node("Replay")
	var cfg := _sim_config()
	var clock := _first_session(cfg)
	game.simulation_time = clock
	game.new_game()
	replay.meta = {}; replay.seq = 0; replay.base = 0; replay.pending = []; replay.inflight = {}
	replay.clock = clock
	# 引导用固定种子保证每次都走得通；之后的随机由参数里的种子决定
	game.random_seed = "reference-full-playthrough"; game.random_streams = {}
	replay.executing = true; replay.advance(); replay._canonicalize_live(); replay.executing = false
	game.clear_presentations()
	_mute_music()
	main = load("res://main.tscn").instantiate(); root.add_child(main)
	if job_dir == "": _build_hud()
	else: params["speed"] = SPEEDS.size() - 1
	out_path = job_dir.path_join("report.json") if job_dir != "" else ProjectSettings.globalize_path(RESULTS).path_join("autoplay-%d/report.json" % Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	t0 = Time.get_ticks_msec()
	await create_timer(0.3).timeout

	phase = "新手引导"
	guide_bot = load("res://tools/sim/GuideBot.gd").new()
	guide_bot.main = main; guide_bot.game = game; guide_bot.replay = replay
	_apply_speed()
	root.add_child(guide_bot)
	var ok: bool = await guide_bot.play()
	if not ok:
		_finish("新手引导没走完：" + (guide_bot.error.get_slice(char(10), 0) if guide_bot.error != "" else "手动停止"))
		if guide_bot.error != "": print(guide_bot.error)
		return
	if shots != "": await _shot("guide_end")
	var sfx = root.get_node("Sfx")
	print("MUSIC_PLAYING ", is_instance_valid(sfx._music) and sfx._music.playing)
	print("GUIDE_DONE lv=", game.level, " energy=", game.energy, " amber=", game.amber, " steps=", guide_bot.steps)
	await create_timer(0.6).timeout

	phase = "策略玩家"
	game.random_seed = "simulation:%d" % int(params["seed"]); game.random_streams = {}
	player_bot = load("res://tools/sim/PlayerBot.gd").new()
	player_bot.live = true
	player_bot.output = out_path
	if job_dir == "":
		player_bot.ui_main = main
	else:
		# 后台：引导走完就不要画面了，策略阶段只跑规则
		player_bot.progress_path = job_dir.path_join("progress.json")
		game.main = null
		main.queue_free()
		main = null
		await process_frame
	_apply_speed()
	root.add_child(player_bot)
	var code: int = await player_bot.run_with(cfg)
	if code != 0:
		_finish("策略玩家异常结束（代码 %d），日志见控制台" % code)
		return
	var reason := str(player_bot.finish_reason)
	var why := {"target_level": "到达目标等级", "duration_limit": "到了演算天数上限", "action_limit": "到了动作上限", "stopped": "手动停止", "invariant_failed": "状态校验失败"}
	_finish(str(why.get(reason, reason)))

func _apply_speed() -> void:
	var s: Array = SPEEDS[int(params["speed"])]
	if guide_bot != null:
		guide_bot.step_delay = float(s[1]); guide_bot.free_delay = float(s[2])
	if player_bot != null:
		player_bot.live_delay = float(s[3]); player_bot.live_batch = int(s[4])
	if speed_btn != null: speed_btn.text = "速度：" + str(s[0]).get_slice("：", 0)

# ---------------------------------------------------------------- 底部状态条

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 120
	root.add_child(hud)
	var panel := ColorRect.new()
	panel.color = Color(0.08, 0.06, 0.04, 0.82)
	panel.theme = _theme()
	panel.anchor_left = 0; panel.anchor_right = 1; panel.anchor_top = 1; panel.anchor_bottom = 1
	panel.offset_top = -150
	hud.add_child(panel)
	hud_text = Label.new()
	hud_text.position = Vector2(16, 8)
	hud_text.size = Vector2(688, 80)
	hud_text.add_theme_font_size_override("font_size", 24)
	hud_text.add_theme_color_override("font_color", Color("f4e8c8"))
	hud_text.clip_text = true
	panel.add_child(hud_text)
	var row := HBoxContainer.new()
	row.position = Vector2(16, 88)
	row.size = Vector2(688, 54)
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	pause_btn = _hud_button(row, "暂停", _toggle_pause)
	speed_btn = _hud_button(row, "速度", _next_speed)
	_hud_button(row, "停止", _stop)
	var timer := Timer.new()
	timer.wait_time = 0.2
	timer.autostart = true
	timer.timeout.connect(_update_hud)
	hud.add_child(timer)
	_apply_speed()

func _hud_button(row: HBoxContainer, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(cb)
	row.add_child(b)
	return b

func _toggle_pause() -> void:
	if player_bot == null: return
	player_bot.live_paused = not player_bot.live_paused
	pause_btn.text = "继续" if player_bot.live_paused else "暂停"

func _next_speed() -> void:
	params["speed"] = (int(params["speed"]) + 1) % SPEEDS.size()
	_apply_speed()

func _stop() -> void:
	if guide_bot != null: guide_bot.stop = true
	if player_bot != null:
		player_bot.live_stop = true
		player_bot.live_paused = false

func _clock_text() -> String:
	var g = root.get_node("G")
	var now: float = g.now()
	var tod := int(fposmod(now + 28800, 86400))
	var day := 1
	if player_bot != null and player_bot.start > 0: day = player_bot.play_day()
	return "第%d天 %02d:%02d" % [day, tod / 3600, tod / 60 % 60]

func _update_hud() -> void:
	if hud_text == null: return
	var g = root.get_node("G")
	var line1 := "%s · %s · Lv%d/目标%d · 体力%d · 琥珀%d" % [phase, _clock_text(), g.level, int(params["target"]), g.energy, g.amber]
	var line2 := ""
	if phase == "新手引导" and guide_bot != null:
		line2 = "引导步骤：" + str(g.rules.onboarding.stage().get("key", ""))
	elif player_bot != null:
		line2 = ("在线 " if player_bot.in_session else "下线 ") + str(player_bot.status)
	hud_text.text = line1 + "\n" + line2

# ---------------------------------------------------------------- 结果

## 用 view.py 在浏览器里打开时间轴（它会开一个本地小服务器窗口）
static func open_timeline(folder: String) -> void:
	var view := ProjectSettings.globalize_path("res://tools/sim/view.py")
	OS.create_process("cmd.exe", ["/c", "start", "timeline", "python", "-X", "utf8", view, folder], true)

func _finish(reason: String) -> void:
	phase = "结束"
	var g = root.get_node("G")
	var lines := PackedStringArray()
	lines.append("演算结束：" + reason)
	lines.append("最终 Lv%d，%s，用时 %d 秒（现实），随机种子 %d" % [g.level, _clock_text(), (Time.get_ticks_msec() - t0) / 1000, int(params["seed"])])
	if player_bot != null:
		lines.append("")
		lines.append("等级  到达  本级耗时  上线次数")
		for row in player_bot.level_rows:
			var spent: String = "（进行中）" if bool(row.get("partial", false)) else g.fmt_time(int(row["duration"]))
			lines.append("Lv%-3d 第%d天  %s  %d次" % [int(row["level"]), int(row["day"]), spent, int(row["sessions"])])
		lines.append("")
		lines.append("完整记录：" + out_path)
	var text := "\n".join(lines)
	print("AUTOPLAY_RESULT\n" + text)
	if job_dir != "":
		# 后台一局：成功时策略机器人已写好进度；失败把原因写进去给进度页看
		var ok := player_bot != null and str(player_bot.finish_reason) in ["target_level", "duration_limit", "action_limit"]
		if not ok:
			var f := FileAccess.open(job_dir.path_join("progress.json"), FileAccess.WRITE)
			if f != null: f.store_string(JSON.stringify({"done": true, "error": reason, "level": g.level})); f.close()
		quit(0 if ok else 1)
		return
	if hud != null: hud.queue_free()
	var layer := CanvasLayer.new()
	layer.layer = 130
	root.add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.08, 0.05, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.theme = _theme()
	layer.add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 40; scroll.offset_right = -40; scroll.offset_top = 50; scroll.offset_bottom = -150
	bg.add_child(scroll)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 640
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color("f4e8c8"))
	scroll.add_child(label)
	var row := HBoxContainer.new()
	row.anchor_left = 0; row.anchor_right = 1; row.anchor_top = 1; row.anchor_bottom = 1
	row.offset_left = 40; row.offset_right = -40; row.offset_top = -130; row.offset_bottom = -40
	row.add_theme_constant_override("separation", 20)
	bg.add_child(row)
	var again := Button.new(); again.text = "改参数再来"
	var view := Button.new(); view.text = "看时间轴"
	var quit_b := Button.new(); quit_b.text = "退出"
	view.pressed.connect(func(): open_timeline(out_path.get_base_dir()))
	view.disabled = player_bot == null
	for b in [again, view, quit_b]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 32)
		row.add_child(b)
	again.pressed.connect(func():
		OS.create_process(OS.get_executable_path(), OS.get_cmdline_args())
		quit())
	quit_b.pressed.connect(func(): quit())
	if shots != "":
		await create_timer(0.5).timeout
		await _shot("result")
	if OS.get_cmdline_user_args().has("--autoquit"): quit(0)
