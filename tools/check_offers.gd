extends SceneTree
## Current limited-offer windows, limits and rejection before platform payment integration.
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func run() -> void:
	var g = root.get_node("G")
	var replay = root.get_node("Replay")
	var offers = load("res://scripts/events/Offers.gd")
	g.set_process(false); replay.set_process(false); root.get_node("Cloud").set_process(false)
	g.simulation_time = 1793577600.0
	replay.active = true; replay.worker = true; replay.authorized = true; replay.executing = true
	replay.clock = int(g.simulation_time); replay.meta = {"allow_gm": false}; g.replay_meta = replay.meta
	g.new_game(); g.tutorial_on = false; g.seen_tutorial = true; g.level = 12
	replay.advance(); replay.executing = false
	for kind in ["spree", "energy"]:
		for index in offers.tiers(kind).size():
			var tier: Dictionary = offers.tier(kind, index)
			var percent: float = offers.value(tier["rewards"]) / (float(tier["price_cny"]) * 15.0) * 100.0
			check(absf(percent - float(tier["value_pct"])) <= 5.0, "%s tier %d value matches the displayed percentage" % [kind, index])
	check(not replay.perform("offer", {"kind": "spree"}).get("ok", false), "spree stays locked at level twelve")
	g.level = 13
	check(replay.perform("offer", {"kind": "spree"}).get("ok", false) and offers.remaining("spree") == 3600, "spree opens for one configured hour")
	var before: Dictionary = g.business_snapshot().duplicate(true)
	check(not offers.buy("spree", 0).get("ok", false) and g.business_snapshot() == before and offers.left("spree", 0) == 5, "unconnected payment cannot grant assets or consume a purchase limit")
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	var panel = main.open("spree")
	await process_frame
	check(panel.left_lbl.text == "剩余可买：5" and panel.buy_btn.text == "¥6", "spree displays the current price and purchase limit")
	panel.buy_btn.pressed.emit()
	await process_frame
	check(g.business_snapshot() == before, "pressing the payment button cannot create a local payment reward")
	g.offers["spree"]["bought"] = {"0": 5} # Authoritative entitlement fixture, never a simulated payment.
	panel._refresh()
	check(not panel.buy_btn.enabled and panel.buy_btn.text == "已买完", "confirmed purchase limits disable exhausted offers")
	main.close_all(); await process_frame
	g.simulation_time += 3601.0
	replay.perform("tick")
	check(not offers.active("spree") and not offers.can_open("spree"), "expired spree observes its cooldown")
	g.simulation_time += 72000.0
	replay.perform("tick")
	check(offers.can_open("spree") and replay.perform("offer", {"kind": "spree"}).get("ok", false) and offers.left("spree", 0) == 5, "next spree window resets limits after cooldown")
	g.level = 16; g.energy = 0
	check(replay.perform("offer", {"kind": "energy"}).get("ok", false) and offers.remaining("energy") == 3600, "energy offer opens for its configured hour")
	panel = main.open("energy_offer"); await process_frame
	check(panel.btns.size() == 3 and panel.btns[0].text == "¥18" and panel.btns[1].text == "¥30" and panel.btns[2].text == "¥45", "energy offer displays all three current prices")
	before = g.business_snapshot().duplicate(true)
	check(not offers.buy("energy", 2).get("ok", false) and g.business_snapshot() == before, "energy purchase also requires platform payment verification")
	g.simulation_time += 3601.0; replay.perform("tick")
	check(not offers.active("energy") and not offers.wants_energy(), "expired energy offer observes its cooldown")
	g.simulation_time += 14400.0; replay.perform("tick")
	check(offers.wants_energy(), "energy offer becomes available after cooldown")
	var saved: Dictionary = replay.snapshot().duplicate(true)
	g.offers = {}
	check(replay.restore(JSON.parse_string(JSON.stringify(saved))) and g.offers == saved["offers"], "limited-offer windows roundtrip through the current snapshot")
	main.free(); g.main = null
	print("RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
