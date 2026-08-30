# ==============================================================================
# OWNWORLD — ROOM LIFECYCLE CONTROLLER (MULTI-FLOOR DESIGNATION SUPPORT)
# File: res://Systems/World/RoomLifecycleController.gd
# Base Class: Node (class_name RoomLifecycleController)
#
# Responsibility: Manages active room entity hierarchies, room streaming,
# multi-slice expansion bounds, and room unloading notifications.
# ==============================================================================

class_name RoomLifecycleController
extends Node

const SECTION_WIDTH: float = 1920.0
const ROOM_HEIGHT: float = 1080.0

var entity_root: Node2D = null
var world_camera: Camera2D = null
var atmosphere: Node = null
var room_bounds: Rect2 = Rect2(0, 0, SECTION_WIDTH, ROOM_HEIGHT)
var current_room_floor_y: float = 600.0
var current_room_title: String = "Main Room"
var current_room_floor_level: String = "1F"
var current_building_id: String = "building_main"
var current_building_name: String = "Main Building"
var room_sections: Array[Dictionary] = [{"wallpaper_path": "", "fill_mode": "cover"}]
var _entities: Array[OwnEntity] = []
var _active_room_id: String = ""

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
	if is_instance_valid(world_camera) and world_camera.has_method("update_room_bounds"):
		world_camera.update_room_bounds(new_bounds)


func load_room(room_id: String, traveler_data: Dictionary = {}) -> void:
	if not is_instance_valid(entity_root):
		return
	var clean_room_id: String = room_id.strip_edges()
	room_loading_started.emit(clean_room_id)
	_clear_entities()

	var state: Dictionary = SaveSystem.load_room_state(clean_room_id)
	if state.is_empty():
		state = SaveSchema.create_empty_room(clean_room_id)

	_active_room_id = clean_room_id
	current_room_floor_y = float(state.get("floor_y", 600.0))
	current_room_title = str(state.get("room_title", clean_room_id))
	current_room_floor_level = str(state.get("floor_level", "1F"))
	current_building_id = str(state.get("building_id", traveler_data.get("building_id", "building_main"))).strip_edges()
	current_building_name = str(state.get("building_name", traveler_data.get("building_name", "Main Building"))).strip_edges()

	if current_building_id.is_empty(): current_building_id = "building_main"
	if current_building_name.is_empty(): current_building_name = "Main Building"

	var raw_sections: Variant = state.get("sections", null)
	room_sections.clear()
	if raw_sections is Array and not (raw_sections as Array).is_empty():
		for item: Variant in (raw_sections as Array):
			if item is Dictionary: 
				room_sections.append((item as Dictionary).duplicate(true))
	elif state.has("slices") and state["slices"] is Array:
		for item: Variant in (state["slices"] as Array):
			if item is Dictionary: 
				room_sections.append((item as Dictionary).duplicate(true))
	else:
		room_sections.append({"wallpaper_path": str(state.get("wallpaper_path", "")), "fill_mode": str(state.get("wallpaper_fill_mode", "cover"))})

	var total_width: float = float(maxi(room_sections.size(), 1)) * SECTION_WIDTH
	room_bounds = Rect2(0.0, 0.0, total_width, ROOM_HEIGHT)

	RoomManager.deserialize_room_into_canvas(state, entity_root, _entities)

	if not traveler_data.is_empty():
		var bundle_value: Variant = traveler_data.get("bundle", [])
		if bundle_value is Array and not (bundle_value as Array).is_empty():
			RoomManager.reconstruct_traveler_bundle(bundle_value as Array, Vector2(300.0, current_room_floor_y - 80.0), entity_root, _entities)

	if is_instance_valid(atmosphere):
		if atmosphere.has_method("set_preset"): 
			atmosphere.set_preset(AppState.time_preset)
		if atmosphere.has_method("set_weather"): 
			atmosphere.set_weather(AppState.weather_preset)
	if is_instance_valid(world_camera) and world_camera.has_method("update_room_bounds"):
		world_camera.update_room_bounds(room_bounds)

	room_loaded.emit(clean_room_id, state.duplicate(true))


func save_active_room() -> bool:
	var room_id: String = _active_room_id if not _active_room_id.is_empty() else AppState.room_id
	return SaveSystem.save_room_state(room_id, get_current_room_state())


func get_entities() -> Array[OwnEntity]: 
	return _entities


func get_active_room_id() -> String: 
	return _active_room_id


func get_current_room_state() -> Dictionary:
	var cam_pos: Vector2 = world_camera.position if is_instance_valid(world_camera) else Vector2(960.0, 540.0)
	var cam_zoom: float = world_camera.zoom.x if is_instance_valid(world_camera) else 1.0
	var serialized_entities: Array[Dictionary] = EntitySerializer.serialize_roots(_entities)

	return SaveSchema.create_room(
		_active_room_id if not _active_room_id.is_empty() else AppState.room_id,
		current_room_title,
		current_room_floor_y,
		room_sections,
		cam_pos,
		cam_zoom,
		serialized_entities,
		current_room_floor_level,
		current_building_id,
		current_building_name
	)


func _clear_entities() -> void:
	if not _active_room_id.is_empty():
		room_unloaded.emit(_active_room_id)
	for entity: OwnEntity in _entities:
		if is_instance_valid(entity):
			entity.queue_free()
	_entities.clear()
