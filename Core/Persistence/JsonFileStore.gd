# ==============================================================================
# OWNWORLD — JSON FILE STORE
# File: res://Core/Persistence/JsonFileStore.gd
# Base Class: RefCounted (class_name JsonFileStore)
# ==============================================================================

class_name JsonFileStore
extends RefCounted


static func write_dictionary(file_path: String, data: Dictionary) -> bool:
	var normalized_path: String = file_path.strip_edges()
	if normalized_path.is_empty():
		return false

	var parent_directory: String = normalized_path.get_base_dir()
	if not parent_directory.is_empty() and not DirAccess.dir_exists_absolute(parent_directory):
		if DirAccess.make_dir_recursive_absolute(parent_directory) != OK:
			return false

	var temp_path: String = normalized_path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()

	if FileAccess.file_exists(normalized_path):
		if DirAccess.remove_absolute(normalized_path) != OK:
			if FileAccess.file_exists(temp_path):
				DirAccess.remove_absolute(temp_path)
			return false

	if DirAccess.rename_absolute(temp_path, normalized_path) != OK:
		if FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(temp_path)
		return false

	return true


static func read_dictionary(file_path: String) -> Dictionary:
	var normalized_path: String = file_path.strip_edges()
	if normalized_path.is_empty() or not FileAccess.file_exists(normalized_path):
		return {}

	# Optimized: Single-call C++ level file read. Bypasses GDScript file handle overhead.
	var content: String = FileAccess.get_file_as_string(normalized_path)
	var parsed: Variant = JSON.parse_string(content)
	
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


static func delete_file(file_path: String) -> bool:
	if file_path.is_empty() or not FileAccess.file_exists(file_path):
		return false
	return DirAccess.remove_absolute(file_path) == OK


static func file_exists(file_path: String) -> bool:
	return not file_path.is_empty() and FileAccess.file_exists(file_path)


static func ensure_directory(directory_path: String) -> bool:
	if directory_path.is_empty():
		return false
	if DirAccess.dir_exists_absolute(directory_path):
		return true
	return DirAccess.make_dir_recursive_absolute(directory_path) == OK
