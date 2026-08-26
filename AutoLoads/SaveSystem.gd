# ==============================================================================
# OWNWORLD — PERSISTENCE SERVICE (COMPLETE ROOM METADATA & ENTITY PERSISTENCE)
# File: res://AutoLoads/SaveSystem.gd
# Autoload: SaveSystem
# ==============================================================================

extends Node

const PATH_SESSION_FILE: String = "user://session.json"
const PATH_SAVES_ROOT: String = "user://saves/"
const PATH_UNIVERSES_DIR: String = "user://universes/"

const DEFAULT_UNIVERSE_ID: String = "default_universe"
const DEFAULT_ROOM_ID: String = "room_main"

signal room_saved(room_id: String)
signal room_loaded(room_id: String)
signal cast_saved()
signal journal_saved(universe_id: String)


func get_current_universe_id() -> String:
	var session: Dictionary = _load_session()
	var universe_id: String = str(session.get("universe_id", DEFAULT_UNIVERSE_ID)).strip_edges()
	return universe_id if not universe_id.is_empty() else DEFAULT_UNIVERSE_ID

# Helper to retrieve all rooms/floors belonging to a specific building in the current universe
func get_building_floors(building_id: String, universe_id: String = "") -> Array[Dictionary]:
	var resolved_bldg_id: String = building_id.strip_edges()
	var save_dir: String = get_universe_save_dir(universe_id)
	var floors: Array[Dictionary] = []

	if not DirAccess.dir_exists_absolute(save_dir):
		return floors

	var dir: DirAccess = DirAccess.open(save_dir)
	if dir == null: return floors

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".json") and file_name != "recipes.json":
			var room_path: String = save_dir.path_join(file_name)
			var room_state: Dictionary = JsonFileStore.read_dictionary(room_path)
			if str(room_state.get("building_id", "building_main")) == resolved_bldg_id:
				floors.append({
					"room_id": str(room_state.get("room_id", file_name.trim_suffix(".json"))),
					"floor_level": str(room_state.get("floor_level", "1F")),
					"label": "%s %s" % [str(room_state.get("floor_level", "1F")), str(room_state.get("room_title", "Room"))]
				})
		file_name = dir.get_next()
	dir.list_dir_end()

	return floors

# Gets the 1F / ground entry room ID for a building
func get_building_entry_room_id(building_id: String, universe_id: String = "") -> String:
	var floors: Array[Dictionary] = get_building_floors(building_id, universe_id)
	for floor_item: Dictionary in floors:
		if str(floor_item.get("floor_level", "")).to_upper() == "1F":
			return str(floor_item.get("room_id", ""))
	if not floors.is_empty():
		return str(floors[0].get("room_id", ""))
	
	# Clean fallback
	return building_id + "_1f" if building_id != "building_main" else "room_main"

func get_current_room_id() -> String:
	var session: Dictionary = _load_session()
	var room_id: String = str(session.get("room_id", DEFAULT_ROOM_ID)).strip_edges()
	return room_id if not room_id.is_empty() else DEFAULT_ROOM_ID


func get_current_universe_name() -> String:
	var session: Dictionary = _load_session()
	var universe_name: String = str(session.get("universe_name", "Default Universe")).strip_edges()
	return universe_name if not universe_name.is_empty() else "Default Universe"


func get_universe_save_dir(universe_id: String = "") -> String:
	var cleaned_id: String = universe_id.strip_edges()
	var resolved_id: String = cleaned_id if not cleaned_id.is_empty() else get_current_universe_id()
	return PATH_SAVES_ROOT + resolved_id + "/rooms/"


func get_universe_cast_path(universe_id: String = "") -> String:
	var cleaned_id: String = universe_id.strip_edges()
	var resolved_id: String = cleaned_id if not cleaned_id.is_empty() else get_current_universe_id()
	return PATH_UNIVERSES_DIR + resolved_id + "_cast.json"


