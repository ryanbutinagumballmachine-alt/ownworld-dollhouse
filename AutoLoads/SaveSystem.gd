# ==============================================================================
# OWNWORLD — PERSISTENCE SERVICE COORDINATOR
# File: res://AutoLoads/SaveSystem.gd
# Autoload Singleton: SaveSystem
# Base Class: Node
#
# Responsibility: Central coordinator for room files, cast rosters, building
# floor hierarchies, and universe journals with unified JSON schema compatibility.
# Uses in-memory AppState caching to eliminate redundant disk reads.
# ==============================================================================

extends Node

const PATH_SAVES_ROOT: String = "user://saves/"
const PATH_UNIVERSES_DIR: String = "user://universes/"

const DEFAULT_UNIVERSE_ID: String = "default_universe"
const DEFAULT_ROOM_ID: String = "room_main"

signal room_saved(room_id: String)
signal room_loaded(room_id: String)
signal cast_saved()
signal journal_saved(universe_id: String)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_initialize_directories()


func _initialize_directories() -> void:
	JsonFileStore.ensure_directory(PATH_SAVES_ROOT)
	JsonFileStore.ensure_directory(PATH_UNIVERSES_DIR)


## Reads current active universe ID directly from RAM (AppState).
func get_current_universe_id() -> String:
	var u_id: String = AppState.universe_id.strip_edges()
	return u_id if not u_id.is_empty() else DEFAULT_UNIVERSE_ID


## Reads current active room ID directly from RAM (AppState).
func get_current_room_id() -> String:
	var r_id: String = AppState.room_id.strip_edges()
	return r_id if not r_id.is_empty() else DEFAULT_ROOM_ID


## Reads current active universe display name directly from RAM (AppState).
func get_current_universe_name() -> String:
	var u_name: String = AppState.universe_name.strip_edges()
	return u_name if not u_name.is_empty() else "Default Universe"


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


static func get_floor_rank(floor_level_str: String) -> int:
	var s: String = floor_level_str.strip_edges().to_upper()
	if s.begins_with("B") and s.trim_prefix("B").is_valid_int():
		return -s.trim_prefix("B").to_int()
	if s.ends_with("F") and s.trim_suffix("F").is_valid_int():
		return s.trim_suffix("F").to_int()
	if s in ["G", "GF", "LG", "LOBBY", "GROUND"]:
		return 1
	if s in ["MEZZANINE"]:
		return 800
	if s in ["ATTIC"]:
		return 900
	if s in ["ROOF", "ROOFTOP"]:
		return 1000
	if s.is_valid_int():
		return s.to_int()
	return 1


## Retrieves all registered floors for a building in the universe.
func get_building_floors(building_id: String, universe_id: String = "") -> Array[Dictionary]:
	var resolved_bldg_id: String = building_id.strip_edges()
	var save_dir: String = get_universe_save_dir(universe_id)
	var floors: Array[Dictionary] = []

	if not DirAccess.dir_exists_absolute(save_dir):
		return floors

	var dir: DirAccess = DirAccess.open(save_dir)
	if not is_instance_valid(dir):
		return floors

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


## Finds the floor directly above the current active room in the same building.
func get_next_floor_above(building_id: String, current_room_id_str: String, universe_id: String = "") -> Dictionary:
	var floors: Array[Dictionary] = get_building_floors(building_id, universe_id)
	if floors.size() <= 1:
		return {}

	floors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var rank_a: int = get_floor_rank(str(a.get("floor_level", "1F")))
		var rank_b: int = get_floor_rank(str(b.get("floor_level", "1F")))
		return rank_a < rank_b
	)

	var current_index: int = -1
	for i: int in range(floors.size()):
		if str(floors[i].get("room_id", "")) == current_room_id_str:
			current_index = i
			break

	if current_index >= 0 and current_index + 1 < floors.size():
		return floors[current_index + 1]

	return {}


