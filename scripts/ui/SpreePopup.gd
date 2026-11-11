extends PopupBase
## 「赶大集」限时超值礼包（data/offers.json 的 spree）：
## 上：横幅标题 + 倒计时；中：集市插画（兽皮棚子、彩旗、阿焰拎着两只鼓鼓的草编袋，琥珀和火种从袋口冒出来）；
## 插画下半压一块半透明奖励格（3×2，物品带 i 角标可看详情）；
## 下：剩余可买 N 次 + 大绿价格按钮 + 红色「多送 150%」爆炸贴。
const R := Rect2(40, 250, 640, 1000)
const ART := Rect2(64, 312, 592, 700)
const GRID := Rect2(92, 704, 536, 286)
const KIND := "spree"
const TIER := 0
var buy_btn: TButton
var clock: Label
var left_lbl: Label
var _tick := 0.0
var _busy := false

func _ready() -> void:
	var t := Offers.tier(KIND, TIER)
	Popups.frame(self, R, str(Offers.cfg(KIND).get("title", "赶大集")), Art.CLAY)
	UI.box(box, ART, _paint_market)
	# 倒计时
	UI.box(box, Rect2(R.get_center().x - 96, R.position.y + 48, 192, 50), func(ci, sz):
		Sprites.draw(ci, "ev_clock_pill", Rect2(Vector2.ZERO, sz))
		Paint.glyph(ci, "clock", Vector2(27, sz.y * 0.5), 0.9, Color.WHITE))
	clock = UI.lbl(box, "", Rect2(R.get_center().x - 52, R.position.y + 48, 140, 50), 28, Color("6b3d1a"))
	_grid(t.get("rewards", []))
	left_lbl = UI.lbl(box, "", Rect2(R.position.x, 1004, R.size.x, 44), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK, true)
	buy_btn = UI.btn(box, Rect2(190, 1056, 340, 112), Offers.price_text(KIND, TIER), "green", _buy, 54)
	buy_btn.name = "spree_buy"
	buy_btn.title_font = false
	_burst(int(t.get("value_pct", 100)) - 100)
	UI.lbl(box, "支付暂未开放", Rect2(R.position.x, 1188, R.size.x, 30), 19, Color("9a8468"))
	_refresh()

## 集市：暖色天空、兽皮棚子、一串彩旗、两边货架，阿焰站中间拎着两只鼓鼓的草编袋
## 手绘部分分层预生成（scripts/sprites/events.gd 的 ev_spree_*），物品图标夹在层之间
func _paint_market(ci: CanvasItem, sz: Vector2) -> void:
	var r := Rect2(Vector2.ZERO, sz)
	Sprites.draw(ci, "ev_spree_bg", r)
	Paint.vgrad(ci, Rect2(10, 10, sz.x - 20, 300), Color("ffc7a0"), Color("f7e3b4"))
	# 远处的太阳光芒
	var sun := Vector2(sz.x * 0.5, 170)
	for j in 14:
		var a := TAU * j / 14.0
		ci.draw_colored_polygon(PackedVector2Array([sun, sun + Vector2.from_angle(a - 0.09) * 360, sun + Vector2.from_angle(a + 0.09) * 360]), Color(1, 0.95, 0.75, 0.28))
	ci.draw_circle(sun, 64, Color(1, 0.93, 0.68, 0.8))
	# 地面、土坑、两边的兽皮棚子
	Sprites.draw(ci, "ev_spree_scene", r)
	_goods(ci, Rect2(6, 120, 170, 230), 914)
	_goods(ci, Rect2(sz.x - 176, 110, 170, 240), 920)
	# 彩旗：绳子从左上垂到右上
	Sprites.draw(ci, "ev_spree_bunting", r)
	# 阿焰 + 两只草编袋（提手 → 袋口物品 → 袋身）
	Paint.bust(ci, Vector2(sz.x * 0.5, 330), 150)
	Sprites.draw(ci, "ev_spree_bags_back", r)
	_bag_items(ci, Vector2(sz.x * 0.5 - 150, 330), -0.18)
	_bag_items(ci, Vector2(sz.x * 0.5 + 150, 322), 0.16)
	Sprites.draw(ci, "ev_spree_bags_front", r)
	# 闪光 + 外框墨线
	Sprites.draw(ci, "ev_spree_top", r)

