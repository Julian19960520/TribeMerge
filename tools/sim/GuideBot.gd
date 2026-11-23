extends Node
## 新手引导机器人：像玩家一样点真实界面和共享命令，从开场走到新手结束。
## 不往棋盘塞物品、不改货币。check_guide_playthrough.gd 和统一演算（autoplay.gd）共用这一套。
## 用法：add_child 到场景树，设好 main/game/replay，await play()。

var main
var game
var replay
## 每一步之间等多久（秒）；自由阶段节奏更快
var step_delay := 0.12
var free_delay := 0.03
var max_steps := 3500
## 每进入一个新步骤先调用一次：on_step.call(step_key) 可以 await（截图、做检查）
var on_step: Callable
## 外部要求停下（演算界面点了「停止」）
var stop := false

var seen := {}
var steps := 0
var free_seen := false
var manual_seen := false
var waited_min := 0
## 卡住时的原因；空字符串表示正常走完或被叫停
var error := ""

func _find(id: String, include_locked := false) -> int:
	for i in game.board.size():
		if str(game.board[i]["id"]) == id and (int(game.board[i]["lock"]) == 0 or include_locked and int(game.board[i]["lock"]) == 1): return i
	return -1

func find_button(n: Node, name: String):
	if n is Control and n.has_signal("pressed") and (n.name == name or name == "build" and n.get("res") == "shell_2"): return n
	for child in n.get_children():
		var found = find_button(child, name)
		if found != null: return found
	return null

func _tap_popups() -> bool:
	var p = main.popup_layer.top()
	if p == null: return false
	if p._closing: return true
	var step := str(game.rules.onboarding.stage().get("key", ""))
	if step in ["level_rule", "level_preview", "recipe_mats", "recipe_time", "recipe_ready"]:
		main._guide.skip_beat()
	elif step in ["level_close", "recipe_close", "build_preview"]: p.close()
	elif step == "build1":
		var button = find_button(p, "build")
		if button != null: button.pressed.emit()
	elif step == "howto": p.close()
	elif p.on_tap.is_valid(): p.on_tap.call()
	else: p.close()
	return true

func _produce() -> bool:
	var id := str(game.rules.onboarding.config()["upgraded_generator"])
	var at := _find(id)
	if at < 0: at = _find(str(game.rules.onboarding.config()["generator"]))
	if at < 0: return false
	if game.energy == 0:
		# 四级送的产体力物品先用掉，再考虑买体力
		if game.level >= 4:
			var egen := _find("emberpot_1")
			if egen >= 0 and game.rules.board.gen_left(egen) > 0:
				replay.perform("tap", {"cell": egen}); return true
			var stashed: int = game.stash.find("emberpot_1")
			if stashed >= 0: replay.perform("stash", {"index": stashed}); return true
		var result: Dictionary = replay.perform("energy")
		if result.get("free", false): free_seen = true
		if result.has("error"):
			# 琥珀不够：像玩家一样等体力回来
			waited_min += 10
			replay.perform("tick", {}, replay.clock + 600)
		return true
	var r: Dictionary = replay.perform("tap", {"cell": at})
	return not r.has("error")

func _free_play() -> bool:
	# 赠送的产体力物品会一直产；需要体力时才收
	for chain in ["fire", "shell", "sand"]:
		for lv in range(6, 1, -1):
			var at := _find("%s_%d" % [chain, lv])
			if at >= 0 and (chain != "fire" or lv == 6 or game.energy == 0):
				replay.perform("tap", {"cell": at}); return true
	for oi in game.orders.size():
		var o: Dictionary = game.orders[oi]
		if game.rules.orders.order_ready(o): main.board_screen._on_deliver(oi); return true
		if game.rules.orders.craft_mats_ready(o): main.board_screen._on_craft(oi); return true
		if str(o.get("phase", "")) == "finished":
			manual_seen = true
			replay.perform("tap", {"cell": int(o["cell"])}); return true
		if str(o.get("phase", "")) == "cook":
			replay.perform("tick", {}, replay.clock + game.rules.orders.cook_left(int(o["cell"])) + 1); return true
	# 订单要的东西留着，其余顺着能走的链往上合
	var protect := {}
	for o in game.orders:
		for id in o.get("mats", o["items"]): protect[str(id)] = int(protect.get(str(id), 0)) + 1
	for lv in range(13, 0, -1):
		for chain in ["fruit", "seed", "fire", "shell"]:
			if lv >= Data.max_lv(chain): continue
			var id := "%s_%d" % [chain, lv]
			if protect.has(id) and game.rules.onboarding.count(id) <= int(protect[id]): continue
			var from := _find(id)
			if from < 0: continue
			for to in game.board.size():
				if to == from or str(game.board[to]["id"]) != id or int(game.board[to]["lock"]) == 2: continue
				var r: Dictionary = replay.perform("drop", {"from": from, "to": to})
				if not r.has("error"): return true
	if _produce(): return true
	# 棋盘满了就卖一件多余的，不改写棋盘
	for i in game.board.size():
		var id := str(game.board[i]["id"])
		if int(game.board[i]["lock"]) == 0 and Data.type_of(id) == "item" and not protect.has(id):
			replay.perform("discard", {"cell": i}); replay.perform("discard_finish"); return true
	return false

