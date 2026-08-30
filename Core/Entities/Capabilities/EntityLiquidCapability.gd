# ==============================================================================
# OWNWORLD — LIQUID CAPABILITY
# File: res://Core/Entities/Capabilities/EntityLiquidCapability.gd
# Base Class: EntityCapability (class_name EntityLiquidCapability)
#
# Responsibility: Discrete liquid volume tracking, fill levels, source emitters,
# and liquid transfer validation between containers and sinks.
# ==============================================================================

class_name EntityLiquidCapability
extends EntityCapability

signal fill_changed(fill_level: int)

const MAX_FILL_LEVEL: int = 2

var is_source: bool = false
var fill_level: int = 0


func get_component_key() -> StringName:
	return &"EntityLiquidCapability"


func configure(source: bool, initial_fill: int = 0) -> void:
	is_source = source
	fill_level = clampi(initial_fill, 0, MAX_FILL_LEVEL)


func can_pour() -> bool:
	return is_source or fill_level > 0


func can_receive() -> bool:
	return fill_level < MAX_FILL_LEVEL


func fill_one() -> bool:
	if not can_receive():
		return false
	fill_level += 1
	fill_changed.emit(fill_level)
	if is_instance_valid(entity):
		EventBus.entity_state_changed.emit(entity.entity_id)
	return true


func consume_one() -> bool:
	if is_source:
		return true
	if fill_level <= 0:
		return false
	fill_level -= 1
	fill_changed.emit(fill_level)
	if is_instance_valid(entity):
		EventBus.entity_state_changed.emit(entity.entity_id)
	return true


func empty() -> void:
	if fill_level == 0:
		return
	fill_level = 0
	fill_changed.emit(fill_level)
	if is_instance_valid(entity):
		EventBus.entity_state_changed.emit(entity.entity_id)


func serialize() -> Dictionary:
	return {
		"is_source": is_source,
		"fill_level": fill_level
	}


func deserialize(data: Dictionary) -> void:
	is_source = bool(data.get("is_source", false))
	fill_level = clampi(int(data.get("fill_level", 0)), 0, MAX_FILL_LEVEL)
