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
		Sprites.draw(ci, "ev_clock_pill", Rect2(Vector2.ZERO, sz))
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
	# 藤蔓野花、草丘是预生成贴图（头图坐标）
	Sprites.draw(ci, "ev_energy_vines", Rect2(0, 74, 720, 276))
	Sprites.draw(ci, "ev_energy_hill", Rect2(96, 384, 528, 150))
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
		Sprites.draw(ci, "ev_spark4", Rect2(p - Vector2(12, 12), Vector2(24, 24)), Color(1, 1, 0.9, 0.85))

func _card(k: int) -> void:
	var t := Offers.tier(KIND, k)
	var r := Rect2(float(CARD_X[k]), CARD_Y, CARD_W, CARD_H)
	# 卡身（条纹、叶子小花、内衬）是预生成贴图，配色见 scripts/sprites/events.gd 的 EN_HEAD / EN_BODY
	UI.box(box, r, func(ci, sz): Sprites.draw(ci, "ev_energy_card_%d" % k, Rect2(Vector2.ZERO, sz)))
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
			Sprites.draw(ci, "ev_energy_best", Rect2(Vector2.ZERO, sz)))
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
