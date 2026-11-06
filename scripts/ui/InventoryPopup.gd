extends PopupBase
## Only visible rows have controls, so expanding storage never creates an unbounded UI tree.
const COLS := 5
const ROW_H := 144.0
const POOL_ROWS := 6
var scroll: Scroller
var slots: Array = []
var capacity: Label
var amber: Label
var unlock: TButton
var _first_row := -1
var _busy := false
func _ready() -> void:
	UI.box(box,Rect2(0,0,720,1480),_paint_frame)
	UI.title(box,"储物洞",Rect2(200,330,320,70),44,Color.WHITE)
	var close_btn := UI.hit(box,Rect2(610,310,70,70),close)
	close_btn.extra = func(ci,sz): Paint.close_btn(ci,sz*0.5,28)
	capacity = UI.lbl(box,"",Rect2(80,412,300,44),26,Color.WHITE)
	UI.icon(box,Art.AMBER_ICON,Vector2(450,434),44)
	amber = UI.lbl(box,"",Rect2(480,412,150,44),26,Color.WHITE)
	scroll = Scroller.new()
	scroll.position = Vector2(54,480)
	scroll.size = Vector2(612,520)
	box.add_child(scroll)
	for k in POOL_ROWS * COLS:
		var b := UI.btn(scroll.content,Rect2(0,0,104,112),"","none",Callable())
		b.set_meta("slot",-1)
		b.extra = func(ci,sz): _paint_slot(ci,sz,int(b.get_meta("slot")))
		b.pressed.connect(func(): _take(int(b.get_meta("slot"))))
		slots.append(b)
	UI.lbl(box,"点击取出物品",Rect2(70,1026,310,42),25,Color.WHITE)
	UI.lbl(box,"棋盘物品拖到皮袋即可存入",Rect2(60,1074,330,38),20,Color("e6e0c8"))
	unlock = UI.btn(box,Rect2(410,1030,244,80),"","green",_expand,28)
	unlock.res = Art.AMBER_ICON
	G.changed.connect(_refresh)
	G.board_changed.connect(_refresh)
	_refresh()
func _paint_frame(ci: CanvasItem, _sz: Vector2) -> void:
	var r := Rect2(30,300,660,860)
	var outer := Art.rrect(r,34,161,1.2)
	Art.fill(ci,outer,Color("657262"),3.5)
	Art.fill(ci,Art.rrect(r.grow(-12),26,165,0.7),Color("8f9a8c"),2,Color("485044"))
	for k in 30:
		var q := r.position + Vector2(Art.srnd(k*3)*r.size.x,Art.srnd(k*5+1)*r.size.y)
		ci.draw_circle(q,3+Art.srnd(k)*5,Color(0,0,0,0.06))
	ci.draw_colored_polygon(Art.rrect(Rect2(50,320,620,150),22,162,0.8),Color("6d7a6c"))
	ci.draw_colored_polygon(Art.rrect(Rect2(54,480,612,520),18,163,0.8),Color("4b3a2e"))
	Paint.pouch(ci,Vector2(360,290),1.0)
func _paint_slot(ci: CanvasItem, sz: Vector2, index: int) -> void:
	if index < 0: return
	var locked := index >= G.inv_cap
	var shape := Art.rrect(Rect2(2,8,sz.x-4,sz.y-12),18,180 + index%30,0.6)
	Art.fill(ci,shape,Color("8a8378") if locked else Color("6a5444"),2.5)
	if locked:
		Paint.glyph(ci,"lock",Vector2(sz.x/2,sz.y/2),1.4)
	elif index < G.inv.size():
		Art.item(ci,str(G.inv[index]),sz/2,90)
	else:
		ci.draw_colored_polygon(Art.ell(Vector2(sz.x/2,sz.y-24),Vector2(34,8),index%30,0,14),Color(0,0,0,0.25))
	var shelf := Rect2(-6,116,116,14)
	Art.fill(ci,Art.rrect(shelf,5,164+index%5,0.4),Art.WOOD,1.5)
func _process(_delta: float) -> void:
	if scroll != null: _layout()
func _layout(force := false) -> void:
	var first := maxi(0,int(scroll.offset/ROW_H)-1)
	if first == _first_row and not force: return
	_first_row = first
	for k in slots.size():
		var index := first * COLS + k
		var b: TButton = slots[k]
		b.visible = index <= G.inv_cap
		b.position = Vector2(14 + (index%COLS)*120,12+(index/COLS)*ROW_H)
		b.set_meta("slot",index)
		b.queue_redraw()
func _refresh() -> void:
	if scroll == null: return
	capacity.text = "已存 %d / %d 格" % [G.inv.size(),G.inv_cap]
	amber.text = str(G.amber)
	unlock.text = "%d 扩充" % G.storage_price()
	unlock.enabled = not _busy
	unlock.queue_redraw()
	scroll.set_length(ceilf(float(G.inv_cap+1)/COLS)*ROW_H+12)
	_layout(true)
func _take(index: int) -> void:
	if _busy: return
	if index == G.inv_cap:
		_expand()
		return
	if index < 0 or index >= G.inv.size(): return
	var to := G.find_empty_near(G.idx(3,4))
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
		var row := int((G.inv_cap-1)/COLS)
		if row*ROW_H+132 > scroll.offset+scroll.size.y: scroll.jump_to(row*ROW_H+144-scroll.size.y)
		_layout(true)
		Sfx.play("merge",1.2)
	else:
		G.main.toast("扩充失败，请检查琥珀余额或连接")
		_refresh()
