# ==============================================================================
# OWNWORLD — SAVE SCHEMA
# File: res://Core/Persistence/SaveSchema.gd
# Base Class: RefCounted (class_name SaveSchema)
# ==============================================================================

class_name SaveSchema
extends RefCounted

const CURRENT_VERSION: int = 2
const ROOM_SCHEMA_NAME: String = "ownworld.room"

const DEFAULT_UNIVERSE_ID: String = "default_universe"
const DEFAULT_ROOM_ID: String = "room_main"
const DEFAULT_ROOM_TITLE: String = "Main Room"
const DEFAULT_FLOOR_Y: float = 600.0
const DEFAULT_WALLPAPER_FILL_MODE: String = "cover"

const DEFAULT_CAMERA_POSITION: Vector2 = Vector2(960.0, 540.0)
const DEFAULT_CAMERA_ZOOM: float = 1.0


static func create_room(
	room_id: String,
	room_title: String,
	floor_y: float,
	wallpaper_path: String,
	wallpaper_fill_mode: String,
	camera_position: Vector2,
	camera_zoom: float,
	entities: Array[Dictionary]
) -> Dictionary:
	var normalized_room_id: String = room_id.strip_edges()
	if normalized_room_id.is_empty(): normalized_room_id = DEFAULT_ROOM_ID

	var normalized_title: String = room_title.strip_edges()
	if normalized_title.is_empty(): normalized_title = normalized_room_id

	return {
		"schema": ROOM_SCHEMA_NAME,
		"version": CURRENT_VERSION,
		"room_id": normalized_room_id,
		"room_title": normalized_title,
		"floor_y": floor_y,
		"wallpaper_path": wallpaper_path,
		"wallpaper_fill_mode": wallpaper_fill_mode,
		"camera": {
			"x": camera_position.x,
			"y": camera_position.y,
			"zoom": maxf(camera_zoom, 0.01)
		},
		"entities": entities.duplicate(true)
	}


static func normalize_room(raw_data: Dictionary, fallback_room_id: String = DEFAULT_ROOM_ID) -> Dictionary:
	if raw_data.is_empty():
		return create_empty_room(fallback_room_id)

	var version: int = _read_version(raw_data)
	match version:
		0: return _migrate_v0(raw_data, fallback_room_id)
		1: return _migrate_v1(raw_data, fallback_room_id)
		CURRENT_VERSION: return _normalize_v2(raw_data, fallback_room_id)
		_: return {}


static func create_empty_room(room_id: String = DEFAULT_ROOM_ID) -> Dictionary:
	return create_room(
		room_id,
		room_id,
		DEFAULT_FLOOR_Y,
		"",
		DEFAULT_WALLPAPER_FILL_MODE,
		DEFAULT_CAMERA_POSITION,
		DEFAULT_CAMERA_ZOOM,
		[]
	)


static func _read_version(data: Dictionary) -> int:
	var value: Variant = data.get("version", 0)
	if value is String:
		var string_value: String = (value as String).strip_edges()
		return int(string_value.get_slice(".", 0)) if not string_value.is_empty() else 0
	return int(value)


static func _migrate_v0(raw_data: Dictionary, fallback_room_id: String) -> Dictionary:
	return create_room(
		fallback_room_id,
		str(raw_data.get("room_title", fallback_room_id)),
		float(raw_data.get("floor_y", DEFAULT_FLOOR_Y)),
		str(raw_data.get("wallpaper_path", "")),
		str(raw_data.get("wallpaper_fill_mode", DEFAULT_WALLPAPER_FILL_MODE)),
		_read_camera_position(raw_data),
		_read_camera_zoom(raw_data),
		_read_entities(raw_data)
	)


static func _migrate_v1(raw_data: Dictionary, fallback_room_id: String) -> Dictionary:
	var room_id: String = str(raw_data.get("room_id", fallback_room_id))
	return create_room(
		room_id,
		str(raw_data.get("room_title", room_id)),
		float(raw_data.get("floor_y", DEFAULT_FLOOR_Y)),
		str(raw_data.get("wallpaper_path", "")),
		str(raw_data.get("wallpaper_fill_mode", DEFAULT_WALLPAPER_FILL_MODE)),
		_read_camera_position(raw_data),
		_read_camera_zoom(raw_data),
		_read_entities(raw_data)
	)


static func _normalize_v2(raw_data: Dictionary, fallback_room_id: String) -> Dictionary:
	var room_id: String = str(raw_data.get("room_id", fallback_room_id))
	if room_id.is_empty(): room_id = fallback_room_id
	var room_title: String = str(raw_data.get("room_title", room_id))

	return create_room(
		room_id,
		room_title,
		float(raw_data.get("floor_y", DEFAULT_FLOOR_Y)),
		str(raw_data.get("wallpaper_path", "")),
		str(raw_data.get("wallpaper_fill_mode", DEFAULT_WALLPAPER_FILL_MODE)),
		_read_camera_position(raw_data),
		_read_camera_zoom(raw_data),
		_read_entities(raw_data)
	)


static func _read_entities(data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw_entities: Variant = data.get("entities", [])
	if raw_entities is Array:
		for value: Variant in (raw_entities as Array):
			if value is Dictionary:
				var entity_data: Dictionary = value as Dictionary
				var entity_id: String = str(entity_data.get("id", "")).strip_edges()
				if not entity_id.is_empty():
					result.append(entity_data.duplicate(true))
	return result


static func _read_camera_position(data: Dictionary) -> Vector2:
	var raw_camera: Variant = data.get("camera", null)
	if raw_camera is Dictionary:
		var camera_data: Dictionary = raw_camera as Dictionary
		return Vector2(float(camera_data.get("x", DEFAULT_CAMERA_POSITION.x)), float(camera_data.get("y", DEFAULT_CAMERA_POSITION.y)))

	var raw_legacy_position: Variant = data.get("camera_pos", null)
	if raw_legacy_position is Dictionary:
		var position_data: Dictionary = raw_legacy_position as Dictionary
		return Vector2(float(position_data.get("x", DEFAULT_CAMERA_POSITION.x)), float(position_data.get("y", DEFAULT_CAMERA_POSITION.y)))

	return DEFAULT_CAMERA_POSITION


static func _read_camera_zoom(data: Dictionary) -> float:
	var raw_camera: Variant = data.get("camera", null)
	if raw_camera is Dictionary:
		return maxf(float((raw_camera as Dictionary).get("zoom", DEFAULT_CAMERA_ZOOM)), 0.01)
	return maxf(float(data.get("camera_zoom", DEFAULT_CAMERA_ZOOM)), 0.01)
