class_name TribeArt
extends RefCounted
## 部落主页的建筑部件。画法在 scripts/sprites/tribe.gd（生成图片用），运行时只贴预生成的图（tribe_{部件 id}）。
## 每件部件以「落地中点」为原点，向上是负 y，1 个单位约等于主页上 1 像素。
## 部件 id 写在 data/builds.json；没有画法的新 id 贴碎石堆（tribe_rubble）。

const DIRT := Color("8a5a32")
const HAY := Color("e2b950")
const FLINT := Color("4c5260")
const OBSID := Color("3b3050")
const CLAYW := Color("b65a38")
const SMOKE := Color(0.96, 0.94, 0.9, 0.6)
const PLUM := Color("7d3c8c")

## 部落大地图（主页上手指拖动看）的尺寸：比屏幕宽一倍多、高一半多。地平线在 WORLD_HORIZON。
const WORLD := Vector2(1600, 2300)
const WORLD_HORIZON := 430.0
## 地块半径：未开放的地块盖一片密林，开放后露出一块空地
const LOT_R := 170.0

## 主页上部件的缩放
const VS := 0.8
## 区域在部落大地图上的中心（篝火广场居中，其余按建造顺序绕一圈）；parts 是每件部件相对中心的落地点（按 builds.json 里的部件顺序）；tag 是区域牌子的位置。
## 高的部件尽量放在后排两角，给牌子让出中间。
const AREAS := {
	"fire": {"at": Vector2(800, 1290), "tag": Vector2(0, 100), "parts": [
		Vector2(0, 6), Vector2(-104, 34), Vector2(98, 40), Vector2(-118, -34), Vector2(96, -54), Vector2(-14, -66), Vector2(-132, 92), Vector2(134, 92)]},
	"gather": {"at": Vector2(800, 930), "tag": Vector2(0, -124), "parts": [
		Vector2(0, -46), Vector2(-66, -24), Vector2(-46, 40), Vector2(62, -22), Vector2(6, 8), Vector2(88, 36)]},
	"stone": {"at": Vector2(500, 1110), "tag": Vector2(0, -124), "parts": [
		Vector2(-50, 38), Vector2(44, 40), Vector2(0, -44), Vector2(-62, -22), Vector2(2, 6), Vector2(64, -22)]},
	"weave": {"at": Vector2(1100, 1110), "tag": Vector2(0, -124), "parts": [
		Vector2(0, -44), Vector2(-64, -24), Vector2(-46, 40), Vector2(4, 6), Vector2(48, 42), Vector2(90, -8)]},
	"hunt": {"at": Vector2(470, 1460), "tag": Vector2(0, -124), "parts": [
		Vector2(-92, 14), Vector2(0, -46), Vector2(-44, 44), Vector2(4, 4), Vector2(62, -22), Vector2(56, 46)]},
	"wood": {"at": Vector2(590, 1790), "tag": Vector2(0, -124), "parts": [
		Vector2(-48, 40), Vector2(0, -44), Vector2(6, 8), Vector2(62, -22), Vector2(-62, -18), Vector2(70, 42)]},
	"fishing": {"at": Vector2(1190, 1450), "tag": Vector2(0, -124), "parts": [
		Vector2(-84, -30), Vector2(-76, 54), Vector2(-6, 8), Vector2(0, -58), Vector2(62, 54), Vector2(84, -34)]},
	"kiln": {"at": Vector2(1010, 1790), "tag": Vector2(0, -124), "parts": [
		Vector2(-46, 40), Vector2(0, -44), Vector2(-62, -22), Vector2(8, 8), Vector2(62, -20), Vector2(54, 44)]},
}

## 部件图的三种画法和生成时的缩放：村庄里（VS、不带白边）、弹窗图标（1.5 倍、带贴纸白边）、单色剪影（白色，贴图时染色）
const VAR_SCALE := {"": 0.8, "_icon": 1.5, "_flat": 1.5}

# ---------------------------------------------------------------- 对外

static func area_at(id: String) -> Vector2:
	if AREAS.has(id):
		return AREAS[id]["at"]
	var k := absi(id.hash()) % 5
	return Vector2(140 + k * 110, 1100)

static func tag_at(id: String) -> Vector2:
	if AREAS.has(id):
		return area_at(id) + (AREAS[id]["tag"] as Vector2)
	return area_at(id) + Vector2(0, -120)

