extends Control
## 棋盘上的生产器不停往上冒小星星。
## 不存粒子状态：每格几颗星按时间轮转，从物品中下部冒出、边飘边转、淡出。
## 挂在棋盘下面用棋盘本地坐标，不挡点击。

const PER_CELL := 4
const LIFE := 2.6
const GOLD := Color("ffd23f")
const GOLD_LIGHT := Color("fff3b0")

var board: Control
var _t := 0.0
var _cells: Array[int] = []
var _drew := false

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	# 只在棋盘格子范围内画，飘出棋盘的部分裁掉，不盖住上下面板
	clip_contents = true

func _process(delta: float) -> void:
	if board == null or not is_visible_in_tree():
		return
	_t += delta
	_collect()
	if not _cells.is_empty() or _drew:
		_drew = not _cells.is_empty()
		queue_redraw()

func _collect() -> void:
	_cells.clear()
	for i in G.board.size():
		var c: Dictionary = G.board[i]
		if int(c.get("lock", 0)) != 0 or str(c.get("id", "")) == "" or typeof(c.get("ck")) == TYPE_DICTIONARY:
			continue
		if board.hid.has(i) or (board.dragging and board.drag_from == i):
			continue
		if Data.gen_stats(c["id"]).is_empty():
			continue
		_cells.append(i)

func _draw() -> void:
	var cell: float = board.CELL
	for i in _cells:
		var ctr: Vector2 = board.cell_center(i)
		var seed := fmod(float(i) * 0.6180339, 1.0)
		for k in PER_CELL:
			var u := fmod(_t / LIFE + float(k) / float(PER_CELL) + seed, 1.0)
			# 每一轮换个出生点和飘向，看起来不重复
			var round_n := floorf(_t / LIFE + float(k) / float(PER_CELL) + seed)
			var h := fmod(sin(float(i) * 12.9898 + float(k) * 78.233 + round_n * 37.719) * 43758.5453, 1.0)
			h = absf(h)
			# 出生点在格子下半部分，之后竖直往上飘
			var h2 := absf(fmod(h * 7.31, 1.0))
			var start := ctr + Vector2((h - 0.5) * cell * 0.76, h2 * cell * 0.42)
			var p := start + Vector2(0, -u * cell * 0.72)
			var fade := minf(u / 0.15, 1.0) * (1.0 - smoothstep(0.6, 1.0, u))
			fade *= clampf(p.y / (cell * 0.3), 0.0, 1.0) # 靠近棋盘上沿先淡掉
			if fade <= 0.0:
				continue
			# 每颗星大小单独随机，和出生位置无关
			var h3 := absf(fmod(h * 13.77 + 0.29, 1.0))
			var r := lerpf(6.0, 16.0, h3) * (0.55 + 0.55 * sin(PI * minf(u * 1.3, 1.0)))
			var spin := 0.0
			# 外圈黄色光晕衬底，里面是近白的高亮星
			draw_circle(p, r * 1.15, Color(GOLD, 0.22 * fade))
			Sprites.at(self, "board_burst_star", p, r * 1.6 / 12.0, spin, Color(GOLD, 0.75 * fade))
			Sprites.at(self, "board_burst_star", p, r / 12.0, spin, Color(1.0, 1.0, 0.92, fade))
