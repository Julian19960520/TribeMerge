extends RefCounted
## 篝火竞速的独立面板（入口在棋盘订单栏主角卡左边）：
## 1. 开始面板 start()：大概说明规则、奖励，底部「匹配」。关掉就是这次不参加。
## 2. 竞赛面板 race_panel()：主区域是 5 根竖着的进度条，里面一根根香蕉往上堆；先堆满的赢。
## 3. 结算面板 result()：名次和奖励，领取后弹开始面板「再来一局」。
## open() 按当前状态挑一个。

const RaceNet := preload("res://scripts/net/Race.gd")
const Meme := preload("res://scripts/Meme.gd")
const Banana := preload("res://scripts/ui/Banana.gd")

const MEDAL := [Color("f2c35a"), Color("cfc9c0"), Color("d08a4a")]
## 竖条里画多少层香蕉（满 = target）
const LAYERS := 18

static func open() -> PopupBase:
	var race: Node = RaceNet.inst()
	var res: Dictionary = race.pending_result()
	if not res.is_empty():
		return result(res)
	if race.joined() and not race.ended():
		return matching_panel() if race.matching() else race_panel()
	return start()

# ================================================================ 1. 开始面板

static func start(again := false) -> PopupBase:
	var race: Node = RaceNet.inst()
	var p := PopupBase.new()
	p.name = "race_start"
	var r := Rect2(60, 260, 600, 940)
	Popups.frame(p, r, "篝火竞速", Art.CLAY, "fire")
	var x0 := r.position.x + 30
	var w := r.size.x - 60
	var rl: Dictionary = race.rules()
	var tg := int(rl.get("target", 300))
	var podium := int(rl.get("podium", 3))
	var tt: Dictionary = rl.get("title", {}) if rl.get("title") is Dictionary else {}
	UI.title(p.box, "再来一局？" if again else "比赛收香蕉！", Rect2(x0, r.position.y + 50, w, 70), 48, Color("ffd23f"))
	# 香蕉堆装饰
	UI.box(p.box, Rect2(x0, r.position.y + 122, w, 110), func(ci, sz):
		for i in 9:
			var row := 0 if i < 5 else 1
			var col := i if i < 5 else i - 5
			var n := 5 if row == 0 else 4
			Banana.draw(ci, Vector2(sz.x * 0.5 + (col - (n - 1) * 0.5) * 50, 78 - row * 30), 58, (col - 2) * 0.12), false)
	var txt := "· 和 4 位族人比谁先收满 %d 根香蕉。\n· 交付订单就有香蕉飞进竞速入口，订单越值钱香蕉越多。\n· 前 %d 名都收满就结束，前 %d 名有奖励，第 1 名拿「%s」称号。\n· 随时可以开一局，比完再来下一局。" % [
		tg, podium, mini(3, podium), str(tt.get("name", "篝火王"))]
	var l := UI.lbl(p.box, txt, Rect2(x0 + 4, r.position.y + 246, w - 8, 220), 22, Color("6b4a2a"), HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# 奖励
	Popups.section(p.box, "奖励", r.position.y + 474, Color("8a5a30"), r.get_center().x)
	var rws: Array = rl.get("rewards", []) if rl.get("rewards") is Array else []
	for i in 3:
		var y := r.position.y + 516 + i * 62
		var rw: Array = rws[i] if i < rws.size() and rws[i] is Array else []
		var rk := i + 1
		UI.box(p.box, Rect2(x0, y, w, 56), func(ci, sz): _reward_row(ci, sz, rk, rw), false)
		UI.lbl(p.box, str(rk), Rect2(x0 + 4, y + 4, 52, 48), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK, true)
		for k in rw.size():
			UI.lbl(p.box, "×%d" % int(rw[k][1]), Rect2(x0 + 104 + k * 108, y + 10, 64, 40), 22, Art.INK, HORIZONTAL_ALIGNMENT_LEFT)
	var busy := {"on": false}
	var b := UI.btn(p.box, Rect2(r.get_center().x - 150, r.end.y - 130, 300, 104), "匹配", "green", Callable(), 42)
	b.name = "race_match"
	b.pressed.connect(func():
		if busy["on"]:
			return
		busy["on"] = true
		b.enabled = false
		var res: Dictionary = await race.join()
		if not is_instance_valid(p):
			return
		if res.get("ok", false):
			p.close()
			matching_panel()
		else:
			busy["on"] = false
			b.enabled = true
			G.main.toast(str(res.get("message", "连不上服务器，请稍后再试"))))
	G.main._attach_popup(p)
	return p

static func _reward_row(ci: CanvasItem, sz: Vector2, rk: int, rw: Array) -> void:
	var b := Art.rrect(Rect2(Vector2(2, 2), sz - Vector2(4, 4)), 14, 200 + rk, 0.4)
	ci.draw_colored_polygon(b, Art.BONE)
	Art.outline(ci, b, 2.0, Color("c9a77a"))
	var m := Art.ell(Vector2(30, sz.y * 0.5), Vector2(22, 22), 210 + rk, 0.03, 18)
	Art.dilate(ci, m, 2.4, Art.INK)
	ci.draw_colored_polygon(m, MEDAL[rk - 1])
	for k in rw.size():
		Art.item(ci, str(rw[k][0]), Vector2(84 + k * 108, sz.y * 0.5), 46)

# Matching is a separate transient popup; race progress never doubles as matchmaking.
static func matching_panel() -> PopupBase:
	var race: Node = RaceNet.inst()
	var p := PopupBase.new()
	p.name = "race_matching"
	Popups.frame(p, Rect2(52, 390, 616, 650), "匹配族人", Art.CLAY)
	var art := UI.box(p.box, Rect2(80, 500, 560, 380), func(ci, sz):
		var time := float(Time.get_ticks_msec()) / 1000.0
		for i in 5:
			var center := Vector2(64 + i * 108, 125 + sin(time*3+i)*7)
			var role := 0 if i==0 else (i*3+int(time*6))%8
			Meme.portrait(ci, role, center, 88)
			_txt(ci, "我" if i==0 else "…", center+Vector2(0,76), 25, Art.INK)
		_txt(ci, "正在寻找对手"+".".repeat(1+int(time*2)%3), Vector2(sz.x/2,300), 28, Art.INK), false)
	UI.lbl(p.box, "匹配完成后自动进入", Rect2(110, 936, 500, 36), 22, Color("8a5a30"))
	race.watch(p)
	var timer := Timer.new()
	timer.wait_time=.08
	timer.autostart=true
	p.add_child(timer)
	timer.timeout.connect(func():
		if p._closing: timer.stop(); return
		art.queue_redraw()
		if race.matching(): return
		timer.stop()
		p.close()
		p.closed.connect(func():
			if race.ended() and not race.pending_result().is_empty(): result(race.pending_result())
			elif race.joined(): race_panel()))
	G.main._attach_popup(p)
	return p

# ================================================================ 2. 竞赛面板

static func race_panel() -> PopupBase:
	var race: Node = RaceNet.inst()
	var p := PopupBase.new()
	p.name = "race_progress"
	var r := Rect2(36, 200, 648, 1100)
	Popups.frame(p, r, "篝火竞速", Art.CLAY, "fire")
	var area := Rect2(r.position.x + 24, r.position.y + 50, r.size.x - 48, r.size.y - 74)
	var box := UI.box(p.box, area, func(ci, sz): _paint_race(ci, sz, race), false)
	race.watch(p)
	var t := Timer.new()
	t.wait_time = 0.033
	t.autostart = true
	p.add_child(t)
	t.timeout.connect(func():
		if p._closing: t.stop(); return
		box.queue_redraw()
		# 比完了：换成结算面板
		if race.ended() and not race.pending_result().is_empty():
			t.stop()
			p.close()
			result(race.pending_result()))
	G.main._attach_popup(p)
	return p

static func _paint_race(ci: CanvasItem, sz: Vector2, race: Node) -> void:
	var tg: float = race.target()
	var t := float(Time.get_ticks_msec()) / 1000.0
	var top := "还剩 %s" % G.fmt_time(race.secs_left())
	_txt(ci, top, Vector2(sz.x * 0.5, 22), 26, Color("8a5a30"))
	var ms: Array = race.members().duplicate()
	# 自己放最左边，其他按位置
	ms.sort_custom(func(a, b):
		if bool(a.get("me", false)) != bool(b.get("me", false)):
			return bool(a.get("me", false))
		return int(a.get("slot", 0)) < int(b.get("slot", 0)))
	var n := 5
	var cw := sz.x / float(n)
	_paint_top_rewards(ci, sz, race.rules().get("rewards", []))
	var tube_top := 208.0
	var tube_bot := sz.y - 204.0
	var tube_w := 82.0
	for i in n:
		var cx := cw * (i + 0.5)
		var m: Dictionary = ms[i] if i < ms.size() else {}
		var mine := bool(m.get("me", false))
		var tr := Rect2(cx - tube_w * 0.5, tube_top, tube_w, tube_bot - tube_top)
		var tube := Art.rrect(tr, 22, 400 + i, 0.4)
		Art.dilate(ci, tube, 3.0, Art.INK)
		ci.draw_colored_polygon(tube, Color("8a5a30") if mine else Color("6b4a2a"))
		if mine:
			Art.outline(ci, tube, 4.0, Color("ffd23f"))
		if m.is_empty():
			continue
		var s: float = race.score_of(m)
		var fr := clampf(s / maxf(tg, 1.0), 0.0, 1.0)
		var layers := int(floor(fr * LAYERS + 0.001))
		var lh := (tr.size.y - 16.0) / float(LAYERS)
		var rng := RandomNumberGenerator.new()
		for k in layers:
			rng.seed = i * 1000 + k
			var y := tr.end.y - 10.0 - lh * (k + 0.5)
			Banana.draw(ci, Vector2(cx + rng.randf_range(-6, 6), y + 8), 86.0, rng.randf_range(-0.25, 0.25), true)
		# 正在堆的那一层：香蕉从上面掉下来
		var part := fr * LAYERS - layers
		if part > 0.05 and layers < LAYERS and race.dash_of(m) > 0.0:
			var y2 := tr.end.y - 10.0 - lh * (layers + 0.5)
			Banana.draw(ci, Vector2(cx, lerpf(tr.position.y + 10, y2, part) + 8), 86.0, 0.2, true)
		if m.get("finished_at") != null:
			Art.item(ci, "fire_2", Vector2(cx, tube_top - 6), 40)
		var dash: float = race.dash_of(m)
		Meme.portrait(ci, int(m.get("avatar", 0)), Vector2(cx, tube_bot + 100 - absf(sin(t * 18.0)) * 8.0 * dash), 92.0)
		var rk: int = race.place_of(m)
		var mc := Vector2(cx + 32, tube_bot + 135)
		var medal := Art.ell(mc, Vector2(16, 16), 40 + rk, 0.03, 16)
		Art.dilate(ci, medal, 2.4, Art.INK)
		ci.draw_colored_polygon(medal, MEDAL[rk - 1] if rk <= 3 else Color("a08a70"))
		_txt(ci, str(rk), mc, 18, Color.WHITE, 4)
		_txt(ci, "%d" % int(s), Vector2(cx, tube_bot + 30), 30, Color("ffd23f") if mine else Color.WHITE, 6)
		_txt(ci, "我" if mine else str(m.get("name", "")), Vector2(cx, tube_bot + 164), 20, Art.CLAY if mine else Color("6b4a2a"))
	# 终点线
	ci.draw_dashed_line(Vector2(10, tube_top + 8), Vector2(sz.x - 10, tube_top + 8), Color(1, 0.85, 0.3, 0.9), 3.0, 10.0)
	_txt(ci, "交付订单收香蕉！先收满 %d 根的赢" % int(tg), Vector2(sz.x * 0.5, sz.y - 18), 22, Color("8a5a30"))

static func _paint_top_rewards(ci: CanvasItem, sz: Vector2, rewards: Array) -> void:
	var width := sz.x/3.0
	for rank in mini(3,rewards.size()):
		var center := Vector2(width*(rank+.5),64)
		var medal := Art.ell(center,Vector2(19,19),300+rank,.02,18)
		Art.fill(ci,medal,MEDAL[rank],2)
		_txt(ci,str(rank+1),center,23,Color.WHITE,4)
		var rw: Array=rewards[rank]
		for k in rw.size():
			var x := center.x+(k-(rw.size()-1)/2.0)*56
			Art.item(ci,str(rw[k][0]),Vector2(x,122),50)
			_txt(ci,"×%d" % int(rw[k][1]),Vector2(x,162),18,Art.INK)

static func _txt(ci: CanvasItem, s: String, c: Vector2, fs: int, col: Color, ol: int = 0) -> void:
	var f: Font = G.font_body
	if f == null:
		return
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(c.x - w * 0.5, c.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5)
	if ol > 0:
		ci.draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ol, Art.INK)
	ci.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

