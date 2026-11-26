extends PopupBase
## 七日签到面板（参考竞品 10 级的 Daily Rewards）：
## 上面一句说明；中间 1～6 天两排三格，最下面一整条是第 7 天大奖。
## 已领的格子压暗打勾，今天能领的格子发橙光，点格子或下面的按钮领取；领完 7 天从头再来。

const PANEL := Rect2(60, 300, 600, 900)
const GRID_X := 92.0
const GRID_Y := 420.0
const CELL := Vector2(170, 170)
const GAP := 18.0
const BIG_H := 170.0

var tiles: Array = []
var claim_btn: TButton
var hint: Label
var _t := 0.0

func _ready() -> void:
	Popups.frame(self, PANEL, TextCatalog.source("notice.data.61616c7afbe5"), Art.TEAL)
	UI.lbl(box, TextCatalog.source("ui.logingiftpopup.d4b872fab9ba"), Rect2(PANEL.position.x + 30, PANEL.position.y + 62, PANEL.size.x - 60, 40), 24, Color("7a5a3a"))
	var days := LoginGift.days()
	for k in days.size():
		var r := _tile_rect(k)
		var t := UI.hit(box, r, _claim)
		t.extra = _paint_tile.bind(k)
		tiles.append(t)
	hint = UI.lbl(box, "", Rect2(PANEL.position.x + 30, PANEL.end.y - 190, PANEL.size.x - 60, 36), 22, Color("8a6a48"))
	claim_btn = UI.btn(box, Rect2(200, PANEL.end.y - 140, 320, 92), TextCatalog.source("ui.duelpopup.844ab9477225"), "green", _claim, 36)
	G.login_gift_changed.connect(_refresh)
	_refresh()

func _tile_rect(k: int) -> Rect2:
	if k >= 6:
		return Rect2(GRID_X, GRID_Y + 2 * (CELL.y + GAP), 3 * CELL.x + 2 * GAP, BIG_H)
	return Rect2(GRID_X + (k % 3) * (CELL.x + GAP), GRID_Y + (k / 3) * (CELL.y + GAP), CELL.x, CELL.y)

func _refresh() -> void:
	if not is_instance_valid(claim_btn): return
	var can := LoginGift.can_claim()
	claim_btn.enabled = can
	claim_btn.text = TextCatalog.resolve(TextCatalog.source("ui.duelpopup.844ab9477225") if can else TextCatalog.source("ui.logingiftpopup.cdbee4e6e4ea"))
	hint.text = TextCatalog.resolve(TextCatalog.fill(TextCatalog.source("ui.logingiftpopup.1d714f194a38"), LoginGift.today_index() + 1) if can else TextCatalog.source("ui.logingiftpopup.1ae165f4e4c8"))
	for t in tiles: t.queue_redraw()

func _paint_tile(ci: CanvasItem, sz: Vector2, k: int) -> void:
	var got := LoginGift.got(k)
	var today := LoginGift.can_claim() and k == LoginGift.today_index()
	var big := k >= 6
	var base := Color("f0a03c") if big else Color("5fb3a6")
	if today: base = Color("ffb347")
	if got: base = Color("b9ae9a")
	var plate := Art.rrect(Rect2(Vector2.ZERO, sz), 22, 960 + k, 0.4)
	Art.dilate(ci, plate, 3.0, Art.INK)
	if today:
		var glow := 1.0 + 0.04 * sin(_t * 4.0)
		ci.draw_set_transform(sz * 0.5 * (1.0 - glow), 0.0, Vector2(glow, glow))
		ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(-6, -6), sz + Vector2(12, 12)), 26, 990 + k, 0.4), Color(1, 0.9, 0.4, 0.55))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ci.draw_colored_polygon(plate, base)
	EventEntryArt.text(ci, TextCatalog.fill(TextCatalog.source("ui.sevendaypopup.670ac1b359ac"), k + 1), Vector2(sz.x * 0.5, 34), 24, Color.WHITE, 5)
	var rewards: Array = LoginGift.days()[k]
	var n := rewards.size()
	var rad := 40.0 if big else 46.0
	var step := 150.0 if big else 0.0
	for j in n:
		var c := Vector2(sz.x * 0.5 + (j - (n - 1) / 2.0) * step, sz.y * 0.5 + 18.0)
		Paint.reward_bubble(ci, c, rad, str(rewards[j][0]), 0, 960 + k * 3 + j)
		EventEntryArt.text(ci, "×%d" % int(rewards[j][1]), c + Vector2(0, rad + 20), 22, Color.WHITE, 5)
	if got:
		ci.draw_colored_polygon(plate, Color(0, 0, 0, 0.18))
		Paint.glyph(ci, "check", sz * 0.5 + Vector2(0, 10), 1.6)
	var edge := plate.duplicate()
	edge.append(plate[0])
	ci.draw_polyline(edge, Art.INK, 4.0, true)

func _process(delta: float) -> void:
	_t += delta
	if LoginGift.can_claim():
		var k := LoginGift.today_index()
		if k < tiles.size(): tiles[k].queue_redraw()

func _claim() -> void:
	if not LoginGift.can_claim():
		return
	var result: Dictionary = await LoginGift.claim()
	if result.has("error") and str(result["error"]) != "": G.main.toast(str(result["error"]))
	if is_instance_valid(self): _refresh()
