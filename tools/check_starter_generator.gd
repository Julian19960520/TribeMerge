extends SceneTree
var failures := 0
var g
var replay
const START := 1794240000
const POT := "emberpot_1"
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func fresh(tutorial := false) -> void:
	replay.executing = true
	replay.meta = {}; replay.seq = 0; replay.base = 0; replay.pending = []; replay.inflight = {}
	replay.clock = START; g.simulation_time = START
	g.new_game(); replay.advance()
	g.level = 4; g.tutorial_on = tutorial; g.seen_tutorial = not tutorial
	g.random_seed = "starter-pot"; g.random_streams = {}
	for i in g.board.size(): g.board[i] = {"id": "", "lock": 0}
	g.stash = []; g.inv = []; g.inv_chests = {}
	replay.advance(); replay._canonicalize_live(); replay.executing = false
func tick(at: int) -> void:
	g.simulation_time = at
	replay.perform("tick", {}, at)
func run() -> void:
	g = root.get_node("G"); replay = root.get_node("Replay")
	for node in root.get_children(): node.set_process(false)
	fresh()
	var claim: Dictionary = replay.perform("level", {"level": 4}, START)
	var timer: Dictionary = g.rules.starter.progress()
	check(not claim.has("error") and g.stash.has(POT) and int(timer.get("expires_at", 0)) == START + 604800, "4级领奖即开始7天有效期，暂存区等待也计时")
	check(replay.perform("level", {"level": 4}, START).has("error"), "新人生产器只能领取一次")
	var higher := false
	for lv in range(5, 41):
		for reward in Data.level_rewards(lv):
			if str(reward[0]) == POT: higher = true
	check(not higher, "后续等级不再重复发火种罐")
	var taken: Dictionary = replay.perform("stash", {"index": g.stash.find(POT)}, START)
	var at := int(taken.get("to", -1))
	check(at >= 0 and g.rules.board.gen_left(at) == 8, "领出的就是满8次生产器")
	var energy: int = g.energy
	var outputs: Array = []
	for _i in 8:
		var out: Dictionary = replay.perform("tap", {"cell": at}, START)
		outputs.append(str(out.get("id", "")))
	check(outputs.all(func(id): return id in ["fire_2", "fire_3", "fire_4"]) and g.energy == energy and g.board[at]["id"] == POT, "连续8次免费产出2～4级体力物品，火种罐始终保留")
	check(g.rules.board.gen_left(at) == 0 and g.rules.board.gen_wait(at) == 43200 and replay.perform("tap", {"cell": at}, START).has("error"), "本轮8次用尽后等待下个12小时周期")
	var saved: Dictionary = replay.snapshot().duplicate(true)
	check(replay.restore(saved) and g.rules.board.gen_left(at) == 0, "保存恢复不重置次数和有效期")
	tick(START + 43199)
	check(g.rules.board.gen_left(at) == 0 and g.rules.board.gen_wait(at) == 1, "12小时到期前1秒不能提前生产")
	tick(START + 43200)
	check(g.rules.board.gen_left(at) == 8, "12小时边界恢复8次")
	replay.perform("tap", {"cell": at}, replay.clock)
	tick(START + 86400)
	check(g.rules.board.gen_left(at) == 8, "未用尽的一轮也按12小时时钟回满，次数不叠加")
	for i in g.board.size():
		if i != at: g.board[i] = {"id": "fruit_1", "lock": 0}
	var blocked: Dictionary = replay.perform("tap", {"cell": at}, replay.clock)
	check(blocked.has("error") and g.rules.board.gen_left(at) == 8, "满盘不消耗生产次数")
	g.board[1] = {"id": "fire_4", "lock": 0}
	g.stash.append(POT)
	g.inv = [POT, "chest_1"]; g.inv_chests = {"1": ["fruit_3"]}
	tick(START + 604799)
	check(g.board[at]["id"] == POT and g.rules.starter.time_left() == 1, "一周结束前1秒仍有效")
	tick(START + 604800)
	check(g.board[at]["id"] == "" and not g.stash.has(POT) and g.inv == ["chest_1"] and g.inv_chests == {"0": ["fruit_3"]} and g.board[1]["id"] == "fire_4", "7天到期移除罐子，保留已生产体力和其他库存内容")
	var expires: int = g.rules.starter.progress()["expires_at"]
	tick(START + 1209600)
	check(g.rules.starter.progress()["expires_at"] == expires and not g.stash.has(POT), "到期后不会再次发放或续期")
	fresh(true)
	g.rules.onboarding.progress()["energy_gift"] = true
	tick(START)
	check(g.stash.count(POT) == 1 and g.rules.starter.time_left() == 604800, "旧版一次性礼盒已消费的新手补回统一生产器")
	tick(START + 1)
	check(g.stash.count(POT) == 1, "旧存档补偿只执行一次")
	g.rules.onboarding.progress()["step"] = g.rules.onboarding.stage_index("free_energy_gift")
	tick(START + 604800)
	check(str(g.rules.onboarding.stage().get("key", "")) not in ["free_energy_gift", "energy_gift"], "离线过期不会卡住火种罐强制引导")
	print("RESULT: %d failures" % failures)
	quit(1 if failures else 0)
