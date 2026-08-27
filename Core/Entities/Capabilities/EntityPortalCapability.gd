# ==============================================================================
# OWNWORLD — PORTAL CAPABILITY
# File: res://Core/Entities/Capabilities/EntityPortalCapability.gd
# Base Class: EntityCapability (class_name EntityPortalCapability)
#
# Responsibility: Manages door transit destinations, traveler eligibility checks,
# and room change request dispatches with passenger hierarchy bundles.
# ==============================================================================

class_name EntityPortalCapability
extends EntityCapability

signal travel_requested(target_room_id: String, traveler: OwnEntity, traveler_data: Dictionary)

var target_room_id: String = ""
var portal_name: String = ""
var door_open: bool = false


func get_component_key() -> StringName:
	return &"EntityPortalCapability"


func configure(destination_room_id: String, name_value: String = "") -> void:
	target_room_id = destination_room_id.strip_edges()
	if not name_value.strip_edges().is_empty():
		portal_name = name_value.strip_edges()


func can_receive_traveler(traveler: OwnEntity) -> bool:
	if entity == null or not is_instance_valid(entity) or traveler == null or not is_instance_valid(traveler):
		return false
	if target_room_id.is_empty() or target_room_id == AppState.room_id or traveler.entity_type != Types.EntityType.CHARACTER:
		return false
	return true


func request_travel(traveler: OwnEntity) -> bool:
	if not can_receive_traveler(traveler):
		return false

	var bundle: Array[Dictionary] = traveler.get_full_hierarchy_bundle()
	var traveler_data: Dictionary = {
		"bundle": bundle,
		"source": "portal",
		"portal_entity_id": entity.entity_id
	}

	travel_requested.emit(target_room_id, traveler, traveler_data)
	EventBus.room_change_requested.emit(target_room_id, traveler_data)
	return true


func set_door_open(open: bool) -> void:
	if door_open == open:
		return
	door_open = open
	if entity != null and is_instance_valid(entity):
		EventBus.entity_state_changed.emit(entity.entity_id)


func serialize() -> Dictionary:
	return {
		"target_room_id": target_room_id,
		"portal_name": portal_name,
		"is_door_open": door_open
	}


func deserialize(data: Dictionary) -> void:
	target_room_id = str(data.get("target_room_id", "")).strip_edges()
	portal_name = str(data.get("portal_name", "")).strip_edges()
	door_open = bool(data.get("is_door_open", false))
