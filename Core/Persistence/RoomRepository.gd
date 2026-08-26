# ==============================================================================
# OWNWORLD — ROOM REPOSITORY
# File: res://Core/Persistence/RoomRepository.gd
# Base Class: RefCounted (class_name RoomRepository)
# ==============================================================================

class_name RoomRepository
extends RefCounted

const ROOT_PATH: String = "user://saves/"
const ROOMS_FOLDER: String = "rooms"


static func get_universe_directory(universe_id: String) -> String:
	return ROOT_PATH.path_join(_normalize_universe_id(universe_id))


static func get_room_directory(universe_id: String) -> String:
	return get_universe_directory(universe_id).path_join(ROOMS_FOLDER)


static func get_room_path(universe_id: String, room_id: String) -> String:
	return get_room_directory(universe_id).path_join(_normalize_room_id(room_id) + ".json")


static func save_room(universe_id: String, room_id: String, room_data: Dictionary) -> bool:
	var normalized_room_id: String = _normalize_room_id(room_id)
	var normalized_data: Dictionary = SaveSchema.normalize_room(room_data, normalized_room_id)
	if normalized_data.is_empty():
		return false
	normalized_data["room_id"] = normalized_room_id
	return JsonFileStore.write_dictionary(get_room_path(universe_id, normalized_room_id), normalized_data)


static func load_room(universe_id: String, room_id: String) -> Dictionary:
	var normalized_room_id: String = _normalize_room_id(room_id)
	var raw_data: Dictionary = JsonFileStore.read_dictionary(get_room_path(universe_id, normalized_room_id))
	if raw_data.is_empty():
		return {}
	return SaveSchema.normalize_room(raw_data, normalized_room_id)


static func delete_room(universe_id: String, room_id: String) -> bool:
	return JsonFileStore.delete_file(get_room_path(universe_id, room_id))


static func list_room_ids(universe_id: String) -> Array[String]:
	var result: Array[String] = []
	var directory_path: String = get_room_directory(universe_id)
	if not DirAccess.dir_exists_absolute(directory_path):
		return result

	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return result

	directory.list_dir_begin()
	var file_name: String = directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(".json") and file_name != "recipes.json":
			result.append(file_name.trim_suffix(".json"))
		file_name = directory.get_next()
	directory.list_dir_end()

	result.sort()
	return result


static func clear_universe(universe_id: String) -> bool:
	var directory_path: String = get_room_directory(universe_id)
	if not DirAccess.dir_exists_absolute(directory_path):
		return false

	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return false

	var changed: bool = false
	directory.list_dir_begin()
	var file_name: String = directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(".json"):
			if JsonFileStore.delete_file(directory_path.path_join(file_name)):
				changed = true
		file_name = directory.get_next()
	directory.list_dir_end()

	return changed


static func _normalize_universe_id(universe_id: String) -> String:
	var normalized: String = universe_id.strip_edges()
	if normalized.is_empty(): normalized = SaveSchema.DEFAULT_UNIVERSE_ID
	return normalized.validate_filename()


static func _normalize_room_id(room_id: String) -> String:
	var normalized: String = room_id.strip_edges()
	if normalized.is_empty(): normalized = SaveSchema.DEFAULT_ROOM_ID
	return normalized.validate_filename()
