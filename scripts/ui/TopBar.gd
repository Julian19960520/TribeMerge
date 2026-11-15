class_name TopBar
extends Control
## 顶栏：等级石碑 / 体力 / 不那那 / 琥珀或沙漏（同一格）/ 集市
## 第三格平时是琥珀；棋盘上选中沙漏或正在制作、能用沙漏加速的物品时换成沙漏。

var _lv: Label
var _en: Label
var _timer: Label
var _sh: Label
var _festival: Control
var _festival_lbl: Label
var _festival_until := 0

## 顶栏横向排布：等级星 | 三条资源 | 集市，按看得见的墨线边算，左右留边和各段间距都约 16
## 资源条左边伸出图标（ICON_OVERHANG），间距从图标左边算
const PILL_W := 136.0
const ICON_OVERHANG := 22.0
const PILLS := {
	"energy": Rect2(134, 52, PILL_W, 50),
	"shell": Rect2(302, 52, PILL_W, 50),
	"amber": Rect2(470, 52, PILL_W, 50),
	"sand": Rect2(470, 52, PILL_W, 50),
}
const LEVEL_C := Vector2(60, 80)
const LEVEL_SIZE := 96.0

## 第三格当前显示什么
var _gem_mode := "amber"
## 棋盘上下文要求显示沙漏
var _ctx_sand := false
## 有东西正飞向这一格时临时切过去
var _flash_kind := ""
var _flash_until := 0
var _gem_box: DrawBox
var _gem_lbl: Label
var _gem_tw: Tween

func _ready() -> void:
	size = Vector2(720, 140)
	mouse_filter = MOUSE_FILTER_IGNORE
	_add_level()
	_add_energy()
	_add_shell()
	_add_gem()
	_add_shop()
	_add_festival_progress()
	_close = UI.hit(self, Rect2(629, 40, 70, 70), func():
		if not _closers.is_empty():
			_closers.back().call())
	_close.extra = func(ci, sz): Paint.close_btn(ci, sz * 0.5, 28)
	_close.visible = false
	_close_home = _close.position
	G.changed.connect(_refresh)
	_refresh()

var _shop: TButton
var _close: TButton
var _closers: Array[Callable] = []
var _close_home := Vector2.ZERO
var _chips := {}
var _home := {}
var _held := {}
var _clicks_locked := false

func _make_chip(id: String, r: Rect2) -> Control:
	var c := Control.new()
	c.position = r.position
	c.size = r.size
	c.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(c)
	_chips[id] = c
	_home[id] = r.position
	return c

## 资源图标：按每张图实际不透明部分的大小和偏移换算，让四个图标看起来一样大、中心对齐
## [绘制尺寸, 中心偏移]，图里的留白不一样，所以绘制尺寸各不相同
const ICON_FIT := {
	"fire_2": [100.0, Vector2(-2, -4)],
	"shell_2": [86.0, Vector2(17, -5)],
	"amber_2": [102.0, Vector2(3, -6)],
	"sand_2": [100.0, Vector2(-2, -4)],
}
const ICON_AT := Vector2(8, 25)

func _icon(ci: CanvasItem, id: String, pill: Rect2) -> void:
	var fit: Array = ICON_FIT.get(id, [64.0, Vector2.ZERO])
	Art.item(ci, id, pill.position + ICON_AT + fit[1], fit[0])

func _add_level() -> void:
	var r := Rect2(LEVEL_C - Vector2(LEVEL_SIZE, 104) * 0.5, Vector2(LEVEL_SIZE, 104))
	var c := _make_chip("level", r)
	var o := r.position
	UI.box(c, Rect2(Vector2.ZERO, r.size), func(ci, _sz):
		Paint.level_badge(ci, LEVEL_C - o, LEVEL_SIZE))
	_lv = UI.lbl(c, "1", Rect2(LEVEL_C + Vector2(-42, -28) - o, Vector2(84, 60)), 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 9, Art.INK, true)
	UI.hit(c, Rect2(Vector2.ZERO, r.size), func(): _open_from("level", "level"))

func _add_energy() -> void:
	var r := Rect2(PILLS["energy"].position.x - ICON_OVERHANG - 4.0, 40, PILL_W + ICON_OVERHANG + 8.0, 80)
	var c := _make_chip("energy", r)
	var o := r.position
	var e := Rect2(PILLS["energy"].position - o, PILLS["energy"].size)
	UI.box(c, Rect2(Vector2.ZERO, r.size), func(ci, _sz):
		Paint.pill(ci, e)
		_icon(ci, "fire_2", e)
		Paint.plus_badge(ci, e.position + Vector2(24, 46)))
	_en = UI.lbl(c, "", Rect2(PILLS["energy"].position + Vector2(30, 0) - o, Vector2(PILL_W - 34.0, 50)), 26)
	_timer = UI.lbl(c, "", Rect2(PILLS["energy"].position + Vector2(30, 46) - o, Vector2(PILL_W - 40.0, 24)), 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK)
	UI.hit(c, Rect2(Vector2.ZERO, r.size), func(): _open_from("energy", "energy"))

