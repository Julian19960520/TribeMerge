extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var replay = root.get_node("Replay")
	var g = root.get_node("G")
	var cloud = root.get_node("Cloud")
	replay.set_process(false); g.set_process(false); cloud.set_process(false)
	var input := ""; var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--input="): input = arg.trim_prefix("--input=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if input == "" or output == "": quit(1); return
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(input))
	replay.restore(fixture); replay.authorized = true; replay.pending=[]
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var bs = main.board_screen
	await bs._on_activate(0) # free energy producer
	await bs._on_activate(1) # ordinary producer
	await bs._on_activate(10) # collect resource
	await bs._on_activate(11) # open and consume a chest
	var before: String = replay.digest()
	await bs._on_activate(12) # opening the pack modal must not burn a pack
	if replay.digest()!=before: push_error("pack modal consumed a card pack before opening")
	var popup = main.popup_layer.get_child(0)
	popup.on_tap.call()
	await process_frame
	await process_frame
	for cell in g.board.size():
		if g.is_free(cell) and Data.type_of(g.cell_id(cell)) == "item":
			bs.board.select(cell)
			bs._on_delete()
			bs.board.select(0) # finalizes refund without recursive change signals
			break
	var ops := []
	for entry in replay.pending:
		var copy: Dictionary=entry.duplicate(true); copy.erase("hash"); ops.append(copy)
	var f:=FileAccess.open(output,FileAccess.WRITE)
	f.store_string(JSON.stringify({"hash":replay.digest(),"data":replay.snapshot(),"ops":ops}))
	f.close()
	main.free(); g.main=null
	quit(0)
