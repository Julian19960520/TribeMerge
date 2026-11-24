"""生成「火光岩画」活动图标：灯光 12 级、壁画 8 级、画笔 3 档、颜料 2 种、入口图标。

风格与月石遗迹的手写 SVG 一致：96×96、深棕描边 #3b2314、厚涂色块 + 一笔高光。
用法：python tools/gen_cave_icons.py  （输出到 assets/events/cave/）
"""
import math
import os

INK = "#3b2314"
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "events", "cave")


def svg(body, halo=0.0, halo_color="#ffcf7a"):
    defs = ""
    if halo > 0:
        defs = (f'<defs><radialGradient id="h"><stop offset="0" stop-color="{halo_color}" stop-opacity="{0.9 * halo:.2f}"/>'
                f'<stop offset=".55" stop-color="#ff9a3c" stop-opacity="{0.35 * halo:.2f}"/>'
                f'<stop offset="1" stop-color="#ff9a3c" stop-opacity="0"/></radialGradient></defs>'
                f'<circle cx="48" cy="44" r="47" fill="url(#h)"/>')
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96">{defs}{body}</svg>'


def shadow(cx=48, cy=86, rx=26, ry=5):
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="#1a0e08" opacity=".28"/>'


def flame(cx, base, h, w, sw=3.5):
    """泪滴形火苗：外焰橙红、内焰金黄、芯点浅黄。"""
    top = base - h
    outer = (f'M{cx} {top}C{cx + w * 0.25} {top + h * 0.3} {cx + w * 0.6} {base - h * 0.45} {cx + w * 0.5} {base - h * 0.2}'
             f'C{cx + w * 0.42} {base + 2} {cx - w * 0.42} {base + 2} {cx - w * 0.5} {base - h * 0.2}'
             f'C{cx - w * 0.6} {base - h * 0.5} {cx - w * 0.1} {top + h * 0.35} {cx} {top}Z')
    ih, iw = h * 0.58, w * 0.52
    itop = base - ih
    inner = (f'M{cx} {itop}C{cx + iw * 0.4} {itop + ih * 0.35} {cx + iw * 0.55} {base - ih * 0.3} {cx + iw * 0.4} {base - ih * 0.1}'
             f'C{cx + iw * 0.3} {base} {cx - iw * 0.3} {base} {cx - iw * 0.4} {base - ih * 0.1}'
             f'C{cx - iw * 0.55} {base - ih * 0.3} {cx - iw * 0.2} {itop + ih * 0.4} {cx} {itop}Z')
    return (f'<path d="{outer}" fill="#f06a2a" stroke="{INK}" stroke-width="{sw}" stroke-linejoin="round"/>'
            f'<path d="{inner}" fill="#ffc94a"/>'
            f'<ellipse cx="{cx}" cy="{base - ih * 0.3}" rx="{iw * 0.18}" ry="{ih * 0.2}" fill="#fff4c2"/>')


