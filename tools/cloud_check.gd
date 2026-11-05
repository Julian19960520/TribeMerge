extends SceneTree
## 云存档 + 服务器热卖联调。自己起一个临时服务器（独立端口和数据库），再把游戏分几次启动（子进程）：
##   play     新玩家注册 → 首传 → 关键事件 → 60 秒间隔内不重复传 → 内容没变不传 → 切后台补传
##            → 热卖来自服务器，删 hot_deals.json / 改本机时间都刷不掉 → 关窗口补传
##   (删本地存档和 hot_deals.json)
##   restore  本机时钟拨快 3 天重开：从服务器恢复进度；热卖、今日购买次数不变
##   conflict 另一台设备抢先传了新版本 → 本机上传被拒(409) → 拉最新版；琥珀凭空暴涨 → 被拒(422) → 回滚
##   (另一台设备再传一版)
##   newer    启动时服务器版本更新 → 用服务器的
##   (关掉服务器)
##   offline  连不上：照常玩、不卡、不报错，热卖退回本地，关窗口不拖
##   (重开服务器)
##   reconnect 离线时的改动连上后补传
## 不碰真实存档：子进程的存档、云状态、热卖、排行状态都放在 user://cloud_check/。
## 用法：Godot --headless --path . --script tools/cloud_check.gd
##       可加 -- --python=py 指定 Python。

const PORT := 18767
const DIR := "user://cloud_check/"
const URL := "http://127.0.0.1:18767"

var _started := false
var _fail := 0
var _phase := ""
var _notices: Array = []

func _process(_d: float) -> bool:
	if not _started:
		_started = true
		_main()
	return false

var _log: Array = []

func _ok(cond: bool, what: String) -> void:
	var line := ("  OK   " if cond else "  FAIL ") + what
	print(line)
	_log.append(line)
	if not cond:
		_fail += 1

func _note(what: String) -> void:
	print("  · " + what)
	_log.append("  · " + what)

## 子进程把结果写成 UTF-8 文件给主控读（主控拿到的 stdout 按系统代码页解码，中文会乱）
func _write_result() -> void:
	_log.append("RESULT: " + ("PASS" if _fail == 0 else "FAIL %d" % _fail))
	var f := FileAccess.open(DIR + "result_%s.txt" % _phase, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_log))

func _arg(key: String, def := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.trim_prefix("--%s=" % key)
	return def

func _main() -> void:
	root.get_node("G").set_process(false)
	_phase = _arg("phase")
	if _phase == "":
		await _orchestrate()
	else:
		var cloud = root.get_node("Cloud")
		cloud.notice.connect(func(t): _notices.append(t))
		match _phase:
			"play": await _phase_play()
			"restore": await _phase_restore()
			"conflict": await _phase_conflict()
			"newer": await _phase_newer()
			"offline": await _phase_offline()
			"reconnect": await _phase_reconnect()
			_: _ok(false, "未知阶段 " + _phase)
		_finish()

func _finish() -> void:
	if _phase != "":
		_write_result()
	print("RESULT: ", "PASS" if _fail == 0 else "FAIL %d" % _fail)
	quit(0 if _fail == 0 else 1)

# ================================================================ 主控

var _server_pid := -1

func _orchestrate() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for f in ["save.json", "state.json", "hot.json", "rank.json", "play_out.json", "server.db"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + f))
	if not await _start_server():
		_ok(false, "启动临时服务器")
		_finish()
		return
	_ok(true, "临时服务器 %s" % URL)

	await _child("play")
	var out := _read_json(DIR + "play_out.json")
	var st := _read_json(DIR + "state.json")
	var r := await _http("GET", "/api/save?id=" + str(st.get("pid", "")), null, str(st.get("token", "")))
	var snap := _unpack(str(r[1].get("data", "")))
	_ok(r[0] == 200 and int(r[1].get("version", 0)) == int(out.get("version", -1)),
		"数据库里有最新快照 v%s（关窗口时补传的那份）" % str(r[1].get("version", "?")))
	_ok(int(snap.get("amber", -1)) == int(out.get("amber", -2)) and int(snap.get("builds", {}).get("fire", 0)) == int(out.get("fire", -1)),
		"快照内容 = 退出时的进度（琥珀 %s，篝火 %s 段）" % [str(snap.get("amber", "?")), str(snap.get("builds", {}).get("fire", "?"))])

	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + "save.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + "hot.json"))
	_ok(not FileAccess.file_exists(DIR + "save.json"), "删掉本地存档和 hot_deals.json")
	await _child("restore", ["--clock-skew=259200"])

	await _child("conflict")

	# 另一台设备再传一版，然后本机启动
	st = _read_json(DIR + "state.json")
	r = await _http("GET", "/api/save?id=" + str(st["pid"]), null, str(st["token"]))
	snap = _unpack(str(r[1]["data"]))
	snap["shells"] = 4242
	r = await _push(snap, int(r[1]["version"]), str(st["token"]))
	_ok(r[0] == 200, "另一台设备上传 v%s（贝币 4242）" % str(r[1].get("version", "?")))
	await _child("newer", ["--expect-version=%d" % int(r[1].get("version", 0))])

	_stop_server()
	await _child("offline")
	await _start_server()
	st = _read_json(DIR + "state.json")
	await _child("reconnect", ["--expect-base=%d" % int(st.get("version", 0))])
	_stop_server()
	_finish()

