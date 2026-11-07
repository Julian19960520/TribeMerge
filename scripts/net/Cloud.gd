extends Node
## 服务器客户端（自动加载 Cloud，排在 G、Rank 后面）。接口见 server/app，规则见 DESIGN.md「十二」。
##
## 账号：第一次打开自动注册游客号（POST /v1/auth/guest），token 存在 user://cloud_state.json，带在 Authorization: Bearer。
##   token 30 天有效，快到期自动续（/v1/auth/refresh）。同一账号同时只有一台设备在线：别处登录后这里收到
##   401 session_replaced，进入「已在其他设备登录」状态（不再同步、不能花钱领奖），在「账号与数据」里重新登录。
##   换设备：设置 →「账号与数据」生成转移码，新设备输入账号 ID + 转移码；或绑定登录渠道（现在有 mock）。
##
## 存档：本地照常存；关键事件后合并上传整份快照（PUT /v1/save，60 秒最多一次，切后台 / 关窗口补传，哈希相同不传）。
##   服务器字段（琥珀、贝币、等级、建造、通行证、卡册……）以服务器为准，每次同步把服务器的值写回本地。
##
## 事件：交单、石头气泡、收取货币物品、丢弃退款先在本地生效，同时排队，随下一次上传交给服务器结算（离线就一直排着）。
## 操作：买东西、建造、开宝箱 / 卡包、领奖都先问服务器（act），带幂等键；连不上就失败，提示稍后再试。
## 时间：G.now() / 「今天」都用服务器时间（本机时间 + 服务器给的差值）。

## 拉了服务器存档覆盖本地之后发出
signal restored
## 给玩家看的提示（另外会走 G.main.toast）
signal notice(text: String)
## 每次请求结束：what = "boot" / "upload" / "hot" / "events" / 接口路径，ok 是否成功
signal synced(what: String, ok: bool)
## 账号状态变了（登录、换号、被顶下线、绑定）
signal account_changed

const DEFAULT_URL := "http://127.0.0.1:8765"
const TIMEOUT := 6.0
const UPLOAD_GAP := 60.0
const MERGE_DELAY := 3.0
const RETRY_SEC := 90.0
const QUIT_WAIT := 2.0
const DAY_OFFSET := 8 * 3600
const SERVER_FIELDS := ["duel_race", "ufo_offer", "gm_activities", "seven_day", "merge_events", "amber", "shells", "level", "xp", "energy_buys", "deals_day", "hot_bought", "deals_bought", "hot_revision",
	"inv_cap", "pass_pts", "pass_tier", "pass_free", "pass_prem", "pass_super", "pass_endless", "pass_super_bonus",
	"tokens", "token_claimed", "builds", "cards", "book_claimed", "shell_bought", "shell_period"]

var state_path := "user://cloud_state.json"
var url := DEFAULT_URL
var enabled := true
## 测试用：假装本机时钟偏了这么多秒
var debug_skew := 0.0

# ---- 存在 cloud_state.json 里的
var device_id := ""
var account_id := ""
var token := ""
var expires_at := 0.0
var renew_after := 0.0
var version := 0
var sent_hash := ""
var pending := false
## 还没交给服务器的事件 [{id, type, ...}]
var events: Array = []
## 本机生成过的转移码（服务器只存哈希，这里留一份给玩家看）
var transfer_code := ""
var last_sync := 0.0
## 服务器时间 - 本机时间（离线时用上次的差值）
var clock_offset := 0.0
## 非空 = 被顶下线 / 登录过期（"session_replaced" / "token_expired" / "session_revoked"）
var kicked := ""

# ---- 运行时
var online := false
var clock_ready := false
var uploads := 0
var _boot_done := false
var _busy := false
var _mark_t := -1.0
var _mark_gen := 0
var _last_up := -1.0e9
var _retry_t := -1.0
var _srv_unix := 0.0
var _srv_tick := 0
var _day := ""
var _day_t := 0.0
var _hot_day := ""
var _hot_revision := 0
var _hot_picks = null
var _hot_busy := false
var _hot_tried := ""
var _quitting := false
## 登录别的账号后、玩家还没选用哪边进度时暂存的新会话
var _pending_login := {}

