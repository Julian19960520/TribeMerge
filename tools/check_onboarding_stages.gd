extends SceneTree
## 参考竞品的分阶段新手流程：教学单给经验、首次补体力免费、升级送订单材料、4 级送火种罐、提示只出一次。
## godot --headless --path . --script tools/check_onboarding_stages.gd -- --replay-test --cloud-off
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func _fresh(replay, game, level: int) -> void:
	replay.executing = true
	replay.seq = 0; replay.base = 0; replay.pending = []; replay.inflight = {}
	replay.clock = 1794240000; replay.meta = {}
	game.random_seed = "onboarding-stages"; game.random_streams = {}
	game.new_game()
	if level > 0:
		game.level = level; game.xp = 0; game.seen_tutorial = true; game.tutorial_on = false
		game.orders = []; game.pending_orders = []
		game.rules.orders.refill_orders()
	replay.advance(); replay._canonicalize_live(); replay.executing = false
	game.clear_presentations(); replay.snapshot()

func run() -> void:
	for node in root.get_children(): node.set_process(false)
	var replay = root.get_node("Replay")
	var game = root.get_node("G")

	_fresh(replay, game, 0)
	var xp := 0
	for o in game.orders: xp += int(o.get("rw", {}).get("xp", 0))
	check(xp == 2, "两张教学订单各给 1 点经验")
	check(Data.xp_need(1) == 3, "1 级升级需要 3 点：两张教学单加草籽单正好升到 2 级")

	_fresh(replay, game, 3)
	game.energy = 0
	var amber: int = game.amber
	var r: Dictionary = replay.perform("energy", {}, replay.clock)
	check(not r.has("error") and bool(r.get("free", false)) and game.energy == 100 and game.amber == amber, "第一次补体力免费，补满 100")
	game.energy = 0
	r = replay.perform("energy", {}, replay.clock)
	check(not r.has("error") and not r.has("free") and game.amber == amber - game.rules.progression.energy_price() + 10 and game.energy == 100, "第二次补体力按原价花琥珀")

	_fresh(replay, game, 1)
	for i in game.board.size():
		if int(game.board[i]["lock"]) == 0 and Data.type_of(str(game.board[i]["id"])) == "item": game.board[i]["id"] = ""
	game.stash = []
	game.level = 2
	game.orders = []
	game.rules.orders.refill_orders()
	var want: Array = game.rules.orders.missing_order_items(3)
	check(not want.is_empty() and want.size() <= 3, "升级时能算出当前订单缺的材料（%s）" % [want])
	var before := {}
	for id in want: before[id] = _count(game, id)
	r = replay.perform("level", {"level": 2}, replay.clock)
	check(not r.has("error") and r.get("help", []) == want, "领 2 级奖励时订单宝箱送出这些材料")
	var placed := true
	for id in want:
		if _count(game, id) <= int(before[id]): placed = false
	check(placed, "订单材料放到了棋盘或暂存区")
	r = replay.perform("level", {"level": 2}, replay.clock)
	check(r.has("error"), "同一级奖励不能重复领")

	var lv4: Array = Data.level_rewards(4)
	var has_pot := false
	for rw in lv4: if str(rw[0]) == "emberpot_1": has_pot = true
	check(has_pot, "4 级奖励里有火种罐")
	check(Data.type_of("emberpot_1") == "egen", "火种罐是点了出体力的生产器")

	quit(1 if failures > 0 else 0)

func _count(game, id: String) -> int:
	var n: int = game.stash.count(id)
	for c in game.board:
		if str(c["id"]) == id: n += 1
	return n