# ================================================================ 3. 结算面板

static func result(res: Dictionary) -> PopupBase:
	var race: Node = RaceNet.inst()
	var p := PopupBase.new()
	var r := Rect2(60, 250, 600, 980)
	var g: Dictionary = res.get("group", {})
	var me: Dictionary = res.get("me", {})
	var place := int(me.get("place", 0))
	Popups.frame(p, r, "比赛结果", Art.CLAY, "fire" if place == 1 else "")
	var x0 := r.position.x + 30
	var w := r.size.x - 60
	var head := "你赢了！" if place == 1 else ("第 %d 名！" % place if place <= 3 else "第 %d 名" % place)
	UI.title(p.box, head, Rect2(x0, r.position.y + 50, w, 80), 60, Color("ffd23f") if place <= 3 else Color.WHITE)
	var sub := "最先收满 %d 根香蕉，拿下「篝火王」称号" % int(g.get("target", 300)) if place == 1 else ("进了前三，有奖励！" if place <= 3 else "下一局再来！")
	UI.lbl(p.box, sub, Rect2(x0, r.position.y + 128, w, 40), 24, Color("8a5a30"))
	var ms: Array = g.get("members", []) if g.get("members") is Array else []
	ms = ms.duplicate()
	ms.sort_custom(func(a, b): return int(a.get("place", 9)) < int(b.get("place", 9)))
	var tg := float(g.get("target", 300))
	for i in ms.size():
		var m: Dictionary = ms[i]
		var y := r.position.y + 180 + i * 84
		UI.box(p.box, Rect2(x0, y, w, 76), func(ci, sz): _result_row(ci, sz, m, tg), false)
	var rw: Array = me.get("reward", []) if me.get("reward") is Array else []
	if int(me.get("place", 0)) > 3: rw = []
	var ry := r.position.y + 180 + 5 * 84 + 14
	if not rw.is_empty():
		Popups.section(p.box, "奖励", ry, Color("8a5a30"), r.get_center().x)
		var n := rw.size()
		for k in n:
			var cx := r.get_center().x + (float(k) - float(n - 1) * 0.5) * 130.0
			UI.icon(p.box, str(rw[k][0]), Vector2(cx, ry + 96), 84)
			UI.lbl(p.box, "×%d" % int(rw[k][1]), Rect2(cx - 50, ry + 136, 100, 36), 26, Art.INK, HORIZONTAL_ALIGNMENT_CENTER, 0, Art.INK, true)
	if rw.is_empty(): UI.lbl(p.box, "仅前三名获得奖励", Rect2(x0, ry + 60, w, 44), 26, Art.INK)
	var busy := {"on": false}
	var b := UI.btn(p.box, Rect2(r.get_center().x - 140, r.end.y - 120, 280, 96), "领取" if not rw.is_empty() else "知道了", "green", Callable(), 38)
	b.name = "race_claim"
	b.pressed.connect(func():
		if busy["on"]:
			return
		busy["on"] = true
		b.enabled = false
		var out: Dictionary = await race.claim(res)
		if not is_instance_valid(p):
			return
		if out.get("ok", false):
			p.close()
			start(true)
			var got: Array = out.get("rewards", rw) if out.get("rewards") is Array else rw
			if not got.is_empty():
				G.main.present_rewards(got)
			if out.get("title") is Dictionary:
				G.main.toast("获得称号「%s」" % str(out["title"].get("name", "")))
		elif str(out.get("error", "")) == "already_claimed":
			p.close()
			start(true)
		else:
			busy["on"] = false
			b.enabled = true
			G.main.toast(str(out.get("message", "领取失败"))))
	G.main._attach_popup(p)
	return p

