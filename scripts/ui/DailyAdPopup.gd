extends PopupBase
const PS := preload("res://scripts/sprites/popups.gd")
## Daily supply view. Unavailable providers never simulate a rewarded completion.
const R := Rect2(60, 420, 600, 660)
const SCREEN := Rect2(100, 492, 520, 300)
var label: Label
var claim_btn: TButton
var screen: DrawBox
var progress: DrawBox
var count: Label
var _t := 0.0
var _frac := 0.0

func _ready() -> void:
	Popups.frame(self, R, "看广告领体力", Art.TEAL)
	screen = UI.box(box, SCREEN.grow(14), _paint_screen, false)
	count = UI.lbl(box, "", Rect2(SCREEN.end.x - 76, SCREEN.position.y + 12, 60, 52), 32, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK, true)
	UI.lbl(box, "部落补给", Rect2(SCREEN.position.x + 14, SCREEN.position.y + 12, 120, 30), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 5, Color(0, 0, 0, 0.6))
	progress = UI.box(box, Rect2(SCREEN.position.x, SCREEN.end.y + 26, SCREEN.size.x, 26), func(ci, sz):
		Sprites.draw(ci, "pop_ad_track", Rect2(Vector2.ZERO, sz))
		if _frac > 0.02:
			ci.draw_colored_polygon(Art.rrect(Rect2(3, 3, maxf(20.0, (sz.x - 6) * _frac), sz.y - 6), 10, 902, 0.0), Art.MOSS)
			ci.draw_colored_polygon(Art.rrect(Rect2(8, 5, maxf(10.0, (sz.x - 16) * _frac), 6), 3, 903, 0.0), Color(1, 1, 1, 0.35)), false)
	label = UI.lbl(box, "准备中…", Rect2(SCREEN.position.x, SCREEN.end.y + 56, SCREEN.size.x, 32), 20, Color("806141"))
	# 奖励
	UI.box(box, Rect2(200, 878, 320, 76), func(ci, sz):
		Sprites.draw(ci, "pop_ad_reward", PS.AD_REWARD)
		Art.item(ci, "fire_4", Vector2(56, sz.y * 0.5), 74))
	UI.lbl(box, "×30 体力", Rect2(290, 878, 220, 76), 36, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 8, Art.INK, true)
	claim_btn = UI.btn(box, Rect2(190, 972, 340, 84), "观看中", "green", _claim, 34)
	claim_btn.name = "ad_claim"
	claim_btn.enabled = false
	label.text = "广告暂不可用，请稍后再试"
	claim_btn.text = "暂不可用"

## 小屏幕：石头外框 + 白天的部落小景（小牙举着篝火吆喝），左右轻摇当「广告」
func _paint_screen(ci: CanvasItem, sz: Vector2) -> void:
	Sprites.draw(ci, "pop_ad_frame", PS.AD_SCREEN)
	var s := Rect2(Vector2(14, 14), sz - Vector2(28, 28))
	Paint.vgrad(ci, Rect2(s.position + Vector2(6, 6), Vector2(s.size.x - 12, s.size.y * 0.6)), Color("8fcbe3"), Color("d8f0e6"))
	ci.draw_set_transform(s.position, 0, Vector2.ONE)
	Paint.hills(ci, s.size.y * 0.66, s.size.x, 20, Color("9cc95a"), 907, s.size.y - 4)
	Paint.hills(ci, s.size.y * 0.8, s.size.x, 12, Color("7fb43a"), 908, s.size.y - 4)
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	Paint.palm(ci, Vector2(s.position.x + 62, s.end.y - 40), 110, 909)
	Paint.palm(ci, Vector2(s.end.x - 60, s.end.y - 46), 90, 910)
	var sway := sin(_t * 3.0) * 6.0
	Paint.mascot(ci, Vector2(s.get_center().x - 70 + sway, s.end.y - 98), 120)
	var fire_c := Vector2(s.get_center().x + 96, s.end.y - 74 - absf(sin(_t * 4.0)) * 10.0)
	ci.draw_circle(fire_c, 52, Color(1, 0.85, 0.4, 0.35))
	Art.item(ci, "fire_4", fire_c, 96)
	# 右上角倒数圆
	if not (_frac >= 1.0):
		var cc := Vector2(sz.x - 52, 52)
		ci.draw_circle(cc, 28, Art.INK)
		ci.draw_circle(cc, 25, Color(0, 0, 0, 0.55))
		ci.draw_arc(cc, 22, -PI * 0.5, -PI * 0.5 + TAU * _frac, 32, Color("ffd23f"), 5.0, true)
	Sprites.draw(ci, "pop_ad_line", PS.AD_SCREEN)

func _process(delta: float) -> void:
	_t += delta
	if screen != null: screen.queue_redraw()

func _claim() -> void:
	G.main.toast("广告暂不可用，请稍后再试")
