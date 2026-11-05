extends SceneTree
## 服务器联调：自己起一个临时服务器（server/run.py，独立端口和 SQLite），再把游戏分几次启动（子进程）。
## 两台「设备」各用一套独立文件（存档、云状态、热卖，都在 user://cloud_check/ 下，a_* 和 b_*），不碰真实存档。
##   A play      新游客注册 → 首传 → 交单（事件）合并上传 → 60 秒内不重复传 → 哈希相同不传 → 建造（服务器扣贝币）
##               → 本地改琥珀被服务器值覆盖 → 买体力 / 买宝箱 / 开宝箱（服务器）→ 切后台补传
##               → 热卖来自服务器，删 hot_deals.json / 拨快时钟都不变 → 生成转移码 → 关窗口补传
##   （检查数据库里的快照；删掉 A 的本地存档和热卖文件）
##   A restore   时钟拨快 3 天重开：从服务器恢复，今日购买次数、热卖不变
##   A conflict  同一会话另一个窗口抢先传了新版本 → 409 拉最新；体力凭空暴涨 → 422 回滚
##   B login     另一台干净设备：先是新游客，输入 A 的账号 ID + 转移码 → 选用云端进度 → 进度一致，B 的游客号作废
##   A kicked    A 再启动：提示「账号已在其他设备登录」，不能花钱；用转移码重新登录 → 拿到 B 改过的更新版本
##   （关掉服务器）
##   A offline   连不上：交单照常（事件排队），买东西 / 建造 / 开箱提示稍后再试，不卡不报错，关窗口不拖
##   （重开服务器）
##   A reconnect 排队的事件补交，贝币按服务器结算
## 用法：Godot --headless --path . --script tools/cloud_check.gd   （需要 pip install -r server/requirements.txt）
##       可加 -- --python=py 指定 Python。

const PORT := 18767
const DIR := "user://cloud_check/"
const URL := "http://127.0.0.1:18767"

var _started := false
var _fail := 0
var _phase := ""
var _notices: Array = []
var _log: Array = []

func _process(_d: float) -> bool:
	if not _started:
		_started = true
		_main()
	return false

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
			"b_login": await _phase_b_login()
			"kicked": await _phase_kicked()
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
	for f in DirAccess.get_files_at(ProjectSettings.globalize_path(DIR)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + f))
	if not await _start_server():
		_ok(false, "启动临时服务器（需要 pip install -r server/requirements.txt）")
		_finish()
		return
	_ok(true, "临时服务器 %s" % URL)

	await _child("play", "a")
	var out := _read_json(DIR + "play_out.json")
	var st := _read_json(DIR + "a_state.json")
	var r := await _http("GET", "/v1/save", null, str(st.get("token", "")))
	var snap := _unpack(str(r[1].get("data", "")))
	_ok(r[0] == 200 and int(r[1].get("version", 0)) == int(st.get("version", -1)),
		"数据库里有最新快照 v%s（关窗口时补传的那份）" % str(r[1].get("version", "?")))
	_ok(int(snap.get("builds", {}).get("fire", 0)) == 2 and int(snap.get("amber", -1)) == int(out.get("amber", -2)),
		"快照里的建造和琥珀是服务器的值（篝火 %s 段，琥珀 %s）" % [str(snap.get("builds", {}).get("fire", "?")), str(snap.get("amber", "?"))])

	var rk := await _http("GET", "/v1/rank/top?n=10", null, str(st.get("token", "")))
	var me = rk[1].get("me")
	_ok(rk[0] == 200 and me is Dictionary and int(me["progress"]) == 2 and int(me["rank"]) == 1,
		"排行榜：进度由服务器从建造算出（%s 件，第 %s 名）" % [str(me.get("progress", "?")) if me is Dictionary else "?", str(me.get("rank", "?")) if me is Dictionary else "?"])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + "a_save.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + "a_hot.json"))
	_ok(not FileAccess.file_exists(DIR + "a_save.json"), "删掉设备 A 的本地存档和 hot_deals.json")
	await _child("restore", "a", ["--clock-skew=259200"])
	await _child("conflict", "a")
	await _child("b_login", "b")
	await _child("kicked", "a")
	_stop_server()
	await _child("offline", "a")
	await _start_server()
	await _child("reconnect", "a")
	_stop_server()
	_finish()

