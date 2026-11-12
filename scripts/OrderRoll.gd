class_name OrderRoll
extends RefCounted
## 订单难度 = 这单物品的理论火苗。
## 主产物从 1 级点出来再合成：1 级 1、2 级 2、3 级 4，也就是 2 的（等级-1）次方。
## 副产物先按 1 级掉率点出来，再合成，所以还要除以这个百分比（各级生产器的平均掉率）。平均 10% 时，1 级副产物是 10 火苗。

const TRIES := 160

static func base_flames(lv: int) -> int:
	if lv < 1:
		return 0
	return 1 << (lv - 1)

static func is_sub(ch: String) -> bool:
	for l in Data.LINES:
		if str(l.get("sub", "")) == ch:
			return true
	return false

## 这条副产物链的 1 级物品在各级生产器里的平均掉率百分比，用来折算副产物的理论火苗。没有就按 5。
## 用平均值而不是第一次出现时的掉率：玩家大部分时间用的是中高级生产器，按最低掉率算会把副产物估得太难。
static func sub_percent(ch: String) -> float:
	var needle := "%s_1" % ch
	for l in Data.LINES:
		if str(l.get("sub", "")) != ch:
			continue
		var sum := 0.0
		var n := 0
		var prod = Data.CHAINS.get(str(l.get("gen", "")), {}).get("prod", [])
		if prod is Array:
			for slot in prod:
				if slot == null or not (slot is Dictionary):
					continue
				var drops = slot.get("drops", [])
				if not (drops is Array):
					continue
				for d in drops:
					if d is Dictionary and str(d.get("id", "")) == needle and int(d.get("p", 0)) > 0:
						sum += float(d["p"])
						n += 1
		return sum / float(n) if n > 0 else 5.0
	return 5.0

static func flames(id: String) -> float:
	var ch := Data.chain(id)
	if id == "" or not Data.CHAINS.has(ch):
		return 0.0
	var base := float(base_flames(Data.lv(id)))
	if is_sub(ch):
		var p := sub_percent(ch)
		if p <= 0.0:
			p = 5.0
		return base * 100.0 / p
	return base

static func total(items: Array) -> float:
	var s := 0.0
	for id in items:
		s += flames(str(id))
	return s

static func fmt(v: float) -> String:
	var n := int(round(v))
	if absf(v - float(n)) < 0.05:
		return str(n)
	return "%.1f" % v

## 随机订单不拿拿：每理论火苗 3 不拿拿，主产物和副产物同价，稀有的副产物不再吃亏。
const PAY_PER_FLAME := 3.0

static func shell_of(items: Array) -> int:
	return maxi(int(round(total(items) * PAY_PER_FLAME)), 1)

## 按目标火苗随一单。avoid 里的物品组合会尽量避开，给「换一单」用。
## allowed 非空时只出这些链上的东西（玩家现有生产器掉得出来的）
static func make(level: int, target: float, rng: RandomNumberGenerator, avoid: Array = [], allowed: Dictionary = {}) -> Dictionary:
	var pool := _pool(level, target, allowed)
	if pool.is_empty() and not allowed.is_empty():
		pool = _pool(level, target)
	if pool.is_empty():
		return {}
	var n := _count(target, rng)
	var best: Array = []
	var best_err := 1.0e18
	var close: Array = []
	var tol := maxf(1.0, target * 0.12)
	for _i in TRIES:
		var built: Array = _try(pool, target, rng, n)
		if built.is_empty():
			continue
		var err := absf(total(built) - target)
		if err < best_err - 0.001:
			best_err = err
			best = built
		if err <= tol:
			close.append(built)
	var chosen: Array = best
	if not close.is_empty():
		var fresh: Array = []
		for built in close:
			if not _same(built, avoid):
				fresh.append(built)
		var bag: Array = fresh if not fresh.is_empty() else close
		chosen = _weighted(bag, target, rng)
	if chosen.is_empty():
		return {}
	var who := 0
	if not Data.PEOPLE.is_empty():
		who = rng.randi() % Data.PEOPLE.size()
	return {
		"who": who,
		"items": chosen,
		"rw": {"shell": shell_of(chosen)},
		"story": false,
	}

