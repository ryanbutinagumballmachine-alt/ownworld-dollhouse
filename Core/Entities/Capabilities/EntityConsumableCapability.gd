# ==============================================================================
# OWNWORLD — CONSUMABLE CAPABILITY
# File: res://Core/Entities/Capabilities/EntityConsumableCapability.gd
# ==============================================================================

class_name EntityConsumableCapability
extends EntityCapability

signal bite_taken(remaining_bites: int)
signal consumed

var is_drink: bool = false
var is_infinite: bool = false
var max_bites: int = 3
var remaining_bites: int = 3


func get_component_key() -> StringName:
	return &"EntityConsumableCapability"


func configure(bite_count: int, drink: bool = false, infinite: bool = false) -> void:
	max_bites = maxi(bite_count, 1)
	remaining_bites = max_bites
	is_drink = drink
	is_infinite = infinite


func can_consume() -> bool:
	return is_infinite or remaining_bites > 0


func consume_one() -> bool:
	if is_infinite:
		bite_taken.emit(remaining_bites)
		return false

	if remaining_bites <= 0:
		return true

	remaining_bites -= 1
	bite_taken.emit(remaining_bites)
	EventBus.entity_state_changed.emit(entity.entity_id)

	if remaining_bites <= 0:
		consumed.emit()
		return true

	return false


func refill() -> void:
	remaining_bites = max_bites
	EventBus.entity_state_changed.emit(entity.entity_id)


func serialize() -> Dictionary:
	return {
		"is_drink": is_drink,
		"is_infinite": is_infinite,
		"max_bites": max_bites,
		"remaining_bites": remaining_bites
	}


func deserialize(data: Dictionary) -> void:
	is_drink = bool(data.get("is_drink", false))
	is_infinite = bool(data.get("is_infinite", false))
	max_bites = maxi(int(data.get("max_bites", 3)), 1)
	remaining_bites = clampi(int(data.get("remaining_bites", max_bites)), 0, max_bites)
