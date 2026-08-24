# ============================================================
# File: res://UI/Drawer/DrawerMetadataService.gd
# ============================================================

# ==============================================================================
# OWNWORLD — DRAWER METADATA SERVICE
# File: res://UI/Drawer/DrawerMetadataService.gd
# Base Class: RefCounted (class_name DrawerMetadataService)
# ==============================================================================

class_name DrawerMetadataService
extends RefCounted

const PATH_ITEM_TAGS_FILE: String = "user://my_art_tags.json"
const PATH_TAGS_LIST_FILE: String = "user://my_art_tags_list.json"
const PATH_TEMPLATE_FOLDERS_FILE: String = "user://template_folders.json"
const PATH_UNIVERSES_DIRECTORY: String = "user://universes/"

static var default_tags: Array[String] = [
	"#props", "#food", "#furniture", "#characters", "#decor", "#clothing", "#magic"
]


static func get_props_path(universe_id: String = "") -> String:
	return UGCManager.get_templates_directory().path_join(_normalize_universe_id(universe_id) + "_props.json")


static func get_furniture_path(universe_id: String = "") -> String:
	return UGCManager.get_templates_directory().path_join(_normalize_universe_id(universe_id) + "_furniture.json")


static func get_cast_path(universe_id: String = "") -> String:
	return PATH_UNIVERSES_DIRECTORY.path_join(_normalize_universe_id(universe_id) + "_cast.json")


static func load_tags_list() -> Array[String]:
	var result: Array[String] = []
	var stored: Variant = _read_json(PATH_TAGS_LIST_FILE)

	if stored is Array:
		for value: Variant in (stored as Array):
			var tag: String = str(value).strip_edges().to_lower()
			if tag.is_empty(): continue
			if not tag.begins_with("#"): tag = "#" + tag
			if not result.has(tag): result.append(tag)

	return result if not result.is_empty() else default_tags.duplicate()


static func save_tags_list(tags: Array[String]) -> bool:
	var normalized: Array[String] = []
	for tag_value: String in tags:
		var tag: String = tag_value.strip_edges().to_lower()
		if tag.is_empty(): continue
		if not tag.begins_with("#"): tag = "#" + tag
		if not normalized.has(tag): normalized.append(tag)

	if normalized.is_empty(): normalized = default_tags.duplicate()
	return _write_json(PATH_TAGS_LIST_FILE, normalized)


static func load_asset_tags() -> Dictionary:
	var stored: Variant = _read_json(PATH_ITEM_TAGS_FILE)
	return (stored as Dictionary).duplicate(true) if stored is Dictionary else {}


static func save_asset_tags(tags_dictionary: Dictionary) -> bool:
	return _write_json(PATH_ITEM_TAGS_FILE, tags_dictionary.duplicate(true))


static func load_registered_folders() -> Dictionary:
	var defaults: Dictionary = {"props": [], "furniture": [], "cast": []}
	var stored: Variant = _read_json(PATH_TEMPLATE_FOLDERS_FILE)
	if not stored is Dictionary: return defaults

	var result: Dictionary = defaults.duplicate(true)
	var stored_dictionary: Dictionary = stored as Dictionary

	for key: String in ["props", "furniture", "cast"]:
		var raw_values: Variant = stored_dictionary.get(key, [])
		if not raw_values is Array: continue
		var folders: Array[String] = []
		for folder_value: Variant in (raw_values as Array):
			var folder: String = _normalize_folder(str(folder_value))
			if not folder.is_empty() and not folders.has(folder):
				folders.append(folder)
		result[key] = folders

	return result


static func save_registered_folders(folder_dictionary: Dictionary) -> bool:
	return _write_json(PATH_TEMPLATE_FOLDERS_FILE, folder_dictionary.duplicate(true))


