extends Node
## 云存档客户端（自动加载 Cloud，排在 G、Rank 后面）。
## 本地优先：G.save_game / load_game 照常写本地存档；这里另外把整份存档（gzip + base64，约 2KB）同步到服务器。
## - 只在关键事件后 mark()（交单、建造、升级、花/得琥珀、开卡包），合并后最多每 UPLOAD_GAP 秒传一次；
##   切后台 / 关窗口时补传一次；内容哈希和服务器那份一样就不传。
## - 启动先拉服务器版本，服务器 version 更新就用服务器的；上传时 version 落后（409）或校验没过（422）
##   都拉服务器最新版覆盖本地并提示。
## - 连不上就照常单机，每 RETRY_SEC 秒再试。
## - 「今天」按服务器时间（北京时间）算；连上过一次后，本局都用服务器时间推算，改系统时间没用。
## - 集市热卖：服务器每人每天抽一次（hot_for），连不上时 HotDeals 退回本地逻辑。
## 身份：G.player_id + 服务器首次注册时下发的 token，存在 user://cloud_state.json（不在主存档里，删存档不丢）。
## 规则和开销估算见 DESIGN.md「十二、云存档」。

## 拉了服务器存档覆盖本地之后发出
signal restored
## 给玩家看的提示（另外会走 G.main.toast）
signal notice(text: String)
## 每次请求结束：what = "boot" / "upload" / "hot" / "purchase"，ok 是否成功
signal synced(what: String, ok: bool)

const DEFAULT_URL := "http://127.0.0.1:8765"
const TIMEOUT := 5.0
const UPLOAD_GAP := 60.0
## 第一次 mark 之后再等几秒才传，把连着的几步操作并成一次
const MERGE_DELAY := 3.0
const RETRY_SEC := 90.0
## 关窗口时最多等上传这么久
const QUIT_WAIT := 2.0
const DAY_OFFSET := 8 * 3600

## 测试可以用 `-- --cloud-state=user://xxx.json --cloud-url=http://...` 换掉
var state_path := "user://cloud_state.json"
var url := DEFAULT_URL
## 关掉整个同步（--cloud-off）
var enabled := true
## 测试用：假装本机时钟偏了这么多秒（只影响还没连上服务器时的本地时间）
var debug_skew := 0.0

# ---- 存在 cloud_state.json 里的
## token 对应的玩家 id
var pid := ""
var token := ""
## 本地存档基于的服务器版本
var version := 0
## 服务器上那份存档的哈希
var sent_hash := ""
var pending := false
## 还没报给服务器的充值琥珀
var credits: Array = []

# ---- 运行时
var online := false
## 拿到过服务器时间
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
var _hot_picks = null
var _hot_busy := false
var _hot_tried := ""
var _quitting := false

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
	if enabled:
		_boot.call_deferred()
	else:
		_set_clock_ready()

func _process(delta: float) -> void:
	_day_t += delta
	if _day_t >= 2.0:
		_day_t = 0.0
		var d := today()
		if d != _day:
			_day = d
			if clock_ready:
				G._check_day()
	if not enabled or _quitting:
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
	if G.player_id != pid:
		# 游戏里重新开始了：换一个身份
		_boot()
		return
	if pending:
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

# ---------------------------------------------------------------- 对外

## 关键事件后调用：记一笔「待上传」
func mark() -> void:
	_mark_gen += 1
	if not pending:
		pending = true
		_mark_t = 0.0
		_save_state()

## 马上补传（切后台、退出、测试）。不看 60 秒间隔，内容没变照样不传。
func flush() -> void:
	if enabled and _boot_done and not _busy and token != "" and (pending or not credits.is_empty()):
		_upload()

## 演示版充值到账：先记下来，服务器据此放行下一份快照里多出来的琥珀
func purchase(amber_n: int) -> void:
	if amber_n <= 0:
		return
	credits.append(amber_n)
	_save_state()
	mark()
	if _boot_done and token != "" and not _busy:
		_send_credits(Callable())

func server_now() -> float:
	if _srv_tick > 0:
		return _srv_unix + float(Time.get_ticks_msec() - _srv_tick) / 1000.0
	return Time.get_unix_time_from_system() + debug_skew

## 今天的日期（北京时间），每日重置、热卖都看它
func today() -> String:
	return Time.get_date_string_from_unix_time(int(server_now()) + DAY_OFFSET)

