extends RefCounted
## 锁格密林的树根位置。
## 以前每格一团固定的三四棵树，格子边界一眼就看得出来；现在整块棋盘按错位网格撒树根，
## 每个点再抖一抖，和格子边界无关，树的疏密处处一样。每棵树归树根所在的格子：
## 格子解锁时它的树一起消失。挨着空格（或棋盘边）的树往里收一点、必要时缩小一点，
## 树冠只越界几像素，不会盖住旁边已解锁的格子。
## 纯静态、固定种子：同一个棋盘尺寸每次排出来都一样。

const CELL := 96.0
## 树的图块（rocks_N.png 的一格，128×128）里树根的位置；树按 BAKE_SCALE 烘焙
const ROOT := Vector2(64, 112)
const TILE := 128.0
const VARIANTS := 63
## 网格间距：横向 DX、纵向 DY，奇数行错开半格。和 96 的格子不成整数倍，行列不会和格子对齐。
const DX := 76.0
const DY := 54.0
## 在烘焙尺寸下（k = 1）树冠左右半宽、树根到树冠顶的高度
const HALF_W := 52.0
const TOP_H := 100.0
## 挨着空格时树冠最多越界几像素
const SPILL_SIDE := 8.0
const SPILL_UP := 16.0
const MIN_K := 0.6

static var _key := Vector2i(-1, -1)
static var _by_cell: Array = []

static func _r(seed: int) -> float:
	var v := sin(float(seed) * 12.9898 + 4.1414) * 43758.5453
	return v - floor(v)

## 每格一个数组，元素是 [格内树根 Vector2, 图块序号 int, 缩放 k float]
static func trees(cols: int, rows: int) -> Array:
	if _key != Vector2i(cols, rows):
		_build(cols, rows)
	return _by_cell

static func _build(cols: int, rows: int) -> void:
	_key = Vector2i(cols, rows)
	_by_cell = []
	for _i in cols * rows:
		_by_cell.append([])
	var w := float(cols) * CELL
	var h := float(rows) * CELL
	var row := 0
	var y := DY * 0.45
	while y < h + DY:
		var x := -DX * 0.5 + (DX * 0.5 if row % 2 == 1 else 0.0) + (_r(row * 7 + 1) - 0.5) * DX * 0.3
		var col := 0
		while x < w + DX:
			var s := row * 1013 + col * 37 + 11
			var p := Vector2(x + (_r(s) - 0.5) * DX * 0.55, y + (_r(s + 1) - 0.5) * DY * 0.6)
			if p.x >= 0.0 and p.x < w and p.y >= 0.0 and p.y < h:
				var cx := int(p.x / CELL)
				var cy := int(p.y / CELL)
				var k := 0.66 + _r(s + 3) * 0.22
				_by_cell[cy * cols + cx].append([p - Vector2(cx, cy) * CELL, int(_r(s + 2) * VARIANTS) % VARIANTS, k])
			x += DX
			col += 1
		y += DY
		row += 1
	_fill_gaps(cols, rows)
	for list in _by_cell:
		list.sort_custom(func(a, b): return float(a[0].y) < float(b[0].y))

## 错位网格加抖动难免有几处稀；而且树冠长在树根上方，一格的下半截平时靠下面那格的树冠盖着，
## 下面那格一解锁，这里就露出空地。所以每格只用自己的树检查一遍：按树冠大致的圆
## （树根上方 CANOPY_UP·k，半径 CANOPY_R·k）扫这一格，哪里没被盖住就在这格里补一棵。
## 这样不管邻格锁没锁，每个锁格自己都是满的；补的树位置跟着空隙走，不会排成格子的样子。
const CANOPY_UP := 56.0
const CANOPY_R := 37.0
const GAP_STEP := 6.0
## 离最近的树冠中心超过 CANOPY_R·k·GAP_SLACK 才算空地（树冠边缘本来就是锯齿的，小缝不补）
const GAP_SLACK := 1.9
## 每格最下面这一条是树干和影子，不要求树冠盖住
const TRUNK_BAND := 30.0
static func _fill_gaps(cols: int, rows: int) -> void:
	for ci in cols * rows:
		var list: Array = _by_cell[ci]
		var added := 0
		var y := GAP_STEP * 0.5
		while y < CELL - TRUNK_BAND:
			var x := GAP_STEP * 0.5
			while x < CELL:
				var q := Vector2(x, y)
				if not _covered(q, list):
					var s := 70001 + ci * 977 + added * 97
					var k := 0.7 + _r(s) * 0.14
					var p := Vector2(clampf(q.x + (_r(s + 1) - 0.5) * 10.0, 2.0, CELL - 2.0), minf(q.y + CANOPY_UP * k, CELL - 3.0))
					list.append([p, int(_r(s + 2) * VARIANTS) % VARIANTS, k])
					added += 1
				x += GAP_STEP
			y += GAP_STEP

static func _covered(q: Vector2, list: Array) -> bool:
	for t in list:
		var k: float = t[2]
		var c: Vector2 = t[0] - Vector2(0, CANOPY_UP * k)
		if c.distance_squared_to(q) <= pow(CANOPY_R * k * GAP_SLACK, 2.0):
			return true
	return false

## 按四邻是不是空着把树根往格子里收：返回 [格内树根, k]
static func place(t: Array, open_l: bool, open_r: bool, open_u: bool, open_d: bool) -> Array:
	var p: Vector2 = t[0]
	var k: float = t[2]
	if open_u:
		k = minf(k, maxf(MIN_K, (p.y + SPILL_UP) / TOP_H))
		p.y = maxf(p.y, TOP_H * k - SPILL_UP)
	var hw := HALF_W * k
	if open_l:
		p.x = maxf(p.x, hw - SPILL_SIDE)
	if open_r:
		p.x = minf(p.x, CELL - hw + SPILL_SIDE)
	if open_d:
		p.y = minf(p.y, CELL - 6.0)
	return [p, k]

static func region(variant: int) -> Rect2:
	return Rect2((variant % 9) * TILE, (variant / 9) * TILE, TILE, TILE)

## 画一棵树：cell_pos 是格子左上角，root 是格内树根
static func draw_tree(ci: CanvasItem, tex: Texture2D, cell_pos: Vector2, root: Vector2, variant: int, k: float) -> void:
	ci.draw_texture_rect_region(tex, Rect2(cell_pos + root - ROOT * k, Vector2(TILE, TILE) * k), region(variant))