## 第 idx 件部件在主页上的落地点
static func part_at(id: String, idx: int) -> Vector2:
	var base := area_at(id)
	if AREAS.has(id):
		var arr: Array = AREAS[id]["parts"]
		if idx >= 0 and idx < arr.size():
			return base + (arr[idx] as Vector2)
	var a := float(idx) * 2.4
	return base + Vector2(cos(a) * 70.0, sin(a) * 34.0)

## 在 c 处画一件部件。squash 是建造动画里的挤压拉伸（以落地点为轴）。
## variant 选图：""（村庄）、"_icon"（带白边）、"_flat"（白色剪影，用 mod 染色）
static func part(ci: CanvasItem, kind: String, c: Vector2, s: float = 1.0, squash: Vector2 = Vector2.ONE, variant: String = "", mod: Color = Color.WHITE) -> void:
	var k := kind if has_art(kind) else "rubble"
	var bs: float = VAR_SCALE.get(variant, 1.0)
	ci.draw_set_transform(c, 0.0, squash * (s / bs))
	Sprites.draw(ci, "tribe_" + k + variant, part_box(k, bs), mod)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 每件部件画了几个建造阶段（scripts/sprites/tribe.gd 里按 _on(阶段) 分层画）。没写的只有 1 个阶段。
## 跟 builds.json 的 steps 对不上也能用：按已建比例换算成最近的阶段。
const STAGES := {
	"totem": 3, "chiefhut": 3, "spears": 3, "featherpole": 4,
	"berrybush": 3, "basketrack": 3, "dryingmat": 3, "seedjar": 3, "sprouts": 4, "fruittree": 4,
	"logs": 3, "chopblock": 3, "bench": 3, "sawhorse": 3, "woodshed": 4, "carvedpole": 4,
	"rockpile": 3, "anvilstone": 3, "flintpit": 3, "toolrack": 3, "whetstone": 4, "obsidian": 4,
	"snare": 3, "meatrack": 3, "hidedry": 3, "hunttent": 4, "skullgate": 4,
	"grassstack": 3, "loomframe": 3, "dyepot": 3, "clothesline": 3, "hidetent": 4,
	"stonestove": 3, "spit": 3, "smokehouse": 3, "cookpit": 3, "firewood": 4, "sacredfire": 4,
	"claypit": 3, "wheel": 3, "potshelf": 3, "firepit": 3, "kilndome": 4, "bigjar": 4,
	"netrack": 3, "fishrack": 3, "fishtrap": 3, "shellpile": 3, "canoe": 4, "stilthut": 4,
}

static func stages_of(kind: String) -> int:
	return int(STAGES.get(kind, 1))

## 已建比例 frac 对应画到第几个阶段（0 = 还没动工）
static func stage_at(kind: String, frac: float) -> int:
	var n := stages_of(kind)
	if frac >= 0.999:
		return n
	if frac <= 0.001:
		return 0
	return clampi(roundi(frac * float(n)), 1, n - 1)

static func stage_key(kind: String, st: int, variant := "") -> String:
	return "tribe_%s_s%d%s" % [kind, st, variant]

## 第 st 阶段新加的零件（只在村庄画法里有，落成动画用）
static func delta_key(kind: String, st: int) -> String:
	return "tribe_%s_d%d" % [kind, st]

## 画第 st 阶段新加的那几件零件；只有 1 个阶段的部件就是整件
static func part_delta(ci: CanvasItem, kind: String, st: int, c: Vector2, s: float, squash: Vector2 = Vector2.ONE, mod: Color = Color.WHITE) -> void:
	if stages_of(kind) <= 1 or not Sprites.has(delta_key(kind, st)):
		part(ci, kind, c, s, squash, "", mod)
		return
	var bs: float = VAR_SCALE[""]
	ci.draw_set_transform(c, 0.0, squash * (s / bs))
	Sprites.draw(ci, delta_key(kind, st), part_box(kind, bs), mod)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 建到一半的部件：frac（0..1）是已建比例。每个阶段有自己画好的样子（先打底、再起墙、再封顶、最后装饰），
