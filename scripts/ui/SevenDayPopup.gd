extends PopupBase
## 七日任务面板。
## 上：成长积分 + 七档阶段奖励轨道（每档一个奖励泡泡，火光沿绳子烧到当前积分；最后一档是大奖）。
## 中：当前页五项任务，可领的排最前、已领的沉到最后；左边的积分牌越难越大越鲜艳。
## 下：七个页签。页签只是「预计第几天能做完」，所有页同时累计、可以提前完成。

const PANEL := Rect2(28, 180, 664, 1200)
const TRACK := Rect2(44, 318, 632, 206)
const RAIL_Y := 150.0
const NODE_X0 := 50.0
const NODE_X1 := 570.0
const ROW_Y := 544.0
const ROW_H := 124.0
const ROW_GAP := 13.0
const TAB_Y := 1256.0
## 积分 → 积分牌的颜色（越难越热）
const TIER := {10: Color("b49c74"), 15: Color("6fae7d"), 20: Color("4fa39a"), 25: Color("e0913a"), 30: Color("d2512d")}

var page := 0
var tasks_root: Control
var tabs: Array = []
var stage_buttons: Array = []
var score: Label
var goal: Label
var rail: DrawBox
var _refresh_pending := false
var _t := 0.0

func _ready() -> void:
	SevenDay.login()
	page = _first_page()
	Popups.frame(self, PANEL, "七日任务", Color("ad6e36"))
	UI.lbl(box, "所有页同时累计，可提前完成 · 每项单独领奖", Rect2(60, 236, 600, 34), 20, Color("8a6a48"))
	UI.box(box, Rect2(60, 274, 600, 50), func(ci, sz):
		Art.item(ci, "xp_1", Vector2(22, 25), 40))
	score = UI.lbl(box, "", Rect2(108, 272, 300, 52), 34, Art.INK, HORIZONTAL_ALIGNMENT_LEFT, 0, Art.INK, true)
	goal = UI.lbl(box, "", Rect2(330, 276, 330, 44), 21, Color("8a5a30"), HORIZONTAL_ALIGNMENT_RIGHT)
	rail = UI.box(box, TRACK, _paint_track, false)
	var stages: Array = SevenDay.config()["milestones"]
	for k in stages.size():
		var stage: Dictionary = stages[k]
		var c := TRACK.position + Vector2(_node_x(k), 70)
		var b := UI.hit(box, Rect2(c - Vector2(42, 48), Vector2(84, 136)), func(): _stage(stage))
		stage_buttons.append([b, stage])
	tasks_root = Control.new()
	tasks_root.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(tasks_root)
	for k in 7:
		var b := UI.btn(box, Rect2(48 + k * 90, TAB_Y, 84, 84), "第%d天" % (k + 1), "hide", func(): page = k; _refresh(), 21)
		tabs.append(b)
	G.seven_day_changed.connect(_schedule_refresh)
	_refresh()

func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(rail): rail.queue_redraw()
	if is_instance_valid(tasks_root):
		for c in tasks_root.get_children():
			if c is DrawBox: c.queue_redraw()

## 打开时先停在有奖可领的那页，其次是第一页还没做完的
func _first_page() -> int:
	for k in 7:
		if SevenDay.ready(k): return k
	for k in 7:
		if not SevenDay.day_done(k): return k
	return 6

func _schedule_refresh() -> void:
	if _refresh_pending: return
	_refresh_pending = true
	_refresh.call_deferred()