func _godot_args(phase: String, dev: String, extra: Array) -> Array:
	var a := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tools/cloud_check.gd", "--",
		"--phase=" + phase, "--save=%s%s_save.json" % [DIR, dev], "--cloud-state=%s%s_state.json" % [DIR, dev],
		"--cloud-url=" + URL, "--hot-file=%s%s_hot.json" % [DIR, dev], "--rank-state=%s%s_rank.json" % [DIR, dev]]
	a.append_array(extra)
	return a

func _child(phase: String, dev: String, extra := []) -> void:
	print("\n== [设备 %s] %s" % [dev.to_upper(), phase])
	var out := []
	var res := DIR + "result_%s.txt" % phase
	DirAccess.remove_absolute(ProjectSettings.globalize_path(res))
	var t0 := Time.get_ticks_msec()
	var code := OS.execute(OS.get_executable_path(), _godot_args(phase, dev, extra), out, true)
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
	OS.set_environment("TRIBE_LOG_LEVEL", "WARNING")
	OS.set_environment("TRIBE_ENV", "test")
	_server_pid = OS.create_process(py, [ProjectSettings.globalize_path("res://server/run.py"), "--port", str(PORT),
		"--database-url", "sqlite:///" + ProjectSettings.globalize_path(DIR + "server.db")])
	for i in 100:
		var r := await _http("GET", "/v1/health", null, "")
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

## 等 Cloud 启动完（连上、确认连不上、或被顶下线）
func _wait_boot(max_sec := 8.0) -> float:
	var c = _cloud()
	var t0 := Time.get_ticks_msec()
	while not c._boot_done and not (c._retry_t > 0.0) and c.kicked == "" and Time.get_ticks_msec() - t0 < max_sec * 1000.0:
		await process_frame
	await _wait_idle()
	return (Time.get_ticks_msec() - t0) / 1000.0

func _wait_idle(max_sec := 6.0) -> void:
	var c = _cloud()
	var t0 := Time.get_ticks_msec()
	await process_frame
	while (c._busy or c._hot_busy) and Time.get_ticks_msec() - t0 < max_sec * 1000.0:
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

## 把订单要的东西直接摆到棋盘上（合成不归服务器管），然后交单
func _deliver(match_items: Array) -> bool:
	var g = _g()
	for oi in g.orders.size():
		var o: Dictionary = g.orders[oi]
		if str(o.get("items", [])) != str(match_items):
			continue
		# 从棋盘末尾往前找格子放（棋盘满了就直接盖掉，测试只关心交单）
		var k: int = g.board.size() - 1
		for it in o["items"]:
			while k > 0 and g.board[k].has("ck"):
				k -= 1
			g.board[k] = {"id": str(it), "lock": 0}
			k -= 1
		return not g.complete_order(oi).is_empty()
	return false

## 奖励里的琥珀 / 贝币：游戏里由 UI 的飞入动画加（Cloud.act 先减掉了），测试里直接加
func _ui_grant(rewards: Array) -> void:
	for rw in rewards:
		var t := Data.type_of(str(rw[0]))
		if t in ["amber", "shell"]:
			_g().add_currency(t, int(rw[1]))

func _save_local() -> void:
	var f := FileAccess.open(_arg("save"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_g().save_dict()))
	f.close()

