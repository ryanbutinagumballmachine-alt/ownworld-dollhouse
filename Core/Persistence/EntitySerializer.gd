# ==============================================================================
# OWNWORLD — ENTITY SERIALIZER
# File: res://Core/Persistence/EntitySerializer.gd
# Base Class: RefCounted (class_name EntitySerializer)
#
# Responsibility: High-speed extraction and hierarchy bundle serialization for
# runtime OwnEntity node trees.
# ==============================================================================

class_name EntitySerializer
extends RefCounted


static func serialize_entity(entity: OwnEntity) -> Dictionary:
	if entity == null or not is_instance_valid(entity):
		return {}
	return entity.to_dict().duplicate(true)


static func serialize_roots(entities: Array[OwnEntity]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entity: OwnEntity in entities:
		if is_instance_valid(entity) and entity.parent_socket_entity == null:
			result.append_array(entity.get_full_hierarchy_bundle())
	return result


static func sanitize_entity_array(raw_entities: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in raw_entities:
		if value is Dictionary:
			var entity_data: Dictionary = (value as Dictionary).duplicate(true)
			var entity_id: String = str(entity_data.get("id", "")).strip_edges()
			if not entity_id.is_empty():
				result.append(entity_data)
	return result
