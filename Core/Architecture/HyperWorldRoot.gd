# ==============================================================================
# OWNWORLD — HYPER ARCHITECTURE
# File: res://Core/Architecture/HyperWorldRoot.gd
# Base Class: Node (HyperWorldRoot)
# ==============================================================================

class_name HyperWorldRoot
extends Node

signal world_ready
signal room_change_requested(room_id: String, traveler_data: Dictionary)
signal universe_change_requested(universe_id: String, universe_name: String)

@export var room_root: Node2D
@export var entity_root: Node2D
@export var world_camera: Camera2D

var _initialized: bool = false


func _ready() -> void:
	_validate_dependencies()
	_connect_domain_events()
	_initialized = true
	world_ready.emit()


func _validate_dependencies() -> void:
	assert(room_root != null, "HyperWorldRoot requires RoomRoot.")
	assert(entity_root != null, "HyperWorldRoot requires EntityRoot.")
	assert(world_camera != null, "HyperWorldRoot requires WorldCamera.")


func _connect_domain_events() -> void:
	pass


func request_room_change(room_id: String, traveler_data: Dictionary = {}) -> void:
	if not room_id.is_empty():
		room_change_requested.emit(room_id, traveler_data)


func request_universe_change(universe_id: String, universe_name: String) -> void:
	if not universe_id.is_empty():
		universe_change_requested.emit(universe_id, universe_name)


func get_entity_root() -> Node2D: return entity_root
func is_initialized() -> bool: return _initialized
