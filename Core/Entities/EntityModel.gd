# ==============================================================================
# OWNWORLD — ENTITY MODEL
# File: res://Core/Entities/EntityModel.gd
# Base Class: RefCounted (class_name EntityModel)
#
# Responsibility: Pure data model representing core spatial, classification,
# and lock states of an entity decoupled from scene-tree Area2D nodes.
# ==============================================================================

class_name EntityModel
extends RefCounted

const CURRENT_SCHEMA_VERSION: int = 2

var id: String = ""
var display_name: String = "Item"
var entity_type: Types.EntityType = Types.EntityType.PROP
var state: Types.EntityState = Types.EntityState.IDLE

var locked: bool = false
var flipped_horizontally: bool = false
var scale_value: float = 1.0
var base_scale: float = 1.0

var wall_mounted: bool = false
var can_float: bool = false
var floor_decor: bool = false


func configure(entity_id: String, name_value: String, type_value: Types.EntityType) -> void:
	id = entity_id.strip_edges()
	display_name = name_value.strip_edges()
	entity_type = type_value


func set_state(new_state: Types.EntityState) -> bool:
	if state == new_state:
		return false
	state = new_state
	return true


func to_dict() -> Dictionary:
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"id": id,
		"display_name": display_name,
		"entity_type": int(entity_type),
		"state": int(state),
		"is_locked": locked,
		"is_flipped_h": flipped_horizontally,
		"entity_scale": scale_value,
		"base_entity_scale": base_scale,
		"is_wall_mounted": wall_mounted,
		"can_float": can_float,
		"is_floor_decor": floor_decor
	}


func from_dict(data: Dictionary) -> void:
	id = str(data.get("id", id)).strip_edges()
	display_name = str(data.get("display_name", display_name)).strip_edges()
	entity_type = int(data.get("entity_type", int(Types.EntityType.PROP))) as Types.EntityType
	state = int(data.get("state", int(Types.EntityState.IDLE))) as Types.EntityState
	locked = bool(data.get("is_locked", false))
	flipped_horizontally = bool(data.get("is_flipped_h", false))
	scale_value = clampf(float(data.get("entity_scale", 1.0)), 0.05, 4.0)
	base_scale = clampf(float(data.get("base_entity_scale", scale_value)), 0.05, 4.0)
	wall_mounted = bool(data.get("is_wall_mounted", false))
	can_float = bool(data.get("can_float", false))
	floor_decor = bool(data.get("is_floor_decor", false))