func _add_shell() -> void:
	var r := Rect2(PILLS["shell"].position.x - ICON_OVERHANG - 4.0, 40, PILL_W + ICON_OVERHANG + 8.0, 80)
	var c := _make_chip("shell", r)
	var o := r.position
	var s := Rect2(PILLS["shell"].position - o, PILLS["shell"].size)
	UI.box(c, Rect2(Vector2.ZERO, r.size), func(ci, _sz):
		Paint.pill(ci, s)
		_icon(ci, "shell_2", s))
	_sh = UI.lbl(c, "", Rect2(PILLS["shell"].position + Vector2(30, 0) - o, Vector2(PILL_W - 34.0, 50)), 26)
	UI.hit(c, Rect2(Vector2.ZERO, r.size), func(): _open_from("shell", "howto"))

## 第三格：琥珀 / 沙漏共用。切换时竖着翻一下。
func _add_gem() -> void:
	var r := Rect2(PILLS["amber"].position.x - ICON_OVERHANG - 4.0, 40, PILL_W + ICON_OVERHANG + 8.0, 80)
	var c := _make_chip("amber", r)
	c.pivot_offset = PILLS["amber"].position - r.position + PILLS["amber"].size * 0.5
	var o := r.position
	var a := Rect2(PILLS["amber"].position - o, PILLS["amber"].size)
	_gem_box = UI.box(c, Rect2(Vector2.ZERO, r.size), func(ci, _sz):
		Paint.pill(ci, a)
		if _gem_mode == "sand":
			_icon(ci, "sand_2", a)
		else:
			_icon(ci, Art.AMBER_ICON, a)
			Paint.plus_badge(ci, a.position + Vector2(24, 46)))
	_gem_lbl = UI.lbl(c, "", Rect2(PILLS["amber"].position + Vector2(30, 0) - o, Vector2(PILL_W - 34.0, 50)), 26)
	UI.hit(c, Rect2(Vector2.ZERO, r.size), func():
		if _gem_mode == "sand":
			G.main.toast(TextCatalog.source("ui.topbar.8204fee264bd") % Data.rush_text())
		else:
			_open_from("amber", "store"))

## 棋盘告诉顶栏：当前选中的东西要不要显示沙漏
func set_sand_context(on: bool) -> void:
	_ctx_sand = on
	_sync_gem()

