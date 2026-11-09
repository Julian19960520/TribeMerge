extends Control
## 部落界面的「礼包链」入口卡片（和通行证、部落礼包同一套黄色卡片），点开礼包链面板。
## 下面一行写队首状态：免费! / ¥6 / 已领完 / 需联网；队首能免费领时亮红点。
## 卡片只在第一次显示和换期时问一次服务器（面板打开时会再拉）。

const Net := preload("res://scripts/net/GiftChain.gd")
const ChainPopup := preload("res://scripts/ui/GiftChainPopup.gd")
const CARD_YELLOW := Color("e7b45a")
const CARD_YELLOW_L := Color("f2c66e")
## 左侧原每日特惠位置，方形卡片。
const RECT := Rect2(14, 280, 100, 116)

var chain: Node
var _btn: TButton
var _state: Label
var _retry_ms := -1

func _ready() -> void:
	position = RECT.position
	size = RECT.size
	mouse_filter = MOUSE_FILTER_IGNORE
	chain = Net.inst()
	_btn = UI.hit(self, Rect2(Vector2.ZERO, RECT.size), func(): ChainPopup.pop_open())
	_btn.name = "gift_card"
	_btn.extra = _paint
	UI.lbl(_btn, "部落礼包", Rect2(0, 78, 100, 24), 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
	_state = UI.lbl(_btn, "", Rect2(0, 100, 100, 20), 14, Color("ffe7a8"), HORIZONTAL_ALIGNMENT_CENTER, 4, Art.INK)
	chain.updated.connect(_refresh)
	_refresh()

func _process(_d: float) -> void:
	if is_visible_in_tree():
		_btn.queue_redraw()
	if Engine.get_process_frames() % 30 != 0 or not is_visible_in_tree():
		return
	if not chain.loading and chain.online():
		var due: bool = not chain.fetched_once or (chain.ends_at() > 0.0 and G.now() >= chain.ends_at() + 1.0)
		if due and (_retry_ms < 0 or Time.get_ticks_msec() - _retry_ms > 60000):
			_retry_ms = Time.get_ticks_msec()
			chain.fetch()
	_refresh()

func _refresh() -> void:
	var txt := ""
	if not chain.online() or not chain.ok:
		txt = "需联网"
	elif chain.done():
		txt = "已领完"
	else:
		var s: Dictionary = chain.step(chain.head())
		txt = Net.price_text(s) if Net.is_paid(s) else "免费!"
	_state.text = txt

func _paint(ci: CanvasItem, sz: Vector2) -> void:
	# 卡底、礼盒是预生成贴图（scripts/sprites/events.gd）
	Sprites.draw(ci, "ev_giftcard_base", Rect2(0, 0, sz.x, sz.x))
	# 背后一圈慢转的光芒
	var c0 := Vector2(sz.x * 0.5, 44)
	var t := float(Time.get_ticks_msec()) / 1000.0
	for j in 10:
		var ang := t * 0.4 + TAU * j / 10.0
		ci.draw_colored_polygon(PackedVector2Array([c0, c0 + Vector2.from_angle(ang - 0.16) * 40, c0 + Vector2.from_angle(ang + 0.16) * 40]), Color(1, 1, 0.85, 0.35))
	# 两边探出头的琥珀和卡包
	Art.item(ci, "pack_1", Vector2(24, 52), 28, true, -0.3)
	Art.item(ci, Art.AMBER_ICON, Vector2(sz.x - 24, 54), 28, true, 0.25)
	# 主角：红色礼盒 + 金色缎带 + 蝴蝶结
	Sprites.draw(ci, "ev_giftcard_box", Rect2(0, 0, sz.x, sz.x))
	# 闪光
	for j in 2:
		var tw := 0.5 + 0.5 * sin(t * 3.0 + j * 2.0)
		var sp: Vector2 = [Vector2(16, 20), Vector2(sz.x - 16, 24)][j]
		var sr := 3 + tw * 4
		Sprites.draw(ci, "ev_spark4", Rect2(sp - Vector2(sr, sr), Vector2(sr, sr) * 2.0), Color(1, 1, 1, 0.5 + tw * 0.5))
	if chain.free_ready():
		var c := Vector2(sz.x - 14, 8)
		c.y -= absf(sin(float(Time.get_ticks_msec()) / 260.0)) * 4.0
		Paint.badge_num(ci, c, 9)
		var f: Font = G.font_title
		if f != null:
			var w := f.get_string_size("!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			var pos := Vector2(c.x - w * 0.5, c.y + (f.get_ascent(20) - f.get_descent(20)) * 0.5)
			ci.draw_string_outline(f, pos, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, Art.INK)
			ci.draw_string(f, pos, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
