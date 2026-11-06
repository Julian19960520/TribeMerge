extends PopupBase
## 月石遗迹活动面板：月夜遗迹背景；顶部是带里程碑宝箱的探索进度；中间是活动棋盘；
## 底部是 8 件遗物陈列、积分气泡（点一下投放 1 件月石碎片）、积分来源说明与选中物品信息。
var cfg: Dictionary
var period_key := ""
var board: MergeEventBoard
var progress: Label
var timer: Label
var points: Label
var selection: Label
var selection_hint: Label
var spawn_btn: TButton
var claim_btn: TButton
var collection: DrawBox
var track: DrawBox
var earn: DrawBox
var info: DrawBox
var fx: Fx
var _clock := 0.0
var _t := 0.0
var _info_id := ""
var _known: Dictionary = {}
var _node_x: Array = []

const INK := Color("3b2314")
const CREAM := Color("fff3c4")
const PANEL := Rect2(28, 174, 664, 1216)
const SCENE := Rect2(44, 192, 632, 1180)
const TRACK := Rect2(56, 266, 608, 138)
const BAR := Rect2(92, 338, 508, 20)
const SHELF := Rect2(56, 1106, 608, 74)
const BUBBLE := Vector2(360, 1268)

func _ready() -> void:
	cfg = MergeEvent.definition(period_key) if period_key != "" else MergeEvent.current()
	if not MergeEvent.available(cfg):
		G.main.toast("活动尚未开始")
		close()
		return
	_known = MergeEvent.state(cfg)["discovered"].duplicate()
	_build()
	G.merge_event_changed.connect(_refresh)
	_refresh()

func _c(key: String, fallback: String) -> Color:
	return Color(str(cfg["theme"].get(key, fallback)))

func _build() -> void:
	Popups.frame(self, PANEL, str(cfg["title"]), _c("banner", "2f6377"), "")
	var scene := UI.box(box, SCENE, _paint_scene)
	box.move_child(scene, 1)
	# 背景盖住了横幅下沿：在背景之上、标题文字之下再画一次横幅。
	var br := Rect2(PANEL.get_center().x - 180, PANEL.position.y - 34, 360, 78)
	var banner := UI.box(box, br.grow(8), func(ci, sz): Paint.banner(ci, Rect2(Vector2(8, 8), sz - Vector2(16, 16)), _c("banner", "2f6377")))
	box.move_child(banner, 2)
	UI.box(box, Rect2(214, 224, 292, 36), func(ci, sz):
		var pill := Art.rrect(Rect2(Vector2.ZERO, sz), sz.y / 2, 51, 0.4)
		Art.fill(ci, pill, Color(0.05, 0.12, 0.16, 0.75), 2.0, Color(_c("glow", "bff3f0"), 0.35))
		Paint.glyph(ci, "clock", Vector2(24, sz.y / 2), 0.9))
	timer = UI.lbl(box, "", Rect2(244, 224, 256, 36), 20, Color("d6f3ef"))
	_build_track()
	_build_board()
	_build_bottom()
	fx = Fx.new()
	fx.cfg = cfg
	box.add_child(fx)
	board.fx = fx.add
	board.spawn_origin = BUBBLE

# ---------------------------------------------------------------- 顶部：探索进度与里程碑

func _build_track() -> void:
	track = UI.box(box, TRACK, _paint_track)
	UI.lbl(box, "遗迹探索", Rect2(TRACK.position.x + 22, TRACK.position.y + 8, 200, 34), 24, CREAM, HORIZONTAL_ALIGNMENT_LEFT, 0, INK, true)
	progress = UI.lbl(box, "", Rect2(TRACK.end.x - 250, TRACK.position.y + 8, 228, 34), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 5, INK, true)
	var ms := MergeEvent.milestones(cfg)
	var total := float(MergeEvent.goal_total(cfg))
	for k in ms.size():
		var x := BAR.position.x + BAR.size.x * minf(1.0, float(ms[k]["at"]) / total)
		_node_x.append(x)
		var r := 40.0 if k == ms.size() - 1 else 32.0
		var b := UI.hit(box, Rect2(x - r - 6, BAR.get_center().y - r - 6, r * 2 + 12, r * 2 + 30), _tap_node.bind(k))
		if k == ms.size() - 1:
			claim_btn = b
			claim_btn.name = "event_completion_reward"

