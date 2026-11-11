extends PopupBase
## 看广告领体力：中间一堆体力在转动的光芒里上下浮，下面写清楚能领多少、按钮去看广告。
## 广告接口不可用时按钮置灰并说明原因，绝不假装看完发奖。
const R := Rect2(60, 400, 600, 700)
const REWARD := 30
var label: Label
var claim_btn: TButton
var stage: DrawBox
var _t := 0.0

func _ready() -> void:
	Popups.frame(self, R, "看广告领体力", Art.TEAL)
	stage = UI.box(box, Rect2(R.position.x + 40, R.position.y + 56, R.size.x - 80, 330), _paint_stage, false)
	UI.lbl(box, "免费补给", Rect2(R.position.x + 40, R.position.y + 402, R.size.x - 80, 40), 28, Color("7a5a3a"))
	UI.lbl(box, "看一段短广告，部落送你 %d 点体力" % REWARD, Rect2(R.position.x + 40, R.position.y + 444, R.size.x - 80, 36), 23, Color("8a6a48"))
	label = UI.lbl(box, "准备中…", Rect2(R.position.x + 40, R.position.y + 494, R.size.x - 80, 32), 21, Color("b0603a"))
	claim_btn = UI.btn(box, Rect2(190, R.position.y + 548, 340, 88), "看广告", "green", _claim, 36)
	claim_btn.name = "ad_claim"
	claim_btn.extra = _paint_play
	claim_btn.enabled = false
	claim_btn.text = "暂不可用"
	label.text = "广告暂不可用，请稍后再试"

## 光芒 + 浮动的体力堆 + 大号「+30」
func _paint_stage(ci: CanvasItem, sz: Vector2) -> void:
	var c := Vector2(sz.x * 0.5, sz.y * 0.48)
	var plate := Art.rrect(Rect2(Vector2.ZERO, sz), 26, 930, 0.4)
	Art.dilate(ci, plate, 3.0, Art.INK)
	var cols := PackedColorArray()
	for q in plate: cols.append(Color("6cc2d2").lerp(Color("2f7f8f"), clampf(q.y / sz.y, 0.0, 1.0)))
	ci.draw_polygon(plate, cols)
	var rot := _t * 0.35
	for k in 14:
		var a := rot + TAU * float(k) / 14.0
		var ray := PackedVector2Array([c, c + Vector2.from_angle(a - 0.09) * 260.0, c + Vector2.from_angle(a + 0.09) * 260.0])
		for part in Geometry2D.intersect_polygons(ray, plate):
			ci.draw_colored_polygon(part, Color(1, 0.95, 0.6, 0.16))
	Sprites.at(ci, "ev_disc", c, 1.6, 0.0, Color(1, 0.92, 0.55, 0.45))
	var bob := sin(_t * 2.4) * 8.0
	Art.item(ci, "fire_5", c + Vector2(0, bob - 6), 190)
	for k in 5:
		var a := _t * 0.8 + TAU * float(k) / 5.0
		var p := c + Vector2(cos(a) * 130, sin(a) * 70)
		ci.draw_colored_polygon(Art.star_pts(p, 8, 3, 4, k), Color(1, 1, 0.85, 0.7 + 0.3 * sin(_t * 3 + k)))
	var text := "+%d" % REWARD
	var f: Font = G.font_title
	var fs := 64
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(sz.x * 0.5 - tw * 0.5 + 40, sz.y - 30)
	Sprites.at(ci, "board_bolt", at + Vector2(-34, -22), 2.4)
	ci.draw_string_outline(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 12, Art.INK)
	ci.draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffe27a"))
	var edge := plate.duplicate()
	edge.append(plate[0])
	ci.draw_polyline(edge, Art.INK, 4.0, true)

## 按钮左边的播放三角
func _paint_play(ci: CanvasItem, sz: Vector2) -> void:
	if not claim_btn.enabled: return
	var c := Vector2(54, sz.y * 0.5 - 2)
	ci.draw_circle(c, 20, Color(1, 1, 1, 0.9))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -10), c + Vector2(11, 0), c + Vector2(-6, 10)]), Color("4f8a1f"))

func _process(delta: float) -> void:
	_t += delta
	if stage != null: stage.queue_redraw()

func _claim() -> void:
	G.main.toast("广告暂不可用，请稍后再试")
