extends Control
## 好运爆发：生产器一下出了高 2~4 级的物品。
## 生产器先闪一圈金光 → 物品照常飞过去 → 落点炸开旋转金芒、两道冲击波、一圈星星，「+N」弹出后上飘消失。
## 只管表现，挂在棋盘下面用棋盘本地坐标；播完自己删掉，不挡点击。

const GEN_FLASH := 0.3
const LAND := 0.28
const TOTAL := 1.7
const GOLD := Color("ffd23f")
const GOLD_LIGHT := Color("fff3b0")

var from_p := Vector2.ZERO
var to_p := Vector2.ZERO
var cell := 96.0
var steps := 3
var _t := 0.0
var _seed := 0.0

static func play(board: Control, from_i: int, to_i: int, lift: int = 3) -> void:
	var fx = load("res://scripts/ui/board/LuckyDropFx.gd").new()
	fx.from_p = board.cell_center(from_i)
	fx.to_p = board.cell_center(to_i)
	fx.cell = board.CELL
	fx.steps = lift
	board.add_child(fx)

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_seed = randf() * TAU
	z_index = 5

func _process(delta: float) -> void:
	_t += delta
	if _t >= TOTAL:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	_draw_gen_flash()
	var t := _t - LAND
	if t < 0.0:
		return
	var span := TOTAL - LAND
	var k := t / span
	_draw_rays(t, k)
	_draw_rings(t)
	_draw_stars(t)
	_draw_cell_flash(t)
	_draw_label(t)

## 生产器那格：金圈一放一收
func _draw_gen_flash() -> void:
	if _t > GEN_FLASH:
		return
	var k := _t / GEN_FLASH
	var r := cell * (0.4 + 0.35 * k)
	draw_arc(from_p, r, 0.0, TAU, 40, Color(GOLD, 1.0 - k), 8.0 * (1.0 - k) + 2.0, true)
	draw_circle(from_p, r * 0.8, Color(GOLD_LIGHT, 0.35 * (1.0 - k)))

## 旋转的金芒，先猛长出来再慢慢淡掉
func _draw_rays(t: float, k: float) -> void:
	var grow := minf(t / 0.18, 1.0)
	var fade := clampf(1.0 - (k - 0.45) / 0.55, 0.0, 1.0)
	if fade <= 0.0:
		return
	var n := 12
	var length := cell * (0.55 + 1.15 * grow) * (0.85 + 0.075 * float(steps))
	var spin := _seed + t * 1.6
	for i in n:
		var a := spin + TAU * float(i) / float(n)
		var half := 0.11 if i % 2 == 0 else 0.07
		var reach := length * (1.0 if i % 2 == 0 else 0.72)
		var pts := PackedVector2Array([
			to_p + Vector2(cos(a - half), sin(a - half)) * cell * 0.22,
			to_p + Vector2(cos(a), sin(a)) * reach,
			to_p + Vector2(cos(a + half), sin(a + half)) * cell * 0.22,
		])
		var cols := PackedColorArray([Color(GOLD_LIGHT, 0.75 * fade), Color(GOLD, 0.0), Color(GOLD_LIGHT, 0.75 * fade)])
		draw_polygon(pts, cols)
	draw_circle(to_p, cell * 0.62, Color(GOLD, 0.28 * fade))

## 两道冲击波，一前一后
func _draw_rings(t: float) -> void:
	for j in 2:
		var rt := (t - 0.12 * float(j)) / 0.55
		if rt < 0.0 or rt > 1.0:
			continue
		var e := 1.0 - pow(1.0 - rt, 3.0)
		var r := cell * (0.35 + 1.25 * e)
		draw_arc(to_p, r, 0.0, TAU, 56, Color(GOLD_LIGHT if j == 0 else GOLD, 1.0 - rt), 10.0 * (1.0 - rt) + 1.5, true)

## 一圈星星往外迸，带点下坠
func _draw_stars(t: float) -> void:
	var st := t / 0.95
	if st > 1.0:
		return
	var n := 14
	for i in n:
		var a := _seed * 1.7 + TAU * float(i) / float(n)
		var speed := 1.0 + 0.45 * sin(float(i) * 2.3 + _seed)
		var e := 1.0 - pow(1.0 - st, 2.0)
		var p := to_p + Vector2(cos(a), sin(a)) * cell * (0.3 + 1.35 * e * speed) + Vector2(0, 40.0 * st * st)
		var r := (11.0 if i % 3 == 0 else 7.0) * (1.0 - st) + 2.0
		var col := Color(GOLD_LIGHT if i % 2 == 0 else GOLD, 1.0 - st)
		Sprites.at(self, "board_burst_star", p, r / 12.0 * 1.6, a + t * 6.0, col)

## 落地瞬间那格一下白亮
func _draw_cell_flash(t: float) -> void:
	var k := t / 0.25
	if k > 1.0:
		return
	var sz := Vector2(cell, cell) * (0.9 + 0.2 * k)
	draw_rect(Rect2(to_p - sz * 0.5, sz), Color(1, 1, 0.85, 0.7 * (1.0 - k)))

## 「+N」弹出、停一下、上飘淡出；级数越高字越大
func _draw_label(t: float) -> void:
	var font: Font = G.font_title
	if font == null:
		return
	var pop := clampf(t / 0.22, 0.0, 1.0)
	var grow := lerpf(0.4, 1.3, 1.0 - pow(1.0 - pop, 3.0)) if pop < 1.0 else 1.3 - 0.3 * clampf((t - 0.22) / 0.12, 0.0, 1.0)
	var rise := clampf((t - 0.75) / 0.65, 0.0, 1.0)
	var alpha := 1.0 - rise
	if alpha <= 0.0:
		return
	var font_size := int(round((34.0 + 6.0 * float(steps)) * grow))
	var tag := TextCatalog.resolve("+%d" % steps)
	var base := to_p + Vector2(-cell, -cell * 0.62 - 50.0 * rise)
	var w := cell * 2.0
	draw_string_outline(font, base, TextCatalog.resolve(tag), HORIZONTAL_ALIGNMENT_CENTER, w, font_size, 9, Color(Art.INK, alpha))
	draw_string(font, base, TextCatalog.resolve(tag), HORIZONTAL_ALIGNMENT_CENTER, w, font_size, Color(GOLD, alpha))
