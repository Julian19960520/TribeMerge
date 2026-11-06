extends PopupBase
var page := 0
var tasks_root: Control
var tabs: Array = []
var stage_buttons: Array = []
var score: Label
var rail: DrawBox
var _refresh_pending := false
func _ready() -> void:
	SevenDay.login()
	Popups.frame(self, Rect2(28, 180, 664, 1200), "七日任务", Color("ad6e36"))
	UI.lbl(box, "七页同时进行，可提前完成", Rect2(70, 245, 580, 38), 22, Color("80603e"))
	score = UI.lbl(box, "", Rect2(70, 293, 580, 44), 29, Art.INK)
	rail = UI.box(box, Rect2(80, 359, 560, 20), func(ci, sz):
		ci.draw_style_box(UI_style(Color("bba783")), Rect2(Vector2.ZERO, sz))
		ci.draw_style_box(UI_style(Color("d99b42")), Rect2(Vector2.ZERO, Vector2(sz.x * minf(1, float(SevenDay.points()) / float(SevenDay.config()["milestones"][-1]["points"])), sz.y))))
	var stages: Array = SevenDay.config()["milestones"]
	for k in stages.size():
		var stage: Dictionary = stages[k]
		var b := UI.hit(box, Rect2(64 + k * 120, 392, 112, 128), func(): _stage(stage))
		b.extra = func(ci, sz):
			var claimed: bool = SevenDay.state()["stages"].has(str(stage["id"]))
			Art.fill(ci, Art.rrect(Rect2(Vector2.ZERO, sz), 14, 720+k, 0.3), Color("d7d3b7") if claimed else Color("f8e7b7"), 2)
			Art.item(ci, str(stage["rewards"][0][0]), Vector2(sz.x / 2, 40), 62)
			if not claimed and SevenDay.points() >= int(stage["points"]): Paint.badge_num(ci, Vector2(sz.x - 7, 7), 7, 7)
		var lbl := UI.lbl(b, "", Rect2(0, 78, 112, 40), 23, Art.INK)
		stage_buttons.append([b,lbl,stage])
	tasks_root = Control.new()
	tasks_root.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(tasks_root)
	for k in 7:
		var b := UI.btn(box, Rect2(51 + k * 89, 1260, 84, 82), "%d日" % (k+1), "hide", func(): page = k; _refresh(), 25)
		tabs.append(b)
	G.seven_day_changed.connect(_schedule_refresh)
	_refresh()
static func UI_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(10)
	return style
func _schedule_refresh() -> void:
	if _refresh_pending: return
	_refresh_pending = true
	_refresh.call_deferred()
func _refresh() -> void:
	_refresh_pending = false
	if not is_instance_valid(score): return
	var stages: Array = SevenDay.config()["milestones"]
	score.text = "成长积分  %d / %d" % [SevenDay.points(), int(stages[-1]["points"])]
	rail.queue_redraw()
	for row in stage_buttons:
		row[1].text = "已领取" if SevenDay.state()["stages"].has(str(row[2]["id"])) else "%d分" % int(row[2]["points"])
		row[0].queue_redraw()
	for child in tasks_root.get_children():
		tasks_root.remove_child(child)
		child.queue_free()
	var tasks: Array = SevenDay.config()["days"][page]["tasks"]
	for k in tasks.size(): _task(tasks[k], 550 + k * 136)
	for k in tabs.size():
		tabs[k].style = "teal" if page == k else "hide"
		tabs[k].extra = func(ci, sz):
			if SevenDay.ready(k): Paint.badge_num(ci, Vector2(sz.x - 7, 7), 6, 6)
		tabs[k].queue_redraw()
func _task(task: Dictionary, y: float) -> void:
	var claimed := SevenDay.got(task)
	UI.box(tasks_root, Rect2(54, y, 612, 124), func(ci, sz):
		Art.fill(ci, Art.rrect(Rect2(Vector2.ZERO, sz), 18, 731, 0.4), Color("e5ddc7") if claimed else Color("fff0d1"), 2))
	UI.lbl(tasks_root, str(task["title"]), Rect2(74, y+8, 410, 38), 27, Art.INK, HORIZONTAL_ALIGNMENT_LEFT)
	var current := mini(SevenDay.value(task), int(task["target"]))
	var progress := "%d / %d" % [current,int(task["target"])]
	if str(task["metric"]) == "paid_cents": progress = "¥%.2f / %.2f" % [current/100.0,int(task["target"])/100.0]
	UI.lbl(tasks_root, progress, Rect2(76, y+50, 205, 32), 22, Color("856344"), HORIZONTAL_ALIGNMENT_LEFT)
	UI.lbl(tasks_root, "+%d积分" % int(task["points"]), Rect2(76,y+84,150,29),20,Color("397d77"),HORIZONTAL_ALIGNMENT_LEFT)
	var rewards: Array = task["rewards"]
	for k in rewards.size():
		var x := 311 + k * 95
		UI.icon(tasks_root,str(rewards[k][0]),Vector2(x,y+77),56)
		UI.lbl(tasks_root,"×%d" % int(rewards[k][1]),Rect2(x+24,y+62,66,32),21,Art.INK,HORIZONTAL_ALIGNMENT_LEFT)
	var b := UI.btn(tasks_root,Rect2(500,y+29,146,68),"已领取" if claimed else ("领取" if SevenDay.done(task) else "进行中"),"green",func(): _claim(str(task["id"]),false),25)
	b.enabled = SevenDay.done(task) and not claimed and not SevenDay.busy
func _claim(id: String, stage: bool) -> void:
	var result := await SevenDay.claim(id, stage)
	if result.has("error") and str(result["error"]) != "": G.main.toast(str(result["error"]))
	if is_instance_valid(self): _refresh()
func _stage(stage: Dictionary) -> void:
	if SevenDay.points() >= int(stage["points"]) and not SevenDay.state()["stages"].has(str(stage["id"])):
		_claim(str(stage["id"]),true)
		return
	var p := PopupBase.new()
	Popups.frame(p,Rect2(90,480,540,500),"阶段奖励",Art.TEAL)
	UI.lbl(p.box,"累计 %d 积分可领取" % int(stage["points"]),Rect2(120,555,480,48),27,Art.INK)
	var rewards: Array = stage["rewards"]
	for k in rewards.size():
		var x := 360.0 + (k - (rewards.size()-1)/2.0) * 160
		UI.icon(p.box,str(rewards[k][0]),Vector2(x,710),110)
		UI.lbl(p.box,"×%d" % int(rewards[k][1]),Rect2(x-60,780,120,42),29,Art.INK)
	UI.btn(p.box,Rect2(230,870,260,70),"知道了","teal",p.close,28)
	G.main._attach_popup(p)
