extends PopupBase
## 「火种大礼包」（data/offers.json 的 energy）：体力用完点生产器、或点顶栏体力时弹出。
## 上：大字标题（两边藤蔓野花）+ 草丘上一只藤编宝箱，周围堆满火种和琥珀 + 倒计时；
## 中：三档价格卡并排（超值 130% / 135% / 140%），最后一档挂「最划算」丝带，每档写琥珀、体力、宝箱 ×1；
## 下：「或者等待 hh:mm:ss 体力恢复到 100」，再给一个琥珀买体力的小按钮。
const KIND := "energy"
const CARD_Y := 630.0
const CARD_H := 600.0
const CARD_W := 206.0
const CARD_X := [36.0, 257.0, 478.0]
const HEAD := [Color("4fa39a"), Color("8cc63f"), Color("eaa53c")]
const BODY := [Color("6cc0b2"), Color("a6d65a"), Color("ffd06a")]
var clock: Label
var wait_lbl: Label
var btns: Array[TButton] = []
var _tick := 0.0
var _busy := false

func _ready() -> void:
	dim_alpha = 0.78
	UI.box(box, Rect2(0, 50, 720, 1480), _paint_head)
	var t := UI.title(box, str(Offers.cfg(KIND).get("title", "火种大礼包")), Rect2(60, 142, 600, 110), 76, Color("ffd23f"))
	t.rotation = -0.02
	var x := UI.hit(box, Rect2(630, 140, 70, 70), close)
	x.name = "energy_offer_close"
	x.extra = func(ci, sz): Paint.close_btn(ci, sz * 0.5, 28)
	# 倒计时
	UI.box(box, Rect2(264, 556, 192, 50), func(ci, sz):
		var p := Art.rrect(Rect2(Vector2.ZERO, sz), 25, 701, 0.5)
		Art.dilate(ci, p, 3.0, Art.INK)
		ci.draw_colored_polygon(p, Art.BONE)
		ci.draw_circle(Vector2(27, sz.y * 0.5), 18, Art.OCHRE)
		Paint.glyph(ci, "clock", Vector2(27, sz.y * 0.5), 0.9, Color.WHITE))
	clock = UI.lbl(box, "", Rect2(304, 556, 148, 50), 28, Color("6b3d1a"))
	for k in Offers.tiers(KIND).size():
		_card(k)
	wait_lbl = UI.lbl(box, "", Rect2(20, 1246, 680, 50), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK)
	var amber := UI.btn(box, Rect2(250, 1306, 220, 64), "琥珀买体力", "hide", func():
		close()
		G.main.open("energy_amber"), 24)
	amber.name = "energy_offer_amber"
	amber.title_font = false
	_refresh()

