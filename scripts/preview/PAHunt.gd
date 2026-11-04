class_name PAHunt
extends PA
## 狩猎线：狩猎陷阱 / 走兽（四脚朝天）/ 飞禽

const MOUSE := Color("9a9590")
const FROG := Color("6dbb4a")
const LIZ := Color("8fb04a")
const HARE := Color("c8a27a")
const HEDGE := Color("a07a58")
const FOX := Color("e07a2a")
const BADG := Color("7a7570")
const BOAR := Color("7a5236")
const GOAT := Color("e8dcc4")
const DEER := Color("b8783e")
const WOLF := Color("8e8c94")
const BISON := Color("5e3a22")
const BEAR := Color("6e4428")
const TIGER := Color("e89a3a")
const RHINO := Color("8a6a4a")
const MAMMOTH := Color("7a4e2e")

static func gen(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			sil(ci, [pg([Vector2(-40, 34), Vector2(-44, 28), Vector2(30, -30), Vector2(44, -42), Vector2(36, -26), Vector2(-34, 38)], s, WOOD)], rim)
			ci.draw_colored_polygon(poly([Vector2(30, -30), Vector2(44, -42), Vector2(36, -26)], s), BONE2)
			ci.draw_circle(Vector2(-10, 10), 2.2, WOOD_D)
			ci.draw_circle(Vector2(8, -6), 1.8, WOOD_D)
		2:
			var parts := [leaf(Vector2(20, -20), 18, 6, -0.6, s + 5), leaf(Vector2(-26, 0), 16, 5, -2.6, s + 6)]
			parts.append_array(ring(Vector2(0, 10), 26, 5.0, s, LEAF_D))
			parts.append_array(ring(Vector2(0, 6), 16, 5.0, s + 2, LEAF_D.lightened(0.1)))
			parts.append(stk(Vector2(20, -6), Vector2(36, -30), 3.0, s + 4, LEAF_D, 2))
			sil(ci, parts, rim)
		3:
			var parts := [stk(Vector2(-30, 40), Vector2(-26, -20), 3.4, s, WOOD_D), stk(Vector2(-26, -20), Vector2(30, -40), 2.6, s + 1, WOOD, 2)]
			parts.append(stk(Vector2(30, -40), Vector2(14, 0), 1.6, s + 2, ROPE, 2))
			sil(ci, parts, rim)
			ci.draw_arc(Vector2(14, 16), 16, 0, TAU, 24, INK, 4.5, true)
			ci.draw_arc(Vector2(14, 16), 16, 0, TAU, 24, ROPE, 2.6, true)
			ci.draw_circle(Vector2(14, 0), 3.0, ROPE.darkened(0.2))
		4:
			var parts := [bx(-40, 20, 80, 14, 4, s, WOOD_D)]
			var jaw_l := [Vector2(-34, 22), Vector2(-34, -6)]
			var jaw_r := [Vector2(34, 22), Vector2(34, -6)]
			for k in 5:
				jaw_l.append(Vector2(-30.0 + float(k) * 6.0, -6.0 - (6.0 if k % 2 == 0 else 0.0)))
				jaw_r.append(Vector2(30.0 - float(k) * 6.0, -6.0 - (6.0 if k % 2 == 0 else 0.0)))
			jaw_l.append(Vector2(-4, 22))
			jaw_r.append(Vector2(4, 22))
			parts.append(pg(jaw_l, s + 1, WOOD))
			parts.append(pg(jaw_r, s + 2, WOOD.darkened(0.06)))
			sil(ci, parts, rim)
			rope(ci, Vector2(-36, 26), Vector2(36, 26), 0.5, 2, 6.0, s)
		5:
			var parts := [ov(Vector2(0, 34), 40, 6, s, Color("7a4f2a"), 0.0, 1), stk(Vector2(-10, 32), Vector2(-2, -4), 2.6, s + 1, WOOD, 2),
				stk(Vector2(-14, 10), Vector2(10, 10), 2.4, s + 2, WOOD, 2),
				pg([Vector2(-44, -2), Vector2(36, -26), Vector2(44, -14), Vector2(-36, 10)], s + 3, STONE, 0), ov(Vector2(18, 26), 8, 6, s + 4, BERRY)]
			sil(ci, parts, rim)
			ln(ci, Vector2(-30, 0), Vector2(30, -18), 1.4, Color(INK, 0.4), s)
		6:
			var parts := [ov(Vector2(0, 18), 46, 20, s, Color("6a4428"), 0.0, 1)]
			sil(ci, parts, rim)
			ci.draw_colored_polygon(ell(Vector2(0, 20), Vector2(36, 13), s, 0.04, 18), Color("2a170c"))
			var stakes := []
			for k in 5:
				var x := -24.0 + float(k) * 12.0
				stakes.append(pg([Vector2(x - 4, 28), Vector2(x, -2.0 - float(k % 2) * 8.0), Vector2(x + 4, 28)], s + 2 + k, WOOD))
			sil(ci, stakes, false)
			sil(ci, [leaf(Vector2(-46, 10), 26, 7, -0.3, s + 9), leaf(Vector2(46, 12), 26, 7, PI + 0.4, s + 10, LEAF_D.lightened(0.1)),
				stk(Vector2(-40, 2), Vector2(-10, 8), 2.0, s + 11, WOOD, 2)], false)
		7:
			var parts := [stk(Vector2(30, 38), Vector2(44, -40), 2.4, s, WOOD, 2), stk(Vector2(38, 38), Vector2(34, -44), 2.4, s + 1, WOOD, 2),
				pg([Vector2(-44, 36), Vector2(-4, -40), Vector2(36, 36)], s + 2, Color("c99a68"), 0),
				pg([Vector2(-10, 36), Vector2(-4, 4), Vector2(4, 36)], s + 3, Color("3a2416"))]
			parts.append(pg([Vector2(44, -40), Vector2(48, -50), Vector2(50, -38)], s + 4, STONE_D))
			parts.append(pg([Vector2(34, -44), Vector2(32, -54), Vector2(38, -46)], s + 5, STONE_D))
			sil(ci, parts, rim)
			for k in 3:
				ln(ci, Vector2(-4, -40), Vector2(-26.0 + float(k) * 20.0, 34), 1.4, Color(INK, 0.35), s + k)
			pl(ci, [Vector2(-34, 20), Vector2(-24, 12), Vector2(-14, 20)], 2.0, CLAY, s)
			pl(ci, [Vector2(10, 16), Vector2(18, 8), Vector2(26, 16)], 2.0, CLAY, s + 1)
			sil(ci, [stk(Vector2(-8, -44), Vector2(-4, -36), 2.0, s + 9, WOOD_D, 2), stk(Vector2(0, -44), Vector2(-4, -36), 2.0, s + 10, WOOD_D, 2)], false)
		8:
			var parts := [bx(-14, -28, 28, 70, 6, s, WOOD),
				pg([Vector2(-14, -26), Vector2(-34, -48), Vector2(-22, -24)], s + 1, BONE2),
				pg([Vector2(14, -26), Vector2(34, -48), Vector2(22, -24)], s + 2, BONE2),
				bx(-30, 4, 60, 9, 3, s + 3, WOOD_D)]
			sil(ci, parts, rim)
			eye(ci, Vector2(-6, -16), 4)
			eye(ci, Vector2(6, -16), 4)
			ci.draw_colored_polygon(poly([Vector2(-6, -6), Vector2(6, -6), Vector2(0, 0)], s), INK)
			for k in 4:
				ci.draw_colored_polygon(poly([Vector2(-8.0 + float(k) * 4.0, 18), Vector2(-4.0 + float(k) * 4.0, 18), Vector2(-6.0 + float(k) * 4.0, 24)], s + k), BONE)
			zig(ci, -12, 12, 32, 3, 6, CLAY, 2.2, s)
			ln(ci, Vector2(-12, 14), Vector2(12, 14), 2.0, INK, s)
		_:
			glow(ci, Vector2(0, -6), 54, GOLD)
			var parts := [pg(arcp(Vector2(0, 38), Vector2(44, 60), PI, TAU, 16), s, Color("c8a478"), 0),
				band(Vector2(-6, 38), 46, 3.6, PI * 1.08, PI * 1.55, s + 1, BONE),
				band(Vector2(6, 38), 46, 3.6, PI * 1.45, PI * 1.92, s + 2, BONE),
				pg([Vector2(-12, 38), Vector2(-8, 8), Vector2(8, 8), Vector2(12, 38)], s + 3, Color("3a2416"))]
			sil(ci, parts, rim)
			for k in 5:
				var a := lerpf(PI * 1.12, PI * 1.88, float(k) / 4.0)
				ln(ci, Vector2(0, 38) + Vector2(cos(a) * 30.0, sin(a) * 40.0), Vector2(0, 38) + Vector2(cos(a) * 42.0, sin(a) * 56.0), 3.0, BONE2.darkened(0.15), s + k)
			sil(ci, [ov(Vector2(0, -20), 12, 9, s + 9, BONE)], false)
			xeye(ci, Vector2(-4, -21), 2.0, 1.8)
			xeye(ci, Vector2(4, -21), 2.0, 1.8)
			ci.draw_colored_polygon(ell(Vector2(0, 26), Vector2(6, 6), s, 0.1, 10), FIRE)
			sparks(ci, [Vector2(-42, -36), Vector2(40, -40), Vector2(40, 26)])

static func main(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			beast(ci, s, rim, {"b": Vector2(16, 10), "c": MOUSE, "h": Vector2(9, 8), "sn": 4, "ear": "round", "es": 6,
				"leg": 6, "lw": 2.4, "tail": "thin", "tl": 30, "tc": PINK.darkened(0.1), "oy": 10})
		2:
			beast(ci, s, rim, {"b": Vector2(18, 13), "c": FROG, "c2": Color("e8f0a0"), "h": Vector2(13, 10), "hp": Vector2(-14, -4), "sn": 0,
				"ear": "", "leg": 14, "lw": 3.4, "ld": Vector2(1.0, 0.45), "tail": "", "oy": 12, "f": ["spots"]})
		3:
			beast(ci, s, rim, {"b": Vector2(18, 8), "c": LIZ, "c2": Color("e8e0a0"), "h": Vector2(10, 7), "hp": Vector2(-20, -2), "sn": 0,
				"ear": "", "leg": 9, "lw": 2.6, "ld": Vector2(1.0, 0.4), "tail": "long", "tl": 34, "oy": 8, "bc": Vector2(-4, 0), "f": ["spots"]})
		4:
			beast(ci, s, rim, {"b": Vector2(20, 14), "c": HARE, "c2": BONE, "h": Vector2(11, 10), "sn": 4, "ear": "long", "es": 16,
				"leg": 9, "lw": 3.2, "tail": "short", "tl": 24, "tc": BONE, "oy": 12})
		5:
			beast(ci, s, rim, {"b": Vector2(22, 15), "c": HEDGE, "c2": Color("e8d0a8"), "h": Vector2(11, 10), "sn": 6, "ear": "round", "es": 4,
				"leg": 6, "lw": 3.0, "tail": "", "oy": 12, "f": ["spike"]})
		6:
			beast(ci, s, rim, {"b": Vector2(22, 13), "c": FOX, "c2": BONE, "h": Vector2(12, 10), "sn": 8, "ear": "pt", "es": 9,
				"leg": 12, "lw": 3.0, "lc": FUR_D, "tail": "bushy", "tl": 30, "oy": 12})
		7:
			beast(ci, s, rim, {"b": Vector2(24, 15), "c": BADG, "c2": BONE2, "h": Vector2(13, 10), "sn": 6, "ear": "round", "es": 4,
				"leg": 8, "lw": 4.0, "lc": BLACK, "tail": "short", "tl": 18, "oy": 12, "f": ["badger"]})
		8:
			beast(ci, s, rim, {"b": Vector2(28, 18), "c": BOAR, "c2": Color("c08a64"), "h": Vector2(15, 13), "sn": 7, "ear": "pt", "es": 8,
				"leg": 10, "lw": 4.4, "hoof": BLACK, "tail": "tuft", "tl": 14, "oy": 14, "f": ["tusk", "mane"]})
		9:
			beast(ci, s, rim, {"b": Vector2(26, 16), "c": GOAT, "c2": BONE, "h": Vector2(12, 11), "sn": 6, "ear": "flap", "es": 6,
				"leg": 16, "lw": 3.4, "hoof": STONE_D, "tail": "short", "tl": 12, "oy": 10, "f": ["goat"]})
		10:
			beast(ci, s, rim, {"b": Vector2(28, 16), "c": DEER, "c2": BONE2, "h": Vector2(12, 10), "sn": 7, "ear": "pt", "es": 7,
				"leg": 20, "lw": 3.2, "hoof": INK, "tail": "short", "tl": 12, "tc": BONE, "oy": 6, "f": ["antler", "whitespots"]})
		11:
			beast(ci, s, rim, {"b": Vector2(28, 16), "c": WOLF, "c2": BONE2, "h": Vector2(14, 11), "sn": 9, "ear": "pt", "es": 10,
				"leg": 16, "lw": 3.8, "tail": "bushy", "tl": 30, "oy": 8, "f": ["mane"]})
		12:
			beast(ci, s, rim, {"b": Vector2(32, 20), "c": BISON, "c2": Color("8a6044"), "h": Vector2(15, 14), "sn": 6, "ear": "", "es": 6,
				"leg": 14, "lw": 5.0, "hoof": INK, "tail": "tuft", "tl": 16, "oy": 10, "f": ["hump", "bison", "fur"]})
		13:
			beast(ci, s, rim, {"b": Vector2(34, 24), "c": BEAR, "c2": Color("a87850"), "h": Vector2(18, 16), "sn": 8, "ear": "round", "es": 7,
				"leg": 12, "lw": 7.0, "tail": "short", "tl": 18, "oy": 12, "f": ["fur", "furline"]})
		14:
			beast(ci, s, rim, {"b": Vector2(34, 20), "c": TIGER, "c2": BONE, "h": Vector2(17, 15), "sn": 7, "ear": "round", "es": 6,
				"leg": 14, "lw": 6.0, "tail": "thin", "tl": 28, "oy": 10, "f": ["stripe", "fang"]})
		15:
			beast(ci, s, rim, {"b": Vector2(36, 24), "c": RHINO, "c2": Color("b89070"), "h": Vector2(18, 15), "sn": 9, "ear": "pt", "es": 7,
				"leg": 12, "lw": 7.0, "hoof": INK, "tail": "tuft", "tl": 14, "oy": 12, "f": ["fur", "rhino", "furline", "notongue"]})
		_:
			glow(ci, Vector2(0, 6), 54, GOLD)
			beast(ci, s, rim, {"b": Vector2(38, 28), "c": MAMMOTH, "c2": Color("a8784e"), "h": Vector2(20, 18), "hp": Vector2(-30, -18), "sn": 0,
				"ear": "flap", "es": 12, "leg": 12, "lw": 8.0, "lc": MAMMOTH.darkened(0.1), "tail": "tuft", "tl": 12, "oy": 18,
				"f": ["fur", "trunk", "bigtusk", "furline", "notongue"]})
			sparks(ci, [Vector2(-40, 36), Vector2(42, 32), Vector2(30, -40)])

static func sub(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			var wing := [Vector2(0, -2), Vector2(-14, -18), Vector2(-40, -14), Vector2(-34, -4), Vector2(-26, 2), Vector2(-18, 0), Vector2(-10, 8)]
			var wr := []
			for p in wing:
				wr.append(Vector2(-(p as Vector2).x, (p as Vector2).y))
			sil(ci, [pg(wing, s, Color("5a4a5e")), pg(wr, s + 1, Color("5a4a5e")), ov(Vector2(0, 4), 10, 14, s + 2, Color("6e5a70"), 0.0, 1),
				pg([Vector2(-8, -8), Vector2(-6, -20), Vector2(-1, -10)], s + 3, Color("6e5a70")),
				pg([Vector2(8, -8), Vector2(6, -20), Vector2(1, -10)], s + 4, Color("6e5a70"))], rim)
			for k in 3:
				ln(ci, Vector2(-14, -18), Vector2(-40.0 + float(k) * 7.0, -14.0 + float(k) * 6.0), 1.4, Color(INK, 0.5), s + k)
				ln(ci, Vector2(14, -18), Vector2(40.0 - float(k) * 7.0, -14.0 + float(k) * 6.0), 1.4, Color(INK, 0.5), s + k + 5)
			xeye(ci, Vector2(-4, -2), 2.4, 2.0)
			xeye(ci, Vector2(4, -2), 2.4, 2.0)
			ci.draw_colored_polygon(poly([Vector2(-2, 6), Vector2(-1, 10), Vector2(0, 6)], s), BONE)
			ci.draw_colored_polygon(poly([Vector2(0, 6), Vector2(1, 10), Vector2(2, 6)], s + 1), BONE)
		2:
			bird(ci, s, rim, {"b": Vector2(14, 10), "c": Color("a8784e"), "c2": Color("e8d8b8"), "hr": 8, "beak": "short", "bk": STONE_D,
				"tail": "fan", "tl": 12, "leg": 6, "oy": 12, "f": ["spot"]})
		3:
			bird(ci, s, rim, {"b": Vector2(16, 13), "c": Color("9a7a52"), "c2": Color("e8d8b8"), "hr": 8, "beak": "short", "bk": STONE_D,
				"tail": "short", "tl": 10, "leg": 6, "oy": 10, "f": ["spot"]})
		4:
			bird(ci, s, rim, {"b": Vector2(18, 13), "c": Color("a8aab8"), "c2": Color("c8a8c8"), "wc": Color("8a8c9c"), "hr": 9, "beak": "short", "bk": PINK,
				"tail": "fan", "tl": 14, "leg": 7, "lc": PINK, "oy": 10, "f": ["chest"], "cc": Color("9ac8b0")})
		5:
			bird(ci, s, rim, {"b": Vector2(20, 13), "c": BLACK, "c2": Color("4a4458"), "wc": Color("1e1a24"), "hr": 10, "beak": "long", "bk": BLACK,
				"tail": "fan", "tl": 18, "leg": 8, "lc": STONE_D, "oy": 10})
		6:
			bird(ci, s, rim, {"b": Vector2(22, 14), "c": Color("9a7a5a"), "c2": Color("e8d8b8"), "wc": Color("7a5e44"), "hr": 10, "hc": Color("2f8a4a"),
				"neck": 6, "nc": Color("2f8a4a"), "beak": "duck", "bk": OCHRE, "tail": "short", "tl": 12, "leg": 6, "lc": OCHRE, "oy": 10})
		7:
			bird(ci, s, rim, {"b": Vector2(20, 14), "c": Color("b8622a"), "c2": Color("e8a85a"), "wc": Color("8a4a22"), "hr": 9, "hc": Color("2a5a8a"),
				"neck": 4, "nc": Color("2a5a8a"), "beak": "short", "bk": BONE2, "tail": "long", "tl": 40, "tc": Color("c8a058"), "leg": 8, "oy": 12, "f": ["wattle"]})
		8:
			bird(ci, s, rim, {"b": Vector2(24, 15), "c": Color("9a8c7a"), "c2": BONE2, "wc": Color("6e6458"), "hr": 9, "hc": BLACK,
				"neck": 14, "nc": BLACK, "beak": "duck", "bk": BLACK, "tail": "short", "tl": 12, "leg": 6, "lc": BLACK, "oy": 14})
		9:
			bird(ci, s, rim, {"b": Vector2(20, 18), "c": Color("a87a4a"), "c2": BONE2, "wc": Color("7a5432"), "hr": 15, "beak": "hook", "bk": STONE_D,
				"tail": "short", "tl": 10, "leg": 6, "oy": 8, "f": ["tufts", "face", "spot"]})
		10:
			bird(ci, s, rim, {"b": Vector2(26, 16), "c": Color("f4f0e8"), "c2": BONE, "wc": Color("e0dace"), "hr": 9, "neck": 22, "nc": Color("f4f0e8"),
				"beak": "duck", "bk": FIRE, "tail": "short", "tl": 12, "leg": 6, "lc": BLACK, "oy": 16})
		11:
			bird(ci, s, rim, {"b": Vector2(26, 18), "c": Color("4a3a30"), "c2": Color("8a7060"), "wc": Color("2e241e"), "hr": 10, "hc": PINK.darkened(0.15),
				"neck": 8, "nc": PINK.darkened(0.15), "beak": "hook", "bk": BONE2, "tail": "fan", "tl": 18, "wing": 46, "leg": 8, "oy": 10, "f": ["ruff"]})
		_:
			glow(ci, Vector2(0, 0), 52, GOLD)
			bird(ci, s, rim, {"b": Vector2(28, 18), "c": Color("6a4428"), "c2": Color("a8784e"), "wc": Color("4a2e1a"), "hr": 12, "hc": Color("f4f0e8"),
				"beak": "hook", "bk": GOLD, "tail": "fan", "tl": 20, "tc": Color("f4f0e8"), "wing": 52, "leg": 9, "lc": GOLD, "oy": 10})
			sparks(ci, [Vector2(-40, -32), Vector2(40, -34), Vector2(36, 28)])
