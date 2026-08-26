# ==============================================================================
# OWNWORLD — SAVE SCHEMA & DATA NORMALIZER
# File: res://Core/Persistence/SaveSchema.gd
# Base Class: RefCounted (class_name SaveSchema)
# ==============================================================================

class_name SaveSchema
extends RefCounted

const CURRENT_VERSION: int = 9
const ROOM_SCHEMA_NAME: String = "ownworld.room"

const DEFAULT_UNIVERSE_ID: String = "default_universe"
const DEFAULT_BUILDING_ID: String = "building_main"
const DEFAULT_BUILDING_NAME: String = "Main Building"
const DEFAULT_ROOM_ID: String = "room_main"
const DEFAULT_ROOM_TITLE: String = "Main Room"
const DEFAULT_FLOOR_LEVEL: String = "1F"
const DEFAULT_FLOOR_Y: float = 580.0
const MAX_SLICES: int = 10

const DEFAULT_CAMERA_POSITION: Vector2 = Vector2(640.0, 360.0)
const DEFAULT_CAMERA_ZOOM: float = 1.0


## Constructs a normalized room dictionary strictly matching schema specifications.
static func create_room(
	room_id: String,
	room_title: String,
	floor_y: float,
	slices: Array[Dictionary],
	camera_position: Vector2,
	camera_zoom: float,
	entities: Array[Dictionary],
	floor_level: String = DEFAULT_FLOOR_LEVEL,
	building_id: String = DEFAULT_BUILDING_ID,
	building_name: String = DEFAULT_BUILDING_NAME
) -> Dictionary:
	var normalized_room_id: String = room_id.strip_edges()
	if normalized_room_id.is_empty():
		normalized_room_id = DEFAULT_ROOM_ID

	var normalized_title: String = room_title.strip_edges()
	if normalized_title.is_empty():
		normalized_title = normalized_room_id

	var normalized_floor_level: String = floor_level.strip_edges()
	if normalized_floor_level.is_empty():
		normalized_floor_level = DEFAULT_FLOOR_LEVEL

	var normalized_building_id: String = building_id.strip_edges()
	if normalized_building_id.is_empty():
		normalized_building_id = DEFAULT_BUILDING_ID

	var normalized_building_name: String = building_name.strip_edges()
	if normalized_building_name.is_empty():
		normalized_building_name = DEFAULT_BUILDING_NAME

	var safe_slices: Array[Dictionary] = []
	for slice_item: Variant in slices:
		if slice_item is Dictionary:
			var s_dict: Dictionary = (slice_item as Dictionary).duplicate(true)
			if not s_dict.has("wallpaper_path"): s_dict["wallpaper_path"] = ""
			if not s_dict.has("fill_mode"): s_dict["fill_mode"] = "cover"
			if not s_dict.has("is_outdoor"): s_dict["is_outdoor"] = false
			if not s_dict.has("wall_color"): s_dict["wall_color"] = ""
			if not s_dict.has("floor_color"): s_dict["floor_color"] = ""
			if not s_dict.has("baseboard_color"): s_dict["baseboard_color"] = ""
			safe_slices.append(s_dict)

	if safe_slices.is_empty():
		safe_slices.append({
			"wallpaper_path": "", "fill_mode": "cover", "is_outdoor": false,
			"wall_color": "", "floor_color": "", "baseboard_color": ""
		})
	elif safe_slices.size() > MAX_SLICES:
		safe_slices.resize(MAX_SLICES)

	return {
		"schema": ROOM_SCHEMA_NAME,
		"version": CURRENT_VERSION,
		"building_id": normalized_building_id,
		"building_name": normalized_building_name,
		"room_id": normalized_room_id,
		"room_title": normalized_title,
		"floor_level": normalized_floor_level,
		"floor_y": floor_y,
		"slice_count": safe_slices.size(),
		"slices": safe_slices,
		"wallpaper_path": safe_slices[0].get("wallpaper_path", ""),
		"wallpaper_fill_mode": safe_slices[0].get("fill_mode", "cover"),
		"is_outdoor": safe_slices[0].get("is_outdoor", false),
		"camera": {
			"x": camera_position.x,
			"y": camera_position.y,
			"zoom": maxf(camera_zoom, 0.01)
		},
		"entities": entities.duplicate(true)
	}


