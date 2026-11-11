extends SceneTree
## 礼包链：截图 + 联调。连一个本地临时服务器（自己先起：python server/run.py --port 18768 --database-url sqlite:///…/gift.db），
## 用 mock 支付走「免费 → 付费 → 免费」，每步核对服务器结果和本地余额，沿途截图（刚开始、队列前移中、买了几步之后）。
## 不碰真实存档：存档 / 云状态 / 排行 / 热卖都指向 user://gift_shot/。
## Godot --path . --script tools/gift_shot.gd -- --save=user://gift_shot/s.json --cloud-state=user://gift_shot/c.json
##   --rank-state=user://gift_shot/r.json --hot-file=user://gift_shot/h.json --cloud-url=http://127.0.0.1:18768 --out=DIR
## 加 --cloud-off 只截「需要联网」那张。

var _started := false
var out := "."
var _fail := 0

func _process(_d: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _ok(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		_fail += 1

func _shot(name: String) -> void:
	var path := out + "/gift_" + name + ".png"
	root.get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path)

func _run() -> void:
	var g := root.get_node("G")
	g.set_process(false)
	root.get_node("Rank").set_process(false)
	var off := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a == "--cloud-off":
			off = true
	g.tutorial_on = false
	g.seen_tutorial = true
	g.level = 6
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	var cloud = root.get_node("Cloud")
	var chain = load("res://scripts/net/GiftChain.gd").inst()
	main.show_screen("home")
	if off:
		await create_timer(1.0).timeout
		_shot("home_offline")
		load("res://scripts/ui/GiftChainPopup.gd").pop_open()
		await create_timer(1.0).timeout
		_shot("popup_offline")
		_ok(not chain.online(), "离线：不能领")
		var r: Dictionary = await chain.claim(0)
		_ok(not r.get("ok", false) and str(r.get("error", "")) == "offline", "离线领免费步被拒：%s" % str(r.get("message", "")))
		_finish()
		return
	# 等云服务注册好游客号
	var t0 := Time.get_ticks_msec()
	while not cloud.can_talk() and Time.get_ticks_msec() - t0 < 15000:
		await process_frame
	_ok(cloud.can_talk(), "连上本地服务器（%s）" % cloud.url)
	chain.fetch()
	while not chain.fetched_once and Time.get_ticks_msec() - t0 < 20000:
		await process_frame
	_ok(chain.ok and chain.head() == 0, "拿到队列，队首第 1 步，共 %d 步" % chain.total())
	_ok(chain.free_ready(), "第 1 步免费 → 入口亮红点")
	await create_timer(0.8).timeout
	_shot("home_card")
	var p = load("res://scripts/ui/GiftChainPopup.gd").pop_open()
	await create_timer(1.2).timeout
	_shot("popup_start")
	# 1) 免费步
	var e0: int = g.energy
	var s0: int = g.shells
	await _press(p)
	_ok(chain.head() == 1, "免费步领完，队首前移到第 2 步")
	await create_timer(0.12).timeout
	_shot("popup_shift_a")
	await create_timer(0.2).timeout
	_shot("popup_shift_b")
	await create_timer(1.4).timeout
	_ok(g.energy == e0 + 50, "火苗 +50（%d → %d）" % [e0, g.energy])
	_ok(g.shells == s0 + 100, "不拿拿 +100（服务器值 %d）" % g.shells)
	_shot("popup_step2")
	# 2) 付费步 ¥6（mock 支付）
	var a0: int = g.amber
	var st0: int = g.stash.size()
	await _press(p)
	_ok(chain.head() == 2, "付费步验单发货，队首前移到第 3 步")
	await create_timer(1.8).timeout
	_ok(g.amber == a0 + 200, "琥珀 +200（%d → %d）" % [a0, g.amber])
	_ok(g.stash.size() >= st0 + 2, "宝箱进暂存（暂存 %d → %d）" % [st0, g.stash.size()])
	# 3) 免费步
	await _press(p)
	_ok(chain.head() == 3, "第 3 步免费领完")
	await create_timer(1.8).timeout
	_shot("popup_after3")
	# 服务器侧再确认一次
	chain.fetch()
	await chain.updated
	_ok(chain.head() == 3, "服务器记的进度：第 %d 步" % (chain.head() + 1))
	# 一路领 / 买到第 10 步（¥68「超值」），看后面的大礼包
	while chain.head() < 9:
		var h: int = chain.head()
		await _press(p)
		if chain.head() == h:
			_ok(false, "第 %d 步没领成" % (h + 1))
			break
		await create_timer(1.3).timeout
	_ok(chain.head() == 9, "走到第 10 步")
	await create_timer(1.0).timeout
	_shot("popup_step10")
	p.close()
	await create_timer(0.5).timeout
	_shot("home_after")
	_finish()

func _press(p) -> void:
	var btn = p.find_child("gift_btn", true, false)
	if btn == null:
		_ok(false, "找不到按钮")
		return
	var h: int = p.chain.head()
	btn.pressed.emit()
	var t0 := Time.get_ticks_msec()
	while p.chain.head() == h and Time.get_ticks_msec() - t0 < 10000:
		await process_frame

func _finish() -> void:
	print("RESULT: " + ("PASS" if _fail == 0 else "FAIL %d" % _fail))
	quit(0 if _fail == 0 else 1)
