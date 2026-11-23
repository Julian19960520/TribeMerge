extends "res://scripts/domain/RuleModule.gd"
## The tutorial is a saved, replayable sequence. The view only acknowledges narration
## and navigation; merges, orders, construction and rewards advance from actual state.

func config() -> Dictionary:
	return Data.ConfigFiles.shared("res://data/onboarding.json")

func progress() -> Dictionary:
	return context.meta().get("onboarding", {})

func active() -> bool:
	return state.tutorial_on and not state.gm_activities and not progress().is_empty()

func stage() -> Dictionary:
	var steps: Array = config()["stages"]
	return steps[clampi(int(progress().get("step", 0)), 0, steps.size() - 1)] if active() else {}

func stage_index(key: String) -> int:
	var steps: Array = config()["stages"]
	for i in steps.size():
		if str(steps[i]["key"]) == key: return i
	return -1

func start() -> void:
	context.meta().erase("onboarding")

func ensure() -> void:
	if not state.tutorial_on or state.gm_activities or not progress().is_empty(): return
	# Previously started tutorials keep their board, balances and outstanding orders.
	# They are released into play rather than being reset to the new opening layout.
	if not state.orders.is_empty() or state.level > 1 or int(state.builds.get("fire", 0)) > 1:
		state.tutorial_on = false
		state.seen_tutorial = true
		for order in state.orders: order.erase("tutorial")
		context.orders.refill_orders()
		return
	context.meta()["onboarding"] = {"step": 0, "issued": [], "delivered": [], "completed": [], "produced": 0, "baseline": 0, "collected": {}, "energy_gift": false}

func advance() -> void:
	ensure()
	if not active(): return
	refill()
	_check_rescue()
	# A command may satisfy adjacent observational frames, but never skips narration.
	for _i in config()["stages"].size():
		var current := stage()
		# Keep the saved step index, but the resource pickup lesson is retired.
		if str(current.get("key", "")) == "coin":
			_next()
			continue
		if str(current.get("key", "")) in ["free_energy_gift", "energy_gift", "egen_merge", "egen_collect"] and context.starter.expired():
			_next()
			continue
		# The drops may already be merged, spent or claimed by hand; a lesson
		# step with no pair left to merge would otherwise hold the board forever.
		if str(current.get("key", "")) == "egen_merge" and not _satisfied(current.get("wait", {})):
			var pair_left := false
			for pair in current.get("pairs", [current.get("pair", [])]):
				if (pair as Array).size() > 0 and count(str(pair[0])) >= 2: pair_left = true
			if not pair_left:
				_next()
				continue
		if str(current.get("mode", "")) == "complete":
			state.tutorial_on = false
			state.seen_tutorial = true
			context.orders.refill_orders()
			return
		var wait: Dictionary = current.get("wait", {})
		if wait.is_empty() or wait.has("presentation") or not _satisfied(wait): return
		_next()

func acknowledge(key: String) -> Dictionary:
	if not active() or str(stage().get("key", "")) != key: return {"error": TextCatalog.source("notice.onboardingrules.ccea20ccace0")}
	if str(stage().get("mode", "")) not in ["dialog", "banner", "enter_board", "open_build", "back", "level_open", "level_close", "recipe_open", "recipe_close", "howto", "animation", "build_preview"]:
		return {"error": TextCatalog.source("notice.onboardingrules.6fae244b7f53")}
	_next()
	return {}

func _next() -> void:
	var p := progress()
	(p["completed"] as Array).append(str(stage()["key"]))
	p["step"] = int(p["step"]) + 1
	p["baseline"] = int(p["produced"])
	state.dirty()
	state.board_changed.emit()
	refill()

func _satisfied(w: Dictionary) -> bool:
	if w.has("has"): return count(str(w["has"])) > 0
	if w.has("count"): return count(str(w["count"][0])) >= int(w["count"][1])
	if w.has("delivered"): return progress()["delivered"].has(str(w["delivered"]))
	if w.has("build"): return int(state.builds.get(str(config()["build_area"]), 0)) >= int(w["build"])
	if w.has("level"): return state.level >= int(w["level"])
	if w.has("produced_since"): return int(progress()["produced"]) - int(progress()["baseline"]) >= int(w["produced_since"])
	if w.has("collected"): return int(progress()["collected"].get(str(w["collected"]), 0)) > 0
	if w.has("ready"):
		var o := order(str(w["ready"]))
		return not o.is_empty() and context.orders.order_ready(o)
	if w.has("craft_ready"):
		var o := order(str(w["craft_ready"]))
		return not o.is_empty() and context.orders.craft_mats_ready(o)
	if w.has("phase"): return str(order(str(w["phase"][0])).get("phase", "")) == str(w["phase"][1])
	if w.has("energy_gift"): return bool(progress()["energy_gift"])
	if w.has("egen_taps"): return int(progress().get("egen_taps", 0)) >= int(w["egen_taps"])
	if w.has("absent"): return count(str(w["absent"])) == 0
	if w.has("energy_gift_ready"):
		var free_slots := 0
		for cell in state.board:
			if int(cell["lock"]) == 0 and str(cell["id"]) == "" and not cell.has("ck"): free_slots += 1
		# Every lesson tap needs its own empty cell; merging is locked until the taps finish.
		var taps := int(config().get("energy_gift_taps", 2))
		return bool(progress()["energy_gift"]) or energy_lesson_needed() and count(str(config()["energy_generator"])) > 0 and free_slots >= taps and context.starter.left() >= taps
	return false