## 后面没建的部分留一层淡淡的轮廓提示。没有阶段图的老部件退回「下半截真图 + 木脚手架」。
static func part_stage(ci: CanvasItem, kind: String, c: Vector2, s: float, frac: float, variant: String = "", squash: Vector2 = Vector2.ONE) -> void:
	if frac >= 0.999:
		part(ci, kind, c, s, squash, variant)
		return
	var k := kind if has_art(kind) else "rubble"
	frac = clampf(frac, 0.0, 1.0)
	var st := stage_at(k, frac)
	if st == 0:
		# 还没动工：只有轮廓
		part(ci, k, c, s, squash, "_flat", Color(0.42, 0.3, 0.18, 0.22))
		return
	if Sprites.has(stage_key(k, st, variant)):
		part(ci, k, c, s, squash, "_flat", Color(0.42, 0.3, 0.18, 0.16))
		var vbs: float = VAR_SCALE.get(variant, 1.0)
		ci.draw_set_transform(c, 0.0, squash * (s / vbs))
		Sprites.draw(ci, stage_key(k, st, variant), part_box(k, vbs))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# 还没建的部分：淡色轮廓
	part(ci, k, c, s, squash, "_flat", Color(0.42, 0.3, 0.18, 0.22))
	var bs: float = VAR_SCALE.get(variant, 1.0)
	var box := part_box(k, bs)
	ci.draw_set_transform(c, 0.0, squash * (s / bs))
	# 已建的部分：内容框下面 frac 这一截（底部留一点地面，至少露出一截）
	var keep := 0.12 + 0.88 * frac
	Sprites.draw_bottom(ci, "tribe_" + k + variant, box, keep)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_scaffold(ci, c, s, k, keep)

## 木脚手架：两根立柱 + 已建高度处一根横梁 + 斜撑，用部件的实际宽高定位。
static func _scaffold(ci: CanvasItem, c: Vector2, s: float, kind: String, keep: float) -> void:
	var h := float(_HEIGHT.get(kind, 80)) * s
	var w := float(_WIDTH.get(kind, 100)) * s
	var lw := maxf(2.0, 4.0 * s)
	var x0 := c.x - w * 0.46
	var x1 := c.x + w * 0.46
	var top := c.y - h * 1.04
	var beam := c.y - h * keep
	var wood := Color("b97a3f")
	var ink := Color("3a2414")
	var lines := [
		[Vector2(x0, c.y + 2 * s), Vector2(x0 - 3 * s, top)],
		[Vector2(x1, c.y + 2 * s), Vector2(x1 + 3 * s, top)],
		[Vector2(x0 - 8 * s, beam), Vector2(x1 + 8 * s, beam)],
		[Vector2(x0, c.y - 2 * s), Vector2(lerpf(x0, x1, 0.45), beam)],
	]
	for seg in lines:
		ci.draw_line(seg[0], seg[1], ink, lw + 3.0 * maxf(s, 0.6), true)
	for seg in lines:
		ci.draw_line(seg[0], seg[1], wood, lw, true)
	# 绑绳
	for x in [x0, x1]:
		ci.draw_circle(Vector2(x, beam), lw * 0.9, Color("e2b950"))

## 部件图的内容框（生成时的像素，相对落地点）
static func part_box(kind: String, bs: float) -> Rect2:
	var b: Array = BOUNDS.get(kind, BOUNDS["rubble"])
	var tl := Vector2(floorf((b[0] - 3) * bs), floorf((b[1] - 3) * bs))
	var br := Vector2(ceilf((b[2] + 3) * bs), ceilf((b[3] + 3) * bs))
	return Rect2(tl, br - tl)

## 弹窗卡片里的图标：自动缩放到 box 里，落地点在底部偏上
## frac < 1 时画建到一半的样子（见 part_stage）
static func icon(ci: CanvasItem, kind: String, r: Rect2, dim := false, frac := 1.0, max_s := 1.5) -> void:
	var h := float(_HEIGHT.get(kind, 80))
	var w := float(_WIDTH.get(kind, 100))
	var s := minf(r.size.y * 0.8 / h, r.size.x * 0.86 / w)
	s = minf(s, max_s)
	var c := Vector2(r.get_center().x, r.end.y - r.size.y * 0.1)
	if dim:
		part(ci, kind, c, s, Vector2.ONE, "_flat", Color("8f7a5e"))
	elif frac < 0.999:
		part_stage(ci, kind, c, s, frac, "_icon")
	else:
		part(ci, kind, c, s, Vector2.ONE, "_icon")

## 区域地块图的 key（新区域没有专属图时用通用的）
static func plot_key(id: String, open: bool) -> String:
	var k := "tribe_plot_%s_%s" % [id if AREAS.has(id) else "any", "open" if open else "lock"]
	return k