func _ready() -> void:
	var own_state := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cloud-state="):
			state_path = a.trim_prefix("--cloud-state=")
			own_state = true
		elif a.begins_with("--clock-skew="):
			debug_skew = float(a.trim_prefix("--clock-skew="))
		elif a.begins_with("--cloud-url="):
			url = a.trim_prefix("--cloud-url=")
		elif a == "--cloud-off":
			enabled = false
	# 跑 --script 测试脚本时，没给单独的状态文件就不同步，免得动到真实存档
	if get_tree().get_script() != null and not own_state:
		enabled = false
	if url == DEFAULT_URL:
		url = str(Data.RULES.get("rank_server", DEFAULT_URL))
	url = url.strip_edges().trim_suffix("/")
	get_tree().set_auto_accept_quit(false)
	_load_state()
	if device_id == "":
		device_id = _uuid()
		_save_state()
	if enabled and kicked == "":
		_boot.call_deferred()
	else:
		_set_clock_ready()
		if kicked != "":
			_say.call_deferred(_kick_text(kicked))

func _process(delta: float) -> void:
	_day_t += delta
	if _day_t >= 2.0:
		_day_t = 0.0
		var d := today()
		if d != _day:
			_day = d
			if clock_ready:
				G._check_day()
	if not enabled or _quitting or kicked != "":
		return
	if _retry_t >= 0.0:
		_retry_t -= delta
		if _retry_t < 0.0:
			if _boot_done:
				_upload()
			else:
				_boot()
		return
	if not _boot_done or _busy:
		return
	if G.player_id != account_id:
		# 游戏里「重新开始」：换一个游客号
		_new_guest_after_reset()
		return
	if token != "" and renew_after > 0.0 and server_now() > renew_after:
		_refresh_token()
		return
	if pending or not events.is_empty():
		if _mark_t < 0.0:
			_mark_t = 0.0
		_mark_t += delta
		if _mark_t >= MERGE_DELAY and _ticks() - _last_up >= UPLOAD_GAP:
			_upload()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			if G.is_processing():
				G.save_game()
			flush.call_deferred()
		NOTIFICATION_WM_CLOSE_REQUEST:
			_quit()

# ================================================================ 对外：时间

func server_now() -> float:
	if _srv_tick > 0:
		return _srv_unix + float(Time.get_ticks_msec() - _srv_tick) / 1000.0
	return Time.get_unix_time_from_system() + clock_offset + debug_skew

func today() -> String:
	return Time.get_date_string_from_unix_time(int(server_now()) + DAY_OFFSET)

func secs_to_midnight() -> int:
	return 86400 - (int(server_now()) + DAY_OFFSET) % 86400

# ================================================================ 对外：同步

## 关键事件后调用：记一笔「待上传」
func mark() -> void:
	_mark_gen += 1
	if not pending:
		pending = true
		if _mark_t < 0.0:
			_mark_t = 0.0
		_save_state()

## 客户端先生效、服务器随后结算的事件。ev = {"type": "order"/"bubble"/"collect"/"refund", ...}
func event(ev: Dictionary) -> void:
	var e := ev.duplicate(true)
	e["id"] = str(e.get("id", _uuid()))
	events.append(e)
	if events.size() > 400:
		events = events.slice(events.size() - 400)
	mark()
	_save_state()

## 马上补传（切后台、退出、手动「同步」按钮）
func flush() -> void:
	if can_talk() and not _busy and (pending or not events.is_empty()):
		_upload()

## 能和服务器说话：开着、启动完了、有 token、没被顶下线
func can_talk() -> bool:
	return enabled and _boot_done and token != "" and kicked == ""

## 服务器说了算的操作：先把排队的事件交掉，再调接口（带幂等键，网络失败用同一个键重试一次）。
## 返回服务器的 JSON；失败时 {"ok": false, "error": ..., "message": ...}。成功时已经把服务器状态写回 G。
## minus：这次奖励里 UI 还会再加一遍的货币（[[id, n], ...]），先减掉，UI 动画加回来后正好等于服务器的值。
func act(path: String, body: Dictionary = {}, minus: Array = []) -> Dictionary:
	if not can_talk():
		var why := _kick_text(kicked) if kicked != "" else "连不上服务器，请稍后再试"
		return {"ok": false, "error": "offline", "message": why}
	while _busy:
		await get_tree().process_frame
	if not events.is_empty():
		var fr := await _send_events()
		if not fr:
			return {"ok": false, "error": "offline", "message": "连不上服务器，请稍后再试"}
	var key := _uuid()
	var res := []
	for attempt in 2:
		_busy = true
		res = await _call("POST", path, body, key)
		_busy = false
		if int(res[0]) != 0:
			break
	var code := int(res[0])
	var d: Dictionary = res[1]
	synced.emit(path, code == 200)
	if code == 0:
		online = false
		_retry_t = RETRY_SEC
		return {"ok": false, "error": "offline", "message": "连不上服务器，请稍后再试"}
	online = true
	if d.get("state") is Dictionary:
		apply_state(d["state"], minus if code == 200 else [])
	if code != 200:
		if not d.has("message"):
			d["message"] = "操作失败"
		d["ok"] = false
	return d

