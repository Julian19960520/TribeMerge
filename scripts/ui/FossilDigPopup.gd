extends PopupBase
const GRID := Rect2(70, 620, 580, 580)
var body: Control
var board_art: DrawBox
var slots_art: DrawBox
var progress_art: DrawBox
var effects: DrawBox
var stage_label: Label
var count_label: Label
var progress_label: Label
var hint: Label
var primary: TButton
var cells: Control
var working := true
var flies: Array = []
var dust: Array = []
var signature := ""
var board_signature := ""

func _ready() -> void:
	name = "fossil_dig_popup"
	Popups.frame(self, Rect2(30, 146, 660, 1240), "恐龙化石", Color("7b6842"))
	body = Control.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(body)
	UI.box(body, Rect2(0, 0, 720, 1480), _decoration, false)
	var info := UI.btn(body, Rect2(58, 186, 46, 46), "?", "teal", _instructions, 26)
	info.is_round = true
	progress_label = UI.lbl(body, "挖出化石，领取考古奖励", Rect2(116, 188, 488, 40), 25, Color("674930"))
	progress_art = UI.box(body, Rect2(0, 0, 720, 1480), _progress, false)
	for i in FossilDig.config()["milestones"].size():
		var row: Dictionary = FossilDig.config()["milestones"][i]
		var hit := UI.hit(body, Rect2(_reward_x(i) - 40, 236, 80, 100), _preview.bind(int(row["bones"])))
		hit.name = "fossil_reward_%d" % int(row["bones"])
	stage_label = UI.lbl(body, "准备挖掘区…", Rect2(76, 344, 568, 40), 26, Color.WHITE)
	slots_art = UI.box(body, Rect2(0, 0, 720, 1480), _slots, false)
	hint = UI.lbl(body, "点击土块开挖，集齐完整骨头", Rect2(64, 552, 592, 40), 23, Color("7b6347"))
	board_art = UI.box(body, GRID, _board, false)
	cells = Control.new()
	cells.position = GRID.position
	cells.size = GRID.size
	cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(cells)
	UI.box(body, Rect2(96, 1240, 528, 54), func(ci, sz):
		Paint.pill(ci, Rect2(Vector2.ZERO, sz))
		FossilArt.shovel(ci, Vector2(44, 24), 60, -0.35)
		var text := "每挖一格用 %d 把" % int(FossilDig.config()["dig_cost"])
		ci.draw_string(G.font_body, Vector2(300, 36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("826243")), false)
	count_label = UI.lbl(body, "铲子  0", Rect2(168, 1240, 220, 54), 30, Color("5d422c"), HORIZONTAL_ALIGNMENT_LEFT)
	primary = UI.btn(body, Rect2(164, 1304, 392, 72), "准备中…", "green", _primary, 34)
	primary.name = "fossil_primary"
	primary.enabled = false
	effects = UI.box(body, Rect2(0, 0, 720, 1480), _effects, false)
	var result: Dictionary = await FossilDig.act("refresh")
	if not is_inside_tree() or _closing: return
	working = false
	if result.has("error"):
		hint.text = str(result["error"])
		primary.text = "重新连接"
		primary.enabled = true
	else: _refresh()
	G.changed.connect(_refresh)

func _decoration(ci: CanvasItem, _sz: Vector2) -> void:
	# 进度区：一块浅色兽皮底
	ci.draw_colored_polygon(Art.rrect(Rect2(60, 180, 600, 156), 20, 984, 0.6), Color(0.55, 0.38, 0.2, 0.14))
	# 陈列区标题条
	Paint.banner(ci, Rect2(190, 340, 340, 48), Color("8a6a3e"))
	# 挖掘场外框
	Sprites.draw(ci, "fos_frame", GRID.grow(28))

func _reward_x(i: int) -> float:
	return 100.0 + i * 520.0 / maxi(1, FossilDig.config()["milestones"].size() - 1)

func _progress(ci: CanvasItem, _sz: Vector2) -> void:
	var rows: Array = FossilDig.config()["milestones"]
	var s := FossilDig.state()
	var score := int(s.get("recovered", 0))
	var fill_x := 68.0
	var previous := 0
	var previous_x := 68.0
	for i in rows.size():
		var goal := int(rows[i]["bones"])
		var x := _reward_x(i)
		if score >= goal: fill_x = x
		elif score >= previous:
			fill_x = lerpf(previous_x, x, float(score - previous) / maxi(1, goal - previous))
		previous = goal
		previous_x = x
	if score >= int(rows[-1]["bones"]): fill_x = 652
	Paint.bar(ci, Rect2(68, 258, 584, 22), (fill_x - 68.0) / 584.0, Art.MOSS)
	for i in rows.size():
		var need := int(rows[i]["bones"])
		var got: bool = need in s.get("claimed", [])
		var ready := score >= need and not got
		var x := _reward_x(i)
		var rw: Array = rows[i]["rewards"]
		var best: Array = rw[-1]
		if ready:
			Sprites.at(ci, "ev_disc", Vector2(x, 268), 0.82, 0.0, Color(1, 0.9, 0.45, 0.6))
		Paint.reward_bubble(ci, Vector2(x, 268), 31, str(best[0]), int(best[1]), i)
		if got:
			ci.draw_circle(Vector2(x, 268), 31, Color(1, 1, 1, 0.45))
			Paint.check_mark(ci, Vector2(x + 16, 284), 0.7)
		# 「几块骨头」标签：小骨头 + 数字
		var text := "领取！" if ready else str(need)
		var fs := 22
		var tw: float = G.font_title.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tx := x - (tw + 22.0) * 0.5
		Sprites.at(ci, "fos_bone_limb_1x2", Vector2(tx + 8, 320), 0.16, PI * 0.5)
		ci.draw_string_outline(G.font_title, Vector2(tx + 22, 328), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Art.INK)
		ci.draw_string(G.font_title, Vector2(tx + 22, 328), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffe27a") if ready else Color.WHITE)

## 陈列卡的位置：最多一排 6 张，多了排两排
func _slot_rect(i: int) -> Rect2:
	var total: int = FossilDig.board().get("pieces", []).size()
	var cols := mini(6, maxi(1, total))
	var rows := 1 if total <= 6 else 2
	var row := i / cols
	var count := mini(cols, total - row * cols)
	var cw := 90.0 if rows == 1 else 84.0
	var ch := 128.0 if rows == 1 else 66.0
	var gap := 8.0
	var x := 360.0 + (i % cols - (count - 1) * 0.5) * (cw + gap)
	var y := 400.0 + row * (ch + 8.0)
	return Rect2(x - cw * 0.5, y, cw, ch)

func _flying(id: int) -> bool:
	return flies.any(func(f): return int(f["piece"]["id"]) == id)

func _slots(ci: CanvasItem, _sz: Vector2) -> void:
	var b := FossilDig.board()
	var pieces: Array = b.get("pieces", [])
	if pieces.is_empty(): return
	Sprites.draw(ci, "fos_shelf", Rect2(64, _slot_rect(0).end.y - 14, 592, 40))
	if pieces.size() > 6:
		Sprites.draw(ci, "fos_shelf", Rect2(64, _slot_rect(pieces.size() - 1).end.y - 14, 592, 40))
	for i in pieces.size():
		var p: Dictionary = pieces[i]
		var r := _slot_rect(i)
		var found := bool(p["found"]) and not _flying(int(p["id"]))
		if found:
			Sprites.at(ci, "ev_disc", r.get_center(), r.size.x / 104.0, 0.0, Color(1, 0.92, 0.55, 0.45))
		Sprites.draw(ci, "fos_card", r)
		var big := r.size.y > 100.0
		var art := Rect2(r.position + Vector2(10, 10), r.size - Vector2(20, 44 if big else 20))
		FossilArt.piece(ci, art, p, not found)
		if big:
			var nm := str(p.get("name", ""))
			ci.draw_string(G.font_body, Vector2(r.position.x, r.end.y - 12), nm, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, Color("6a4a2c") if found else Color("9a805e"))
		if found: Paint.check_mark(ci, r.position + Vector2(r.size.x - 14, 16), 0.5)

func _piece_rect(piece: Dictionary) -> Rect2:
	var pitch := GRID.size.x / int(FossilDig.board()["n"])
	return Rect2(GRID.position + Vector2(int(piece["x"]), int(piece["y"])) * pitch, Vector2(int(piece["w"]), int(piece["h"])) * pitch)

func _board(ci: CanvasItem, sz: Vector2) -> void:
	var b := FossilDig.board()
	if b.is_empty(): return
	var n := int(b["n"])
	var pitch := sz.x / n
	# 先铺满坑底，再画还埋着的骨头，最后盖上没挖的土块
	for cell in n * n:
		FossilArt.pit(ci, Rect2(Vector2(cell % n, cell / n) * pitch, Vector2.ONE * pitch))
	for p in b["pieces"]:
		if p["found"]: continue
		var r := _piece_rect(p)
		r.position -= GRID.position
		FossilArt.piece(ci, r.grow(-pitch * 0.04), p)
	for cell in n * n:
		if cell in b["dug"]: continue
		FossilArt.dirt(ci, Rect2(Vector2(cell % n, cell / n) * pitch, Vector2.ONE * pitch).grow(1), cell)

func _refresh() -> void:
	if _closing or not is_instance_valid(primary): return
	var b := FossilDig.board()
	if b.is_empty(): return
	var s := FossilDig.state()
	var sig := str([s, flies.size(), working])
	if sig == signature: return
	signature = sig
	var found: int = b["pieces"].filter(func(p): return bool(p["found"])).size()
	stage_label.text = "第 %d 关 · 骨头 %d/%d" % [int(s["stage"]), found, b["pieces"].size()]
	progress_label.text = "收集进度  %d / %d" % [int(s["recovered"]), int(FossilDig.config()["milestones"][-1]["bones"])]
	count_label.text = "铲子  %d" % int(s["shovels"])
	primary.enabled = not working and flies.is_empty()
	primary.text = "去帮族人"
	if FossilDig.cleared():
		if not flies.is_empty(): primary.text = "化石归位中…"
		elif FossilDig.finished():
			primary.text = "领取进度奖励" if not FossilDig.ready_rewards().is_empty() else "全部挖掘完成"
			primary.enabled = not working and not FossilDig.ready_rewards().is_empty()
		else: primary.text = "下一关 · %d×%d" % [int(b["n"]) + 1, int(b["n"]) + 1]
		hint.text = "本关化石已集齐！" if not FossilDig.finished() else "远古骨骼全部重见天日！"
	elif int(s["shovels"]) < int(FossilDig.config()["dig_cost"]): hint.text = "每实现一个心愿，获得 %d 把铲子" % int(FossilDig.config()["shovels_per_order"])
	else: hint.text = "点击土块开挖，集齐完整骨头"
	primary.queue_redraw()
	var bsig := str([s["stage"], b["n"]])
	if bsig != board_signature:
		board_signature = bsig
		for child in cells.get_children(): cells.remove_child(child); child.queue_free()
		var n := int(b["n"])
		var pitch := GRID.size.x / n
		for cell in n * n:
			var button := UI.hit(cells, Rect2(Vector2(cell % n, cell / n) * pitch, Vector2.ONE * pitch), _dig.bind(cell))
			button.name = "fossil_cell_%d" % cell
	board_art.queue_redraw(); slots_art.queue_redraw(); progress_art.queue_redraw()

func _dig(cell: int) -> void:
	if working or _closing or FossilDig.board().is_empty() or FossilDig.cleared(): return
	if cell in FossilDig.board()["dug"]: return
	working = true
	var result: Dictionary = await FossilDig.act("dig", cell)
	if not is_inside_tree() or _closing: return
	working = false
	if result.has("error"):
		G.main.toast(str(result["error"]))
		_refresh()
		return
	var n := int(FossilDig.board()["n"])
	var pitch := GRID.size.x / n
	dust.append({"c": GRID.position + Vector2(cell % n + 0.5, cell / n + 0.5) * pitch, "t": 0.0, "pitch": pitch})
	for p in result.get("found", []):
		var target := _slot_rect(int(p["id"]))
		flies.append({"piece": p, "from": _piece_rect(p), "to": Rect2(target.position + Vector2(10, 0), target.size - Vector2(20, 16)), "t": -0.12})
	Sfx.play("coin" if not result.get("found", []).is_empty() else "pop", 0.95)
	_refresh()

func _primary() -> void:
	if working or _closing or not flies.is_empty(): return
	if FossilDig.board().is_empty():
		working = true
		var response: Dictionary = await FossilDig.act("refresh")
		if not is_inside_tree() or _closing: return
		working = false
		if response.has("error"): G.main.toast(str(response["error"]))
		else: _refresh()
		return
	if not FossilDig.cleared():
		close()
		G.main.show_screen("board", true)
		return
	if FossilDig.finished():
		var ready := FossilDig.ready_rewards()
		if not ready.is_empty(): _preview(int(ready[0]["bones"]))
		return
	working = true
	var result: Dictionary = await FossilDig.act("next")
	if not is_inside_tree() or _closing: return
	working = false
	if result.has("error"): G.main.toast(str(result["error"]))
	else:
		dust.clear()
		board_art.pivot_offset = board_art.size * 0.5
		board_art.scale = Vector2.ONE * 0.94
		create_tween().tween_property(board_art, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_refresh()

func _process(delta: float) -> void:
	if _closing or not is_instance_valid(effects): return
	if flies.is_empty() and dust.is_empty(): return
	for f in flies: f["t"] = float(f["t"]) + delta
	for d in dust: d["t"] = float(d["t"]) + delta
	var before := flies.size()
	flies = flies.filter(func(f): return float(f["t"]) < 0.72)
	dust = dust.filter(func(d): return float(d["t"]) < 0.4)
	effects.queue_redraw()
	if before != flies.size(): _refresh()

func _effects(ci: CanvasItem, _sz: Vector2) -> void:
	for d in dust:
		var t := float(d["t"]) / 0.4
		var c: Vector2 = d["c"]
		for k in 7:
			var a := k * TAU / 7.0
			var p := c + Vector2(cos(a), sin(a)) * t * minf(58, float(d["pitch"]) * 0.36)
			ci.draw_circle(p, (1.0 - t) * 7 + 1, Color(0.61, 0.4, 0.22, 1 - t))
		if t < 0.7: FossilArt.shovel(ci, c + Vector2(10, -18), minf(70, float(d["pitch"]) * 0.65), lerpf(-1.2, 0.3, t))
	for f in flies:
		var t := clampf(float(f["t"]) / 0.72, 0, 1)
		var ease := 1.0 - pow(1.0 - t, 2)
		var start: Rect2 = f["from"]
		var end: Rect2 = f["to"]
		var pos := start.get_center().lerp(end.get_center(), ease) + Vector2(sin(t * PI) * 46, -sin(t * PI) * 90)
		var sz := start.size.lerp(end.size, ease)
		Sprites.at(ci, "ev_disc", pos, minf(1.8, sz.length() / 160.0), 0.0, Color(1, 0.91, 0.55, sin(t * PI) * 0.45))
		FossilArt.piece(ci, Rect2(pos - sz * 0.5, sz), f["piece"])

func _preview(need: int) -> void:
	if working or _closing: return
	var row: Dictionary = {}
	for candidate in FossilDig.config()["milestones"]:
		if int(candidate["bones"]) == need: row = candidate
	if row.is_empty(): return
	var p := PopupBase.new()
	p.name = "fossil_reward_preview"
	Popups.frame(p, Rect2(70, 446, 580, 474), "考古奖励", Color("7b6842"))
	UI.lbl(p.box, "累计挖出 %d 块完整骨头" % need, Rect2(100, 514, 520, 44), 28, Color("785536"))
	var rewards: Array = row["rewards"]
	for i in rewards.size():
		var x := 360.0 + (i - (rewards.size() - 1) * 0.5) * 148
		UI.icon(p.box, str(rewards[i][0]), Vector2(x, 644), 92)
		UI.lbl(p.box, "×%d" % int(rewards[i][1]), Rect2(x - 60, 698, 120, 40), 28, Art.INK)
	var got: bool = need in FossilDig.state().get("claimed", [])
	var ready := int(FossilDig.state().get("recovered", 0)) >= need and not got
	var b := UI.btn(p.box, Rect2(190, 804, 340, 76), "领取" if ready else ("已领取" if got else "进度 %d/%d" % [int(FossilDig.state().get("recovered", 0)), need]), "green" if ready else "grey", Callable(), 32)
	b.name = "fossil_claim_%d" % need
	b.enabled = ready
	b.pressed.connect(func():
		if working: return
		working = true; b.enabled = false
		var result: Dictionary = await FossilDig.act("claim", need)
		if not is_instance_valid(self): return
		working = false
		if result.has("error"):
			G.main.toast(str(result["error"]))
			if is_instance_valid(b): b.enabled = true
		else:
			if is_instance_valid(p): p.close()
			G.main.present_rewards(result.get("rewards", []))
		_refresh())
	G.main._attach_popup(p)

func _instructions() -> void:
	var p := PopupBase.new()
	Popups.frame(p, Rect2(66, 392, 588, 680), "挖掘手记", Color("7b6842"))
	var text := "每实现一个心愿，获得 %d 把铲子。\n\n每点击一格消耗 %d 把铲子，泥土下可能是骨头，也可能是空地。\n\n挖开一块骨头占据的全部格子，骨头就会飞入顶部对应的剪影。\n\n集齐本关骨头即可进入更大的挖掘区。累计收集骨头，点击顶部宝箱领取进度奖励。" % [int(FossilDig.config()["shovels_per_order"]), int(FossilDig.config()["dig_cost"])]
	var label := UI.lbl(p.box, text, Rect2(108, 474, 504, 456), 26, Art.INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.btn(p.box, Rect2(208, 964, 304, 74), "开始考古", "green", p.close, 32)
	G.main._attach_popup(p)
