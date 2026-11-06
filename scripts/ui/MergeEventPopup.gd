extends PopupBase
var cfg: Dictionary
var period_key := ""
var board: MergeEventBoard
var progress: Label
var timer: Label
var points: Label
var selection: Label
var spawn_btn: TButton
var claim_btn: TButton
var collection: DrawBox
var _clock := 0.0

func _ready() -> void:
	cfg = MergeEvent.definition(period_key) if period_key != "" else MergeEvent.current()
	if not MergeEvent.available(cfg):
		G.main.toast("活动尚未开始")
		close()
		return
	_build()
	G.merge_event_changed.connect(_refresh)
	_refresh()

func _build() -> void:
	var theme: Dictionary = cfg["theme"]
	var r := Rect2(28, 174, 664, 1216)
	Popups.frame(self, r, str(cfg["title"]), Color(str(theme["background"])), "")
	UI.box(box, Rect2(46, 274, 628, 1082), func(ci, sz):
		Art.fill(ci, Art.rrect(Rect2(Vector2.ZERO, sz), 22, 404, 0.3), Color(str(theme["background"])), 2.5)
		for k in 12:
			var pt := Vector2(25 + (k * 137) % 580, 30 + (k * 179) % 980)
			ci.draw_circle(pt, 2, Color(0.8, 1, 0.93, 0.25)))
	timer = UI.lbl(box, "", Rect2(100, 243, 520, 32), 19, Color("6a5741"))
	progress = UI.lbl(box, "", Rect2(72, 292, 366, 36), 24, Color("fff0c5"))
	collection = UI.box(box, Rect2(80, 1090, 560, 66), _paint_collection)
	board = MergeEventBoard.new()
	board.cfg = cfg
	var cell_size := minf(576.0 / int(cfg["board"]["cols"]), 672.0 / int(cfg["board"]["visible_rows"]))
	board.size = Vector2(int(cfg["board"]["cols"]), int(cfg["board"]["visible_rows"])) * cell_size
	board.position = Vector2((720 - board.size.x) / 2, 414)
	box.add_child(board)
	board.selection_changed.connect(func(id, locked):
		selection.text = (str(MergeEvent.item(cfg, id).get("name", "")) + (" · 同级合并解锁" if locked else "")) if id != "" else ("在旁边合并，揭开覆盖" if locked else "")
		_refresh())
	board.action_finished.connect(func(_r): _refresh())
	selection = UI.lbl(box, "同级合并，解开遗迹", Rect2(80, 1162, 560, 32), 21, Color("e7e6c6"))
	spawn_btn = UI.hit(box, Rect2(282, 1196, 156, 156), func(): board.spawn())
	spawn_btn.extra = _paint_spawn
	points = UI.lbl(spawn_btn, "", Rect2(0, 107, 156, 40), 29, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
	claim_btn = UI.btn(box, Rect2(456, 284, 188, 58), "通关奖励", "green", _claim, 24)
	claim_btn.name = "event_completion_reward"
	var rewards: Array = cfg["rewards"]
	var gap := 540.0 / maxi(1, rewards.size())
	for k in rewards.size():
		var rw: Array = rewards[k]
		var x := 90 + (k + 0.5) * gap
		UI.icon(box, str(rw[0]), Vector2(x - 20, 373), 58)
		UI.lbl(box, "×%d" % int(rw[1]), Rect2(x + 10, 356, 70, 36), 23, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 4, Art.INK)

func _paint_spawn(ci: CanvasItem, sz: Vector2) -> void:
	var c := Vector2(sz.x / 2, 67)
	ci.draw_circle(c + Vector2(0, 5), 60, Color(0, 0, 0, 0.2))
	ci.draw_circle(c, 60, Color(str(cfg["theme"]["accent"])))
	ci.draw_arc(c, 59, 0, TAU, 48, Color("d7fff1"), 3, true)
	ci.draw_arc(c + Vector2(-4, -4), 47, PI * 1.08, PI * 1.55, 18, Color(1, 1, 1, 0.8), 6, true)
	ci.draw_texture_rect(MergeEvent.texture(str(cfg["theme"]["point_icon"])), Rect2(c - Vector2(36, 36), Vector2(72, 72)), false)
	Paint.plus_badge(ci, c + Vector2(43, 34))

func _paint_collection(ci: CanvasItem, sz: Vector2) -> void:
	var chain: Array = cfg["chain"]
	var s := MergeEvent.state(cfg)
	var gap := sz.x / chain.size()
	for k in chain.size():
		var c := Vector2(gap * (k + 0.5), 34)
		var id := str(chain[k]["id"])
		ci.draw_circle(c, gap * 0.40, Color(0.1, 0.2, 0.25, 0.4))
		if s["discovered"].has(id): MergeEvent.draw_item(ci, cfg, id, c, gap * 0.86)
		else: ci.draw_string(G.font_title, c + Vector2(-9, 10), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 29, Color("93aead"))

func _refresh() -> void:
	if not is_instance_valid(board): return
	var s := MergeEvent.state(cfg)
	var total := int(cfg["board"]["cols"]) * (int(cfg["board"]["total_rows"]) - 1)
	progress.text = "遗迹解锁  %d / %d" % [total - MergeEvent.remaining(s), total]
	if str(cfg["board"].get("goal", "unlock_all")) == "discover_all":
		progress.text = "物品发现  %d / %d" % [s["discovered"].size(), cfg["chain"].size()]
	points.text = "×%d" % int(s["points"])
	spawn_btn.enabled = MergeEvent.active(cfg) and not bool(s["claimed"])
	spawn_btn.queue_redraw()
	claim_btn.enabled = not bool(s["claimed"])
	claim_btn.text = "已领取" if bool(s["claimed"]) else ("领取奖励" if MergeEvent.complete(cfg, s) else "通关奖励")
	claim_btn.queue_redraw()
	collection.queue_redraw()
	_tick()

func _process(delta: float) -> void:
	_clock += delta
	if _clock >= 1:
		_clock = 0
		_tick()

func _tick() -> void:
	if not is_instance_valid(timer): return
	var left := maxi(0, int(float(cfg["ends_at"]) - G.now()))
	timer.text = "第 %d 期 · 剩余 %s" % [int(str(cfg["key"]).get_slice(":", 1)) + 1, G.fmt_time(left)] if left > 0 else "本期已结束 · 已完成奖励仍可领取"
	if left <= 0: spawn_btn.enabled = false

func _claim() -> void:
	if not MergeEvent.complete(cfg, MergeEvent.state(cfg)):
		_preview_rewards()
		return
	var result: Dictionary = await MergeEvent.act(cfg, "claim")
	if result.has("error"):
		if str(result["error"]) != "": G.main.toast(str(result["error"]))
	else: close()

func _preview_rewards() -> void:
	var p := PopupBase.new()
	Popups.frame(p, Rect2(48, 450, 624, 570), "通关奖励", Color(str(cfg["theme"]["background"])))
	UI.lbl(p.box, "发现全部物品后领取" if str(cfg["board"].get("goal", "unlock_all")) == "discover_all" else "解锁全部格子后领取", Rect2(80, 518, 560, 48), 28, Art.INK)
	var rewards: Array = cfg["rewards"]
	var gap := 540.0 / maxi(1, rewards.size())
	for k in rewards.size():
		var reward: Array = rewards[k]
		var x := 90 + gap * k
		UI.box(p.box, Rect2(x + 5, 600, gap - 10, 210), func(ci, sz):
			Art.fill(ci, Art.rrect(Rect2(Vector2.ZERO, sz), 20, 480 + k, 0.4), Color(str(cfg["theme"]["panel"])), 2)
			Art.item(ci, str(reward[0]), Vector2(sz.x / 2, 78), minf(120, gap - 20)))
		UI.lbl(p.box, "×%d" % int(reward[1]), Rect2(x, 740, gap, 50), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
	UI.btn(p.box, Rect2(210, 870, 300, 86), "知道了", "teal", p.close, 30)
	G.main._attach_popup(p)
