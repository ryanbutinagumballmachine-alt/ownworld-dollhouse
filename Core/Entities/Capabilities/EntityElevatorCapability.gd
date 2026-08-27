# ==============================================================================
# OWNWORLD — ELEVATOR CAPABILITY
# File: res://Core/Entities/Capabilities/EntityElevatorCapability.gd
# Base Class: EntityPortalCapability (class_name EntityElevatorCapability)
#
# Responsibility: Multi-floor transit keypad selection and cab passenger bundling.
# ==============================================================================

class_name EntityElevatorCapability
extends EntityPortalCapability

signal floor_selection_requested(elevator: OwnEntity, floors: Array[Dictionary])

var floors: Array[Dictionary] = []


func get_component_key() -> StringName:
	return &"EntityElevatorCapability"


func configure_floors(new_floors: Array[Dictionary]) -> void:
	floors.clear()
	for floor_item: Dictionary in new_floors:
		var room_id: String = str(floor_item.get("room_id", "")).strip_edges()
		if not room_id.is_empty():
			floors.append(floor_item.duplicate(true))


func request_floor_selection() -> void:
	if entity != null and is_instance_valid(entity) and not floors.is_empty():
		floor_selection_requested.emit(entity, floors.duplicate(true))


func get_floor(index: int) -> Dictionary:
	if index < 0 or index >= floors.size():
		return {}
	return floors[index].duplicate(true)


func travel_to_floor(index: int) -> bool:
	var floor_item: Dictionary = get_floor(index)
	if floor_item.is_empty() or entity == null or not is_instance_valid(entity):
		return false

	var target_dest_room_id: String = str(floor_item.get("room_id", "")).strip_edges()
	if target_dest_room_id.is_empty():
		return false

	var label: String = str(floor_item.get("label", target_dest_room_id))
	var bundle: Array[Dictionary] = []
	var passengers: Array[OwnEntity] = entity.get_passengers_for_elevator()

	for passenger: OwnEntity in passengers:
		if is_instance_valid(passenger):
			bundle.append_array(passenger.get_full_hierarchy_bundle())

	var traveler_data: Dictionary = {
		"bundle": bundle,
		"arrival_elevator": true,
		"floor_name": label,
		"source": "elevator",
		"elevator_entity_id": entity.entity_id
	}

	EventBus.room_change_requested.emit(target_dest_room_id, traveler_data)
	return true


func serialize() -> Dictionary:
	return {"floors": floors.duplicate(true)}


func deserialize(data: Dictionary) -> void:
	var raw_floors: Variant = data.get("floors", [])
	floors.clear()
	if raw_floors is Array:
		for value: Variant in (raw_floors as Array):
			if value is Dictionary:
				floors.append((value as Dictionary).duplicate(true))
