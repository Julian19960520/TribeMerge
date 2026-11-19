class_name Paint
extends RefCounted
const Meme := preload("res://scripts/Meme.gd")
const TextureCache := preload("res://scripts/resources/TextureCache.gd")
## 生成图片用的尺寸、种子表都在目录文件里
const PS := preload("res://scripts/sprites/paint.gd")
## 界面部件、角色、卡牌与村庄的程序化绘制。

const BTN := {
	"green": [Color("8cc63f"), Color("4f8a1f"), Color("c3ea7a")],
	"orange": [Color("f4a933"), Color("b9661a"), Color("ffd98a")],
	"grey": [Color("c2bbaf"), Color("847d72"), Color("e3ddd2")],
	"teal": [Color("4fb3a6"), Color("2a7469"), Color("8fe0d4")],
	"red": [Color("dd5a33"), Color("8f2e15"), Color("ff9a72")],
	"wood": [Color("c98b4a"), Color("7a4a22"), Color("e8b67a")],
	"hide": [Color("f6e7c8"), Color("c9a774"), Color("fffaf0")],
	"purple": [Color("a35ce0"), Color("5e2a8f"), Color("d6a8ff")],
}

static func button(ci: CanvasItem, r: Rect2, style: String, _seed: int = 0, _pressed: bool = false) -> void:
	Sprites.draw(ci, "btn_" + (style if BTN.has(style) else "green"), r)

static func round_btn(ci: CanvasItem, c: Vector2, rad: float, style: String, _seed: int = 0) -> void:
	Sprites.draw(ci, "rbtn_" + (style if BTN.has(style) else "teal"), Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0))

static func panel(ci: CanvasItem, r: Rect2, _seed: int = 1) -> void:
	Sprites.draw(ci, "panel", r)
	Sprites.at(ci, "panel_ornament", Vector2(r.get_center().x, r.end.y - 34))

## 横幅：赭石框 + col 颜色的布面
static func banner(ci: CanvasItem, r: Rect2, col: Color, _seed: int = 2) -> void:
	Sprites.draw(ci, "banner_base", r)
	Sprites.draw(ci, "banner_fill", r.grow(-7), col)
	Sprites.draw(ci, "banner_top", r)

## 图鉴里还没领的新发现：红礼盒。
static func gift(ci: CanvasItem, c: Vector2, s: float) -> void:
	Sprites.at(ci, "paint_gift", c, s / PS.S_GIFT)

static func close_btn(ci: CanvasItem, c: Vector2, rad: float = 26.0, _seed: int = 4) -> void:
	Sprites.at(ci, "close_btn", c, rad / 26.0)

static func pill(ci: CanvasItem, r: Rect2, _seed: int = 5) -> void:
	Sprites.draw(ci, "pill", r)

static func plus_badge(ci: CanvasItem, c: Vector2, _seed: int = 6) -> void:
	Sprites.at(ci, "plus_badge", c)

static func badge_num(ci: CanvasItem, c: Vector2, _seed: int = 7, radius: float = 16.0) -> void:
	Sprites.at(ci, "badge_num", c, radius / 16.0)

static func level_badge(ci: CanvasItem, c: Vector2, s: float, _seed: int = 8) -> void:
	Sprites.at(ci, "level_badge", c, s / 220.0)

static func bar(ci: CanvasItem, r: Rect2, t: float, col: Color = Art.MOSS, _seed: int = 9) -> void:
	var thin := r.size.y < 20.0
	Sprites.draw(ci, "bar_bg_thin" if thin else "bar_bg", r)
	t = clampf(t, 0.0, 1.0)
	if t > 0.02:
		var fr := Rect2(r.position + Vector2(3, 3), Vector2(maxf(r.size.y - 6, (r.size.x - 6) * t), r.size.y - 6))
		Sprites.draw(ci, "bar_fill_thin" if thin else "bar_fill", fr, col)
		if not thin:
			Sprites.draw(ci, "bar_hl", Rect2(fr.position + Vector2(6, 2), Vector2(maxf(4, fr.size.x - 12), fr.size.y * 0.3)), Color(1, 1, 1, 0.35))

