# ==============================================================================
# Script: res://Systems/World/RoomLifecycleController.gd
# Base Class: Node (class_name RoomLifecycleController)
# ==============================================================================

class_name RoomLifecycleController
extends Node

var entity_root: Node2D = null
var world_camera: Camera2D = null
var atmosphere: Node = null
var room_bounds: Rect2 = Rect2(0, 0, 1920, 1080)
var current_room_floor_y: float = 600.0
var current_room_title: String = "Main Room"
var current_wallpaper_path: String = ""
var current_wallpaper_fill_mode: String = "cover"
var _entities: Array = []
var _active_room_id: String = ""
var _snapshot_service: RoomSnapshotService = RoomSnapshotService.new()

signal room_loading_started(room_id: String)
signal room_loaded(room_id: String, room_state: Dictionary)
signal room_unloaded(room_id: String)


func configure(p_entity_root: Node2D, p_world_camera: Camera2D, p_atmosphere: Node, p_room_bounds: Rect2) -> void:
	entity_root = p_entity_root
	world_camera = p_world_camera
	atmosphere = p_atmosphere
	if p_room_bounds.size.x > 0.0 and p_room_bounds.size.y > 0.0:
		room_bounds = p_room_bounds


func set_room_bounds(new_bounds: Rect2) -> void:
	room_bounds = new_bounds
	if world_camera and world_camera.has_method("update_room_bounds"):
		world_camera.update_room_bounds(new_bounds)


func load_room(room_id: String, traveler_data: Dictionary = {}) -> void:
	if entity_root == null:
		return
	room_loading_started.emit(room_id)
	_clear_entities()

	var state: Dictionary = SaveSystem.load_room_state(room_id)
	if state.is_empty():
		state = SaveSchema.create_empty_room(room_id)

	_active_room_id = room_id
	current_room_floor_y = float(state.get("floor_y", 600.0))
	current_room_title = str(state.get("room_title", room_id))
	current_wallpaper_path = str(state.get("wallpaper_path", ""))
	current_wallpaper_fill_mode = str(state.get("wallpaper_fill_mode", "cover"))

	RoomManager.deserialize_room_into_canvas(state, entity_root, _entities)

	if not traveler_data.is_empty():
		var bundle_value: Variant = traveler_data.get("bundle", [])
		if bundle_value is Array and not (bundle_value as Array).is_empty():
			RoomManager.reconstruct_traveler_bundle(bundle_value as Array, Vector2(300.0, current_room_floor_y - 80.0), entity_root, _entities)

	if atmosphere and atmosphere.has_method("set_preset"): atmosphere.set_preset(AppState.time_preset)
	if atmosphere and atmosphere.has_method("set_weather"): atmosphere.set_weather(AppState.weather_preset)
	if world_camera and world_camera.has_method("update_room_bounds"): world_camera.update_room_bounds(room_bounds)

	room_loaded.emit(room_id, state.duplicate(true))


func save_active_room() -> bool:
	var room_id: String = _active_room_id if not _active_room_id.is_empty() else AppState.room_id
	return SaveSystem.save_room_state(room_id, get_current_room_state())

func get_entities() -> Array: return _entities
func get_active_room_id() -> String: return _active_room_id

func get_current_room_state() -> Dictionary:
	return _snapshot_service.create_snapshot(
		_active_room_id if not _active_room_id.is_empty() else AppState.room_id,
		current_room_title, current_room_floor_y, current_wallpaper_path,
		current_wallpaper_fill_mode, world_camera, _entities
	)


func _clear_entities() -> void:
	if not _active_room_id.is_empty():
		room_unloaded.emit(_active_room_id)
	for entity: Variant in _entities:
		if is_instance_valid(entity):
			entity.queue_free()
	_entities.clear()