func _refresh() -> void:
	_refresh_pending = false
	if not is_instance_valid(score): return
	var stages: Array = SevenDay.config()["milestones"]
	var pts := SevenDay.points()
	score.text = "成长积分 %d" % pts
	goal.text = "全部领完啦！"
	for stage in stages:
		if pts < int(stage["points"]):
			goal.text = "再得 %d 分领下一档" % (int(stage["points"]) - pts)
			break
	rail.queue_redraw()
	for child in tasks_root.get_children():
		tasks_root.remove_child(child)
		child.queue_free()
	var tasks: Array = SevenDay.config()["days"][page]["tasks"].duplicate()
	# 可领 → 进行中 → 已领（同组内保持配置顺序）
	var order := func(t: Dictionary) -> int: return 2 if SevenDay.got(t) else (0 if SevenDay.done(t) else 1)
	var sorted: Array = []
	for rank in 3:
		for t in tasks:
			if order.call(t) == rank: sorted.append(t)
	for k in sorted.size(): _task(sorted[k], ROW_Y + k * (ROW_H + ROW_GAP), k)
	for k in tabs.size():
		var sel := page == k
		tabs[k].style = "teal" if sel else "hide"
		tabs[k].extra = func(ci, sz):
			if SevenDay.day_done(k):
				# 整页领完：盖一层绿 + 大勾
				ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(4, 4), sz - Vector2(8, 8)), 14, 780 + k, 0), Color(Art.MOSS, 0.45))
				ci.draw_circle(Vector2(sz.x - 16, sz.y - 16), 14, Art.INK)
				ci.draw_circle(Vector2(sz.x - 16, sz.y - 16), 12, Art.MOSS_D)
				ci.draw_polyline(PackedVector2Array([Vector2(sz.x - 23, sz.y - 16), Vector2(sz.x - 18, sz.y - 11), Vector2(sz.x - 9, sz.y - 22)]), Color.WHITE, 3.5, true)
			elif SevenDay.ready(k): Paint.badge_num(ci, Vector2(sz.x - 9, 9), 6, 9)
		tabs[k].queue_redraw()

# ---------------------------------------------------------------- 阶段奖励轨道

func _node_x(k: int) -> float:
	var n: int = SevenDay.config()["milestones"].size()
	return lerpf(NODE_X0, NODE_X1, float(k) / float(maxi(1, n - 1)))

## 火光烧到的位置：节点之间按积分分段插值（节点等距，阈值不等距）
func _fill_x(pts: int) -> float:
	var stages: Array = SevenDay.config()["milestones"]
	var prev_p := 0.0
	var prev_x := 14.0
	for k in stages.size():
		var p := float(stages[k]["points"])
		var x := _node_x(k)
		if pts < p: return lerpf(prev_x, x, (pts - prev_p) / (p - prev_p))
		prev_p = p
		prev_x = x
	return TRACK.size.x - 14.0

func _paint_track(ci: CanvasItem, sz: Vector2) -> void:
	# 皮子底板
	Sprites.draw(ci, "ev_sd_track", Rect2(Vector2.ZERO, sz))
	var stages: Array = SevenDay.config()["milestones"]
	var pts := SevenDay.points()
	# 绳子轨道 + 火光填充
	var fx := _fill_x(pts)
	Paint.bar(ci, Rect2(14, RAIL_Y - 13, sz.x - 28, 26), (fx - 14.0) / (sz.x - 28.0), Color("ffb02e"), 713)
	if pts > 0 and fx < sz.x - 20:
		Sprites.draw(ci, "ev_sd_flame", Rect2(fx - 15, RAIL_Y - 34, 30, 40))
	for k in stages.size():
		var st: Dictionary = stages[k]
		var x := _node_x(k)
		var reached := pts >= int(st["points"])
		var got := SevenDay.stage_got(st)
		var ready := reached and not got
		var grand := bool(st.get("grand", false))
		# 轨道上的积分石
		Sprites.draw(ci, "ev_sd_stone_on" if reached else "ev_sd_stone_off", Rect2(x - 24, RAIL_Y - 22, 48, 44))
		var label := str(int(st["points"]))
		var f: Font = G.font_title
		var fs := 18 if label.length() < 3 else 16
		var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_string_outline(f, Vector2(x - tw * 0.5, RAIL_Y + 7), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color.WHITE if reached else Color("f3ecdc"))
		ci.draw_string(f, Vector2(x - tw * 0.5, RAIL_Y + 7), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.INK)
		# 泡泡和积分石之间的挂绳
		Sprites.draw(ci, "ev_sd_rope", Rect2(x - 3, 98, 6, 30))
		# 奖励泡泡：可领的上下跳、外圈发光；已领的变灰打勾；大奖更大、带光芒
		var lift := sin(_t * 5.0 + k) * 4.0 if ready else 0.0
		var c := Vector2(x, 62 + lift)
		var rad := 40.0 if grand else 32.0
		if grand:
			for j in 12:
				var a := _t * 0.6 + TAU * j / 12.0
				var ray := PackedVector2Array([c + Vector2(cos(a - 0.12), sin(a - 0.12)) * (rad + 4), c + Vector2(cos(a), sin(a)) * (rad + 22), c + Vector2(cos(a + 0.12), sin(a + 0.12)) * (rad + 4)])
				ci.draw_colored_polygon(ray, Color(1.0, 0.82, 0.3, 0.55 if not got else 0.2))
		if ready:
			var glow := 0.35 + 0.2 * sin(_t * 6.0)
			ci.draw_circle(c, rad + 10, Color(1.0, 0.85, 0.35, glow))
		var rw: Array = st["rewards"][0]
		Paint.reward_bubble(ci, c, rad, str(st.get("icon", rw[0])), int(rw[1]), 730 + k)
		if st["rewards"].size() > 1:
			_more(ci, c + Vector2(rad * 0.78, -rad * 0.62), st["rewards"].size() - 1)
		if got:
			ci.draw_circle(c, rad, Color(0.95, 0.92, 0.85, 0.6))
			Paint.check_mark(ci, c + Vector2(0, 4), 0.8)
		elif ready:
			Paint.badge_num(ci, c + Vector2(-rad * 0.72, -rad * 0.7), 740 + k, 9)
		if grand:
			var rib := Rect2(c.x - 30, c.y + rad - 6, 60, 24)
			Sprites.draw(ci, "ev_sd_grand_rib", rib)
			EventEntryArt.text(ci, "大奖", Vector2(c.x, rib.position.y + 19), 17, Color.WHITE, 4)