## Reads any arbitrary dictionary and upgrades/normalizes it to current schema standards.
static func normalize_room(raw_data: Dictionary, fallback_room_id: String = DEFAULT_ROOM_ID) -> Dictionary:
	if raw_data.is_empty():
		return create_empty_room(fallback_room_id)

	var room_id: String = str(raw_data.get("room_id", fallback_room_id)).strip_edges()
	if room_id.is_empty(): room_id = fallback_room_id
	var room_title: String = str(raw_data.get("room_title", room_id)).strip_edges()
	var floor_level: String = str(raw_data.get("floor_level", DEFAULT_FLOOR_LEVEL)).strip_edges()
	var building_id: String = str(raw_data.get("building_id", DEFAULT_BUILDING_ID)).strip_edges()
	var building_name: String = str(raw_data.get("building_name", DEFAULT_BUILDING_NAME)).strip_edges()
	var floor_y: float = float(raw_data.get("floor_y", DEFAULT_FLOOR_Y))

	var raw_slices: Variant = raw_data.get("slices", null)
	var slices_list: Array[Dictionary] = []

	if raw_slices is Array and not (raw_slices as Array).is_empty():
		for item: Variant in (raw_slices as Array):
			if item is Dictionary:
				var dict: Dictionary = (item as Dictionary).duplicate(true)
				if not dict.has("is_outdoor"):
					dict["is_outdoor"] = bool(raw_data.get("is_outdoor", false))
				slices_list.append(dict)
	elif raw_data.has("sections") and raw_data["sections"] is Array:
		for item: Variant in (raw_data["sections"] as Array):
			if item is Dictionary:
				var dict: Dictionary = (item as Dictionary).duplicate(true)
				if not dict.has("is_outdoor"):
					dict["is_outdoor"] = bool(raw_data.get("is_outdoor", false))
				slices_list.append(dict)
	else:
		var wall_path: String = str(raw_data.get("wallpaper_path", ""))
		var fill_mode: String = str(raw_data.get("wallpaper_fill_mode", "cover"))
		var is_outdoor: bool = bool(raw_data.get("is_outdoor", false))
		slices_list.append({
			"wallpaper_path": wall_path, "fill_mode": fill_mode, "is_outdoor": is_outdoor,
			"wall_color": "", "floor_color": "", "baseboard_color": ""
		})

	return create_room(
		room_id,
		room_title,
		floor_y,
		slices_list,
		_read_camera_position(raw_data),
		_read_camera_zoom(raw_data),
		_read_entities(raw_data),
		floor_level,
		building_id,
		building_name
	)


## Creates a fresh default room payload.
static func create_empty_room(
	room_id: String = DEFAULT_ROOM_ID,
	building_id: String = DEFAULT_BUILDING_ID,
	building_name: String = DEFAULT_BUILDING_NAME,
	floor_level: String = DEFAULT_FLOOR_LEVEL
) -> Dictionary:
	return create_room(
		room_id,
		room_id,
		DEFAULT_FLOOR_Y,
		[{
			"wallpaper_path": "", "fill_mode": "cover", "is_outdoor": false,
			"wall_color": "", "floor_color": "", "baseboard_color": ""
		}],
		DEFAULT_CAMERA_POSITION,
		DEFAULT_CAMERA_ZOOM,
		[],
		floor_level,
		building_id,
		building_name
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
		return Vector2(
			float(camera_data.get("x", DEFAULT_CAMERA_POSITION.x)),
			float(camera_data.get("y", DEFAULT_CAMERA_POSITION.y))
		)

	var raw_legacy: Variant = data.get("camera_pos", null)
	if raw_legacy is Dictionary:
		var pos_data: Dictionary = raw_legacy as Dictionary
		return Vector2(
			float(pos_data.get("x", DEFAULT_CAMERA_POSITION.x)),
			float(pos_data.get("y", DEFAULT_CAMERA_POSITION.y))
		)

	return DEFAULT_CAMERA_POSITION


static func _read_camera_zoom(data: Dictionary) -> float:
	var raw_camera: Variant = data.get("camera", null)
	if raw_camera is Dictionary:
		return maxf(float((raw_camera as Dictionary).get("zoom", DEFAULT_CAMERA_ZOOM)), 0.01)
	return maxf(float(data.get("camera_zoom", DEFAULT_CAMERA_ZOOM)), 0.01)
