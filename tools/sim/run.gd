extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var script = load("res://tools/sim/PlayerBot.gd")
	if script == null or not script.can_instantiate():
		quit(2)
		return
	var bot = script.new()
	root.add_child(bot)
	var code: int = await bot.run()
	quit(code)