static func load_template_array(file_path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var normalized_path: String = file_path.strip_edges()
	if normalized_path.is_empty(): return result

	var stored: Variant = _read_json(normalized_path)
	if not stored is Array: return result

	for value: Variant in (stored as Array):
		if value is Dictionary:
			result.append((value as Dictionary).duplicate(true))
	return result


static func save_template_array(file_path: String, items: Array[Dictionary]) -> bool:
	if file_path.strip_edges().is_empty(): return false
	return _write_json(file_path, items.duplicate(true))


static func load_current_props() -> Array[Dictionary]:
	return load_template_array(get_props_path(AppState.universe_id))


static func save_current_props(items: Array[Dictionary]) -> bool:
	return save_template_array(get_props_path(AppState.universe_id), items)


static func load_current_furniture() -> Array[Dictionary]:
	return load_template_array(get_furniture_path(AppState.universe_id))


static func save_current_furniture(items: Array[Dictionary]) -> bool:
	return save_template_array(get_furniture_path(AppState.universe_id), items)


static func load_current_cast() -> Array[Dictionary]:
	return load_template_array(get_cast_path(AppState.universe_id))


static func save_current_cast(items: Array[Dictionary]) -> bool:
	return save_template_array(get_cast_path(AppState.universe_id), items)


static func scrub_character_from_universe_rooms(character_id: String, character_name: String) -> void:
	var universe_id: String = _normalize_universe_id(AppState.universe_id)
	var room_ids: Array[String] = RoomRepository.list_room_ids(universe_id)
	var normalized_name: String = character_name.strip_edges().to_lower()

	for room_id: String in room_ids:
		var room_data: Dictionary = RoomRepository.load_room(universe_id, room_id)
		if room_data.is_empty(): continue

		var raw_entities: Variant = room_data.get("entities", [])
		if not raw_entities is Array: continue

		var entities: Array = raw_entities as Array
		var modified: bool = false

		for index: int in range(entities.size() - 1, -1, -1):
			var value: Variant = entities[index]
			if not value is Dictionary: continue
			var entity_data: Dictionary = value as Dictionary
			var entity_id: String = str(entity_data.get("id", ""))
			var entity_name: String = str(entity_data.get("display_name", "")).strip_edges().to_lower()

			var id_match: bool = not character_id.is_empty() and entity_id == character_id
			var name_match: bool = not normalized_name.is_empty() and entity_name == normalized_name
			if id_match or name_match:
				entities.remove_at(index)
				modified = true

		if modified:
			room_data["entities"] = entities
			RoomRepository.save_room(universe_id, room_id, room_data)


static func _read_json(file_path: String) -> Variant:
	var path: String = file_path.strip_edges()
	if path.is_empty() or not FileAccess.file_exists(path): return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null: return null
	var text: String = file.get_as_text()
	file.close()
	return JSON.parse_string(text)


static func _write_json(file_path: String, value: Variant) -> bool:
	var path: String = file_path.strip_edges()
	if path.is_empty(): return false

	var parent_directory: String = path.get_base_dir()
	if not parent_directory.is_empty() and not DirAccess.dir_exists_absolute(parent_directory):
		if DirAccess.make_dir_recursive_absolute(parent_directory) != OK: return false

	if value is Dictionary:
		return JsonFileStore.write_dictionary(path, value as Dictionary)

	var temporary_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null: return false

	file.store_string(JSON.stringify(value, "\t"))
	file.flush()
	file.close()

	if FileAccess.file_exists(path):
		if DirAccess.remove_absolute(path) != OK:
			DirAccess.remove_absolute(temporary_path)
			return false

	return DirAccess.rename_absolute(temporary_path, path) == OK


static func _normalize_universe_id(universe_id: String) -> String:
	var normalized: String = universe_id.strip_edges()
	if normalized.is_empty(): normalized = SaveSchema.DEFAULT_UNIVERSE_ID
	return normalized.validate_filename()


static func _normalize_folder(folder: String) -> String:
	var normalized: String = folder.replace("\\", "/").strip_edges().trim_prefix("/").trim_suffix("/")
	var parts: PackedStringArray = normalized.split("/", false)
	var safe_parts: Array[String] = []
	for part: String in parts:
		if part.is_empty() or part == "." or part == "..": continue
		safe_parts.append(part)
	return "/".join(safe_parts)
