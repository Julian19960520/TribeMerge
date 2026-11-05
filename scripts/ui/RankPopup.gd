class_name RankPopup
extends RefCounted
## 部落排行：按部落解锁进度（已建成部件数）排名，平分时先达到的在前。自己那行高亮，底部固定显示自己的名次。
## 名字头像以后接平台账号，这里不提供改名。连不上服务器时列表区显示提示和「重试」，不影响游戏。

const ROW := 78.0
const R := Rect2(36, 206, 648, 1110)

static func open() -> PopupBase:
	var p := PopupBase.new()
	_build(p)
	G.main._attach_popup(p)
	return p

static func _build(p: PopupBase) -> void:
	var r := R
	Popups.frame(p, r, "部落排行", Art.AMBER)
	var x0 := r.position.x + 30
	var w := r.size.x - 60

	# 我的进度
	UI.box(p.box, Rect2(x0, r.position.y + 62, w, 132), func(ci, sz): _card(ci, sz, Color("fbeccb"), Art.LEATHER, 3))
	UI.lbl(p.box, "我的部落进度", Rect2(x0 + 24, r.position.y + 72, 260, 40), 24, Color("8a5a30"), HORIZONTAL_ALIGNMENT_LEFT)
	var prog := UI.lbl(p.box, "", Rect2(x0 + 24, r.position.y + 110, 300, 60), 40, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 8, Art.INK, true)
	var areas := UI.lbl(p.box, "", Rect2(x0 + 24, r.position.y + 158, 330, 30), 20, Color("8a7a66"), HORIZONTAL_ALIGNMENT_LEFT)
	var rank_big := UI.lbl(p.box, "", Rect2(x0 + w - 250, r.position.y + 84, 226, 70), 46, Art.FIRE2, HORIZONTAL_ALIGNMENT_RIGHT, 10, Art.INK, true)
	var rank_sub := UI.lbl(p.box, "", Rect2(x0 + w - 250, r.position.y + 150, 226, 30), 20, Color("8a7a66"), HORIZONTAL_ALIGNMENT_RIGHT)

	# 表头 + 列表
	var hy := r.position.y + 214
	UI.lbl(p.box, "名次", Rect2(x0, hy, 96, 34), 22, Color("8a5a30"))
	UI.lbl(p.box, "昵称", Rect2(x0 + 110, hy, 280, 34), 22, Color("8a5a30"), HORIZONTAL_ALIGNMENT_LEFT)
	UI.lbl(p.box, "进度", Rect2(x0 + w - 170, hy, 150, 34), 22, Color("8a5a30"), HORIZONTAL_ALIGNMENT_RIGHT)
	var list_top := hy + 40
	var list_bot := r.end.y - 128
	var sc := Scroller.new()
	sc.position = Vector2(x0, list_top)
	sc.size = Vector2(w, list_bot - list_top)
	p.box.add_child(sc)
	var status := UI.lbl(p.box, "", Rect2(x0, list_top + 120, w, 150), 26, Color("8a5a30"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var retry := UI.btn(p.box, Rect2(r.get_center().x - 110, list_top + 300, 220, 76), "重试", "green", Callable(), 32)
	retry.visible = false

	# 底部：自己
	var me_row := Control.new()
	me_row.position = Vector2(x0, r.end.y - 112)
	me_row.size = Vector2(w, ROW)
	me_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.box.add_child(me_row)

	var state := {"data": {}, "ok": false, "loading": true}
	var refresh_head := func():
		var pn := Rank.progress_now()
		prog.text = "%d / %d 件" % [pn, Rank.parts_total()]
		areas.text = "完成区域 %d / %d" % [Rank.areas_done(), Rank.areas_total()]
		var me = state["data"].get("me") if state["ok"] else null
		if me is Dictionary:
			rank_big.text = "第 %d 名" % int(me["rank"])
			rank_sub.text = "共 %d 个部落" % int(state["data"].get("total", 0))
		elif state["ok"]:
			rank_big.text = "未上榜"
			rank_sub.text = "建造后自动上传"
		else:
			rank_big.text = "离线"
			rank_sub.text = "排名暂时看不到"
	var render := func():
		for c in sc.content.get_children():
			c.queue_free()
		for c in me_row.get_children():
			c.queue_free()
		refresh_head.call()
		retry.visible = false
		if state["loading"]:
			status.text = "正在联络远方的部落……"
			sc.set_length(0)
			return
		if not state["ok"]:
			status.text = "暂时连不上排行榜服务器。\n先去建造吧，进度会在连上后自动补传。"
			retry.visible = true
			sc.set_length(0)
			_row(me_row, {"rank": 0, "name": Rank.nick, "progress": Rank.progress_now()}, true)
			return
		var top: Array = state["data"].get("top", [])
		status.text = "还没有部落上榜。" if top.is_empty() else ""
		for i in top.size():
			var e: Dictionary = top[i]
			var holder := Control.new()
			holder.position = Vector2(0, i * ROW)
			holder.size = Vector2(w, ROW)
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sc.content.add_child(holder)
			_row(holder, e, str(e.get("id", "")) == G.player_id)
		sc.set_length(top.size() * ROW + 8)
		var me = state["data"].get("me")
		if me is Dictionary:
			_row(me_row, me, true)
		else:
			_row(me_row, {"rank": 0, "name": Rank.nick, "progress": Rank.progress_now()}, true)
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
	Popups.live(p, G.changed, refresh_head)

	reload.call()

## 一行：名次（前三名奖牌）、昵称、进度。mine 为真时高亮。
static func _row(parent: Control, e: Dictionary, mine: bool) -> void:
	var w := parent.size.x
	var rk := int(e.get("rank", 0))
	UI.box(parent, Rect2(0, 4, w, ROW - 8), func(ci, sz):
		if mine:
			_card(ci, sz, Color("ffe08a"), Art.CLAY, 4)
		else:
			_card(ci, sz, Art.BONE, Color("c9a77a"), 2)
		if rk >= 1 and rk <= 3:
			var cols := [Art.FIRE2, Color("d9d4cc"), Color("d08a4a")]
			var m := Art.ell(Vector2(48, sz.y * 0.5), Vector2(24, 24), 40 + rk, 0.03, 18)
			Art.dilate(ci, m, 2.6, Art.INK)
			ci.draw_colored_polygon(m, cols[rk - 1])
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

static func _card(ci: CanvasItem, sz: Vector2, fill: Color, line: Color, lw: float) -> void:
	var b := Art.rrect(Rect2(Vector2(2, 2), sz - Vector2(4, 4)), 14, 7, 0.4)
	ci.draw_colored_polygon(b, fill)
	Art.outline(ci, b, lw, line)