## 选中格的四角括号。图是白色画的，按 col 染色。
static func cell_bracket(ci: CanvasItem, r: Rect2, col: Color = Color("ffd23f")) -> void:
	Sprites.draw(ci, "cell_bracket", r, col)

static func check_mark(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	Sprites.at(ci, "check_mark", c, s)

# ---------------------------------------------------------------- 小图标（按钮内）

## 图按 2 倍生成；可染色的画成白色，按 col 染
static func glyph(ci: CanvasItem, kind: String, c: Vector2, s: float = 1.0, col: Color = Color.WHITE) -> void:
	if not PS.GLYPHS.has(kind):
		return
	if PS.GLYPH_FIXED.has(kind):
		Sprites.at(ci, "paint_glyph_" + kind, c, s * 0.5)
		return
	Sprites.at(ci, "paint_glyph_" + kind, c, s * 0.5, 0.0, col)
	if kind == "gear":
		Sprites.at(ci, "paint_glyph_gear_hole", c, s * 0.5)

# ---------------------------------------------------------------- 大图标（主页按钮）

static func hammer(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	Sprites.at(ci, "paint_hammer", c, s / PS.K_HAMMER)

static func book(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	Sprites.at(ci, "paint_book", c, s / PS.K_BOOK)

static func cards_icon(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	Sprites.at(ci, "paint_cards", c, s / PS.K_CARDS)

static func hut_icon(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	Sprites.at(ci, "paint_hut", c, s / PS.K_HUT)

static func shop_icon(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	Sprites.at(ci, "paint_shop", c, s / PS.K_SHOP)

static func pouch(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	Sprites.at(ci, "paint_pouch", c, s / PS.K_POUCH)

static func home_icon(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	Sprites.at(ci, "paint_home", c, s / PS.K_HOME)

## 配置首页上每个编辑器的标记。按这一页在改什么来画。
static func cfg_icon(ci: CanvasItem, kind: String, c: Vector2, size: float) -> void:
	var s := size / 100.0
	match kind:
		"chains":
			Art.item(ci, "fruit_1", c, size)
		"albums":
			cards_icon(ci, c, s * 1.45)
		"builds":
			hut_icon(ci, c + Vector2(0, 4.0 * s), s * 1.05)
		"level":
			Art.item(ci, "xp_1", c, size)
		_:
			if PS.CFG_KINDS.has(kind):
				Sprites.at(ci, "paint_cfg_" + kind, c, s)

static func _cfg_rand(ci: CanvasItem, c: Vector2, s: float) -> void:
	Sprites.at(ci, "paint_cfg_rand", c, s)

static func _cfg_unlock(ci: CanvasItem, c: Vector2, s: float) -> void:
	Sprites.at(ci, "paint_cfg_unlock", c, s)

static func _cfg_board(ci: CanvasItem, c: Vector2, s: float) -> void:
	Sprites.at(ci, "paint_cfg_board", c, s)

static func _cfg_story(ci: CanvasItem, c: Vector2, s: float) -> void:
	Sprites.at(ci, "paint_cfg_story", c, s)

static func _cfg_pass(ci: CanvasItem, c: Vector2, s: float) -> void:
	Sprites.at(ci, "paint_cfg_pass", c, s)

static func _cfg_people(ci: CanvasItem, c: Vector2, s: float) -> void:
	Sprites.at(ci, "paint_cfg_people", c, s)

static func _cfg_amber(ci: CanvasItem, c: Vector2, s: float) -> void:
	Sprites.at(ci, "paint_cfg_amber", c, s)

static func _cfg_rules(ci: CanvasItem, c: Vector2, s: float) -> void:
	Sprites.at(ci, "paint_cfg_rules", c, s)

static func _cfg_tile(ci: CanvasItem, r: Rect2, fill: Color, _seed: int) -> void:
	Sprites.draw(ci, "paint_cfg_tile_base", r)
	Sprites.draw(ci, "paint_cfg_tile_fill", r, fill)
	Sprites.draw(ci, "paint_cfg_tile_line", r)

static func _cfg_pip(ci: CanvasItem, c: Vector2, col: Color) -> void:
	Sprites.at(ci, "paint_cfg_pip_fill", c, 1.0, 0.0, col)
	Sprites.at(ci, "paint_cfg_pip_line", c)

static func _mini_face(ci: CanvasItem, c: Vector2, r: float, skin: Color, _seed: int) -> void:
	Sprites.at(ci, "paint_mini_face_skin", c, r / PS.R_MINI, 0.0, skin)
	Sprites.at(ci, "paint_mini_face_line", c, r / PS.R_MINI)

# ---------------------------------------------------------------- 角色

## 三层：墨线底、皮肤（按 skin 染）、五官
static func face(ci: CanvasItem, c: Vector2, r: float, skin: Color, _seed: int, smile: bool = true) -> void:
	var k := r / PS.R_FACE
	Sprites.at(ci, "paint_face_base", c, k)
	Sprites.at(ci, "paint_face_skin", c, k, 0.0, skin)
	Sprites.at(ci, "paint_face_top" if smile else "paint_face_top_plain", c, k)

static func portrait(ci: CanvasItem, kind: int, c: Vector2, s: float) -> void:
	Meme.portrait(ci, kind, c, s)

static func face_mouth_only(ci: CanvasItem, c: Vector2, r: float) -> void:
	Sprites.at(ci, "paint_face_mouth", c, r / PS.R_MOUTH)

## 小酋长使用完整画像，衣饰直接包含在原图中。
static func mascot(ci: CanvasItem, c: Vector2, s: float, _prop: String = "") -> void:
	Meme.draw_portrait(ci, Meme.XIAOYA, Rect2(c + Vector2(-0.48, -0.66) * s, Vector2(0.96, 1.28) * s))

## 主角阿焰（Meme.HERO）和小牙站在一起。c、s 和原来的画法对齐（整张约 280*s/100 高）。
static func heroine(ci: CanvasItem, c: Vector2, s: float) -> void:
	var k := s / 100.0
	Meme.draw_portrait(ci, Meme.HERO, Rect2(c + Vector2(-107.75, -120) * k, Vector2(187.5, 250) * k))
	mascot(ci, c + Vector2(96, 84) * k, 92.0 * k)

## 阿焰半身。原点在胸口，头顶朝上（尺寸和原来的画法对齐，整张约 164*s/100 高）。
static func bust(ci: CanvasItem, c: Vector2, s: float) -> void:
	var k := s / 100.0
	Meme.draw_portrait(ci, Meme.HERO, Rect2(c + Vector2(-61.5, -106) * k, Vector2(123, 164) * k))

static func speech(ci: CanvasItem, r: Rect2, point_left: bool, _seed: int = 8) -> void:
	Sprites.draw(ci, "speech_body", r)
	var base := Vector2(r.position.x + 12.0 if point_left else r.end.x - 12.0, r.position.y + r.size.y * 0.56)
	Sprites.at(ci, "speech_tail_l" if point_left else "speech_tail_r", base)

# ---------------------------------------------------------------- 岩画卡牌

const ALBUM_COL := [Color("c98a55"), Color("b8a27a"), Color("6b4a3a"), Color("a07858"), Color("c4a06a"), Color("8a9a8a"),
	Color("b9894a"), Color("8f8478"), Color("a86a4a"), Color("7f9a7a"), Color("94705a"), Color("5f6a8a")]

## 底色和斑点是平涂圆，直接画；岩画图案贴白色图、按墨色染
static func card_art(ci: CanvasItem, album: int, idx: int, r: Rect2, clip: PackedVector2Array = PackedVector2Array()) -> void:
	var illustration := CardArtwork.texture(album, idx)
	if illustration != null:
		TextureCache.hold(ci, illustration)
		if clip.is_empty(): ci.draw_texture_rect(illustration, r, false)
		else: _card_texture(ci, illustration, r, clip)
		return
	var bg: Color = ALBUM_COL[album % ALBUM_COL.size()]
	if clip.is_empty(): ci.draw_rect(r, bg)
	else: ci.draw_colored_polygon(clip, bg)
	var speckles := r if clip.is_empty() else r.grow(-minf(32.0, r.size.x * 0.22))
	for i in 30:
		var p := speckles.position + Vector2(Art.srnd(album * 100 + idx * 10 + i) * speckles.size.x, Art.srnd(album * 77 + idx * 13 + i * 3) * speckles.size.y)
		ci.draw_circle(p, 2.0 + Art.srnd(i + idx) * 10.0, Color(bg.darkened(0.2), 0.35))
	var ink := Color("7a2412") if album != 2 else Color("f2c96a")
	var c := r.get_center()
	var s := r.size.x / 100.0
	ci.draw_set_transform(c, 0.0, Vector2.ONE * s)
	var motif := (album * 3 + idx) % 6
	var k := 1.0 / PS.K_ROCK
	match motif:
		0:
			_mammoth(ci, Vector2(-4, 6), 1.0, ink, idx)
		1:
			_deer(ci, Vector2(-6, 6), 1.0, ink, idx)
			_hunter(ci, Vector2(30, 10), 0.8, ink, idx)
		2:
			for i in 3:
				_hunter(ci, Vector2(-30 + i * 30, 8 + (i % 2) * 6), 0.9, ink, idx + i)
		3:
			for i in 4:
				_hand(ci, Vector2(-26 + (i % 2) * 52, -16 + (i / 2) * 36), 0.8, ink if i % 2 == 0 else Color(ink, 0.6), idx + i)
		4:
			ci.draw_circle(Vector2(0, -6), 16, ink)
			Sprites.at(ci, "paint_rock_rays", Vector2(0, -6), k, 0.0, ink)
			_fish_glyph(ci, Vector2(0, 32), ink, idx)
		_:
			Sprites.at(ci, "paint_rock_flame", Vector2.ZERO, k, 0.0, ink)
			for i in 2:
				_hunter(ci, Vector2(-30 + i * 60, 10), 0.85, ink, idx + i)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _card_texture(ci: CanvasItem, texture: Texture2D, r: Rect2, clip: PackedVector2Array) -> void:
	var uv := PackedVector2Array()
	for point in clip: uv.append((point - r.position) / r.size)
	ci.draw_polygon(clip, PackedColorArray([Color.WHITE]), uv, texture)

static func _mammoth(ci: CanvasItem, c: Vector2, s: float, col: Color, _seed: int) -> void:
	Sprites.at(ci, "paint_rock_mammoth", c, s / PS.K_ROCK, 0.0, col)
	Sprites.at(ci, "paint_rock_mammoth_tusk", c, s / PS.K_ROCK)

static func _deer(ci: CanvasItem, c: Vector2, s: float, col: Color, _seed: int) -> void:
	Sprites.at(ci, "paint_rock_deer", c, s / PS.K_ROCK, 0.0, col)

static func _hunter(ci: CanvasItem, c: Vector2, s: float, col: Color, _seed: int) -> void:
	Sprites.at(ci, "paint_rock_hunter", c, s / PS.K_ROCK, 0.0, col)

static func _hand(ci: CanvasItem, c: Vector2, s: float, col: Color, _seed: int) -> void:
	Sprites.at(ci, "paint_rock_hand", c, s / PS.K_ROCK, 0.0, col)

static func _fish_glyph(ci: CanvasItem, c: Vector2, col: Color, _seed: int) -> void:
	Sprites.at(ci, "paint_rock_fish", c, 1.0 / PS.K_ROCK, 0.0, col)

## 卡片：皮框颜色按星级（1★ 素皮 → 5★ 金），顶上星级横幅，下面名牌（名字由调用处写）。
## 画面窗口 = 框内 (12, 12) 到 (宽-12, 高-70)，见 scripts/sprites/album.gd。
static func card(ci: CanvasItem, r: Rect2, album: int, idx: int, owned: bool, _flush: bool = false) -> void:
	var stars := CardPacks.stars(album, idx)
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 6), r.size), 18, 0, 0.0), Color(0, 0, 0, 0.25))
	Sprites.draw(ci, "alb_card_%d" % stars, r)
	var win := card_window(r)
	if owned:
		var side := maxf(win.size.x, win.size.y)
		var sq := Rect2(win.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))
		card_art(ci, album, idx, sq, Art.rrect(win, 10, 0, 0.0))
	else:
		Sprites.draw(ci, "alb_locked", win)
	Sprites.draw(ci, "alb_window", win)
	var rw := 30.0 + float(stars) * 19.0
	var cx := r.get_center().x
	Sprites.draw(ci, "alb_ribbon", Rect2(cx - rw * 0.5, r.position.y - 10, rw, 28))
	for star in stars:
		Sprites.at(ci, "paint_card_star", Vector2(cx + (float(star) - float(stars - 1) * 0.5) * 19.0, r.position.y + 3), 0.62)

static func card_window(r: Rect2) -> Rect2:
	return Rect2(r.position + Vector2(12, 12), Vector2(r.size.x - 24, r.size.y - 82))

## 卡片大图：同星级颜色的粗皮框
static func collection_picture(ci: CanvasItem, r: Rect2, album: int, idx: int) -> void:
	var stars := CardPacks.stars(album, idx)
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 10), r.size).grow(-8), 28, 0, 0.0), Color(0, 0, 0, 0.35))
	card_art(ci, album, idx, r.grow(-14), Art.rrect(r.grow(-14), 22, 0, 0.0))
	Sprites.draw(ci, "alb_pic_%d" % stars, r)