func _godot_args(phase: String, extra: Array) -> Array:
	var a := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tools/cloud_check.gd", "--",
		"--phase=" + phase, "--save=" + DIR + "save.json", "--cloud-state=" + DIR + "state.json",
		"--cloud-url=" + URL, "--hot-file=" + DIR + "hot.json", "--rank-state=" + DIR + "rank.json"]
	a.append_array(extra)
	return a

func _child(phase: String, extra := []) -> void:
	print("\n== ", phase)
	var out := []
	var res := DIR + "result_%s.txt" % phase
	DirAccess.remove_absolute(ProjectSettings.globalize_path(res))
	var t0 := Time.get_ticks_msec()
	var code := OS.execute(OS.get_executable_path(), _godot_args(phase, extra), out, true)
	var ms := Time.get_ticks_msec() - t0
	# 子进程期间主线程卡住，下一帧 delta 很大，新建的 HTTPRequest 会立刻超时：先空转两帧
	await process_frame
	await process_frame
	var f := FileAccess.open(res, FileAccess.READ)
	var log := f.get_as_text() if f != null else "(没有结果文件)"
	for line in log.split("\n"):
		if line.begins_with("  "):
			print("  ", line)
	var errs := []
	for line in "\n".join(out).split("\n"):
		if (line.contains("ERROR") or line.contains("WARNING")) and not line.contains("still in use at exit") \
				and not line.contains("leaked at exit") and not line.contains("[cloud]"):
			errs.append(line.strip_edges())
	for e in errs:
		print("    ! ", e)
	_ok(code == 0 and log.contains("RESULT: PASS"), "[%s] 子进程通过（%.1f 秒）" % [phase, ms / 1000.0])
	_ok(errs.is_empty(), "[%s] 没有报错" % phase)

func _start_server() -> bool:
	var py := _arg("python", "python")
	_server_pid = OS.create_process(py, [ProjectSettings.globalize_path("res://server/rank_server.py"),
		"--port", str(PORT), "--db", ProjectSettings.globalize_path(DIR + "server.db")])
	for i in 60:
		var r := await _http("GET", "/api/health", null, "")
		if r[0] == 200:
			return true
		await create_timer(0.1).timeout
	return false

func _stop_server() -> void:
	if _server_pid > 0:
		OS.kill(_server_pid)
		_server_pid = -1

# ================================================================ 子进程：各阶段

func _cloud():
	return root.get_node("Cloud")

func _g():
	return root.get_node("G")

## 等 Cloud 启动完（连上或确认连不上）
func _wait_boot(max_sec := 8.0) -> float:
	var t0 := Time.get_ticks_msec()
	while not _cloud()._boot_done and not (_cloud()._retry_t > 0.0) and Time.get_ticks_msec() - t0 < max_sec * 1000.0:
		await process_frame
	await _wait_idle()
	return (Time.get_ticks_msec() - t0) / 1000.0

func _wait_idle(max_sec := 6.0) -> void:
	var t0 := Time.get_ticks_msec()
	while (_cloud()._busy or _cloud()._hot_busy) and Time.get_ticks_msec() - t0 < max_sec * 1000.0:
		await process_frame

func _wait_hot() -> void:
	var c = _cloud()
	c.want_hot()
	var t0 := Time.get_ticks_msec()
	while c.hot_for(c.today()) == null and Time.get_ticks_msec() - t0 < 5000:
		await process_frame

func _hot_ids() -> Array:
	var HD = load("res://scripts/HotDeals.gd")
	var out := []
	for d in HD.today():
		out.append("%s:%d:%d" % [d["id"], d["price"], d["stock"]])
	return out

