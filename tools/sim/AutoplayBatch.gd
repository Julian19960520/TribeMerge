extends CanvasLayer
## 统一演算的「后台批量」：不开画面，选中的每档强度各开一个后台 Godot 进程同时跑，用同一个随机种子。
## 每个进程跑 autoplay.gd 的单局（--job-dir），一样先走真实新手引导再交给策略机器人；
## 这里只排队、看进度、汇总。每局用自己的临时存档，不碰真实存档。

const SHORT := ["每天两次", "每天三次", "体力满就上线"]
const WATCH := [10, 15, 20, 25, 30, 35, 40]

var params: Dictionary
var theme: Theme
var folder := ""
var jobs: Array = []
var text: Label
var buttons: HBoxContainer
var links: VBoxContainer
var started := 0
var stopped := false

func _ready() -> void:
	layer = 50
	var bg := ColorRect.new()
	bg.color = Color("2a2118")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.theme = theme
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 32; scroll.offset_right = -32; scroll.offset_top = 40; scroll.offset_bottom = -140
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bg.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	text = Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 640
	text.add_theme_font_size_override("font_size", 22)
	text.add_theme_color_override("font_color", Color("f4e8c8"))
	box.add_child(text)
	links = VBoxContainer.new()
	links.add_theme_constant_override("separation", 8)
	box.add_child(links)
	buttons = HBoxContainer.new()
	buttons.anchor_left = 0; buttons.anchor_right = 1; buttons.anchor_top = 1; buttons.anchor_bottom = 1
	buttons.offset_left = 32; buttons.offset_right = -32; buttons.offset_top = -120; buttons.offset_bottom = -32
	buttons.add_theme_constant_override("separation", 16)
	bg.add_child(buttons)
	_button("停止全部", _stop)
	_plan()
	started = Time.get_ticks_msec()
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_poll)
	add_child(timer)
	_poll()

func _button(label: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(cb)
	buttons.add_child(b)
	return b

func _plan() -> void:
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "-")
	folder = ProjectSettings.globalize_path("res://tools/sim/results").path_join("autoplay-batch-" + stamp)
	for kind in SHORT.size():
		if int(params["kinds"]) & (1 << kind) == 0: continue
		var dir := folder.path_join(["twice", "thrice", "full"][kind])
		jobs.append({"kind": kind, "seed": int(params["seed"]), "dir": dir, "pid": -1, "state": "排队", "level": 0, "day": 0, "result": {}})

func _launch(job: Dictionary, index: int) -> void:
	DirAccess.make_dir_recursive_absolute(job["dir"])
	var save := "user://autoplay_batch/j%d" % index
	var abs_save := ProjectSettings.globalize_path(save)
	if DirAccess.dir_exists_absolute(abs_save):
		for f in DirAccess.get_files_at(abs_save): DirAccess.remove_absolute(abs_save.path_join(f))
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "tools/sim/autoplay.gd", "--",
		"--replay-test", "--cloud-off", "--save=%s/s.json" % save, "--cloud-state=%s/c.json" % save,
		"--rank-state=%s/r.json" % save, "--hot-file=%s/h.json" % save, "--job-dir=" + str(job["dir"]),
		"--p:intensity=%d" % int(job["kind"]), "--p:seed=%d" % int(job["seed"]),
		"--p:target=%d" % int(params["target"]), "--p:days=%d" % int(params["days"]),
		"--p:events=%s" % str(bool(params["events"])).to_lower(), "--p:storage=%s" % str(bool(params["storage"])).to_lower(),
		"--p:detail=%s" % str(bool(params["detail"])).to_lower()]
	job["pid"] = OS.create_process(OS.get_executable_path(), args)
	job["state"] = "运行中" if int(job["pid"]) > 0 else "启动失败"
	job["t0"] = Time.get_ticks_msec()

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
	return raw if raw is Dictionary else {}

func _poll() -> void:
	var running := 0
	for job in jobs:
		if job["state"] != "运行中": continue
		var progress := _read(str(job["dir"]).path_join("progress.json"))
		if not progress.is_empty():
			job["level"] = int(progress.get("level", 0)); job["day"] = int(progress.get("day", 0))
		if OS.is_process_running(int(job["pid"])):
			running += 1
			continue
		job["secs"] = (Time.get_ticks_msec() - int(job["t0"])) / 1000
		var report := _read(str(job["dir"]).path_join("report.json"))
		var runs: Array = report.get("runs", [])
		if progress.has("error") or runs.is_empty():
			job["state"] = "失败：" + str(progress.get("error", "进程退出，没有结果"))
		else:
			job["state"] = "完成"
			job["result"] = runs[0]
	if not stopped:
		for i in jobs.size():
			if jobs[i]["state"] == "排队":
				_launch(jobs[i], i)
				running += 1
	_render(running)