static func collection_cover(ci: CanvasItem, album: int, r: Rect2) -> void:
	var c := r.get_center()
	var radius := minf(r.size.x, r.size.y) * 0.5 - 4.0
	ci.draw_circle(c + Vector2(0, 5), radius + 3, Color(0, 0, 0, 0.3))
	var edge := Art.ell(c, Vector2.ONE * radius, 0, 0.0, 64, 0.0, 0.0)
	ci.draw_colored_polygon(edge, Art.LEATHER)
	var texture := CardArtwork.cover(album)
	if texture != null: _card_texture(ci, texture, r, edge)
	Art.outline(ci, edge, 7, Art.LEATHER)
	Art.outline(ci, Art.ell(c, Vector2.ONE * (radius + 3), 0, 0.0, 64, 0.0, 0.0), 2.0, Art.INK)
	Art.dashed(ci, edge, 7, 5, Art.ROPE, 1.5)

# ---------------------------------------------------------------- 背景与村庄

static func vgrad(ci: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))

## 山脊那截贴白色图（按种子各一张）按 col 染，下面平涂到 bottom
static func hills(ci: CanvasItem, y: float, w: float, amp: float, col: Color, seed: int, bottom: float) -> void:
	if bottom > y:
		ci.draw_rect(Rect2(0, y, w, bottom - y), col)
	if PS.HILL_SEEDS.has(seed) and amp > 0.0:
		Sprites.draw(ci, "paint_hill_%d" % seed, Rect2(0, y - amp * 1.3, w, amp * 1.3), col)

