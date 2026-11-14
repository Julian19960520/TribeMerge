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