func _paint_track(ci: CanvasItem, sz: Vector2) -> void:
	var s := MergeEvent.state(cfg)
	var base := Art.rrect(Rect2(Vector2.ZERO, sz), 20, 404, 0.6)
	ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(0, 6), sz), 20, 405, 0.0), Color(0, 0, 0, 0.3))
	Art.dilate(ci, base, 3.0, INK)
	ci.draw_colored_polygon(base, Color("24404a"))
	ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(6, 6), Vector2(sz.x - 12, sz.y * 0.42)), 15, 406, 0.3), Color(1, 1, 1, 0.05))
	Art.dashed(ci, Art.rrect(Rect2(Vector2(7, 7), sz - Vector2(14, 14)), 15, 407, 0.0), 10, 7, Color(_c("glow", "bff3f0"), 0.28), 2.0)
	var o := TRACK.position
	var bar := Rect2(BAR.position - o, BAR.size)
	var total := float(MergeEvent.goal_total(cfg))
	var frac := clampf(float(MergeEvent.progress(cfg, s)) / total, 0.0, 1.0)
	var groove := Art.rrect(bar, bar.size.y / 2, 408, 0.3)
	Art.dilate(ci, groove, 3.0, INK)
	ci.draw_colored_polygon(groove, Color("10232a"))
	if frac > 0.0:
		var fill := Rect2(bar.position, Vector2(maxf(bar.size.y, bar.size.x * frac), bar.size.y))
		ci.draw_colored_polygon(Art.rrect(fill, bar.size.y / 2, 409, 0.2), _c("accent", "8cdece"))
		ci.draw_colored_polygon(Art.rrect(Rect2(fill.position + Vector2(6, 3), Vector2(fill.size.x - 12, 6)), 3, 410, 0.0), Color(1, 1, 1, 0.5))
		var shine := fmod(_t * 0.35, 1.0) * fill.size.x
		ci.draw_circle(fill.position + Vector2(shine, fill.size.y / 2), 6, Color(1, 1, 1, 0.35))
	var ms := MergeEvent.milestones(cfg)
	var have := MergeEvent.got(cfg, s)
	var ready := MergeEvent.claimable(cfg, s)
	for k in ms.size():
		var last := k == ms.size() - 1
		var r := 36.0 if last else 28.0
		var c := Vector2(float(_node_x[k]) - o.x, bar.get_center().y)
		var state := 2 if have.has(k) else (1 if ready.has(k) else 0)
		if state == 1:
			c.y -= absf(sin(_t * 4.0)) * 6.0
			ci.draw_circle(c, r + 12 + 3 * sin(_t * 6.0), Color(1, 0.93, 0.55, 0.28))
		var disc := Art.ell(c, Vector2(r, r), 420 + k, 0.03, 22)
		Art.dilate(ci, disc, 3.0, INK)
		ci.draw_colored_polygon(disc, Color("f2c14e") if state == 1 else (Color("3d6a6f") if state == 2 else Color("2e5058")))
		ci.draw_colored_polygon(Art.ell(c + Vector2(0, 3), Vector2(r - 6, r - 7), 430 + k, 0.03, 20), Color(0, 0, 0, 0.18))
		Art.item(ci, _featured(ms[k]["rewards"]), c, r * (1.55 if last else 1.45))
		if state == 2:
			ci.draw_circle(c, r - 2, Color(0.1, 0.2, 0.22, 0.45))
			Paint.check_mark(ci, c + Vector2(r * 0.45, r * 0.45), 0.9)
		var tag := "领取" if state == 1 else ("通关" if last else "%d格" % int(ms[k]["at"]))
		if str(cfg["board"].get("goal", "")) == "discover_all" and not last and state != 1: tag = "%d件" % int(ms[k]["at"])
		var tw := 62.0 if state == 1 else 54.0
		var pill := Rect2(c + Vector2(-tw / 2, r - 4), Vector2(tw, 26))
		Art.fill(ci, Art.rrect(pill, 13, 440 + k, 0.3), Color("8cc63f") if state == 1 else Color("10232a"), 2.2, INK)
		var font: Font = G.font_title if state == 1 else G.font_body
		var fs := 18
		var w := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_string(font, pill.position + Vector2((tw - w) / 2, 19), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE if state == 1 else Color("bfe3df"))

## 节点上展示的奖励：自选宝箱 > 体力宝箱 > 卡包 > 宝箱 > 第一项。
func _featured(rewards: Array) -> String:
	for prefix in ["choice", "energybox", "pack", "chest"]:
		for rw in rewards:
			if str(rw[0]).begins_with(prefix): return str(rw[0])
	return str(rewards[0][0]) if not rewards.is_empty() else "chest_1"