## 标题两侧的藤蔓野花 + 草丘、宝箱、火种和琥珀堆
func _paint_head(ci: CanvasItem, _sz: Vector2) -> void:
	for side in [-1.0, 1.0]:
		var base := Vector2(360 + side * 290, 330)
		var vine: Array = []
		for k in 9:
			var u := float(k) / 8.0
			vine.append(base + Vector2(side * -sin(u * 2.4) * 40.0 - side * u * 30.0, -u * 230.0))
		Art.pl(ci, vine, 7.0, Art.INK, 711)
		Art.pl(ci, vine, 4.0, Art.LEAF_D, 711)
		for k in range(1, 8):
			var p: Vector2 = vine[k]
			var leaf := Art.ell(p + Vector2(side * 16, 0), Vector2(18, 8), 712 + k, 0.08, 10, side * 0.6 + (k % 2) * 0.8)
			Art.fill(ci, leaf, Art.LEAF, 2.2)
		for k in [2, 5, 8]:
			var p: Vector2 = vine[k]
			_flower(ci, p + Vector2(side * -14, -6), Art.BERRY if k == 5 else Color("f39ab0"), 720 + k)
	# 草丘
	var hill := Art.ell(Vector2(360, 452), Vector2(250, 62), 730, 0.04, 30)
	ci.draw_colored_polygon(Art.ell(Vector2(360, 466), Vector2(252, 60), 731, 0.04, 30), Color(0, 0, 0, 0.3))
	Art.dilate(ci, hill, 3.0, Art.INK)
	ci.draw_colored_polygon(hill, Color("8a6038"))
	ci.draw_colored_polygon(Art.ell(Vector2(360, 440), Vector2(240, 48), 732, 0.05, 28), Art.LEAF)
	for k in 12:
		var p := Vector2(150 + Art.srnd(k * 5 + 1) * 420, 418 + Art.srnd(k * 3 + 7) * 34)
		Art.pl(ci, [p, p + Vector2(-4, -12), p + Vector2(2, -4), p + Vector2(6, -14)], 2.0, Art.LEAF_D, 733 + k)
	# 宝箱后面的光
	var c := Vector2(360, 330)
	for j in 12:
		var a := TAU * j / 12.0
		ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a - 0.1) * 190, c + Vector2.from_angle(a + 0.1) * 190]), Color(1, 0.95, 0.6, 0.18))
	Art.item(ci, "chest_1", c, 230)
	# 火种和琥珀堆满草丘（后排 → 前排）
	for k in 16:
		var u := Art.srnd(k * 11 + 3)
		var p := Vector2(150 + u * 420, 392 + Art.srnd(k * 7 + 5) * 28)
		Art.item(ci, "fire_3" if k % 3 != 0 else Art.AMBER_ICON, p, 64, true, (Art.srnd(k) - 0.5) * 0.8)
	for k in 9:
		var p := Vector2(176 + k * 46, 436 + (k % 2) * 12)
		Art.item(ci, "fire_2" if k % 4 != 1 else "amber_3", p, 56, true, (Art.srnd(k + 40) - 0.5) * 0.8)
	for k in 5:
		var p := Vector2(120 + Art.srnd(k * 19 + 2) * 480, 200 + Art.srnd(k * 23 + 4) * 140)
		ci.draw_colored_polygon(Art.star_pts(p, 12, 3.5, 4, 740 + k), Color(1, 1, 0.9, 0.85))

func _flower(ci: CanvasItem, c: Vector2, col: Color, seed: int) -> void:
	for k in 5:
		var a := TAU * k / 5.0
		Art.fill(ci, Art.ell(c + Vector2.from_angle(a) * 9, Vector2(8, 6), seed + k, 0.1, 8, a), col, 2.0)
	ci.draw_circle(c, 5, Art.FIRE2)

