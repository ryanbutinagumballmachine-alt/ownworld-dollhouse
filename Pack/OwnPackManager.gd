# ==============================================================================
# OWNWORLD — OWN PACK MANAGER (ZIP ARCHIVE IMPORT & EXPORT)
# File: res://Pack/OwnPackManager.gd
# Base Class: RefCounted (class_name OwnPackManager)
#
# Responsibility: ZIP archive packing and unpacking for .ownpack universe bundles.
# Includes path traversal sanitization (Zip-Slip protection) and manifest validation.
# ==============================================================================

class_name OwnPackManager
extends RefCounted

const SAFE_EXTENSIONS: Array[String] = [
	"png", "jpg", "jpeg", "webp",
	"mp3", "ogg", "wav",
	"ttf", "otf",
	"json", "tres"
]

const UNIVERSES_DIR: String = "user://universes/"
const MAPS_DIR: String = "user://maps/"


static func get_exports_dir() -> String:
	return UGCManager.get_exports_dir()


static func get_packs_dir() -> String:
	return UGCManager.get_packs_dir()


## Exports an entire story universe into a single .ownpack ZIP archive.
static func export_universe_pack(pack_name: String, author: String, universe_id: String, output_filename: String) -> bool:
	var clean_universe_id: String = universe_id.strip_edges()
	if clean_universe_id.is_empty():
		return false

	var clean_output_name: String = output_filename.strip_edges()
	if clean_output_name.is_empty(): 
		clean_output_name = clean_universe_id
	if clean_output_name.ends_with(".ownpack"): 
		clean_output_name = clean_output_name.trim_suffix(".ownpack")

	var output_path: String = get_exports_dir().path_join(clean_output_name + ".ownpack")

	var packer: ZIPPacker = ZIPPacker.new()
	if packer.open(output_path) != OK:
		push_error("[OwnPackManager] ZIPPacker failed to open output stream: " + output_path)
		return false

	var manifest: Dictionary = {
		"pack_name": pack_name,
		"author": author,
		"version": "1.0.0",
		"universe_id": clean_universe_id,
		"created_at": Time.get_unix_time_from_system()
	}

	packer.start_file("manifest.json")
	packer.write_file(JSON.stringify(manifest, "\t").to_utf8_buffer())
	packer.close_file()

	_write_file_to_packer(packer, UNIVERSES_DIR + clean_universe_id + ".json", "universe.json")
	_write_file_to_packer(packer, SaveSystem.get_universe_cast_path(clean_universe_id), "cast.json")
	_write_file_to_packer(packer, _get_universe_map_path(clean_universe_id), "map.json")
	_write_file_to_packer(packer, SaveSystem.get_universe_journal_path(clean_universe_id), "journal.json")

	var recipes_path: String = SaveSystem.get_universe_save_dir(clean_universe_id) + "recipes.json"
	_write_file_to_packer(packer, recipes_path, "recipes.json")

	var room_dir_path: String = SaveSystem.get_universe_save_dir(clean_universe_id)
	var room_dir: DirAccess = DirAccess.open(room_dir_path)
	if room_dir != null:
		room_dir.list_dir_begin()
		var file_name: String = room_dir.get_next()
		while not file_name.is_empty():
			if not room_dir.current_is_dir() and file_name.ends_with(".json") and file_name != "recipes.json":
				_write_file_to_packer(packer, room_dir_path + file_name, "rooms/" + file_name)
			file_name = room_dir.get_next()
		room_dir.list_dir_end()

	_export_directory_files(packer, UGCManager.get_art_root_directory(), "art/")
	_export_directory_files(packer, UGCManager.get_font_root_directory(), "font/")
	_export_directory_files(packer, UGCManager.get_theme_root_directory(), "theme/")
	packer.close()
	return true


