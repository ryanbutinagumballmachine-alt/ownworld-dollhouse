# ==============================================================================
# OWNWORLD — CONTAINER CAPABILITY
# File: res://Core/Entities/Capabilities/EntityContainerCapability.gd
# ==============================================================================

class_name EntityContainerCapability
extends EntityCapability

signal opened
signal closed
signal item_stored(item_data: Dictionary)
signal item_unpacked(item_data: Dictionary)

var is_open: bool = false
var stored_items: Array[Dictionary] = []


func get_component_key() -> StringName:
	return &"EntityContainerCapability"


func can_store(item: OwnEntity) -> bool:
	if entity == null or item == null or not is_instance_valid(item):
		return false
	if item == entity or item.entity_type != Types.EntityType.PROP:
		return false
	return true


func store_item(item: OwnEntity) -> bool:
	if not can_store(item):
		return false

	var serialized_item: Dictionary = item.to_dict().duplicate(true)
	stored_items.append(serialized_item)
	item_stored.emit(serialized_item)
	EventBus.entity_state_changed.emit(entity.entity_id)
	return true


func unpack_item(index: int) -> Dictionary:
	if index < 0 or index >= stored_items.size():
		return {}

	var item_data: Dictionary = stored_items[index].duplicate(true)
	stored_items.remove_at(index)
	item_unpacked.emit(item_data)
	EventBus.entity_state_changed.emit(entity.entity_id)
	return item_data


func clear() -> void:
	if stored_items.is_empty():
		return
	stored_items.clear()
	EventBus.entity_state_changed.emit(entity.entity_id)


func get_item_count() -> int: return stored_items.size()

func get_item(index: int) -> Dictionary:
	if index < 0 or index >= stored_items.size():
		return {}
	return stored_items[index].duplicate(true)


func set_open(open: bool) -> void:
	if is_open == open:
		return
	is_open = open
	if is_open:
		opened.emit()
	else:
		closed.emit()
	EventBus.entity_state_changed.emit(entity.entity_id)


func toggle_open() -> void:
	set_open(not is_open)


func serialize() -> Dictionary:
	return {
		"is_open": is_open,
		"stored_items": stored_items.duplicate(true)
	}


func deserialize(data: Dictionary) -> void:
	is_open = bool(data.get("is_open", false))
	stored_items.clear()
	var raw_items: Variant = data.get("stored_items", [])
	if raw_items is Array:
		for value: Variant in (raw_items as Array):
			if value is Dictionary:
				stored_items.append((value as Dictionary).duplicate(true))