## 树干是一张竖直的图，转到 base→树顶；树冠按种子各一张白图，按 col 染
static func palm(ci: CanvasItem, base: Vector2, h: float, seed: int, col: Color = Color("2f6b3a")) -> void:
	var top := base + Vector2(Art.srnd(seed) * 30.0 - 15.0, -h)
	var d := top - base
	ci.draw_set_transform(base, d.angle() + PI * 0.5, Vector2.ONE)
	Sprites.draw(ci, "paint_palm_trunk", Rect2(-6, -d.length(), 12, d.length()), Color("6a4526"))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var k: int = seed if PS.PALM_SEEDS.has(seed) else posmod(seed, 6)
	Sprites.at(ci, "paint_palm_%d" % k, top, 1.0, 0.0, col)

static func campfire_scene(ci: CanvasItem, c: Vector2, s: float) -> void:
	Sprites.at(ci, "paint_campfire_glow", c + Vector2(0, 30) * s, s)
	# 物品贴图自己设变换，不能套在 draw_set_transform 里
	Art.item(ci, "fire_4", c, 100.0 * s)


## hide = {区域 id: 部件下标}：正在播建造动画的那件先不画
## 部落大地图（TribeArt.WORLD 大小，主页上手指拖动看）。sz 不用了，保留参数给旧调用方。
## 篝火广场在中间，其余地块按建造顺序绕一圈；没开放的地块盖着密林，地图四周也是林子，建一块开一块。
## 整张部落地图一次画完（预览用）。主页拆成三层：地面和后排树（静止）、建筑（跟着沸腾线重绘）、前排树（静止）。
static func village(ci: CanvasItem, _sz: Vector2, builds: Dictionary, level: int = 99, hide: Dictionary = {}) -> void:
	village_ground(ci, builds, level)
	TribeArt.village(ci, builds, level, hide)
	village_front(ci, builds, level)