def stick(x1, y1, x2, y2, w=8, fill="#8a5a32"):
    return (f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{INK}" stroke-width="{w + 6}" stroke-linecap="round"/>'
            f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{fill}" stroke-width="{w}" stroke-linecap="round"/>')


def spark(x, y, r=4, c="#fff0a6"):
    return f'<path d="M{x} {y - r}Q{x + r * 0.2} {y - r * 0.2} {x + r} {y}Q{x + r * 0.2} {y + r * 0.2} {x} {y + r}Q{x - r * 0.2} {y + r * 0.2} {x - r} {y}Q{x - r * 0.2} {y - r * 0.2} {x} {y - r}Z" fill="{c}"/>'


def hi(d, w=4, c="#fff3c4"):
    return f'<path d="{d}" fill="none" stroke="{c}" stroke-width="{w}" stroke-linecap="round" opacity=".9"/>'


# ---------------------------------------------------------------- 灯光线
def glow_1():  # 松脂滴
    return svg(shadow(rx=16) +
               f'<path d="M48 22C56 36 66 48 66 60A18 18 0 0 1 30 60C30 48 40 36 48 22Z" fill="#e8962a" stroke="{INK}" stroke-width="4.5" stroke-linejoin="round"/>'
               f'<path d="M52 44C58 52 61 58 60 64" fill="none" stroke="#b8641a" stroke-width="5" stroke-linecap="round"/>'
               + hi("M40 50Q41 42 45 36") + spark(64, 28, 5), 0.35)


def glow_2():  # 松脂块
    return svg(shadow(rx=24) +
               f'<path d="M26 58L32 34L52 24L70 36L72 60L54 74L34 72Z" fill="#e8962a" stroke="{INK}" stroke-width="4.5" stroke-linejoin="round"/>'
               f'<path d="M52 24L50 48L72 60M50 48L34 72" fill="none" stroke="#b8641a" stroke-width="3.5" stroke-linejoin="round"/>'
               f'<path d="M32 36L50 28L48 46L30 56Z" fill="#f7b84a"/>'
               + hi("M36 40L46 34") + spark(70, 24, 5) + spark(24, 30, 3.5), 0.45)


def glow_3():  # 干苔灯芯
    tuft = ''.join(f'<path d="M{48 + dx} 74Q{48 + dx * 1.6} {60 - abs(dx) * 0.3} {48 + dx * 2.2} {54 - (8 - abs(dx))}" fill="none" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>'
                   f'<path d="M{48 + dx} 74Q{48 + dx * 1.6} {60 - abs(dx) * 0.3} {48 + dx * 2.2} {54 - (8 - abs(dx))}" fill="none" stroke="#8a9a46" stroke-width="3.5" stroke-linecap="round"/>'
                   for dx in (-8, -4, 0, 4, 8))
    return svg(shadow(rx=22) +
               f'<ellipse cx="48" cy="74" rx="20" ry="8" fill="#6b7a34" stroke="{INK}" stroke-width="4"/>'
               + tuft + flame(48, 50, 30, 22), 0.55)


def glow_4():  # 树枝火把
    return svg(shadow(cx=44, rx=14) + stick(40, 86, 54, 42, 8) +
               f'<path d="M50 50L60 46" stroke="{INK}" stroke-width="3" stroke-linecap="round"/>'
               + flame(56, 44, 32, 24) + spark(30, 24, 4), 0.6)


def glow_5():  # 桦皮火把
    bark = ''.join(f'<line x1="{44 + k * 3.2}" y1="{76 - k * 9}" x2="{51 + k * 3.2}" y2="{80 - k * 9}" stroke="#2e1a0e" stroke-width="2.5" stroke-linecap="round"/>' for k in range(3))
    return svg(shadow(cx=44, rx=14) + stick(38, 88, 56, 40, 12, "#efe6d2") + bark +
               f'<path d="M50 48L62 42L60 52Z" fill="#efe6d2" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
               + flame(57, 42, 38, 28) + spark(30, 22, 4.5) + spark(76, 30, 3.5), 0.7)


def glow_6():  # 松明火把：裹满松脂的粗木把
    return svg(shadow(cx=44, rx=16) + stick(38, 88, 54, 46, 12, "#7a4a28") +
               f'<path d="M44 52Q56 40 66 48Q64 60 52 64Q42 62 44 52Z" fill="#c9782a" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>'
               f'<path d="M48 56Q56 50 62 52" fill="none" stroke="#e8a84a" stroke-width="3" stroke-linecap="round"/>'
               + flame(56, 48, 44, 34) + spark(28, 26, 5) + spark(80, 22, 4), 0.8)


def glow_7():  # 贝壳油灯
    ribs = ''.join(f'<line x1="48" y1="80" x2="{48 + math.cos(a) * 30}" y2="{80 - math.sin(a) * 22}" stroke="#c98a5a" stroke-width="2.5"/>' for a in [math.pi * (0.2 + 0.15 * k) for k in range(5)])
    return svg(shadow(rx=28) +
               f'<path d="M18 74Q20 54 48 52Q76 54 78 74Q66 84 48 84Q30 84 18 74Z" fill="#f3d9b8" stroke="{INK}" stroke-width="4.5" stroke-linejoin="round"/>'
               + ribs + f'<ellipse cx="48" cy="62" rx="20" ry="6" fill="#c9782a" stroke="{INK}" stroke-width="3"/>'
               + flame(48, 60, 36, 24) + hi("M26 70Q30 60 40 57"), 0.8)


def glow_8():  # 兽脂石灯
    return svg(shadow(rx=28) +
               f'<path d="M20 58L76 58L70 80Q48 88 26 80Z" fill="#9a8a78" stroke="{INK}" stroke-width="4.5" stroke-linejoin="round"/>'
               f'<ellipse cx="48" cy="58" rx="28" ry="8" fill="#7a6a5a" stroke="{INK}" stroke-width="4"/>'
               f'<ellipse cx="48" cy="58" rx="20" ry="4.5" fill="#f0e2b8"/>'
               f'<path d="M30 70L38 74M58 74L66 70" stroke="#6a5a4a" stroke-width="3" stroke-linecap="round"/>'
               + flame(48, 56, 40, 28) + hi("M26 64Q30 72 36 76", 3.5, "#c8bba8"), 0.85)


def glow_9():  # 火把束
    body = stick(34, 88, 40, 44, 8) + stick(62, 88, 56, 44, 8) + stick(48, 90, 48, 42, 9, "#7a4a28")
    rope = f'<path d="M36 66Q48 72 60 66" fill="none" stroke="{INK}" stroke-width="8" stroke-linecap="round"/><path d="M36 66Q48 72 60 66" fill="none" stroke="#d8b46a" stroke-width="4" stroke-linecap="round"/>'
    return svg(shadow(rx=22) + body + rope + flame(38, 44, 30, 22, 3) + flame(58, 44, 30, 22, 3) + flame(48, 42, 42, 30)
               + spark(22, 24, 4.5) + spark(76, 20, 5), 0.9)


def glow_10():  # 洞壁火龛
    return svg(
        f'<path d="M10 90L10 40Q12 14 48 10Q84 14 86 40L86 90Z" fill="#6a5040" stroke="{INK}" stroke-width="4.5" stroke-linejoin="round"/>'
        f'<path d="M24 86L24 50Q26 28 48 26Q70 28 72 50L72 86Z" fill="#2a160c" stroke="{INK}" stroke-width="4"/>'
        f'<path d="M14 30L22 34M78 26L70 32M12 62L20 62M84 64L76 66" stroke="#4a3426" stroke-width="3" stroke-linecap="round"/>'
        f'<ellipse cx="48" cy="80" rx="18" ry="5" fill="#9a8a78" stroke="{INK}" stroke-width="3"/>'
        + flame(48, 78, 42, 28) + f'<path d="M28 52Q30 36 44 32" fill="none" stroke="#ff9a3c" stroke-width="3" stroke-linecap="round" opacity=".6"/>', 0.7)


def _stones(cx, cy, rx, ry, n, r):
    out = ""
    for k in range(n):
        a = math.pi * (0.05 + 0.9 * k / (n - 1))
        x, y = cx + math.cos(a) * rx, cy + math.sin(a) * ry * 0.6
        out += f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{r}" ry="{r * 0.75}" fill="#9a8a78" stroke="{INK}" stroke-width="3.5"/>'
    return out


def _logs(cx, cy, w):
    return (stick(cx - w, cy + 4, cx + w * 0.6, cy - 10, 7, "#7a4a28") + stick(cx + w, cy + 4, cx - w * 0.6, cy - 10, 7, "#8a5a32"))


def glow_11():  # 石圈火塘
    back = ''.join(f'<ellipse cx="{48 + dx}" cy="62" rx="8" ry="6" fill="#857563" stroke="{INK}" stroke-width="3.5"/>' for dx in (-22, 0, 22))
    return svg(shadow(rx=36, ry=6) + back + _logs(48, 70, 22) + flame(48, 66, 46, 34) + _stones(48, 70, 32, 18, 6, 9)
               + spark(24, 22, 4.5) + spark(72, 18, 5), 0.95)


def glow_12():  # 部落火塘
    back = ''.join(f'<ellipse cx="{48 + dx}" cy="60" rx="9" ry="7" fill="#857563" stroke="{INK}" stroke-width="3.5"/>' for dx in (-28, -10, 10, 28))
    return svg(shadow(rx=40, ry=7) + back + _logs(48, 70, 28) + flame(36, 66, 34, 24, 3) + flame(60, 66, 36, 24, 3) + flame(48, 66, 58, 38)
               + _stones(48, 72, 38, 20, 7, 9) + spark(18, 26, 5) + spark(78, 16, 6) + spark(70, 40, 3.5) + spark(26, 46, 3.5), 1.0, "#fff0a0")


# ---------------------------------------------------------------- 壁画线：岩板 + 赭红颜料
def slab(gold=False):
    edge = "#d8a84a" if gold else INK
    return (shadow(rx=36, ry=5) +
            f'<path d="M12 22Q14 12 26 12L70 10Q84 12 86 24L88 70Q86 84 72 84L24 86Q10 84 10 70Z" fill="#c9a27a" stroke="{edge}" stroke-width="{6 if gold else 4.5}" stroke-linejoin="round"/>'
            + (f'<path d="M12 22Q14 12 26 12L70 10Q84 12 86 24L88 70Q86 84 72 84L24 86Q10 84 10 70Z" fill="none" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>' if gold else "")
            + f'<path d="M18 26Q20 18 30 18L66 17Q78 18 80 28L81 66Q79 77 68 77L28 78Q17 77 17 66Z" fill="#dcb98e"/>'
            '<path d="M22 70L30 66M70 22L76 28M62 72L72 70" stroke="#b8906a" stroke-width="2.5" stroke-linecap="round"/>')


RED = "#a8361e"
DARK = "#4a2014"


def beast(cx, cy, s, kind, c=RED):
    """洞穴画风的走兽：躯干椭圆 + 细腿 + 头角。"""
    w, h = 16 * s, 8 * s
    body = f'<ellipse cx="{cx}" cy="{cy}" rx="{w}" ry="{h}" fill="{c}"/>'
    legs = ''.join(f'<line x1="{cx + dx * w}" y1="{cy + h * 0.6}" x2="{cx + dx * w + lean * s}" y2="{cy + h + 9 * s}" stroke="{c}" stroke-width="{3 * s}" stroke-linecap="round"/>'
                   for dx, lean in ((-0.7, -2), (-0.4, 2), (0.45, -2), (0.75, 3)))
    if kind == "deer":
        head = (f'<ellipse cx="{cx + w + 3 * s}" cy="{cy - h - 2 * s}" rx="{5 * s}" ry="{3.5 * s}" fill="{c}"/>'
                f'<path d="M{cx + w - 2 * s} {cy - h * 0.4}L{cx + w + 2 * s} {cy - h - 2 * s}" stroke="{c}" stroke-width="{4 * s}"/>'
                f'<path d="M{cx + w + 2 * s} {cy - h - 5 * s}L{cx + w} {cy - h - 14 * s}M{cx + w + 1 * s} {cy - h - 10 * s}L{cx + w - 5 * s} {cy - h - 12 * s}M{cx + w + 5 * s} {cy - h - 5 * s}L{cx + w + 9 * s} {cy - h - 13 * s}" stroke="{c}" stroke-width="{2.2 * s}" stroke-linecap="round" fill="none"/>')
    elif kind == "bison":
        body = f'<path d="M{cx - w} {cy + h * 0.3}Q{cx - w} {cy - h} {cx} {cy - h * 1.5}Q{cx + w * 0.8} {cy - h * 1.9} {cx + w} {cy - h * 0.4}Q{cx + w} {cy + h} {cx} {cy + h}Q{cx - w * 0.8} {cy + h} {cx - w} {cy + h * 0.3}Z" fill="{c}"/>'
        head = (f'<ellipse cx="{cx + w + 3 * s}" cy="{cy}" rx="{6 * s}" ry="{5 * s}" fill="{DARK}"/>'
                f'<path d="M{cx + w + 1 * s} {cy - 4 * s}Q{cx + w + 6 * s} {cy - 10 * s} {cx + w + 10 * s} {cy - 6 * s}" stroke="{DARK}" stroke-width="{2.2 * s}" fill="none" stroke-linecap="round"/>')
    elif kind == "horse":
        head = (f'<path d="M{cx + w - 3 * s} {cy - h * 0.5}L{cx + w + 4 * s} {cy - h - 8 * s}L{cx + w + 12 * s} {cy - h - 3 * s}" stroke="{c}" stroke-width="{5 * s}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
                f'<path d="M{cx + w - 4 * s} {cy - h}L{cx + w + 2 * s} {cy - h - 9 * s}" stroke="{DARK}" stroke-width="{2.5 * s}" stroke-linecap="round"/>'
                f'<path d="M{cx - w} {cy - 2 * s}Q{cx - w - 8 * s} {cy} {cx - w - 9 * s} {cy + 9 * s}" stroke="{DARK}" stroke-width="{3 * s}" fill="none" stroke-linecap="round"/>')
        legs = ''.join(f'<line x1="{cx + dx * w}" y1="{cy + h * 0.6}" x2="{cx + dx * w + lean * s}" y2="{cy + h + 9 * s}" stroke="{c}" stroke-width="{3 * s}" stroke-linecap="round"/>'
                       for dx, lean in ((-0.7, -8), (-0.4, -4), (0.45, 6), (0.75, 10)))
    else:  # mammoth
        body = f'<path d="M{cx - w} {cy + h}Q{cx - w * 1.1} {cy - h * 1.6} {cx} {cy - h * 1.7}Q{cx + w * 1.1} {cy - h * 1.6} {cx + w} {cy}L{cx + w} {cy + h}Z" fill="{c}"/>'
        head = (f'<path d="M{cx + w} {cy - h * 0.5}Q{cx + w + 8 * s} {cy} {cx + w + 5 * s} {cy + h + 8 * s}" stroke="{c}" stroke-width="{4.5 * s}" fill="none" stroke-linecap="round"/>'
                f'<path d="M{cx + w - 2 * s} {cy + 2 * s}Q{cx + w + 12 * s} {cy + 6 * s} {cx + w + 14 * s} {cy - 4 * s}" stroke="#f3ead6" stroke-width="{2.5 * s}" fill="none" stroke-linecap="round"/>')
        legs = ''.join(f'<rect x="{cx + dx * w - 2.5 * s}" y="{cy + h * 0.5}" width="{5 * s}" height="{9 * s}" fill="{c}"/>' for dx in (-0.7, -0.3, 0.35, 0.75))
    return body + legs + head


def man(x, y, s=1.0, spear=False, c=DARK):
    out = (f'<circle cx="{x}" cy="{y - 13 * s}" r="{3.2 * s}" fill="{c}"/>'
           f'<path d="M{x} {y - 10 * s}L{x} {y}M{x} {y}L{x - 4 * s} {y + 9 * s}M{x} {y}L{x + 4 * s} {y + 9 * s}M{x - 5 * s} {y - 6 * s}L{x + 5 * s} {y - 8 * s}" stroke="{c}" stroke-width="{2.6 * s}" stroke-linecap="round" fill="none"/>')
    if spear:
        out += f'<path d="M{x + 2 * s} {y - 2 * s}L{x + 14 * s} {y - 16 * s}" stroke="{c}" stroke-width="{2 * s}" stroke-linecap="round"/><path d="M{x + 14 * s} {y - 16 * s}l{-1 * s} {5 * s}l{4 * s} {-3 * s}Z" fill="{c}"/>'
    return out


def mural_1():
    dots = ''.join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{RED}"/>' for x, y, r in ((34, 38, 6), (52, 32, 5), (64, 48, 6.5), (40, 58, 5), (58, 64, 5.5), (30, 70, 3.5)))
    return svg(slab() + dots)


def mural_2():
    hand = ('<path d="M38 72Q32 62 34 50L32 34Q32 30 35 30Q38 30 38 34L39 46L40 28Q40 24 43.5 24Q47 24 47 28L47 46L49 26Q49 22 52.5 22Q56 22 56 26L55.5 47L59 32Q60 28 63 29Q66 30 65 34L62 54Q66 50 70 50Q73 51 72 54L64 66Q58 76 48 76Q42 76 38 72Z" fill="' + RED + '"/>')
    spray = ''.join(f'<circle cx="{48 + math.cos(a) * 30:.1f}" cy="{50 + math.sin(a) * 30:.1f}" r="1.8" fill="{RED}" opacity=".55"/>' for a in [k * 0.52 for k in range(12)])
    return svg(slab() + spray + hand)


def mural_3():
    return svg(slab() + beast(44, 52, 1.05, "deer"))


def mural_4():
    return svg(slab() + beast(44, 52, 1.15, "bison"))


def mural_5():
    return svg(slab() + beast(42, 50, 1.1, "horse") + f'<path d="M20 32L28 32M22 40L30 40" stroke="{RED}" stroke-width="2.5" stroke-linecap="round" opacity=".6"/>')


def mural_6():
    return svg(slab() + beast(60, 48, 0.8, "bison") + man(28, 62, 1.0, True) + man(40, 70, 0.85, True))


def mural_7():
    return svg(slab() + beast(62, 46, 0.72, "mammoth", "#8a2a18") + beast(36, 56, 0.85, "mammoth"))


def mural_8():
    sun = f'<circle cx="70" cy="28" r="7" fill="#e0a030"/>' + ''.join(
        f'<line x1="{70 + math.cos(a) * 10:.1f}" y1="{28 + math.sin(a) * 10:.1f}" x2="{70 + math.cos(a) * 14:.1f}" y2="{28 + math.sin(a) * 14:.1f}" stroke="#e0a030" stroke-width="2.5" stroke-linecap="round"/>' for a in [k * math.pi / 4 for k in range(8)])
    ground = f'<path d="M18 72Q48 66 80 72" stroke="{RED}" stroke-width="2.5" fill="none" stroke-linecap="round"/>'
    people = man(24, 62, 0.8) + man(34, 62, 0.8, True) + man(44, 62, 0.8) + man(54, 62, 0.75, True)
    return svg(slab(True) + sun + ground + people + beast(68, 58, 0.45, "mammoth") + spark(18, 20, 4) + spark(82, 78, 3.5), 0.4, "#ffe7a0")


# ---------------------------------------------------------------- 画笔
def brush_1():  # 苔藓刷
    tuft = ''.join(f'<path d="M58 34Q{64 + dx} {22 + dx * 0.4} {70 + dx} {14 + abs(dx)}" stroke="{INK}" stroke-width="7" fill="none" stroke-linecap="round"/>'
                   f'<path d="M58 34Q{64 + dx} {22 + dx * 0.4} {70 + dx} {14 + abs(dx)}" stroke="#8a9a46" stroke-width="3.5" fill="none" stroke-linecap="round"/>' for dx in (-8, -3, 2, 7))
    return svg(shadow(cx=40, rx=18) + stick(28, 84, 58, 36, 8) + tuft + f'<circle cx="62" cy="30" r="8" fill="{RED}" stroke="{INK}" stroke-width="3"/>')


def brush_2():  # 兽毛笔
    return svg(shadow(cx=40, rx=18) + stick(26, 84, 54, 40, 8, "#a8784a") +
               f'<path d="M52 42Q50 28 62 18Q74 12 78 16Q80 24 70 36Q62 44 52 42Z" fill="#7a5a3a" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>'
               f'<path d="M70 20Q78 16 78 16Q76 24 72 28Z" fill="{RED}"/>'
               f'<path d="M50 44L56 38" stroke="#d8b46a" stroke-width="5" stroke-linecap="round"/>'
               + hi("M58 34Q60 26 66 22", 2.5, "#c8a07a"))


def brush_3():  # 骨管喷笔
    spray = ''.join(f'<circle cx="{70 + math.cos(a) * d:.1f}" cy="{26 + math.sin(a) * d:.1f}" r="{r}" fill="{RED}"/>' for a, d, r in ((-0.9, 8, 3), (-0.3, 12, 2.5), (0.3, 9, 3.5), (-1.4, 14, 2), (0.8, 15, 2.2), (-0.1, 18, 1.8)))
    return svg(shadow(cx=40, rx=20) +
               f'<path d="M22 80L56 40" stroke="{INK}" stroke-width="18" stroke-linecap="round"/>'
               f'<path d="M22 80L56 40" stroke="#efe6d2" stroke-width="11" stroke-linecap="round"/>'
               f'<circle cx="22" cy="80" r="7" fill="#efe6d2" stroke="{INK}" stroke-width="3.5"/>'
               f'<path d="M30 66L36 72M40 54L46 60" stroke="#b8a888" stroke-width="2.5" stroke-linecap="round"/>'
               f'<circle cx="56" cy="40" r="5" fill="{INK}"/>' + spray + spark(84, 12, 4.5), 0.35)


# ---------------------------------------------------------------- 颜料
def paint_1():  # 红赭颜料：石臼里的红泥
    return svg(shadow(rx=28) +
               f'<path d="M20 52L76 52L70 76Q48 86 26 76Z" fill="#9a8a78" stroke="{INK}" stroke-width="4.5" stroke-linejoin="round"/>'
               f'<ellipse cx="48" cy="52" rx="28" ry="9" fill="#7a6a5a" stroke="{INK}" stroke-width="4"/>'
               f'<path d="M26 52Q30 40 44 42Q50 34 60 40Q72 42 70 52Q48 60 26 52Z" fill="{RED}" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>'
               + hi("M36 46Q42 42 48 44", 3, "#e8784a") + f'<circle cx="66" cy="30" r="5" fill="{RED}" stroke="{INK}" stroke-width="2.5"/>')


def paint_2():  # 彩泥颜料：贝壳里三色彩泥
    return svg(shadow(rx=30) +
               f'<path d="M16 60Q18 42 48 40Q78 42 80 60Q68 80 48 80Q28 80 16 60Z" fill="#f3d9b8" stroke="{INK}" stroke-width="4.5" stroke-linejoin="round"/>'
               f'<ellipse cx="34" cy="54" rx="10" ry="6" fill="{RED}" stroke="{INK}" stroke-width="3"/>'
               f'<ellipse cx="52" cy="50" rx="10" ry="6" fill="#e0a030" stroke="{INK}" stroke-width="3"/>'
               f'<ellipse cx="62" cy="62" rx="10" ry="6" fill="#2e2a28" stroke="{INK}" stroke-width="3"/>'
               f'<ellipse cx="40" cy="66" rx="8" ry="5" fill="#f0ead8" stroke="{INK}" stroke-width="3"/>'
               + spark(74, 30, 5) + spark(22, 30, 3.5), 0.35)


def entry():  # 活动入口：岩板上的手印 + 火把
    hand = ('<path d="M30 66Q26 58 27 48L26 36Q26 33 28.5 33Q31 33 31 36L32 45L32.5 31Q32.5 28 35.5 28Q38.5 28 38.5 31L38.5 45L40 29Q40 26 43 26Q46 26 46 29L45.5 46L48.5 35Q49.5 32 52 33Q54.5 34 53.5 37L51 52Q54 49 57 49Q59.5 50 58.5 52.5L52 62Q47 70 39 70Q33 70 30 66Z" fill="' + RED + '"/>')
    return svg(slab() + hand + stick(70, 88, 78, 54, 7) + flame(79, 54, 30, 22) + spark(64, 22, 4), 0.55)


def brush_4():  # 羽毛彩笔：骨管上扎一束彩羽，笔尖蘸着赭红和金黄
    feathers = ''.join(f'<path d="M58 38Q{66 + dx} {24 - dy} {74 + dx} {10 + dy}Q{70 + dx * 0.5} {26} 58 38Z" fill="{c}" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
                       for dx, dy, c in ((-10, 4, "#e0a030"), (-2, 0, RED), (6, 4, "#5aa0b8")))
    return svg(shadow(cx=40, rx=20) +
               f'<path d="M22 80L56 40" stroke="{INK}" stroke-width="16" stroke-linecap="round"/>'
               f'<path d="M22 80L56 40" stroke="#efe6d2" stroke-width="9" stroke-linecap="round"/>'
               f'<path d="M34 66L40 60" stroke="{RED}" stroke-width="5" stroke-linecap="round"/>'
               f'<path d="M42 56L48 50" stroke="#e0a030" stroke-width="5" stroke-linecap="round"/>' + feathers + spark(84, 30, 4) + spark(30, 30, 3), 0.4)


def brush_5():  # 火神笔：笔头燃着一簇火苗，笔杆缠金
    return svg(shadow(cx=40, rx=22) +
               f'<path d="M20 82L54 42" stroke="{INK}" stroke-width="18" stroke-linecap="round"/>'
               f'<path d="M20 82L54 42" stroke="#c8903a" stroke-width="11" stroke-linecap="round"/>'
               f'<path d="M28 68L36 74M36 58L44 64M44 50L50 55" stroke="#ffd66a" stroke-width="3.5" stroke-linecap="round"/>'
               f'<path d="M50 44Q52 34 60 30Q66 36 62 46Z" fill="#7a5a3a" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>'
               + flame(66, 32, 28, 22) + spark(84, 52, 4.5) + spark(30, 22, 4), 0.75, "#ffe7a0")


# ---------------------------------------------------------------- 卡包碎片：主游戏绿卡包撕下来的残片，越高级越完整
PACK = (f'<path d="M23 16Q48 8 74 16L77 76Q49 87 20 76Z" fill="#76b47a" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>'
        f'<path d="M23 16L29 22L34 16L40 22L46 15L52 22L58 15L64 22L74 16" fill="none" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
        f'<path d="M28 31Q49 25 68 32L68 62Q49 69 28 62Z" fill="#f3dfb6" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>'
        f'<path d="M39 37L59 37L56 53L43 55Z" fill="#9a6241" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
        f'<path d="M41 41L57 41M46 47L54 47" stroke="#f7d772" stroke-width="2.5" stroke-linecap="round"/>')


def _tear(x0, y0, x1, y1, n, amp, seed):
    """从 (x0,y0) 到 (x1,y1) 的锯齿撕口。"""
    pts = []
    for k in range(n + 1):
        t = k / n
        j = 0 if k in (0, n) else (amp if (k + seed) % 2 else -amp) * (0.6 + 0.4 * ((k * 7 + seed) % 3) / 2)
        dx, dy = y1 - y0, x0 - x1
        ln = math.hypot(dx, dy) or 1
        pts.append((x0 + (x1 - x0) * t + dx / ln * j, y0 + (y1 - y0) * t + dy / ln * j))
    return pts


def shard(level):
    """撕口折线 = 碎片轮廓的一边；其余边沿用卡包外形（被裁剪出来）。"""
    cuts = {  # 每级保留的区域：多边形外框 + 撕口
        1: [(0, 0)] + _tear(46, 0, 0, 40, 6, 3.5, 1),
        2: [(0, 0)] + _tear(56, 0, 0, 56, 7, 3.5, 2),
        3: [(0, 0)] + _tear(52, 0, 44, 96, 8, 3.5, 3) + [(0, 96)],
        4: [(0, 0)] + _tear(62, 0, 58, 96, 8, 3.5, 4) + [(0, 96)],
        5: [(0, 0), (96, 0)] + _tear(96, 52, 52, 96, 6, 3.5, 5) + [(0, 96)],
        6: [(0, 0), (96, 0)] + _tear(96, 66, 66, 96, 4, 3, 6) + [(0, 96)],
    }
    poly = cuts[level]
    d = "M" + "L".join(f"{x:.1f} {y:.1f}" for x, y in poly) + "Z"
    tear = [p for p in poly if 0 < p[0] < 96 or 0 < p[1] < 96]
    edge = "M" + "L".join(f"{x:.1f} {y:.1f}" for x, y in tear)
    body = (f'<defs><clipPath id="c"><path d="{d}"/></clipPath>'
            f'<clipPath id="k"><path d="M23 16Q48 8 74 16L77 76Q49 87 20 76Z"/></clipPath></defs>' + shadow(rx=16 + level * 2) +
            f'<g clip-path="url(#c)">{PACK}</g>'
            f'<g clip-path="url(#k)"><path d="{edge}" fill="none" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/></g>')
    sparks = "".join(spark(x, y, r) for x, y, r in ((82, 18, 4), (14, 46, 3))[: max(0, level - 4)])
    return svg(body + sparks, 0.12 * max(0, level - 3), "#c8f0a0")


ICONS = {f"glow_{k}": globals()[f"glow_{k}"] for k in range(1, 13)}
ICONS.update({f"mural_{k}": globals()[f"mural_{k}"] for k in range(1, 9)})
ICONS.update({"brush_1": brush_1, "brush_2": brush_2, "brush_3": brush_3, "paint_1": paint_1, "paint_2": paint_2, "entry": entry})
ICONS.update({"brush_4": brush_4, "brush_5": brush_5})
ICONS.update({f"shard_{k}": (lambda k=k: shard(k)) for k in range(1, 7)})

if __name__ == "__main__":
    import sys
    os.makedirs(OUT, exist_ok=True)
    only = set(sys.argv[1:])  # 传名字就只写这几张，不动已有图标
    for name, fn in ICONS.items():
        if only and name not in only: continue
        with open(os.path.join(OUT, name + ".svg"), "w", encoding="utf-8") as f:
            f.write(fn())
    print(f"wrote {len(ICONS)} icons to {os.path.normpath(OUT)}")