func _tap_node(k: int) -> void:
	var s := MergeEvent.state(cfg)
	if MergeEvent.claimable(cfg, s).has(k):
		_claim()
	else:
		_preview_rewards(k)

# ---------------------------------------------------------------- 棋盘

func _build_board() -> void:
	board = MergeEventBoard.new()
	board.cfg = cfg
	var cell_size := minf(576.0 / int(cfg["board"]["cols"]), 672.0 / int(cfg["board"]["visible_rows"]))
	board.size = Vector2(int(cfg["board"]["cols"]), int(cfg["board"]["visible_rows"])) * cell_size
	board.position = Vector2((720 - board.size.x) / 2, 418)
	var frame_r := Rect2(board.position, board.size).grow(10)
	UI.box(box, frame_r, func(ci, sz):
		var outer := Art.rrect(Rect2(Vector2.ZERO, sz), 18, 501, 0.6)
		ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(0, 8), sz), 18, 502, 0.0), Color(0, 0, 0, 0.35))
		Art.dilate(ci, outer, 3.0, INK)
		ci.draw_colored_polygon(outer, Color("4f6c72"))
		for k in 18:
			var p := Vector2(Art.srnd(k * 3 + 7) * sz.x, (0.0 if k % 2 == 0 else sz.y - 5.0) + Art.srnd(k) * 5.0)
			ci.draw_circle(p, 1.5 + Art.srnd(k + 9) * 2.0, Color(0, 0, 0, 0.18)))
	box.add_child(board)
	UI.box(box, Rect2(frame_r.position - Vector2(10, 18), Vector2(frame_r.size.x + 20, 60)), _paint_corner_vines)
	board.selection_changed.connect(func(_id, _locked): _show_cell(board.selected))
	board.action_finished.connect(func(_r): _refresh())

func _paint_corner_vines(ci: CanvasItem, sz: Vector2) -> void:
	var leaf := _c("vine", "7fae5a")
	for side in 2:
		var dir := 1.0 if side == 0 else -1.0
		var x0 := 12.0 if side == 0 else sz.x - 12.0
		var pts := PackedVector2Array()
		for k in 9:
			var t := float(k) / 8.0
			pts.append(Vector2(x0 + dir * t * 120.0, 22 + sin(t * 5.0 + side) * 7.0 + t * t * 6.0))
		ci.draw_polyline(pts, INK, 6.0, true)
		ci.draw_polyline(pts, leaf.darkened(0.3), 3.0, true)
		for k in [1, 3, 5, 7]:
			var c: Vector2 = pts[k] + Vector2(0, -7 if k % 4 == 1 else 8)
			var e := Art.ell(c, Vector2(9, 5), 520 + k + side * 9, 0.02, 10, 0.5 * dir * (1 if k % 4 == 1 else -1), 0.4)
			Art.fill(ci, e, leaf if k % 4 == 1 else leaf.lightened(0.12), 1.8, INK)

# ---------------------------------------------------------------- 底部：遗物陈列、积分气泡、说明

func _build_bottom() -> void:
	collection = UI.box(box, SHELF, _paint_collection)
	var chain: Array = cfg["chain"]
	var gap := (SHELF.size.x - 24) / chain.size()
	for k in chain.size():
		UI.hit(box, Rect2(SHELF.position.x + 12 + gap * k, SHELF.position.y, gap, SHELF.size.y), _show_relic.bind(k))
	earn = UI.box(box, Rect2(56, 1192, 200, 166), _paint_earn)
	UI.lbl(box, "主棋盘交订单", Rect2(56, 1200, 200, 30), 21, CREAM)
	UI.lbl(box, "+1~3", Rect2(150, 1236, 120, 56), 38, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 6, INK, true)
	UI.lbl(box, "订单越难 积分越多", Rect2(56, 1302, 200, 26), 17, Color("a9cfcb"))
	UI.lbl(box, "1 积分 = 1 块碎片", Rect2(56, 1326, 200, 26), 17, Color("a9cfcb"))
	spawn_btn = UI.hit(box, Rect2(BUBBLE.x - 76, BUBBLE.y - 78, 152, 164), func(): board.spawn())
	spawn_btn.extra = _paint_spawn
	points = UI.lbl(spawn_btn, "", Rect2(16, 122, 120, 38), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, INK, true)
	info = UI.box(box, Rect2(464, 1192, 200, 166), _paint_info)
	selection = UI.lbl(box, "", Rect2(468, 1284, 192, 32), 22, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 0, INK, true)
	selection_hint = UI.lbl(box, "", Rect2(468, 1316, 192, 34), 17, Color("a9cfcb"))
	_show_cell(-1)

