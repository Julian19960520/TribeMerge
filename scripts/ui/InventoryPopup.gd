extends PopupBase
## 储物洞：山洞石壁上一层层木搁板，每层 5 格，往下无限加层（需求 #33：无限格子、可滚动、每格 +10、行距小）。
## 已开的格子是石壁里凿出的小龛；下一格是可扩建的虚线格（点它或底部按钮扩建）；同一层剩下的位置是碎石堵着。
## 只给看得见的几层建控件（POOL_ROWS 层循环复用），格子再多界面节点数也不变。
const COLS := 5
const ROW_H := 126.0
const POOL_ROWS := 6
const SLOT := 108.0
const GAP_X := 122.0
const FR := Rect2(30, 300, 660, 880)
const VIEW := Rect2(50, 432, 620, 600)
var scroll: Scroller
var slots: Array = []
var shelves: Array = []
var capacity: Label
var next_lbl: Label
var unlock: TButton
var _first_row := -1
var _busy := false

func _ready() -> void:
	UI.box(box, Rect2(0, 0, 720, 1480), _paint_frame)
	UI.title(box, "储物洞", Rect2(230, 322, 260, 64), 42, Color.WHITE)
	var close_btn := UI.hit(box, Rect2(FR.end.x - 56, FR.position.y - 18, 70, 70), close)
	close_btn.extra = func(ci, sz): Paint.close_btn(ci, sz * 0.5, 28)
	capacity = UI.lbl(box, "", Rect2(70, 388, 300, 38), 24, Color("fbe7c0"), HORIZONTAL_ALIGNMENT_LEFT, 5, Color("2a1a10"))
	next_lbl = UI.lbl(box, "", Rect2(350, 388, 300, 38), 20, Color("e0c79c"), HORIZONTAL_ALIGNMENT_RIGHT, 4, Color("2a1a10"))
	scroll = Scroller.new()
	scroll.position = VIEW.position
	scroll.size = VIEW.size
	box.add_child(scroll)
	for r in POOL_ROWS:
		var sh := UI.box(scroll.content, Rect2(0, 0, VIEW.size.x, ROW_H), func(ci, sz): _paint_shelf(ci, sz), false)
		sh.set_meta("row", -1)
		shelves.append(sh)
	for k in POOL_ROWS * COLS:
		var b := UI.btn(scroll.content, Rect2(0, 0, SLOT, SLOT), "", "none", Callable())
		b.set_meta("slot", -1)
		b.extra = func(ci, sz): _paint_slot(ci, sz, int(b.get_meta("slot")))
		b.pressed.connect(func(): _take(int(b.get_meta("slot"))))
		slots.append(b)
	UI.lbl(box, "点物品取回棋盘", Rect2(66, 1054, 320, 36), 24, Color("fbe7c0"), HORIZONTAL_ALIGNMENT_LEFT, 5, Color("2a1a10"))
	UI.lbl(box, "棋盘上的物品拖到皮袋即可存入", Rect2(66, 1094, 330, 30), 18, Color("d8c4a0"), HORIZONTAL_ALIGNMENT_LEFT)
	unlock = UI.btn(box, Rect2(410, 1052, 250, 82), "", "green", _expand, 28)
	unlock.res = Art.AMBER_ICON
	unlock.name = "storage_expand"
	G.changed.connect(_refresh)
	G.board_changed.connect(_refresh)
	_refresh()

