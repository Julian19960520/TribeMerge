extends SceneTree
## 竞品式新手流程走一遍，不能卡住：
## 一、强引导（全屏蒙黑只露交互区）：剧情句点击继续、合成、合出生产器（弹新生产器）、生产、交两单、第一次建设、
##    讲订单和等级（点开等级详情）后结束；每个要操作的步骤都必须亮出至少一块区域。
## 二、引导后的一次性提示：第二次建设送半编草篓 → 暂存区 → 合到藤蔓上 → 两只小草篓合成藤篮 → 点藤篮。
## godot --headless --path . --script tools/check_guide_playthrough.gd -- --replay-test --cloud-off
## 加 --guide-shots=DIR 时每个步骤第一次出现截一张图（需要有窗口，不能 --headless）
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

const ACTIONS := ["merge1", "vine", "to_prod", "produce", "make_fruit2", "submit1", "produce_more", "climb",
	"submit2", "upgrade", "build", "back", "level"]
const BEATS := ["merge1", "produce", "produce_more", "upgrade", "back", "level"]

var shots := ""
var new_gen_seen := false

func _drag(board, a: int, b: int) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = board.cell_center(a)
	board._gui_input(e)
	for t in [0.3, 1.0]:
		var m := InputEventMouseMotion.new()
		m.position = board.cell_center(a).lerp(board.cell_center(b), t)
		board._gui_input(m)
	var r := InputEventMouseButton.new()
	r.button_index = MOUSE_BUTTON_LEFT
	r.pressed = false
	r.position = board.cell_center(b)
	board._gui_input(r)

func _find_btn(n: Node, res: String):
	if "res" in n and str(n.get("res")) == res: return n
	for c in n.get_children():
		var f = _find_btn(c, res)
		if f != null: return f
	return null

func _shot(name: String) -> void:
	if shots == "": return
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots, name])

## 领奖全屏、升级弹窗、新生产器弹窗：点掉（建设窗不点，它要按绿按钮）
func _tap_popups(main) -> void:
	for p in main.popup_layer.get_children():
		var tap = p.get("on_tap")
		var tappable: bool = tap is Callable and tap.is_valid()
		if (p.has_meta("board_reward") or p.has_meta("reward_screen") or tappable) and _find_btn(p, "shell_2") == null:
			if tappable: tap.call()
			elif p.has_method("close"): p.close()

func _on_present(kind, _payload) -> void:
	if kind == "new_generator": new_gen_seen = true

