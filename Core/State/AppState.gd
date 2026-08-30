# ==============================================================================
# OWNWORLD — RUNTIME APPLICATION STATE (SINGLE SOURCE OF TRUTH)
# File: res://Core/State/AppState.gd
# Autoload Singleton: AppState
# Base Class: Node
#
# Responsibility: Centralized in-memory runtime state for active Universe,
# Building, Room, Atmosphere, Unique Entity ID generation, and Z-index ordering.
# Eliminates redundant synchronous disk I/O on property getters.
# ==============================================================================

extends Node

const PATH_SESSION_FILE: String = "user://session.json"

const DEFAULT_UNIVERSE_ID: String = "default_universe"
const DEFAULT_UNIVERSE_NAME: String = "Default Universe"
const DEFAULT_BUILDING_ID: String = "building_main"
const DEFAULT_BUILDING_NAME: String = "Main Building"
const DEFAULT_ROOM_ID: String = "room_main"
const DEFAULT_FLOOR_LEVEL: String = "1F"

const DEFAULT_TIME_PRESET: String = "day"
const DEFAULT_WEATHER_PRESET: String = "none"

const MIN_Z_INDEX: int = 100
const MAX_Z_INDEX: int = 900

var universe_id: String = DEFAULT_UNIVERSE_ID
var universe_name: String = DEFAULT_UNIVERSE_NAME
var building_id: String = DEFAULT_BUILDING_ID
var building_name: String = DEFAULT_BUILDING_NAME
var room_id: String = DEFAULT_ROOM_ID
var floor_level: String = DEFAULT_FLOOR_LEVEL

var time_preset: String = DEFAULT_TIME_PRESET
var weather_preset: String = DEFAULT_WEATHER_PRESET

var is_transitioning: bool = false

var _next_entity_uid: int = 1
var _next_z_index: int = MIN_Z_INDEX


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_session_from_disk()


## Loads persisted session state into RAM once at startup.
func load_session_from_disk() -> void:
	if not FileAccess.file_exists(PATH_SESSION_FILE):
		save_session_to_disk()
		return

	var file: FileAccess = FileAccess.open(PATH_SESSION_FILE, FileAccess.READ)
	if not is_instance_valid(file):
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if parsed is Dictionary:
		apply_session_state(parsed as Dictionary)


## Persists active session state to disk atomically.
func save_session_to_disk() -> bool:
	var payload: Dictionary = export_session_state()
	return JsonFileStore.write_dictionary(PATH_SESSION_FILE, payload)


func apply_session_state(session_data: Dictionary) -> void:
	if session_data.is_empty():
		return
	universe_id = _read_string(session_data, "universe_id", DEFAULT_UNIVERSE_ID)
	universe_name = _read_string(session_data, "universe_name", DEFAULT_UNIVERSE_NAME)
	building_id = _read_string(session_data, "building_id", DEFAULT_BUILDING_ID)
	building_name = _read_string(session_data, "building_name", DEFAULT_BUILDING_NAME)
	room_id = _read_string(session_data, "room_id", DEFAULT_ROOM_ID)
	floor_level = _read_string(session_data, "floor_level", DEFAULT_FLOOR_LEVEL)
	time_preset = _read_string(session_data, "time_preset", DEFAULT_TIME_PRESET).to_lower()
	weather_preset = _read_string(session_data, "weather_preset", DEFAULT_WEATHER_PRESET).to_lower()
	is_transitioning = false


func export_session_state() -> Dictionary:
	return {
		"universe_id": universe_id,
		"universe_name": universe_name,
		"building_id": building_id,
		"building_name": building_name,
		"room_id": room_id,
		"floor_level": floor_level,
		"time_preset": time_preset,
		"weather_preset": weather_preset
	}


func switch_universe(new_universe_id: String, new_universe_name: String, starting_room_id: String = DEFAULT_ROOM_ID) -> bool:
	var normalized_id: String = new_universe_id.strip_edges()
	if normalized_id.is_empty() or is_transitioning:
		return false

	var normalized_name: String = new_universe_name.strip_edges()
	if normalized_name.is_empty(): 
		normalized_name = normalized_id

	var normalized_room_id: String = starting_room_id.strip_edges()
	if normalized_room_id.is_empty(): 
		normalized_room_id = DEFAULT_ROOM_ID

	universe_id = normalized_id
	universe_name = normalized_name
	room_id = normalized_room_id
	building_id = DEFAULT_BUILDING_ID
	building_name = DEFAULT_BUILDING_NAME
	floor_level = DEFAULT_FLOOR_LEVEL

	save_session_to_disk()
	EventBus.universe_changed.emit(universe_id, universe_name)
	EventBus.application_state_changed.emit()
	return true


func set_active_room(new_room_id: String, new_floor_level: String = "1F", new_building_id: String = "", new_building_name: String = "") -> void:
	var clean_room_id: String = new_room_id.strip_edges()
	if clean_room_id.is_empty(): 
		clean_room_id = DEFAULT_ROOM_ID

	room_id = clean_room_id
	if not new_floor_level.strip_edges().is_empty():
		floor_level = new_floor_level.strip_edges()
	if not new_building_id.strip_edges().is_empty():
		building_id = new_building_id.strip_edges()
	if not new_building_name.strip_edges().is_empty():
		building_name = new_building_name.strip_edges()

	save_session_to_disk()
	EventBus.application_state_changed.emit()


func begin_room_transition(target_room_id: String) -> bool:
	var normalized_room_id: String = target_room_id.strip_edges()
	if normalized_room_id.is_empty() or is_transitioning:
		return false

	is_transitioning = true
	room_id = normalized_room_id
	EventBus.application_state_changed.emit()
	return true


func complete_room_transition() -> void:
	if not is_transitioning:
		return
	is_transitioning = false
	save_session_to_disk()
	EventBus.application_state_changed.emit()


func set_time_preset(preset_name: String) -> bool:
	var normalized: String = preset_name.strip_edges().to_lower()
	if normalized.is_empty() or normalized == time_preset:
		return false
	time_preset = normalized
	save_session_to_disk()
	_publish_atmosphere_change()
	return true


func set_weather_preset(preset_name: String) -> bool:
	var normalized: String = preset_name.strip_edges().to_lower()
	if normalized.is_empty() or normalized == weather_preset:
		return false
	weather_preset = normalized
	save_session_to_disk()
	_publish_atmosphere_change()
	return true


func _publish_atmosphere_change() -> void:
	EventBus.global_atmosphere_changed.emit(time_preset, weather_preset)
	EventBus.application_state_changed.emit()


func generate_entity_uuid(base_name: String) -> String:
	var sanitized: String = base_name.strip_edges().validate_node_name()
	if sanitized.is_empty():
		sanitized = "entity"
	var entity_uid: String = "%s_%d" % [sanitized, _next_entity_uid]
	_next_entity_uid += 1
	return entity_uid


func get_next_z_index() -> int:
	var result: int = _next_z_index
	_next_z_index += 1
	if _next_z_index > MAX_Z_INDEX:
		_next_z_index = MIN_Z_INDEX
	return result


func _read_string(source: Dictionary, key: String, fallback: String) -> String:
	if not source.has(key):
		return fallback
	var raw_val: Variant = source[key]
	if raw_val == null:
		return fallback
	var resolved: String = str(raw_val).strip_edges()
	return resolved if not resolved.is_empty() else fallback
