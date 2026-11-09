extends RefCounted
## 集市「热卖」每天的货单。
## 底子是 data/store.json 的那几件；每天第一次打开集市时，悄悄把其中 0～2 件普通货换成
## 「当前订单要的东西的半成品」：同一条链、比订单要的低 1～2 级，玩家买回去还得自己合一下。
## 换上去的那件放在原来那格，价格、库存按同一套规则算，看起来和平时的货没区别。
## 当天的货单存在 user://hot_deals.json，订单变了也不跟着变，第二天再刷。
## 连得上服务器时，换哪几格由服务器按它存的最新快照每人每天抽一次（Cloud.hot_for），改本机时间、
## 删 hot_deals.json 都刷不掉；这里只按原格算价格和库存。连不上才用下面的本地 roll。

const SAVE := "user://hot_deals.json"
## 换几件：0 件 20%，1 件 55%，2 件 25%
const HINT_ODDS := [20, 55, 25]
## 主产物每理论火苗的琥珀价，副产物便宜些（副产物理论火苗本来就被掉率放大了）
const PRICE_MAIN := 0.6
const PRICE_SUB := 0.33

static var _cache_day := ""
static var _cache: Array = []
## 测试可以用 `-- --hot-file=user://xxx.json` 换掉
static var _path := ""

## 今天的热卖货单，每项 {"id", "price", "stock"}，下标和 hot_bought 的 "hot_%d" 对应
static func today() -> Array:
	if Replay.active:
		var signature := G.today() + ":" + str(G.hot_revision)
		var saved: Dictionary = Replay.meta.get("hot", {})
		if saved.get("signature", "") == signature: return saved["list"]
		if G.replay_input(): return Replay.perform("shop_view").get("list", [])
		var rows := roll(Data.STORE_HOT, _wanted(), G.random_for("shop"))
		Replay.meta["hot"] = {"signature": signature, "list": rows}
		return rows
	var cloud = _cloud()
	var day: String = cloud.today() if cloud != null else Time.get_date_string_from_system()
	var sig := _base_sig() + ":" + str(G.hot_revision)
	var picks = cloud.hot_for(day) if cloud != null else null
	if picks is Array:
		if _cache_day == day + sig + "@server" + JSON.stringify(picks) and not _cache.is_empty():
			return _cache
		_cache = from_picks(Data.STORE_HOT, picks)
		_cache_day = day + sig + "@server" + JSON.stringify(picks)
		_store({"day": day, "sig": sig, "list": _cache, "server": true})
		return _cache
	if cloud != null:
		cloud.want_hot()
	if _cache_day == day + sig and not _cache.is_empty():
		return _cache
	var saved := _load()
	if str(saved.get("day", "")) == day and str(saved.get("sig", "")) == sig and saved.get("list") is Array:
		# JSON 读回来的数字都是小数，价格、库存转回整数，不然按钮上会显示「8.0」
		_cache = []
		for d in saved["list"]:
			if d is Dictionary:
				_cache.append({"id": str(d.get("id", "")), "price": int(d.get("price", 0)), "stock": int(d.get("stock", 0))})
	else:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		_cache = roll(Data.STORE_HOT, _wanted(), rng)
		_store({"day": day, "sig": sig, "list": _cache})
	_cache_day = day + sig
	return _cache

## 清掉内存里的货单（测试用：模拟重开游戏）
static func clear_cache() -> void:
	_cache_day = ""
	_cache = []

## 服务器抽好的换货 [{"slot", "id"}] 套到底子上。格子或物品对不上（两边配置不一致）的那项跳过。
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

static func _cloud() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Cloud") if tree != null else null

static func _file() -> String:
	if _path == "":
		_path = SAVE
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--hot-file="):
				_path = a.trim_prefix("--hot-file=")
	return _path

## 按底子和「订单缺的东西」排一份货单。单独拿出来方便测试。
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

## 同一条链就照这格原来的价按理论火苗等比换算，价位和平时的货对得上；不同链才用通用公式
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

## 订单里要、但棋盘和储物洞里都还没有的普通物品
static func _wanted() -> Array:
	var have := {}
	for c in G.board:
		if int(c.get("lock", 0)) == 0 and str(c.get("id", "")) != "":
			have[str(c["id"])] = int(have.get(str(c["id"]), 0)) + 1
	for s in G.stash:
		var sid := str(s.get("id", "")) if s is Dictionary else str(s)
		have[sid] = int(have.get(sid, 0)) + 1
	var out: Array = []
	for o in G.orders:
		for it in o.get("items", []):
			var id := str(it)
			if int(have.get(id, 0)) > 0:
				have[id] = int(have[id]) - 1
				continue
			if _is_goods(id) and not out.has(id):
				out.append(id)
	return out

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

## 底子改过（配置页改了 store.json）就当天重排
static func _base_sig() -> String:
	return str(JSON.stringify(Data.STORE_HOT).hash())

static func _load() -> Dictionary:
	if not FileAccess.file_exists(_file()):
		return {}
	var f := FileAccess.open(_file(), FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}

static func _store(d: Dictionary) -> void:
	var f := FileAccess.open(_file(), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))

## 花钻石刷新整组：每个货位都在其基础等级附近重新抽，排除该位置当前物品。
static func reroll_all(previous: Array) -> Array:
	var rng := G.random_for("shop") if Replay.active else RandomNumberGenerator.new()
	if not Replay.active: rng.randomize()
	var picks: Array = []
	for k in Data.STORE_HOT.size():
		var base: Dictionary = Data.STORE_HOT[k]
		var id := str(base["id"])
		var ch := Data.chain(id)
		var old := str(previous[k]["id"]) if k < previous.size() else id
		var pool: Array = []
		for lv in range(maxi(1, Data.lv(id) - 1), mini(Data.max_lv(ch), Data.lv(id) + 1) + 1):
			var candidate := "%s_%d" % [ch, lv]
			if candidate != old: pool.append(candidate)
		picks.append({"slot": k, "id": pool[rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else id})
	_cache = from_picks(Data.STORE_HOT, picks)
	if Replay.active: Replay.meta["hot"] = {"signature": G.today() + ":" + str(G.hot_revision), "list": _cache}
	var day := G.today()
	var sig := _base_sig() + ":" + str(G.hot_revision)
	_cache_day = day + sig
	_store({"day": day, "sig": sig, "list": _cache})
	return _cache
