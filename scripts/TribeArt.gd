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

## 主页上部件的缩放
const VS := 0.8
## 区域在主页上的中心；parts 是每件部件相对中心的落地点（按 builds.json 里的部件顺序）；tag 是区域牌子的位置。
## 高的部件尽量放在后排两角，给牌子让出中间。
const AREAS := {
	"fire": {"at": Vector2(360, 872), "tag": Vector2(0, 100), "parts": [
		Vector2(0, 6), Vector2(-104, 34), Vector2(98, 40), Vector2(-118, -34), Vector2(96, -54), Vector2(-14, -66)]},
	"gather": {"at": Vector2(360, 600), "tag": Vector2(0, -124), "parts": [
		Vector2(0, -46), Vector2(-66, -24), Vector2(-46, 40), Vector2(62, -22), Vector2(6, 8), Vector2(88, 36)]},
	"stone": {"at": Vector2(124, 600), "tag": Vector2(0, -124), "parts": [
		Vector2(-50, 38), Vector2(44, 40), Vector2(0, -44), Vector2(-62, -22), Vector2(2, 6), Vector2(64, -22)]},
	"weave": {"at": Vector2(596, 600), "tag": Vector2(0, -124), "parts": [
		Vector2(0, -44), Vector2(-64, -24), Vector2(-46, 40), Vector2(4, 6), Vector2(48, 42), Vector2(90, -8)]},
	"hunt": {"at": Vector2(124, 884), "tag": Vector2(0, -124), "parts": [
		Vector2(-92, 14), Vector2(0, -46), Vector2(-44, 44), Vector2(4, 4), Vector2(62, -22), Vector2(56, 46)]},
	"cook": {"at": Vector2(596, 884), "tag": Vector2(0, -124), "parts": [
		Vector2(0, -44), Vector2(-46, 42), Vector2(-62, -18), Vector2(8, 10), Vector2(62, -22), Vector2(52, 44)]},
	"wood": {"at": Vector2(124, 1176), "tag": Vector2(0, -124), "parts": [
		Vector2(-48, 40), Vector2(0, -44), Vector2(6, 8), Vector2(62, -22), Vector2(-62, -18), Vector2(70, 42)]},
	"kiln": {"at": Vector2(596, 1176), "tag": Vector2(0, -124), "parts": [
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

## 部件图的内容框（生成时的像素，相对落地点）
static func part_box(kind: String, bs: float) -> Rect2:
	var b: Array = BOUNDS.get(kind, BOUNDS["rubble"])
	var tl := Vector2(floorf((b[0] - 3) * bs), floorf((b[1] - 3) * bs))
	var br := Vector2(ceilf((b[2] + 3) * bs), ceilf((b[3] + 3) * bs))
	return Rect2(tl, br - tl)

## 弹窗卡片里的图标：自动缩放到 box 里，落地点在底部偏上
static func icon(ci: CanvasItem, kind: String, r: Rect2, dim := false) -> void:
	var h := float(_HEIGHT.get(kind, 80))
	var w := float(_WIDTH.get(kind, 100))
	var s := minf(r.size.y * 0.8 / h, r.size.x * 0.86 / w)
	s = minf(s, 1.5)
	var c := Vector2(r.get_center().x, r.end.y - r.size.y * 0.1)
	if dim:
		part(ci, kind, c, s, Vector2.ONE, "_flat", Color("8f7a5e"))
	else:
		part(ci, kind, c, s, Vector2.ONE, "_icon")

## 区域地块图的 key（新区域没有专属图时用通用的）
static func plot_key(id: String, open: bool) -> String:
	var k := "tribe_plot_%s_%s" % [id if AREAS.has(id) else "any", "open" if open else "lock"]
	return k

## 整个村庄的部件层。hide = {区域 id: 部件下标}：这件正在播建造动画，先不画。
static func village(ci: CanvasItem, builds: Dictionary, level: int, hide: Dictionary = {}) -> void:
	for b in Data.BUILDS:
		if b is not Dictionary:
			continue
		var id := str(b.get("id", ""))
		var parts := Data.build_parts(b)
		var st := clampi(int(builds.get(id, 0)), 0, parts.size())
		var open := level >= Data.build_unlock(b)
		var at := area_at(id)
		Sprites.draw(ci, plot_key(id, open), Rect2(at + PLOT_BOX.position, PLOT_BOX.size))
		var order: Array = []
		for k in st:
			if hide.has(id) and int(hide[id]) == k:
				continue
			order.append(k)
		order.sort_custom(func(a, c): return part_at(id, a).y < part_at(id, c).y)
		# 下一件的地基：虚线圈 + 木桩
		if open and st < parts.size() and not (hide.has(id) and int(hide[id]) == st):
			var gp := part_at(id, st)
			Sprites.draw(ci, "tribe_found_%d" % (st % FOUND_N), Rect2(gp + FOUND_BOX.position, FOUND_BOX.size))
		for k in order:
			var pid := str(parts[k].get("id", "")) if parts[k] is Dictionary else ""
			part(ci, pid, part_at(id, k), VS)

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
	"rubble": [-41, -43, 38, 12],
}
