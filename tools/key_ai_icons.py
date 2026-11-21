"""把品红底的合成物生图抠成 256 透明图标。"""
from collections import deque
from pathlib import Path

from PIL import Image

SRC = Path(r"C:\Users\MSN\.cursor\projects\c-Users-MSN-Desktop-TribeMerge\assets")
DST = Path(r"C:\Users\MSN\Desktop\TribeMerge\assets\items\ai")
SIDE = 256
FIT = 168


def is_bg(r: int, g: int, b: int) -> bool:
	if g > 70 or r < 110 or b < 80:
		return False
	if b < r * 0.40:
		return False
	return (r + b) * 0.5 - g > 60


def key(im: Image.Image) -> Image.Image:
	im = im.convert("RGBA")
	w, h = im.size
	pix = im.load()
	seen = bytearray(w * h)
	q = deque()

	def push(x: int, y: int) -> None:
		i = y * w + x
		if seen[i]:
			return
		r, g, b, _a = pix[x, y]
		if not is_bg(r, g, b):
			return
		seen[i] = 1
		q.append((x, y))

	for x in range(w):
		push(x, 0)
		push(x, h - 1)
	for y in range(h):
		push(0, y)
		push(w - 1, y)
	while q:
		x, y = q.popleft()
		r, g, b, _a = pix[x, y]
		pix[x, y] = (r, g, b, 0)
		for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
			if 0 <= nx < w and 0 <= ny < h:
				push(nx, ny)
	for _ in range(3):
		kill = []
		for y in range(h):
			for x in range(w):
				r, g, b, a = pix[x, y]
				if a == 0 or not is_bg(r, g, b):
					continue
				if x == 0 or y == 0 or x == w - 1 or y == h - 1 or pix[x - 1, y][3] == 0 or pix[x + 1, y][3] == 0 or pix[x, y - 1][3] == 0 or pix[x, y + 1][3] == 0:
					kill.append((x, y))
		for x, y in kill:
			r, g, b, _a = pix[x, y]
			pix[x, y] = (r, g, b, 0)
	return im


def fit(im: Image.Image) -> Image.Image:
	bbox = im.getbbox()
	if bbox is None:
		return Image.new("RGBA", (SIDE, SIDE), (0, 0, 0, 0))
	crop = im.crop(bbox)
	cw, ch = crop.size
	scale = FIT / max(cw, ch)
	nw, nh = max(1, int(cw * scale)), max(1, int(ch * scale))
	crop = crop.resize((nw, nh), Image.Resampling.LANCZOS)
	out = Image.new("RGBA", (SIDE, SIDE), (0, 0, 0, 0))
	out.paste(crop, ((SIDE - nw) // 2, (SIDE - nh) // 2), crop)
	return out


def main() -> None:
	DST.mkdir(parents=True, exist_ok=True)
	for n in range(1, 19):
		src = SRC / f"fruitplate_{n}.jpg"
		out = fit(key(Image.open(src)))
		path = DST / f"fruitplate_{n}.png"
		out.save(path)
		print(path.name, out.getbbox())


if __name__ == "__main__":
	main()
