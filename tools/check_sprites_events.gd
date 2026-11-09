extends SceneTree
## 对照：左边原始现场绘制，右边预生成贴图。godot --path . --script tools/check_sprites_events.gd
## 同时把改过的活动界面脚本都加载一遍，确认没有语法错误。
const FILES := ["PassPopup", "DuelPopup", "DuelEntry", "UfoPopup", "UfoEntry", "MergeEventPopup", "MergeEventEntry", "RacePopup", "RaceEntry",
	"RankPopup", "SevenDayPopup", "SevenDayEntry", "SpreePopup", "SpreeCard", "EnergyOfferPopup", "GiftChainPopup", "GiftChainCard", "EventEntryArt"]

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	await process_frame
	var bad := 0
	for f in FILES:
		var s = load("res://scripts/ui/%s.gd" % f)
		if s == null or not s.can_instantiate():
			push_error("脚本加载失败 " + f)
			bad += 1
	print("SCRIPTS_OK" if bad == 0 else "SCRIPTS_BAD %d" % bad)
	var vp := SubViewport.new()
	vp.size = Vector2i(1400, 1500)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var d = load("res://scripts/ui/DrawBox.gd").new()
	d.boil = false
	d.size = Vector2(1400, 1500)
	var ds = load("res://tools/check_sprites_events_draw.gd")
	if ds == null:
		quit(1)
		return
	d.painter = ds.paint
	vp.add_child(d)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_shots/sprites"))
	vp.get_texture().get_image().save_png("res://_shots/sprites/events_compare.png")
	print("SAVED")
	quit()
