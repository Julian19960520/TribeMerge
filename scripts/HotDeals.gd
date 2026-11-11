extends RefCounted

const HINT_ODDS := [20, 55, 25]
const PRICE_MAIN := 0.6
const PRICE_SUB := 0.33

static func from_picks(base: Array, picks: Array) -> Array:
	var out: Array = []
	for d in base:
		out.append((d as Dictionary).duplicate())
	for p in picks:
		if not (p is Dictionary):
			continue
		var k := int(p.get("slot", -1))
		var id := str(p.get("id", ""))
		if k < 0 or k >= out.size() or not Data.CHAINS.has(Data.chain(id)):
			continue
		if Data.chain(str(out[k]["id"])) != Data.chain(id) and not (_is_goods(str(out[k]["id"])) and _is_goods(id)):
			continue
		var lv := Data.lv(id)
		if lv < 1 or lv > Data.max_lv(Data.chain(id)):
			continue
		var old: Dictionary = out[k]
		out[k] = {"id": id, "price": _price_like(id, old), "stock": clampi(int(old.get("stock", 3)), 1, 3 if lv >= 5 else 5)}
	return out

static func roll(base: Array, wanted: Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for d in base:
		out.append((d as Dictionary).duplicate())
	var n := _pick_count(rng)
	var slots: Array = []
	for k in out.size():
		if _is_goods(str(out[k].get("id", ""))):
			slots.append(k)
	var pool := wanted.duplicate()
	_shuffle(pool, rng)
	var used_chains := {}
	while n > 0 and not pool.is_empty() and not slots.is_empty():
		var need := str(pool.pop_back())
		var ch := Data.chain(need)
		if used_chains.has(ch):
			continue
		# 比订单要的低 1 级（60%）或 2 级；正好是别的订单要的那件就换另一个，免得太直白
		var drops := [1, 2] if rng.randi_range(0, 99) < 60 else [2, 1]
		var id := ""
		for dl in drops:
			var lv: int = Data.lv(need) - int(dl)
			var cand := "%s_%d" % [ch, lv]
			if lv >= 2 and not wanted.has(cand):
				id = cand
				break
		if id == "" or out.any(func(d): return str(d.get("id", "")) == id):
			continue
		var lv := Data.lv(id)
		# 先换同一条产线的那格（水果换水果），没有就随便一格普通货
		var at := -1
		for k in slots:
			if Data.chain(str(out[k]["id"])) == ch:
				at = k
				break
		if at < 0:
			for k in slots:
				if Data.line_of(str(out[k]["id"])).get("id", "") == Data.line_of(id).get("id", "?"):
					at = k
					break
		if at < 0:
			at = slots[rng.randi_range(0, slots.size() - 1)]
		slots.erase(at)
		used_chains[ch] = true
		var old: Dictionary = out[at]
		out[at] = {"id": id, "price": _price_like(id, old), "stock": clampi(int(old.get("stock", 3)), 1, 3 if lv >= 5 else 5)}
		n -= 1
	return out

static func _price_like(id: String, old: Dictionary) -> int:
	var oid := str(old.get("id", ""))
	var of := OrderRoll.flames(oid)
	if Data.chain(oid) == Data.chain(id) and of > 0.0 and int(old.get("price", 0)) > 0:
		return maxi(2, int(round(float(old["price"]) * OrderRoll.flames(id) / of)))
	return price_of(id)

static func price_of(id: String) -> int:
	var f := OrderRoll.flames(id)
	var per := PRICE_SUB if OrderRoll.is_sub(Data.chain(id)) else PRICE_MAIN
	return maxi(2, int(round(f * per)))

static func _is_goods(id: String) -> bool:
	if id == "" or Data.is_dish(id):
		return false
	var ch := Data.chain(id)
	return Data.CHAINS.has(ch) and str(Data.CHAINS[ch].get("type", "")) == "item"

static func _pick_count(rng: RandomNumberGenerator) -> int:
	var r := rng.randi_range(0, 99)
	var acc := 0
	for k in HINT_ODDS.size():
		acc += int(HINT_ODDS[k])
		if r < acc:
			return k
	return 0

static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

static func _base_sig() -> String:
	return str(JSON.stringify(Data.STORE_HOT).hash())
