extends PopupBase
const Meme := preload("res://scripts/Meme.gd")
const MemeSprites := preload("res://scripts/sprites/meme.gd")
const GAP := 178.0
var path: Scroller
var trail: DrawBox
var runners: DrawBox
var title: Label
var cohort_label: Label
var clock_label: Label
var stage_label: Label
var score_label: Label
var status_label: Label
var action_button: TButton
var signature := ""
var count := 10
var visual_stage := 0.0
var elapsed := 0.0
var working := false
var focused_round := -1
var focused_stage := -1
var focus_tween: Tween
var attack_active := false
var attack_node := -1
var attack_time := 0.0
var attack_duration := 1.15

func _ready() -> void:
	set_meta("fullscreen", true)
	dim_alpha = 0.92
	count = TigerEscape.config()["stages"].size()
	UI.box(box, Rect2(0, 0, 720, 1480), _background, false)
	title = UI.title(box, TextCatalog.source("ui.tigerescapepopup.4d795b5b190d"), Rect2(82, 105, 556, 82), 57, Color("ffda76"))
	var info := UI.btn(box, Rect2(28, 117, 50, 50), "?", "teal", _instructions, 28)
	info.is_round = true
	UI.box(box, Rect2(34, 204, 652, 243), _header, false)
	stage_label = UI.lbl(box, "", Rect2(48, 222, 170, 83), 27, Color("fff2ce"), HORIZONTAL_ALIGNMENT_CENTER, 5, Art.WOOD_D)
	clock_label = UI.lbl(box, "", Rect2(460, 225, 208, 80), 26, Color("ffe3a1"), HORIZONTAL_ALIGNMENT_CENTER, 5, Art.WOOD_D)
	cohort_label = UI.lbl(box, "", Rect2(43, 316, 192, 42), 21, Color("ffe3a1"), HORIZONTAL_ALIGNMENT_CENTER, 5, Art.WOOD_D)
	status_label = UI.lbl(box, TextCatalog.source("ui.tigerescapepopup.f00b5535bc10"), Rect2(62, 371, 596, 50), 30, Color("ffecc2"), HORIZONTAL_ALIGNMENT_CENTER, 6, Art.WOOD_D)
	path = Scroller.new()
	path.position = Vector2(20, 466)
	path.size = Vector2(680, 766)
	box.add_child(path)
	path.set_length((count + 1) * GAP + 240)
	trail = UI.box(path.content, Rect2(Vector2.ZERO, path.content.size), _trail, false)
	for n in range(1, count + 1):
		var at := _node_pos(n)
		var hit := UI.hit(path.content, Rect2(at - Vector2(78, 92), Vector2(156, 166)), func(): _preview(n))
		hit.name = "tiger_node_%d" % n
	runners = UI.box(path.content, Rect2(Vector2.ZERO, path.content.size), _runners, false)
	score_label = UI.lbl(box, "", Rect2(100, 1244, 520, 40), 27, Color("ffe5a0"), HORIZONTAL_ALIGNMENT_CENTER, 5, Art.WOOD_D)
	action_button = UI.btn(box, Rect2(150, 1302, 420, 100), TextCatalog.source("ui.tigerescapepopup.b594fa791878"), "green", _primary, 40)
	action_button.name = "tiger_primary"
	UI.box(box, Rect2(22, 1260, 110, 115), func(ci, sz): TigerArt.draw(ci, sz * 0.5, 82), false)
	UI.lbl(box, TextCatalog.fill(TextCatalog.source("ui.tigerescapepopup.c5d9596cdc4e"), int(TigerEscape.config()["points_per_order"])), Rect2(130, 1418, 460, 35), 23, Color("bbceb1"))
	visual_stage = float(TigerEscape.round_state().get("stage", 0))
	_refresh(true)
	if Cloud.can_talk() and not TigerEscape.round_state().is_empty():
		TigerEscape.refresh_from_server()

func _process(delta: float) -> void:
	if _closing: return
	if attack_active:
		attack_time += delta
		trail.queue_redraw()
		runners.queue_redraw()
		if attack_time >= attack_duration:
			attack_active = false
			TigerEscape.acknowledge_attack(TigerEscape.round_state(), attack_node)
			_focus(int(TigerEscape.round_state().get("stage", 0)), true)
		_refresh()
	elapsed += delta
	var m := TigerEscape.round_state()
	var target := float(m.get("stage", 0))
	if absf(target - visual_stage) > 0.01:
		visual_stage = move_toward(visual_stage, target, delta * 4.5)
		runners.queue_redraw()
	if elapsed >= 0.25:
		elapsed = 0
		_refresh()
		runners.queue_redraw()

func _node_pos(n: int) -> Vector2:
	return Vector2(210 if n % 2 == 0 else 478, (count - n) * GAP + 190)

