extends "res://scripts/domain/RuleModule.gd"
## Clock-aligned energy, daily rollover, shop periods and pass seasons.

func _regen() -> void:
	if state.energy >= state.MAX_ENERGY:
		state.energy_stamp = context.now()
		state.changed.emit()
		return
	var n = int((context.now() - state.energy_stamp) / state.REGEN_SEC)
	if n > 0:
		state.energy = min(state.MAX_ENERGY, state.energy + n)
		state.energy_stamp += n * state.REGEN_SEC
		state.dirty()
	state.changed.emit()

func energy_left() -> int:
	if state.energy >= state.MAX_ENERGY:
		return 0
	return int(state.REGEN_SEC - fmod(context.now() - state.energy_stamp, state.REGEN_SEC))

func energy_full_left() -> int:
	if state.energy >= state.MAX_ENERGY:
		return 0
	return energy_left() + (state.MAX_ENERGY - state.energy - 1) * state.REGEN_SEC

func secs_to_midnight() -> int:
	return 86400 - posmod(int(context.now()) + 28800, 86400)

func today() -> String:
	return Time.get_date_string_from_unix_time(int(context.now()) + 28800)

func shell_period_now() -> String:
	return str(int((context.now() + 8 * 3600) / float(Data.STORE_SHELL_HOURS * 3600)))

func shell_secs_left() -> int:
	var span = Data.STORE_SHELL_HOURS * 3600
	return span - int(context.now() + 8 * 3600) % span

func check_shell_period() -> void:
	var p = shell_period_now()
	if p != state.shell_period:
		state.shell_period = p
		state.shell_bought = {}

func _pass_season_span() -> int:
	return maxi(1, int(Data.PASS_SEASON.get("days", 35))) * 86400

func _pass_season_offset() -> int:
	var start = str(Data.PASS_SEASON.get("start", "2026-11-02"))
	return int(context.now()) + 8 * 3600 - int(Time.get_unix_time_from_datetime_string(start + "T00:00:00"))

func pass_season_now() -> String:
	return str(floori(float(_pass_season_offset()) / float(_pass_season_span())))

func pass_secs_left() -> int:
	return _pass_season_span() - posmod(_pass_season_offset(), _pass_season_span())

func check_pass_season() -> void:
	var s = pass_season_now()
	if s == state.pass_season:
		return
	state.pass_season = s
	state.pass_pts = 0
	state.pass_tier = 0
	state.pass_free = []
	state.pass_prem = []
	state.pass_super = []
	state.pass_endless = 0
	state.pass_super_bonus = false
	state.dirty()
	state.changed.emit()

func event_left() -> int:
	return 35 * 86400 + 15 * 3600 - int(fmod(context.now(), 86400.0))

func _check_day() -> void:
	check_pass_season()
	context.login()
	# 等云存档拿到服务器时间（或确认连不上）再判断，免得改了本机时间先把每日次数清掉
	if not context.clock_ready(): return
	var d: String = today()
	if d != state.deals_day:
		state.deals_day = d
		state.deals_bought = {}
		state.hot_bought = {}
		state.hot_revision = 0
		state.dirty()
		state.energy_buys = 0

