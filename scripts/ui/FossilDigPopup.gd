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
	UI.box(body, Rect2(56, 168, 608, 1040), _decoration, false)
	var info := UI.btn(body, Rect2(54, 180, 48, 48), "?", "teal", _instructions, 27)
	info.is_round = true
	progress_label = UI.lbl(body, "挖出化石，领取考古奖励", Rect2(116, 184, 488, 40), 26, Color("674930"))
	progress_art = UI.box(body, Rect2(0, 0, 720, 1480), _progress, false)
	for i in FossilDig.config()["milestones"].size():
		var row: Dictionary = FossilDig.config()["milestones"][i]
		var hit := UI.hit(body, Rect2(_reward_x(i) - 44, 232, 88, 96), _preview.bind(int(row["bones"])))
		hit.name = "fossil_reward_%d" % int(row["bones"])
	stage_label = UI.lbl(body, "准备挖掘区…", Rect2(76, 342, 568, 46), 29, Color("60432d"))
	slots_art = UI.box(body, Rect2(0, 0, 720, 1480), _slots, false)
	hint = UI.lbl(body, "点击土块开挖，集齐完整骨头", Rect2(64, 562, 592, 44), 23, Color("7b6347"))
	board_art = UI.box(body, GRID, _board, false)
	cells = Control.new()
	cells.position = GRID.position
	cells.size = GRID.size
	cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(cells)
	UI.box(body, Rect2(106, 1226, 508, 54), func(ci, sz):
		FossilArt.plate(ci, Rect2(Vector2.ZERO, sz), Color("ebd8ad"), Color("c6a574"), 22)
		FossilArt.shovel(ci, Vector2(42, 24), 48)
		var text := "每格消耗 %d 把" % int(FossilDig.config()["dig_cost"])
		ci.draw_string(G.font_body, Vector2(288, 35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("826243")), false)
	count_label = UI.lbl(body, "铲子  0", Rect2(168, 1226, 220, 54), 30, Color("5d422c"), HORIZONTAL_ALIGNMENT_LEFT)
	primary = UI.btn(body, Rect2(164, 1296, 392, 76), "准备中…", "green", _primary, 34)
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
	FossilArt.plate(ci, Rect2(4, 221, 600, 168), Color("d9bf8b"), Color("bd9b66"), 18)
	FossilArt.plate(ci, Rect2(GRID.position - Vector2(56, 168) - Vector2(11, 11), GRID.size + Vector2(22, 22)), Color("725137"), Color("553c2a"), 22)
	# Corner ropes and small field-notebook rivets keep the board in the tribe's material palette.
	for p in [Vector2(14, 233), Vector2(590, 233), Vector2(14, 377), Vector2(590, 377)]:
		ci.draw_circle(p, 5, Color("8c6a42"))

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
	FossilArt.plate(ci, Rect2(68, 266, 584, 20), Color("9f7b4d"), Color("745536"), 10)
	if fill_x > 68: FossilArt.plate(ci, Rect2(68, 266, maxf(5, fill_x - 68), 20), Color("97b35b"), Color("738b43"), 10)
	for i in rows.size():
		var need := int(rows[i]["bones"])
		var got: bool = need in s.get("claimed", [])
		var ready := score >= need and not got
		var x := _reward_x(i)
		ci.draw_circle(Vector2(x, 270), 34, Color("ffdf84") if ready else Color("c4a471"))
		Art.item(ci, "chest_1" if i < rows.size() - 1 else "choice_1", Vector2(x, 265), 65 if ready else 58)
		if got: Paint.check_mark(ci, Vector2(x + 15, 283), 0.7)
		elif not ready: ci.draw_circle(Vector2(x, 265), 24, Color(0.35, 0.24, 0.12, 0.18))
		var text := "已领取" if got else ("领取" if ready else str(need))
		ci.draw_string(G.font_body, Vector2(x - 41, 324), text, HORIZONTAL_ALIGNMENT_CENTER, 82, 22, Color("567139") if ready else Color("785a3c"))

func _slot_rect(i: int) -> Rect2:
	var total: int = FossilDig.board().get("pieces", []).size()
	var rows := 1 if total <= 6 else 2
	var cols := mini(6, total)
	var row := i / cols
	var count := mini(cols, total - row * cols)
	var x := 360.0 + (i % cols - (count - 1) * 0.5) * 94.0
	var y := 464.0 if rows == 1 else 430.0 + row * 82
	return Rect2(x - 42, y - 34, 84, 68)

func _flying(id: int) -> bool:
	return flies.any(func(f): return int(f["piece"]["id"]) == id)

func _slots(ci: CanvasItem, _sz: Vector2) -> void:
	var b := FossilDig.board()
	var pieces: Array = b.get("pieces", [])
	for i in pieces.size():
		var p: Dictionary = pieces[i]
		var r := _slot_rect(i)
		var found := bool(p["found"]) and not _flying(int(p["id"]))
		if found: ci.draw_circle(r.get_center() + Vector2(0, -4), 30, Color(1, 0.91, 0.58, 0.48))
		FossilArt.piece(ci, Rect2(r.position + Vector2(10, 0), r.size - Vector2(20, 16)), p, not found)
		var dim := "%d×%d" % [int(p["w"]), int(p["h"])]
		ci.draw_string(G.font_body, r.position + Vector2(0, 65), dim, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 19, Color("7a5a38"))
		if found: Paint.check_mark(ci, r.position + Vector2(66, 43), 0.38)

func _piece_rect(piece: Dictionary) -> Rect2:
	var pitch := GRID.size.x / int(FossilDig.board()["n"])
	return Rect2(GRID.position + Vector2(int(piece["x"]), int(piece["y"])) * pitch, Vector2(int(piece["w"]), int(piece["h"])) * pitch)

func _board(ci: CanvasItem, sz: Vector2) -> void:
	var b := FossilDig.board()
	if b.is_empty(): return
	var n := int(b["n"])
	var pitch := sz.x / n
	ci.draw_rect(Rect2(Vector2.ZERO, sz), Color("dbc194"))
	for cell in n * n:
		var r := Rect2(Vector2(cell % n, cell / n) * pitch, Vector2.ONE * pitch)
		ci.draw_rect(r.grow(-1), Color("d6bb8e") if cell % 2 else Color("ddc69d"))
		ci.draw_circle(r.get_center() + Vector2(pitch * 0.23, pitch * 0.16), maxf(1, pitch * 0.015), Color("c5a777"))
	for p in b["pieces"]:
		if p["found"]: continue
		var r := _piece_rect(p)
		r.position -= GRID.position
		FossilArt.piece(ci, r, p)
	# Full-cell opaque masks prevent covered bones leaking through tile gaps.
	for cell in n * n:
		if cell in b["dug"]: continue
		FossilArt.dirt(ci, Rect2(Vector2(cell % n, cell / n) * pitch, Vector2.ONE * pitch), cell)

func _refresh() -> void:
	if _closing or not is_instance_valid(primary): return
	var b := FossilDig.board()
	if b.is_empty(): return
	var s := FossilDig.state()
	var sig := str([s, flies.size(), working])
	if sig == signature: return
	signature = sig
	var found: int = b["pieces"].filter(func(p): return bool(p["found"])).size()
	stage_label.text = "第 %d 关 · %d×%d    骨头 %d/%d" % [int(s["stage"]), int(b["n"]), int(b["n"]), found, b["pieces"].size()]
	progress_label.text = "收集进度  %d / %d" % [int(s["recovered"]), int(FossilDig.config()["milestones"][-1]["bones"])]
	count_label.text = "铲子  %d" % int(s["shovels"])
	primary.enabled = not working and flies.is_empty()
	primary.text = "去完成订单"
	if FossilDig.cleared():
		if not flies.is_empty(): primary.text = "化石归位中…"
		elif FossilDig.finished():
			primary.text = "领取进度奖励" if not FossilDig.ready_rewards().is_empty() else "全部挖掘完成"
			primary.enabled = not working and not FossilDig.ready_rewards().is_empty()
		else: primary.text = "下一关 · %d×%d" % [int(b["n"]) + 1, int(b["n"]) + 1]
		hint.text = "本关化石已集齐！" if not FossilDig.finished() else "远古骨骼全部重见天日！"
	elif int(s["shovels"]) < int(FossilDig.config()["dig_cost"]): hint.text = "完成主棋盘订单，每单获得 %d 把铲子" % int(FossilDig.config()["shovels_per_order"])
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
		ci.draw_circle(pos, minf(85, sz.length() * 0.3), Color(1, 0.91, 0.55, sin(t * PI) * 0.25))
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
	var text := "完成主棋盘订单，每单获得 %d 把铲子。\n\n每点击一格消耗 %d 把铲子，泥土下可能是骨头，也可能是空地。\n\n挖开一块骨头占据的全部格子，骨头就会飞入顶部对应的剪影。\n\n集齐本关骨头即可进入更大的挖掘区。累计收集骨头，点击顶部宝箱领取进度奖励。" % [int(FossilDig.config()["shovels_per_order"]), int(FossilDig.config()["dig_cost"])]
	var label := UI.lbl(p.box, text, Rect2(108, 474, 504, 456), 26, Art.INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.btn(p.box, Rect2(208, 964, 304, 74), "开始考古", "green", p.close, 32)
	G.main._attach_popup(p)