func _card(ci: CanvasItem, sz: Vector2, seed: int, glow: float = 0.0) -> void:
	var r := Art.rrect(Rect2(Vector2.ZERO, sz), 18, seed, 0.6)
	if glow > 0.0: Art.dilate(ci, r, 7.0, Color(1, 0.9, 0.5, glow))
	Art.dilate(ci, r, 3.0, INK)
	ci.draw_colored_polygon(r, Color("1e3842"))
	Art.dashed(ci, Art.rrect(Rect2(Vector2(6, 6), sz - Vector2(12, 12)), 13, seed + 1, 0.0), 9, 6, Color(_c("glow", "bff3f0"), 0.22), 1.8)

func _paint_earn(ci: CanvasItem, sz: Vector2) -> void:
	var s := MergeEvent.state(cfg)
	var hungry := int(s["points"]) < int(cfg["points"]["spawn_cost"]) and MergeEvent.active(cfg)
	_card(ci, sz, 601, (0.35 + 0.3 * sin(_t * 4.0)) if hungry else 0.0)
	# 订单小卡 → 积分
	var tk := Rect2(16, 46, 40, 50)
	Art.fill(ci, Art.rrect(tk, 6, 610, 0.4), Color("f6e7c8"), 2.4, INK)
	for k in 3: ci.draw_line(tk.position + Vector2(8, 14 + k * 11), tk.position + Vector2(32, 14 + k * 11), Color(0.4, 0.27, 0.12, 0.55), 2.0)
	Paint.check_mark(ci, tk.position + Vector2(34, 44), 0.7)
	ci.draw_texture_rect(MergeEvent.texture(str(cfg["theme"]["point_icon"])), Rect2(56, 52, 40, 40), false)

func _paint_spawn(ci: CanvasItem, sz: Vector2) -> void:
	var s := MergeEvent.state(cfg)
	var can := int(s["points"]) >= int(cfg["points"]["spawn_cost"]) and spawn_btn.enabled
	var c := Vector2(sz.x / 2, 72)
	if can:
		ci.draw_circle(c, 70 + 4 * sin(_t * 3.0), Color(_c("glow", "bff3f0"), 0.18))
	ci.draw_circle(c + Vector2(0, 6), 62, Color(0, 0, 0, 0.25))
	var ring := Art.ell(c, Vector2(62, 62), 620, 0.02, 30)
	Art.dilate(ci, ring, 3.5, INK)
	var bub := _c("accent", "8cdece") if can else Color("6b8487")
	ci.draw_colored_polygon(ring, Color(bub, 0.92))
	ci.draw_colored_polygon(Art.ell(c + Vector2(4, 6), Vector2(54, 52), 621, 0.02, 26), Color(bub.darkened(0.25), 0.7))
	ci.draw_colored_polygon(Art.ell(c + Vector2(-2, -2), Vector2(52, 50), 622, 0.02, 26), Color(bub.lightened(0.18), 0.9))
	ci.draw_arc(c + Vector2(-4, -4), 46, PI * 1.08, PI * 1.5, 14, Color(1, 1, 1, 0.85), 6, true)
	ci.draw_circle(c + Vector2(30, -32), 5, Color(1, 1, 1, 0.8))
	var bob := sin(_t * 2.5) * 3.0 if can else 0.0
	MergeEvent.draw_item(ci, cfg, str(cfg["chain"][int(cfg["points"]["spawn_tier"]) - 1]["id"]), c + Vector2(0, bob - 2), 78, Color.WHITE if can else Color(0.7, 0.75, 0.78, 0.8))
	var pill := Rect2(Vector2(20, 124), Vector2(112, 36))
	Art.fill(ci, Art.rrect(pill, 18, 623, 0.3), Color("10232a"), 2.5, INK)
	ci.draw_texture_rect(MergeEvent.texture(str(cfg["theme"]["point_icon"])), Rect2(pill.position + Vector2(-8, -4), Vector2(44, 44)), false)
	if can: Paint.plus_badge(ci, c + Vector2(46, 38))