func _phase_play() -> void:
	var c = _cloud()
	var g = _g()
	await _wait_boot()
	_ok(c.online and c.token != "" and c.account_id == g.player_id, "新游客注册拿到 token（%s）" % g.player_id)
	_ok(c.uploads == 1 and c.version == 1, "启动后首传一次，服务器 v%d" % c.version)
	_ok(g.amber == 80 and g.shells == 0, "余额来自服务器（琥珀 %d，贝币 %d）" % [g.amber, g.shells])

	# 交新手单 1：本地先加贝币，事件排队
	_ok(_deliver(["fruit_2"]), "交新手单 1（本地生效，事件排队 %d）" % c.events.size())
	await create_timer(c.MERGE_DELAY + 1.5).timeout
	_ok(c.uploads == 1, "60 秒间隔内不重复上传（%.0f 秒后仍是 %d 次）" % [c.MERGE_DELAY + 1.5, c.uploads])
	g.add_currency("shell", 25)  # BoardScreen 的飞入动画会加；这里直接加
	c.flush()
	await _wait_idle()
	_ok(c.uploads == 2 and c.events.is_empty() and g.shells == 25, "补传：事件结算，服务器贝币 %d（v%d）" % [g.shells, c.version])
	c.mark()
	c.flush()
	await _wait_idle()
	_ok(c.uploads == 2, "内容没变（哈希相同）不上传")

	# 新手单 2 → 够建篝火第二件
	_ok(_deliver(["fruit_8"]), "交新手单 2")
	var built: Dictionary = await g.do_build("fire")
	_ui_grant(built.get("rewards", []))
	_ok(not built.is_empty() and int(g.builds.get("fire", 0)) == 2, "建造：服务器先结算交单再扣贝币（篝火 %d 段，贝币 %d）" % [int(g.builds.get("fire", 0)), g.shells])

	# 改本地琥珀没用
	var real: int = g.amber
	g.amber = 99999
	c.mark()
	c.flush()
	await _wait_idle()
	_ok(g.amber == real, "本地把琥珀改成 99999，同步后变回服务器的 %d" % g.amber)

	_ok(await g.buy_energy(), "买体力（服务器扣琥珀，今日第 %d 次，琥珀 %d）" % [g.energy_buys, g.amber])
	var sb: Dictionary = await g.shop_buy("deal_0", "chest_1", 10, true)
	_ok(sb.get("ok", false), "集市买每日特惠宝箱（琥珀 %d）" % g.amber)
	var items: Array = await g.open_chest()
	_ok(items.size() == 3, "服务器开宝箱：%s" % str(items))
	var again: Array = await g.open_chest()
	_ok(again.is_empty(), "没有宝箱额度时开不了")
	c._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await _wait_idle()
	_ok(c.version >= 3 and not c.pending, "切到后台时补传：v%d" % c.version)

	# 热卖
	await _wait_hot()
	var day: String = c.today()
	_ok(c.hot_for(day) is Array, "拿到服务器的今日热卖（%s）" % day)
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

	var code: String = await c.make_transfer_code()
	_ok(code.length() == 11, "生成转移码 %s" % code)

	# 关窗口：补传后退出
	_deliver(["fruit_2"])  # 没有这张单了，什么也不做
	g.energy -= 1
	c.mark()
	_save_local()
	var f := FileAccess.open(DIR + "play_out.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"amber": g.amber, "fire": int(g.builds.get("fire", 0)), "hot": a,
		"energy_buys": g.energy_buys, "id": g.player_id, "code": code}))
	f.close()
	_write_result()
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
	_ok(g.player_id == str(want["id"]), "账号还是 %s" % g.player_id)
	_ok(g.amber == int(want["amber"]) and int(g.builds.get("fire", 0)) == int(want["fire"]),
		"进度从服务器恢复（琥珀 %d，篝火 %d 段）" % [g.amber, int(g.builds.get("fire", 0))])
	_ok(_notices.has("已从云端恢复进度"), "提示「已从云端恢复进度」")
	_ok(FileAccess.file_exists(_arg("save")), "恢复后写回了本地存档")
	_ok(g.energy_buys == int(want["energy_buys"]), "本机时钟快 3 天，今日火种购买次数没被清零（%d）" % g.energy_buys)
	_ok(absf(g.now() - Time.get_unix_time_from_system()) < 60.0, "G.now() 用的是服务器时间（不受本机时钟影响）")
	await _wait_hot()
	_ok(_hot_ids() == want["hot"], "热卖和删档前一样")

