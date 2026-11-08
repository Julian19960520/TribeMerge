extends SceneTree
## Godot --path . --script tools/sheet/item_sheet.gd -- --chains=basket,fruit,seed [--cell=150] [--pick=3,5] --out=PATH.png
var _started := false
func _process(_d: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false
func _run() -> void:
	var chains := ["basket", "fruit", "seed"]
	var out := "sheet.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--chains="): chains = a.trim_prefix("--chains=").split(",")
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
	var cell := 150.0
	var pick := []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cell="): cell = float(a.trim_prefix("--cell="))
		if a.begins_with("--pick="):
			for x in a.trim_prefix("--pick=").split(","): pick.append(int(x))
	var n := pick.size()
	if pick.is_empty():
		for ch in chains: n = maxi(n, Data.CHAINS[ch]["items"].size())
	var vp := SubViewport.new()
	vp.transparent_bg = false
	vp.size = Vector2i(int(cell * n), int((cell + 24.0) * chains.size()))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var d := Node2D.new()
	d.set_script(load("res://tools/sheet/SheetDraw.gd"))
	d.chains = chains
	d.cell = cell
	d.pick = pick
	vp.add_child(d)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out)
	print("SHEET ", out)
	quit()