## 山洞外框：粗糙石壁 + 洞里暗处；顶上挂皮袋和木牌
func _paint_frame(ci: CanvasItem, _sz: Vector2) -> void:
	ci.draw_colored_polygon(Art.rrect(Rect2(FR.position + Vector2(0, 12), FR.size), 40, 161, 0.0), Color(0, 0, 0, 0.35))
	var outer := Art.rrect(FR, 40, 161, 2.2, 30.0)
	Art.dilate(ci, outer, 3.5, Art.INK)
	ci.draw_colored_polygon(outer, Color("7d776c"))
	# 石块纹理
	for k in 42:
		var q := FR.position + Vector2(Art.srnd(k * 3) * FR.size.x, Art.srnd(k * 5 + 1) * FR.size.y)
		var rr := 6.0 + Art.srnd(k) * 16.0
		ci.draw_colored_polygon(Art.ell(q, Vector2(rr, rr * 0.7), 170 + k, 0.12, 10), Color("6a645a") if k % 2 == 0 else Color("8c867a"))
	# 洞口（暗）
	var cave := Art.rrect(Rect2(VIEW.position - Vector2(10, 62), VIEW.size + Vector2(20, 76)), 30, 162, 1.6, 34.0)
	Art.dilate(ci, cave, 3.0, Art.INK)
	ci.draw_colored_polygon(cave, Color("3a2a1f"))
	Paint.vgrad(ci, Rect2(VIEW.position + Vector2(10, -50), Vector2(VIEW.size.x - 20, 60)), Color("2c2018"), Color("3a2a1f"))
	ci.draw_colored_polygon(Art.rrect(Rect2(VIEW.position.x, VIEW.end.y - 6, VIEW.size.x, 20), 8, 163, 0.0), Color(0, 0, 0, 0.25))
	# 底部石台
	var ledge := Art.rrect(Rect2(FR.position.x + 18, 1040, FR.size.x - 36, 110), 22, 164, 1.0)
	Art.dilate(ci, ledge, 3.0, Art.INK)
	ci.draw_colored_polygon(ledge, Color("5c4636"))
	# 木牌 + 皮袋
	var sign := Art.rrect(Rect2(240, 318, 240, 70), 14, 165, 0.8)
	ci.draw_line(Vector2(270, 300), Vector2(282, 320), Art.ROPE, 5.0, true)
	ci.draw_line(Vector2(450, 300), Vector2(438, 320), Art.ROPE, 5.0, true)
	ci.draw_colored_polygon(Art.rrect(Rect2(240, 326, 240, 70), 14, 165, 0.0), Color(0, 0, 0, 0.3))
	Art.dilate(ci, sign, 3.0, Art.INK)
	ci.draw_colored_polygon(sign, Art.WOOD)
	Art.pl(ci, [Vector2(256, 342), Vector2(360, 338), Vector2(464, 344)], 2.0, Art.WOOD_D, 166)
	Art.pl(ci, [Vector2(256, 370), Vector2(360, 374), Vector2(464, 368)], 2.0, Art.WOOD_D, 167)
	Paint.pouch(ci, Vector2(176, 318), 0.8)

## 一层木搁板：板子横穿整行，两头石钉托着（不再是每格一小截橙条）
func _paint_shelf(ci: CanvasItem, sz: Vector2) -> void:
	var y := SLOT + 4.0
	ci.draw_colored_polygon(Art.rrect(Rect2(4, y + 10, sz.x - 8, 10), 4, 171, 0.0), Color(0, 0, 0, 0.3))
	var plank := Art.rrect(Rect2(2, y, sz.x - 4, 15), 5, 172, 0.5, 60.0)
	Art.dilate(ci, plank, 2.5, Art.INK)
	ci.draw_colored_polygon(plank, Color("a06a36"))
	ci.draw_colored_polygon(Art.rrect(Rect2(8, y + 2, sz.x - 16, 4), 2, 173, 0.0), Color("c98b4a"))
	for x in [14.0, sz.x - 14.0]:
		ci.draw_colored_polygon(Art.poly([Vector2(x - 8, y + 14), Vector2(x + 8, y + 14), Vector2(x + 3, y + 26), Vector2(x - 3, y + 26)], 174), Art.STONE_D)

