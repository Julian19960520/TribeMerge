class_name Rewards
extends RefCounted
## 唯一领奖入口：先结算并保存，再播放动画；动画被切页/关闭打断也不会丢奖。
## [id, n]：资源的 n 是到账数量，其他的 n 是物品数量。
## [id, n, "item"]：实物数量；可领取的资源按物品等级折算，0 价值物品仍进棋盘/暂存。
## board_origin 仅用于开箱等明确产出棋盘实物的行为，保留可合并资源实物。

const RESOURCE_TYPES := ["energy", "shell", "amber", "sand"]

static func kind(id: String) -> String:
	return Data.type_of(id) if Data.DISHES.has(id) or Data.CHAINS.has(Data.chain(id)) else ""

static func is_resource(id: String) -> bool:
	return kind(id) in RESOURCE_TYPES

static func unit(id: String) -> String:
	return str({"energy": "点体力", "shell": "个贝币", "amber": "个琥珀", "sand": "个沙漏"}.get(kind(id), ""))

static func items(ids: Array) -> Array:
	var rewards: Array = []
	for id in ids:
		if str(id) != "": rewards.append([str(id), 1, "item"])
	return rewards

static func grant(rewards: Array, from: Callable = Callable(), fly := true, apply := true, delivery: Dictionary = {}) -> void:
	if G.replay_input(): apply = false
	var item_flies: Array = []
	var resource_flies: Array = []
	var pack_n := 0
	var leveled := false
	var placed := 0
	var overflow := 0
	var origin := int(delivery.get("board_origin", -1))
	for k in rewards.size():
		var rw = rewards[k]
		if not rw is Array or rw.size() < 2: continue
		var id := str(rw[0])
		var n := int(rw[1])
		var t := kind(id)
		if n <= 0 or t == "": continue
		var pos: Vector2 = from.call(k) if from.is_valid() else Vector2(360, 700)
		var physical: bool = rw.size() > 2 and str(rw[2]) in ["item", "physical"]
		# 宝箱产物明确是棋盘实物；其他奖励里的火苗等自动兑换到账。
		if physical and str(rw[2]) == "item" and origin < 0 and t in RESOURCE_TYPES and Data.value_of(id) > 0:
			if apply:
				for _j in n: G.cloud_event({"type": "collect", "item": id})
			n *= Data.value_of(id)
			physical = false
		if not physical and t in RESOURCE_TYPES:
			if apply: G.add_currency(t, n)
			resource_flies.append([id, pos, t])
		elif not physical and t == "xp":
			if apply: leveled = G.add_xp(n) or leveled
			resource_flies.append([id, pos, "xp"])
		elif not physical and t == "token":
			if apply: pack_n += G.add_tokens(n)
			item_flies.append([id, pos])
		else:
			if apply:
				for _j in n:
					if origin >= 0:
						var to := G.find_empty_near(origin)
						G.discover(id)
						if to >= 0:
							G.board[to]["id"] = id
							if fly and is_instance_valid(G.main):
								if bool(delivery.get("from_stash", false)):
									G.main.board_screen._fly_stash_to(id, to, placed * 0.14)
								else:
									G.main.board_screen.board.fly_in(origin, to, id)
							placed += 1
							continue
						overflow += 1
					G.stash.append(id)
			if origin < 0: item_flies.append([id, pos])
	if apply:
		G.dirty()
		G.changed.emit()
		if origin >= 0: G.board_changed.emit()
	if fly and is_instance_valid(G.main):
		for entry in resource_flies:
			var dest: Vector2
			if str(entry[2]) == "xp":
				dest = G.main.topbar.get_global_transform() * Vector2(64, 82)
			else:
				dest = G.main.topbar.target(str(entry[2]))
			G.main.fly(str(entry[0]), entry[1], dest, func(): pass, 90)
		_fly_items(item_flies)
		if overflow > 0: G.main.toast("放不下的 %d 个物品进了暂存区" % overflow)
	if pack_n > 0:
		# 积分自动换包也走同一入口，展示面板时不重复入账。
		grant([["pack_1", pack_n]], Callable(), false)
		if fly and is_instance_valid(G.main): G.main.present_rewards([["pack_1", pack_n]], false)
	if leveled and is_instance_valid(G.main):
		if fly:
			G.main.get_tree().create_timer(0.7).timeout.connect(func():
				if is_instance_valid(G.main): G.main.open("levelup"))
		else: G.main.open("levelup")

static func _fly_items(flies: Array) -> void:
	if flies.is_empty() or not is_instance_valid(G.main): return
	if G.main.screen == "home":
		var home: HomeScreen = G.main.home
		home.present_go(func():
			if not is_instance_valid(home): return
			home.arm_go(flies.size())
			for item in flies:
				G.main.fly(str(item[0]), item[1], home.go_center(), home.release_go, 90))
	else:
		for item in flies:
			G.main.fly(str(item[0]), item[1], G.main.board_screen.stash_pos(), Callable(), 90)