func energy_lesson_needed() -> bool:
	if state.energy == 0: return true
	for tag in config().get("energy_gift_after", []):
		if not progress().get("delivered", []).has(str(tag)): return false
	return not config().get("energy_gift_after", []).is_empty()

func count(id: String, locked := false) -> int:
	var n := 0
	for cell in state.board:
		if str(cell["id"]) == id and (int(cell["lock"]) == 0 or locked and int(cell["lock"]) == 1): n += 1
	return n

func order(tag: String) -> Dictionary:
	for o in state.orders:
		if str(o.get("onboarding", "")) == tag: return o
	return {}

func _vine_target(id: String, row: Dictionary) -> String:
	var output: String = context.orders.vine_output(id)
	# A lesson order may ask for the item one merge with a vined copy makes, never
	# a whole chain of vines above it: that turned a pear into a 256-berry grape.
	var limit := int(row.get("max_item_level", Data.lv(id) + 1))
	if Data.lv(output) <= limit: return output
	# Revealing a chain of vines must not promote a beginner's affordable order
	# all the way to a pomegranate. Prefer another non-vine target in its budget.
	var keys: Dictionary = context.orders.vine_plan()["keys"]
	var chain := Data.chain(id)
	for level in range(mini(limit, Data.max_lv(chain)), 0, -1):
		var candidate := "%s_%d" % [chain, level]
		if not keys.has(candidate): return candidate
	return "%s_%d" % [chain, limit]

func refill() -> void:
	if not active(): return
	var p := progress()
	var changed := _sync_orders()
	var cap := 1 if int(state.builds.get(str(config()["build_area"]), 0)) < 3 else 2
	for row in config()["orders"]:
		if state.orders.size() >= cap: break
		var tag := str(row["tag"])
		if p["issued"].has(tag) or state.level < int(row["level"]) or int(state.builds.get(str(config()["build_area"]), 0)) < int(row["build"]): continue
		if row.has("gate") and int(p["step"]) < stage_index(str(row["gate"])): continue
		if row.has("after") and not p["delivered"].has(str(row["after"])): continue
		var o := {"who": p["issued"].size() % Data.PEOPLE.size(), "items": row["items"].duplicate(), "rw": {"shell": int(row["coin"])}, "story": true, "onboarding": tag}
		if int(row["xp"]) > 0: o["rw"]["xp"] = int(row["xp"])
		if row.has("dish"):
			var dish := str(row["dish"])
			var d: Dictionary = Data.DISHES[dish.trim_prefix("dish_")]
			o.merge({"kind": "craft", "dish": dish, "mats": d["mats"].duplicate(), "secs": int(d["secs"]), "phase": "need", "manual_collect": true})
			o["items"] = d["mats"].duplicate()
		state.order_identity(o)
		o["guide_revision"] = int(config()["version"])
		if row.get("prefer_vine_output", false) and not row.has("dish"):
			for i in o["items"].size(): o["items"][i] = _vine_target(str(o["items"][i]), row)
		state.orders.append(o)
		p["issued"].append(tag)
		changed = true
	if changed:
		state.dirty()
		state.orders_changed.emit()

