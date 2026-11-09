extends SceneTree
## Trusted worker. Input paths are server-owned temporary files, never shell commands.
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var replay = root.get_node("Replay")
	var game = root.get_node("G")
	var input := ""
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--input="): input = arg.trim_prefix("--input=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var request = JSON.parse_string(FileAccess.get_file_as_string(input))
	var result := {"ok": false, "error": "bad_input"}
	if request is Dictionary:
		replay.active = true; replay.worker = true; replay.executing = true
		if request.get("mode", "") == "new":
			replay.clock = int(request["at"])
			game.random_seed = str(request["seed"]); game.random_streams = {}
			replay.meta = {"allow_gm": bool(request.get("allow_gm", false))}; replay.seq = 0
			game.new_game(); game.player_id = str(request["player"])
			replay.advance()
		else:
			replay.restore(request["data"])
		replay.executing = false
		var valid := true
		for op in request.get("ops", []):
			if int(op["seq"]) != replay.seq + 1 or int(op["at"]) < replay.clock:
				valid = false; result = {"ok": false, "error": "sequence"}; break
			var r = replay.perform(str(op["name"]), op.get("args", {}), int(op["at"]))
			if r is Dictionary and (r.has("error") or r.get("ok", true) == false):
				valid = false; result = {"ok": false, "error": "illegal_operation", "message": str(r), "seq": op["seq"]}; break
			# A redundant idle tick is legal, but must not advance an invented seq.
			if replay.seq != int(op["seq"]):
				valid = false; result = {"ok": false, "error": "redundant_tick"}; break
		if valid:
			result = {"ok": true, "data": replay.snapshot(), "hash": replay.digest(), "rules": replay.rules_hash(), "seq": replay.seq, "engine": Engine.get_version_info()["string"]}
	var f := FileAccess.open(output, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(result)); f.close()
	quit(0)