## 远山：几层山脊，越远越淡、越偏天色
static func far_range(ci: CanvasItem, base_y: float, width: float, amp: float, seed: int, col: Color, bottom: float) -> void:
	var pts := PackedVector2Array()
	var n := 64
	for k in n + 1:
		var x := width * float(k) / float(n)
		var t := x / width
		var y := base_y
		y -= amp * (0.55 + 0.45 * sin(t * 5.1 + float(seed)))
		y -= amp * 0.5 * maxf(0.0, sin(t * 11.3 + float(seed) * 2.3))
		y -= amp * 0.18 * sin(t * 37.0 + float(seed) * 5.1)
		pts.append(Vector2(x, y))
	var ridge := pts.duplicate()
	pts.append(Vector2(width, bottom))
	pts.append(Vector2(0, bottom))
	ci.draw_colored_polygon(pts, col)
	ci.draw_polyline(ridge, col.lightened(0.18), 3.0)

## 地图边上的一排林梢剪影，接住草地和远山
static func treeline(ci: CanvasItem, y: float, width: float, seed: int, col: Color, bottom: float) -> void:
	var x := -30.0
	var i := seed
	var pts := PackedVector2Array([Vector2(-30, bottom)])
	while x < width + 60.0:
		var r := 34.0 + Art.srnd(i) * 26.0
		var top := y - r - Art.srnd(i + 7) * 30.0
		for k in 7:
			var a := PI + PI * float(k) / 6.0
			pts.append(Vector2(x + r + cos(a) * r, top + r + sin(a) * r * 0.9))
		x += r * 1.5
		i += 1
	pts.append(Vector2(width + 60, bottom))
	ci.draw_colored_polygon(pts, col)