func _phase_conflict() -> void:
	var c = _cloud()
	var g = _g()
	await _wait_boot()
	var v0: int = c.version
	_ok(c.online and c.uploads == 0, "启动：本地和服务器一致，不上传（v%d）" % v0)
	# 同一会话的另一个窗口抢先传了一版（棋盘上多了一件东西）
	var other: Dictionary = g.save_dict().duplicate(true)
	var k := 0
	while other["board"][k]["id"] != "":
		k += 1
	other["board"][k] = {"id": "fruit_3", "lock": 0}
	var r := await _push(other, v0, c.token)
	_ok(r[0] == 200, "另一个窗口上传 v%d" % int(r[1].get("version", 0)))
	g.energy -= 1
	c.mark()
	c.flush()
	await _wait_idle()
	await _wait_idle()
	_ok(str(g.board[k]["id"]) == "fruit_3" and c.version == v0 + 1, "本机上传版本落后被拒，拉了最新版（v%d）" % c.version)
	_ok(_notices.any(func(t): return t.contains("别的设备")), "提示了「别的设备上有更新的进度」")
	var e0: int = g.energy
	g.energy += 5000
	c.mark()
	c.flush()
	await _wait_idle()
	await _wait_idle()
	_ok(g.energy == e0 and c.version == v0 + 1, "体力凭空 +5000 的快照被拒，回滚到服务器的（%d）" % g.energy)
	_ok(_notices.any(func(t): return t.contains("校验")), "提示了「存档校验没通过」")

func _phase_b_login() -> void:
	var c = _cloud()
	var g = _g()
	var want := _read_json(DIR + "play_out.json")
	await _wait_boot()
	var guest: String = c.account_id
	var guest_token: String = c.token
	_ok(guest != "" and guest != str(want["id"]), "干净的设备 B：先是新游客 %s" % guest)
	var bad: Dictionary = await c.login_transfer(str(want["id"]), "WRONG-CODE0")
	_ok(not bad.get("ok", false), "转移码输错：%s" % str(bad.get("message", "")))
	var res: Dictionary = await c.login_transfer(str(want["id"]), str(want["code"]))
	_ok(res.get("ok", false) and int(res.get("cloud", {}).get("parts", 0)) == 2,
		"账号 ID + 转移码登录，云端摘要：等级 %s，已建 %s 件" % [str(res.get("cloud", {}).get("level", "?")), str(res.get("cloud", {}).get("parts", "?"))])
	await c.use_cloud_login()
	await _wait_idle()
	_ok(g.player_id == str(want["id"]) and int(g.builds.get("fire", 0)) == 2 and g.amber == int(want["amber"]),
		"选「用云端进度」：设备 B 的进度和 A 一致（%s，篝火 %d 段，琥珀 %d）" % [g.player_id, int(g.builds.get("fire", 0)), g.amber])
	var old := await _http("GET", "/v1/account", null, guest_token)
	_ok(old[0] == 401, "设备 B 原来的游客 token 作废（%s）" % str(old[1].get("error", "")))
	# B 在这台设备上玩了一会儿，传上去一版
	var k := 0
	while g.board[k]["id"] != "":
		k += 1
	g.board[k] = {"id": "fruit_4", "lock": 0}
	c.mark()
	c.flush()
	await _wait_idle()
	var f := FileAccess.open(DIR + "b_out.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": c.version, "cell": k}))
	f.close()
	_ok(c.uploads >= 1, "设备 B 上传 v%d" % c.version)

func _phase_kicked() -> void:
	var c = _cloud()
	var g = _g()
	var want := _read_json(DIR + "play_out.json")
	var b := _read_json(DIR + "b_out.json")
	await _wait_boot()
	_ok(c.kicked == "session_replaced", "设备 A 再启动：服务器说账号已在其他设备登录")
	_ok(_notices.any(func(t): return t.contains("其他设备登录")), "提示了「账号已在其他设备登录」")
	_ok(not await g.buy_energy(), "被顶下线后不能花琥珀")
	var res: Dictionary = await c.login_transfer(str(want["id"]), str(want["code"]))
	_ok(res.get("ok", false) and res.get("same", false), "用转移码重新登录（同一个账号，直接换新 token）")
	await _wait_idle()
	_ok(c.kicked == "" and c.version == int(b["version"]) and str(g.board[int(b["cell"])]["id"]) == "fruit_4",
		"服务器版本更新（设备 B 传的 v%d），用了服务器的" % c.version)

