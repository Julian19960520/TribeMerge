extends PopupBase
const PS := preload("res://scripts/sprites/popups.gd")
## 自选宝箱：三张卡片三选一。点卡片先选中（抬起 + 金边 + 勾），再点「就要它」确认，
## 选中的物品替换棋盘上宝箱那一格。每张卡写清楚给多少（40 体力 / 15 琥珀 / 3 件随机物品）
## 和用途小签，三项价值相近（见 data/choice_chests.json），让玩家按眼下需要挑。
const R := Rect2(40, 370, 640, 740)
const CARD_W := 184.0
const CARD_H := 316.0
const CARD_Y := 612.0
var cell := -1
var box_id := ""
var options: Array[TButton] = []
var confirm: TButton
var picked := -1
var _pending := false
var _choices: Array = []

func _ready() -> void:
	var c := ChoiceChest.definition(box_id)
	Popups.frame(self, R, str(c.get("title", "自选宝箱")), Art.TEAL)
	_choices = c.get("choices", [])
	# 顶部：发光的宝箱
	UI.box(box, Rect2(260, 400, 200, 146), func(ci, sz):
		var cc := Vector2(sz.x * 0.5, 74)
		for k in 12:
			var a := TAU * k / 12.0
			var p1 := cc + Vector2(cos(a - 0.12), sin(a - 0.12)) * 30
			var p2 := cc + Vector2(cos(a), sin(a)) * 92
			var p3 := cc + Vector2(cos(a + 0.12), sin(a + 0.12)) * 30
			ci.draw_colored_polygon(PackedVector2Array([p1, p2, p3]), Color(1, 0.85, 0.4, 0.22))
		ci.draw_circle(cc, 56, Color(1, 0.93, 0.65, 0.35))
		Art.item(ci, box_id, cc, 132))
	UI.lbl(box, "三选一 · 选中的物品放在宝箱的位置", Rect2(80, 544, 560, 34), 22, Color("806141"))
	if _choices.size() != 3: return
	for k in 3:
		var id := str(_choices[k])
		var x := 360.0 + (k - 1) * (CARD_W + 16) - CARD_W * 0.5
		var b := UI.btn(box, Rect2(x, CARD_Y, CARD_W, CARD_H), "", "none", _choose.bind(k))
		b.name = "choice_%d" % k
		b.pivot_offset = Vector2(CARD_W, CARD_H) * 0.5
		b.extra = func(ci, sz): _paint_card(ci, sz, k, id)
		UI.lbl(b, _tag(id), Rect2(CARD_W * 0.5 - 56, -14, 112, 34), 19, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
		UI.lbl(b, Data.name_of(id), Rect2(6, 176, CARD_W - 12, 36), 24, Art.INK)
		UI.lbl(b, _amount(id), Rect2(14, 222, CARD_W - 28, 44), 24, Color("6b3d1a"))
		options.append(b)
	confirm = UI.btn(box, Rect2(190, 958, 340, 86), "先选一件", "green", _confirm, 36)
	confirm.name = "choice_confirm"
	confirm.enabled = false

func _paint_card(ci: CanvasItem, sz: Vector2, k: int, id: String) -> void:
	var on := picked == k
	var dim := picked >= 0 and not on
	# 卡片底（木框、内底、聚光圈、数量胶囊）
	Sprites.draw(ci, "pop_cc_card_" + ("on" if on else ("dim" if dim else "n")), PS.CC_CARD)
	Art.item(ci, id, Vector2(sz.x * 0.5, 98), 120)
	# 用途小签（标签文字是子节点）
	var t := Rect2(sz.x * 0.5 - 54, -12, 108, 32)
	Sprites.draw(ci, "pop_tag_base", t)
	Sprites.draw(ci, "pop_tag_fill", t, [Art.CLAY, Color("d9962a"), Art.TEAL][k % 3])
	if on:
		var cc := Vector2(sz.x - 22, 26)
		ci.draw_circle(cc, 20, Art.INK)
		ci.draw_circle(cc, 17, Art.MOSS)
		Paint.check_mark(ci, cc, 0.9)
	if dim:
		Sprites.draw(ci, "pop_cc_dimmer", PS.CC_CARD, Color(0.25, 0.15, 0.08, 0.18))

static func _tag(id: String) -> String:
	match Rewards.kind(id):
		"energy": return "补体力"
		"amber": return "攒琥珀"
		"shell": return "攒贝币"
		"sand": return "加速"
		"chest": return "碰运气"
		"pack": return "抽卡"
	return "直接用"

static func _amount(id: String) -> String:
	var unit := {"energy": "体力", "amber": "琥珀", "shell": "贝币", "sand": "沙漏"}
	var kind := Rewards.kind(id)
	if unit.has(kind) and Data.value_of(id) > 0:
		return "%d %s" % [Data.value_of(id), unit[kind]]
	if kind == "chest": return "3 件随机物品"
	if kind == "pack": return "一包典藏卡"
	return "×1"

func _choose(option: int) -> void:
	if _pending: return
	picked = option
	for k in options.size():
		var b: TButton = options[k]
		var tw := b.create_tween().set_parallel(true)
		tw.tween_property(b, "position:y", CARD_Y - (12.0 if k == option else 0.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector2.ONE * (1.04 if k == option else 0.97), 0.18)
		b.queue_redraw()
	confirm.enabled = true
	confirm.text = "就要%s" % Data.name_of(str(_choices[option]))
	confirm.queue_redraw()

func _confirm() -> void:
	if _pending or picked < 0: return
	_pending = true
	confirm.enabled = false; confirm.queue_redraw()
	var result: Dictionary = await ChoiceChest.choose(cell, box_id, picked)
	if not is_instance_valid(self): return
	_pending = false
	if result.has("error"):
		G.main.toast(str(result["error"]))
		confirm.enabled = true; confirm.queue_redraw()
		return
	G.main.board_screen.board.pop(cell)
	G.main.board_screen.board.burst(cell)
	Sfx.play("merge")
	close()

func close() -> void:
	if _pending: return
	super.close()