func _focus(stage: int, animate: bool) -> void:
	var dest := clampf(_node_pos(stage).y - 500, 0, path._max())
	if focus_tween != null and focus_tween.is_valid(): focus_tween.kill()
	path.jump_to(path.offset)
	if animate:
		focus_tween = create_tween()
		focus_tween.tween_property(path, "offset", dest, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else: path.jump_to(dest)

func _refresh(first := false) -> void:
	var m := TigerEscape.round_state()
	var stage := int(m.get("stage", 0))
	var status := str(m.get("status", "idle"))
	if not m.is_empty() and int(m.get("destroyed", -1)) > TigerEscape.seen_attack(m) and not attack_active:
		attack_node = int(m["destroyed"])
		attack_time = 0
		attack_active = true
		_focus(attack_node, not first)
	if attack_active: status = "attacking"
	cohort_label.text = TextCatalog.resolve(TextCatalog.fill(TextCatalog.source("ui.tigerescapepopup.57bfcf49487f"), [TigerEscape.survivors(m), TigerEscape.player_count(m)]))
	stage_label.text = TextCatalog.resolve(TextCatalog.fill(TextCatalog.source("ui.tigerescapepopup.68a50bbc84e2"), [stage, count]))
	clock_label.text = TextCatalog.resolve(TextCatalog.fill(TextCatalog.source("ui.tigerescapepopup.edc4bd8226a5"), [TigerEscape.stage_remaining(m), TigerEscape.stage_quota(m)]) if status == "running" else TextCatalog.source("ui.tigerescapepopup.422bc1b9ceb0"))
	if status == "won": clock_label.text = TextCatalog.resolve(TextCatalog.source("ui.tigerescapepopup.630a53f031a3"))
	elif status == "lost": clock_label.text = TextCatalog.resolve(TextCatalog.source("ui.tigerescapepopup.3fe387e551de"))
	if attack_active: clock_label.text = TextCatalog.resolve(TextCatalog.source("ui.tigerescapepopup.96394ca97644"))
	clock_label.modulate = Color("ff9585") if status == "running" and TigerEscape.stage_remaining(m) <= 10 else Color.WHITE
	var rows: Array = m.get("stages", TigerEscape.config()["stages"])
	var need := int(rows[mini(stage, count - 1)]["points"])
	score_label.text = TextCatalog.resolve(TextCatalog.fill(TextCatalog.source("ui.tigerescapepopup.cf517f7ce05b"), [int(m.get("points", 0)), need]) if status == "running" else TextCatalog.source("ui.tigerescapepopup.8dbac4d2006c"))
	status_label.text = TextCatalog.resolve({"idle": TextCatalog.source("ui.tigerescapepopup.f00b5535bc10"), "running": TextCatalog.source("ui.tigerescapepopup.d7610459bccc"), "won": TextCatalog.source("ui.tigerescapepopup.21a23652518d"), "lost": TextCatalog.source("ui.tigerescapepopup.8674cad15875"), "attacking": TextCatalog.source("ui.tigerescapepopup.c9ebb2f8db71")}.get(status, ""))
	action_button.text = TextCatalog.resolve({"idle": TextCatalog.source("ui.tigerescapepopup.b594fa791878"), "running": TextCatalog.source("ui.duelpopup.245ede446986"), "won": TextCatalog.source("ui.tigerescapepopup.0b14b6a80994"), "lost": TextCatalog.source("ui.tigerescapepopup.465801b6c612"), "attacking": TextCatalog.source("ui.tigerescapepopup.4eff1498c0b5")}.get(status, TextCatalog.source("ui.tigerescapepopup.b594fa791878")))
	if status in ["won", "lost"]:
		score_label.text = TextCatalog.resolve(TextCatalog.fill(TextCatalog.source("ui.tigerescapepopup.0c3999c12dd3"), stage))
		action_button.text = TextCatalog.resolve(TextCatalog.source("ui.tigerescapepopup.0b14b6a80994") if not TigerEscape.pending_rewards(m).is_empty() else TextCatalog.source("ui.tigerescapepopup.465801b6c612"))
	action_button.style = "orange" if status == "lost" else "green"
	action_button.enabled = not working and not attack_active
	action_button.queue_redraw()
	var sig := str([m.get("id", 0), stage, status, m.get("destroyed", -1), m.get("claimed", [])])
	if sig != signature:
		signature = sig
		trail.queue_redraw()
		if not attack_active and (first or stage != focused_stage or int(m.get("id", 0)) != focused_round):
			_focus(stage, not first)
			focused_stage = stage
			focused_round = int(m.get("id", 0))

func _primary() -> void:
	if working or attack_active: return
	var m := TigerEscape.round_state()
	if m.get("status", "") == "running":
		close()
		G.main.show_screen("board", true)
		return
	working = true
	var result: Dictionary = await TigerEscape.act("join" if m.is_empty() else "restart")
	if not result.has("error") and Cloud.can_talk():
		await TigerEscape.sync_join_server()
	working = false
	if not is_inside_tree() or _closing: return
	if result.has("error"): G.main.toast(str(result["error"]))
	else:
		visual_stage = 0
		_focus(0, false)
		if not result.get("rewards", []).is_empty(): G.main.present_rewards(result["rewards"])
	_refresh(true)

func _preview(n: int) -> void:
	if working or _closing or attack_active: return
	var m := TigerEscape.round_state()
	var rows: Array = m.get("stages", TigerEscape.config()["stages"])
	var rewards: Array = rows[n - 1]["rewards"]
	var reached := n <= int(m.get("stage", 0))
	var claimed: bool = n in m.get("claimed", [])
	var p := PopupBase.new()
	Popups.frame(p, Rect2(80, 460, 560, 460), TextCatalog.fill(TextCatalog.source("ui.tigerescapepopup.3fea10c89e10"), n), Art.OCHRE)
	for k in rewards.size():
		var x := 360.0 + (k - (rewards.size() - 1) * 0.5) * 145
		UI.icon(p.box, str(rewards[k][0]), Vector2(x, 640), 90)
		UI.lbl(p.box, "×%d" % int(rewards[k][1]), Rect2(x - 55, 695, 110, 44), 28, Art.INK)
	var label := TextCatalog.source("ui.duelpopup.844ab9477225") if reached and not claimed else (TextCatalog.source("notice.sevenday.426e458a4124") if claimed else TextCatalog.source("ui.tigerescapepopup.724a5ac4c63d"))
	var b := UI.btn(p.box, Rect2(195, 794, 330, 76), label, "green" if reached and not claimed else "grey", Callable(), 32)
	b.enabled = reached and not claimed
	b.pressed.connect(func():
		if working: return
		working = true
		b.enabled = false
		var result: Dictionary = await TigerEscape.act("claim", n)
		working = false
		if not is_instance_valid(self): return
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
	Popups.frame(p, Rect2(68, 400, 584, 610), TextCatalog.source("ui.tigerescapepopup.f92098f45c5a"), Art.OCHRE)
	var text := TextCatalog.source("ui.tigerescapepopup.66b9b632537c")
	var label := UI.lbl(p.box, text, Rect2(108, 508, 504, 390), 26, Art.INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.btn(p.box, Rect2(225, 914, 270, 64), TextCatalog.source("ui.tigerescapepopup.e2508646d82f"), "green", p.close, 30)
	G.main._attach_popup(p)

func _background(ci: CanvasItem, sz: Vector2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, sz), Color("203e35"))
	for k in 8:
		var x := k * 112.0 - 40
		var color := Color("2a5042") if k % 2 else Color("315a45")
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 32, 0), Vector2(x + 75, 1480), Vector2(x - 24, 1480)]), color)
	for side in [-1, 1]:
		for k in 9:
			var center := Vector2(24 if side < 0 else 696, 440 + k * 114)
			Sprites.at(ci, "tiger_bush", center, 1.0, side * 0.7)
	ci.draw_rect(Rect2(0, 1232, 720, 248), Color("203e35"))

