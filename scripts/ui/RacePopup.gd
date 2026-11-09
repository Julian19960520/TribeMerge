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
	Popups.frame(p, r, "香蕉竞速", Art.CLAY, "fire")
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
	var txt := "· 和 4 位族人比谁先收满 %d 根香蕉。\n· 交付订单就有香蕉飞进竞速入口，订单越值钱香蕉越多。\n· 前 %d 名都收满就结束；只有前 %d 名有奖励，名次越靠前越丰富，第 1 名还拿「%s」称号。\n· 随时可以开一局，比完再来下一局。" % [
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
	Sprites.draw(ci, "ev_race_row", Rect2(Vector2(2, 2), sz - Vector2(4, 4)))
	_medal(ci, Vector2(30, sz.y * 0.5), 22.0, rk)
	for k in rw.size():
		Art.item(ci, str(rw[k][0]), Vector2(84 + k * 108, sz.y * 0.5), 46)

# 匹配是单独的面板：五个座位，我先坐好（带黄圈），对手的座位里头像飞快地换，一个个「锁定」；全部到齐自动进竞赛面板。
static func matching_panel() -> PopupBase:
	var race: Node = RaceNet.inst()
	var p := PopupBase.new()
	p.name = "race_matching"
	var r := Rect2(52, 380, 616, 660)
	Popups.frame(p, r, "匹配族人", Art.CLAY, "fire")
	var t0 := Time.get_ticks_msec()
	var lo := (maxi(G.level, 1) - 1) / 5 * 5 + 1
	UI.lbl(p.box, "同等级段 Lv.%d～%d 的族人" % [lo, lo + 4], Rect2(r.position.x + 30, r.position.y + 52, r.size.x - 60, 36), 22, Color("8a5a30"))
	var art := UI.box(p.box, Rect2(r.position.x + 20, r.position.y + 100, r.size.x - 40, 440), func(ci, sz):
		_paint_matching(ci, sz, race, float(Time.get_ticks_msec() - t0) / 1000.0), false)
	UI.lbl(p.box, "匹配完成后自动开赛", Rect2(r.position.x + 30, r.end.y - 82, r.size.x - 60, 36), 22, Color("a08a70"))
	race.watch(p)
	var timer := Timer.new()
	timer.wait_time = 0.033
	timer.autostart = true
	p.add_child(timer)
	timer.timeout.connect(func():
		if p._closing:
			timer.stop()
			return
		art.queue_redraw()
		if race.matching():
			return
		timer.stop()
		p.close()
		p.closed.connect(func():
			if race.ended() and not race.pending_result().is_empty():
				result(race.pending_result())
			elif race.joined():
				race_panel()))
	G.main._attach_popup(p)
	return p

static func _paint_matching(ci: CanvasItem, sz: Vector2, race: Node, el: float) -> void:
	var me: Dictionary = race.me()
	var ms: Array = race.members()
	var total: float = RaceNet.MATCH_SEC
	var found := 0
	for i in 5:
		var row := 0 if i < 2 else 1
		var col := i if i < 2 else i - 2
		var n := 2 if row == 0 else 3
		var c := Vector2(sz.x * 0.5 + (col - (n - 1) * 0.5) * 176.0, 84.0 + row * 178.0)
		var lock_at := 0.0 if i == 0 else total * (0.18 + 0.2 * i)
		var locked := el >= lock_at
		if locked:
			found += 1
		# 座位：圆底
		var seat := Rect2(c + Vector2(-70, -62), Vector2(140, 140))
		Sprites.draw(ci, "ev_race_seat_" + ("me" if i == 0 else ("on" if locked else "off")), seat)
		var role := int(me.get("avatar", 0)) if i == 0 else int(el * 9.0 + i * 3) % 8
		var name := "我"
		if i > 0 and locked:
			var m: Dictionary = _other(ms, i)
			role = int(m.get("avatar", i))
			name = str(m.get("name", "族人"))
		var pop := 1.0 + 0.18 * maxf(0.0, 1.0 - (el - lock_at) / 0.25) if locked and i > 0 else 1.0
		Meme.portrait(ci, role, c, 116.0 * pop)
		if not locked:
			Sprites.draw(ci, "ev_race_seat_shade", seat, Color(0.42, 0.29, 0.16, 0.45))
			_txt(ci, "?", c + Vector2(0, 6), 56, Color.WHITE, 7)
		_txt(ci, name if locked else "…", c + Vector2(0, 96), 22, Art.CLAY if i == 0 else Art.INK)
	var dots := ".".repeat(1 + int(el * 3.0) % 3)
	_txt(ci, ("对手到齐，准备开赛！" if found >= 5 else "正在寻找对手%s  %d/5" % [dots, found]), Vector2(sz.x * 0.5, sz.y - 12), 28, Art.INK)

static func _other(ms: Array, k: int) -> Dictionary:
	var i := 0
	for m in ms:
		if m is Dictionary and not bool(m.get("me", false)):
			i += 1
			if i == k:
				return m
	return {}

# ================================================================ 2. 竞赛面板

static func race_panel() -> PopupBase:
	var race: Node = RaceNet.inst()
	var p := PopupBase.new()
	p.name = "race_progress"
	var r := Rect2(36, 196, 648, 1110)
	Popups.frame(p, r, "香蕉竞速", Art.CLAY, "fire")
	var area := Rect2(r.position.x + 24, r.position.y + 48, r.size.x - 48, r.size.y - 70)
	var box := UI.box(p.box, area, func(ci, sz): _paint_race(ci, sz, race), false)
	# 竹筒顶上的金银铜宝箱：点一下弹气泡看这一名的奖励，点空白收起
	var bubble := Control.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cw := area.size.x / 5.0
	for i in 5:
		var col := i
		var hit := UI.hit(p.box, Rect2(area.position.x + cw * (i + 0.5) - 42, area.position.y + CHEST_Y - 40, 84, 80), func():
			var m := _member_at(race, col)
			var rk: int = race.place_of(m) if not m.is_empty() else 99
			_toggle_rank_bubble(p, bubble, race, rk, area.position.x + cw * (col + 0.5), area.position.y + CHEST_Y + 40))
		hit.name = "race_chest_col_%d" % i
	p.box.add_child(bubble)
	p.on_tap = func(): _toggle_rank_bubble(p, bubble, race, 0, 0, 0)
	race.watch(p)
	var t := Timer.new()
	t.wait_time = 0.033
	t.autostart = true
	p.add_child(t)
	t.timeout.connect(func():
		if p._closing:
			t.stop()
			return
		box.queue_redraw()
		# 比完了：换成结算面板
		if race.ended() and not race.pending_result().is_empty():
			t.stop()
			p.close()
			result(race.pending_result()))
	G.main._attach_popup(p)
	return p

const TUBE_TOP := 196.0
## 宝箱中心（相对比赛区域）
const CHEST_Y := 166.0

static func _sorted_members(race: Node) -> Array:
	var ms: Array = race.members().duplicate()
	ms.sort_custom(func(a, b):
		if bool(a.get("me", false)) != bool(b.get("me", false)):
			return bool(a.get("me", false))
		return int(a.get("slot", 0)) < int(b.get("slot", 0)))
	return ms

static func _member_at(race: Node, col: int) -> Dictionary:
	var ms := _sorted_members(race)
	return ms[col] if col < ms.size() else {}

## 金银铜宝箱：箱体用名次色，箱盖更亮，深色箍带 + 锁扣
static func _rank_chest(ci: CanvasItem, c: Vector2, rank: int, s: float) -> void:
	var k := s / 64.0
	# 箱子和名次章是按 s = 64 预生成的贴图，图心在 (0, -2)
	Sprites.at(ci, "ev_race_chest_%d" % rank, c + Vector2(0, -2) * k, k)
	var mc := c + Vector2(26, -24) * k
	_txt(ci, str(rank + 1), mc, int(16 * k), Color.WHITE, 4)

static func _toggle_rank_bubble(p: PopupBase, layer: Control, race: Node, rank: int, x: float, y: float) -> void:
	var cur: int = p.get_meta("rank_bubble", 0)
	for ch in layer.get_children():
		layer.remove_child(ch)
		ch.queue_free()
	if rank < 1 or rank > 3 or cur == rank:
		p.set_meta("rank_bubble", 0)
		return
	var rws: Array = race.rules().get("rewards", []) if race.rules().get("rewards") is Array else []
	var rw: Array = rws[rank - 1] if rank - 1 < rws.size() and rws[rank - 1] is Array else []
	p.set_meta("rank_bubble", rank)
	var w := maxf(200.0, 40.0 + rw.size() * 82.0)
	var bx := clampf(x - w * 0.5, 50.0, 670.0 - w)
	var tip := x - bx
	var b := UI.hit(layer, Rect2(bx, y + 14, w, 142), func(): pass)
	b.name = "race_rank_bubble"
	b.extra = func(ci, sz):
		var ptr := PackedVector2Array([Vector2(tip - 14, 4), Vector2(tip, -14), Vector2(tip + 14, 4)])
		Art.fill(ci, ptr, Art.BONE, 2.4)
		Sprites.draw(ci, "ev_race_bubble", Rect2(Vector2.ZERO, sz))
		ci.draw_colored_polygon(ptr, Art.BONE)
		_txt(ci, "第 %d 名奖励" % rank, Vector2(sz.x * 0.5, 24), 22, Color("8a5a30"))
		for j in rw.size():
			var cx: float = sz.x * 0.5 + (j - (rw.size() - 1) / 2.0) * 82.0
			Art.item(ci, str(rw[j][0]), Vector2(cx, 78), 56)
			_txt(ci, "×%d" % int(rw[j][1]), Vector2(cx, 120), 20, Color.WHITE, 5)
const TUBE_W := 84.0

static func _paint_race(ci: CanvasItem, sz: Vector2, race: Node) -> void:
	var tg: float = race.target()
	var t := float(Time.get_ticks_msec()) / 1000.0
	# 顶部：剩余时间 + 前三名奖励
	_pill(ci, Rect2(sz.x * 0.5 - 120, 2, 240, 40), "还剩 %s" % G.fmt_time(race.secs_left()), "time", Color.WHITE)
	# 自己放最左边，其他按位置
	var ms := _sorted_members(race)
	var cw := sz.x / 5.0
	var tube_bot := sz.y - 262.0
	# 终点线 + 小旗
	var fy := TUBE_TOP + 10.0
	ci.draw_dashed_line(Vector2(6, fy), Vector2(sz.x - 6, fy), Color("e0a030"), 3.0, 10.0)
	_txt(ci, "终点 %d 根 · 前三名开宝箱" % int(tg), Vector2(sz.x * 0.5, 66), 20, Color("8a5a30"))
	# 竹筒顶上按当前名次摆金银铜宝箱
	for i in mini(5, ms.size()):
		var rk0: int = race.place_of(ms[i]) - 1
		if rk0 >= 0 and rk0 < 3:
			var cc := Vector2(cw * (i + 0.5), CHEST_Y + sin(t * 2.4 + i) * 2.0)
			ci.draw_circle(cc, 34, Color(MEDAL[rk0], 0.25))
			_rank_chest(ci, cc, rk0, 62.0 if rk0 == 0 else 54.0)
	for i in 5:
		var cx := cw * (i + 0.5)
		var m: Dictionary = ms[i] if i < ms.size() else {}
		var mine := bool(m.get("me", false))
		var tr := Rect2(cx - TUBE_W * 0.5, TUBE_TOP, TUBE_W, tube_bot - TUBE_TOP)
		# 竹筒：外框、深色内壁、一侧高光、竹节
		Sprites.draw(ci, "ev_race_tube_" + ("me" if mine else "other"), tr)
		for q in range(1, 4):
			var ny := tr.position.y + tr.size.y * q / 4.0
			ci.draw_line(Vector2(tr.position.x + 4, ny), Vector2(tr.end.x - 4, ny), Color(0, 0, 0, 0.18), 2.0)
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
		var part := fr * LAYERS - layers
		if part > 0.05 and layers < LAYERS and race.dash_of(m) > 0.0:
			var y2 := tr.end.y - 10.0 - lh * (layers + 0.5)
			Banana.draw(ci, Vector2(cx, lerpf(tr.position.y + 10, y2, part) + 8), 86.0, 0.2, true)
		if m.get("finished_at") != null:
			Art.item(ci, "fire_2", Vector2(cx, TUBE_TOP + 30), 44)
		# 进度下面：香蕉数、头像（带名次牌）、名字
		_pill(ci, Rect2(cx - 50, tube_bot + 20, 100, 38), "%d" % int(s), "me" if mine else "other",
			Art.INK if mine else Color.WHITE)
		var dash: float = race.dash_of(m)
		var hc := Vector2(cx, tube_bot + 140 - absf(sin(t * 18.0)) * 8.0 * dash)
		if mine:
			Sprites.draw(ci, "ev_disc", Rect2(hc + Vector2(-52, -46), Vector2(104, 104)), Color(1.0, 0.86, 0.35, 0.9))
		Meme.portrait(ci, int(m.get("avatar", 0)), hc, 88.0)
		var rk: int = race.place_of(m)
		var mc := hc + Vector2(36, 30)
		_medal(ci, mc, 17.0, rk)
		_txt(ci, str(rk), mc, 19, Color.WHITE, 4)
		_txt(ci, "我" if mine else str(m.get("name", "")), Vector2(cx, sz.y - 46), 21, Art.CLAY if mine else Color("6b4a2a"))
	_txt(ci, "交付订单收香蕉，先收满的赢！", Vector2(sz.x * 0.5, sz.y - 14), 20, Color("a08a70"))

## style：time 倒计时 / me 自己的香蕉数 / other 别人的
static func _pill(ci: CanvasItem, r: Rect2, s: String, style: String, fg: Color) -> void:
	Sprites.draw(ci, "ev_race_pill_" + style, r)
	_txt(ci, s, r.get_center(), int(r.size.y * 0.62), fg, 4 if fg == Color.WHITE else 0)

## 名次章：前三名金银铜，其余灰褐（预生成贴图）
static func _medal(ci: CanvasItem, c: Vector2, rad: float, rk: int) -> void:
	Sprites.draw(ci, "ev_medal_%d" % (rk - 1 if rk >= 1 and rk <= 3 else 3), Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0))

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
	Sprites.draw(ci, "ev_race_result_" + ("me" if mine else "other"), Rect2(Vector2(2, 2), sz - Vector2(4, 4)))
	var rk := int(m.get("place", 0))
	var mc := Vector2(34, sz.y * 0.5)
	_medal(ci, mc, 22.0, rk)
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
