extends Node2D
## 把若干条物品链画成一张对照图（现场绘制，不读 PNG）。
var chains: Array = []
var pick: Array = []
var cell := 150.0
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("f3e6cc"))
	var font := ThemeDB.fallback_font
	Art.force_live = true
	for r in chains.size():
		var ch: String = chains[r]
		var items: Array = Data.CHAINS[ch]["items"]
		var col := 0
		for i in items.size():
			if not pick.is_empty() and not pick.has(i + 1):
				continue
			col += 1
			var c := Vector2(cell * 0.5 + float(col - 1) * cell, cell * 0.5 + float(r) * (cell + 24.0))
			Art.item(self, "%s_%d" % [ch, i + 1], c, cell * 0.62, true)
			draw_string(font, c + Vector2(-cell * 0.5, cell * 0.5 + 14), "%d %s" % [i + 1, items[i]], HORIZONTAL_ALIGNMENT_CENTER, cell, 18, Color.BLACK)
	Art.force_live = false