func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--guide-shots="): shots = a.trim_prefix("--guide-shots=")
	var g = root.get_node("G")
	g.new_game()
	g.presentation_event.connect(_on_present)
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.3).timeout
	var guide = main._guide
	var bs = main.board_screen
	var board = bs.board
	var seen := {}
	var beats := {}
	var stuck := 0
	var last := ""
	var empty := 0
	var to_build_ticks := 0
	var beat_locked := true
	## 交第一张单（樱桃）时，藤蔓下的樱桃（第 33 格）还压在石头下，不会出现「交单还是开藤蔓」二选一
	var vine_cherry_hidden := true
	for _k in 600:
		if not g.tutorial_on: break
		if shots != "":
			for p in main.popup_layer.get_children():
				if p.has_meta("reward_screen") and not seen.has("popup_%d" % p.get_instance_id()):
					seen["popup_%d" % p.get_instance_id()] = true
					await _shot("popup_%02d" % seen.size())
		_tap_popups(main)
		var step: String = guide._step
		if not seen.has(step + guide._beat) and guide.visible:
			await _shot("guide_%02d_%s%s" % [seen.size(), step, "_beat" if guide._beat != "" else ""])
			step = guide._step
		seen[step + guide._beat] = true
		seen[step] = true
		if step == "to_build": to_build_ticks += 1
		## 剧情句：亮着但不让操作，点任意处继续
		if guide._beat != "":
			beats[guide._beat] = true
			if guide.visible and (guide.allows_drop(guide.SRC, guide.DST) or guide.allows_activate(guide.PROD) or not guide._pass.is_empty()):
				beat_locked = false
			await create_timer(0.45).timeout
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			guide._gui_input(click)
			await create_timer(0.1).timeout
			continue
		## 转场、弹出动画的一两帧里区域可能还没量出来，连续 2 秒都没有才算错
		empty = empty + 1 if step in ACTIONS and guide.visible and guide._strong() and guide._holes.is_empty() else 0
		if empty > 8:
			check(false, "步骤 %s 没有亮出可操作区域" % step)
			break
		match step:
			"merge1", "vine", "stones", "to_prod", "make_fruit2", "climb":
				if guide._merge_a >= 0 and guide._merge_b >= 0:
					_drag(board, guide._merge_a, guide._merge_b)
				elif step == "climb":
					bs._on_activate(guide.PROD)
			"produce", "produce_more":
				bs._on_activate(guide.PROD)
			"submit1", "submit2":
				if step == "submit1" and int(g.board[33]["lock"]) != 2: vine_cherry_hidden = false
				for oi in g.orders.size():
					if g.rules.orders.order_ready(g.orders[oi]):
						bs._on_deliver(oi)
						break
			"upgrade":
				bs._on_hammer()
			"build":
				for p in main.popup_layer.get_children():
					var b = _find_btn(p, "shell_2")
					if b != null: b.pressed.emit()
			"back":
				main.home.go.pressed.emit()
			"level":
				bs._base_btn.pressed.emit()
		stuck = stuck + 1 if step == last else 0
		last = step
		if stuck == 20 and OS.get_environment("GUIDE_DEBUG") != "":
			print("DEBUG step=%s screen=%s popups=%s" % [step, main.screen, main.popup_layer.get_children()])
		if stuck > 60:
			check(false, "引导卡在 %s" % step)
			break
		await create_timer(0.25).timeout
	check(not g.tutorial_on, "整段引导能走完")
	for s in ACTIONS:
		check(seen.has(s), "经过了步骤 %s" % s)
	for b in BEATS:
		check(beats.has(b), "说了剧情句 %s" % b)
	check(beat_locked, "剧情句时棋盘和按钮都点不了")
	check(vine_cherry_hidden and str(g.board[33]["id"]) != "fruit_2", "第一张单的樱桃不用和藤蔓抢：交单时藤蔓樱桃还没露出来，之后爬藤时才打开")
	check(new_gen_seen, "合出小草篓时弹了新生产器")
	check(g.level == 1 and g.xp == 2, "引导结束时经验 2/3，再交一单升级")
	## 截图模式每张停 0.8 秒，量不准，只在正常跑的时候查
	if shots == "": check(to_build_ticks > 0 and to_build_ticks <= 4, "点锤子后建设窗 1 秒内弹出（%d 次轮询）" % to_build_ticks)

	# ---- 二、第二次建设送半编草篓，提示带着把生产器升到藤篮
	await create_timer(0.5).timeout
	for p in main.popup_layer.get_children():
		if p.has_method("close"): p.close()
	await create_timer(0.3).timeout
	g.shells += 1000
	var built: Dictionary = await root.get_node("Replay").perform("build", {"id": "fire"})
	check(not built.has("error") and g.stash.has("basket_3"), "第二次建设送半编草篓（进暂存区）")
	var tips = main.tips
	var b5_tapped := false
	new_gen_seen = false
	for _k in 200:
		_tap_popups(main)
		for p in main.popup_layer.get_children():
			if p.get_meta("fullscreen", false) and p.has_method("close"): p.close()
		if tips.visible:
			if not seen.has("tip_" + tips._key):
				seen["tip_" + tips._key] = true
				await _shot("tip_%s" % tips._key)
			match tips._key:
				"stash":
					bs._on_stash()
					tips._close(false)
				"gen_merge3":
					var p3: Vector2i = tips._merge3_pair()
					if p3.x >= 0: _drag(board, p3.x, p3.y)
				"gen_merge5":
					var p5: Vector2i = tips._pair_of("basket_4")
					if p5.x >= 0: _drag(board, p5.x, p5.y)
				"gen_tap":
					bs._on_activate(tips._find_id("basket_5"))
					tips._close(false)
					b5_tapped = true
				_:
					tips._close(false)
		if b5_tapped: break
		await create_timer(0.25).timeout
	for k in ["howto", "stash", "gen_merge3", "gen_merge5", "gen_tap"]:
		check(g.tips_seen.has(k), "引导后的提示 %s 出现过" % k)
	check(new_gen_seen, "合出藤篮时弹了生产器升级")
	check(b5_tapped and tips._find_id("basket_5") >= 0, "提示带着把生产器升到藤篮并点了它")
	quit(1 if failures > 0 else 0)