func _paint_info(ci: CanvasItem, sz: Vector2) -> void:
	_card(ci, sz, 640)
	var c := Vector2(sz.x / 2, 52)
	if _info_id != "":
		ci.draw_circle(c, 40, Color(_c("glow", "bff3f0"), 0.14))
		var known: bool = MergeEvent.state(cfg)["discovered"].has(_info_id)
		MergeEvent.draw_item(ci, cfg, _info_id, c, 80, Color.WHITE if known else Color(0.06, 0.14, 0.18, 0.9))
	else:
		# 两件碎片 → 箭头 → 吊坠：示意合成
		var a := str(cfg["chain"][0]["id"])
		MergeEvent.draw_item(ci, cfg, a, c + Vector2(-62, 4), 46)
		MergeEvent.draw_item(ci, cfg, a, c + Vector2(-26, 4), 46)
		Art.fill(ci, Art.poly([c + Vector2(2, -6), c + Vector2(18, 4), c + Vector2(2, 14)], 641, 0.3), CREAM, 2.0, INK)
		MergeEvent.draw_item(ci, cfg, str(cfg["chain"][1]["id"]), c + Vector2(52, 0), 60)

func _show_cell(i: int) -> void:
	if not is_instance_valid(selection): return
	var s := MergeEvent.state(cfg)
	if i < 0 or i >= s["cells"].size():
		_info_id = ""
		selection.text = "两件相同合成"
		selection_hint.text = "在石板旁合成可揭开它"
	else:
		var c: Dictionary = s["cells"][i]
		var lock := int(c["lock"])
		if lock == 2:
			_info_id = ""
			selection.text = "藤蔓石板"
			selection_hint.text = "在旁边合成即可揭开"
		else:
			_info_id = str(c["id"])
			if _info_id == "":
				selection.text = "空地"
				selection_hint.text = "积分投放会落到这里"
			else:
				var row := MergeEvent.item(cfg, _info_id)
				selection.text = str(row.get("name", ""))
				var tier: int = cfg["chain"].find(row) + 1
				if lock == 1: selection_hint.text = "拖入同样的%s解锁" % str(row.get("name", ""))
				elif MergeEvent.next_id(cfg, _info_id) == "": selection_hint.text = "第 %d 级 · 最高级" % tier
				else: selection_hint.text = "第 %d 级 · 合成得%s" % [tier, str(MergeEvent.item(cfg, MergeEvent.next_id(cfg, _info_id)).get("name", ""))]
	info.queue_redraw()

func _show_relic(k: int) -> void:
	var row: Dictionary = cfg["chain"][k]
	_info_id = str(row["id"])
	var known: bool = MergeEvent.state(cfg)["discovered"].has(_info_id)
	selection.text = str(row["name"]) if known else "？？？"
	selection_hint.text = ("第 %d 级遗物" % (k + 1)) if known else "第 %d 级 · 合成后揭晓" % (k + 1)
	info.queue_redraw()

func _paint_collection(ci: CanvasItem, sz: Vector2) -> void:
	var chain: Array = cfg["chain"]
	var s := MergeEvent.state(cfg)
	var ledge := Art.rrect(Rect2(Vector2(0, 8), sz - Vector2(0, 8)), 16, 701, 0.6)
	ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(0, 14), sz - Vector2(0, 8)), 16, 702, 0.0), Color(0, 0, 0, 0.3))
	Art.dilate(ci, ledge, 3.0, INK)
	ci.draw_colored_polygon(ledge, Color("5b787d"))
	ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(6, 12), Vector2(sz.x - 12, 10)), 5, 703, 0.0), Color(1, 1, 1, 0.12))
	var gap := (sz.x - 24) / chain.size()
	var top := -1
	for k in chain.size():
		if s["discovered"].has(str(chain[k]["id"])): top = k
	for k in chain.size():
		var c := Vector2(12 + gap * (k + 0.5), sz.y / 2 + 4)
		var id := str(chain[k]["id"])
		var socket := Art.ell(c, Vector2(gap * 0.43, 25), 710 + k, 0.03, 18)
		ci.draw_colored_polygon(socket, Color("223b42"))
		Art.outline(ci, socket, 2.0, Color(0, 0, 0, 0.35))
		if s["discovered"].has(id):
			if k == top: ci.draw_circle(c, 30 + 2 * sin(_t * 3.0), Color(_c("glow", "bff3f0"), 0.22))
			MergeEvent.draw_item(ci, cfg, id, c + Vector2(0, -6), gap * 0.86)
		else:
			MergeEvent.draw_item(ci, cfg, id, c + Vector2(0, -4), gap * 0.78, Color(0.05, 0.13, 0.17, 0.85))
		var n := str(k + 1)
		ci.draw_string(G.font_title, c + Vector2(gap * 0.28, 24), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("dcefe9") if s["discovered"].has(id) else Color("6f8f92"))

