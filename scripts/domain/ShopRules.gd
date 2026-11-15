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
## 每个刷新周期（含花琥珀立即补货）按当前已解锁产线随机摆货。
## data/store_shell.json 的 items 只当摆位模板：模板里的物品是主产物还是副产物、几级、库存几件；
## 实际摆哪条产线的东西每期随机，价格按物品难度 × 4 不那那（目录里没有就用模板价）。
func shell_stall() -> Array:
	context.clock.check_shell_period()
	var sig := str(state.shell_period) + ":" + str(Data.STORE_SHELL.size())
	var saved: Dictionary = context.meta().get("shell_stall", {})
	if str(saved.get("signature", "")) == sig and (saved.get("list", []) as Array).size() == Data.STORE_SHELL.size():
		return saved["list"]
	var rows := _roll_stall(context.random_for("shell_stall"))
	context.meta()["shell_stall"] = {"signature": sig, "list": rows}
	return rows

func _roll_stall(rng: RandomNumberGenerator) -> Array:
	var pools := {"M": [], "S": []}
	var left := {"M": [], "S": []}
	for l in Data.unlocked_lines(state.level):
		for role in ["M", "S"]:
			var ch := str(l.get("main" if role == "M" else "sub", ""))
			if ch != "" and Data.product_open(state.level, ch):
				pools[role].append(ch)
	var out: Array = []
	for k in Data.STORE_SHELL.size():
		var tpl: Dictionary = Data.STORE_SHELL[k]
		var tid := str(tpl.get("id", ""))
		var role := Data.draw_role(Data.chain(tid))
		var id := tid
		if pools.has(role) and not (pools[role] as Array).is_empty():
			# 同一种角色尽量不重样，摆完一轮再重新洗
			if (left[role] as Array).is_empty(): left[role] = (pools[role] as Array).duplicate()
			var pick := rng.randi_range(0, (left[role] as Array).size() - 1)
			id = "%s_%d" % [str(left[role][pick]), Data.lv(tid)]
			(left[role] as Array).remove_at(pick)
		var price := int(tpl.get("price", 0))
		var diff := PriceBook.difficulty(id)
		if diff > 0.0: price = ceili(diff * 4.0)
		out.append({"id": id, "price": price, "stock": int(tpl.get("stock", 1))})
	return out
