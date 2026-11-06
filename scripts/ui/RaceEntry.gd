extends Control
## 棋盘订单栏里、主角卡左边的「篝火竞速」入口（参加与否都在）。
## 画法在 EventEntryArt：香蕉串 + 赛旗，下面一个状态牌（等级锁 / 开赛 / 匹配中 / 名次 / 领奖）。
## 交付订单时 BoardScreen 调 fly_from()：香蕉从订单卡飞进这里。比完一局自动弹结算；领完奖弹「再来一局」。

const RaceNet := preload("res://scripts/net/Race.gd")
const RacePopup := preload("res://scripts/ui/RacePopup.gd")
const Banana := preload("res://scripts/ui/Banana.gd")

const W := 104.0

var race: Node
var _btn: TButton
var _bump := 0.0
var _redraw_clock := 0.0
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
		_redraw_clock += delta
		if _redraw_clock >= 1.0 or _bump > 0:
			_redraw_clock = 0
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
	# 一个状态牌：锁 → 等级；空闲 → 开赛；匹配中；比赛中 → 名次（金银铜底色）；比完 → 领奖 / 结算
	var badge := {"text": "开赛", "style": "teal"}
	var dot := false
	if not race.unlocked(): badge = {"text": "%d级" % race.unlock_level(), "style": "lock"}
	elif race.ended():
		dot = int(race.pending_result().get("me", {}).get("place", 0)) in [1, 2, 3]
		badge = {"text": "领奖" if dot else "结算", "style": "go"}
	elif race.matching(): badge = {"text": "匹配中", "style": "time"}
	elif race.racing():
		var place: int = race.place_of(race.me())
		badge = {"text": "第%d名" % place, "style": ["gold", "silver", "bronze"][place - 1] if place in [1, 2, 3] else "num"}
	EventEntryArt.paint(ci, sz, "race", "香蕉竞速", badge, not race.unlocked(), dot, _bump)

static func _txt(ci: CanvasItem, f: Font, s: String, c: Vector2, fs: int, col: Color, ol: int = 0) -> void:
	if f == null:
		return
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := Vector2(c.x - w * 0.5, c.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5)
	if ol > 0:
		ci.draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ol, Art.INK)
	ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