static func default_diff(curve: int, index: int) -> int:
	var low := 36 + index * 12
	if curve <= 0:
		return maxi(1, low)
	return maxi(1, low * 2)

static func _weighted(bag: Array, target: float, rng: RandomNumberGenerator) -> Array:
	var total_w := 0.0
	var weights: Array = []
	for built in bag:
		var err := absf(total(built) - target)
		var w := 1.0 / (1.0 + err * err)
		weights.append(w)
		total_w += w
	var roll := rng.randf() * total_w
	for i in bag.size():
		roll -= float(weights[i])
		if roll <= 0.0:
			return bag[i]
	return bag[0]

static func _pool(level: int, target: float, allowed: Dictionary = {}) -> Array:
	var cap := maxf(target * 1.55, target + 2.0)
	var out: Array = []
	var cheapest: Dictionary = {}
	for l in Data.unlocked_lines(level):
		for key in ["main", "sub"]:
			var ch := str(l.get(key, ""))
			if ch == "" or not Data.CHAINS.has(ch) or not Data.product_open(level, ch):
				continue
			if not allowed.is_empty() and not allowed.has(ch):
				continue
			var n := Data.max_lv(ch)
			for lv in n:
				var id := "%s_%d" % [ch, lv + 1]
				var cost := flames(id)
				if cost <= 0.0:
					continue
				var it := {"id": id, "cost": cost}
				if cheapest.is_empty() or cost < float(cheapest["cost"]):
					cheapest = it
				if cost <= cap:
					out.append(it)
	if out.is_empty() and not cheapest.is_empty():
		out.append(cheapest)
	return out

static func _try(pool: Array, target: float, rng: RandomNumberGenerator, n: int = -1) -> Array:
	if n < 1:
		n = _count(target, rng)
	var picked: Array = []
	var spent := 0.0
	for i in n:
		var left := n - i
		var budget := target - spent
		var want := budget
		if left > 1:
			want = budget * rng.randf_range(0.34, 0.72)
		var id := _pick_near(pool, maxf(want, 0.5), rng, picked)
		if id == "":
			break
		picked.append(id)
		spent += flames(id)
	return picked

static func _count(target: float, rng: RandomNumberGenerator) -> int:
	var r := rng.randf()
	if target < 4.0:
		return 1
	if target < 12.0:
		return 1 if r < 0.62 else 2
	if r < 0.26:
		return 1
	if r < 0.74:
		return 2
	return 3

static func _pick_near(pool: Array, want: float, rng: RandomNumberGenerator, already: Array) -> String:
	var ranked: Array = []
	for it in pool:
		var id := str(it["id"])
		var count := 0
		for have in already:
			if str(have) == id:
				count += 1
		if count >= 2:
			continue
		ranked.append({"id": id, "err": absf(float(it["cost"]) - want)})
	if ranked.is_empty():
		return ""
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["err"]) < float(b["err"]))
	var keep := mini(6, ranked.size())
	var total_w := 0.0
	var weights: Array = []
	for i in keep:
		var w := 1.0 / (1.0 + float(ranked[i]["err"]))
		weights.append(w)
		total_w += w
	var roll := rng.randf() * total_w
	for i in keep:
		roll -= float(weights[i])
		if roll <= 0.0:
			return str(ranked[i]["id"])
	return str(ranked[0]["id"])

static func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	var aa: Array = []
	var bb: Array = []
	for x in a:
		aa.append(str(x))
	for x in b:
		bb.append(str(x))
	aa.sort()
	bb.sort()
	for i in aa.size():
		if str(aa[i]) != str(bb[i]):
			return false
	return true