func get_universe_journal_path(universe_id: String = "") -> String:
	var cleaned_id: String = universe_id.strip_edges()
	var resolved_id: String = cleaned_id if not cleaned_id.is_empty() else get_current_universe_id()
	return PATH_UNIVERSES_DIR + resolved_id + "_journal.json"


func save_current_room_state() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var room_id: String = get_current_room_id()
	var main_node: Node = tree.root.find_child("Main", true, false)
	if main_node == null:
		main_node = tree.current_scene
	if main_node == null or main_node.get("is_room_loaded") == false:
		return

	var room_payload: Dictionary = {}

	# Grab the complete serialized room state from Main (slices, floor_y, title, entities)
	if main_node.has_method("get_current_room_state"):
		room_payload = main_node.call("get_current_room_state")
	elif main_node.has_method("_serialize_state"):
		room_payload = main_node.call("_serialize_state")
	else:
		var entity_bundles: Array[Dictionary] = []
		var raw_entities: Variant = main_node.get("all_entities")
		if raw_entities is Array:
			for entity_variant: Variant in (raw_entities as Array):
				if not entity_variant is OwnEntity or not is_instance_valid(entity_variant):
					continue
				var entity: OwnEntity = entity_variant as OwnEntity
				if entity.parent_socket_entity == null:
					entity_bundles.append_array(entity.get_full_hierarchy_bundle())
				if entity.entity_type == Types.EntityType.CHARACTER:
					update_character_in_cast(entity)
		room_payload = {"entities": entity_bundles}

	save_room_state(room_id, room_payload)


func update_character_in_cast(entity: OwnEntity) -> void:
	if not is_instance_valid(entity) or entity.entity_type != Types.EntityType.CHARACTER:
		return
	update_character_data_in_cast(entity.to_dict())


func update_character_data_in_cast(char_data: Dictionary) -> void:
	var character_id: String = str(char_data.get("id", "")).strip_edges()
	var character_name: String = str(char_data.get("display_name", "")).strip_edges()
	var name_key: String = character_name.to_lower()

	if character_id.is_empty() and character_name.is_empty():
		return

	# 1. Instantly update live in-room entities in memory
	sync_live_character_entities(char_data)

	# 2. Persist to cast repository
	var cast_path: String = get_universe_cast_path()
	var cast_list: Array[Dictionary] = []

	if FileAccess.file_exists(cast_path):
		var file: FileAccess = FileAccess.open(cast_path, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Array:
				for item: Variant in (parsed as Array):
					if item is Dictionary:
						cast_list.append((item as Dictionary).duplicate(true))

	var updated: bool = false
	for index: int in range(cast_list.size()):
		var cast_entry: Dictionary = cast_list[index]
		var id_matches: bool = not character_id.is_empty() and str(cast_entry.get("id", "")) == character_id
		var name_matches: bool = not name_key.is_empty() and str(cast_entry.get("display_name", "")).strip_edges().to_lower() == name_key
		if id_matches or name_matches:
			cast_list[index] = char_data.duplicate(true)
			updated = true
			break

	if not updated:
		cast_list.append(char_data.duplicate(true))

	if not DirAccess.dir_exists_absolute(PATH_UNIVERSES_DIR):
		DirAccess.make_dir_recursive_absolute(PATH_UNIVERSES_DIR)

	var write_file: FileAccess = FileAccess.open(cast_path, FileAccess.WRITE)
	if write_file != null:
		write_file.store_string(JSON.stringify(cast_list, "\t"))
		write_file.flush()
		write_file.close()
		cast_saved.emit()

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("character_data_changed"):
		eb.emit_signal("character_data_changed", character_id, char_data.duplicate(true))


func sync_live_character_entities(char_data: Dictionary) -> void:
	var character_id: String = str(char_data.get("id", "")).strip_edges()
	var character_name: String = str(char_data.get("display_name", "")).strip_edges()
	var name_key: String = character_name.to_lower()

	var tree: SceneTree = get_tree()
	if tree != null:
		for node: Node in tree.get_nodes_in_group("characters"):
			if not is_instance_valid(node):
				continue
			var node_id: String = str(node.get("entity_id"))
			var node_name: String = str(node.get("display_name")).strip_edges().to_lower()
			if (not character_id.is_empty() and node_id == character_id) or (not name_key.is_empty() and node_name == name_key):
				if node.has_method("update_character_profile"):
					node.call("update_character_profile", char_data)
				elif node.has_method("from_dict"):
					node.call("from_dict", char_data)


func save_room_state(room_id: String, room_data: Dictionary) -> bool:
	var resolved_room_id: String = room_id.strip_edges()
	if resolved_room_id.is_empty():
		resolved_room_id = DEFAULT_ROOM_ID

	var save_dir: String = get_universe_save_dir()
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)

	var file_path: String = save_dir + resolved_room_id + ".json"
	var temp_path: String = file_path + ".tmp"

	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(room_data, "\t"))
	file.flush()
	file.close()

	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)

	var rename_error: Error = DirAccess.rename_absolute(temp_path, file_path)
	if rename_error == OK:
		room_saved.emit(resolved_room_id)
		return true
	return false


