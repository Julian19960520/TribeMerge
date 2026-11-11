extends Control
var button: TButton

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	button = UI.hit(self, Rect2(Vector2.ZERO, size), func(): G.main.open("fossil"))
	button.name = "fossil_entry"
	button.extra = _paint
	G.changed.connect(func(): button.queue_redraw())

func _paint(ci: CanvasItem, sz: Vector2) -> void:
	Sprites.at(ci, "fos_entry", Vector2(sz.x * 0.5, sz.y - 108), 0.92)
	var ready := not FossilDig.ready_rewards().is_empty()
	var text := "×%d" % int(FossilDig.state().get("shovels", 0))
	if ready: text = "领奖"
	elif FossilDig.finished(): text = "完成"
	elif FossilDig.cleared(): text = "下一关"
	EventEntryArt._pill(ci, Vector2(sz.x * 0.5, sz.y - 42), text, "go" if ready or FossilDig.cleared() else "num")
	EventEntryArt.text(ci, "恐龙化石", Vector2(sz.x * 0.5, sz.y - 8), 20, Color("fff0c5"))
	if ready: Paint.badge_num(ci, Vector2(sz.x - 18, 30), 8, 10)

func fly_from(origin: Vector2) -> void:
	if not FossilDig.unlocked(): return
	var fx := UI.box(G.main.fx_layer, Rect2(origin - Vector2(30, 30), Vector2(60, 60)), func(ci, sz): FossilArt.shovel(ci, sz * 0.5, 54), false)
	var tw := fx.create_tween()
	tw.tween_property(fx, "position", get_global_rect().get_center() - fx.size * 0.5, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(fx.queue_free)