## 「+1」小角标：这一档不止一样奖励
func _more(ci: CanvasItem, c: Vector2, n: int) -> void:
	Sprites.draw(ci, "ev_sd_more", Rect2(c - Vector2(13, 11), Vector2(26, 22)))
	EventEntryArt.text(ci, "+%d" % n, c + Vector2(0, 6), 15, Color.WHITE, 3)

# ---------------------------------------------------------------- 任务行

func _task(task: Dictionary, y: float, k: int) -> void:
	var claimed := SevenDay.got(task)
	var done := SevenDay.done(task)
	var pts := int(task["points"])
	var target := int(task["target"])
	var current := mini(SevenDay.value(task), target)
	var paid := str(task["metric"]) == "paid_cents"
	var progress := "%d/%d" % [current, target]
	if paid: progress = "¥%d/%d" % [current / 100, target / 100]
	var tier_key: int = pts if TIER.has(pts) else (30 if pts > 30 else 10)
	var ready := done and not claimed
	UI.box(tasks_root, Rect2(48, y, 624, ROW_H), func(ci, sz):
		if ready:
			# 可领：外圈呼吸金光 + 亮黄底 + 绿描边
			var glow := 0.35 + 0.25 * sin(_t * 5.0 + k)
			Sprites.draw(ci, "ev_sd_row_glow", Rect2(Vector2.ZERO, sz), Color(1.0, 0.82, 0.25, glow))
		Sprites.draw(ci, "ev_sd_row_" + ("claimed" if claimed else ("ready" if ready else "idle")), Rect2(Vector2.ZERO, sz))
		# 积分牌：一块石头挂牌，越难颜色越热；已领变灰
		Sprites.draw(ci, "ev_sd_tag_claimed" if claimed else "ev_sd_tag_%d" % tier_key, Rect2(Vector2(16, sz.y * 0.5 - 42), Vector2(80, 84)))
		EventEntryArt.text(ci, str(pts), Vector2(56, sz.y * 0.5 + 6), 32, Color.WHITE, 6)
		EventEntryArt.text(ci, "积分", Vector2(56, sz.y * 0.5 + 30), 15, Color.WHITE, 4)
		# 进度条
		var bar := Rect2(112, 70, 196, 30)
		var pfs := 18 if progress.length() <= 7 else 16
		Paint.bar(ci, bar, float(current) / float(maxi(1, target)), Color("b5ad9c") if claimed else (Art.MOSS if done else Color("ffb02e")), 734 + k)
		EventEntryArt.text(ci, progress, bar.get_center() + Vector2(0, 6), pfs, Color.WHITE, 4)
		# 奖励泡泡
		var rewards: Array = task["rewards"]
		for j in rewards.size():
			var c := Vector2(352 + j * 72, sz.y * 0.5 + 2)
			Paint.reward_bubble(ci, c, 31, str(rewards[j][0]), int(rewards[j][1]), 740 + k * 3 + j)
			if claimed: ci.draw_circle(c, 32, Color(0.85, 0.83, 0.78, 0.65))
		if claimed:
			# 已领：整行压灰，右侧绿色大勾 + 「已领取」
			ci.draw_circle(Vector2(560, sz.y * 0.5 - 8), 26, Art.INK)
			ci.draw_circle(Vector2(560, sz.y * 0.5 - 8), 23, Art.MOSS_D)
			ci.draw_polyline(PackedVector2Array([Vector2(548, sz.y * 0.5 - 8), Vector2(557, sz.y * 0.5 + 1), Vector2(573, sz.y * 0.5 - 18)]), Color.WHITE, 5, true)
			EventEntryArt.text(ci, "已领取", Vector2(560, sz.y * 0.5 + 40), 20, Color("7a7264"), 0)
		elif ready:
			# 「可领取」角标
			var rib := Rect2(sz.x - 118, -12, 96, 30)
			Sprites.draw(ci, "ev_sd_ready_rib", rib)
			EventEntryArt.text(ci, "可领取", rib.get_center() + Vector2(0, 7), 18, Color.WHITE, 4))
	UI.lbl(tasks_root, str(task["title"]), Rect2(160, y + 12, 330, 44), 25, Color("8a7a66") if claimed else Art.INK, HORIZONTAL_ALIGNMENT_LEFT, 0, Art.INK, true)
	if claimed: return
	if not done:
		UI.box(tasks_root, Rect2(530, y + 34, 128, 56), func(ci, sz):
			Sprites.draw(ci, "ev_sd_wip", Rect2(Vector2.ZERO, sz))
			EventEntryArt.text(ci, "进行中", Vector2(sz.x * 0.5, sz.y * 0.5 + 8), 22, Color("9a8a70"), 0), false)
		return
	var b := UI.btn(tasks_root, Rect2(526, y + 28, 136, 70), "领取", "green", func(): _claim(str(task["id"]), false), 28)
	b.enabled = true