## 哪些地块已经开放（开放的或已经开始建的）
static func _opened(builds: Dictionary, level: int) -> Dictionary:
	var opened := {}
	for b in Data.BUILDS:
		var id := str(b.get("id", ""))
		opened[id] = TribeArt.lot_open(id, level) or int(builds.get(id, 0)) > 0
	return opened

## 整张图的树，分前后两排：站在某块开放地块前面（下方）的算前排，画在建筑上面
static func _village_trees(builds: Dictionary, level: int, front: bool) -> Array:
	var W := TribeArt.WORLD
	var hz := TribeArt.WORLD_HORIZON
	var hub := TribeArt.area_at("fire")
	var opened := _opened(builds, level)
	var trees: Array = []
	# 没开放的地块：一丛密林
	for b in Data.BUILDS:
		var id := str(b.get("id", ""))
		if bool(opened[id]): continue
		var c := TribeArt.area_at(id)
		for k in 16:
			var a := Art.srnd(k * 13 + absi(id.hash()) % 97) * TAU
			var d := sqrt(Art.srnd(k * 29 + 5 + absi(id.hash()) % 89)) * TribeArt.LOT_R
			trees.append([c + Vector2(cos(a) * d, sin(a) * d * 0.62 - 10.0), k + absi(id.hash()) % 50])
	# 其余空地都种满树：错开的网格 + 抖动，避开开放的地块、土路和河
	var step := Vector2(92, 74)
	var gi := 0
	var row := 0
	var y0 := hz + 150.0
	while y0 + row * step.y < W.y + 40.0:
		var y := y0 + row * step.y
		var col := 0
		var x0 := -20.0 + (step.x * 0.5 if row % 2 == 1 else 0.0)
		while x0 + col * step.x < 1470.0:
			gi += 1
			var p := Vector2(x0 + col * step.x, y) + Vector2(Art.srnd(gi * 7 + 1) - 0.5, Art.srnd(gi * 7 + 2) - 0.5) * Vector2(52, 40)
			col += 1
			if _clear_ground(p, opened, hub): continue
			trees.append([p, gi + 200])
		row += 1
	var out: Array = []
	for t in trees:
		var p: Vector2 = t[0]
		# 前后排按一条平滑的分界线切：分界线以下全算前排，相邻两棵树不会前后颠倒
		var cut := INF
		for id in opened:
			if not bool(opened[id]): continue
			var c := TribeArt.area_at(str(id))
			cut = minf(cut, c.y + 0.45 * maxf(0.0, absf(p.x - c.x) - TribeArt.LOT_R * 1.2))
		if (p.y > cut) == front: out.append(t)
	out.sort_custom(func(a, c): return float(a[0].y) < float(c[0].y))
	return out