## 把服务器状态写进 G。minus 见 act。
func apply_state(st: Dictionary, minus: Array = []) -> void:
	for k in SERVER_FIELDS:
		if st.has(k):
			G.set_server_field(k, st[k])
	for rw in minus:
		if rw is Array and rw.size() >= 2:
			var id := str(rw[0])
			var t := Data.type_of(id) if Data.CHAINS.has(Data.chain(id)) else ""
			if t == "amber":
				G.amber -= int(rw[1])
			elif t == "shell":
				G.shells -= int(rw[1])
	G.dirty()
	G.changed.emit()
	G.merge_event_changed.emit()
	G.seven_day_changed.emit()

# ================================================================ 对外：热卖

func hot_for(day: String):
	if _hot_day == day and _hot_revision == G.hot_revision and _hot_picks is Array:
		return _hot_picks
	return null

func want_hot() -> void:
	if can_talk() and online and not _hot_busy and _hot_tried != today():
		_fetch_hot()

# ================================================================ 对外：账号

## 账号与数据页用：{account_id, bindings, has_transfer_code, last_sync_at, ...}
func account_info() -> Dictionary:
	if not can_talk():
		return {"ok": false, "message": _kick_text(kicked) if kicked != "" else "连不上服务器"}
	var r := await _call("GET", "/v1/account", null)
	return r[1] if int(r[0]) == 200 else _fail(r)

## 生成新的转移码（旧的作废）。返回 "XXXXX-XXXXX" 或 ""。
func make_transfer_code() -> String:
	if not can_talk():
		return ""
	var r := await _call("POST", "/v1/account/transfer-code", {})
	if int(r[0]) != 200:
		return ""
	transfer_code = str(r[1].get("code", ""))
	_save_state()
	account_changed.emit()
	return transfer_code

func bind_provider(provider: String, credential: String) -> Dictionary:
	if not can_talk():
		return {"ok": false, "message": "连不上服务器"}
	var r := await _call("POST", "/v1/account/bind", {"provider": provider, "credential": credential, "device_id": device_id})
	if int(r[0]) == 200:
		account_changed.emit()
	return r[1] if int(r[0]) == 200 else _fail(r)

## 用转移码登录别的账号。成功后不立刻切换：返回 {"ok", "cloud": 云端摘要, "local": 本机摘要}，
## 由玩家选 use_cloud_login()（推荐）或 keep_local_login()。
func login_transfer(acc: String, code: String) -> Dictionary:
	var r := await _call("POST", "/v1/auth/transfer", {"account_id": acc.strip_edges().to_upper(), "code": code.strip_edges(), "device_id": device_id}, "", true)
	return await _after_login(r)

func login_provider(provider: String, credential: String) -> Dictionary:
	var r := await _call("POST", "/v1/auth/provider", {"provider": provider, "credential": credential, "device_id": device_id}, "", true)
	return await _after_login(r)

func _after_login(r: Array) -> Dictionary:
	if int(r[0]) != 200:
		return _fail(r)
	var d: Dictionary = r[1]
	_pending_login = d
	if str(d.get("account_id", "")) == account_id:
		# 本来就是这个号（比如被顶下线后重新登录）：直接换上新 token，按正常启动拉存档
		await use_cloud_login()
		return {"ok": true, "same": true}
	return {"ok": true, "account_id": d.get("account_id", ""), "cloud": d.get("cloud", {}), "local": local_summary()}

## 用云端进度：作废本机游客号的 token，丢掉本机存档，换成登录的账号并拉它的存档。
func use_cloud_login() -> bool:
	if _pending_login.is_empty():
		return false
	var d := _pending_login
	_pending_login = {}
	var same := str(d.get("account_id", "")) == account_id
	if token != "" and not same and kicked == "":
		await _call("POST", "/v1/auth/logout", {}, "", false, token)
	account_id = str(d.get("account_id", ""))
	token = str(d.get("token", ""))
	expires_at = float(d.get("expires_at", 0.0))
	renew_after = float(d.get("renew_after", 0.0))
	kicked = ""
	if not same:
		version = 0
		sent_hash = ""
		pending = false
		events = []
		transfer_code = ""
	_hot_day = ""
	_hot_picks = null
	_hot_tried = ""
	_save_state()
	await _pull_async("relogin" if same else "login")
	account_changed.emit()
	return true