func secs_to_midnight() -> int:
	return 86400 - (int(server_now()) + DAY_OFFSET) % 86400

## 服务器给的今天热卖换货 [{"slot", "id"}]；还没拿到返回 null
func hot_for(day: String):
	if _hot_day == day and _hot_picks is Array:
		return _hot_picks
	return null

## 打开集市时调用：还没有今天的货单就去要
func want_hot() -> void:
	if enabled and _boot_done and online and token != "" and not _hot_busy and _hot_tried != today():
		_fetch_hot()

# ---------------------------------------------------------------- 启动

func _boot() -> void:
	_retry_t = -1.0
	if _busy:
		return
	var fresh: bool = not G.loaded_save
	if token != "" and pid != "" and (pid == G.player_id or fresh):
		_pull("boot")
	else:
		_register()

func _register() -> void:
	pid = G.player_id
	token = ""
	version = 0
	sent_hash = ""
	pending = true
	_hot_day = ""
	_hot_picks = null
	_hot_tried = ""
	_busy = true
	_req("/api/register", HTTPClient.METHOD_POST, {"id": pid}, func(code: int, d: Dictionary):
		_busy = false
		if code == 200:
			token = str(d.get("token", ""))
			_save_state()
			_pull("boot")
		elif code == 409:
			# id 被别人注册了而我们没有 token：只能单机
			push_warning("[cloud] 玩家 id %s 已在服务器注册，本机没有 token，云存档停用" % pid)
			_boot_done = true
			online = true
			_set_clock_ready()
			synced.emit("boot", false)
		else:
			_offline("boot"))

## 拉服务器版本；比本地新就用服务器的
func _pull(why: String) -> void:
	_busy = true
	_req("/api/save?id=%s" % pid.uri_encode(), HTTPClient.METHOD_GET, null, func(code: int, d: Dictionary):
		_busy = false
		if code == 200:
			var sv := int(d.get("version", 0))
			var data := str(d.get("data", ""))
			var fresh: bool = not G.loaded_save and not _boot_done
			if fresh and pid != G.player_id:
				if data == "":
					# 本地存档删了，服务器上也没有：就用新开的这局
					_register()
					return
				_apply(data, sv, str(d.get("hash", "")))
				_say("已从云端恢复进度")
			elif data != "" and (sv > version or why != "boot"):
				var lost := pending and why == "boot"
				_apply(data, sv, str(d.get("hash", "")))
				if why == "stale":
					_say("别的设备上有更新的进度，已切换到云端存档")
				elif why == "rejected":
					_say("存档校验没通过，已恢复到云端进度")
				elif lost:
					_say("云端有更新的进度，已同步")
			else:
				if sv < version:
					version = sv
				if _local_hash() != str(d.get("hash", "")):
					pending = true
				sent_hash = str(d.get("hash", ""))
			_after_boot()
			if why == "boot" and (pending or not credits.is_empty()):
				_upload()
			want_hot()
		elif code == 403 or code == 404:
			if code == 404:
				_register()
				return
			push_warning("[cloud] token 被拒绝，云存档停用")
			_after_boot()
		else:
			_offline("boot"))

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

# ---------------------------------------------------------------- 上传

## 规范化后的存档 JSON：先过一遍 parse，读档前后（int / float 混着）得到同一份文本，哈希才对得上
func _local_snapshot() -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(G.save_dict())))

func _local_hash() -> String:
	return _local_snapshot().md5_text()

