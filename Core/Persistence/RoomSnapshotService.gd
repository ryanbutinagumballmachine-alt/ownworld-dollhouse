# ==============================================================================
# OWNWORLD — ROOM SNAPSHOT SERVICE
# File: res://Core/Persistence/RoomSnapshotService.gd
# Base Class: RefCounted (class_name RoomSnapshotService)
#
# Responsibility: High-level room snapshot compilation. Correctly bridges
# active Camera2D states and multi-slice wallpapers into SaveSchema payloads.
# ==============================================================================

class_name RoomSnapshotService
extends RefCounted


## Creates a fully normalized room snapshot payload from live world parameters.
func create_snapshot(
	room_id: String,
	room_title: String,
	floor_y: float,
	slices_or_wallpaper: Variant,
	camera: Camera2D = null,
	entities: Array[OwnEntity] = [],
	floor_level: String = SaveSchema.DEFAULT_FLOOR_LEVEL,
	building_id: String = SaveSchema.DEFAULT_BUILDING_ID,
	building_name: String = SaveSchema.DEFAULT_BUILDING_NAME
) -> Dictionary:
	var camera_position: Vector2 = SaveSchema.DEFAULT_CAMERA_POSITION
	var camera_zoom: float = SaveSchema.DEFAULT_CAMERA_ZOOM

	if camera != null and is_instance_valid(camera):
		camera_position = camera.position
		camera_zoom = maxf(camera.zoom.x, 0.01)

	var resolved_slices: Array[Dictionary] = []
	if slices_or_wallpaper is Array:
		for item: Variant in (slices_or_wallpaper as Array):
			if item is Dictionary:
				resolved_slices.append((item as Dictionary).duplicate(true))
	elif slices_or_wallpaper is String:
		resolved_slices.append({
			"wallpaper_path": str(slices_or_wallpaper),
			"fill_mode": "cover",
			"is_outdoor": false,
			"wall_color": "",
			"floor_color": "",
			"baseboard_color": ""
		})

	if resolved_slices.is_empty():
		resolved_slices.append({
			"wallpaper_path": "",
			"fill_mode": "cover",
			"is_outdoor": false,
			"wall_color": "",
			"floor_color": "",
			"baseboard_color": ""
		})

	var serialized_entities: Array[Dictionary] = EntitySerializer.serialize_roots(entities)

	return SaveSchema.create_room(
		room_id,
		room_title,
		floor_y,
		resolved_slices,
		camera_position,
		camera_zoom,
		serialized_entities,
		floor_level,
		building_id,
		building_name
	)
