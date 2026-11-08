extends SceneTree
## 付费限时礼包检查：赶大集（spree）/ 火种大礼包（energy）的触发、显示、mock 支付到账、限购和冷却，沿途截图。
## 用隔离存档跑，不碰真实存档：
## Godot --path . --script tools/check_offers.gd -- --cloud-off --save=user://offers_test/s.json --cloud-state=user://offers_test/c.json --rank-state=user://offers_test/r.json --hot-file=user://offers_test/h.json --out=<截图目录>
var failures := []
var out := ""
var _started := false
var g: Node
var main: Node

func _process(_d: float) -> bool:
	if not _started:
		_started = true
		run()
	return false

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)

func shot(n: String) -> void:
	if out == "": return
	await create_timer(0.9).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "/offers_" + n + ".png")
	print("shot ", n)

func top() -> Node:
	var layer: Control = main.popup_layer
	var live: Array = layer.get_children().filter(func(c): return not c.is_queued_for_deletion() and not c._closing)
	return live[-1] if not live.is_empty() else null

func top_is(path: String) -> bool:
	var p := top()
	return p != null and p.get_script() != null and p.get_script().resource_path == path

func clear() -> void:
	main.close_all()
	await process_frame
	await process_frame

func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
	g = root.get_node("G")
	var offers = load("res://scripts/events/Offers.gd")
	g.new_game()
	g.tutorial_on = false
	g.seen_tutorial = true
	g.level = 12
	g.simulation_time = 1793577600.0
	g.settings.erase("spree_popped")
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	await clear()
	var ticker: Node = offers.inst()

	# ---- 配置：面板上写的「多送 / 超值」和内容估值一致
	for kind in ["spree", "energy"]:
		for k in offers.tiers(kind).size():
			var t: Dictionary = offers.tier(kind, k)
			var pct: float = offers.value(t["rewards"]) / (float(t["price_cny"]) * 15.0) * 100.0
			check(absf(pct - float(t["value_pct"])) <= 5.0, "%s tier %d value %.0f%% matches label %d%%" % [kind, k, pct, int(t["value_pct"])])

	# ---- 12 级：都不开
	await ticker.tick()
	check(not offers.active("spree") and top() == null, "level 12: spree does not open")
	g.energy = 0
	main.open("energy")
	await create_timer(0.2).timeout
	check(not offers.active("energy") and top_is("res://scripts/ui/PopupBase.gd"), "level 12: out of energy opens the amber energy popup")
	await clear()

	# ---- 13 级：赶大集自动开一期并弹一次
	g.level = 13
	g.energy = 50
	await ticker.tick()
	await process_frame
	check(offers.active("spree") and offers.remaining("spree") == 3600, "level 13: spree window opens for one hour")
	check(top_is("res://scripts/ui/SpreePopup.gd"), "spree auto-popup on open")
	var p: Node = top()
	check(p.left_lbl.text == "剩余可买：5" and p.buy_btn.text == "¥6" and p.buy_btn.enabled, "spree shows remaining 5 and ¥6 button")
	check(p.find_child("spree_burst", true, false) != null and p.find_child("spree_info_2", true, false) != null, "spree has 150% burst and info badges")
	await shot("spree")
	await clear()
	await ticker.tick()
	await process_frame
	check(top() == null, "spree pops only once per window")
	var home_card: Node = main.home.find_child("spree_card", true, false)
	check(home_card != null and home_card.visible, "home entry card visible while spree is live")
	await shot("home_card")

	# ---- 买一次：琥珀 +60、体力 +60、贝币 +300、生产器 / 宝箱 / 卡包进暂存
	p = main.open("spree")
	await process_frame
	var amber: int = g.amber
	var energy: int = g.energy
	var shells: int = g.shells
	g.stash = []
	p.buy_btn.pressed.emit()
	await create_timer(0.3).timeout
	check(g.amber == amber + 60 and g.energy == energy + 60 and g.shells == shells + 300, "spree pays amber 60, energy 60, shells 300")
	check(g.stash == ["basket_4", "chest_1", "pack_1"], "spree delivers generator, chest and pack to stash")
	check(offers.left("spree", 0) == 4 and p.left_lbl.text == "剩余可买：4", "spree limit counts down")
	await shot("spree_bought")
	for i in 4:
		check((await offers.buy("spree", 0)).get("ok", false), "spree buy %d" % (i + 2))
	p._refresh()
	check(not (await offers.buy("spree", 0)).get("ok", false) and not p.buy_btn.enabled and p.buy_btn.text == "已买完", "spree sold out after 5")
	check(g.amber == amber + 300, "five spree buys total 300 amber")
	await clear()

	# ---- 赶大集期满 → 冷却 → 下一期
	g.simulation_time += 3601.0
	check(not offers.active("spree") and not offers.can_open("spree"), "spree expired and cooling down")
	g.simulation_time += 72000.0
	check(offers.can_open("spree"), "spree reopens after 20h cooldown")
	await ticker.tick()
	await process_frame
	check(offers.active("spree") and offers.left("spree", 0) == 5 and top_is("res://scripts/ui/SpreePopup.gd"), "new spree window resets limit and pops again")
	await clear()

	# ---- 火种大礼包：体力 0 点生产器 → 弹礼包（开 10 分钟）
	g.energy = 0
	g.energy_stamp = g.now()
	main.open("energy")
	await create_timer(0.2).timeout
	check(offers.active("energy") and offers.remaining("energy") == 600, "out of energy opens a 10 minute energy offer")
	check(top_is("res://scripts/ui/EnergyOfferPopup.gd"), "energy offer popup shown instead of amber popup")
	p = top()
	check(p.btns.size() == 3 and p.btns[0].text == "¥18" and p.btns[1].text == "¥30" and p.btns[2].text == "¥45", "three price cards ¥18 / ¥30 / ¥45")
	check(p.find_child("energy_best", true, false) != null, "last card has best-value ribbon")
	check(p.wait_lbl.text.begins_with("或者等待 ") and p.wait_lbl.text.ends_with("体力恢复到 100"), "wait line uses energy_full_left: " + p.wait_lbl.text)
	await shot("energy")
	amber = g.amber
	energy = g.energy
	g.stash = []
	p.btns[2].pressed.emit()
	await create_timer(0.3).timeout
	check(g.amber == amber + 350 and g.energy == energy + 1450 and g.stash == ["chest_1"], "tier 3 pays amber 350, energy 1450, chest")
	check(not p.btns[2].enabled and p.btns[2].text == "已购买" and p.btns[0].enabled, "bought tier disabled, others still buyable")
	await shot("energy_bought")
	await clear()
	# 体力入口（顶栏「+」同一个 open("energy")）：还有没买的档位就还是礼包
	main.open("energy")
	await create_timer(0.2).timeout
	check(top_is("res://scripts/ui/EnergyOfferPopup.gd"), "energy entry reopens offer while tiers remain")
	await clear()
	check((await offers.buy("energy", 0)).get("ok", false) and (await offers.buy("energy", 1)).get("ok", false), "tiers 1 and 2 buyable once")
	check(not (await offers.buy("energy", 0)).get("ok", false), "tier cannot be bought twice")
	main.open("energy")
	await create_timer(0.2).timeout
	check(top_is("res://scripts/ui/PopupBase.gd"), "all tiers bought: energy entry falls back to amber popup")
	await clear()
	# 期满 → 冷却 4 小时 → 再开
	g.simulation_time += 601.0
	check(not offers.active("energy") and not offers.wants_energy(), "energy offer expired, cooling down")
	g.simulation_time += 14400.0
	check(offers.wants_energy(), "energy offer available again after cooldown")
	main.open("energy")
	await create_timer(0.2).timeout
	check(top_is("res://scripts/ui/EnergyOfferPopup.gd") and offers.left("energy", 2) == 1, "new energy window resets tier limits")
	await clear()

	# ---- 存档：offers 字段写进存档、读回来一样
	var d: Dictionary = g.save_dict()
	check(d.has("offers") and (d["offers"] as Dictionary).has("spree") and (d["offers"] as Dictionary).has("energy"), "offers saved in save_dict")

	print("RESULT: ", failures.size(), " failures")
	for f in failures: print("  FAILED: ", f)
	quit(0 if failures.is_empty() else 1)
