class_name EventEntryArt
extends RefCounted
## 棋盘任务栏的活动入口（香蕉竞速 / 月石遗迹 / 七日任务）：没有卡片底，底部对齐。
## 从下往上：一行活动名 → 状态小牌（数量 / 倒计时 / 领奖 / 锁）→ 主题图（预生成贴图，见 scripts/sprites/events.gd）。
## 三张图画在同一个 100×100 的格子里、落在同一条地面线上，视觉分量一致。
##
## kind：race / ruins / seven，或一张贴图的 res:// 路径（以后别的合成活动用自己的图）。
## badge：{"text": "×12", "style": "num|time|go|lock|teal|gold|silver|bronze"}，空字典不画。
## dot：右上角红点（有奖可领）。bump：0~1，香蕉飞进来时图片弹一下。

const PILL := {
	"num": [Color("fff3d2"), Color("6b3f1d")],
	"time": [Color("5a3a22"), Color("ffe9a4")],
	"go": [Color("7cc243"), Color.WHITE],
	"lock": [Color("9b958b"), Color.WHITE],
	"teal": [Color("4fa39a"), Color.WHITE],
	"gold": [Color("ffcf3f"), Color("6b3f1d")],
	"silver": [Color("dfe3e6"), Color("4a4f55")],
	"bronze": [Color("e09a5c"), Color("5a2e12")],
}

static func paint(ci: CanvasItem, sz: Vector2, kind: String, title: String, badge := {}, locked := false, dot := false, bump := 0.0) -> void:
	var ground := sz.y - 46.0
	var c := Vector2(sz.x * 0.5, ground)
	# 地面影子
	Sprites.draw(ci, "ev_ell_shadow", Rect2(c + Vector2(-44, -10), Vector2(88, 16)), Color(0.16, 0.1, 0.04, 0.28))
	var s := 1.08 * (1.0 + 0.12 * sin(bump * PI))
	if kind in ["duel", "race", "ruins", "seven"]:
		# 主题图预生成在 scripts/sprites/events.gd（原点 = 地面中点，图心在 (0, -54)）
		Sprites.at(ci, "ev_entry_%s%s" % [kind, "_grey" if locked else ""], c + Vector2(0, -54) * s, s)
	else:
		ci.draw_set_transform(c, 0.0, Vector2(s, s))
		ci.draw_texture_rect(MergeEvent.texture(kind), Rect2(-50, -104, 100, 110), false, Color(.7, .7, .7) if locked else Color.WHITE)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if locked: Paint.glyph(ci, "lock", c + Vector2(0, -50), .7)
	if dot: Paint.badge_num(ci, c + Vector2(42, -100), 8, 10)
	if not badge.is_empty(): _pill(ci, c + Vector2(0, 4), str(badge.get("text", "")), str(badge.get("style", "num")))
	text(ci, title, Vector2(sz.x * 0.5, sz.y - 8), 21, Color("fff0c5"))

static func text(ci: CanvasItem, s: String, center: Vector2, fs: int, color: Color, ol := 6) -> void:
	var f: Font = G.font_title
	var p := center - Vector2(f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x / 2, 0)
	ci.draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ol, Art.INK)
	ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

## 状态小牌：压在图片脚下，宽度随字
static func _pill(ci: CanvasItem, c: Vector2, s: String, style: String) -> void:
	var cols: Array = PILL.get(style, PILL["num"])
	var f: Font = G.font_title
	var fs := 18
	var w := maxf(44.0, f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 20.0)
	var r := Rect2(c - Vector2(w * 0.5, 13), Vector2(w, 26))
	Sprites.draw(ci, "ev_pill_" + (style if PILL.has(style) else "num"), r)
	var p := Vector2(c.x - f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5, c.y + 7)
	if style in ["go", "lock", "teal"]:
		ci.draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Art.INK)
	ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cols[1])
