class_name IconText
extends RefCounted
## 图文混排：文案里写 {xp}、{energy} 之类的记号，显示时就地换成资源图标。
##
## 记号一览（顺序和顶栏一致）：
##   {xp}     灵感灯泡（主角经验）
##   {energy} 体力
##   {banana} 不那那
##   {amber}  琥珀
##   {sand}   沙漏
##   {token}  祭典鼓（活动积分）
##   {item:物品编号}  任意物品，例如 {item:fire_3}
##
## 用法：
##   - UI.lbl 建出来的标签自动支持；之后直接改 .text 也行（下一帧前换好）。
##   - RichTextLabel 用 IconText.set_rich(label, bbcode) 代替 label.text = bbcode。
##   - 画布里直接画字用 IconText.draw_line(...)。

const ICONS := {
	"xp": "xp_1",
	"energy": "fire_2",
	"banana": "shell_2",
	"amber": "amber_2",
	"sand": "sand_2",
	"token": "token_1",
}
## 每张图的留白不一样：[绘制尺寸倍率, 中心偏移（按绘制尺寸 100 算）]，让不同图标在字里看起来一样大、压在行中线上
const FIT := {
	"xp_1": [0.95, Vector2(0, 2)],
	"fire_2": [1.12, Vector2(-2, -2)],
	"shell_2": [1.0, Vector2(-4, -2)],
	"amber_2": [0.98, Vector2(0, -2)],
	"sand_2": [1.15, Vector2(0, -2)],
	"token_1": [0.95, Vector2(0, 0)],
}
## 图标占一个全角空格的位置，左右各垫一个细空格免得贴字；绘制尺寸 = 字号 × SCALE（物品图四周有留白，所以比字号大）
const SLOT := "　"
const PAD := " "
const SCALE := 1.55
## RichTextLabel 里的图标贴图边长（按字号的倍数）
const RICH_SCALE := 1.15
const TEX_PX := 96

static var _rx: RegEx
static var _textures := {}
static var _holder: Node

static func _regex() -> RegEx:
	if _rx == null:
		_rx = RegEx.create_from_string("\\{(xp|energy|banana|amber|sand|token|item:[a-z0-9_]+)\\}")
	return _rx

static func has_icons(text: String) -> bool:
	return text.contains("{") and _regex().search(text) != null

## 记号 → 物品编号
static func icon_id(token: String) -> String:
	if token.begins_with("item:"):
		return token.substr(5)
	return str(ICONS.get(token, ""))

## 拆开：{"text": 记号换成占位空格后的文字, "icons": [[字符下标, 物品编号], ...]}
static func split(text: String) -> Dictionary:
	var out := ""
	var icons: Array = []
	var at := 0
	for m in _regex().search_all(text):
		out += text.substr(at, m.get_start() - at) + PAD
		icons.append([out.length(), icon_id(m.get_string(1))])
		out += SLOT + PAD
		at = m.get_end()
	out += text.substr(at)
	return {"text": out, "icons": icons}

## 只要文字（给量宽度、写日志用）：记号换成占位空格
static func plain(text: String) -> String:
	return split(text)["text"] if has_icons(text) else text

## 以 c 为中心画一个字号为 fs 的行内图标
static func paint(ci: CanvasItem, id: String, c: Vector2, fs: float) -> void:
	var fit: Array = FIT.get(id, [1.0, Vector2.ZERO])
	var s := fs * SCALE * float(fit[0])
	Art.item(ci, id, c + (fit[1] as Vector2) * (s / 100.0), s)

## 画一行带图标的字（ci.draw_string 的替代）。pos 是基线左端，align/width 同 draw_string。
static func draw_line(ci: CanvasItem, font: Font, pos: Vector2, text: String, align: int = HORIZONTAL_ALIGNMENT_LEFT,
		width: float = -1.0, fs: int = 16, col: Color = Color.WHITE, outline: int = 0, ocol: Color = Color.BLACK) -> void:
	var parts := split(TextCatalog.resolve(text))
	var t: String = parts["text"]
	if outline > 0:
		ci.draw_string_outline(font, pos, TextCatalog.resolve(t), align, width, fs, outline, ocol)
	ci.draw_string(font, pos, TextCatalog.resolve(t), align, width, fs, col)
	if parts["icons"].is_empty():
		return
	var total := font.get_string_size(TextCatalog.resolve(t), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x0 := pos.x
	if width > 0.0:
		if align == HORIZONTAL_ALIGNMENT_CENTER: x0 += (width - total) * 0.5
		elif align == HORIZONTAL_ALIGNMENT_RIGHT: x0 += width - total
	var slot_w := font.get_string_size(TextCatalog.resolve(SLOT), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var mid_y := pos.y - font.get_ascent(fs) + font.get_height(fs) * 0.5
	for ic in parts["icons"]:
		var before := font.get_string_size(TextCatalog.resolve(t.substr(0, int(ic[0]))), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		paint(ci, str(ic[1]), Vector2(x0 + before + slot_w * 0.5, mid_y), fs)

## 给 RichTextLabel 填带图标的 BBCode。没有记号时等同于 label.text = bbcode。
static func set_rich(label: RichTextLabel, bbcode: String) -> void:
	if not has_icons(bbcode):
		label.text = TextCatalog.resolve(bbcode)
		return
	label.text = ""
	label.clear()
	var fs := label.get_theme_font_size("normal_font_size")
	var side := roundi(fs * RICH_SCALE)
	var at := 0
	for m in _regex().search_all(bbcode):
		label.append_text(TextCatalog.resolve(bbcode.substr(at, m.get_start() - at)))
		label.add_text(PAD)
		label.add_image(texture(icon_id(m.get_string(1))), side, side, Color.WHITE, INLINE_ALIGNMENT_CENTER)
		label.add_text(PAD)
		at = m.get_end()
	label.append_text(TextCatalog.resolve(bbcode.substr(at)))

## 物品图标的贴图（RichTextLabel 只认贴图）：在后台小视口里画一次，按编号缓存
static func texture(id: String) -> Texture2D:
	if _textures.has(id):
		return _textures[id]
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	if _holder == null or not is_instance_valid(_holder):
		_holder = Node.new()
		_holder.name = "IconTextures"
		tree.root.add_child.call_deferred(_holder)
	var vp := SubViewport.new()
	vp.size = Vector2i(TEX_PX, TEX_PX)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var d := DrawBox.new()
	d.boil = false
	d.size = Vector2(TEX_PX, TEX_PX)
	# 贴图边长按字号 × RICH_SCALE 显示，图标按 SCALE 画：换算到 TEX_PX 画布
	var fs := TEX_PX / RICH_SCALE
	d.painter = func(ci, sz): paint(ci, id, sz * 0.5, fs)
	vp.add_child(d)
	_holder.add_child.call_deferred(vp)
	var tex := vp.get_texture()
	_textures[id] = tex
	return tex
