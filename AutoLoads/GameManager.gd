# ==============================================================================
# OWNWORLD — GAME MANAGER
# File: res://AutoLoads/GameManager.gd
# Placement: AutoLoad Singleton
# Base Class: Node (GameManager)
# ==============================================================================

extends Node

const PATH_SAVES_ROOT: String = "user://saves/"
const PATH_UNIVERSES_DIR: String = "user://universes/"
const PATH_MAPS_DIR: String = "user://maps/"
const PATH_SESSION_FILE: String = "user://session.json"

const BASE_CANVAS_SIZE: Vector2i = Vector2i(1280, 720)
const CORNER_RADIUS: int = 6

var current_universe_id: String = "default_universe"
var current_universe_name: String = "Default Universe"
var current_room_id: String = "room_main"

var global_time_preset: String = "day"
var global_weather_preset: String = "none"

var pending_traveler_data: Dictionary = {}
var is_transitioning: bool = false

var transition_layer: CanvasLayer = null
var transition_rect: ColorRect = null

var _current_z_counter: int = 100
var _next_entity_uid: int = 1

var _theme_icon_cache: Dictionary = {}
var _popup_icon_cache: Dictionary = {}

var active_theme_cache: Dictionary = {}

signal universe_changed(new_universe_id: String)
signal room_changed(new_room_id: String, departing_room_id: String, traveler_data: Dictionary)
signal global_atmosphere_changed(time_preset: String, weather_preset: String)
signal theme_changed(theme_data: Dictionary)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_enforce_engine_viewport_scaling()
	_initialize_filesystem()
	_load_session()
	_sync_theme_from_service()
	_ensure_universe_directories(current_universe_id)
	_build_transition_overlay()
	_connect_event_bus_signals()


func _connect_event_bus_signals() -> void:
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb == null:
		return
	if eb.has_signal("theme_changed") and not eb.theme_changed.is_connected(_on_event_bus_theme_changed):
		eb.theme_changed.connect(_on_event_bus_theme_changed)
	if eb.has_signal("room_changed") and not eb.room_changed.is_connected(_on_event_bus_room_changed):
		eb.room_changed.connect(_on_event_bus_room_changed)
	if eb.has_signal("universe_changed") and not eb.universe_changed.is_connected(_on_event_bus_universe_changed):
		eb.universe_changed.connect(_on_event_bus_universe_changed)


func _on_event_bus_room_changed(new_room: String, departing_room: String, traveler_data: Dictionary) -> void:
	current_room_id = new_room
	_write_session_file()
	room_changed.emit(new_room, departing_room, traveler_data)


func _on_event_bus_universe_changed(new_u_id: String, new_u_name: String) -> void:
	current_universe_id = new_u_id
	current_universe_name = new_u_name
	_write_session_file()
	universe_changed.emit(new_u_id)


func _enforce_engine_viewport_scaling() -> void:
	var window: Window = get_window()
	if window == null:
		return
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	window.content_scale_size = BASE_CANVAS_SIZE


func _initialize_filesystem() -> void:
	var paths: Array[String] = [
		PATH_SAVES_ROOT, PATH_UNIVERSES_DIR, PATH_MAPS_DIR
	]
	for path: String in paths:
		if not DirAccess.dir_exists_absolute(path):
			DirAccess.make_dir_recursive_absolute(path)

	UGCManager.ensure_all_directories()


func _ensure_universe_directories(universe_id: String) -> void:
	var universe_directory: String = get_universe_save_dir(universe_id)
	if not DirAccess.dir_exists_absolute(universe_directory):
		DirAccess.make_dir_recursive_absolute(universe_directory)