## 前排树：画在建筑上面
static func village_front(ci: CanvasItem, builds: Dictionary, level: int) -> void:
	for t in _village_trees(builds, level, true):
		forest_tree(ci, t[0], int(t[1]))

## 地面层：天空、远山、林梢、草地、河、土路、后排树
static func village_ground(ci: CanvasItem, builds: Dictionary, level: int) -> void:
	var W := TribeArt.WORLD
	var hz := TribeArt.WORLD_HORIZON
	var hub := TribeArt.area_at("fire")
	# 天空、远山
	vgrad(ci, Rect2(0, 0, W.x, hz), Color("8fcfd6"), Color("f8e2ae"))
	ci.draw_circle(Vector2(1180, 170), 70, Color(1, 0.95, 0.7, 0.45))
	ci.draw_circle(Vector2(1180, 170), 46, Color("fff1b8"))
	far_range(ci, hz - 70.0, W.x, 150.0, 1, Color("b7cfc6"), hz + 40.0)
	far_range(ci, hz - 20.0, W.x, 110.0, 4, Color("8fb3a4"), hz + 60.0)
	far_range(ci, hz + 30.0, W.x, 70.0, 9, Color("6c977c"), hz + 90.0)
	# 草地
	vgrad(ci, Rect2(0, hz + 60.0, W.x, W.y - hz - 60.0), Color("9cc35a"), Color("6d9a3c"))
	# 地图边上的林梢
	treeline(ci, hz + 110.0, W.x, 3, Color("3f7a45"), hz + 200.0)
	treeline(ci, hz + 150.0, W.x, 17, Color("2f6b3a"), hz + 220.0)
	# 右边一条河
	var river := PackedVector2Array()
	var rows := 24
	for k in rows + 1:
		var y := hz + 170.0 + float(k) * (W.y - hz - 170.0) / float(rows)
		river.append(Vector2(1480 + sin(float(k) * 0.8) * 22.0, y))
	for k in rows + 1:
		var j := rows - k
		var y := hz + 170.0 + float(j) * (W.y - hz - 170.0) / float(rows)
		river.append(Vector2(1545 + sin(float(j) * 0.8) * 22.0, y))
	ci.draw_colored_polygon(river, Color("5fb4c8"))
	# 草地上的浅色斑块，打破大片平涂
	for i in 46:
		var p := Vector2(60 + Art.srnd(i * 7 + 1) * 1380.0, hz + 180.0 + Art.srnd(i * 7 + 2) * (W.y - hz - 220.0))
		ci.draw_colored_polygon(Art.ell(p, Vector2(60, 22) * (0.6 + Art.srnd(i * 7 + 3)), i, 0.1, 14), Color(0.75, 0.86, 0.45, 0.35))
	# 从篝火广场通往各个开放地块的土路
	var opened := _opened(builds, level)
	for b in Data.BUILDS:
		var id := str(b.get("id", ""))
		if id == "fire" or not bool(opened[id]): continue
		_dirt_path(ci, hub, TribeArt.area_at(id), absi(id.hash()) % 7)
	# 后排树（没开放的地块盖着的密林、空地上的树）
	for t in _village_trees(builds, level, false):
		forest_tree(ci, t[0], int(t[1]))

