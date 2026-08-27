# ==============================================================================
# OWNWORLD — SOCKET RESOLVER
# File: res://Systems/SocketManager.gd
# Base Class: RefCounted (class_name SocketManager)
#
# Responsibility: Evaluates proximity snapping between dragged items and host
# entities (holding hands, sitting on chairs, wearing hats/glasses, surface props).
# ==============================================================================

class_name SocketManager
extends RefCounted

const SNAP_RADIUS: float = 38.0


static func evaluate_and_snap(dropped_entity: OwnEntity, all_entities: Array[OwnEntity]) -> bool:
	if dropped_entity == null or not is_instance_valid(dropped_entity):
		return false

	var best_target: OwnEntity = null
	var best_socket_key: String = ""
	var closest_distance: float = SNAP_RADIUS

	for target_entity: OwnEntity in all_entities:
		if target_entity == null or not is_instance_valid(target_entity) or target_entity == dropped_entity:
			continue

		for socket_key: String in target_entity.snap_points.keys():
			if not is_socket_compatible(dropped_entity, target_entity, socket_key):
				continue
			if is_socket_occupied(target_entity, socket_key):
				continue

			var target_socket_world: Vector2 = target_entity.to_global(target_entity.snap_points[socket_key])
			var incoming_anchor_world: Vector2 = _get_incoming_anchor_world_pos(dropped_entity, socket_key)
			var distance: float = incoming_anchor_world.distance_to(target_socket_world)

			if distance < closest_distance:
				closest_distance = distance
				best_target = target_entity
				best_socket_key = socket_key

	if best_target == null or best_socket_key.is_empty():
		return false

	var success: bool = dropped_entity.attach_to_socket(best_target, best_socket_key)
	if not success:
		return false

	AudioManager.play_snap_chime()
	best_target.spray_emotion("❤️")
	EventBus.interaction_completed.emit(dropped_entity.entity_id, best_target.entity_id)
	return true


static func _get_incoming_anchor_world_pos(incoming: OwnEntity, socket_key: String) -> Vector2:
	var socket_name: String = socket_key.to_lower()

	if socket_name.begins_with("seat") or socket_name.begins_with("bed"):
		if incoming.snap_points.has("sit_point"):
			return incoming.to_global(incoming.snap_points["sit_point"])
		return incoming.global_position + Vector2(0.0, incoming.get_visual_bottom_offset())

	if socket_name.begins_with("hand") or socket_name.begins_with("hold"):
		for grip_key: String in ["grip", "handle", "hold_point"]:
			if incoming.snap_points.has(grip_key):
				return incoming.to_global(incoming.snap_points[grip_key])

	if socket_name.begins_with("head") or socket_name.begins_with("hat"):
		if incoming.snap_points.has("mount"):
			return incoming.to_global(incoming.snap_points["mount"])

	if socket_name.begins_with("surface") or socket_name.begins_with("shelf"):
		return incoming.global_position + Vector2(0.0, incoming.get_visual_bottom_offset())

	return incoming.global_position


static func is_socket_occupied(host: OwnEntity, socket_key: String) -> bool:
	if host == null or not is_instance_valid(host):
		return false
	for child: OwnEntity in host.attached_children:
		if child != null and is_instance_valid(child) and child.attached_socket_key == socket_key:
			return true
	return false


static func is_socket_compatible(incoming: OwnEntity, host: OwnEntity, socket_key: String) -> bool:
	if incoming == null or host == null:
		return false
	var socket_name: String = socket_key.to_lower()
	if socket_name == "sit_point":
		return false

	if host.entity_type == Types.EntityType.CHARACTER:
		if socket_name.begins_with("hand") or socket_name.begins_with("head") or socket_name.begins_with("face") or socket_name.begins_with("back") or socket_name.begins_with("neck") or socket_name.begins_with("hold"):
			return incoming.entity_type == Types.EntityType.PROP
		return false

	if host.entity_type == Types.EntityType.FURNITURE:
		if socket_name.begins_with("seat") or socket_name.begins_with("bed"):
			return incoming.entity_type == Types.EntityType.CHARACTER
		if socket_name.begins_with("surface") or socket_name.begins_with("hang") or socket_name.begins_with("hook") or socket_name.begins_with("shelf"):
			return incoming.entity_type == Types.EntityType.PROP
		return false

	if host.entity_type == Types.EntityType.CONTAINER:
		return incoming.entity_type == Types.EntityType.PROP

	return false