## 整个村庄的部件层。hide = {区域 id: 部件下标}：这件正在播建造动画，先不画。
## 开放的地块露出一块空地；没开放的地块由 Paint.village 盖密林，这里不画。
static func village(ci: CanvasItem, builds: Dictionary, level: int, hide: Dictionary = {}) -> void:
	for b in Data.BUILDS:
		if b is not Dictionary:
			continue
		var id := str(b.get("id", ""))
		var parts := Data.build_parts(b)
		var st := clampi(int(builds.get(id, 0)), 0, parts.size())
		var open := lot_open(id, level)
		if not open and st == 0:
			continue
		# 空地和土路画在静止的地面层（Paint.village_ground）
		var order: Array = []
		for k in st:
			if hide.has(id) and int(hide[id]) == k:
				continue
			order.append(k)
		# 正在建的部件（当前这件和提前开工的下一件）按进度画半成品；当前这件还没动工就画地基
		var staged: Array = []
		if open and st < parts.size() and not (hide.has(id) and int(hide[id]) == st):
			if _steps_of(builds, "_steps", id) > 0: staged.append(st)
			else:
				var gp := part_at(id, st)
				Sprites.draw(ci, "tribe_found_%d" % (st % FOUND_N), Rect2(gp + FOUND_BOX.position, FOUND_BOX.size))
		if open and st + 1 < parts.size() and _steps_of(builds, "_ahead", id) > 0 and not (hide.has(id) and int(hide[id]) == st + 1):
			staged.append(st + 1)
		order.append_array(staged)
		order.sort_custom(func(a, c): return part_at(id, a).y < part_at(id, c).y)
		for k in order:
			var pid := str(parts[k].get("id", "")) if parts[k] is Dictionary else ""
			if k < st:
				part(ci, pid, part_at(id, k), VS)
			else:
				var done := _steps_of(builds, "_steps" if k == st else "_ahead", id)
				part_stage(ci, pid, part_at(id, k), VS, float(done) / float(Data.part_steps(parts[k])))

static func _steps_of(builds: Dictionary, key: String, id: String) -> int:
	var d = builds.get(key, {})
	return int(d.get(id, 0)) if d is Dictionary else 0

## 地块能不能建（游戏里看建造规则：产线开放且前一块建完；没有游戏状态时只看等级）
static func lot_open(id: String, level: int) -> bool:
	if Engine.get_main_loop() is SceneTree and (Engine.get_main_loop() as SceneTree).root.has_node("G"):
		var g = (Engine.get_main_loop() as SceneTree).root.get_node("G")
		if g.rules != null: return g.rules.progression.build_open(id)
	return level >= Data.build_unlock(Data.build_def(id))

## 开出来的空地：一片压实的土地，边上一圈浅草
static func clearing(ci: CanvasItem, at: Vector2, id: String) -> void:
	var r := Vector2(LOT_R * 1.05, LOT_R * 0.62)
	ci.draw_colored_polygon(Art.ell(at + Vector2(0, 10), r * 1.08, 3, 0.0, 40, 0.0, 0.0), Color("8fb453"))
	ci.draw_colored_polygon(Art.ell(at + Vector2(0, 10), r, 3, 0.0, 40, 0.0, 0.0), Color("c9a464") if id == "fire" else Color("b9a062"))
	ci.draw_colored_polygon(Art.ell(at + Vector2(0, 4), r * 0.8, 3, 0.0, 40, 0.0, 0.0), Color("d3b273") if id == "fire" else Color("c4ab6c"))

## 地块图、地基图相对区域中心 / 落地点的内容框
const PLOT_BOX := Rect2(-128, -74, 256, 168)
const FOUND_BOX := Rect2(-36, -20, 72, 40)
const FOUND_N := 6

## 部件名字 → 画法里能认的 id（新 id 没有画法时用碎石堆）
static func has_art(kind: String) -> bool:
	return _HEIGHT.has(kind)

# ---------------------------------------------------------------- 尺寸（给弹窗图标缩放用）

