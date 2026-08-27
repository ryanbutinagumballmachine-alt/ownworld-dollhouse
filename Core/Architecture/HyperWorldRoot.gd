# ==============================================================================
# OWNWORLD — HYPER ARCHITECTURE ROOT
# File: res://Core/Architecture/HyperWorldRoot.gd
# Base Class: Node (class_name HyperWorldRoot)
#
# Responsibility: Foundational world scene tree root controller.
# Enforces strict dependency validation, typed scene anchoring, and domain routing.
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
	assert(room_root != null, "HyperWorldRoot: room_root export must not be null.")
	assert(entity_root != null, "HyperWorldRoot: entity_root export must not be null.")
	assert(world_camera != null, "HyperWorldRoot: world_camera export must not be null.")


func _connect_domain_events() -> void:
	pass


func request_room_change(room_id: String, traveler_data: Dictionary = {}) -> void:
	var clean_id: String = room_id.strip_edges()
	if not clean_id.is_empty():
		room_change_requested.emit(clean_id, traveler_data)


func request_universe_change(universe_id: String, universe_name: String) -> void:
	var clean_id: String = universe_id.strip_edges()
	var clean_name: String = universe_name.strip_edges()
	if not clean_id.is_empty():
		universe_change_requested.emit(clean_id, clean_name if not clean_name.is_empty() else clean_id)


func get_entity_root() -> Node2D:
	return entity_root


func is_initialized() -> bool:
	return _initialized
