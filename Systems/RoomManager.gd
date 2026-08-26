# ==============================================================================
# OWNWORLD — ROOM MANAGER (HIERARCHY TRANSIT & MULTI-FLOOR RECONSTRUCTION)
# File: res://Systems/RoomManager.gd
# Base Class: RefCounted (class_name RoomManager)
# ==============================================================================

class_name RoomManager
extends RefCounted

const DEFAULT_FLOOR_Y: float = 600.0
const DEFAULT_ENTITY_ID: String = "entity"
const DEFAULT_ENTITY_NAME: String = "Item"
const DEFAULT_TEXTURE_SIZE: Vector2 = Vector2(64.0, 64.0)


static func stream_room(room_id: String, traveler_data: Dictionary, canvas: Node2D, all_entities: Array[OwnEntity]) -> void:
	if canvas == null:
		return

	clear_runtime_entities(canvas, all_entities)

	var saved_state: Dictionary = SaveSystem.load_room_state(room_id)
	if not saved_state.is_empty():
		deserialize_room_into_canvas(saved_state, canvas, all_entities)

	if not traveler_data.is_empty():
		var bundle: Array = traveler_data.get("bundle", [])
		if not bundle.is_empty():
			var spawn_position: Vector2 = resolve_traveler_spawn_position(traveler_data, all_entities)
			reconstruct_traveler_bundle(bundle, spawn_position, canvas, all_entities)


static func clear_runtime_entities(canvas: Node2D, all_entities: Array[OwnEntity]) -> void:
	for entity: OwnEntity in all_entities:
		if is_instance_valid(entity):
			entity.queue_free()
	all_entities.clear()

	if canvas != null:
		for child: Node in canvas.get_children():
			if child is OwnEntity and is_instance_valid(child):
				child.queue_free()


static func resolve_traveler_spawn_position(traveler_data: Dictionary, all_entities: Array[OwnEntity]) -> Vector2:
	if bool(traveler_data.get("arrival_elevator", false)):
		for entity: OwnEntity in all_entities:
			if is_instance_valid(entity) and entity.is_elevator:
				return entity.global_position

	for entity: OwnEntity in all_entities:
		if is_instance_valid(entity) and entity.is_portal and not entity.is_elevator:
			return entity.global_position + Vector2(100.0, 0.0)

	return Vector2(300.0, SaveSchema.DEFAULT_FLOOR_Y - 80.0)


static func reconstruct_traveler_bundle(bundle: Array, spawn_pos: Vector2, canvas: Node2D, all_entities: Array[OwnEntity]) -> void:
	if canvas == null or bundle.is_empty():
		return

	var lookup: Dictionary = {}
	for value: Variant in bundle:
		if value is Dictionary:
			var entity: OwnEntity = _create_entity_from_data(value as Dictionary, spawn_pos)
			if entity != null:
				canvas.add_child(entity)
				all_entities.append(entity)
				lookup[entity.entity_id] = entity

	_relink_hierarchy(bundle, lookup)


static func deserialize_room_into_canvas(snapshot: Dictionary, canvas: Node2D, all_entities: Array[OwnEntity]) -> void:
	if canvas == null:
		return
	clear_runtime_entities(canvas, all_entities)

	var raw_entities: Variant = snapshot.get("entities", [])
	if not raw_entities is Array:
		return

	var entity_data_list: Array = raw_entities as Array
	if entity_data_list.is_empty():
		return

	var lookup: Dictionary = {}
	for value: Variant in entity_data_list:
		if value is Dictionary:
			var entity_data: Dictionary = value as Dictionary
			var spawn_position: Vector2 = Vector2(float(entity_data.get("x", 0.0)), float(entity_data.get("y", 0.0)))
			var entity: OwnEntity = _create_entity_from_data(entity_data, spawn_position)
			if entity != null:
				canvas.add_child(entity)
				all_entities.append(entity)
				lookup[entity.entity_id] = entity

	_relink_hierarchy(entity_data_list, lookup)

	for entity: OwnEntity in all_entities:
		if is_instance_valid(entity):
			CapabilitySynchronizer.synchronize(entity)


