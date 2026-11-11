class_name RankPopup
extends RefCounted
const Meme := preload("res://scripts/Meme.gd")
## 部落排行：按部落解锁进度（已建成部件数）排名，平分时先达到的在前。前三名站领奖台，第四名起是列表，自己高亮，底部固定显示自己的名次。
## 名字头像以后接平台账号，这里不提供改名。连不上服务器时列表区显示提示和「重试」，不影响游戏。

const ROW := 78.0
const R := Rect2(36, 206, 648, 1110)
## 领奖台区域高度和三级台阶高度（第一、二、三名）
const POD_H := 330.0
const STEP_H := [160.0, 124.0, 100.0]
const STEP_GAP := 6.0
const MEDAL := [Color("f2c35a"), Color("cfc9c0"), Color("d08a4a")]

static func open() -> PopupBase:
	var p := PopupBase.new()
	_build(p)
	G.main._attach_popup(p)
	return p

static func _build(p: PopupBase) -> void:
	var r := R
	Popups.frame(p, r, "部落排行", Art.AMBER)
	if not Cloud.enabled:
		UI.lbl(p.box, "本地试玩版\n在线排行榜暂未开放", Rect2(72, 500, 576, 180), 28, Art.INK)
		return
	var x0 := r.position.x + 30
	var w := r.size.x - 60

	# 领奖台（前三名）
	var pod := Control.new()
	pod.name = "Podium"
	pod.position = Vector2(x0, r.position.y + 56)
	pod.size = Vector2(w, POD_H)
	pod.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.box.add_child(pod)

	# 表头 + 第 4 名起的列表
	var hy := r.position.y + 56 + POD_H + 10
	var head := Control.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.box.add_child(head)
	UI.lbl(head, "名次", Rect2(x0, hy, 96, 34), 22, Color("8a5a30"))
	UI.lbl(head, "昵称", Rect2(x0 + 110, hy, 280, 34), 22, Color("8a5a30"), HORIZONTAL_ALIGNMENT_LEFT)
	UI.lbl(head, "进度", Rect2(x0 + w - 170, hy, 150, 34), 22, Color("8a5a30"), HORIZONTAL_ALIGNMENT_RIGHT)
	var list_top := hy + 40
	var list_bot := r.end.y - 128
	var sc := Scroller.new()
	sc.position = Vector2(x0, list_top)
	sc.size = Vector2(w, list_bot - list_top)
	p.box.add_child(sc)
	var status := UI.lbl(p.box, "", Rect2(x0, r.position.y + 300, w, 150), 26, Color("8a5a30"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var retry := UI.btn(p.box, Rect2(r.get_center().x - 110, r.position.y + 480, 220, 76), "重试", "green", Callable(), 32)
	retry.visible = false

	# 底部：自己
	var me_row := Control.new()
	me_row.position = Vector2(x0, r.end.y - 112)
	me_row.size = Vector2(w, ROW)
	me_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.box.add_child(me_row)

	var state := {"data": {}, "ok": false, "loading": true}
	var render := func():
		for n in [sc.content, me_row, pod]:
			for c in n.get_children():
				c.queue_free()
		retry.visible = false
		var top: Array = state["data"].get("top", []) if state["ok"] else []
		var shown: bool = state["ok"] and not top.is_empty()
		head.visible = shown
		if state["loading"]:
			status.text = "正在联络远方的部落……"
		elif not state["ok"]:
			status.text = "暂时连不上排行榜服务器。
先去建造吧，进度会在连上后自动补传。"
			retry.visible = true
		elif top.is_empty():
			status.text = "还没有部落上榜。"
		else:
			status.text = ""
		var mine := {"rank": 0, "name": Rank.nick, "progress": Rank.progress_now()}
		if state["ok"] and state["data"].get("me") is Dictionary:
			mine = state["data"]["me"]
		if not state["loading"]:
			_row(me_row, mine, true)
		if not shown:
			sc.set_length(0)
			return
		_podium(pod, top)
		var rest := top.slice(3)
		for i in rest.size():
			var e: Dictionary = rest[i]
			var holder := Control.new()
			holder.position = Vector2(0, i * ROW)
			holder.size = Vector2(w, ROW)
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sc.content.add_child(holder)
			_row(holder, e, str(e.get("id", "")) == G.player_id)
		sc.set_length(rest.size() * ROW + 8)
	var reload := func():
		state["loading"] = true
		render.call()
		Rank.fetch(func(ok: bool, d: Dictionary):
			if not is_instance_valid(p) or p.is_queued_for_deletion():
				return
			state["loading"] = false
			state["ok"] = ok
			state["data"] = d
			render.call())
	retry.pressed.connect(reload)
	# 上传成功（建造）后刷新一次；失败不刷新，免得来回重试
	Popups.live(p, Rank.synced, func(ok: bool):
		if ok and not state["loading"]:
			reload.call())

	reload.call()

## 领奖台：第二名在左、第一名居中最高、第三名在右。台阶上写名次和进度，台阶上方是头像（暂用名字首字）和名字。
static func _podium(pod: Control, top: Array) -> void:
	var w := pod.size.x
	var sw := (w - 2 * STEP_GAP) / 3.0
	var order := [1, 0, 2]
	for k in 3:
		var i: int = order[k]
		var hgt: float = STEP_H[i]
		var x := k * (sw + STEP_GAP)
		var y := POD_H - hgt
		var e: Dictionary = top[i] if i < top.size() else {}
		var mine := not e.is_empty() and str(e.get("id", "")) == G.player_id
		var rk := i + 1
		UI.box(pod, Rect2(x, y, sw, hgt), func(ci, sz): _paint_step(ci, sz, rk), false)
		UI.lbl(pod, str(rk), Rect2(x, y + 6, sw, 54), 48 if rk == 1 else 40, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 10, Art.INK, true)
		if e.is_empty():
			UI.lbl(pod, "虚位以待", Rect2(x, y - 44, sw, 36), 22, Color("a08a70"))
			continue
		UI.lbl(pod, "%d 件" % int(e.get("progress", 0)), Rect2(x, y + 56, sw, 34), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK, true)
		var nm := str(e.get("name", ""))
		UI.lbl(pod, nm + ("（我）" if mine else ""), Rect2(x - 6, y - 44, sw + 12, 36), 22 if nm.length() <= 6 else 18, Art.CLAY if mine else Art.INK)
		var ac := Vector2(x + sw * 0.5, y - 92)
		var ar := 42.0 if rk == 1 else 36.0
		UI.box(pod, Rect2(ac - Vector2(ar + 8, ar + 8), Vector2(ar + 8, ar + 8) * 2), func(ci, sz): _paint_avatar(ci, sz * 0.5, ar, rk, mine))
		if rk == 1:
			UI.box(pod, Rect2(ac + Vector2(-30, -ar - 40), Vector2(60, 40)), func(ci, sz): _paint_crown(ci, sz))

## 领奖台台阶、头像底、皇冠都是预生成贴图（scripts/sprites/events.gd）
static func _paint_step(ci: CanvasItem, sz: Vector2, rk: int) -> void:
	Sprites.draw(ci, "ev_rank_step_%d" % rk, Rect2(Vector2.ZERO, sz))

static func _paint_avatar(ci: CanvasItem, c: Vector2, rad: float, rk: int, mine: bool) -> void:
	ci.draw_circle(c, rad + 4, Art.AMBER if mine else Art.WOOD_D)
	ci.draw_circle(c, rad, Art.HIDE)
	Meme.portrait(ci, Meme.HERO if mine else posmod(rk, 5), c, rad * 2.0)

static func _paint_crown(ci: CanvasItem, sz: Vector2) -> void:
	Sprites.draw(ci, "ev_rank_crown", Rect2(Vector2.ZERO, sz))

## 一行：名次（前三名奖牌）、昵称、进度。mine 为真时高亮。
static func _row(parent: Control, e: Dictionary, mine: bool) -> void:
	var w := parent.size.x
	var rk := int(e.get("rank", 0))
	UI.box(parent, Rect2(0, 4, w, ROW - 8), func(ci, sz):
		Sprites.draw(ci, "ev_rank_row_" + ("me" if mine else "other"), Rect2(Vector2(2, 2), sz - Vector2(4, 4)))
		if rk >= 1 and rk <= 3:
			Sprites.draw(ci, "ev_medal_%d" % (rk - 1), Rect2(Vector2(24, sz.y * 0.5 - 24), Vector2(48, 48)))
	, false)
	var rank_txt := "未上榜" if rk <= 0 else str(rk)
	var fs := 18 if rk <= 0 else (30 if rk < 100 else 22)
	UI.lbl(parent, rank_txt, Rect2(0, 4, 96, ROW - 8), fs, Color.WHITE if rk >= 1 and rk <= 3 else Art.INK,
		HORIZONTAL_ALIGNMENT_CENTER, 6 if rk >= 1 and rk <= 3 else 0, Art.INK, rk > 0)
	var name := str(e.get("name", ""))
	if mine:
		name += "（我）"
	UI.lbl(parent, name, Rect2(110, 4, w - 300, ROW - 8), 26, Art.INK, HORIZONTAL_ALIGNMENT_LEFT)
	UI.lbl(parent, "%d 件" % int(e.get("progress", 0)), Rect2(w - 190, 4, 170, ROW - 8), 28,
		Art.CLAY if mine else Color("6b4a2a"), HORIZONTAL_ALIGNMENT_RIGHT, 0, Art.INK, true)