## 保留本机进度：放弃这次登录（作废刚拿到的会话），继续用本机的游客号。
func keep_local_login() -> void:
	if _pending_login.is_empty():
		return
	var d := _pending_login
	_pending_login = {}
	await _call("POST", "/v1/auth/logout", {}, "", false, str(d.get("token", "")))

## 本机进度摘要，和云端摘要对比给玩家看
func local_summary() -> Dictionary:
	var parts := 0
	for b in Data.BUILDS:
		if b is Dictionary:
			parts += clampi(int(G.builds.get(str(b.get("id", "")), 0)), 0, Data.build_stages(b))
	return {"level": G.level, "parts": parts, "amber": G.amber}

## 进度明显（不是刚开局）：用来决定要不要额外提醒
static func has_progress(s: Dictionary) -> bool:
	return int(s.get("level", 1)) >= 3 or int(s.get("parts", 0)) >= 3

func _fail(r: Array) -> Dictionary:
	var d: Dictionary = r[1] if r[1] is Dictionary else {}
	var msg := str(d.get("message", "连不上服务器，请稍后再试" if int(r[0]) == 0 else "操作失败"))
	return {"ok": false, "error": str(d.get("error", "offline")), "message": msg}

# ================================================================ 启动

func _boot() -> void:
	_retry_t = -1.0
	if _busy:
		return
	if token == "":
		_register()
	else:
		_pull_async("boot")

func _register() -> void:
	_busy = true
	var body := {"device_id": device_id}
	if G.loaded_save and G.player_id != "":
		body["player_id"] = G.player_id
	var r := await _call("POST", "/v1/auth/guest", body, "", true)
	_busy = false
	if int(r[0]) != 200:
		_offline("boot")
		return
	var d: Dictionary = r[1]
	account_id = str(d["account_id"])
	token = str(d["token"])
	expires_at = float(d.get("expires_at", 0.0))
	renew_after = float(d.get("renew_after", 0.0))
	version = 0
	sent_hash = ""
	pending = true
	if G.player_id != account_id:
		G.player_id = account_id
		G.dirty()
	_save_state()
	account_changed.emit()
	_pull_async("boot")

func _new_guest_after_reset() -> void:
	token = ""
	account_id = ""
	events = []
	transfer_code = ""
	_boot_done = false
	G.loaded_save = false
	_register()

## 拉服务器存档。服务器版本更新（或本机存档没了、或刚登录别的号）就用服务器的。
func _pull_async(why: String) -> void:
	_busy = true
	var r := await _call("GET", "/v1/save", null)
	_busy = false
	var code := int(r[0])
	var d: Dictionary = r[1]
	if code == 401:
		_boot_done = true
		return
	if code != 200:
		_offline("boot")
		return
	var sv := int(d.get("version", 0))
	var data := str(d.get("data", ""))
	var fresh: bool = not G.loaded_save and not _boot_done
	if data != "" and (why == "login" or (fresh and account_id != G.player_id) or sv > version or why == "stale" or why == "rejected"):
		var lost := pending and why in ["boot", "relogin"] and not fresh
		_apply_save(data, sv, str(d.get("hash", "")))
		match why:
			"stale": _say("别的设备上有更新的进度，已切换到云端存档")
			"rejected": _say("存档校验没通过，已恢复到云端进度")
			"login": _say("已切换到账号 %s 的云端进度" % account_id)
			_:
				if fresh:
					_say("已从云端恢复进度")
				elif lost:
					_say("云端有更新的进度，已同步")
	else:
		if data == "" and why == "login":
			# 登录的号在服务器上还没有存档（几乎不会）：从新局开始
			G.new_game()
			G.player_id = account_id
		if sv < version:
			version = sv
		# 和上次同步后的本地内容比（服务器存的是合并前的哈希，对不上本地）
		if _local_hash() != sent_hash:
			pending = true
		if d.get("state") is Dictionary and events.is_empty():
			apply_state(d["state"])
	_after_boot()
	if pending or not events.is_empty():
		_upload()
	want_hot()

func _after_boot() -> void:
	_boot_done = true
	online = true
	_save_state()
	_set_clock_ready()
	synced.emit("boot", true)