const _HEIGHT := {
	"campfire": 86, "logpile": 56, "stumps": 40, "drum": 70, "totem": 150, "chiefhut": 130,
	"berrybush": 62, "basketrack": 80, "dryingmat": 34, "seedjar": 60, "sprouts": 40, "fruittree": 150,
	"rockpile": 46, "anvilstone": 48, "flintpit": 44, "toolrack": 86, "whetstone": 56, "obsidian": 86,
	"grassstack": 70, "loomframe": 96, "dyepot": 64, "clothesline": 92, "hidetent": 118, "featherpole": 140,
	"spears": 106, "snare": 74, "meatrack": 96, "hidedry": 92, "hunttent": 96, "skullgate": 120,
	"stonestove": 58, "spit": 76, "smokehouse": 112, "cookpit": 40, "firewood": 62, "sacredfire": 130,
	"logs": 58, "chopblock": 66, "bench": 40, "sawhorse": 56, "woodshed": 110, "carvedpole": 150,
	"claypit": 34, "wheel": 64, "potshelf": 92, "firepit": 56, "kilndome": 104, "bigjar": 92,
	"netrack": 92, "fishrack": 80, "fishtrap": 50, "shellpile": 40, "canoe": 44, "stilthut": 136,
	"rubble": 40,
}
const _WIDTH := {
	"campfire": 104, "logpile": 100, "stumps": 104, "drum": 70, "totem": 96, "chiefhut": 170,
	"berrybush": 80, "basketrack": 86, "dryingmat": 104, "seedjar": 74, "sprouts": 96, "fruittree": 120,
	"rockpile": 84, "anvilstone": 82, "flintpit": 92, "toolrack": 82, "whetstone": 92, "obsidian": 80,
	"grassstack": 84, "loomframe": 84, "dyepot": 76, "clothesline": 120, "hidetent": 110, "featherpole": 70,
	"spears": 76, "snare": 80, "meatrack": 104, "hidedry": 86, "hunttent": 116, "skullgate": 120,
	"stonestove": 88, "spit": 104, "smokehouse": 96, "cookpit": 100, "firewood": 92, "sacredfire": 86,
	"logs": 100, "chopblock": 84, "bench": 104, "sawhorse": 90, "woodshed": 124, "carvedpole": 90,
	"claypit": 100, "wheel": 76, "potshelf": 100, "firepit": 100, "kilndome": 110, "bigjar": 80,
	"netrack": 104, "fishrack": 112, "fishtrap": 100, "shellpile": 92, "canoe": 136, "stilthut": 116,
	"rubble": 70,
}

## 每件部件实际画出来的外框（1 倍、带白边、4 帧并集；tools/measure_tribe.gd 量出来的）：[左, 上, 右, 下]
const BOUNDS := {

	"campfire": [-63, -73, 63, 26],
	"logpile": [-53, -63, 57, 14],
	"stumps": [-56, -35, 55, 17],
	"drum": [-39, -85, 51, 10],
	"totem": [-57, -155, 57, 11],
	"chiefhut": [-95, -144, 95, 18],
	"berrybush": [-51, -72, 50, 12],
	"basketrack": [-48, -86, 48, 12],
	"dryingmat": [-59, -31, 59, 12],
	"seedjar": [-41, -65, 44, 12],
	"sprouts": [-57, -35, 56, 12],
	"fruittree": [-71, -162, 71, 16],
	"rockpile": [-54, -52, 49, 13],
	"anvilstone": [-49, -59, 51, 13],
	"flintpit": [-53, -53, 65, 18],
	"toolrack": [-46, -107, 46, 12],
	"whetstone": [-55, -57, 57, 13],
	"obsidian": [-54, -97, 55, 12],
	"grassstack": [-51, -84, 51, 13],
	"loomframe": [-50, -104, 50, 12],
	"dyepot": [-41, -95, 41, 11],
	"clothesline": [-64, -96, 64, 12],
	"hidetent": [-61, -129, 61, 16],
	"featherpole": [-39, -155, 39, 12],
	"spears": [-48, -113, 48, 11],
	"snare": [-42, -78, 47, 12],
	"meatrack": [-58, -100, 58, 14],
	"hidedry": [-50, -98, 50, 12],
	"hunttent": [-65, -104, 66, 16],
	"skullgate": [-61, -131, 61, 14],
	"stonestove": [-56, -45, 56, 22],
	"spit": [-61, -124, 61, 14],
	"smokehouse": [-59, -144, 59, 14],
	"cookpit": [-57, -75, 57, 14],
	"firewood": [-57, -71, 57, 13],
	"sacredfire": [-49, -138, 49, 14],
	"logs": [-64, -79, 60, 14],
	"chopblock": [-50, -76, 57, 13],
	"bench": [-59, -42, 61, 12],
	"sawhorse": [-55, -66, 55, 12],
	"woodshed": [-73, -104, 73, 16],
	"carvedpole": [-52, -159, 53, 9],
	"claypit": [-57, -44, 58, 16],
	"wheel": [-45, -73, 44, 12],
	"potshelf": [-59, -119, 59, 14],
	"firepit": [-57, -88, 57, 14],
	"kilndome": [-59, -151, 59, 16],
	"bigjar": [-45, -97, 45, 12],
	"netrack": [-56, -100, 56, 14],
	"fishrack": [-64, -90, 64, 14],
	"fishtrap": [-52, -58, 56, 14],
	"shellpile": [-50, -50, 52, 14],
	"canoe": [-74, -66, 74, 16],
	"stilthut": [-64, -146, 64, 16],
	"rubble": [-41, -43, 38, 12],
}
