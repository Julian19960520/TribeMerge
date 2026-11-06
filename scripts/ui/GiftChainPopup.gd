extends PopupBase
## 礼包链面板：一串用绳子串起来的礼包，一次看 3 个。只有最上面（队首）那个能领 / 买；
## 下面两个是锁着的预览。领完队列往上移一格，底下露出新的。进度以服务器为准（scripts/net/GiftChain.gd）。

const Net := preload("res://scripts/net/GiftChain.gd")
const Meme := preload("res://scripts/Meme.gd")

const R := Rect2(36, 210, 648, 1080)
const SLOT0 := 372.0
const CARD_H := 236.0
const GAP := 52.0
const CARD_X := 70.0
const CARD_W := 580.0
## 队首卡片的陶土色、锁着的预览压暗
const BODY := Color("b8743e")
const BODY_LOCK := Color("7d5a3e")
const INNER := Color("f3e2c0")
const INNER_LOCK := Color("c9b391")

var chain: Node
var _cards: Array = []   # [{"node": Control, "i": 步数}]
var _shown := -1
var _shown_cycle := -1
var _holder: Control
var _status: Label
var _time: Label
var _prog: Label
var _anim := false

static func pop_open() -> PopupBase:
	var p = load("res://scripts/ui/GiftChainPopup.gd").new()
	p._setup()
	G.main._attach_popup(p)
	return p

func _setup() -> void:
	chain = Net.inst()
	var r := R
	Popups.frame(self, r, "部落礼包链", Art.CLAY, "meme")
	_prog = UI.lbl(box, "", Rect2(r.position.x + 40, r.position.y + 52, 260, 36), 22, Color("6b4a2a"), HORIZONTAL_ALIGNMENT_LEFT)
	_time = UI.lbl(box, "", Rect2(r.end.x - 320, r.position.y + 52, 280, 36), 22, Color("6b4a2a"), HORIZONTAL_ALIGNMENT_RIGHT)
	var tip := UI.lbl(box, "按顺序领取 · 越往后越丰厚", Rect2(r.position.x, r.position.y + 90, r.size.x, 34), 20, Color("8a6a4a"))
	tip.modulate.a = 0.9
	# 绳子（在卡片后面）
	UI.box(box, Rect2(0, 0, 720, 1480), _paint_rope, false)
	_holder = Control.new()
	_holder.mouse_filter = MOUSE_FILTER_IGNORE
	_holder.clip_contents = true
	_holder.position = Vector2(0, SLOT0 - 24)
	_holder.size = Vector2(720, 3 * CARD_H + 2 * GAP + 40)
	box.add_child(_holder)
	_status = UI.lbl(box, "", Rect2(r.position.x + 20, r.end.y - 76, r.size.x - 40, 50), 22, Color("8a5a30"))
	chain.updated.connect(_on_updated)
	_render()
	chain.fetch()

func _process(_d: float) -> void:
	if Engine.get_process_frames() % 20 == 0 and _time != null:
		var left: float = chain.ends_at() - G.now()
		_time.text = ("本期剩余 %s" % _fmt_left(left)) if chain.ok and left > 0.0 else ""
		if chain.ok and left <= 0.0 and not chain.loading:
			chain.fetch()

## 奖励一排：卡片里 76～500（右边留给石锁）
static func _cell(cnt: int) -> float:
	return minf(118.0, 424.0 / maxf(1.0, float(cnt)))

static func _x0(cnt: int) -> float:
	return 76.0 + (424.0 - _cell(cnt) * cnt) * 0.5

static func _fmt_left(s: float) -> String:
	var t := int(maxf(s, 0.0))
	if t >= 86400:
		return "%d天%d小时" % [t / 86400, (t % 86400) / 3600]
	return "%02d:%02d:%02d" % [t / 3600, (t % 3600) / 60, t % 60]

# ---------------------------------------------------------------- 渲染

func _slot_y(k: int) -> float:
	return 24.0 + k * (CARD_H + GAP)

func _render() -> void:
	for c in _cards:
		(c["node"] as Node).queue_free()
	_cards.clear()
	var h: int = chain.head()
	_shown = h
	_shown_cycle = int(chain.info.get("cycle", -1))
	for k in 3:
		var i := h + k
		if i >= chain.total():
			break
		var n := _card(i, k == 0)
		n.position = Vector2(CARD_X, _slot_y(k))
		_cards.append({"node": n, "i": i})
	_refresh_text()

func _refresh_text() -> void:
	var h: int = mini(chain.head(), chain.total())
	_prog.text = "进度 %d / %d" % [h, chain.total()]
	if not chain.online() or (not chain.ok and chain.fetched_once):
		_status.text = "需要联网才能领取和购买"
	elif not chain.ok:
		_status.text = "正在连接部落…"
	elif chain.done():
		_status.text = "本期礼包全部领完啦！下期 %s 后刷新" % _fmt_left(chain.ends_at() - G.now())
	else:
		_status.text = ""