func _set_clock_ready() -> void:
	var first := not clock_ready
	clock_ready = true
	_day = today()
	if first or G.deals_day != _day:
		G._check_day()

func _offline(what: String) -> void:
	online = false
	_retry_t = RETRY_SEC
	if not clock_ready:
		_set_clock_ready()
	synced.emit(what, false)

func _refresh_token() -> void:
	_busy = true
	var r := await _call("POST", "/v1/auth/refresh", {})
	_busy = false
	if int(r[0]) == 200:
		token = str(r[1]["token"])
		expires_at = float(r[1].get("expires_at", 0.0))
		renew_after = float(r[1].get("renew_after", 0.0))
		_save_state()
	else:
		renew_after = server_now() + 3600.0

# ================================================================ 上传

## 规范化后的存档 JSON：先过一遍 parse，读档前后（int / float 混着）得到同一份文本，哈希才对得上
func _local_snapshot() -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(G.save_dict())))

func _local_hash() -> String:
	return _local_snapshot().md5_text()

func _upload() -> void:
	_retry_t = -1.0
	if _busy or token == "" or kicked != "":
		return
	var txt := _local_snapshot()
	var h := txt.md5_text()
	if h == sent_hash and events.is_empty():
		pending = false
		_mark_t = -1.0
		_save_state()
		return
	var batch: Array = events.slice(0, 200)
	var data := Marshalls.raw_to_base64(txt.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	var gen := _mark_gen
	_busy = true
	_last_up = _ticks()
	var r := await _call("PUT", "/v1/save", {"base": version, "hash": h, "data": data, "events": batch})
	_busy = false
	var code := int(r[0])
	var d: Dictionary = r[1]
	match code:
		200:
			online = true
			uploads += 1
			version = int(d.get("version", version))
			sent_hash = h
			_drop_events(batch)
			if gen == _mark_gen:
				pending = false
				_mark_t = -1.0
			else:
				_mark_t = 0.0
			last_sync = server_now()
			if d.get("state") is Dictionary and events.is_empty():
				apply_state(d["state"])
				G.save_game()
				# 服务器字段写回后，本地快照就等于服务器合并后的那份：以后按新内容比较
				sent_hash = _local_hash()
			_save_state()
			synced.emit("upload", true)
			if _hot_day != today():
				_hot_tried = ""
				want_hot()
		409:
			synced.emit("upload", false)
			_pull_async("stale")
		422:
			push_warning("[cloud] 快照被服务器拒绝：%s" % str(d.get("message", "")))
			_drop_events(batch)
			synced.emit("upload", false)
			_pull_async("rejected")
		401:
			synced.emit("upload", false)
		_:
			_offline("upload")

## 只交事件（act 之前用）。成功返回 true。
func _send_events() -> bool:
	_busy = true
	var batch: Array = events.slice(0, 200)
	var r := await _call("POST", "/v1/events", {"events": batch})
	_busy = false
	if int(r[0]) != 200:
		return false
	_drop_events(batch)
	_save_state()
	if r[1].get("state") is Dictionary and events.is_empty():
		apply_state(r[1]["state"])
	synced.emit("events", true)
	return true

func _drop_events(batch: Array) -> void:
	var ids := {}
	for e in batch:
		ids[str(e.get("id", ""))] = true
	events = events.filter(func(e): return not ids.has(str(e.get("id", ""))))

## 用服务器的存档覆盖本地
func _apply_save(b64: String, sv: int, _h: String) -> void:
	var raw := Marshalls.base64_to_raw(b64).decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	var txt := raw.get_string_from_utf8()
	var d = JSON.parse_string(txt)
	if not (d is Dictionary and d.has("board")):
		push_warning("[cloud] 服务器存档解不开，保持本地")
		return
	var f := FileAccess.open(G.save_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(txt)
	f.close()
	if not G.load_game():
		return
	G.loaded_save = true
	G.player_id = account_id
	version = sv
	sent_hash = _local_hash()
	pending = false
	_hot_day = ""
	_hot_picks = null
	_hot_tried = ""
	_save_state()
	G._check_day()
	G.board_changed.emit()
	G.orders_changed.emit()
	G.changed.emit()
	restored.emit()

# ================================================================ 热卖

func _fetch_hot() -> void:
	_hot_busy = true
	var day := today()
	var r := await _call("GET", "/v1/shop", null)
	_hot_busy = false
	_hot_tried = day
	if int(r[0]) == 200 and r[1].get("picks") is Array:
		accept_hot(str(r[1].get("day", day)), int(r[1].get("hot_revision", 0)), r[1]["picks"])
		synced.emit("hot", true)
	else:
		synced.emit("hot", false)

# ================================================================ 退出

func _quit() -> void:
	if _quitting:
		return
	_quitting = true
	if G.is_processing():
		G.save_game()
	# 通知分发过程中不能 add_child（HTTPRequest），等一帧
	await get_tree().process_frame
	if can_talk() and not _busy and (pending or not events.is_empty()):
		_upload()
	var t0 := _ticks()
	while _busy and _ticks() - t0 < QUIT_WAIT:
		await get_tree().process_frame
	_save_state()
	get_tree().quit()

# ================================================================ 网络

func _ticks() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func _uuid() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

## 发请求，返回 [code, data]。连不上 / 超时 code = 0。每次成功都顺手校一下服务器时间。
## 401（被顶下线 / 过期）统一在这里处理。anon = 不带 token；use_token 指定用哪个 token（不触发下线处理）。
func _call(method: String, path: String, body, idem := "", anon := false, use_token := "") -> Array:
	var h := HTTPRequest.new()
	h.timeout = TIMEOUT
	add_child(h)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var tk := use_token if use_token != "" else token
	if not anon and tk != "":
		headers.append("Authorization: Bearer " + tk)
	if idem != "":
		headers.append("Idempotency-Key: " + idem)
	var m := HTTPClient.METHOD_GET
	match method:
		"POST": m = HTTPClient.METHOD_POST
		"PUT": m = HTTPClient.METHOD_PUT
	var sent_at := Time.get_ticks_msec()
	var err := h.request(url + path, headers, m, "" if body == null else JSON.stringify(body))
	if err != OK:
		h.queue_free()
		await get_tree().process_frame
		return [0, {}]
	var res: Array = await h.request_completed
	h.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		return [0, {}]
	var d = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if not (d is Dictionary):
		return [0, {}]
	var code := int(res[1])
	if d.has("now"):
		var rtt := Time.get_ticks_msec() - sent_at
		_srv_unix = float(d["now"]) + float(rtt) / 2000.0
		_srv_tick = Time.get_ticks_msec()
		clock_offset = _srv_unix - Time.get_unix_time_from_system()
	if code == 401 and not anon and use_token == "":
		_on_kicked(str(d.get("error", "unauthorized")))
	return [code, d]

func _on_kicked(why: String) -> void:
	if kicked != "":
		return
	kicked = why if why in ["session_replaced", "token_expired", "session_revoked"] else "session_revoked"
	_save_state()
	_say(_kick_text(kicked))
	account_changed.emit()

func _kick_text(why: String) -> String:
	match why:
		"session_replaced": return "账号已在其他设备登录，本机不再同步。可在 设置 → 账号与数据 重新登录"
		"token_expired": return "登录已过期，请在 设置 → 账号与数据 重新登录"
	return "已退出登录，请在 设置 → 账号与数据 重新登录"

# ================================================================ 本地状态

func _load_state() -> void:
	var f := FileAccess.open(state_path, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary):
		return
	device_id = str(d.get("device_id", ""))
	account_id = str(d.get("account_id", ""))
	token = str(d.get("token", ""))
	expires_at = float(d.get("expires_at", 0.0))
	renew_after = float(d.get("renew_after", 0.0))
	version = int(d.get("version", 0))
	sent_hash = str(d.get("sent_hash", ""))
	pending = bool(d.get("pending", false))
	events = d.get("events", []) if d.get("events") is Array else []
	transfer_code = str(d.get("transfer_code", ""))
	last_sync = float(d.get("last_sync", 0.0))
	clock_offset = float(d.get("clock_offset", 0.0))
	kicked = str(d.get("kicked", ""))

func _save_state() -> void:
	var f := FileAccess.open(state_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"device_id": device_id, "account_id": account_id, "token": token,
		"expires_at": expires_at, "renew_after": renew_after, "version": version, "sent_hash": sent_hash,
		"pending": pending, "events": events, "transfer_code": transfer_code, "last_sync": last_sync,
		"clock_offset": clock_offset, "kicked": kicked}))

func _say(text: String) -> void:
	notice.emit(text)
	if G.main != null and G.main.has_method("toast"):
		G.main.toast(text)

func accept_hot(day: String, revision: int, picks: Array) -> void:
	_hot_day = day
	_hot_revision = revision
	_hot_picks = picks
