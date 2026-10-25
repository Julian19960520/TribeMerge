class_name TopBar
extends Control
## 顶栏：等级石碑 / 体力 / 贝币 / 琥珀 / 集市

var _lv: Label
var _en: Label
var _timer: Label
var _sh: Label
var _am: Label

const PILLS := {
	"energy": Rect2(150, 52, 150, 50),
	"shell": Rect2(334, 52, 150, 50),
	"amber": Rect2(518, 52, 120, 50),
}

func _ready() -> void:
	size = Vector2(720, 140)
	mouse_filter = MOUSE_FILTER_IGNORE
	UI.box(self, Rect2(0, 0, 720, 140), _paint)
	_lv = UI.lbl(self, "1", Rect2(22, 52, 84, 60), 40, Color("fff1c4"), HORIZONTAL_ALIGNMENT_CENTER, 10, Art.INK, true)
	_en = UI.lbl(self, "", Rect2(PILLS["energy"].position + Vector2(30, 0), Vector2(110, 50)), 28)
	_timer = UI.lbl(self, "", Rect2(PILLS["energy"].position + Vector2(36, 46), Vector2(100, 24)), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK)
	_sh = UI.lbl(self, "", Rect2(PILLS["shell"].position + Vector2(30, 0), Vector2(110, 50)), 28)
	_am = UI.lbl(self, "", Rect2(PILLS["amber"].position + Vector2(26, 0), Vector2(90, 50)), 28)
	UI.hit(self, Rect2(14, 30, 100, 104), func(): G.main.open("level"))
	UI.hit(self, Rect2(120, 40, 190, 80), func(): G.main.open("energy"))
	UI.hit(self, Rect2(316, 40, 174, 80), func(): G.main.open("howto"))
	UI.hit(self, Rect2(496, 40, 146, 80), _open_store)
	_shop = UI.hit(self, Rect2(644, 34, 70, 84), _open_store)
	_shop.extra = func(ci, sz): Paint.hut_icon(ci, sz * 0.5 + Vector2(0, 4), 0.85)
	_close = UI.hit(self, Rect2(644, 40, 70, 70), func():
		if not _closers.is_empty():
			_closers.back().call())
	_close.extra = func(ci, sz): Paint.close_btn(ci, sz * 0.5, 28)
	_close.visible = false
	G.changed.connect(_refresh)
	_refresh()

var _shop: TButton
var _close: TButton
var _closers: Array[Callable] = []

func _open_store() -> void:
	if G.main.popup_layer.get_children().any(func(c): return c.has_meta("store") and not c.is_queued_for_deletion()):
		return
	G.main.open("store")

## 全屏页面打开时，集市按钮变成关闭按钮
func push_close(cb: Callable) -> void:
	_closers.append(cb)
	_sync()

func pop_close(cb: Callable) -> void:
	_closers.erase(cb)
	_sync()

func _sync() -> void:
	_close.visible = not _closers.is_empty()
	_shop.visible = _closers.is_empty()

func _paint(ci: CanvasItem, _sz: Vector2) -> void:
	Paint.level_badge(ci, Vector2(64, 82), 92)
	for k in PILLS:
		Paint.pill(ci, PILLS[k])
	var e: Rect2 = PILLS["energy"]
	Art.item(ci, "fire_2", e.position + Vector2(4, 22), 70)
	Paint.plus_badge(ci, e.position + Vector2(14, 48))
	var s: Rect2 = PILLS["shell"]
	Art.item(ci, "shell_1", s.position + Vector2(6, 24), 66)
	var a: Rect2 = PILLS["amber"]
	Art.item(ci, "amber_2", a.position + Vector2(4, 24), 62)
	Paint.plus_badge(ci, a.position + Vector2(14, 48))

func _refresh() -> void:
	_lv.text = str(G.level)
	_en.text = str(G.energy)
	_sh.text = str(G.shells)
	_am.text = str(G.amber)
	var left := G.energy_left()
	_timer.text = G.fmt_time(left) if left > 0 else ""

func target(kind: String) -> Vector2:
	var r: Rect2 = PILLS.get(kind, PILLS["shell"])
	return get_global_transform() * (r.position + Vector2(8, 24))
