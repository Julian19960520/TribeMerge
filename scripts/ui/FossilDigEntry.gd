extends Control
var button: TButton

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	button = UI.hit(self, Rect2(Vector2.ZERO, size), func(): G.main.open("fossil"))
	button.name = "fossil_entry"
	button.extra = _paint
	G.changed.connect(func(): button.queue_redraw())

func _paint(ci: CanvasItem, sz: Vector2) -> void:
	# 和其他入口同一条地面线；档期剩余时间 + 挖出的骨头进度（满 = 最后一档里程碑）
	var ground := EventEntryArt.ground(sz)
	Sprites.draw(ci, "ev_ell_shadow", Rect2(Vector2(sz.x * 0.5 - 44, ground - 10), Vector2(88, 16)), Color(0.16, 0.1, 0.04, 0.28))
	Sprites.at(ci, "fos_entry", Vector2(sz.x * 0.5, ground - 40), 0.92)
	var stages: Array = FossilDig.config()["milestones"]
	var need := int(stages[-1]["bones"]) if not stages.is_empty() else 0
	var info := {"have": mini(int(FossilDig.state().get("recovered", 0)), need), "need": need, "icon": "bone"}
	if ActivitySchedule.scheduled("fossil"): info["left"] = ActivitySchedule.seconds_left("fossil")
	EventEntryArt.footer(ci, sz, info)
	if not FossilDig.ready_rewards().is_empty(): Paint.badge_num(ci, Vector2(sz.x * 0.5 + 42, ground - 100), 8, 10)

func fly_from(origin: Vector2) -> void:
	if not FossilDig.unlocked(): return
	var fx := UI.box(G.main.fx_layer, Rect2(origin - Vector2(30, 30), Vector2(60, 60)), func(ci, sz): FossilArt.shovel(ci, sz * 0.5, 54), false)
	var tw := fx.create_tween()
	tw.tween_property(fx, "position", get_global_rect().get_center() - fx.size * 0.5, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(fx.queue_free)