func _claim(id: String, stage: bool) -> void:
	var result := await SevenDay.claim(id, stage)
	if result.has("error") and str(result["error"]) != "": G.main.toast(str(result["error"]))
	if is_instance_valid(self): _refresh()

# ---------------------------------------------------------------- 阶段详情

func _stage(stage: Dictionary) -> void:
	if SevenDay.stage_ready(stage):
		_claim(str(stage["id"]), true)
		return
	var p := PopupBase.new()
	var grand := bool(stage.get("grand", false))
	Popups.frame(p, Rect2(80, 470, 560, 520), str(stage.get("title", "阶段奖励")), Art.CLAY if grand else Art.TEAL)
	var got := SevenDay.stage_got(stage)
	var line := "已领取" if got else "累计 %d 积分可领（还差 %d）" % [int(stage["points"]), int(stage["points"]) - SevenDay.points()]
	UI.lbl(p.box, line, Rect2(110, 545, 500, 46), 25, Color("8a5a30"))
	var rewards: Array = stage["rewards"]
	UI.box(p.box, Rect2(80, 600, 560, 220), func(ci, sz):
		for k in rewards.size():
			var x: float = sz.x * 0.5 + (k - (rewards.size() - 1) / 2.0) * 150
			Paint.reward_bubble(ci, Vector2(x, 96), 58, str(rewards[k][0]), 0, 770 + k)
			EventEntryArt.text(ci, "×%d" % int(rewards[k][1]), Vector2(x, 190), 28, Color.WHITE, 6))
	UI.btn(p.box, Rect2(230, 860, 260, 76), "知道了", "teal", p.close, 28)
	G.main._attach_popup(p)