func _header(ci: CanvasItem, sz: Vector2) -> void:
	Sprites.draw(ci, "tiger_header", Rect2(Vector2.ZERO, sz))
	Art.item(ci, "choice_1", Vector2(326, 98), 132)
	Art.item(ci, "fire_4", Vector2(248, 139), 73)
	Art.item(ci, "amber_4", Vector2(407, 139), 70)

func _trail(ci: CanvasItem, _sz: Vector2) -> void:
	var m := TigerEscape.round_state()
	var stage := int(m.get("stage", 0))
	var destroyed := attack_node - 1 if attack_active and attack_time / attack_duration < 0.62 else int(m.get("destroyed", -1))
	for n in range(count):
		var from := _node_pos(n)
		var to := _node_pos(n + 1)
		for k in range(1, 7):
			var at := from.lerp(to, k / 7.0)
			ci.draw_circle(at, 3, Color("d3bf7c") if n >= destroyed else Color("4a5241"))
	for n in range(count + 1):
		var at := _node_pos(n)
		if attack_active and n == attack_node: at.x += sin(attack_time * 80) * 5
		var gone := n <= destroyed
		if gone:
			for j in 4:
				var fragment := at + Vector2((j - 1.5) * 37, (j % 2) * 22)
				Sprites.at(ci, "tiger_frag", fragment, 1.0, j * 0.4)
			EventEntryArt.text(ci, TextCatalog.source("ui.tigerescapepopup.01369dbca918"), at + Vector2(0, 62), 21, Color("c88369"), 3)
			continue
		Sprites.at(ci, "tiger_node", at + MemeSprites.NODE_BOX.get_center())
		if n > 0:
			var claimed: bool = n in m.get("claimed", [])
			if not claimed and n != stage:
				Paint.gift(ci, at + Vector2(0, -42), 96 if n == count else 78)
			if n <= stage and not claimed:
				ci.draw_circle(at + Vector2(65, -42), 13, Art.MOSS)
				EventEntryArt.text(ci, "!", at + Vector2(65, -34), 23, Color.WHITE, 3)
			EventEntryArt.text(ci, "%d  %s" % [n, TextCatalog.source("notice.sevenday.426e458a4124") if claimed else TextCatalog.source("ui.tigerescapepopup.43d137967524")], at + Vector2(0, 62), 22, Color("fff0c7"), 4)
		else: EventEntryArt.text(ci, TextCatalog.source("ui.tigerescapepopup.d7622e6c7bb0"), at + Vector2(0, 62), 22, Color("fff0c7"), 4)