func _paint_slot(ci: CanvasItem, sz: Vector2, index: int) -> void:
	if index < 0: return
	var cap := G.inv_cap
	var r := Rect2(Vector2(4, 4), sz - Vector2(8, 6))
	if index < cap:
		# 凿出来的石龛
		var niche := Art.rrect(r, 20, 180 + index % 30, 0.6)
		ci.draw_colored_polygon(niche, Color("241912"))
		ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(4, 4), r.size - Vector2(8, 8)), 16, 181 + index % 30, 0.4), Color("4a3628"))
		ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(6, 4), Vector2(r.size.x - 12, 14)), 8, 182, 0.0), Color(0, 0, 0, 0.25))
		Art.outline(ci, niche, 2.0, Color("1a110b"))
		if index < G.inv.size():
			ci.draw_colored_polygon(Art.ell(Vector2(sz.x * 0.5, sz.y - 14), Vector2(32, 6), index % 30, 0.0, 14), Color(0, 0, 0, 0.35))
			Art.item(ci, str(G.inv[index]), sz * 0.5 + Vector2(0, -2), 86)
	elif index == cap:
		# 下一格：虚线框 + 加号 + 价格（点它扩建）
		var niche := Art.rrect(r, 20, 183, 0.6)
		ci.draw_colored_polygon(niche, Color(0.36, 0.27, 0.2, 0.75))
		Art.dashed(ci, Art.rrect(r.grow(-3), 18, 184, 0.0), 9, 6, Color("ffd98a"), 2.5)
		var c := Vector2(sz.x * 0.5, 40)
		ci.draw_circle(c, 18, Art.INK)
		ci.draw_circle(c, 15, Art.MOSS)
		ci.draw_line(c + Vector2(-8, 0), c + Vector2(8, 0), Color.WHITE, 4.0, true)
		ci.draw_line(c + Vector2(0, -8), c + Vector2(0, 8), Color.WHITE, 4.0, true)
		Art.item(ci, Art.AMBER_ICON, Vector2(30, 82), 30, false)
		var f: Font = G.font_body
		var t := str(G.storage_price())
		ci.draw_string_outline(f, Vector2(46, 91), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Art.INK)
		ci.draw_string(f, Vector2(46, 91), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	else:
		# 还没挖开：碎石堵着（离可扩建那格越远越暗）
		var rocks := [[Vector2(36, 70), Vector2(30, 24)], [Vector2(72, 66), Vector2(28, 28)], [Vector2(54, 42), Vector2(26, 20)]]
		for k in rocks.size():
			var e := Art.ell(rocks[k][0], rocks[k][1], 190 + index * 3 + k, 0.12, 12)
			Art.dilate(ci, e, 2.5, Art.INK)
			ci.draw_colored_polygon(e, Color("6f6a63") if k != 1 else Color("847d72"))
			ci.draw_colored_polygon(Art.ell(rocks[k][0] - Vector2(6, 8), rocks[k][1] * 0.35, 195 + k, 0.1, 10), Color(1, 1, 1, 0.12))

func _process(_delta: float) -> void:
	if scroll != null: _layout()

## 至少铺满可视区（后面几层是还没挖开的碎石壁），格子少时洞里也不会空一大片
func _rows() -> int:
	return maxi(int(ceil(float(G.inv_cap + 1) / COLS)), int(ceil(VIEW.size.y / ROW_H)))

func _layout(force := false) -> void:
	var first := maxi(0, int(scroll.offset / ROW_H) - 1)
	if first == _first_row and not force: return
	_first_row = first
	var rows := _rows()
	for r in shelves.size():
		var row := first + r
		var sh: DrawBox = shelves[r]
		sh.visible = row < rows
		sh.position = Vector2(0, 8 + row * ROW_H)
		sh.set_meta("row", row)
	for k in slots.size():
		var index := first * COLS + k
		var b: TButton = slots[k]
		b.visible = index < rows * COLS
		b.position = Vector2(8 + (index % COLS) * GAP_X, 8 + (index / COLS) * ROW_H)
		b.set_meta("slot", index)
		b.modulate = Color(0.72, 0.68, 0.64) if index / COLS > G.inv_cap / COLS else Color.WHITE
		b.queue_redraw()

func _refresh() -> void:
	if scroll == null: return
	capacity.text = "已存 %d / %d 格" % [G.inv.size(), G.inv_cap]
	next_lbl.text = "每扩一格，下一格 +%d" % int(Data.RULES.get("storage_expand_step", 10))
	unlock.text = "%d 扩建" % G.storage_price()
	unlock.enabled = not _busy
	unlock.queue_redraw()
	scroll.set_length(_rows() * ROW_H + 24)
	_layout(true)

func _take(index: int) -> void:
	if _busy: return
	if index == G.inv_cap:
		_expand()
		return
	if index < 0 or index >= G.inv.size(): return
	var to := G.find_empty_near(G.idx(3, 4))
	if to < 0:
		G.main.toast("棋盘满了！")
		return
	var id := str(G.inv[index])
	G.inv.remove_at(index)
	G.board[to]["id"] = id
	G.dirty()
	G.board_changed.emit()
	Sfx.play("pop")

func _expand() -> void:
	if _busy: return
	_busy = true
	_refresh()
	var success := await G.expand_storage()
	if not is_instance_valid(self): return
	_busy = false
	if success:
		_refresh()
		var row := int(G.inv_cap / COLS)
		if row * ROW_H + ROW_H > scroll.offset + scroll.size.y: scroll.jump_to(row * ROW_H + ROW_H + 16 - scroll.size.y)
		_layout(true)
		Sfx.play("merge", 1.2)
	else:
		G.main.toast("扩建失败，请检查琥珀余额或连接")
		_refresh()
