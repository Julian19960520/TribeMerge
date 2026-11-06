extends Control
## 棋盘订单栏里、主角卡左边的「篝火竞速」入口（参加与否都在）。
## 没到 5 级：锁着，写「5级解锁」。没在比：一串香蕉 +「匹配」。比赛中：我的香蕉数、名次。比完：「领奖!」。
## 交付订单时 BoardScreen 调 fly_from()：香蕉从订单卡飞进这里。比完一局自动弹结算；领完奖弹「再来一局」。

const RaceNet := preload("res://scripts/net/Race.gd")
const RacePopup := preload("res://scripts/ui/RacePopup.gd")
const Banana := preload("res://scripts/ui/Banana.gd")

const W := 104.0

var race: Node
var _btn: TButton
var _bump := 0.0
## 已经自动弹过结算的那局
var _popped := ""

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	race = RaceNet.inst()
	_btn = UI.hit(self, Rect2(Vector2.ZERO, size), _on_tap)
	_btn.name = "race_entry"
	_btn.extra = _paint
	race.updated.connect(_on_update)
	race.watch(self)

func _on_tap() -> void:
	if not race.unlocked():
		G.main.toast("%d 级解锁篝火竞速" % race.unlock_level())
		return
	RacePopup.open()

func _on_update() -> void:
	_btn.queue_redraw()
	# 比完了：自动弹一次结算
	if race.ended() and is_visible_in_tree():
		var gid := str(race.group().get("id", ""))
		if gid != _popped and not race.pending_result().is_empty() and G.main.popup_layer.get_child_count() == 0:
			_popped = gid
			RacePopup.open()

func _process(delta: float) -> void:
	_bump = maxf(0.0, _bump - delta * 3.0)
	if is_visible_in_tree():
		_btn.queue_redraw()
		if race.joined():
			race.watch(self)

func center() -> Vector2:
	return global_position + size * 0.5

## 交单时香蕉从 from（全局坐标）飞进入口
func fly_from(from: Vector2) -> void:
	if not race.racing() or race.matching():
		return
	for k in 3:
		var d := DrawBox.new()
		d.size = Vector2(56, 56)
		d.position = from - d.size * 0.5
		var rot := randf_range(-0.6, 0.6)
		d.painter = func(ci, sz): Banana.draw(ci, sz * 0.5, 46.0, rot)
		G.main.fx_layer.add_child(d)
		var to := center() + Vector2(0, -20)
		var mid := from.lerp(to, 0.5) + Vector2(randf_range(-70, 70), -120)
		var tw := d.create_tween()
		tw.tween_interval(k * 0.09)
		tw.tween_method(func(t: float):
			d.position = from.lerp(mid, t).lerp(mid.lerp(to, t), t) - d.size * 0.5
			d.scale = Vector2.ONE * lerpf(1.0, 0.6, t), 0.0, 1.0, 0.55).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			_bump = 1.0
			d.queue_free())

func _paint(ci: CanvasItem, sz: Vector2) -> void:
	var r := Rect2(4, 16, sz.x - 8, sz.y - 24)
	var k := 1.0 + 0.08 * sin(_bump * PI)
	var lock: bool = not race.unlocked()
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 8), r.size), 18, 61, 0.0), Color(0, 0, 0, 0.3))
	var b := Art.rrect(r, 18, 61, 1.0)
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Color("b9a58a") if lock else Color("ffe9a8"))
	Art.dashed(ci, Art.rrect(r.grow(-6), 12, 62, 0.0), 8, 6, Color(0.65, 0.4, 0.2, 0.45), 2.0)
	var f: Font = G.font_title if G.font_title else G.font_body
	_txt(ci, f, "竞速", Vector2(sz.x * 0.5, 44), 22, Color("fff1c4"), 5)
	# 香蕉堆
	var c := Vector2(sz.x * 0.5, 108)
	for i in 3:
		Banana.draw(ci, c + Vector2((i - 1) * 16, 8 - absf(i - 1) * 2) * k, 50.0 * k, (i - 1) * 0.45 - 0.2)
	if lock:
		ci.draw_colored_polygon(Art.rrect(r, 18, 61, 0.0), Color(0.2, 0.15, 0.1, 0.35))
		Paint.glyph(ci, "lock", c, 1.2)
		_txt(ci, G.font_body, "%d级解锁" % race.unlock_level(), Vector2(sz.x * 0.5, 180), 18, Color.WHITE, 5)
		return
	var bot: String = "匹配"
	var col := Color.WHITE
	if race.ended():
		bot = "领奖!"
		col = Color("ffd23f")
	elif race.matching():
		bot = "匹配中" + ".".repeat(1 + (Time.get_ticks_msec() / 300) % 3)
	elif race.racing():
		var me: Dictionary = race.me()
		bot = "%d" % int(race.score_of(me))
		_txt(ci, G.font_body, "第%d名" % race.place_of(me), Vector2(sz.x * 0.5, 150), 18, Color("6b4a2a"))
	_txt(ci, G.font_body, bot, Vector2(sz.x * 0.5, 184), 22 if bot.length() < 5 else 18, col, 5)

static func _txt(ci: CanvasItem, f: Font, s: String, c: Vector2, fs: int, col: Color, ol: int = 0) -> void:
	if f == null:
		return
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := Vector2(c.x - w * 0.5, c.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5)
	if ol > 0:
		ci.draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ol, Art.INK)
	ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