func _runners(ci: CanvasItem, _sz: Vector2) -> void:
	var m := TigerEscape.round_state()
	var stage := int(m.get("stage", 0))
	var phase := clampf(attack_time / attack_duration, 0, 1) if attack_active else 0.0
	for node in range(count + 1):
		var group: Array = []
		for bot in m.get("bots", []):
			if int(bot["stage"]) == node and (bot["status"] != "lost" or (attack_active and node == attack_node)):
				group.append(bot)
		var shown := mini(group.size(), 4)
		for j in shown:
			var pos := _node_pos(node) + Vector2((j - (shown - 1) * 0.5) * 38, -66 if node != stage else -110)
			var scale := 1.0 - clampf((phase - 0.42) / 0.35, 0, 1) if attack_active and node == attack_node else 1.0
			if scale > 0.01:
				Meme.portrait(ci, int(group[j]["avatar"]), pos, 43 * scale)
				EventEntryArt.text(ci, str(group[j]["name"]), pos + Vector2(0, 35), 15, Color("e5e6c4"), 3)
		if group.size() > shown: EventEntryArt.text(ci, "+%d" % (group.size() - shown), _node_pos(node) + Vector2(80, -62), 19, Color("fff0c7"), 4)
	var low := clampi(int(floor(visual_stage)), 0, count)
	var high := mini(low + 1, count)
	var progress := visual_stage - low
	var at := _node_pos(low).lerp(_node_pos(high), progress)
	at.y -= sin(progress * PI) * 90
	var eaten: bool = attack_active and stage == attack_node and m.get("status", "") == "lost"
	var hero_scale := 1.0 - clampf((phase - 0.42) / 0.35, 0, 1) if eaten else 1.0
	if hero_scale > 0.01 and not (m.get("status", "") == "lost" and not attack_active):
		Meme.portrait(ci, Meme.HERO, at + Vector2(0, -58), 102 * hero_scale)
		EventEntryArt.text(ci, TextCatalog.source("ui.duelpopup.a0c7716669b5"), at + Vector2(0, -9), 21, Color("ffdb71"), 4)
	if m.get("status", "") == "running" and not attack_active:
		var need := int(m["stages"][stage]["points"])
		Paint.bar(ci, Rect2(at + Vector2(-77, -7), Vector2(154, 20)), float(m["points"]) / need, Art.MOSS)
		EventEntryArt.text(ci, "%d/%d" % [int(m["points"]), need], at + Vector2(0, 10), 20, Color.WHITE, 4)
	var tiger_node := clampi(mini(stage, int(m.get("destroyed", -1)) + 1), 0, count)
	var tiger_at := _node_pos(tiger_node) + Vector2(-137, 60)
	if attack_active:
		var target := _node_pos(attack_node) + Vector2(0, -38)
		var jump := clampf(phase / 0.5, 0, 1)
		tiger_at = (target + Vector2(-155, 108)).lerp(target, 1.0 - pow(1.0 - jump, 2))
		tiger_at.y -= sin(jump * PI) * 95
		if phase > 0.45: tiger_at += Vector2(sin(phase * 90) * 6, sin(phase * 68) * 4)
		if phase > 0.6:
			for k in 8:
				var angle := k * TAU / 8
				var burst := target + Vector2.from_angle(angle) * (phase - 0.6) * 180
				ci.draw_circle(burst, maxf(1, (1 - phase) * 12), Color("c5a46a"))
	TigerArt.draw(ci, tiger_at, 103 * (1.0 + sin(phase * PI) * 0.3))
