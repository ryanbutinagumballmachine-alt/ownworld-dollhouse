# ==============================================================================
# OWNWORLD — JSON FILE STORE (ATOMIC DISK I/O)
# File: res://Core/Persistence/JsonFileStore.gd
# Base Class: RefCounted (class_name JsonFileStore)
#
# Responsibility: Atomic transactional disk I/O with temporary file swaps
# to prevent zero-byte corruptions during unexpected power cuts or OS suspension.
# ==============================================================================

class_name JsonFileStore
extends RefCounted


## Atomically writes a dictionary to disk using a temporary file swap.
static func write_dictionary(file_path: String, data: Dictionary) -> bool:
	var normalized_path: String = file_path.strip_edges().replace("\\", "/")
	if normalized_path.is_empty():
		return false

	var parent_directory: String = normalized_path.get_base_dir()
	if not parent_directory.is_empty() and not DirAccess.dir_exists_absolute(parent_directory):
		if DirAccess.make_dir_recursive_absolute(parent_directory) != OK:
			return false

	var temp_path: String = normalized_path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if not is_instance_valid(file):
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


## High-speed C++ engine level file content read and JSON parse.
static func read_dictionary(file_path: String) -> Dictionary:
	var normalized_path: String = file_path.strip_edges().replace("\\", "/")
	if normalized_path.is_empty() or not FileAccess.file_exists(normalized_path):
		return {}

	var content: String = FileAccess.get_file_as_string(normalized_path)
	var parsed: Variant = JSON.parse_string(content)
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


## Safely removes a file from disk.
static func delete_file(file_path: String) -> bool:
	var normalized_path: String = file_path.strip_edges().replace("\\", "/")
	if normalized_path.is_empty() or not FileAccess.file_exists(normalized_path):
		return false
	return DirAccess.remove_absolute(normalized_path) == OK


## Checks if a file exists on disk.
static func file_exists(file_path: String) -> bool:
	var normalized_path: String = file_path.strip_edges().replace("\\", "/")
	return not normalized_path.is_empty() and FileAccess.file_exists(normalized_path)


## Ensures a target directory exists on disk.
static func ensure_directory(directory_path: String) -> bool:
	var normalized_path: String = directory_path.strip_edges().replace("\\", "/")
	if normalized_path.is_empty():
		return false
	if DirAccess.dir_exists_absolute(normalized_path):
		return true
	return DirAccess.make_dir_recursive_absolute(normalized_path) == OK
