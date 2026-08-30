# ==============================================================================
# OWNWORLD — GAME MANAGER (SESSION & VIEWPORT COORDINATOR)
# File: res://AutoLoads/GameManager.gd
# Autoload Singleton: GameManager
# Base Class: Node
#
# Responsibility: High-level game session coordination, viewport scaling,
# cast roster compilation, and factory reset execution.
# Integrates with AppState to eliminate redundant state duplication.
# ==============================================================================

extends Node

const PATH_SAVES_ROOT: String = "user://saves/"
const PATH_UNIVERSES_DIR: String = "user://universes/"
const PATH_MAPS_DIR: String = "user://maps/"

const BASE_CANVAS_SIZE: Vector2i = Vector2i(1280, 720)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_enforce_engine_viewport_scaling()
	_initialize_filesystem()


func _enforce_engine_viewport_scaling() -> void:
	var window: Window = get_window()
	if not is_instance_valid(window):
		return
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	window.content_scale_size = BASE_CANVAS_SIZE

	# Enforce Sensor Landscape orientation on mobile platforms (Android & iOS)
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)


func _initialize_filesystem() -> void:
	var paths: Array[String] = [
		PATH_SAVES_ROOT, PATH_UNIVERSES_DIR, PATH_MAPS_DIR
	]
	for path: String in paths:
		if not DirAccess.dir_exists_absolute(path):
			DirAccess.make_dir_recursive_absolute(path)

	UGCManager.ensure_all_directories()


func get_all_universe_character_data() -> Array[Dictionary]:
	var roster: Dictionary = {}
	var seen_names: Dictionary = {}

	var tree: SceneTree = get_tree()
	if is_instance_valid(tree):
		for node: Node in tree.get_nodes_in_group(&"characters"):
			if not is_instance_valid(node) or not node.has_method("to_dict"):
				continue
			var data: Dictionary = node.call("to_dict") as Dictionary
			var character_id: String = str(data.get("id", ""))
			var character_name: String = str(data.get("display_name", "")).strip_edges().to_lower()
			if character_id.is_empty():
				continue
			roster[character_id] = data.duplicate(true)
			if not character_name.is_empty():
				seen_names[character_name] = true

	var cast_path: String = SaveSystem.get_universe_cast_path(AppState.universe_id)
	if FileAccess.file_exists(cast_path):
		var cast_file: FileAccess = FileAccess.open(cast_path, FileAccess.READ)
		if is_instance_valid(cast_file):
			var parsed: Variant = JSON.parse_string(cast_file.get_as_text())
			cast_file.close()
			var cast_items: Array = []
			if parsed is Array:
				cast_items = parsed as Array
			elif parsed is Dictionary:
				cast_items = (parsed as Dictionary).get("cast", (parsed as Dictionary).get("templates", []))

			for item: Variant in cast_items:
				if not item is Dictionary:
					continue
				var character_data: Dictionary = (item as Dictionary).duplicate(true)
				var character_id: String = str(character_data.get("id", ""))
				var character_name: String = str(character_data.get("display_name", "")).strip_edges().to_lower()
				if character_id.is_empty() or roster.has(character_id):
					continue
				if not character_name.is_empty() and seen_names.has(character_name):
					continue
				roster[character_id] = character_data
				if not character_name.is_empty():
					seen_names[character_name] = true

	var result: Array[Dictionary] = []
	for value: Variant in roster.values():
		if value is Dictionary:
			result.append(value as Dictionary)
	return result


func factory_reset_entire_game() -> void:
	_wipe_dir_recursive("user://")
	_initialize_filesystem()

	AppState.universe_id = "default_universe"
	AppState.universe_name = "Default Universe"
	AppState.room_id = "room_main"
	AppState.time_preset = "day"
	AppState.weather_preset = "none"
	AppState.save_session_to_disk()

	ThemeService.reset_to_default_theme()
	get_tree().reload_current_scene()


func _wipe_dir_recursive(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if not is_instance_valid(dir):
		return
	dir.list_dir_begin()
	var item: String = dir.get_next()
	var subdirs: Array[String] = []

	while not item.is_empty():
		if item != "." and item != "..":
			var full_path: String = path.path_join(item)
			if dir.current_is_dir():
				subdirs.append(full_path)
			else:
				DirAccess.remove_absolute(full_path)
		item = dir.get_next()
	dir.list_dir_end()

	for subdir: String in subdirs:
		_wipe_dir_recursive(subdir)
		DirAccess.remove_absolute(subdir)