# ---------------------------------------------------------------- 月夜遗迹背景

func _paint_scene(ci: CanvasItem, sz: Vector2) -> void:
	var r := Art.rrect(Rect2(Vector2.ZERO, sz), 18, 801, 0.4)
	ci.draw_colored_polygon(r, _c("sky_top", "142636"))
	var bands := 10
	for k in bands:
		var t := float(k) / bands
		ci.draw_rect(Rect2(6, 8 + sz.y * t, sz.x - 12, sz.y / bands + 1), Color(_c("sky_top", "142636").lerp(_c("sky_bottom", "2c5a63"), t), 0.9))
	# 月亮（藏在进度板后面露出一角）与星星
	var moon := Vector2(sz.x - 70, 46)
	for k in 3: ci.draw_circle(moon, 64 + k * 22, Color(_c("glow", "bff3f0"), 0.07))
	ci.draw_circle(moon, 46, Color("f4f6dc"))
	ci.draw_circle(moon + Vector2(14, -8), 9, Color("dfe4c6"))
	ci.draw_circle(moon + Vector2(-16, 12), 6, Color("dfe4c6"))
	for k in 36:
		var p := Vector2(16 + Art.srnd(k * 3 + 1) * (sz.x - 32), 14 + Art.srnd(k * 7 + 2) * (sz.y - 28))
		var tw := 0.35 + 0.35 * sin(_t * (1.5 + Art.srnd(k) * 2.0) + k)
		ci.draw_circle(p, 1.2 + Art.srnd(k + 11) * 1.6, Color(0.85, 1, 0.95, tw))
	# 底部远处的断柱剪影
	var sil := Color(_c("sky_top", "142636"), 0.75)
	var base_y := sz.y - 8
	for k in 7:
		var x := 20 + k * (sz.x - 40) / 6.0
		var h := 90 + Art.srnd(k * 5) * 110
		var w := 26 + Art.srnd(k * 9) * 18
		ci.draw_colored_polygon(Art.poly([Vector2(x - w / 2, base_y), Vector2(x - w / 2 + 3, base_y - h), Vector2(x - w / 2 + w * 0.4, base_y - h - 10 * Art.srnd(k)), Vector2(x + w / 2, base_y - h + 6), Vector2(x + w / 2, base_y)], 810 + k, 0.4), sil)
	Art.outline(ci, r, 2.5, Color(INK, 0.9))

# ---------------------------------------------------------------- 状态刷新

func _refresh() -> void:
	if not is_instance_valid(board): return
	var s := MergeEvent.state(cfg)
	progress.text = "%d / %d" % [MergeEvent.progress(cfg, s), MergeEvent.goal_total(cfg)]
	points.text = "×%d" % int(s["points"])
	spawn_btn.enabled = MergeEvent.active(cfg) and not bool(s["claimed"])
	claim_btn.enabled = true
	for id in s["discovered"]:
		if not _known.has(id):
			_known[id] = true
			var row := MergeEvent.item(cfg, str(id))
			var k: int = cfg["chain"].find(row)
			if k > 0 and is_instance_valid(fx):
				fx.add("banner", Vector2(360, 520), {"id": str(id), "text": "新遗物 · " + str(row.get("name", ""))})
				Sfx.play("fanfare")
	for d in [spawn_btn, collection, track, earn, info]: d.queue_redraw()
	_tick()

func _process(delta: float) -> void:
	_t += delta
	_clock += delta
	if is_instance_valid(spawn_btn):
		spawn_btn.queue_redraw()
		earn.queue_redraw()
		if not MergeEvent.claimable(cfg, MergeEvent.state(cfg)).is_empty() or Engine.get_process_frames() % 3 == 0: track.queue_redraw()
	if _clock >= 1:
		_clock = 0
		_tick()

func _tick() -> void:
	if not is_instance_valid(timer): return
	var left := maxi(0, int(float(cfg["ends_at"]) - G.now()))
	timer.text = "第 %d 期 · 剩余 %s" % [int(str(cfg["key"]).get_slice(":", 1)) + 1, G.fmt_time(left)] if left > 0 else "本期已结束 · 已达成的宝箱仍可领取"
	if left <= 0: spawn_btn.enabled = false

func _claim() -> void:
	var result: Dictionary = await MergeEvent.act(cfg, "claim")
	if result.has("error"):
		if str(result["error"]) != "": G.main.toast(str(result["error"]))
		return
	fx.add("spark", Vector2(float(_node_x[int(result.get("milestones", [0])[-1])]), BAR.get_center().y), {})
	_refresh()

