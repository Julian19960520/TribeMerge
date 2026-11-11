extends SceneTree
## Validation worker. Each request replaces all account state before execution.
## The service form keeps the engine warm; the file form serves local checks.
const RESPONSE_PREFIX := "TRIBE_REPLAY_RESPONSE "
const MAX_REQUEST_BYTES := 8 * 1024 * 1024

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var arguments := OS.get_cmdline_user_args()
	for node in root.get_children(): node.set_process(false)
	if "--replay-service" in arguments:
		_service()
		quit(0)
		return
	var input := ""
	var output := ""
	for argument in arguments:
		if argument.begins_with("--input="): input = argument.trim_prefix("--input=")
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if input == "" or output == "":
		quit(2)
		return
	var result := execute(JSON.parse_string(FileAccess.get_file_as_string(input)))
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		quit(3)
		return
	file.store_string(JSON.stringify(result))
	file.flush()
	file.close()
	quit(0)

func _service() -> void:
	while true:
		var line := OS.read_string_from_stdin(MAX_REQUEST_BYTES)
		if line == "": break
		if line.strip_edges() == "": continue
		var request = JSON.parse_string(line)
		if request is Dictionary and request.get("mode", "") == "shutdown": break
		print(RESPONSE_PREFIX + JSON.stringify(execute(request)))

func execute(request) -> Dictionary:
	if not request is Dictionary: return {"ok": false, "error": "bad_input"}
	var replay = root.get_node("Replay")
	var game = root.get_node("G")
	if request.get("mode", "") == "rules":
		return {"ok": true, "rules": replay.rules_hash(), "engine": Engine.get_version_info()["string"]}
	if not request.get("mode", "") in ["new", "load", "replay"]:
		return {"ok": false, "error": "bad_mode"}
	replay.active = true
	replay.worker = true
	replay.authorized = true
	replay.executing = true
	replay.pending = []
	replay.inflight = {}
	replay.base = 0
	replay.seq = 0
	replay.clock = int(request.get("at", 0))
	replay.meta = {}
	game.set_block_signals(true)
	game.clear_presentations()
	game.main = null
	game.simulation_time = -1.0
	game.opened = []
	game.cooked_pop = []
	game.clear_transient()
	if request["mode"] == "new":
		if not request.get("seed") is String or not request.get("player") is String or not request.has("at"):
			return _failed(replay, game, "bad_input")
		game.random_seed = request["seed"]
		game.random_streams = {}
		replay.meta = {"allow_gm": bool(request.get("allow_gm", false))}
		game.new_game()
		game.player_id = request["player"]
		replay.advance()
	else:
		if not request.get("data") is Dictionary or not replay.restore(request["data"]):
			return _failed(replay, game, "bad_snapshot")
	replay.executing = false
	var operations = request.get("ops", [])
	if not operations is Array or operations.size() > 256:
		return _failed(replay, game, "bad_operations")
	for operation in operations:
		if not operation is Dictionary or not operation.has_all(["seq", "at", "name", "args"]) or not operation["args"] is Dictionary:
			return _failed(replay, game, "bad_operation")
		if int(operation["seq"]) != replay.seq + 1 or int(operation["at"]) < replay.clock:
			return _failed(replay, game, "sequence")
		var result = replay.perform(str(operation["name"]), operation["args"], int(operation["at"]))
		if replay._failed(result):
			return _failed(replay, game, "illegal_operation", str(result), int(operation["seq"]))
		if replay.seq != int(operation["seq"]):
			return _failed(replay, game, "redundant_tick")
	replay._canonicalize_live()
	var state: Dictionary = replay.snapshot()
	game.clear_presentations()
	game.set_block_signals(false)
	return {"ok": true, "data": state, "hash": JSON.stringify(state).sha256_text(),
		"rules": replay.rules_hash(), "seq": replay.seq, "engine": Engine.get_version_info()["string"]}

func _failed(replay: Node, game: Node, error: String, message := "", sequence := -1) -> Dictionary:
	replay.executing = false
	game.clear_presentations()
	game.set_block_signals(false)
	return {"ok": false, "error": error, "message": message, "seq": sequence}
