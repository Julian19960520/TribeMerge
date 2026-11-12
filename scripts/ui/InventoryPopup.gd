extends PopupBase
const PS := preload("res://scripts/sprites/popups.gd")
## 储物洞：山洞石壁上一层层木搁板，每层 5 格，往下无限加层；同排同价，每排 +10 琥珀。
## 已开的格子是石壁里凿出的小龛；下一格是可扩建的虚线格（点它或底部按钮扩建）；同一层剩下的位置是碎石堵着。
## 只给看得见的几层建控件（POOL_ROWS 层循环复用），格子再多界面节点数也不变。
const COLS := Data.STORAGE_COLS
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
	# 石壁、石块纹理、洞口
	Sprites.draw(ci, "pop_inv_frame", PS.INV_FRAME)
	Paint.vgrad(ci, Rect2(VIEW.position + Vector2(10, -50), Vector2(VIEW.size.x - 20, 60)), Color("2c2018"), Color("3a2a1f"))
	# 洞底阴影 + 底部石台
	Sprites.draw(ci, "pop_inv_ledge", PS.INV_LEDGE)
	# 木牌 + 皮袋
	Sprites.draw(ci, "pop_inv_sign", PS.INV_SIGN)
	Paint.pouch(ci, Vector2(176, 318), 0.8)

## 一层木搁板：板子横穿整行，两头石钉托着（不再是每格一小截橙条）
func _paint_shelf(ci: CanvasItem, _sz: Vector2) -> void:
	Sprites.draw(ci, "pop_inv_shelf", PS.INV_SHELF)

func _paint_slot(ci: CanvasItem, sz: Vector2, index: int) -> void:
	if index < 0: return
	var cap := G.inv_cap
	var r := Rect2(Vector2(4, 4), sz - Vector2(8, 6))
	if index < cap:
		# 凿出来的石龛
		Sprites.draw(ci, "pop_inv_niche", r)
		if index < G.inv.size():
			Sprites.at(ci, "pop_spot_shadow", Vector2(sz.x * 0.5, sz.y - 14), 1.0, 0.0, Color(0, 0, 0, 0.35))
			Art.item(ci, str(G.inv[index]), sz * 0.5 + Vector2(0, -2), 86)
	elif index == cap:
		# 下一格：虚线框 + 加号 + 价格（点它扩建）
		Sprites.draw(ci, "pop_inv_next", r)
		Art.item(ci, Art.AMBER_ICON, Vector2(30, 82), 30, false)
		var f: Font = G.font_body
		var t := str(G.rules.progression.storage_price())
		ci.draw_string_outline(f, Vector2(46, 91), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Art.INK)
		ci.draw_string(f, Vector2(46, 91), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	else:
		# 还没挖开：碎石堵着（离可扩建那格越远越暗）
		Sprites.draw(ci, "pop_inv_rocks", r)

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
	next_lbl.text = "同排同价，每排 +%d" % int(Data.RULES.get("storage_expand_step", 10))
	unlock.text = "%d 扩建" % G.rules.progression.storage_price()
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
	var to := G.rules.board.find_empty_near(G.rules.board.idx(3, 4))
	if to < 0:
		G.main.toast("棋盘满了！")
		return
	var result: Dictionary = Replay.perform("inventory", {"index": index})
	if result.has("error"): G.main.toast(str(result["error"]))
	else: Sfx.play("pop")

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