func _preview_rewards(k: int) -> void:
	var ms := MergeEvent.milestones(cfg)
	var m: Dictionary = ms[k]
	var s := MergeEvent.state(cfg)
	var last := k == ms.size() - 1
	var p := PopupBase.new()
	p.tap_to_close = true
	Popups.frame(p, Rect2(48, 470, 624, 540), "通关大奖" if last else "探索宝箱", _c("banner", "2f6377"))
	var goal := "发现 %d 件遗物" % int(m["at"]) if str(cfg["board"].get("goal", "")) == "discover_all" else ("解锁全部 %d 格遗迹" % int(m["at"]) if last else "解锁 %d 格遗迹" % int(m["at"]))
	var have := MergeEvent.got(cfg, s).has(k)
	UI.lbl(p.box, goal, Rect2(80, 538, 560, 44), 30, INK, HORIZONTAL_ALIGNMENT_CENTER, 0, INK, true)
	UI.lbl(p.box, "已领取" if have else "当前进度 %d / %d" % [mini(MergeEvent.progress(cfg, s), int(m["at"])), int(m["at"])], Rect2(80, 582, 560, 34), 22, Color("8a5a30"))
	var rewards: Array = m["rewards"]
	var gap := 540.0 / maxi(1, rewards.size())
	for j in rewards.size():
		var reward: Array = rewards[j]
		var x := 90 + gap * j
		UI.box(p.box, Rect2(x + 6, 636, gap - 12, 200), func(ci, sz):
			Art.fill(ci, Art.rrect(Rect2(Vector2.ZERO, sz), 20, 480 + j, 0.4), Color("24404a"), 3.0, INK)
			ci.draw_circle(Vector2(sz.x / 2, 82), 52, Color(_c("glow", "bff3f0"), 0.15))
			Art.item(ci, str(reward[0]), Vector2(sz.x / 2, 82), minf(112, gap - 30)))
		UI.lbl(p.box, "×%d" % int(reward[1]), Rect2(x, 770, gap, 50), 32, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, INK, true)
	UI.btn(p.box, Rect2(210, 880, 300, 86), "知道了", "teal", p.close, 30)
	G.main._attach_popup(p)

# ---------------------------------------------------------------- 特效层（面板坐标）