static func _export_directory_files(packer: ZIPPacker, root_path: String, internal_prefix: String) -> void:
	var dir: DirAccess = DirAccess.open(root_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.get_extension().to_lower() in SAFE_EXTENSIONS:
			_write_file_to_packer(packer, root_path.path_join(file_name), internal_prefix + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


static func _write_file_to_packer(packer: ZIPPacker, source_path: String, internal_path: String) -> void:
	if not FileAccess.file_exists(source_path):
		return
	var file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		return
	packer.start_file(internal_path)
	packer.write_file(file.get_buffer(file.get_length()))
	packer.close_file()
	file.close()


## Safely imports an .ownpack or ZIP archive into user universes.
static func import_pack_file(source_file_path: String) -> bool:
	if not FileAccess.file_exists(source_file_path):
		return false

	var reader: ZIPReader = ZIPReader.new()
	if reader.open(source_file_path) != OK:
		push_error("[OwnPackManager] ZIPReader failed to open archive: " + source_file_path)
		return false

	var files: PackedStringArray = reader.get_files()
	if not "manifest.json" in files:
		reader.close()
		return false

	var manifest_data: Variant = JSON.parse_string(reader.read_file("manifest.json").get_string_from_utf8())
	if not manifest_data is Dictionary:
		reader.close()
		return false

	var manifest: Dictionary = manifest_data as Dictionary
	var universe_id: String = str(manifest.get("universe_id", "imported_universe")).strip_edges()
	var universe_name: String = str(manifest.get("pack_name", universe_id)).strip_edges()
	if universe_id.is_empty(): 
		universe_id = "imported_universe"
	if universe_name.is_empty(): 
		universe_name = universe_id

	JsonFileStore.ensure_directory(UNIVERSES_DIR)
	JsonFileStore.ensure_directory(MAPS_DIR)

	var universe_save_dir: String = SaveSystem.get_universe_save_dir(universe_id)
	JsonFileStore.ensure_directory(universe_save_dir)

	for internal_path: String in files:
		if internal_path.ends_with("/"):
			continue
		var extension: String = internal_path.get_extension().to_lower()
		if extension not in SAFE_EXTENSIONS:
			continue

		var destination: String = _resolve_import_destination(internal_path, universe_id, universe_save_dir)
		if destination.is_empty() or not _is_safe_destination(destination, universe_id, universe_save_dir):
			continue

		var buffer: PackedByteArray = reader.read_file(internal_path)
		var output_file: FileAccess = FileAccess.open(destination, FileAccess.WRITE)
		if output_file != null:
			output_file.store_buffer(buffer)
			output_file.flush()
			output_file.close()

	reader.close()

	var universe_manifest_path: String = UNIVERSES_DIR + universe_id + ".json"
	if not FileAccess.file_exists(universe_manifest_path):
		var fallback_manifest: Dictionary = {
			"id": universe_id,
			"name": universe_name,
			"created_at": Time.get_unix_time_from_system()
		}
		JsonFileStore.write_dictionary(universe_manifest_path, fallback_manifest)

	return true


static func _resolve_import_destination(internal_path: String, universe_id: String, universe_save_dir: String) -> String:
	if internal_path == "universe.json": 
		return UNIVERSES_DIR + universe_id + ".json"
	if internal_path == "cast.json": 
		return SaveSystem.get_universe_cast_path(universe_id)
	if internal_path == "map.json": 
		return _get_universe_map_path(universe_id)
	if internal_path == "journal.json": 
		return SaveSystem.get_universe_journal_path(universe_id)
	if internal_path == "recipes.json": 
		return universe_save_dir + "recipes.json"
	if internal_path.begins_with("rooms/"): 
		return universe_save_dir + internal_path.get_file()
	if internal_path.begins_with("art/"): 
		return UGCManager.get_art_root_directory().path_join(internal_path.get_file())
	if internal_path.begins_with("font/") or internal_path.begins_with("fonts/"): 
		return UGCManager.get_font_root_directory().path_join(internal_path.get_file())
	if internal_path.begins_with("theme/") or internal_path.begins_with("themes/"): 
		return UGCManager.get_theme_root_directory().path_join(internal_path.get_file())
	return ""


static func _is_safe_destination(destination: String, _universe_id: String, universe_save_dir: String) -> bool:
	var normalized: String = destination.replace("\\", "/")
	if normalized.contains(".."):
		return false
	var allowed_roots: Array[String] = [
		UNIVERSES_DIR,
		MAPS_DIR,
		UGCManager.get_art_root_directory(),
		UGCManager.get_font_root_directory(),
		UGCManager.get_theme_root_directory(),
		UGCManager.get_dollhouse_dir(),
		universe_save_dir
	]
	for allowed_root: String in allowed_roots:
		if normalized.begins_with(allowed_root.replace("\\", "/")):
			return true
	return false


static func _get_universe_map_path(universe_id: String) -> String:
	return MAPS_DIR + universe_id + "_map.json"
