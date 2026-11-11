extends "res://scripts/domain/RuleModule.gd"
## Shop state and randomness use the same explicit context as other domain services.
const Goods := preload("res://scripts/HotDeals.gd")

func signature() -> String:
	return context.clock.today() + ":" + str(state.hot_revision) + ":" + Goods._base_sig()

func cached() -> Dictionary:
	var saved: Dictionary = context.meta().get("hot", {})
	return saved if saved.get("signature", "") == signature() else {}

func today() -> Array:
	var saved := cached()
	if not saved.is_empty(): return saved["list"]
	var rows := Goods.roll(Data.STORE_HOT, _wanted(), context.random_for("shop"))
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
	var rng = context.random_for("shop")
	var picks: Array = []
	for k in Data.STORE_HOT.size():
		var base: Dictionary = Data.STORE_HOT[k]
		var id = str(base["id"])
		var ch = Data.chain(id)
		var old = str(previous[k]["id"]) if k < previous.size() else id
		var pool: Array = []
		for level in range(maxi(1, Data.lv(id) - 1), mini(Data.max_lv(ch), Data.lv(id) + 1) + 1):
			var candidate = "%s_%d" % [ch, level]
			if candidate != old: pool.append(candidate)
		picks.append({"slot": k, "id": pool[rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else id})
	var rows = Goods.from_picks(Data.STORE_HOT, picks)
	context.meta()["hot"] = {"signature": context.clock.today() + ":" + str(state.hot_revision) + ":" + Goods._base_sig(), "list": rows}
	return rows
