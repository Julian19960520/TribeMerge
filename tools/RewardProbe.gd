extends "res://scripts/Main.gd"
## Test fixture: records the production dispatcher's actual animation endpoints.
var flights: Array = []
func fly(id: String, from: Vector2, to: Vector2, cb: Callable = Callable(), _s: float = 70.0) -> void:
	flights.append({"id": id, "from": from, "to": to})
	if cb.is_valid(): cb.call()
