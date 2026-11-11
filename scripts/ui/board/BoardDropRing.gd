extends RefCounted
## A small repeating version of the existing merge burst, never a permanent halo.

const Burst := preload("res://scripts/ui/board/BoardMergeBurst.gd")
const PERIOD := 0.90
const PULSE_TIME := 0.72

var target := -1
var kind := ""
var age := 0.0
var alpha := 0.0

func clear() -> void:
	target = -1
	kind = ""
	age = 0.0
	alpha = 0.0

func tick(delta: float, next_target: int, next_kind: String) -> bool:
	var was_visible := target >= 0
	if next_target >= 0:
		if next_target != target or next_kind != kind:
			clear()
			target = next_target
			kind = next_kind
		age += delta
		alpha = minf(1.0, alpha + delta / 0.12)
	elif target >= 0:
		alpha = maxf(0.0, alpha - delta / 0.10)
		if alpha <= 0.0: clear()
	return was_visible or target >= 0

func paint(ci: CanvasItem, center: Vector2, cell_size: float) -> void:
	if target < 0 or alpha <= 0.0: return
	var pulse := fmod(age, PERIOD)
	if pulse >= PULSE_TIME: return
	var t := pulse / PULSE_TIME
	var seed := float(target) * 2.399 + floorf(age / PERIOD) * 0.53
	Burst.paint(ci, center, t, seed, true, alpha * 0.82, cell_size / 96.0)