## Gets the entry level (1F) room ID for a building.
func get_building_entry_room_id(building_id: String, universe_id: String = "") -> String:
	var floors: Array[Dictionary] = get_building_floors(building_id, universe_id)
	for floor_item: Dictionary in floors:
		if str(floor_item.get("floor_level", "")).to_upper() == "1F":
			return str(floor_item.get("room_id", ""))
	if not floors.is_empty():
		return str(floors[0].get("room_id", ""))
	
	return building_id + "_1f" if building_id != "building_main" else "room_main"


## Saves the active room hierarchy state.
func save_current_room_state() -> void:
	var tree: SceneTree = get_tree()
	if not is_instance_valid(tree):
		return
	var target_room_id: String = get_current_room_id()
	var main_node: Node = tree.root.find_child("Main", true, false)
	if not is_instance_valid(main_node):
		main_node = tree.current_scene
	if not is_instance_valid(main_node) or main_node.get("is_room_loaded") == false:
		return

	var room_payload: Dictionary = {}
	if main_node.has_method("get_current_room_state"):
		room_payload = main_node.call("get_current_room_state")
	elif main_node.has_method("_serialize_state"):
		room_payload = main_node.call("_serialize_state")
	else:
		return

	save_room_state(target_room_id, room_payload)


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

	sync_live_character_entities(char_data)

	var cast_path: String = get_universe_cast_path()
	var cast_list: Array[Dictionary] = []

	if FileAccess.file_exists(cast_path):
		var file: FileAccess = FileAccess.open(cast_path, FileAccess.READ)
		if is_instance_valid(file):
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			file.close()
			var cast_items: Array = []
			if parsed is Array:
				cast_items = parsed as Array
			elif parsed is Dictionary:
				cast_items = (parsed as Dictionary).get("cast", (parsed as Dictionary).get("templates", []))

			for item: Variant in cast_items:
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

	JsonFileStore.ensure_directory(PATH_UNIVERSES_DIR)
	var success: bool = JsonFileStore.write_dictionary(cast_path, {"cast": cast_list})
	if success:
		cast_saved.emit()
		EventBus.character_data_changed.emit(character_id, char_data.duplicate(true))


func sync_live_character_entities(char_data: Dictionary) -> void:
	var character_id: String = str(char_data.get("id", "")).strip_edges()
	var character_name: String = str(char_data.get("display_name", "")).strip_edges()
	var name_key: String = character_name.to_lower()

	var tree: SceneTree = get_tree()
	if is_instance_valid(tree):
		for node: Node in tree.get_nodes_in_group(&"characters"):
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

	var success: bool = RoomRepository.save_room(get_current_universe_id(), resolved_room_id, room_data)
	if success:
		room_saved.emit(resolved_room_id)
		EventBus.room_saved.emit(resolved_room_id)
	return success


func load_room_state(room_id: String) -> Dictionary:
	var resolved_room_id: String = room_id.strip_edges()
	if resolved_room_id.is_empty():
		resolved_room_id = DEFAULT_ROOM_ID

	var data: Dictionary = RoomRepository.load_room(get_current_universe_id(), resolved_room_id)
	if not data.is_empty():
		room_loaded.emit(resolved_room_id)
		EventBus.room_loaded.emit(resolved_room_id)
	return data


func save_universe_journal(universe_id: String, journal_data: Dictionary) -> bool:
	var target_id: String = universe_id.strip_edges()
	if target_id.is_empty(): 
		target_id = get_current_universe_id()
	if target_id.is_empty(): 
		target_id = DEFAULT_UNIVERSE_ID

	var file_path: String = get_universe_journal_path(target_id)
	var success: bool = JsonFileStore.write_dictionary(file_path, journal_data)
	if success:
		journal_saved.emit(target_id)
		EventBus.journal_saved.emit(target_id)
	return success


func load_universe_journal(universe_id: String) -> Dictionary:
	var target_id: String = universe_id.strip_edges()
	if target_id.is_empty(): 
		target_id = get_current_universe_id()
	if target_id.is_empty(): 
		target_id = DEFAULT_UNIVERSE_ID

	var file_path: String = get_universe_journal_path(target_id)
	var data: Dictionary = JsonFileStore.read_dictionary(file_path)
	if not data.has("timeline"): 
		data["timeline"] = []
	if not data.has("factions"): 
		data["factions"] = []
	return data
