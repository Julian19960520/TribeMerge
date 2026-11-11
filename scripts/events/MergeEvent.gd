class_name MergeEvent
extends RefCounted
## Seasonal board controller. Its item IDs never enter the main board/inventory.

static func config() -> Dictionary:
	return Data.ConfigFiles.shared("res://data/merge_events.json")

static func current(at := -1.0) -> Dictionary:
	if at < 0: at = G.now()
	for raw in config().get("seasons", []):
		if not bool(raw.get("enabled", true)): continue
		var start := float(Time.get_unix_time_from_datetime_string(str(raw["start_utc"])))
		var period := float(raw.get("repeat_days", 0)) * 86400.0
		var duration := float(raw.get("duration_days", 7)) * 86400.0
		if at < start: continue
		var index := int((at - start) / period) if period > 0 else 0
		var begins := start + index * period
		if at >= begins + duration: continue
		var c: Dictionary = raw.duplicate(true)
		c["key"] = "%s:%d" % [c["id"], index]
		c["ends_at"] = begins + duration
		return c
	return {}

static func definition(key: String) -> Dictionary:
	for raw in config().get("seasons", []):
		if str(raw["id"]) == key.get_slice(":", 0):
			var c: Dictionary = raw.duplicate(true)
			c["key"] = key
			c["ends_at"] = float(Time.get_unix_time_from_datetime_string(str(c["start_utc"]))) + int(key.get_slice(":", 1)) * float(c.get("repeat_days", 0)) * 86400 + float(c.get("duration_days", 7)) * 86400
			return c
	return {}

static func available(c: Dictionary) -> bool:
	return not c.is_empty() and (G.gm_activities or G.level >= int(c.get("unlock_level", 1)))

static func active(c: Dictionary) -> bool:
	return available(c) and str(current().get("key", "")) == str(c.get("key", ""))

static func fresh(c: Dictionary) -> Dictionary:
	var b: Dictionary = c["board"]
	var cols := int(b["cols"])
	var rows := int(b["total_rows"])
	var cells: Array = []
	for row in rows:
		for col in cols:
			if row == rows - 1:
				cells.append({"id": "", "lock": 0})
				continue
			var tier := locked_tier(b, rows - 2 - row, col)
			cells.append({"id": str(c["chain"][clampi(tier - 1, 0, c["chain"].size() - 2)]["id"]), "lock": 2})
	return {"rules_version": 3, "cells": cells, "points": 0, "earned": 0, "spent": 0, "discovered": {}, "min_view": rows - int(b["visible_rows"]), "view": rows - int(b["visible_rows"]), "claimed": false, "got": [], "orders": 0}

## Locked item tier at a depth (0 = row right above the open bottom row). Deeper layers hold higher relics.
## Shared integer hash keeps client and worker boards identical.
static func locked_tier(b: Dictionary, depth: int, col: int) -> int:
	var seed := int(b.get("seed", 0))
	var layers: Array = b["layers"]
	var tiers: Array = layers[-1]["tiers"]
	var acc := 0
	for layer in layers:
		acc += int(layer["rows"])
		if depth < acc:
			tiers = layer["tiers"]
			break
	return int(tiers[((depth * 131 + col * 71 + seed * 17) % 97) % tiers.size()])

static func state(c: Dictionary) -> Dictionary:
	var key := str(c.get("key", ""))
	if key == "": return {}
	return G.merge_events.get(key, {})

static func next_id(c: Dictionary, id: String) -> String:
	var chain: Array = c["chain"]
	for k in chain.size() - 1:
		if str(chain[k]["id"]) == id: return str(chain[k + 1]["id"])
	return ""

static func item(c: Dictionary, id: String) -> Dictionary:
	for row in c["chain"]:
		if str(row["id"]) == id: return row
	return {}

static func order_points(c: Dictionary, order: Dictionary) -> int:
	var score := 1
	var ids: Array = order.get("items", [])
	for id in ids: score = maxi(score, Data.lv(str(id)))
	score += maxi(0, ids.size() - 1)
	var p: Dictionary = c["points"]
	var tier := 0
	for threshold in p["order_thresholds"]:
		if score >= int(threshold): tier += 1
	return clampi(int(p["order_rewards"][mini(tier, p["order_rewards"].size() - 1)]), 1, 3)

