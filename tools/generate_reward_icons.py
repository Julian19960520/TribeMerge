"""Build the game's hand-drawn SVG resource icons and five chest grades."""
from pathlib import Path
import math

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/ui/items"
INK = "#3b2314"


def svg(body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="160" height="160" viewBox="0 0 160 160">'
            f'<g stroke="{INK}" stroke-width="4" stroke-linejoin="round" stroke-linecap="round">{body}</g></svg>\n')


def bolt(x=0, y=0, scale=1, color="#ffd43b"):
    return (f'<g transform="translate({x} {y}) scale({scale})">'
            f'<path d="M10 -53 L-30 7 L-4 4 L-15 53 L33 -12 L7 -8 L20 -53 Z" fill="{color}"/>'
            '<path d="M9 -39 L-18 1 L0 -1" fill="none" stroke="#fff5aa" stroke-width="4"/></g>')


def banana(x=0, y=0, scale=1, angle=0):
    return (f'<g transform="translate({x} {y}) rotate({angle}) scale({scale})">'
            '<path d="M-35 -25 C-43 17 -17 48 18 40 Q44 34 44 3 L36 -4 C24 27 -17 24 -26 -28 Z" fill="#ffd638"/>'
            '<path d="M-31 -14 C-30 15 -3 34 24 26" fill="none" stroke="#d99b24" stroke-width="4"/>'
            '<path d="M-29 -20 C-24 8 -2 22 20 17" fill="none" stroke="#fff19a" stroke-width="4"/>'
            '<path d="M-35 -25 L-35 -36 L-26 -36 L-26 -28 Z" fill="#668d38"/>'
            '<path d="M36 -4 L44 3 L47 -3 L40 -10 Z" fill="#79512b"/></g>')


def star(x, y, radius=7, color="#fff0a0"):
    pts = []
    for i in range(8):
        a = i * math.pi / 4 - math.pi / 2
        r = radius if i % 2 == 0 else radius * .35
        pts.append(f'{x+math.cos(a)*r:.2f},{y+math.sin(a)*r:.2f}')
    return f'<polygon points="{" ".join(pts)}" fill="{color}" stroke-width="2"/>'


def amber(x=0, y=0, scale=1, angle=0):
    return (f'<g transform="translate({x} {y}) rotate({angle}) scale({scale})">'
            '<path d="M-32 -20 L2 -42 L34 -17 L30 25 L-1 43 L-36 16 Z" fill="#f2a328"/>'
            '<path d="M-32 -20 L-5 -6 L2 -42 M-5 -6 L34 -17 M-5 -6 L30 25 M-5 -6 L-1 43 M-5 -6 L-36 16" fill="none" stroke="#ba6a20" stroke-width="2"/>'
            '<path d="M-28 -19 L-3 -34 L-9 -12 Z" fill="#ffe39a" stroke="none"/>'
            '<g stroke="#70401d" stroke-width="2.5"><path d="M-7 3 L-15 -3 M-7 10 L-17 10 M-6 17 L-14 23 M7 3 L15 -3 M7 10 L17 10 M6 17 L14 23"/>'
            '<ellipse cx="0" cy="10" rx="7" ry="11" fill="#8b5324"/><circle cx="0" cy="-4" r="4" fill="#8b5324"/></g>'
            '<path d="M17 -24 L24 -19" fill="none" stroke="#fff5bf" stroke-width="4"/></g>')


def hourglass(x=0, y=0, scale=1, angle=0):
    return (f'<g transform="translate({x} {y}) rotate({angle}) scale({scale})">'
            '<path d="M-23 -37 Q-28 -15 -6 0 Q-28 16 -23 37 L23 37 Q28 16 6 0 Q28 -15 23 -37 Z" fill="#d4ede3"/>'
            '<path d="M-17 -28 L17 -28 Q16 -17 0 -8 Q-16 -17 -17 -28 Z" fill="#e6b74f" stroke-width="2"/>'
            '<path d="M-20 33 Q0 8 20 33 Z" fill="#e6b74f" stroke-width="2"/>'
            '<path d="M0 -5 L0 18" fill="none" stroke="#bd872f" stroke-width="2" stroke-dasharray="3 3"/>'
            '<path d="M-27 -39 L-27 39 M27 -39 L27 39" stroke="#a76b35" stroke-width="6"/>'
            '<path d="M-32 -47 L32 -47 L32 -37 L-32 -37 Z M-32 37 L32 37 L32 47 L-32 47 Z" fill="#e7c28c"/>'
            '<path d="M-17 -19 L-14 -12 M-16 18 L-18 25" fill="none" stroke="#fffdf1" stroke-width="3"/></g>')


