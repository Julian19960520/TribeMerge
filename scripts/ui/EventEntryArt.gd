class_name EventEntryArt
extends RefCounted
const EntrySprites := preload("res://scripts/sprites/events.gd")
const TextureCache := preload("res://scripts/resources/TextureCache.gd")
const Banana := preload("res://scripts/ui/Banana.gd")
## 棋盘任务栏的活动入口：没有卡片底，底部对齐，不写活动名。
## 从下往上：剩余时间 → 积分进度条（有的活动才画）→ 主题图（预生成贴图，见 scripts/sprites/events.gd）。
## 主题图画在同一个格子里、落在同一条地面线上，没有奶白贴纸边，视觉分量一致。
##
## kind：race / ruins / seven / duel / tiger，或一张贴图的 res:// 路径（以后别的合成活动用自己的图）。
## info：
##   left   剩余秒数，<0 不画时间
##   have / need  进度条（need<=0 不画）；rival 对手的分，在条上画一道红刻度
##   icon   进度条左端的积分图标：banana / bone / tag，或一张贴图的 res:// 路径
##   lock   未解锁时代替时间的那行字（如「12级」）
## dot：右上角红点（有奖可领）。bump：0~1，积分飞进来时图片弹一下。

const BAR_W := 88.0
const BAR_H := 20.0
const PILL_FILL := Color("5c3a1e")

static func paint(ci: CanvasItem, sz: Vector2, kind: String, info := {}, locked := false, dot := false, bump := 0.0) -> void:
	var c := Vector2(sz.x * 0.5, ground(sz))
	Sprites.draw(ci, "ev_ell_shadow", Rect2(c + Vector2(-44, -10), Vector2(88, 16)), Color(0.16, 0.1, 0.04, 0.28))
	var s := 1.08 * (1.0 + 0.12 * sin(bump * PI))
	if kind in ["race", "ruins", "seven", "duel", "tiger"]:
		# 主题图预生成在 scripts/sprites/events.gd（原点 = 地面中点，图心在 (0, -54)）
		Sprites.at(ci, "ev_entry_%s%s" % [kind, "_grey" if locked else ""], c + Vector2(0, -54) * s, s)
	else:
		ci.draw_set_transform(c, 0.0, Vector2(s, s))
		var icon := MergeEventArt.texture(kind)
		TextureCache.hold(ci, icon)
		ci.draw_texture_rect(icon, Rect2(-50, -104, 100, 110), false, Color(.7, .7, .7) if locked else Color.WHITE)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if locked: Paint.glyph(ci, "lock", c + Vector2(0, -50), .7)
	if dot: Paint.badge_num(ci, c + Vector2(42, -100), 8, 10)
	footer(ci, sz, info)

## 地面线：压在进度条后面，进度条盖住图片底部
static func ground(sz: Vector2) -> float:
	return sz.y - 40.0

## 底部两行：进度条（可选）+ 剩余时间 / 解锁等级
static func footer(ci: CanvasItem, sz: Vector2, info: Dictionary) -> void:
	var need := float(info.get("need", 0))
	if need > 0.0:
		var have := float(info.get("have", 0))
		var r := Rect2(Vector2((sz.x - BAR_W) * 0.5 + 8.0, sz.y - 48.0), Vector2(BAR_W, BAR_H))
		Paint.bar(ci, r, have / need, Art.OCHRE)
		if info.has("rival"):
			var x := r.position.x + 3.0 + (r.size.x - 6.0) * clampf(float(info["rival"]) / need, 0.0, 1.0)
			ci.draw_line(Vector2(x, r.position.y - 3), Vector2(x, r.end.y + 3), Art.INK, 5.0, true)
			ci.draw_line(Vector2(x, r.position.y - 1.5), Vector2(x, r.end.y + 1.5), Art.CLAY, 2.6, true)
		text(ci, "%d/%d" % [int(have), int(need)], Vector2(r.get_center().x + 6.0, r.end.y - 4.0), 15, Color.WHITE, 4)
		point_icon(ci, str(info.get("icon", "")), Vector2(r.position.x, r.get_center().y))
	var line := str(info.get("lock", ""))
	var clock := false
	if line == "" and int(info.get("left", -1)) >= 0:
		line = G.fmt_time(int(info["left"]))
		clock = true
	if line == "": return
	var f: Font = G.font_title
	var fs := 18
	var w := f.get_string_size(TextCatalog.resolve(line), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var gw := 22.0 if clock else 0.0
	var x0 := sz.x * 0.5 - (w + gw) * 0.5
	# 时间 / 解锁等级垫一块深棕胶囊，和进度条、主角经验条一个样式；底边压在格子底线上
	var pill := Rect2(x0 - 9.0, sz.y - 26.0, w + gw + 18.0, 24.0)
	Sprites.draw(ci, "board_epill_ink", pill)
	Sprites.draw(ci, "board_epill_fill", pill, PILL_FILL)
	if clock: Paint.glyph(ci, "clock", Vector2(x0 + 8, sz.y - 12), 0.8)
	text(ci, line, Vector2(x0 + gw + w * 0.5, sz.y - 6), fs, Color("fff0c5"), 5)

static func text(ci: CanvasItem, s: String, center: Vector2, fs: int, color: Color, ol := 6) -> void:
	var f: Font = G.font_title
	var p := center - Vector2(f.get_string_size(TextCatalog.resolve(s), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x / 2, 0)
	ci.draw_string_outline(f, p, TextCatalog.resolve(s), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ol, Art.INK)
	ci.draw_string(f, p, TextCatalog.resolve(s), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

## 进度条左端的积分图标，约 36px
static func point_icon(ci: CanvasItem, kind: String, c: Vector2) -> void:
	match kind:
		"": return
		"banana": Banana.draw(ci, c + Vector2(0, 2), 36.0, -0.5)
		"bone": Sprites.at(ci, "fos_bone_limb_1x2", c, 0.24, PI * 0.25)
		"tag":
			Sprites.draw(ci, "ev_sd_tag_30", Rect2(c - Vector2(17, 18), Vector2(34, 36)))
		_:
			var icon := MergeEventArt.texture(kind)
			if icon == null: return
			TextureCache.hold(ci, icon)
			ci.draw_texture_rect(icon, Rect2(c - Vector2(18, 18), Vector2(36, 36)), false)
