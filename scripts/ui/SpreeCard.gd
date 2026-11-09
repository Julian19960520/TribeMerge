extends Control
## 部落界面左侧「赶大集」入口（通行证、部落礼包下面一格，同一套黄色卡片）。
## 只在这一期进行中、还有得买时显示，下面一行是倒计时。第一次创建时顺便挂上 Offers 节点（负责开期和自动弹出）。
const RECT := Rect2(14, 412, 100, 116)
var _btn: TButton
var _time: Label

func _ready() -> void:
	position = RECT.position
	size = RECT.size
	mouse_filter = MOUSE_FILTER_IGNORE
	Offers.inst()
	_btn = UI.hit(self, Rect2(Vector2.ZERO, RECT.size), func(): G.main.open("spree"))
	_btn.name = "spree_card"
	_btn.extra = _paint
	UI.lbl(_btn, "赶大集", Rect2(0, 78, 100, 24), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
	_time = UI.lbl(_btn, "", Rect2(0, 100, 100, 20), 14, Color("ffe7a8"), HORIZONTAL_ALIGNMENT_CENTER, 4, Art.INK)
	_refresh()

func _process(_d: float) -> void:
	if Engine.get_process_frames() % 30 == 0: _refresh()

func _refresh() -> void:
	var on := Offers.active("spree") and Offers.any_left("spree")
	_btn.visible = on
	if on:
		_time.text = SpreePopupScript.clock_text(Offers.remaining("spree"))
		_btn.queue_redraw()

const SpreePopupScript := preload("res://scripts/ui/SpreePopup.gd")

func _paint(ci: CanvasItem, sz: Vector2) -> void:
	# 卡底 + 袋子提手、袋身 + 爆炸贴是两层预生成贴图，物品夹在中间
	var box := Rect2(0, 0, sz.x, sz.x)
	Sprites.draw(ci, "ev_spree_card_back", box)
	var c := Vector2(sz.x * 0.5, 50)
	Art.item(ci, Art.AMBER_ICON, c + Vector2(-8, -12), 26, true, -0.3)
	Art.item(ci, "fire_3", c + Vector2(9, -14), 24, true, 0.2)
	Sprites.draw(ci, "ev_spree_card_front", box)