func _sync_gem() -> void:
	var want := "sand" if _ctx_sand else "amber"
	if _flash_kind != "" and Time.get_ticks_msec() < _flash_until:
		want = _flash_kind
	if want == _gem_mode:
		return
	var c: Control = _chips["amber"]
	if _gem_tw != null and _gem_tw.is_valid():
		_gem_tw.kill()
	_gem_tw = c.create_tween()
	_gem_tw.tween_property(c, "scale:y", 0.0, 0.08).set_ease(Tween.EASE_IN)
	_gem_tw.tween_callback(func():
		_gem_mode = want
		_refresh()
		_gem_box.queue_redraw())
	_gem_tw.tween_property(c, "scale:y", 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(_d: float) -> void:
	if _festival.visible and Time.get_ticks_msec() >= _festival_until:
		_festival.hide()
	if _flash_kind != "" and Time.get_ticks_msec() >= _flash_until:
		_flash_kind = ""
		_sync_gem()

func _add_festival_progress() -> void:
	_festival = _make_chip("token", Rect2(190, 118, 340, 58))
	UI.box(_festival, Rect2(Vector2.ZERO, _festival.size), func(ci, sz):
		Paint.pill(ci, Rect2(Vector2.ZERO, sz))
		Art.item(ci, "token_1", Vector2(28, 28), 48))
	_festival_lbl = UI.lbl(_festival, "", Rect2(56, 0, 276, 58), 23, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK)
	UI.hit(_festival, Rect2(Vector2.ZERO, _festival.size), func():
		if G.rules.progression.feature_unlocked(Data.CARD_LEVEL): G.main.open("event")
		else: G.main.toast(TextCatalog.source("ui.topbar.ed9bbdbbe892") % Data.CARD_LEVEL))
	_festival.hide()

func _add_shop() -> void:
	var r := Rect2(624, 34, 80, 84)
	var c := _make_chip("shop", r)
	_shop = UI.hit(c, Rect2(Vector2.ZERO, r.size), func(): _open_from("shop", "store"))
	_shop.extra = func(ci, sz):
		Paint.shop_icon(ci, Vector2(sz.x * 0.5, 44), 0.72)
		if G.rules.progression.has_free_daily(): Paint.badge_num(ci, Vector2(sz.x - 10, 16), 7, 8.0)

func _open_from(id: String, popup_name: String) -> void:
	var p: PopupBase = G.main.open(popup_name)
	if p == null:
		return
	# 集市打开全屏页时，这一角只留关闭钮，小屋不跟上去
	if id == "shop" and p.has_meta("fullscreen"):
		return
	_lift(id, p)

func _lift(id: String, p: PopupBase) -> void:
	var c: Control = _chips[id]
	if c.get_parent() != G.main.pin:
		var gp := c.global_position
		c.reparent(G.main.pin, true)
		c.global_position = gp
		_set_clicks(c, false)
	var token := p.get_instance_id()
	_held[token] = id
	p.tree_exiting.connect(_drop.bind(token), CONNECT_ONE_SHOT)
	_front_close()

func _drop(token: int) -> void:
	if not _held.has(token):
		return
	var id: String = _held[token]
	_held.erase(token)
	for other in _held.values():
		if other == id:
			return
	var c: Control = _chips[id]
	if c.get_parent() != self:
		c.reparent(self, true)
		c.position = _home[id]
	_set_clicks(c, not _clicks_locked)

func on_popup_opened() -> void:
	_clicks_locked = true
	_apply_bar_clicks(false)

func on_popup_exited() -> void:
	if G.main.popup_layer.get_child_count() > 0:
		return
	_clicks_locked = false
	_apply_bar_clicks(true)

func _apply_bar_clicks(on: bool) -> void:
	for id in _chips:
		var c: Control = _chips[id]
		if c.get_parent() == self:
			_set_clicks(c, on)

func _set_clicks(n: Node, on: bool) -> void:
	if n is TButton:
		n.mouse_filter = MOUSE_FILTER_STOP if on else MOUSE_FILTER_IGNORE
	elif n is Control:
		n.mouse_filter = MOUSE_FILTER_IGNORE
	for ch in n.get_children():
		_set_clicks(ch, on)

## 全屏页面打开时，集市按钮变成关闭按钮
func push_close(cb: Callable) -> void:
	_closers.append(cb)
	_sync()

func pop_close(cb: Callable) -> void:
	_closers.erase(cb)
	_sync()

func _sync() -> void:
	var up := not _closers.is_empty()
	_close.visible = up
	_shop.visible = not up
	if up:
		_front_close()
	else:
		_back_close()

func _front_close() -> void:
	if not _close.visible:
		return
	var host: Control = G.main.pin
	if _close.get_parent() != host:
		var gp := _close.global_position
		_close.reparent(host, true)
		_close.global_position = gp
	_close.mouse_filter = MOUSE_FILTER_STOP
	host.move_child(_close, host.get_child_count() - 1)

func _back_close() -> void:
	if _close.get_parent() != self:
		_close.reparent(self, true)
		_close.position = _close_home
	_close.mouse_filter = MOUSE_FILTER_STOP

func target(kind: String) -> Vector2:
	if kind == "token":
		_festival_until = Time.get_ticks_msec() + 1800
		_festival.show()
		_refresh()
		return _festival.get_global_transform() * Vector2(28, 28)
	if kind == "sand" or kind == "amber":
		_flash_kind = kind
		_flash_until = Time.get_ticks_msec() + 1600
		_sync_gem()
	var r: Rect2 = PILLS.get(kind, PILLS["shell"])
	return get_global_transform() * (r.position + Vector2(8, 24))

func _refresh() -> void:
	_festival_lbl.text = TextCatalog.resolve(TextCatalog.source("ui.topbar.0520da220f57") % [G.tokens - G.token_claimed, G.TOKEN_STEP])
	_lv.text = TextCatalog.resolve(str(G.level))
	_en.text = TextCatalog.resolve(str(G.energy))
	_sh.text = TextCatalog.resolve(str(G.shells))
	_gem_lbl.text = TextCatalog.resolve(str(G.rush if _gem_mode == "sand" else G.amber))
	var left := G.rules.clock.energy_left()
	_timer.text = TextCatalog.resolve(G.fmt_time(left) if left > 0 else "")