func _sync_orders() -> bool:
	var rows := {}
	for row in config()["orders"]: rows[str(row["tag"])] = row
	var changed := false
	for index in range(state.orders.size() - 1, -1, -1):
		var o: Dictionary = state.orders[index]
		if not o.has("onboarding"): continue
		var row: Dictionary = rows.get(str(o["onboarding"]), {})
		var cooking := str(o.get("kind", "")) == "craft" and str(o.get("phase", "need")) != "need"
		if row.is_empty():
			# Keep earned work and already-displayed XP. Unstarted retired recipes
			# become ordinary orders instead of taking away their fixed star.
			if str(o.get("kind", "")) == "craft" and not cooking:
				o["items"] = [context.orders.vine_output("fruit_6" if str(o["onboarding"]) == "craft4" else "fruit_7")]
				for key in ["kind", "dish", "mats", "secs", "phase", "cell", "t0", "manual_collect"]: o.erase(key)
				o["guide_revision"] = int(config()["version"])
				changed = true
			continue
		if int(o.get("guide_revision", 0)) < int(config()["version"]):
			# Already completed work and all displayed XP remain claimable as offered.
			var prepared: bool = context.orders.order_ready(o) or str(o.get("kind", "")) == "craft" and context.orders.craft_mats_ready(o)
			if not cooking and not prepared:
				o["items"] = row["items"].duplicate()
				if row.has("dish"):
					var d: Dictionary = Data.DISHES[str(row["dish"])]
					o.merge({"dish": str(row["dish"]), "mats": d["mats"].duplicate(), "items": d["mats"].duplicate(), "secs": int(d["secs"])}, true)
				else:
					for key in ["kind", "dish", "mats", "secs", "phase", "cell", "t0", "manual_collect"]: o.erase(key)
				o["rw"]["shell"] = int(row["coin"])
				if row.get("prefer_vine_output", false) and not row.has("dish"):
					for i in o["items"].size(): o["items"][i] = _vine_target(str(o["items"][i]), row)
			o["guide_revision"] = int(config()["version"])
			changed = true
		if not row.get("prefer_vine_output", false) or row.has("dish"): continue
		# Follow a newly revealed vined copy (merging into it costs nothing extra),
		# but never climb past one level above the lesson's item.
		if row.has("max_item_level") and context.orders.order_ready(o): continue
		for i in o["items"].size():
			if i >= row["items"].size(): break
			var capped: Dictionary = row.duplicate()
			capped["max_item_level"] = int(row.get("max_item_level", Data.lv(str(row["items"][i])) + 1))
			var id: String = _vine_target(str(o["items"][i]), capped)
			if Data.lv(id) > Data.lv(str(o["items"][i])): o["items"][i] = id; changed = true
	return changed

func delivered(o: Dictionary) -> void:
	if active() and o.has("onboarding"):
		(progress()["delivered"] as Array).append(str(o["onboarding"]))

func observe(name: String, args: Dictionary, result: Dictionary) -> void:
	if not active(): return
	if name == "tap" and str(result.get("kind", "")) == "produce":
		progress()["produced"] = int(progress()["produced"]) + 1
		if context.starter.is_item(context.board.cell_id(int(args.get("cell", -1)))):
			progress()["energy_gift"] = true
			progress()["egen_taps"] = int(progress().get("egen_taps", 0)) + 1
	if name == "tap" and str(result.get("kind", "")) == "collect":
		var id := str(result.get("id", ""))
		var kind := Data.type_of(id)
		progress()["collected"][kind] = int(progress()["collected"].get(kind, 0)) + int(result.get("amount", 0))
	advance()

func merge_fragment(merged: String, roll: float) -> String:
	if not active(): return ""
	var lesson: Dictionary = config()["coin_tutorial"]
	if int(progress()["step"]) < stage_index(str(lesson["start_stage"])): return ""
	# Use the same configured drop item and probability as normal play.
	var drop := Data.resource_drop("main", roll, state.level, merged)
	if drop != str(lesson["drop"]): return ""
	var empty := 0
	for cell in state.board:
		if int(cell["lock"]) == 0 and str(cell["id"]) == "" and not cell.has("ck"): empty += 1
	# Do not consume the last production slot, especially before a forced tap.
	if empty < 2: return ""
	return drop

func scripted_drop(gen_id: String) -> String:
	if not active(): return ""
	if str(stage().get("key", "")) == "gen_tap" and gen_id == str(config()["upgraded_generator"]):
		return str(config()["upgrade_first_drop"])
	# Like the reference game's gift box: the lesson's four drops merge pairwise
	# into one full basket of stamina (4 x 15 -> 2 x 40 -> 100), refilling an empty bar.
	# The pot can be taken from the stash and tapped before stamina runs out, so
	# the first taps give the lesson's drop whenever they happen.
	if gen_id == str(config()["energy_generator"]) and int(progress().get("egen_taps", 0)) < int(config().get("energy_gift_taps", 2)) and int(progress()["step"]) <= stage_index("energy_gift"):
		return str(config().get("energy_gift_drop", ""))
	# Only the single new-product lesson is scripted. All subsequent production
	# uses the exact drops displayed by Data.gen_stats, including the configured secondary rate.
	return ""

func unlimited_generator(id: String) -> bool:
	# This tutorial takes minutes. A 12-minute cooldown would block the early loop.
	return active() and id in [str(config()["generator"]), str(config()["upgraded_generator"])]

func _check_rescue() -> void:
	var d: Dictionary = config()["rescue"]
	if state.level < int(d["min_level"]) or state.level > int(d["max_level"]) or state.energy > 0 or not context.meta().get("free_energy", false): return
	if progress().get("rescue_claimed", false): return
	var cleared := 0
	for cell in state.board:
		if int(cell["lock"]) == 0: cleared += 1
	if cleared >= int(d["cleared_cells"]): progress()["rescue_pending"] = true

func claim_rescue() -> Dictionary:
	if not active() or not progress().get("rescue_pending", false) or progress().get("rescue_claimed", false): return {"error": TextCatalog.source("notice.onboardingrules.957ba00eb791")}
	progress()["rescue_claimed"] = true
	progress()["rescue_pending"] = false
	var rewards: Array = [config()["rescue"]["reward"]]
	context.settle(rewards)
	return {"rewards": rewards}