func _upload() -> void:
	_retry_t = -1.0
	if _busy or token == "":
		return
	if not credits.is_empty():
		_send_credits(_upload)
		return
	var txt := _local_snapshot()
	var h := txt.md5_text()
	if h == sent_hash:
		pending = false
		_save_state()
		return
	var data := Marshalls.raw_to_base64(txt.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	var gen := _mark_gen
	_busy = true
	_last_up = _ticks()
	_req("/api/save", HTTPClient.METHOD_POST, {"id": pid, "base": version, "hash": h, "data": data},
		func(code: int, d: Dictionary): _on_upload(code, d, h, gen))

func _on_upload(code: int, d: Dictionary, h: String, gen: int) -> void:
	_busy = false
	match code:
		200:
			online = true
			uploads += 1
			version = int(d.get("version", version))
			sent_hash = h
			if gen == _mark_gen:
				pending = false
			else:
				_mark_t = 0.0
			_save_state()
			synced.emit("upload", true)
			if _hot_day != today():
				_hot_tried = ""
				want_hot()
		409:
			synced.emit("upload", false)
			_pull("stale")
		422:
			push_warning("[cloud] 快照被服务器拒绝：%s" % str(d.get("reason", "")))
			synced.emit("upload", false)
			_pull("rejected")
		403, 404:
			synced.emit("upload", false)
			_register()
		_:
			_offline("upload")

func _send_credits(then: Callable) -> void:
	if credits.is_empty():
		if then.is_valid():
			then.call()
		return
	_busy = true
	var n := int(credits[0])
	_req("/api/purchase", HTTPClient.METHOD_POST, {"id": pid, "amber": n}, func(code: int, _d: Dictionary):
		_busy = false
		if code == 200:
			credits.remove_at(0)
			_save_state()
			synced.emit("purchase", true)
			_send_credits(then)
		elif code == 400:
			credits.remove_at(0)
			_save_state()
			_send_credits(then)
		else:
			_offline("purchase"))

## 用服务器的存档覆盖本地
func _apply(b64: String, sv: int, h: String) -> void:
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
	pid = G.player_id
	version = sv
	sent_hash = h if h != "" else txt.md5_text()
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

# ---------------------------------------------------------------- 热卖

func _fetch_hot() -> void:
	_hot_busy = true
	var day := today()
	_req("/api/hot?id=%s" % pid.uri_encode(), HTTPClient.METHOD_GET, null, func(code: int, d: Dictionary):
		_hot_busy = false
		_hot_tried = day
		if code == 200 and d.get("picks") is Array:
			_hot_day = str(d.get("day", day))
			_hot_picks = d["picks"]
			synced.emit("hot", true)
		else:
			synced.emit("hot", false))

# ---------------------------------------------------------------- 退出

func _quit() -> void:
	if _quitting:
		return
	_quitting = true
	# 测试脚本会关掉 G 的 _process，那时不替它写存档
	if G.is_processing():
		G.save_game()
	# 通知分发过程中不能 add_child（HTTPRequest），等一帧
	await get_tree().process_frame
	if enabled and _boot_done and token != "" and not _busy and (pending or not credits.is_empty()):
		_upload()
	if _busy:
		var t0 := _ticks()
		while _busy and _ticks() - t0 < QUIT_WAIT:
			await get_tree().process_frame
	_save_state()
	get_tree().quit()

# ---------------------------------------------------------------- 网络

func _ticks() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

## 发请求；done(code, data)。连不上 / 超时 code = 0。每次成功都顺手校一下服务器时间。
func _req(path: String, method: int, body, done: Callable) -> void:
	var h := HTTPRequest.new()
	h.timeout = TIMEOUT
	add_child(h)
	var sent_at := Time.get_ticks_msec()
	h.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, raw: PackedByteArray):
		h.queue_free()
		var d = null
		if result == HTTPRequest.RESULT_SUCCESS:
			d = JSON.parse_string(raw.get_string_from_utf8())
		if not (d is Dictionary):
			done.call(0, {})
			return
		if d.has("now"):
			var rtt := Time.get_ticks_msec() - sent_at
			_srv_unix = float(d["now"]) + float(rtt) / 2000.0
			_srv_tick = Time.get_ticks_msec()
		done.call(code, d))
	var headers := PackedStringArray(["Content-Type: application/json"])
	if token != "":
		headers.append("X-Token: " + token)
	var err := h.request(url + path, headers, method, "" if body == null else JSON.stringify(body))
	if err != OK:
		h.queue_free()
		done.call_deferred(0, {})

# ---------------------------------------------------------------- 本地状态

func _load_state() -> void:
	var f := FileAccess.open(state_path, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary):
		return
	pid = str(d.get("pid", ""))
	token = str(d.get("token", ""))
	version = int(d.get("version", 0))
	sent_hash = str(d.get("sent_hash", ""))
	pending = bool(d.get("pending", false))
	credits = []
	var c = d.get("credits", [])
	if c is Array:
		for x in c:
			credits.append(int(x))

func _save_state() -> void:
	var f := FileAccess.open(state_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"pid": pid, "token": token, "version": version, "sent_hash": sent_hash,
		"pending": pending, "credits": credits}))

func _say(text: String) -> void:
	notice.emit(text)
	if G.main != null and G.main.has_method("toast"):
		G.main.toast(text)