static func _result_row(ci: CanvasItem, sz: Vector2, m: Dictionary, tg: float) -> void:
	var mine := bool(m.get("me", false))
	var b := Art.rrect(Rect2(Vector2(2, 2), sz - Vector2(4, 4)), 14, 7, 0.4)
	ci.draw_colored_polygon(b, Color("ffe08a") if mine else Art.BONE)
	Art.outline(ci, b, 4.0 if mine else 2.0, Art.CLAY if mine else Color("c9a77a"))
	var rk := int(m.get("place", 0))
	var mc := Vector2(34, sz.y * 0.5)
	var medal := Art.ell(mc, Vector2(22, 22), 40 + rk, 0.03, 18)
	Art.dilate(ci, medal, 2.4, Art.INK)
	ci.draw_colored_polygon(medal, MEDAL[rk - 1] if rk >= 1 and rk <= 3 else Color("a08a70"))
	_txt(ci, str(rk), mc, 24, Color.WHITE, 5)
	Meme.portrait(ci, int(m.get("avatar", 0)), Vector2(100, sz.y * 0.5 + 6), 62.0)
	var f: Font = G.font_body
	if f:
		ci.draw_string(f, Vector2(142, sz.y * 0.5 + 9), str(m.get("name", "")) + ("（我）" if mine else ""), HORIZONTAL_ALIGNMENT_LEFT, 230, 24, Art.INK)
	var s := float(m.get("score", 0))
	_txt(ci, ("%d 收满" % int(tg)) if m.get("finished_at") != null else "%d 根" % int(s), Vector2(sz.x - 80, sz.y * 0.5), 24,
		Art.CLAY if mine else Color("6b4a2a"))
	if rk == 1:
		Art.item(ci, "fire_2", Vector2(sz.x - 160, sz.y * 0.5), 34)
