extends "res://scripts/domain/RuleModule.gd"
## Shop state and randomness use the same explicit context as other domain services.
const Goods := preload("res://scripts/HotDeals.gd")

func signature() -> String:
	return context.clock.today() + ":" + str(state.hot_revision) + ":" + Goods._base_sig()

func cached() -> Dictionary:
	var saved: Dictionary = context.meta().get("hot", {})
	if saved.get("signature", "") != signature(): return {}
	if not Goods.valid_rows(saved.get("list", []), Data.STORE_HOT, state.level): return {}
	return saved

func today() -> Array:
	var saved := cached()
	if not saved.is_empty(): return saved["list"]
	var rows := Goods.roll(Data.STORE_HOT, _wanted(), context.random_for("shop"), state.level)
	context.meta()["hot"] = {"signature": signature(), "list": rows}
	return rows

func _wanted() -> Array:
	var have = {}
	for c in state.board:
		if int(c.get("lock", 0)) == 0 and str(c.get("id", "")) != "":
			have[str(c["id"])] = int(have.get(str(c["id"]), 0)) + 1
	for s in state.stash:
		var sid = str(s.get("id", "")) if s is Dictionary else str(s)
		have[sid] = int(have.get(sid, 0)) + 1
	var out: Array = []
	for o in state.orders:
		for it in o.get("items", []):
			var id = str(it)
			if int(have.get(id, 0)) > 0:
				have[id] = int(have[id]) - 1
				continue
			if Goods._is_goods(id) and not out.has(id):
				out.append(id)
	return out

func reroll_all(previous: Array) -> Array:
	var rows := Goods.roll(Data.STORE_HOT, _wanted(), context.random_for("shop"), state.level, previous)
	context.meta()["hot"] = {"signature": context.clock.today() + ":" + str(state.hot_revision) + ":" + Goods._base_sig(), "list": rows}
	return rows

# ---------------------------------------------------------------- 不那那小摊
## 每个刷新周期（含花琥珀立即补货）按当前已解锁产线随机摆货，同一件物品不重复。
## data/store_shell.json 的 items 只当摆位模板：模板里的物品是主产物还是副产物、几级、库存几件；
## 实际摆哪条产线的东西每期随机，价格按物品难度 × 4 不那那（目录里没有就用模板价）。
func shell_stall() -> Array:
	context.clock.check_shell_period()
	var sig := str(state.shell_period) + ":" + str(Data.STORE_SHELL.size())
	var saved: Dictionary = context.meta().get("shell_stall", {})
	var saved_list: Array = saved.get("list", []) if saved.get("list") is Array else []
	if str(saved.get("signature", "")) == sig and _ids_unique(saved_list):
		return saved_list
	# 旧存档可能把同一件货摆了好几格。换掉这份清单时，已购次数是按格子记的，对不上新货，清掉。
	if not _ids_unique(saved_list):
		state.shell_bought = {}
	var rows := _roll_stall(context.random_for("shell_stall"))
	context.meta()["shell_stall"] = {"signature": sig, "list": rows}
	return rows

## 同一件物品（同一个 id）一期内只出现一次。已开放的产线不够填满格子时就少摆几格，不再把抽过的链洗回来。
## 这种角色一条已开放产线都没有时，才沿用模板上的物品，而且模板之间也不重复。
func _roll_stall(rng: RandomNumberGenerator) -> Array:
	var pools := {"M": [], "S": []}
	for l in Data.unlocked_lines(state.level):
		for ch in Data.products(l):
			if Data.product_open(state.level, ch):
				var role := "M" if Data.primary(l) == ch else "S"
				var pool: Array = pools[role]
				if not pool.has(ch):
					pool.append(ch)
	var left := {"M": (pools["M"] as Array).duplicate(), "S": (pools["S"] as Array).duplicate()}
	var used := {}
	var out: Array = []
	for k in Data.STORE_SHELL.size():
		var tpl: Dictionary = Data.STORE_SHELL[k]
		var tid := str(tpl.get("id", ""))
		var role := Data.draw_role(Data.chain(tid))
		var id := ""
		if left.has(role) and not (left[role] as Array).is_empty():
			var bag: Array = left[role]
			var pick := rng.randi_range(0, bag.size() - 1)
			var ch := str(bag[pick])
			bag.remove_at(pick)
			left[role] = bag
			var cap := Data.max_lv(ch)
			if cap >= 1:
				id = "%s_%d" % [ch, clampi(Data.lv(tid), 1, cap)]
		elif (not pools.has(role) or (pools[role] as Array).is_empty()) and not used.has(tid) and Data.is_board_item(tid):
			id = tid
		if id == "" or used.has(id):
			continue
		used[id] = true
		var price := int(tpl.get("price", 0))
		var diff := PriceBook.difficulty(id)
		if diff > 0.0: price = ceili(diff * 4.0)
		out.append({"id": id, "price": price, "stock": int(tpl.get("stock", 1))})
	return out

func _ids_unique(rows: Array) -> bool:
	var seen := {}
	for row in rows:
		if not row is Dictionary:
			return false
		var id := str(row.get("id", ""))
		if id == "" or seen.has(id):
			return false
		seen[id] = true
	return true