func _phase_play() -> void:
	var c = _cloud()
	var g = _g()
	await _wait_boot()
	_ok(c.online and c.token != "", "新玩家注册拿到 token（%s）" % g.player_id)
	_ok(c.uploads == 1 and c.version == 1, "启动后首传一次，服务器 v%d" % c.version)

	g.shells += 100000
	g.amber += 200
	c.purchase(200)  # 演示充值：先报给服务器，否则下一份快照的琥珀会被当成凭空多出来
	g.do_build("fire")
	_ok(c.pending, "建造后标记待上传")
	await create_timer(c.MERGE_DELAY + 1.5).timeout
	_ok(c.uploads == 1, "60 秒间隔内不重复上传（%.0f 秒后仍是 %d 次）" % [c.MERGE_DELAY + 1.5, c.uploads])
	c.flush()
	await _wait_idle()
	_ok(c.uploads == 2 and c.version == 2 and not c.pending, "补传：v%d" % c.version)
	c.mark()
	c.flush()
	await _wait_idle()
	_ok(c.uploads == 2 and not c.pending, "内容没变（哈希相同）不上传")

	_ok(g.buy_energy(), "买一次火种（今日次数 %d）" % g.energy_buys)
	c._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await process_frame
	await _wait_idle()
	_ok(c.uploads == 3 and c.version == 3, "切到后台时补传：v%d" % c.version)

	# 热卖
	await _wait_hot()
	var day: String = c.today()
	_ok(c.hot_for(day) is Array, "拿到服务器的今日热卖（%s，换了 %d 件）" % [day, (c.hot_for(day) as Array).size() if c.hot_for(day) is Array else -1])
	var HD = load("res://scripts/HotDeals.gd")
	HD.clear_cache()
	var a := _hot_ids()
	_note("热卖 %s" % str(a))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_arg("hot-file")))
	HD.clear_cache()
	_ok(_hot_ids() == a, "删掉 hot_deals.json 后货单不变")
	c.debug_skew = 3 * 86400.0
	HD.clear_cache()
	_ok(c.today() == day and _hot_ids() == a, "本机时钟拨快 3 天：日期仍是服务器的 %s，货单不变" % c.today())
	c._hot_day = ""
	c._hot_picks = null
	c._hot_tried = ""
	await _wait_hot()
	HD.clear_cache()
	_ok(_hot_ids() == a, "再向服务器要一次：同一天还是同一份")
	c.debug_skew = 0.0

	# 关窗口：补传后退出
	g.spend("amber", 1)
	var f := FileAccess.open(_arg("save"), FileAccess.WRITE)
	f.store_string(JSON.stringify(g.save_dict()))
	f.close()
	f = FileAccess.open(DIR + "play_out.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"amber": g.amber, "fire": int(g.builds.get("fire", 0)), "version": 4,
		"hot": a, "energy_buys": g.energy_buys, "id": g.player_id}))
	f.close()
	_write_result()
	# Cloud 接管退出：补传 → quit
	root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await create_timer(5.0).timeout
	_ok(false, "关窗口后 5 秒还没退出")
	_finish()

func _phase_restore() -> void:
	var c = _cloud()
	var g = _g()
	var want := _read_json(DIR + "play_out.json")
	_ok(not g.loaded_save, "本地没有存档，先新开了一局（%s）" % g.player_id)
	await _wait_boot()
	_ok(g.player_id == str(want["id"]), "玩家 id 恢复为 %s" % g.player_id)
	_ok(g.amber == int(want["amber"]) and int(g.builds.get("fire", 0)) == int(want["fire"]),
		"进度从服务器恢复（琥珀 %d，篝火 %d 段）" % [g.amber, int(g.builds.get("fire", 0))])
	_ok(c.version == int(want["version"]) and _notices.has("已从云端恢复进度"), "版本 v%d，提示「已从云端恢复进度」" % c.version)
	_ok(FileAccess.file_exists(_arg("save")), "恢复后写回了本地存档")
	_ok(g.energy_buys == int(want["energy_buys"]), "本机时钟快 3 天，今日火种购买次数没被清零（%d）" % g.energy_buys)
	await _wait_hot()
	_ok(_hot_ids() == want["hot"], "热卖和删档前一样")