func _on_updated() -> void:
	if not is_inside_tree() or _anim:
		return
	var h: int = chain.head()
	var cy := int(chain.info.get("cycle", -1))
	if h == _shown + 1 and cy == _shown_cycle and not _cards.is_empty():
		_advance()
	else:
		# 换期 / 别处领过 / 联网状态变了：整个重画
		_render()

## 队列前移：队首飞出，后面的往上挪一格，底下露出新的一个
func _advance() -> void:
	_anim = true
	var old: Array = _cards.duplicate()
	_cards.clear()
	var first: Control = old[0]["node"]
	first.pivot_offset = first.size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(first, "scale", Vector2(1.08, 1.08), 0.14).set_trans(Tween.TRANS_SINE)
	tw.tween_property(first, "modulate:a", 0.0, 0.3).set_delay(0.12)
	tw.tween_property(first, "position:x", first.position.x + 760.0, 0.36).set_delay(0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	for k in range(1, old.size()):
		var n: Control = old[k]["node"]
		tw.tween_property(n, "position:y", _slot_y(k - 1), 0.42).set_delay(0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var ni: int = chain.head() + 2
	var fresh: Control = null
	if ni < chain.total():
		fresh = _card(ni, false)
		fresh.position = Vector2(CARD_X, _slot_y(3))
		fresh.modulate.a = 0.0
		tw.tween_property(fresh, "position:y", _slot_y(2), 0.42).set_delay(0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(fresh, "modulate:a", 1.0, 0.3).set_delay(0.3)
	Sfx.play("whoosh")
	tw.chain().tween_callback(func():
		first.queue_free()
		for k in range(1, old.size()):
			(old[k]["node"] as Node).queue_free()
		if fresh != null:
			fresh.queue_free()
		_anim = false
		_render()
		# 新队首解锁：弹一下
		if not _cards.is_empty():
			var c: Control = _cards[0]["node"]
			c.pivot_offset = c.size * 0.5
			c.scale = Vector2(0.94, 0.94)
			c.create_tween().tween_property(c, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			Sfx.play("pop"))

func _card(i: int, live: bool) -> Control:
	var s: Dictionary = chain.step(i)
	var rw: Array = s.get("rewards", [])
	var paid := Net.is_paid(s)
	var n := Control.new()
	n.mouse_filter = MOUSE_FILTER_IGNORE
	n.size = Vector2(CARD_W, CARD_H)
	_holder.add_child(n)
	UI.box(n, Rect2(Vector2.ZERO, n.size), func(ci, sz): _paint_card(ci, sz, i, live, paid, rw.size()))
	# 步数徽章
	UI.lbl(n, str(i + 1), Rect2(4, 6, 60, 56), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK, true)
	var tag := str(s.get("tag", ""))
	if tag != "":
		var tl := UI.lbl(n, tag, Rect2(CARD_W - 150, -10, 150, 40), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
		tl.rotation = 0.06
	# 奖励
	var icons: Array = []
	var cnt := rw.size()
	var cell := _cell(cnt)
	var x0 := _x0(cnt)
	for k in cnt:
		var c := Vector2(x0 + cell * (k + 0.5), 92)
		icons.append(c)
		UI.lbl(n, "×%d" % int(rw[k][1]), Rect2(c.x - 60, 128, 120, 34), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK, true)
	n.set_meta("icons", icons)
	# 按钮
	var br := Rect2(CARD_W * 0.5 - 130, CARD_H - 70, 260, 66)
	if live:
		var online: bool = chain.online() and chain.ok
		var b := UI.btn(n, br, "", "orange" if paid else "green", Callable(), 32)
		b.title_font = not paid
		if not online:
			b.text = "需要联网"
			b.enabled = false
		else:
			b.text = Net.price_text(s) if paid else "免费领取"
			b.enabled = not chain.busy
		b.pressed.connect(func(): _press(i, n, b))
		b.name = "gift_btn"
	else:
		var lk := UI.lbl(n, Net.price_text(s) if paid else "免费", Rect2(br.position.x, br.position.y + 8, br.size.x, 50), 26,
			Color("f3e2c0"), HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK, not paid)  # 标题字体没有 ¥，价格用正文字体
		lk.modulate.a = 0.85
	return n

func _paint_card(ci: CanvasItem, sz: Vector2, i: int, live: bool, paid: bool, cnt: int) -> void:
	var r := Rect2(Vector2.ZERO, sz - Vector2(0, 8))
	ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(0, 8), r.size), 22, 700 + i, 0.0), Color(0, 0, 0, 0.32))
	var b := Art.rrect(r, 22, 710 + i, 1.0)
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, BODY if live else BODY_LOCK)
	# 木纹
	for k in 4:
		var y := 16.0 + k * 52.0 + Art.srnd(i * 7 + k) * 10.0
		Art.ln(ci, Vector2(24, y), Vector2(sz.x - 24, y + (Art.srnd(i + k * 3) - 0.5) * 6.0), 1.6, Color(0.25, 0.12, 0.05, 0.18), i * 10 + k)
	var ir := Rect2(70, 22, sz.x - 140, 148)
	var inner := Art.rrect(ir, 16, 720 + i, 0.6)
	ci.draw_colored_polygon(inner, INNER if live else INNER_LOCK)
	Art.dashed(ci, Art.rrect(ir.grow(-6), 12, 730 + i, 0.0), 6, 5, Color(0.55, 0.32, 0.1, 0.4), 1.6)
	# 步数徽章（陶土圆片）
	var badge := Art.ell(Vector2(34, 34), Vector2(26, 24), 740 + i, 0.05, 16)
	Art.dilate(ci, badge, 2.6, Art.INK)
	ci.draw_colored_polygon(badge, Art.CLAY if paid else Color("8a6a3a"))
	# 奖励图标
	var s: Dictionary = chain.step(i)
	var rw: Array = s.get("rewards", [])
	var cell := _cell(cnt)
	var x0 := _x0(cnt)
	for k in cnt:
		var id := str(rw[k][0])
		var c := Vector2(x0 + cell * (k + 0.5), 86)
		Art.item(ci, Art.AMBER_ICON if id.begins_with("amber_") else id, c, minf(96.0, cell - 10.0))
	# 标签印章
	if str(s.get("tag", "")) != "":
		var seal := Art.rrect(Rect2(sz.x - 150, -8, 150, 38), 12, 750 + i, 0.8)
		Art.fill(ci, seal, Art.CLAY if live else Color("8a4a2e"), 2.6)
	if not live:
		# 锁着：压暗 + 绳子捆上 + 石锁
		ci.draw_colored_polygon(b, Color(0.12, 0.06, 0.02, 0.38))
		Art.ln(ci, Vector2(sz.x * 0.5 - 6, 0), Vector2(sz.x * 0.5 + 6, r.size.y), 7.0, Art.ROPE, i * 3 + 1)
		Art.ln(ci, Vector2(sz.x * 0.5 - 6, 0), Vector2(sz.x * 0.5 + 6, r.size.y), 2.0, Color(0.45, 0.3, 0.12, 0.8), i * 3 + 2)
		var lc := Vector2(sz.x - 36, r.size.y * 0.5 + 6)
		var plate := Art.ell(lc, Vector2(28, 28), 760 + i, 0.06, 14)
		Art.dilate(ci, plate, 2.6, Art.INK)
		ci.draw_colored_polygon(plate, Art.STONE)
		Paint.glyph(ci, "lock", lc, 1.5)

## 卡片之间串着的两股绳子 + 绳结
func _paint_rope(ci: CanvasItem, _sz: Vector2) -> void:
	var top := SLOT0 - 24.0
	for k in 3:
		var y0 := top + _slot_y(k) + CARD_H - 30.0
		var y1 := top + _slot_y(k + 1) + 20.0
		if k == 2:
			y1 = R.end.y - 90.0
		for side in [-1.0, 1.0]:
			var x: float = CARD_X + CARD_W * 0.5 + side * 200.0
			Art.ln(ci, Vector2(x, y0), Vector2(x + side * 4.0, y1), 8.0, Art.INK, k * 4 + int(side))
			Art.ln(ci, Vector2(x, y0), Vector2(x + side * 4.0, y1), 5.0, Art.ROPE, k * 4 + int(side) + 1)
			var m := Vector2(x + side * 2.0, (y0 + y1) * 0.5)
			var knot := Art.ell(m, Vector2(9, 8), 770 + k * 2 + int(side), 0.08, 10)
			Art.dilate(ci, knot, 2.0, Art.INK)
			ci.draw_colored_polygon(knot, Color("c9a35e"))

# ---------------------------------------------------------------- 操作

func _press(i: int, card: Control, b: TButton) -> void:
	if chain.busy or _anim:
		return
	var s: Dictionary = chain.step(i)
	b.enabled = false
	b.queue_redraw()
	# 先记下奖励图标的位置（队列前移会把卡片挪走）
	var pts: Array = []
	for c in card.get_meta("icons", []):
		pts.append(card.get_global_transform() * (c as Vector2))
	var r: Dictionary
	if Net.is_paid(s):
		r = await chain.buy(i)
	else:
		r = await chain.claim(i)
	if not r.get("ok", false):
		G.main.toast(str(r.get("message", "连不上服务器，请稍后再试")))
		if is_instance_valid(b):
			b.enabled = true
			b.queue_redraw()
		return
	var rw: Array = r.get("rewards", [])
	Rewards.grant(rw, func(k): return pts[k] if k < pts.size() else Vector2(360, 700))
	if Net.is_paid(s):
		G.main.toast("演示版本：%s 礼包已到账" % Net.price_text(s))
