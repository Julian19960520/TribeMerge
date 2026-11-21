extends SceneTree
const Goods := preload("res://scripts/HotDeals.gd")
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func ordinary_ids(rows: Array) -> Array:
	return rows.slice(0, 5).map(func(row): return str(row["id"]))

func run() -> void:
	for node in root.get_children(): node.set_process(false)
	var g = root.get_node("G")
	var replay = root.get_node("Replay")
	var random := RandomNumberGenerator.new(); random.seed = 7114
	for level in [1, 2, 3, 5, 6, 7, 8, 13, 15, 16, 23, 24, 25, 26, 29, 31, 40]:
		var previous: Array = []
		var valid := true; var changed := true
		var seen_chains := {}
		for _i in 100:
			var rows := Goods.roll(Data.STORE_HOT, ["fruit_10", "gem_6"], random, level, previous)
			valid = valid and Goods.valid_rows(rows, Data.STORE_HOT, level)
			for k in 5:
				var id := str(rows[k]["id"])
				seen_chains[Data.chain(id)] = true
				valid = valid and Data.product_open(level, Data.chain(id)) and Data.lv(id) >= 3 + Goods.level_bonus(level) and Data.lv(id) <= 8 + Goods.level_bonus(level)
				valid = valid and int(rows[k]["price"]) == Goods.price_of(id) and int(rows[k]["stock"]) == [5, 3, 2, 1, 1][k]
			valid = valid and Data.lv(str(rows[4]["id"])) >= 7 + Goods.level_bonus(level)
			valid = valid and int(rows[5]["price"]) == 120 and int(rows[5]["stock"]) == 1 and Data.lv(str(rows[5]["id"])) == 1
			if not previous.is_empty(): changed = changed and ordinary_ids(previous) != ordinary_ids(rows)
			previous = rows
		check(valid and changed, "%d级热卖仅已解锁产物，等级递增且有高阶商品，刷新必定变化" % level)
		var covered := true
		for line in Data.unlocked_lines(level): covered = covered and seen_chains.has(Data.primary(line))
		check(covered, "%d级商品池覆盖所有已解锁主产线" % level)
	var ordered: Array = Goods.from_picks(Data.STORE_HOT, [], 1)
	for bad in [{"slot": 0, "id": "tool_3"}, {"slot": 0, "id": "fire_3"}, {"slot": 0, "id": "fruit_1"}, {"slot": 4, "id": "fruit_14"}, {"slot": 5, "id": "hearth_1"}]:
		check(Goods.from_picks(Data.STORE_HOT, [bad], 1) == ordered, "商品选择拒绝未解锁、资源与越级数据：%s" % str(bad["id"]))
	check(Goods.from_picks(Data.STORE_HOT, [{"slot": 0, "id": "fruit_4"}], 1) == ordered, "商品选择不会形成重复等级或乱序")
	g.new_game(); g.tutorial_on = false; g.seen_tutorial = true; g.level = 1
	replay.active = true; replay.authorized = true
	replay.clock = 1794240000; replay.seq = 0; replay.pending = []; replay.inflight = {}; replay.meta = {}
	g.deals_day = g.rules.clock.today()
	g.hot_bought = {"hot_0": 2}
	var invalid: Array = ordered.duplicate(true); invalid[0]["id"] = "tool_3"
	replay.meta["hot"] = {"signature": g.rules.shop.signature(), "list": invalid}
	var repaired: Array = g.shop_view()
	check(Goods.valid_rows(repaired, Data.STORE_HOT, 1) and g.hot_bought == {"hot_0": 2}, "旧缓存的未解锁低阶商品自动修正，保留购买次数")
	var random_after: Dictionary = g.random_save().duplicate(true)
	check(g.shop_view() == repaired and g.random_save() == random_after, "重复打开商店沿用同一轮商品与随机数位置")
	g.level = 16
	var promoted: Array = g.shop_view()
	check(Goods.valid_rows(promoted, Data.STORE_HOT, 16) and Data.lv(str(promoted[0]["id"])) >= 5, "达到新等级段后旧货架自动提高商品等级")
	g.amber = 10000
	var result: Dictionary = replay.perform("hot_refresh")
	var refreshed: Array = g.shop_view()
	check(result.get("ok", false) and g.amber == 9990 and g.hot_bought.is_empty() and ordinary_ids(promoted) != ordinary_ids(refreshed), "付费刷新准确扣10琥珀，重置限购并替换递增货架")
	var high_id := str(refreshed[4]["id"])
	var price := int(refreshed[4]["price"])
	var bought: Dictionary = replay.perform("shop", {"key": "hot_4", "id": high_id})
	check(bought.get("ok", false) and g.amber == 9990 - price and g.stash.has(high_id), "高阶商品按显示价格发放对应物品")
	check(not replay.perform("shop", {"key": "hot_4", "id": high_id}).get("ok", false) and g.amber == 9990 - price, "限购一件的高阶商品不能重复购买")
	var snapshot: Dictionary = replay.snapshot()
	var rng_snapshot: Dictionary = g.random_save().duplicate(true)
	check(replay.restore(snapshot) and g.shop_view() == refreshed and g.random_save() == rng_snapshot, "购买后的整轮商品及随机状态可持久化恢复")
	var main = load("res://main.tscn").instantiate(); root.add_child(main)
	var shop = main.open("store")
	await process_frame
	var goods: Control = shop.find_child("HotGoods", true, false)
	var grades := []
	for node in goods.get_children():
		if node.has_meta("hot_item_level"): grades.append(int(node.get_meta("hot_item_level")))
	check(grades == refreshed.map(func(row): return Data.lv(str(row["id"]))), "商品卡清楚标出等级，与实际六格商品一致")
	shop.close(); main.queue_free()
	await process_frame
	quit(1 if failures else 0)