class Fx extends Control:
	var cfg: Dictionary
	var parts: Array = []

	func _init() -> void:
		size = Vector2(720, 1480)
		mouse_filter = MOUSE_FILTER_IGNORE

	func add(kind: String, pos: Vector2, data: Dictionary = {}) -> void:
		match kind:
			"spark":
				var n := 6 if data.get("small", false) else 10
				for k in n:
					var a := TAU * k / n + randf() * 0.4
					parts.append({"k": "star", "p": pos, "v": Vector2.from_angle(a) * randf_range(150, 260) * (0.6 if n == 6 else 1.0), "t": 0.0, "dur": 0.55, "r": randf_range(6, 10)})
				parts.append({"k": "ring", "p": pos, "t": 0.0, "dur": 0.45, "r": 60.0 if n == 10 else 40.0})
			"leaves":
				for k in 10:
					parts.append({"k": "leaf", "p": pos + Vector2(randf_range(-20, 20), randf_range(-20, 20)), "v": Vector2(randf_range(-180, 180), randf_range(-260, -80)), "t": 0.0, "dur": 0.9, "rot": randf() * TAU, "spin": randf_range(-8, 8), "c": data.get("color", Color("7fae5a"))})
			"dust":
				for k in 6:
					parts.append({"k": "chip", "p": pos + Vector2(randf_range(-30, 30), randf_range(-24, 24)), "v": Vector2(randf_range(-120, 120), randf_range(-200, -40)), "t": 0.0, "dur": 0.7, "rot": randf() * TAU, "spin": randf_range(-10, 10), "c": data.get("color", Color("6e8d93"))})
				for k in 3:
					parts.append({"k": "puff", "p": pos + Vector2(randf_range(-20, 20), randf_range(0, 20)), "t": 0.0, "dur": 0.6, "r": randf_range(16, 26)})
			"text":
				parts.append({"k": "text", "p": pos, "t": 0.0, "dur": 1.2, "s": str(data.get("text", "")), "c": data.get("color", Color.WHITE), "fs": int(data.get("size", 28))})
			"fly":
				parts.append({"k": "fly", "from": data.get("from", pos), "p": pos, "t": 0.0, "dur": 0.42, "id": str(data.get("id", "")), "done": data.get("done", Callable())})
			"banner":
				parts.append({"k": "banner", "p": pos, "t": 0.0, "dur": 1.9, "id": str(data.get("id", "")), "s": str(data.get("text", ""))})

	func _process(delta: float) -> void:
		if parts.is_empty(): return
		for q in parts:
			q["t"] = float(q["t"]) + delta / float(q["dur"])
			if q.has("v"):
				q["p"] = (q["p"] as Vector2) + (q["v"] as Vector2) * delta
				q["v"] = (q["v"] as Vector2) * (1.0 - delta * 2.5) + Vector2(0, 520 if q["k"] != "star" else 120) * delta
			if q.has("spin"): q["rot"] = float(q["rot"]) + float(q["spin"]) * delta
		for q in parts.filter(func(q): return float(q["t"]) >= 1.0):
			if q["k"] == "fly" and (q["done"] as Callable).is_valid(): (q["done"] as Callable).call()
		parts = parts.filter(func(q): return float(q["t"]) < 1.0)
		queue_redraw()

	func _draw() -> void:
		for q in parts:
			var t := float(q["t"])
			var p: Vector2 = q["p"]
			match str(q["k"]):
				"star":
					var a := 1.0 - t
					draw_colored_polygon(Art.star_pts(p, float(q["r"]) * a + 2, float(q["r"]) * 0.4 * a + 1, 4, 3), Color(1, 0.95, 0.6, a))
				"ring":
					draw_arc(p, 14 + t * float(q["r"]), 0, TAU, 28, Color(1, 0.95, 0.65, 1 - t), 5 * (1 - t) + 1, true)
				"leaf":
					var e := Art.ell(p, Vector2(9, 5), 0, 0.0, 10, float(q["rot"]), 0.0)
					draw_colored_polygon(e, Color(q["c"], 1 - t * t))
					Art.outline(self, e, 1.5, Color(Art.INK, 1 - t * t))
				"chip":
					var pts := PackedVector2Array([p + Vector2.from_angle(float(q["rot"])) * 8, p + Vector2.from_angle(float(q["rot"]) + 2.2) * 7, p + Vector2.from_angle(float(q["rot"]) + 4.0) * 6])
					draw_colored_polygon(pts, Color(q["c"], 1 - t))
					draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(Art.INK, 1 - t), 1.5)
				"puff":
					draw_circle(p + Vector2(0, -t * 20), float(q["r"]) * (0.6 + t), Color(0.85, 0.9, 0.88, 0.35 * (1 - t)))
				"text":
					var a := clampf((1 - t) * 3.0, 0, 1)
					var fs := int(q["fs"])
					var w := G.font_title.get_string_size(str(q["s"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
					var at := p + Vector2(-w / 2, -t * 50)
					draw_string_outline(G.font_title, at, str(q["s"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(Art.INK, a))
					draw_string(G.font_title, at, str(q["s"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(q["c"], a))
				"fly":
					var from: Vector2 = q["from"]
					var e2 := t * t * (3.0 - 2.0 * t)
					var pos := from.lerp(p, e2) + Vector2(0, -sin(t * PI) * 120)
					draw_circle(pos, 30, Color(0.75, 1, 0.97, 0.25))
					MergeEvent.draw_item(self, cfg, str(q["id"]), pos, 70 + sin(t * PI) * 16)
				"banner":
					var a := clampf(minf(t * 6.0, (1 - t) * 4.0), 0, 1)
					var sc := 0.8 + 0.2 * minf(1.0, t * 6.0)
					draw_set_transform(p, 0, Vector2.ONE * sc)
					var r := Rect2(-210, -58, 420, 116)
					Art.fill(self, Art.rrect(r, 26, 901, 0.4), Color(0.12, 0.25, 0.3, 0.94 * a), 3.0, Color(Art.INK, a))
					draw_circle(Vector2(-140, 0), 50, Color(0.75, 1, 0.97, 0.25 * a))
					MergeEvent.draw_item(self, cfg, str(q["id"]), Vector2(-140, -2), 96, Color(1, 1, 1, a))
					draw_string(G.font_body, Vector2(-80, -14), "解锁图鉴", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.75, 0.95, 0.92, a))
					draw_string_outline(G.font_title, Vector2(-80, 26), str(q["s"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, Color(Art.INK, a))
					draw_string(G.font_title, Vector2(-80, 26), str(q["s"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 0.95, 0.7, a))
					draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