func load_room_state(room_id: String) -> Dictionary:
	var resolved_room_id: String = room_id.strip_edges()
	if resolved_room_id.is_empty():
		resolved_room_id = DEFAULT_ROOM_ID

	var file_path: String = get_universe_save_dir() + resolved_room_id + ".json"
	if not FileAccess.file_exists(file_path):
		return {}

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}

	var content: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(content)
	if parsed is Dictionary:
		var normalized: Dictionary = SaveSchema.normalize_room(parsed as Dictionary, resolved_room_id)
		room_loaded.emit(resolved_room_id)
		return normalized
	return {}


func save_universe_journal(universe_id: String, journal_data: Dictionary) -> bool:
	var target_id: String = universe_id.strip_edges()
	if target_id.is_empty(): target_id = get_current_universe_id()
	if target_id.is_empty(): target_id = DEFAULT_UNIVERSE_ID

	var file_path: String = get_universe_journal_path(target_id)
	var temp_path: String = file_path + ".tmp"

	if not DirAccess.dir_exists_absolute(PATH_UNIVERSES_DIR):
		DirAccess.make_dir_recursive_absolute(PATH_UNIVERSES_DIR)

	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(journal_data, "\t"))
	file.flush()
	file.close()

	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)

	var rename_error: Error = DirAccess.rename_absolute(temp_path, file_path)
	if rename_error == OK:
		journal_saved.emit(target_id)
		return true
	return false


func load_universe_journal(universe_id: String) -> Dictionary:
	var target_id: String = universe_id.strip_edges()
	if target_id.is_empty(): target_id = get_current_universe_id()
	if target_id.is_empty(): target_id = DEFAULT_UNIVERSE_ID

	var file_path: String = get_universe_journal_path(target_id)
	if not FileAccess.file_exists(file_path):
		return {"timeline": [], "factions": []}

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {"timeline": [], "factions": []}

	var content: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(content)
	if parsed is Dictionary:
		var data: Dictionary = parsed as Dictionary
		if not data.has("timeline"): data["timeline"] = []
		if not data.has("factions"): data["factions"] = []
		return data
	return {"timeline": [], "factions": []}


func _load_session() -> Dictionary:
	var default_session: Dictionary = {
		"universe_id": DEFAULT_UNIVERSE_ID,
		"universe_name": "Default Universe",
		"room_id": DEFAULT_ROOM_ID,
		"time_preset": "day",
		"weather_preset": "none"
	}
	if not FileAccess.file_exists(PATH_SESSION_FILE):
		return default_session

	var file: FileAccess = FileAccess.open(PATH_SESSION_FILE, FileAccess.READ)
	if file == null:
		return default_session

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return parsed as Dictionary
		
	return default_session