def resource_unit(ch, x, y, scale, angle=0):
    if ch == 'fire':
        return f'<g transform="rotate({angle} {x} {y})">{bolt(x,y,scale)}</g>'
    return {'shell':banana, 'amber':amber, 'sand':hourglass}[ch](x,y,scale,angle)


def fragment(ch):
    # Jagged missing parts, rather than a miniature complete object, mark tier one.
    if ch == 'fire':
        return ('<path d="M92 24 L48 85 L72 82 L65 101 L78 92 L87 99 L94 81 L111 66 L88 71 L102 24 Z" fill="#d9bd5f"/>'
                '<path d="M65 101 L78 92 L87 99" fill="none" stroke="#947b3b" stroke-width="3"/>'
                '<path d="M96 115 L108 104 L104 125 Z" fill="#d9bd5f" stroke-width="3"/>')
    if ch == 'shell':
        return ('<path d="M42 40 C29 84 57 127 92 119 L100 110 L91 106 L98 97 L88 94 C62 96 47 66 52 38 Z" fill="#e0c65e"/>'
                '<path d="M44 54 C40 79 57 106 81 108" fill="none" stroke="#fff0ac" stroke-width="5"/>'
                '<path d="M92 119 L100 110 L91 106 L98 97 L88 94 L82 99 L88 107 L83 114 Z" fill="#fff2cb" stroke-width="2"/>'
                '<path d="M42 40 L42 27 L52 27 L52 38 Z" fill="#778345"/>'
                '<path d="M116 112 L127 116 L118 125 Z" fill="#e0c65e" stroke-width="3"/>')
    if ch == 'amber':
        return ('<path d="M48 52 L81 29 L104 46 L93 56 L104 65 L92 73 L101 85 L78 112 L43 91 Z" fill="#d6a150"/>'
                '<path d="M48 52 L70 61 L81 29 M70 61 L43 91 M70 61 L78 112" fill="none" stroke="#a47030" stroke-width="2"/>'
                '<path d="M93 56 L104 65 L92 73 L101 85" fill="none" stroke="#fff1b2" stroke-width="3"/>'
                '<path d="M116 96 L132 107 L117 119 L108 106 Z" fill="#d6a150" stroke-width="3"/>')
    return ('<path d="M51 40 Q48 63 71 80 L68 91 L80 87 L86 95 L91 82 Q112 62 109 40 Z" fill="#c5d7cf"/>'
            '<path d="M59 49 L101 49 Q99 63 80 73 Q61 63 59 49 Z" fill="#c9ae6d" stroke-width="2"/>'
            '<path d="M68 91 L80 87 L86 95 L91 82" fill="none" stroke="#f3f3df" stroke-width="3"/>'
            '<path d="M45 40 L45 79 L40 88 M115 40 L115 89 L121 96" fill="none" stroke="#9b744a" stroke-width="6"/>'
            '<path d="M38 27 L122 27 L122 40 L38 40 Z" fill="#c6aa82"/>'
            '<path d="M40 125 L120 114 L122 126 L42 137 Z" fill="#c6aa82"/>'
            '<path d="M55 119 Q80 94 103 115 Z" fill="#d8ba73" stroke-width="2"/>'
            '<path d="M110 101 L123 107 L114 114 Z" fill="#c5d7cf" stroke-width="2"/>')


def basket_front():
    return ('<path d="M18 99 Q80 112 142 99 L128 139 Q80 153 32 139 Z" fill="#b98343"/>'
            '<path d="M28 115 Q80 129 132 115 M33 128 Q80 142 128 128 M46 106 L51 142 M68 110 L69 146 M92 110 L91 146 M114 106 L109 142" fill="none" stroke="#7f542d" stroke-width="3"/>'
            '<path d="M18 99 Q80 112 142 99" fill="none" stroke="#efd295" stroke-width="8"/>'
            '<path d="M18 98 Q80 111 142 98" fill="none" stroke-width="2"/>')


def resource(ch, grade):
    body = '<ellipse cx="80" cy="143" rx="59" ry="7" fill="#3b2314" opacity=".13" stroke="none"/>'
    if grade == 1:
        return svg(body + fragment(ch))
    if grade == 2:
        return svg(body + resource_unit(ch,80,77,1.02))
    if grade == 3:
        layout = [(48,75,.79,-7),(113,83,.79,7)]
    elif grade == 4:
        layout = [(46,43,.54,-5),(112,43,.54,5),(46,109,.54,-5),(112,109,.54,5)]
    else:
        layout = [(80,38,.44,0),(52,65,.46,-9),(106,65,.46,9),
                  (29,101,.46,-15),(63,108,.48,-5),(98,108,.48,5),(132,101,.46,15)]
    if grade == 6:
        body += '<path d="M30 106 C13 39 39 16 80 16 C121 16 147 39 130 106" fill="none" stroke="#795129" stroke-width="11"/>'
        body += '<path d="M30 106 C13 39 39 16 80 16 C121 16 147 39 130 106" fill="none" stroke="#e4c184" stroke-width="6"/>'
        layout = [(x,y-7,s,a) for x,y,s,a in layout]
    body += ''.join(resource_unit(ch,*position) for position in layout)
    if grade == 6: body += basket_front()
    return svg(body)