static func _create_entity_from_data(entity_data: Dictionary, spawn_position: Vector2) -> OwnEntity:
	var entity_id: String = _read_entity_id(entity_data)
	var display_name: String = str(entity_data.get("display_name", entity_id if not entity_id.is_empty() else DEFAULT_ENTITY_NAME)).strip_edges()
	if display_name.is_empty(): display_name = DEFAULT_ENTITY_NAME

	var entity_type: Types.EntityType = _read_entity_type(entity_data)
	var texture_path: String = str(entity_data.get("texture_path", "")).strip_edges()
	var texture: Texture2D = _load_entity_texture(texture_path, entity_type)

	var entity: OwnEntity = OwnEntity.new()
	entity.setup(entity_id, display_name, texture, spawn_position, entity_type, texture_path)
	entity.from_dict(entity_data)

	if not entity_data.has("x"): entity.global_position = spawn_position
	if not entity_data.has("y"): entity.global_position.y = spawn_position.y

	CapabilitySynchronizer.synchronize(entity)
	return entity


static func _read_entity_id(entity_data: Dictionary) -> String:
	var value: String = str(entity_data.get("id", "")).strip_edges()
	return value if not value.is_empty() else AppState.generate_entity_uuid(str(entity_data.get("display_name", DEFAULT_ENTITY_ID)))


static func _read_entity_type(entity_data: Dictionary) -> Types.EntityType:
	var type_value: int = int(entity_data.get("entity_type", int(Types.EntityType.PROP)))
	if type_value < int(Types.EntityType.PROP) or type_value > int(Types.EntityType.APPLIANCE):
		return Types.EntityType.PROP
	return type_value as Types.EntityType


static func _load_entity_texture(texture_path: String, entity_type: Types.EntityType) -> Texture2D:
	var normalized_path: String = texture_path.strip_edges()
	if not normalized_path.is_empty():
		if normalized_path.begins_with("res://") and ResourceLoader.exists(normalized_path):
			var resource: Resource = load(normalized_path)
			if resource is Texture2D: return resource as Texture2D
		if (normalized_path.begins_with("user://") or not normalized_path.begins_with("res://")) and FileAccess.file_exists(normalized_path):
			var texture: Texture2D = UGCManager.load_texture_from_file(normalized_path)
			if texture != null: return texture

	var fallback_color: Color = Color.CORAL if entity_type == Types.EntityType.CHARACTER else Color.AQUAMARINE
	return UGCManager.create_blank_starter_graphic(DEFAULT_TEXTURE_SIZE, fallback_color)


static func _relink_hierarchy(raw_entities: Array, lookup: Dictionary) -> void:
	for value: Variant in raw_entities:
		if not value is Dictionary:
			continue
		var entity_data: Dictionary = value as Dictionary
		var child_id: String = str(entity_data.get("id", "")).strip_edges()
		var parent_id: String = str(entity_data.get("parent_socket_entity_id", "")).strip_edges()
		var socket_key: String = str(entity_data.get("attached_socket_key", "")).strip_edges()

		if child_id.is_empty() or parent_id.is_empty() or socket_key.is_empty():
			continue

		var child_entity: OwnEntity = lookup.get(child_id, null) as OwnEntity
		var parent_entity: OwnEntity = lookup.get(parent_id, null) as OwnEntity
		if child_entity != null and parent_entity != null and is_instance_valid(child_entity) and is_instance_valid(parent_entity) and child_entity != parent_entity:
			child_entity.attach_to_socket(parent_entity, socket_key, true)


static func collect_hierarchy(root_entity: OwnEntity) -> Array[OwnEntity]:
	var result: Array[OwnEntity] = []
	if root_entity == null or not is_instance_valid(root_entity):
		return result
	result.append(root_entity)
	for child: OwnEntity in root_entity.attached_children:
		if is_instance_valid(child):
			result.append_array(collect_hierarchy(child))
	return result


static func collect_root_entities(all_entities: Array[OwnEntity]) -> Array[OwnEntity]:
	var result: Array[OwnEntity] = []
	for entity: OwnEntity in all_entities:
		if is_instance_valid(entity) and entity.parent_socket_entity == null:
			result.append(entity)
	return result


static func validate_snapshot(snapshot: Dictionary) -> bool:
	if snapshot.is_empty(): return false
	var raw_entities: Variant = snapshot.get("entities", null)
	if not raw_entities is Array: return false

	var ids: Dictionary = {}
	for value: Variant in (raw_entities as Array):
		if not value is Dictionary: continue
		var entity_id: String = str((value as Dictionary).get("id", "")).strip_edges()
		if entity_id.is_empty() or ids.has(entity_id): return false
		ids[entity_id] = true
	return true