func _dump() -> String:
	return "STATE %d %d energy %d amber %d stash %s orders %s\nBOARD %s" % [game.level, game.xp, game.energy, game.amber, str(game.stash), str(game.orders), str(game.board)]

## 走完新手引导返回 true；卡住返回 false（原因在 error）
func play() -> bool:
	var same_step := 0
	var last_step := ""
	var step_since := Time.get_ticks_msec()
	for k in max_steps:
		if stop: return false
		steps += 1
		game.simulation_time = replay.clock
		if not game.tutorial_on: return true
		var guide = main._guide
		var step := str(game.rules.onboarding.stage().get("key", ""))
		var mode := str(game.rules.onboarding.stage().get("mode", ""))
		same_step = same_step + 1 if step == last_step else 0
		if step != last_step: step_since = Time.get_ticks_msec()
		last_step = step
		# 卡住要同时满足步数和时间：加速播放时动画仍按真实时间走，不能按步数算超时
		var limit := 1800 if mode == "free" else 50
		if same_step > limit and Time.get_ticks_msec() - step_since > int(limit * (30 if mode == "free" else 120)):
			error = "引导卡在 " + step + "\n" + _dump()
			return false
		if not seen.has(step):
			seen[step] = true
			print("STEP ", step, " lv=", game.level, " xp=", game.xp, " energy=", game.energy, " money=", game.shells, " amber=", game.amber, " waited=", waited_min)
			if on_step.is_valid(): await on_step.call(step)
		if main.home.is_building():
			pass # 建造自己会完成；不打开也不安装箱子
		elif _tap_popups(): pass
		elif main.level_pending or main._rw_showing or main._wipe.running(): pass
		elif guide.visible and guide._mode == "stash": main.board_screen._on_stash()
		elif mode in ["dialog", "banner"]: guide.skip_beat()
		elif mode == "enter_board" or mode == "back": main.home.go.pressed.emit()
		elif mode == "merge":
			var pair: Vector2i = guide.merge_hint()
			if pair.x >= 0: replay.perform("drop", {"from": pair.x, "to": pair.y})
		elif mode in ["produce", "collect", "energy_gen", "take_dish"]:
			if mode == "take_dish": manual_seen = true
			var at: int = guide._cell_target()
			if at >= 0: main.board_screen._on_activate(at)
		elif mode == "submit": main.board_screen._on_deliver(guide._order_index())
		elif mode == "open_build": main.board_screen._on_hammer()
		elif mode == "level_open": main.board_screen._base_btn.pressed.emit()
		elif mode == "recipe_open":
			var oi: int = guide._order_index()
			if oi >= 0: main.open("recipe", str(game.orders[oi]["dish"]))
		elif mode == "cook": main.board_screen._on_craft(guide._order_index())
		elif mode == "stash": main.board_screen._on_stash()
		elif step in ["build2_wait", "build3_wait"]:
			main.board_screen._on_hammer()
			await get_tree().create_timer(maxf(0.65, step_delay)).timeout
			var b = find_button(main.popup_layer, "build")
			if b != null: b.pressed.emit()
		elif mode == "free":
			if not _free_play():
				error = "无法继续自由阶段 " + step + "\n" + _dump()
				return false
		# 打开弹窗的几步要等弹窗真正弹出、引导接上；太快会被下一步当成多余弹窗关掉
		var wait := free_delay if mode == "free" else step_delay
		if mode in ["open_build", "level_open", "recipe_open"]: wait = maxf(wait, 0.5)
		await get_tree().create_timer(wait).timeout
		if k % 200 == 199: print("PROGRESS ", k, " ", step)
	error = "引导超过 %d 步还没走完" % max_steps
	return false