func _level_day(run: Dictionary, lv: int) -> int:
	for row in run.get("levels", []):
		if int(row["level"]) == lv: return int(row["day"])
	return 0

func _render(running: int) -> void:
	var lines := PackedStringArray()
	var target := int(params["target"])
	lines.append("后台批量演算 · 目标 Lv%d · 最多 %d 天 · 随机种子 %d" % [target, int(params["days"]), int(params["seed"])])
	lines.append("已用 %d 秒" % ((Time.get_ticks_msec() - started) / 1000))
	lines.append("")
	var done := true
	for job in jobs:
		var head := "%s：" % SHORT[int(job["kind"])]
		if job["state"] == "完成":
			var run: Dictionary = job["result"]
			var lv := int((run.get("state", {}) as Dictionary).get("level", 0))
			var td := _level_day(run, target)
			lines.append(head + ("第%d天到 Lv%d" % [td, target] if lv >= target and td > 0 else "%d天只到 Lv%d" % [int(params["days"]), lv]) + "（%d秒）" % int(job.get("secs", 0)))
		elif job["state"] == "运行中":
			done = false
			lines.append(head + "运行中 Lv%d 第%d天" % [int(job["level"]), maxi(int(job["day"]), 1)] if int(job["level"]) > 0 else head + "运行中（走新手引导）")
		else:
			if job["state"] == "排队": done = false
			lines.append(head + str(job["state"]))
	if done or stopped and running == 0:
		lines.append("")
		lines.append_array(_table())
		lines.append("")
		lines.append("结果文件夹：" + folder)
		if not has_meta("finished"):
			set_meta("finished", true)
			_write_summary(lines)
			_finished_buttons()
	text.text = "\n".join(lines)

## 各档对比：每个关键等级第几天到
func _table() -> PackedStringArray:
	var out := PackedStringArray()
	var levels: Array = []
	for lv in WATCH:
		if lv <= int(params["target"]): levels.append(lv)
	if not levels.has(int(params["target"])): levels.append(int(params["target"]))
	var head := "强度          "
	for lv in levels: head += "Lv%-4d" % lv
	out.append("各档第几天到")
	out.append(head)
	for job in jobs:
		if job["state"] != "完成": continue
		var row := "%-8s" % SHORT[int(job["kind"])]
		for lv in levels:
			var d := _level_day(job["result"], lv)
			row += ("  第%d天" % d) if d > 0 else "   —   "
		out.append(row)
	return out

func _write_summary(lines: PackedStringArray) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	var f := FileAccess.open(folder.path_join("summary.txt"), FileAccess.WRITE)
	if f != null: f.store_string("\n".join(lines)); f.close()
	print("AUTOPLAY_BATCH\n" + "\n".join(lines))

func _finished_buttons() -> void:
	for c in buttons.get_children(): c.queue_free()
	_button("改参数再来", func():
		OS.create_process(OS.get_executable_path(), _restart_args())
		get_tree().quit())
	_button("打开文件夹", func(): OS.shell_open(folder))
	_button("退出", func(): get_tree().quit())
	if bool(params["detail"]):
		for job in jobs:
			if job["state"] != "完成": continue
			var b := Button.new()
			b.text = "看时间轴：" + SHORT[int(job["kind"])]
			b.add_theme_font_size_override("font_size", 24)
			var dir := str(job["dir"])
			b.pressed.connect(func(): load("res://tools/sim/autoplay.gd").open_timeline(dir))
			links.add_child(b)
	if OS.get_cmdline_user_args().has("--autoquit"): get_tree().quit(0)

func _restart_args() -> PackedStringArray:
	var out := PackedStringArray()
	for a in OS.get_cmdline_args():
		if a != "--autostart" and not a.begins_with("--p:"): out.append(a)
	return out

func _stop() -> void:
	stopped = true
	for job in jobs:
		if job["state"] == "运行中" and OS.is_process_running(int(job["pid"])):
			OS.kill(int(job["pid"]))
			job["state"] = "已停止"
		elif job["state"] == "排队":
			job["state"] = "未开始"
	_render(0)