## 这一点要留空：开放地块的空地、通往它们的土路
static func _clear_ground(p: Vector2, opened: Dictionary, hub: Vector2) -> bool:
	for id in opened:
		if not bool(opened[id]): continue
		var c := TribeArt.area_at(str(id))
		# 按树干上方一点算（树冠往上长）：下边的树冠不压住空地，上边的树贴到空地边上
		var q := (p + Vector2(0, -30) - c - Vector2(0, 10)) / Vector2(TribeArt.LOT_R * 1.2, TribeArt.LOT_R * 0.74)
		if q.length() < 1.0: return true
		if str(id) != "fire" and Geometry2D.get_closest_point_to_segment(p, hub, c).distance_to(p) < 78.0: return true
	return false

## 一棵林子里的树：树干 + 两三层深浅不一的树冠
static func forest_tree(ci: CanvasItem, base: Vector2, seed: int) -> void:
	var s := 0.8 + Art.srnd(seed * 3 + 1) * 0.5
	ci.draw_colored_polygon(Art.ell(base + Vector2(0, 4), Vector2(34, 10) * s, seed, 0.05, 14), Color(0.2, 0.3, 0.12, 0.35))
	ci.draw_rect(Rect2(base + Vector2(-5, -40) * s, Vector2(10, 42) * s), Color("6a4526"))
	var greens := [Color("2f6b3a"), Color("3d7f40"), Color("4f9447")]
	for k in 3:
		var c := base + Vector2((Art.srnd(seed * 5 + k) - 0.5) * 26.0, -58.0 - float(k) * 16.0) * s
		ci.draw_colored_polygon(Art.ell(c, Vector2(44 - k * 9, 34 - k * 7) * s, seed + k, 0.12, 16), greens[k])
	ci.draw_circle(base + Vector2(-10, -98) * s, 7.0 * s, Color(1, 1, 1, 0.12))

## 从 a 到 b 的一条弯弯的土路
static func _dirt_path(ci: CanvasItem, a: Vector2, b: Vector2, seed: int) -> void:
	var n := 14
	var side := (b - a).normalized().orthogonal()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for k in n + 1:
		var t := float(k) / float(n)
		var p := a.lerp(b, t) + side * sin(t * PI) * (20.0 + float(seed) * 4.0)
		var w := 22.0 - 6.0 * t
		left.append(p + side * w)
		right.append(p - side * w)
	right.reverse()
	left.append_array(right)
	ci.draw_colored_polygon(left, Color("d9b778"))

static func _spot_hut(ci: CanvasItem, c: Vector2, st: int) -> void:
	if st == 0:
		return
	var s := 0.9 + 0.08 * float(st)
	var key := "paint_spot_hut_5" if st >= 5 else ("paint_spot_hut_3" if st >= 3 else "paint_spot_hut_1")
	Sprites.at(ci, key, c, s / PS.K_SPOT)

## 格子上的奖励气泡。id 为空时画一枚淡淡的空泡，给编辑器点选。
static func reward_bubble(ci: CanvasItem, c: Vector2, rad: float, id: String, n: int, _seed: int, lift: float = 0.0) -> void:
	c += Vector2(0, lift)
	id = Rewards.before_cards(id)
	Sprites.at(ci, "paint_bubble_empty" if id == "" else "paint_bubble", c, rad / PS.R_BUBBLE)
	if id == "":
		return
	_bubble_content(ci, c, rad, id, n)

## 泡里的物品和数量
static func _bubble_content(ci: CanvasItem, c: Vector2, rad: float, id: String, n: int) -> void:
	var icon_y := -rad * 0.08 if n > 1 else 0.0
	Art.item(ci, id, c + Vector2(0, icon_y), rad * 1.45, false)
	if n <= 1 or G.font_title == null:
		return
	var f: Font = G.font_title
	var fs := int(clampf(round(rad * 0.58), 11.0, 20.0))
	var text := str(n)
	var tw := f.get_string_size(TextCatalog.resolve(text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := c + Vector2(-tw * 0.5, rad * 0.62)
	ci.draw_string_outline(f, pos, TextCatalog.resolve(text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(3, int(fs / 5.0)), Art.INK)
	ci.draw_string(f, pos, TextCatalog.resolve(text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
