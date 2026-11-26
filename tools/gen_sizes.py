"""量 7 条产线生产器每一级的原始大小，按逐级递增的目标算出缩放，写进 scripts/art/PAGen.gd 的 FIT。

python tools/gen_sizes.py --godot D:/.../Godot.exe
目标大小 = 0.5 × 最长边 + 0.5 × √(宽×高)，占格子的比例从 1 级 LO 线性涨到 10 级 HI；最长边不超过 CAP。
"""
import argparse, json, subprocess, tempfile
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
LINES = ["food", "wood", "tool", "hunt", "cloth", "fish", "pot"]
CELL = 300
LO, HI, CAP = 0.52, 0.86, 0.94
## 量的时候画多大（和 tools/gen_sheet.gd 里 --measure 用的一致）
MEASURE_K = 0.36
## 个别等级按观感再调一点：目标大小乘这个系数
ADJUST = {("tool", 7): 0.85, ("tool", 8): 1.04, ("hunt", 8): 0.92, ("hunt", 9): 1.04, ("fish", 1): 0.94, ("fish", 2): 1.1, ("pot", 7): 0.86, ("pot", 8): 1.04, ("pot", 9): 1.2, ("pot", 10): 1.1}

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--godot", required=True); a = ap.parse_args()
    out = Path(tempfile.mkdtemp()) / "raw.png"
    subprocess.run([a.godot, "--path", str(ROOT), "res://tools/gen_sheet.tscn", "--", f"--out={out}", f"--cell={CELL}", "--measure"], check=True, capture_output=True, timeout=300)
    im = Image.open(out).convert("RGBA")
    unit = CELL * MEASURE_K / 100.0
    up = 0.56 / MEASURE_K
    fit = {}
    for r, line in enumerate(LINES):
        rows = []
        for lv in range(1, 11):
            box = im.crop(((lv - 1) * CELL, r * CELL, lv * CELL, (r + 1) * CELL)).getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
            x0, y0, x1, y1 = box
            w, h = (x1 - x0) / CELL * up, (y1 - y0) / CELL * up
            m = 0.5 * max(w, h) + 0.5 * (w * h) ** 0.5
            target = LO + (HI - LO) * (lv - 1) / 9
            target *= ADJUST.get((line, lv), 1.0)
            k = min(target / m, CAP / max(w, h))
            cx = ((x0 + x1) / 2 - CELL / 2) / unit
            cy = ((y0 + y1) / 2 - CELL / 2) / unit
            rows.append([round(k, 3), round(cx, 1), round(cy, 1)])
        fit[line] = rows
    body = "const FIT := {\n" + "".join(f'\t"{l}": {json.dumps(v)},\n' for l, v in fit.items()) + "}"
    p = ROOT / "scripts/art/PAGen.gd"
    src = p.read_text(encoding="utf-8")
    i = src.index("const FIT := {")
    j = i + len("const FIT := {}") if src.startswith("const FIT := {}", i) else src.index("\n}\n", i) + 2
    src = src[:i] + body + src[j:]
    p.write_text(src, encoding="utf-8")
    print(json.dumps(fit))

if __name__ == "__main__":
    main()
