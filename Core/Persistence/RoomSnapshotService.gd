# ==============================================================================
# OWNWORLD — ROOM SNAPSHOT SERVICE
# File: res://Core/Persistence/RoomSnapshotService.gd
# Base Class: RefCounted (class_name RoomSnapshotService)
# ==============================================================================

class_name RoomSnapshotService
extends RefCounted


func create_snapshot(
	room_id: String,
	room_title: String,
	floor_y: float,
	wallpaper_path: String,
	wallpaper_fill_mode: String,
	camera: Camera2D,
	entities: Array[OwnEntity]
) -> Dictionary:
	var camera_position: Vector2 = SaveSchema.DEFAULT_CAMERA_POSITION
	var camera_zoom: float = SaveSchema.DEFAULT_CAMERA_ZOOM

	if camera != null:
		camera_position = camera.position
		camera_zoom = maxf(camera.zoom.x, 0.01)

	var serialized_entities: Array[Dictionary] = EntitySerializer.serialize_roots(entities)

	return SaveSchema.create_room(
		room_id,
		room_title,
		floor_y,
		wallpaper_path,
		wallpaper_fill_mode,
		camera_position,
		camera_zoom,
		serialized_entities
	)
