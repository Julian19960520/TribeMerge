extends RefCounted
## A module receives its state and services explicitly; no singleton or transport lookup.
var _owner: WeakRef
var context:
	get: return _owner.get_ref()
var state:
	get: return context.state

func _init(owner: RefCounted) -> void:
	_owner = weakref(owner)