def chest(ch, grade):
    themes = {'chest':('#b78346','#f0ce89'), 'energybox':('#d36c32','#ffd75b'),
              'premiumbox':('#8056a6','#e6b946'), 'choice':('#4c9f96','#b2e0bd')}
    color, trim = themes[ch]
    body = '<ellipse cx="80" cy="142" rx="63" ry="9" fill="#3b2314" opacity=".17" stroke="none"/>'
    if grade >= 4:
        body += star(21,31,10)+star(139,33,8)
    body += (f'<path d="M22 69 L138 69 L135 129 Q80 143 25 129 Z" fill="{color}"/>'
             f'<path d="M21 68 Q19 25 80 24 Q141 25 139 68 Z" fill="{color}"/>'
             f'<path d="M32 55 Q39 34 80 33 Q119 34 128 55" fill="none" stroke="{trim}" stroke-width="6"/>'
             '<path d="M31 88 Q80 100 129 88 M31 112 Q80 123 129 112" fill="none" stroke="#3b2314" stroke-opacity=".3" stroke-width="3"/>')
    if ch == 'chest':
        body += '<path d="M39 74 L44 130 M57 78 L60 134 M80 80 L80 136 M103 78 L100 134 M121 74 L116 130" stroke="#704923" stroke-width="3"/>'
    if grade >= 2:
        body += f'<path d="M43 34 L47 129 M117 34 L113 129" stroke="{trim}" stroke-width="10"/>'
    if grade == 5:
        body += '<path d="M48 28 L42 10 L63 20 L80 5 L97 20 L118 10 L112 28 Z" fill="#ffd64b"/>'
    body += f'<path d="M19 66 Q80 79 141 66 L141 77 Q80 91 19 77 Z" fill="{trim}"/>'
    body += '<path d="M56 88 Q80 82 104 88 L101 122 Q80 131 59 122 Z" fill="#fff0ce"/>'
    if ch == 'energybox': body += bolt(80,105,.30)
    elif ch == 'premiumbox':
        body += bolt(70,104,.24)
        body += '<path d="M88 93 L100 104 L94 117 L82 112 L81 101 Z" fill="#eea036" stroke-width="3"/>'
    elif ch == 'choice':
        body += '<path d="M66 96 L74 104 L66 112 L58 104 Z" fill="#e36b53" stroke-width="2"/><circle cx="82" cy="104" r="7" fill="#ffd64b" stroke-width="2"/><path d="M98 97 L105 111 L91 111 Z" fill="#83b84a" stroke-width="2"/>'
    else:
        body += '<path d="M80 91 L95 105 L80 120 L65 105 Z" fill="#72b449" stroke-width="3"/>'
    # One to five bone beads make the grade visible at chessboard size.
    for i in range(grade):
        x = 80 + (i-(grade-1)/2)*13
        body += f'<circle cx="{x}" cy="135" r="4.5" fill="#fff5d8" stroke-width="2"/>'
    return svg(body)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # 体力/不拿拿/琥珀/沙漏改由 scripts/Art.gd 的 _currency 绘制，烘焙成 PNG，这里不再生成 SVG
    for ch in ('energybox','premiumbox','chest','choice'):
        for grade in range(1,6): (OUT/f'{ch}_{grade}.svg').write_text(chest(ch, grade))
    # Existing UI art paths share the same new energy/choice appearance.
    (ROOT/'assets/ui/energy_chest.svg').write_text(chest('energybox',1))
    (ROOT/'assets/ui/choice_chest.svg').write_text(chest('choice',1))
    import sys
    if '--board-sprites' in sys.argv:
        import cairosvg
        for name, w, h, color in [('board_bolt',16,18,'#ffd23f'), ('board_bolt_boost',16,18,'#b45cff'),
                                   ('board_boost_off',36,42,'#ffd23f'), ('board_boost_on',36,42,'#b45cff')]:
            width, height = w+10, h+10
            pts = [(0.22,-.5),(-.5,.06),(-.05,.03),(-.24,.5),(.5,-.12),(.06,-.08),(.37,-.5)]
            points = ' '.join(f'{width/2+x*(w-2):.2f},{height/2+y*(h-2):.2f}' for x,y in pts)
            body = f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}"><polygon points="{points}" fill="{color}" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/></svg>'
            for frame in range(4):
                cairosvg.svg2png(bytestring=body.encode(),write_to=str(ROOT/f'assets/sprites/png/{name}_{frame}.png'))


if __name__ == '__main__':
    main()