static func on_order(order: Dictionary) -> int:
	var c := current()
	if not available(c): return 0
	var s := state(c)
	var n := order_points(c, order)
	s["points"] = int(s["points"]) + n
	s["earned"] = int(s["earned"]) + n
	s["orders"] = int(s["orders"]) + 1
	_changed()
	return n

static func _changed() -> void:
	G.dirty()
	G.merge_event_changed.emit()

static func remaining(s: Dictionary) -> int:
	var n := 0
	for cell in s["cells"]:
		if int(cell["lock"]) != 0: n += 1
	return n

static func complete(c: Dictionary, s: Dictionary) -> bool:
	return progress(c, s) >= goal_total(c)

## Goal size: covered cells for unlock_all, chain length for discover_all.
static func goal_total(c: Dictionary) -> int:
	if str(c["board"].get("goal", "unlock_all")) == "discover_all": return c["chain"].size()
	return int(c["board"]["cols"]) * (int(c["board"]["total_rows"]) - 1)

static func progress(c: Dictionary, s: Dictionary) -> int:
	if str(c["board"].get("goal", "unlock_all")) == "discover_all":
		var n := 0
		for row in c["chain"]:
			if s["discovered"].has(str(row["id"])): n += 1
		return n
	return goal_total(c) - remaining(s)

## Progress milestones; the last one is the completion reward. Old configs with a bare `rewards` list get one milestone.
static func milestones(c: Dictionary) -> Array:
	return c["milestones"]

static func got(_c: Dictionary, s: Dictionary) -> Array:
	return s["got"]

## Indexes of reached but unclaimed milestones.
static func claimable(c: Dictionary, s: Dictionary) -> Array:
	var out: Array = []
	var have := got(c, s)
	var p := progress(c, s)
	var ms := milestones(c)
	for k in ms.size():
		if p >= mini(int(ms[k]["at"]), goal_total(c)) and not have.has(k): out.append(k)
	return out

static func claim_rewards(c: Dictionary, indexes: Array) -> Array:
	var out: Array = []
	var ms := milestones(c)
	for k in indexes:
		for rw in ms[int(k)]["rewards"]: out.append((rw as Array).duplicate())
	return out

static func unlocked_tier(c: Dictionary, s: Dictionary) -> int:
	var tier := 0
	for k in c["chain"].size():
		if s["discovered"].has(str(c["chain"][k]["id"])): tier = k + 1
	return tier

static func advance_target(c: Dictionary, s: Dictionary) -> int:
	var rows := 0
	var tier := unlocked_tier(c, s)
	for stage in c["board"].get("advance_by_tier", []):
		if tier >= int(stage["tier"]): rows += maxi(0, int(stage["rows"]))
	return maxi(0, int(c["board"]["total_rows"]) - int(c["board"]["visible_rows"]) - rows)

static func _advance(c: Dictionary, s: Dictionary) -> void:
	var cols := int(c["board"]["cols"])
	var rows := int(c["board"]["visible_rows"])
	var cells: Array = s["cells"]
	var target := advance_target(c, s)
	while int(s["view"]) > target:
		var view := int(s["view"])
		var shifted := false
		# Preserve every outgoing item, and never strand an uncleared lower cell.
		for step in range(mini(view - target, int(c["board"]["reveal_rows"])), 0, -1):
			var next_view := view - step
			var next_end := (next_view + rows) * cols
			var outgoing: Array = []
			var slots: Array = []
			var clear := true
			for k in range(next_end, (view + rows) * cols):
				if int(cells[k]["lock"]) != 0: clear = false
				if str(cells[k]["id"]) != "": outgoing.append(k)
			for k in range(next_view * cols, next_end):
				if int(cells[k]["lock"]) == 0 and str(cells[k]["id"]) == "": slots.append(k)
			# Keep room to place and merge a fresh pair after the camera advances.
			if not clear or outgoing.size() + 2 > slots.size(): continue
			slots.reverse()
			for k in outgoing.size():
				cells[slots[k]]["id"] = cells[outgoing[k]]["id"]
				cells[outgoing[k]]["id"] = ""
			s["min_view"] = next_view
			s["view"] = next_view
			shifted = true
			break
		if not shifted: break