func _phase_offline() -> void:
	var c = _cloud()
	var g = _g()
	var t := await _wait_boot()
	_ok(not c.online and c.clock_ready, "连不上服务器：%.2f 秒内转为单机" % t)
	var shells0: int = g.shells
	var t0 := Time.get_ticks_msec()
	var worst := 0
	var last := Time.get_ticks_msec()
	# 一张普通随机单（服务器按公式上限放行）
	var story := {"who": 0, "items": ["fruit_3"], "rw": {"shell": 12}, "story": false}
	g.orders.append(story)
	var n_items: Array = story["items"]
	_ok(_deliver(n_items), "交单照常（%s），事件排队 %d 件" % [str(n_items), c.events.size()])
	g.add_currency("shell", int(story["rw"].get("shell", 0)))
	_ok(not await g.buy_energy(), "买体力：连不上时失败")
	_ok((await g.do_build("fire")).is_empty(), "建造：连不上时失败")
	_ok((await g.open_chest()).is_empty(), "开宝箱：连不上时失败，宝箱留着")
	var list: Array = load("res://scripts/HotDeals.gd").today()
	_ok(list.size() == Data.STORE_HOT.size(), "热卖显示退回本地逻辑（%d 件）" % list.size())
	while Time.get_ticks_msec() - t0 < 2500:
		await process_frame
		var now := Time.get_ticks_msec()
		worst = maxi(worst, now - last)
		last = now
	_ok(worst < 200, "单机照常玩，最长一帧 %d ms" % worst)
	_ok(not c.events.is_empty() and g.shells > shells0, "交单的贝币先记在本地（%d），事件留着等补交" % g.shells)
	_save_local()
	var f := FileAccess.open(DIR + "off_out.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"shells": g.shells}))
	f.close()
	_write_result()
	root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await create_timer(3.0).timeout
	_ok(false, "连不上时关窗口 3 秒还没退出")
	_finish()

func _phase_reconnect() -> void:
	var c = _cloud()
	var g = _g()
	var off := _read_json(DIR + "off_out.json")
	_ok(not c.events.is_empty(), "启动时还有 %d 件离线事件" % c.events.size())
	await _wait_boot()
	await _wait_idle()
	_ok(c.online and c.events.is_empty() and c.uploads >= 1, "重新连上：事件补交并结算（v%d）" % c.version)
	_ok(g.shells == int(off["shells"]), "服务器结算后的贝币和离线时一致（%d）" % g.shells)

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

## 模拟同一会话的另一个窗口直接上传
func _push(snap: Dictionary, base: int, token: String) -> Array:
	var txt := JSON.stringify(snap)
	var data := Marshalls.raw_to_base64(txt.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	return await _http("PUT", "/v1/save", {"base": base, "hash": txt.md5_text(), "data": data}, token)

func _http(method: String, path: String, body, token: String) -> Array:
	var h := HTTPRequest.new()
	h.timeout = 3.0
	root.add_child(h)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if token != "":
		headers.append("Authorization: Bearer " + token)
	var m := HTTPClient.METHOD_GET
	if method == "POST":
		m = HTTPClient.METHOD_POST
	elif method == "PUT":
		m = HTTPClient.METHOD_PUT
	if h.request(URL + path, headers, m, "" if body == null else JSON.stringify(body)) != OK:
		h.queue_free()
		return [0, {}]
	var res: Array = await h.request_completed
	h.queue_free()
	var d = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8()) if res[0] == HTTPRequest.RESULT_SUCCESS else null
	return [int(res[1]) if res[0] == HTTPRequest.RESULT_SUCCESS else 0, d if d is Dictionary else {}]
