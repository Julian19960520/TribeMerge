class_name MergeEvent
extends RefCounted
## Seasonal board controller. Its item IDs never enter the main board/inventory.
static var _config: Dictionary = {}
static var _textures: Dictionary = {}
static var busy := false

static func config() -> Dictionary:
	if _config.is_empty():
		var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/merge_events.json"))
		if raw is Dictionary: _config = raw
	return _config

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
	var tiers: Array = b["locked_tiers"]
	for row in rows:
		for col in cols:
			var depth := rows - 2 - row
			var tier := int(tiers[(maxi(depth, 0) / 2 + col + int(b.get("seed", 0))) % tiers.size()])
			if depth < 2: tier = 1
			cells.append({"id": str(c["chain"][clampi(tier - 1, 0, c["chain"].size() - 2)]["id"]) if row < rows - 1 else "", "lock": 2 if row < rows - 1 else 0})
	return {"rules_version": 2, "cells": cells, "points": 0, "earned": 0, "spent": 0, "discovered": {}, "min_view": rows - int(b["visible_rows"]), "view": rows - int(b["visible_rows"]), "claimed": false, "orders": 0}

static func state(c: Dictionary) -> Dictionary:
	var key := str(c.get("key", ""))
	if key == "": return {}
	if not G.merge_events.has(key):
		G.merge_events[key] = fresh(c)
		G.dirty()
	if migrate(c, G.merge_events[key]): G.dirty()
	return G.merge_events[key]

static func migrate(c: Dictionary, s: Dictionary) -> bool:
	if int(s.get("rules_version", 1)) >= 2: return false
	var cells: Array = s["cells"]
	var cols := int(c["board"]["cols"])
	for k in cells.size():
		if int(cells[k]["lock"]) != 1: continue
		var frontier := false
		for neighbor in MergeGrid.neighbors(k, cols, cells.size()):
			if int(cells[neighbor]["lock"]) == 0: frontier = true
		if not frontier: cells[k]["lock"] = 2
	s["rules_version"] = 2
	s["min_view"] = int(s["view"])
	return true

static func next_id(c: Dictionary, id: String) -> String:
	var chain: Array = c["chain"]
	for k in chain.size() - 1:
		if str(chain[k]["id"]) == id: return str(chain[k + 1]["id"])
	return ""

static func item(c: Dictionary, id: String) -> Dictionary:
	for row in c["chain"]:
		if str(row["id"]) == id: return row
	return {}

static func texture(path: String) -> Texture2D:
	if not _textures.has(path): _textures[path] = load(path)
	return _textures[path]

static func draw_item(ci: CanvasItem, c: Dictionary, id: String, center: Vector2, size: float, tint := Color.WHITE) -> void:
	var row := item(c, id)
	if row.is_empty(): return
	ci.draw_texture_rect(texture(str(row["icon"])), Rect2(center - Vector2.ONE * size / 2, Vector2.ONE * size), false, tint)

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
	if str(c["board"].get("goal", "unlock_all")) == "discover_all":
		for row in c["chain"]:
			if not s["discovered"].has(str(row["id"])): return false
		return true
	return remaining(s) == 0

static func _advance(c: Dictionary, s: Dictionary) -> void:
	var cols := int(c["board"]["cols"])
	var rows := int(c["board"]["visible_rows"])
	var cells: Array = s["cells"]
	while int(s["view"]) > 0:
		var view := int(s["view"])
		var ready := true
		for col in cols:
			if int(cells[view * cols + col]["lock"]) != 0: ready = false
		if not ready: break
		var shifted := false
		# Preserve every outgoing item, and never strand an uncleared lower cell.
		for step in range(mini(view, int(c["board"]["reveal_rows"])), 0, -1):
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
			if not clear or outgoing.size() > slots.size(): continue
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
static func local_action(c: Dictionary, s: Dictionary, action: String, args: Dictionary = {}) -> Dictionary:
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
		s["discovered"][str(cells[b]["id"])] = true
		if locked: s["discovered"][under] = true
		result = {"kind": kind, "from": a, "to": b, "id": id, "under": under, "unlocked": locked, "revealed": revealed}
		_advance(c, s)
	elif action == "recycle":
		var at := int(args.get("cell", -1))
		if at < lo or at >= hi or int(cells[at]["lock"]) != 0 or str(cells[at]["id"]) == "": return {"error": "请选择一个未锁定的物品"}
		cells[at]["id"] = ""
		result = {"kind": "recycle"}
	elif action == "claim":
		if bool(s["claimed"]) or not complete(c, s): return {"error": "奖励已领取，或尚未完成活动"}
		s["claimed"] = true
		result = {"kind": "claim", "rewards": c["rewards"].duplicate(true)}
	else: return {"error": "未知操作"}
	return result

static func act(c: Dictionary, action: String, args: Dictionary = {}) -> Dictionary:
	if busy: return {"error": ""}
	if action != "claim" and not active(c): return {"error": "本期活动已结束"}
	busy = true
	var result: Dictionary
	if G.server_mode():
		var body: Dictionary = args.duplicate()
		body["season"] = str(c["key"])
		body["action"] = action
		var minus: Array = c["rewards"] if action == "claim" else []
		var response: Dictionary = await G._cloud().act("/v1/merge-event/action", body, minus)
		result = response.get("give", {}) if response.get("ok", false) else {"error": str(response.get("message", "连不上服务器"))}
	else:
		result = local_action(c, state(c), action, args)
	busy = false
	if not result.has("error"):
		_changed()
		if action == "claim":
			Rewards.grant(c["rewards"], Callable(), false)
			if G.main: G.main.present_rewards(c["rewards"], false)
		G.save_game()
	return result
