# ==============================================================================
# OWNWORLD — APPLICATION STATE
# File: res://Core/State/AppState.gd
# Autoload: AppState
# ==============================================================================

extends Node

const DEFAULT_UNIVERSE_ID: String = "default_universe"
const DEFAULT_UNIVERSE_NAME: String = "Default Universe"
const DEFAULT_ROOM_ID: String = "room_main"

const DEFAULT_TIME_PRESET: String = "day"
const DEFAULT_WEATHER_PRESET: String = "none"

const MIN_Z_INDEX: int = 100
const MAX_Z_INDEX: int = 900

var universe_id: String = DEFAULT_UNIVERSE_ID
var universe_name: String = DEFAULT_UNIVERSE_NAME
var room_id: String = DEFAULT_ROOM_ID

var time_preset: String = DEFAULT_TIME_PRESET
var weather_preset: String = DEFAULT_WEATHER_PRESET

var transitioning: bool = false

var _next_entity_uid: int = 1
var _next_z_index: int = MIN_Z_INDEX


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func apply_session_state(session_data: Dictionary) -> void:
	if session_data.is_empty():
		return
	universe_id = _read_string(session_data, "universe_id", DEFAULT_UNIVERSE_ID)
	universe_name = _read_string(session_data, "universe_name", DEFAULT_UNIVERSE_NAME)
	room_id = _read_string(session_data, "room_id", DEFAULT_ROOM_ID)
	time_preset = _read_string(session_data, "time_preset", DEFAULT_TIME_PRESET).to_lower()
	weather_preset = _read_string(session_data, "weather_preset", DEFAULT_WEATHER_PRESET).to_lower()
	transitioning = false


func export_session_state() -> Dictionary:
	return {
		"universe_id": universe_id,
		"universe_name": universe_name,
		"room_id": room_id,
		"time_preset": time_preset,
		"weather_preset": weather_preset
	}


func request_universe_change(new_universe_id: String, new_universe_name: String, starting_room_id: String = DEFAULT_ROOM_ID) -> bool:
	var normalized_id: String = new_universe_id.strip_edges()
	if normalized_id.is_empty() or transitioning:
		return false

	var normalized_name: String = new_universe_name.strip_edges()
	if normalized_name.is_empty(): normalized_name = normalized_id

	var normalized_room_id: String = starting_room_id.strip_edges()
	if normalized_room_id.is_empty(): normalized_room_id = DEFAULT_ROOM_ID

	var changed: bool = (universe_id != normalized_id or universe_name != normalized_name or room_id != normalized_room_id)
	universe_id = normalized_id
	universe_name = normalized_name
	room_id = normalized_room_id

	if not changed:
		return false

	EventBus.universe_change_requested.emit(universe_id, universe_name)
	EventBus.universe_changed.emit(universe_id, universe_name)
	EventBus.application_state_changed.emit()
	return true


func begin_universe_transition(new_universe_id: String, new_universe_name: String) -> bool:
	var normalized_id: String = new_universe_id.strip_edges()
	if normalized_id.is_empty() or transitioning:
		return false

	transitioning = true
	universe_id = normalized_id
	universe_name = new_universe_name.strip_edges() if not new_universe_name.strip_edges().is_empty() else normalized_id
	room_id = DEFAULT_ROOM_ID
	EventBus.application_state_changed.emit()
	return true


func complete_universe_transition() -> void:
	if not transitioning:
		return
	transitioning = false
	EventBus.application_state_changed.emit()


func request_room_change(target_room_id: String, traveler_data: Dictionary = {}) -> bool:
	var normalized_room_id: String = target_room_id.strip_edges()
	if normalized_room_id.is_empty() or transitioning:
		return false
	if normalized_room_id == room_id and traveler_data.is_empty():
		return false

	EventBus.room_change_requested.emit(normalized_room_id, traveler_data.duplicate(true))
	return true


func begin_room_transition(target_room_id: String) -> bool:
	var normalized_room_id: String = target_room_id.strip_edges()
	if normalized_room_id.is_empty() or transitioning:
		return false

	transitioning = true
	room_id = normalized_room_id
	EventBus.application_state_changed.emit()
	return true


func complete_room_transition() -> void:
	if not transitioning:
		return
	transitioning = false
	EventBus.application_state_changed.emit()


func set_time_preset(preset_name: String) -> bool:
	var normalized: String = preset_name.strip_edges().to_lower()
	if normalized.is_empty() or normalized == time_preset:
		return false
	time_preset = normalized
	_publish_atmosphere_change()
	return true


func set_weather_preset(preset_name: String) -> bool:
	var normalized: String = preset_name.strip_edges().to_lower()
	if normalized.is_empty() or normalized == weather_preset:
		return false
	weather_preset = normalized
	_publish_atmosphere_change()
	return true


func get_atmosphere_state() -> Dictionary:
	return {
		"time_preset": time_preset,
		"weather_preset": weather_preset
	}


func _publish_atmosphere_change() -> void:
	EventBus.global_atmosphere_changed.emit(time_preset, weather_preset)
	EventBus.application_state_changed.emit()


func generate_entity_uuid(base_name: String) -> String:
	var sanitized_name: String = base_name.strip_edges().validate_node_name()
	if sanitized_name.is_empty():
		sanitized_name = "entity"
	var entity_uid: String = "%s_%d" % [sanitized_name, _next_entity_uid]
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