func _load_session() -> void:
	if not FileAccess.file_exists(PATH_SESSION_FILE):
		current_universe_id = "default_universe"
		current_universe_name = "Default Universe"
		current_room_id = "room_main"
		global_time_preset = "day"
		global_weather_preset = "none"
		_write_session_file()
		return

	var file: FileAccess = FileAccess.open(PATH_SESSION_FILE, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if not parsed is Dictionary:
		return

	var data: Dictionary = parsed as Dictionary
	current_universe_id = str(data.get("universe_id", "default_universe")).strip_edges()
	current_universe_name = str(data.get("universe_name", "Default Universe")).strip_edges()
	current_room_id = str(data.get("room_id", "room_main")).strip_edges()
	global_time_preset = str(data.get("time_preset", "day")).strip_edges().to_lower()
	global_weather_preset = str(data.get("weather_preset", "none")).strip_edges().to_lower()

	if current_universe_id.is_empty(): current_universe_id = "default_universe"
	if current_universe_name.is_empty(): current_universe_name = "Default Universe"
	if current_room_id.is_empty(): current_room_id = "room_main"
	if global_time_preset.is_empty(): global_time_preset = "day"
	if global_weather_preset.is_empty(): global_weather_preset = "none"


func _write_session_file() -> void:
	var payload: Dictionary = {
		"universe_id": current_universe_id,
		"universe_name": current_universe_name,
		"room_id": current_room_id,
		"time_preset": global_time_preset,
		"weather_preset": global_weather_preset
	}
	var file: FileAccess = FileAccess.open(PATH_SESSION_FILE, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file.close()


func save_session() -> void:
	_write_session_file()


func get_universe_save_dir(universe_id: String = "") -> String:
	var resolved_id: String = universe_id if not universe_id.is_empty() else current_universe_id
	return PATH_SAVES_ROOT.path_join(resolved_id).path_join("rooms") + "/"

func get_universe_map_path(universe_id: String = "") -> String:
	var resolved_id: String = universe_id if not universe_id.is_empty() else current_universe_id
	return PATH_MAPS_DIR.path_join(resolved_id + "_map.json")

func get_universe_cast_path(universe_id: String = "") -> String:
	var resolved_id: String = universe_id if not universe_id.is_empty() else current_universe_id
	return PATH_UNIVERSES_DIR.path_join(resolved_id + "_cast.json")

func get_universe_journal_path(universe_id: String = "") -> String:
	var resolved_id: String = universe_id if not universe_id.is_empty() else current_universe_id
	return PATH_UNIVERSES_DIR.path_join(resolved_id + "_journal.json")

func get_saved_props_path(universe_id: String = "") -> String:
	var resolved_id: String = universe_id if not universe_id.is_empty() else current_universe_id
	return UGCManager.get_templates_directory().path_join(resolved_id + "_props.json")

func get_saved_furniture_path(universe_id: String = "") -> String:
	var resolved_id: String = universe_id if not universe_id.is_empty() else current_universe_id
	return UGCManager.get_templates_directory().path_join(resolved_id + "_furniture.json")


func get_all_universe_character_data() -> Array[Dictionary]:
	var roster: Dictionary = {}
	var seen_names: Dictionary = {}

	var tree: SceneTree = get_tree()
	if tree != null:
		for node: Node in tree.get_nodes_in_group("characters"):
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

	var cast_path: String = get_universe_cast_path(current_universe_id)
	if FileAccess.file_exists(cast_path):
		var cast_file: FileAccess = FileAccess.open(cast_path, FileAccess.READ)
		if cast_file != null:
			var parsed: Variant = JSON.parse_string(cast_file.get_as_text())
			cast_file.close()
			if parsed is Array:
				for item: Variant in (parsed as Array):
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

	var save_dir: String = get_universe_save_dir(current_universe_id)
	if DirAccess.dir_exists_absolute(save_dir):
		var dir: DirAccess = DirAccess.open(save_dir)
		if dir != null:
			dir.list_dir_begin()
			var file_name: String = dir.get_next()
			while not file_name.is_empty():
				if not dir.current_is_dir() and file_name.ends_with(".json"):
					var room_path: String = save_dir.path_join(file_name)
					var room_file: FileAccess = FileAccess.open(room_path, FileAccess.READ)
					if room_file != null:
						var room_parsed: Variant = JSON.parse_string(room_file.get_as_text())
						room_file.close()
						if room_parsed is Dictionary:
							var entities: Array = (room_parsed as Dictionary).get("entities", [])
							for entity_object: Variant in entities:
								if not entity_object is Dictionary:
									continue
								var entity_data: Dictionary = (entity_object as Dictionary).duplicate(true)
								if int(entity_data.get("entity_type", 0)) != 1:
									continue
								var entity_id: String = str(entity_data.get("id", ""))
								var entity_name: String = str(entity_data.get("display_name", "")).strip_edges().to_lower()
								if entity_id.is_empty() or roster.has(entity_id):
									continue
								if not entity_name.is_empty() and seen_names.has(entity_name):
									continue
								roster[entity_id] = entity_data
								if not entity_name.is_empty():
									seen_names[entity_name] = true
				file_name = dir.get_next()
			dir.list_dir_end()

	var result: Array[Dictionary] = []
	for value: Variant in roster.values():
		if value is Dictionary:
			result.append(value as Dictionary)
	return result


func update_universe_character_data(char_data: Dictionary) -> void:
	SaveSystem.update_character_data_in_cast(char_data)


func clear_current_universe_rooms(universe_id: String = "") -> void:
	var resolved_id: String = universe_id if not universe_id.is_empty() else current_universe_id
	var save_dir: String = get_universe_save_dir(resolved_id)
	if not DirAccess.dir_exists_absolute(save_dir):
		return
	var dir: DirAccess = DirAccess.open(save_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			DirAccess.remove_absolute(save_dir.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()


func get_next_z_index() -> int:
	_current_z_counter += 1
	if _current_z_counter > 900:
		_current_z_counter = 100
	return _current_z_counter


func generate_entity_uuid(base_name: String) -> String:
	var sanitized: String = base_name.validate_node_name()
	if sanitized.is_empty():
		sanitized = "entity"
	var result: String = "%s_%d" % [sanitized, _next_entity_uid]
	_next_entity_uid += 1
	return result


func set_global_time(preset_name: String) -> void:
	global_time_preset = preset_name.strip_edges().to_lower()
	_write_session_file()
	global_atmosphere_changed.emit(global_time_preset, global_weather_preset)
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("global_atmosphere_changed"):
		eb.emit_signal("global_atmosphere_changed", global_time_preset, global_weather_preset)


func set_global_weather(weather_name: String) -> void:
	global_weather_preset = weather_name.strip_edges().to_lower()
	_write_session_file()
	global_atmosphere_changed.emit(global_time_preset, global_weather_preset)
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("global_atmosphere_changed"):
		eb.emit_signal("global_atmosphere_changed", global_time_preset, global_weather_preset)


func switch_universe(new_u_id: String, new_u_name: String, starting_room: String = "room_main") -> void:
	var resolved_id: String = new_u_id.strip_edges()
	if resolved_id.is_empty(): resolved_id = "default_universe"
	var resolved_name: String = new_u_name.strip_edges()
	if resolved_name.is_empty(): resolved_name = "Default Universe"

	_ensure_universe_directories(resolved_id)
	current_universe_id = resolved_id
	current_universe_name = resolved_name
	current_room_id = starting_room if not starting_room.is_empty() else "room_main"

	_write_session_file()
	universe_changed.emit(current_universe_id)
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("universe_changed"):
		eb.emit_signal("universe_changed", current_universe_id, current_universe_name)


func get_theme_corner_radius() -> int: return ThemeService.get_corner_radius()
func get_theme_color(color_key: String, fallback_hex: String = "#ffffff") -> Color: return ThemeService.get_color(color_key, fallback_hex)
func create_theme_resource() -> Theme: return ThemeService.create_theme()
func apply_global_theme_to_tree() -> void: ThemeService.apply_theme_globally()

func update_active_theme_cache(theme_data: Dictionary) -> void:
	active_theme_cache = theme_data.duplicate(true)
	clear_theme_icon_cache()
	ThemeService.apply_theme(active_theme_cache)
	theme_changed.emit(active_theme_cache)

func _on_event_bus_theme_changed(theme_data: Dictionary) -> void:
	active_theme_cache = theme_data.duplicate(true)
	clear_theme_icon_cache()
	theme_changed.emit(active_theme_cache)

func _sync_theme_from_service() -> void:
	active_theme_cache = ThemeService.get_theme_data()
	clear_theme_icon_cache()

func save_theme_to_disk() -> void: ThemeService.save_theme_to_disk()
func get_theme_icon(icon_name: String, _optional_tint: Color = Color.TRANSPARENT) -> Texture2D: return ThemeService.get_icon(icon_name)
func get_popup_icon(icon_name: String) -> Texture2D: return ThemeService.get_popup_icon(icon_name)

func clear_theme_icon_cache() -> void:
	_theme_icon_cache.clear()
	_popup_icon_cache.clear()
	ThemeService.clear_icon_cache()


func factory_reset_entire_game() -> void:
	_wipe_dir_recursive("user://")
	_initialize_filesystem()

	current_universe_id = "default_universe"
	current_universe_name = "Default Universe"
	current_room_id = "room_main"
	global_time_preset = "day"
	global_weather_preset = "none"

	_write_session_file()
	ThemeService.reset_to_default_theme()
	get_tree().reload_current_scene()


func _wipe_dir_recursive(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
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


func _build_transition_overlay() -> void:
	transition_layer = CanvasLayer.new()
	transition_layer.name = "TransitionCanvas"
	transition_layer.layer = 127
	add_child(transition_layer)

	transition_rect = ColorRect.new()
	transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.add_child(transition_rect)