func _card(k: int) -> void:
	var t := Offers.tier(KIND, k)
	var r := Rect2(float(CARD_X[k]), CARD_Y, CARD_W, CARD_H)
	var head: Color = HEAD[k]
	var body: Color = BODY[k]
	UI.box(box, r, func(ci, sz):
		ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(0, 10), sz), 24, 750 + k, 0.0), Color(0, 0, 0, 0.3))
		var b := Art.rrect(Rect2(Vector2.ZERO, sz), 24, 751 + k, 0.8)
		Art.dilate(ci, b, 3.0, Art.INK)
		ci.draw_colored_polygon(b, head)
		ci.draw_colored_polygon(Art.rrect(Rect2(8, 8, sz.x - 16, sz.y - 16), 18, 754 + k, 0.6), body)
		# 竖条纹
		for j in 6:
			var x: float = 22.0 + j * (sz.x - 44) / 5.0
			Art.ln(ci, Vector2(x, 14), Vector2(x, sz.y - 14), 10.0, Color(1, 1, 1, 0.12), 757 + j)
		# 顶上的叶子和小花
		for j in 7:
			var p := Vector2(16 + j * (sz.x - 32) / 6.0, 4 + (j % 2) * 6)
			Art.fill(ci, Art.ell(p, Vector2(20, 10), 760 + j + k * 7, 0.08, 10, -0.5 + j * 0.17), Art.LEAF, 2.2)
		_flower(ci, Vector2(sz.x * 0.36, 0), Color("f39ab0"), 780 + k * 5)
		_flower(ci, Vector2(sz.x * 0.68, 6), Color("8fc7ff") if k == 0 else Art.BERRY, 790 + k * 5)
		# 内衬
		var inner := Art.rrect(Rect2(16, 92, sz.x - 32, 360), 16, 800 + k, 0.5)
		ci.draw_colored_polygon(inner, Color("f5e7cf"))
		Art.outline(ci, inner, 2.0, Color(0, 0, 0, 0.15)))
	UI.lbl(box, "超值 %d%%!" % int(t.get("value_pct", 100)), Rect2(r.position.x, r.position.y + 34, r.size.x, 50), 30, Color("ffe14a"), HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK, true)
	var rw: Array = t.get("rewards", [])
	for j in mini(rw.size(), 3):
		var row: Array = rw[j]
		var id := str(row[0])
		var c := Vector2(r.get_center().x, r.position.y + 150 + j * 116)
		UI.icon(box, id, c, 76)
		UI.lbl(box, "×%d" % int(row[1]), Rect2(r.position.x, c.y + 30, r.size.x, 40), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK, true)
		if not Rewards.is_resource(id):
			var info := UI.hit(box, Rect2(c.x - 44, c.y - 44, 88, 88), func(): G.main.open("item_info", id))
			info.name = "energy_info_%d" % k
			info.extra = func(ci, _sz): SpreePopupScript._info_badge(ci, Vector2(76, 12))
	if bool(t.get("best", false)):
		var rib := UI.box(box, Rect2(r.position.x - 14, r.position.y + 446, r.size.x + 28, 56), func(ci, sz):
			var p := Art.poly([Vector2(0, 6), Vector2(sz.x, 0), Vector2(sz.x - 14, sz.y * 0.5), Vector2(sz.x, sz.y), Vector2(0, sz.y - 4), Vector2(12, sz.y * 0.5)], 820)
			Art.fill(ci, p, Color("e8577a"), 3.0)
			Art.dashed(ci, Art.poly([Vector2(16, 12), Vector2(sz.x - 18, 8), Vector2(sz.x - 18, sz.y - 10), Vector2(16, sz.y - 10)], 821), 7, 5, Color(1, 0.9, 0.9, 0.7), 2.0))
		rib.name = "energy_best"
		rib.rotation = -0.03
		UI.lbl(rib, "最划算", Rect2(0, 0, rib.size.x, rib.size.y), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 7, Color("8a1d3a"), true)
	var b := UI.btn(box, Rect2(r.position.x + 16, r.end.y - 92, r.size.x - 32, 78), Offers.price_text(KIND, k), "green", func(): _buy(k), 36)
	b.name = "energy_buy_%d" % k
	b.title_font = false
	btns.append(b)

const SpreePopupScript := preload("res://scripts/ui/SpreePopup.gd")

func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 1.0:
		_tick = 0.0
		_refresh()

func _refresh() -> void:
	var live := Offers.active(KIND)
	clock.text = SpreePopupScript.clock_text(Offers.remaining(KIND)) if live else "已结束"
	for k in btns.size():
		var n := Offers.left(KIND, k)
		btns[k].enabled = live and n > 0 and not _busy
		btns[k].text = Offers.price_text(KIND, k) if n > 0 else "已购买"
		if not live and n > 0: btns[k].text = "已结束"
		btns[k].queue_redraw()
	var left := G.energy_full_left()
	var s := left
	var hms := "%02d:%02d:%02d" % [s / 3600, (s % 3600) / 60, s % 60]
	wait_lbl.text = "体力已满，先去合成吧！" if left == 0 else "或者等待 %s 体力恢复到 %d" % [hms, G.MAX_ENERGY]

func _buy(k: int) -> void:
	if _busy: return
	_busy = true
	_refresh()
	var from := btns[k].get_global_rect().get_center() + Vector2(0, -300)
	var r: Dictionary = await Offers.buy(KIND, k, func(_j): return from)
	if not is_instance_valid(self): return
	_busy = false
	if not r.get("ok", false):
		var msg := str(r.get("message", ""))
		if msg != "": G.main.toast(msg)
	elif not G.server_mode():
		G.main.toast("演示版本：礼包已到账")
	_refresh()