## 兽皮棚下的几样货
func _goods(ci: CanvasItem, r: Rect2, seed: int) -> void:
	var goods := ["fruit_4", "pot_3", "fruit_6"] if seed % 2 == 0 else ["tool_4", "cloth_4", "veg_3"]
	for k in 3:
		Art.item(ci, goods[k], Vector2(r.position.x + 32 + k * (r.size.x - 64) / 2.0, r.end.y - 74), 50)

## 草编袋口冒出的琥珀和火种（Art.item 会重置画布变换，所以这里手动旋转各点）
func _bag_items(ci: CanvasItem, c: Vector2, rot: float) -> void:
	Art.item(ci, Art.AMBER_ICON, c + Vector2(-18, -48).rotated(rot), 50, true, rot - 0.3)
	Art.item(ci, "fire_3", c + Vector2(17, -52).rotated(rot), 48, true, rot + 0.2)
	Art.item(ci, "amber_3", c + Vector2(2, -40).rotated(rot), 40, true, rot + 0.1)

## 奖励格：半透明底板 3×2，每格图标 + ×数量；实物（宝箱 / 卡包 / 生产器）右上角 i，点开看详情
func _grid(rewards: Array) -> void:
	UI.box(box, GRID, func(ci, sz):
		Sprites.draw(ci, "ev_spree_grid", Rect2(Vector2.ZERO, sz)))
	var cols := 3
	var cw := GRID.size.x / cols
	var ch := GRID.size.y / 2.0
	for k in mini(rewards.size(), 6):
		var rw: Array = rewards[k]
		var id := str(rw[0])
		var n := int(rw[1])
		var c := GRID.position + Vector2(cw * (k % cols + 0.5), ch * (k / cols) + 58)
		UI.icon(box, id, c, 92)
		UI.lbl(box, "×%d" % n, Rect2(c.x - 80, c.y + 44, 160, 44), 32, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK, true)
		if not Rewards.is_resource(id):
			var info := UI.hit(box, Rect2(c.x - 50, c.y - 50, 100, 100), func(): G.main.open("item_info", id))
			info.name = "spree_info_%d" % k
			info.extra = func(ci, _sz): _info_badge(ci, Vector2(84, 14))

static func _info_badge(ci: CanvasItem, c: Vector2) -> void:
	Sprites.draw(ci, "ev_info_badge", Rect2(c - Vector2(15, 15), Vector2(30, 30)))

## 红色爆炸贴：多送 xx%
func _burst(extra: int) -> void:
	var st := UI.box(box, Rect2(504, 1018, 150, 136), func(ci, sz):
		Sprites.draw(ci, "ev_spree_burst", Rect2(Vector2.ZERO, sz)))
	st.rotation = 0.2
	st.pivot_offset = st.size * 0.5
	st.name = "spree_burst"
	UI.lbl(st, "多送", Rect2(0, 30, 150, 34), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Color("7a1c12"), true)
	UI.lbl(st, "%d%%" % extra, Rect2(0, 62, 150, 44), 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 7, Color("7a1c12"), true)

func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 1.0:
		_tick = 0.0
		_refresh()

static func clock_text(sec: int) -> String:
	if sec >= 3600: return "%d:%02d:%02d" % [sec / 3600, (sec % 3600) / 60, sec % 60]
	return "%02d:%02d" % [sec / 60, sec % 60]

func _refresh() -> void:
	var live := Offers.active(KIND)
	var n := Offers.left(KIND, TIER)
	clock.text = clock_text(Offers.remaining(KIND)) if live else "已结束"
	left_lbl.text = "剩余可买：%d" % n
	buy_btn.enabled = live and n > 0 and not _busy
	buy_btn.text = Offers.price_text(KIND, TIER) if live and n > 0 else ("已买完" if n <= 0 else "下次再来")
	buy_btn.queue_redraw()

func _buy() -> void:
	if _busy: return
	_busy = true
	_refresh()
	var from := buy_btn.get_global_rect().get_center() + Vector2(0, -160)
	var r: Dictionary = await Offers.buy(KIND, TIER)
	if not is_instance_valid(self): return
	_busy = false
	if not r.get("ok", false):
		var msg := str(r.get("message", ""))
		if msg != "": G.main.toast(msg)
	else: RewardPresenter.present(r.get("rewards", []), func(_k): return from)
	_refresh()