func _phase_conflict() -> void:
	var c = _cloud()
	var g = _g()
	await _wait_boot()
	var v0: int = c.version
	_ok(c.online and c.uploads == 0, "启动：本地和服务器一致，不上传（v%d）" % v0)
	# 另一台设备抢先传了一版
	var other: Dictionary = g.save_dict().duplicate(true)
	other["shells"] = 777
	var r := await _push(other, v0, c.token)
	_ok(r[0] == 200, "另一台设备上传 v%d" % int(r[1].get("version", 0)))
	g.spend("amber", 1)
	c.flush()
	await _wait_idle()
	await _wait_idle()
	_ok(g.shells == 777 and c.version == v0 + 1, "本机上传版本落后被拒，拉了最新版（贝币 %d，v%d）" % [g.shells, c.version])
	_ok(_notices.any(func(t): return t.contains("别的设备")), "提示了「别的设备上有更新的进度」")
	# 凭空多出琥珀
	var amber0: int = g.amber
	g.amber += 99999
	c.mark()
	c.flush()
	await _wait_idle()
	await _wait_idle()
	_ok(g.amber == amber0 and c.version == v0 + 1, "琥珀凭空 +99999 的快照被拒，回滚到服务器的（%d）" % g.amber)
	_ok(_notices.any(func(t): return t.contains("校验")), "提示了「存档校验没通过」")

func _phase_newer() -> void:
	var c = _cloud()
	var g = _g()
	_ok(g.loaded_save and g.shells != 4242, "本地存档是旧的（贝币 %d）" % g.shells)
	await _wait_boot()
	_ok(g.shells == 4242 and c.version == int(_arg("expect-version")), "启动时服务器版本更新，用了服务器的（贝币 %d，v%d）" % [g.shells, c.version])

func _phase_offline() -> void:
	var c = _cloud()
	var g = _g()
	var t := await _wait_boot()
	_ok(not c.online and c.clock_ready, "连不上服务器：%.2f 秒内转为单机" % t)
	var t0 := Time.get_ticks_msec()
	var worst := 0
	var last := Time.get_ticks_msec()
	g.shells += 100
	g.do_build("fire")
	g.spend("amber", 1)
	c.flush()
	var list: Array = load("res://scripts/HotDeals.gd").today()
	_ok(list.size() == Data.STORE_HOT.size(), "热卖退回本地逻辑（%d 件）" % list.size())
	while Time.get_ticks_msec() - t0 < 2500:
		await process_frame
		var now := Time.get_ticks_msec()
		worst = maxi(worst, now - last)
		last = now
	_ok(worst < 200, "单机照常玩，最长一帧 %d ms" % worst)
	_ok(c.pending, "改动记着待上传")
	var f := FileAccess.open(_arg("save"), FileAccess.WRITE)
	f.store_string(JSON.stringify(g.save_dict()))
	f.close()
	_write_result()
	root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await create_timer(3.0).timeout
	_ok(false, "连不上时关窗口 3 秒还没退出")
	_finish()

func _phase_reconnect() -> void:
	var c = _cloud()
	await _wait_boot()
	_ok(c.online and c.uploads == 1 and c.version == int(_arg("expect-base")) + 1,
		"重新连上：离线时的改动补传了（v%d）" % c.version)

# ================================================================ 工具

func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}

func _unpack(b64: String) -> Dictionary:
	if b64 == "":
		return {}
	var d = JSON.parse_string(Marshalls.base64_to_raw(b64).decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8())
	return d if d is Dictionary else {}

## 模拟另一台设备直接上传
func _push(snap: Dictionary, base: int, token: String) -> Array:
	var txt := JSON.stringify(snap)
	var data := Marshalls.raw_to_base64(txt.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	return await _http("POST", "/api/save", {"id": str(snap["player_id"]), "base": base, "hash": txt.md5_text(), "data": data}, token)

func _http(method: String, path: String, body, token: String) -> Array:
	var h := HTTPRequest.new()
	h.timeout = 3.0
	root.add_child(h)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if token != "":
		headers.append("X-Token: " + token)
	var m := HTTPClient.METHOD_POST if method == "POST" else HTTPClient.METHOD_GET
	if h.request(URL + path, headers, m, "" if body == null else JSON.stringify(body)) != OK:
		h.queue_free()
		return [0, {}]
	var res: Array = await h.request_completed
	h.queue_free()
	var d = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8()) if res[0] == HTTPRequest.RESULT_SUCCESS else null
	return [int(res[1]) if res[0] == HTTPRequest.RESULT_SUCCESS else 0, d if d is Dictionary else {}]