## Returns an error string or a result with animation cell indices.
static func local_action(c: Dictionary, s: Dictionary, action: String, args: Dictionary = {}, drop_roll := -1.0) -> Dictionary:
	var cells: Array = s["cells"]
	var cols := int(c["board"]["cols"])
	var view := int(s["view"])
	if action != "claim" and int(args.get("view", view)) != view: return {"error": "棋盘已滚动，请重试"}
	var lo := view * cols
	var hi := lo + int(c["board"]["visible_rows"]) * cols
	var result := {}
	if action != "claim" and bool(s["claimed"]): return {"error": "本期奖励已领取"}
	s["view"] = view
	if action == "spawn":
		var cost := int(c["points"]["spawn_cost"])
		if int(s["points"]) < cost: return {"error": "完成主棋盘订单可获得活动积分"}
		var to := MergeGrid.nearest_empty(cells, cols, hi - cols + cols / 2, func(k): return k >= lo and k < hi)
		if to < 0: return {"error": "当前区域已满，请先合并物品"}
		var id := str(c["chain"][int(c["points"]["spawn_tier"]) - 1]["id"])
		s["points"] = int(s["points"]) - cost
		s["spent"] = int(s["spent"]) + cost
		cells[to]["id"] = id
		s["discovered"][id] = true
		result = {"kind": "spawn", "to": to, "id": id}
	elif action == "drop":
		var a := int(args.get("from", -1))
		var b := int(args.get("to", -1))
		if a < lo or a >= hi or b < lo or b >= hi: return {"error": ""}
		if int(cells[b]["lock"]) == 2: return {"error": "先在旁边合并，揭开覆盖"}
		var next := func(id): return next_id(c, id)
		var kind := MergeGrid.drop_kind(cells, a, b, next)
		if kind == "": return {"error": "锁定物品需要用同级物品合并解锁" if int(cells[b]["lock"]) != 0 else ""}
		var locked := int(cells[b]["lock"]) != 0
		var id := str(cells[a]["id"])
		var under := str(cells[b]["id"])
		MergeGrid.apply_drop(cells, a, b, kind, next)
		var revealed := MergeGrid.reveal_neighbors(cells, b, cols) if kind == "merge" else []
		var drop := Data.resource_drop("event", drop_roll if drop_roll >= 0 else G.rng.randf(), G.level) if kind == "merge" else ""
		s["discovered"][str(cells[b]["id"])] = true
		if locked: s["discovered"][under] = true
		result = {"kind": kind, "from": a, "to": b, "id": id, "under": under, "unlocked": locked, "revealed": revealed}
		if drop != "": result["drops"] = [drop]
	elif action == "recycle":
		var at := int(args.get("cell", -1))
		if at < lo or at >= hi or int(cells[at]["lock"]) != 0 or str(cells[at]["id"]) == "": return {"error": "请选择一个未锁定的物品"}
		cells[at]["id"] = ""
		result = {"kind": "recycle"}
	elif action == "claim":
		var ready := claimable(c, s)
		if ready.is_empty(): return {"error": "继续解锁遗迹，到达下一个宝箱即可领取"}
		var have := got(c, s).duplicate()
		have.append_array(ready)
		s["got"] = have
		if have.has(milestones(c).size() - 1): s["claimed"] = true
		result = {"kind": "claim", "milestones": ready, "rewards": claim_rewards(c, ready)}
	else: return {"error": "未知操作"}
	if action in ["drop", "spawn", "recycle"]:
		_advance(c, s)
		result["advance_rows"] = view - int(s["view"])
	return result

static func act(c: Dictionary, action: String, args: Dictionary = {}) -> Dictionary:
	var input := args.duplicate()
	input["season"] = str(c["key"])
	input["action"] = action
	return Replay.perform("activity", input)
