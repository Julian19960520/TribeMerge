extends Control
## 棋盘任务栏的七日签到入口：一个礼包，今天能领时挂红点，底下写「可领取」或「明日再来」。
var btn: TButton
var _t := 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	btn = UI.hit(self, Rect2(Vector2.ZERO, size), func(): G.main.open("login_gift"))
	btn.extra = _paint
	G.login_gift_changed.connect(func(): btn.queue_redraw())

func _process(delta: float) -> void:
	_t += delta
	if LoginGift.can_claim(): btn.queue_redraw()

func _paint(ci: CanvasItem, sz: Vector2) -> void:
	var c := Vector2(sz.x * 0.5, EventEntryArt.ground(sz))
	Sprites.draw(ci, "ev_ell_shadow", Rect2(c + Vector2(-44, -10), Vector2(88, 16)), Color(0.16, 0.1, 0.04, 0.28))
	var can := LoginGift.can_claim()
	var bob := sin(_t * 3.0) * 4.0 if can else 0.0
	Art.item(ci, "premiumbox_3", c + Vector2(0, -50 + bob), 96)
	if can: Paint.badge_num(ci, c + Vector2(42, -100), 8, 10)
	EventEntryArt.footer(ci, sz, {"lock": TextCatalog.source("ui.sevendaypopup.54cd6730d6f4") if can else TextCatalog.source("ui.logingiftentry.32f5ed07c26a")})
