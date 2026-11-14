class_name SettingsPopups
extends RefCounted
const Layout := preload("res://scripts/config/board_layout.gd")
const PS := preload("res://scripts/sprites/popups.gd")

static func settings() -> PopupBase:
	var p := PopupBase.new()
	var r := Rect2(46, 300, 628, 820)
	Popups.frame(p, r, TextCatalog.source("ui.settingspopups.df3d58c7d84b"), Art.TEAL)
	var keys := ["music", "sound", "vibrate", "hint", "boil"]
	var names := [TextCatalog.source("ui.settingspopups.db9514212493"), TextCatalog.source("ui.settingspopups.5e9d80d0e3c3"), TextCatalog.source("ui.settingspopups.4908952d86aa"), TextCatalog.source("ui.settingspopups.f56c6c82203b"), TextCatalog.source("ui.settingspopups.68e5785b7348")]
	for k in keys.size():
		var key: String = keys[k]
		var x := 80.0 + k * 116.0
		var b := UI.btn(p.box, Rect2(x, r.position.y + 76, 96, 96), "", "teal" if G.settings.get(key, true) else "grey", Callable())
		b.is_round = true
		if key == "boil":
			# 没有现成小图标，用字代替
			b.text = TextCatalog.resolve(TextCatalog.source("ui.settingspopups.c553cd300518"))
			b.font_size = 40
		else:
			b.glyph = key
		UI.lbl(p.box, names[k], Rect2(x - 12, r.position.y + 176, 120, 34), 22, Color("6b5640"))
		b.pressed.connect(func():
			var on: bool = not G.settings.get(key, true)
			if key == "boil":
				G.set_boil(on)
			else:
				G.settings[key] = on
			b.style = "teal" if on else "grey"
			b.queue_redraw()
			G.dirty()
			if key == "music":
				Sfx.refresh_music())
	var labels := [[TextCatalog.source("ui.settingspopups.c044f887b35d"), "chat"], [TextCatalog.source("ui.settingspopups.4039a65eb96b"), "globe"]]
	for k in 2:
		var b := UI.btn(p.box, Rect2(106, r.position.y + 250 + k * 130, 508, 88), labels[k][0], "orange", Callable(), 34)
		var g: String = labels[k][1]
		b.extra = func(ci, sz): Paint.glyph(ci, g, Vector2(56, sz.y * 0.5 - 3), 1.6)
		if k == 0:
			b.pressed.connect(func(): G.main.toast(TextCatalog.source("ui.settingspopups.d1fb506c2d8a")))
		else:
			b.pressed.connect(func(): G.main.toast(TextCatalog.source("ui.settingspopups.51cd5550f5d0")))
	var terms := UI.lbl(p.box, TextCatalog.source("ui.settingspopups.0fbc4c4fa48a"), Rect2(260, r.position.y + 590, 200, 40), 24, Color("2f7f8a"))
	UI.box(p.box, Rect2(290, r.position.y + 626, 140, 6), func(ci, sz): ci.draw_line(Vector2(0, 2), Vector2(sz.x, 2), Color("2f7f8a"), 2.0))
	UI.lbl(p.box, TextCatalog.source("ui.settingspopups.8ccb268b39a4") % G.player_id, Rect2(r.position.x, r.position.y + 650, r.size.x, 34), 20, Color("8a7a66"))
	UI.lbl(p.box, "V0.1.0", Rect2(r.position.x, r.position.y + 688, r.size.x, 34), 22, Color("8a7a66"))
	var cfg := UI.btn(p.box, Rect2(r.position.x + 36, r.position.y + 690, 180, 50), TextCatalog.source("ui.settingspopups.e4cc45cd9a21"), "teal", Callable(), 22)
	cfg.title_font = false
	cfg.pressed.connect(func():
		p.close()
		G.main.show_screen("cfg"))
	var acct := UI.btn(p.box, Rect2(106, r.position.y + 510, 508, 70), TextCatalog.source("ui.accountpopup.61eb351d1806"), "teal", Callable(), 30)
	acct.pressed.connect(func():
		p.close()
		load("res://scripts/ui/AccountPopup.gd").open())
	var reset := UI.btn(p.box, Rect2(r.end.x - 170, r.position.y + 690, 130, 50), TextCatalog.source("ui.settingspopups.cc92cb4b8980"), "grey", Callable(), 20)
	reset.title_font = false
	reset.pressed.connect(func():
		G.reset_game()
		G.main.call_deferred("begin_guide"))
	return p

# ---------------------------------------------------------------- 建造

## 部落建造：一个区域的全部部件。已建好的亮着、下一件高亮、之后的是剪影。花不那那建下一件 → 主页播建造动画 → 领奖。
