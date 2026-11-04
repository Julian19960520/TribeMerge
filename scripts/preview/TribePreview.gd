extends Control
## 部落部件预览：第 1 页全部部件，第 2、3 页村庄，第 4 页火种 / 贝币 / 琥珀 / 沙漏 6 级。点一下翻页。
## 运行「部件预览.bat」打开；加参数 --tribe-shots <目录> 会把两页截图存进去后退出。

const W := 1640
const H := 1000
var page := 0

func _ready() -> void:
	var win := get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = Vector2i(W, H)
	win.move_to_center()
	win.title = "部落部件预览"
	size = Vector2(W, H)
	G.boil_tick.connect(queue_redraw)
	var args := OS.get_cmdline_user_args()
	var at := args.find("--tribe-shots")
	if at >= 0:
		var dir := args[at + 1] if at + 1 < args.size() else ProjectSettings.globalize_path("res://shots")
		_shots.call_deferred(dir)

func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for i in 4:
		page = i
		queue_redraw()
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("tribe_%d.png" % i))
	get_tree().quit()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		page = (page + 1) % 4
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("c8dd9a"))
	if page == 0:
		_parts()
	elif page == 1:
		_villages()
	elif page == 2:
		_closeup()
	else:
		_currency()

func _parts() -> void:
	var cw := W / 12.0
	var ch := H / 4.0
	var n := 0
	for b in Data.BUILDS:
		for p in Data.build_parts(b):
			var col := n % 12
			var row := n / 12
			var r := Rect2(col * cw, row * ch, cw, ch)
			draw_rect(r.grow(-3), Color(1, 1, 1, 0.18))
			var kind := str(p.get("id", ""))
			TribeArt.part(self, kind, Vector2(r.get_center().x, r.end.y - 52), 1.0)
			var f := G.font_body
			var t := "%s %s" % [str(b.get("name", "")), str(p.get("name", ""))]
			draw_string(f, Vector2(r.position.x + 6, r.end.y - 14), t, HORIZONTAL_ALIGNMENT_CENTER, cw - 12, 16, Art.INK)
			n += 1

var _views: Array[SubViewport] = []

func _make_views() -> void:
	var states := []
	var full := {}
	var half := {}
	for b in Data.BUILDS:
		var id := str(b["id"])
		var st := Data.build_stages(b)
		full[id] = st
		half[id] = int(ceil(st / 2.0)) if Data.build_unlock(b) <= 16 else 0
	states.append([full, 99])
	states.append([half, 16])
	states.append([{"fire": 1}, 1])
	for s in states:
		var vp := SubViewport.new()
		vp.size = Vector2i(720, 1480)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var builds: Dictionary = s[0]
		var lv: int = s[1]
		var d := UI.box(vp, Rect2(0, 0, 720, 1480), func(ci, sz):
			Paint.village(ci, sz, builds, lv)
			for b in Data.BUILDS:
				var tp := TribeArt.tag_at(str(b["id"]))
				ci.draw_rect(Rect2(tp - Vector2(74, 26), Vector2(148, 52)), Color(0.45, 0.25, 0.1, 0.85))
				ci.draw_string(G.font_body, tp + Vector2(-74, 8), str(b["name"]), HORIZONTAL_ALIGNMENT_CENTER, 148, 22, Color.WHITE))
		_views.append(vp)

func _villages() -> void:
	if _views.is_empty():
		_make_views()
		queue_redraw.call_deferred()
	for i in _views.size():
		draw_texture_rect(_views[i].get_texture(), Rect2(20 + i * 540, 4, 720 * 0.665, 1480 * 0.665), false)

## 1:1 看清楚：左边全建好，右边建了一半
func _closeup() -> void:
	if _views.is_empty():
		_make_views()
		queue_redraw.call_deferred()
	for i in 2:
		draw_texture_rect_region(_views[i].get_texture(), Rect2(20 + i * 800, 0, 720, 1000), Rect2(0, 480, 720, 1000))

func _currency() -> void:
	var rows := ["fire", "shell", "amber", "sand"]
	for r in rows.size():
		for lv in range(1, 7):
			var id := "%s_%d" % [rows[r], lv]
			var c := Vector2(150 + (lv - 1) * 250, 130 + r * 240)
			Art.force_live = true
			Art.item(self, id, c, 150)
			Art.force_live = false
			draw_string(G.font_body, c + Vector2(-110, 106), "%s  Lv.%d  得 %d" % [Data.name_of(id), lv, Data.value_of(id)], HORIZONTAL_ALIGNMENT_CENTER, 220, 20, Art.INK)
