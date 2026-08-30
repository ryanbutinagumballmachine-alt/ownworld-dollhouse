# ==============================================================================
# OWNWORLD — ENTITY SOCKET COMPONENT
# File: res://Core/Entities/Components/EntitySocketComponent.gd
# Base Class: EntityComponent (class_name EntitySocketComponent)
#
# Responsibility: Spatial snap anchor registration, interaction zone bounds,
# parent-child hierarchy cycle detection, and socket attachment transitions.
# ==============================================================================

class_name EntitySocketComponent
extends EntityComponent

const DEFAULT_INTERACTION_RADIUS: float = 55.0

var snap_points: Dictionary = {}
var interaction_points: Dictionary = {}

var parent_socket_entity: OwnEntity = null
var attached_socket_key: String = ""
var attached_children: Array[OwnEntity] = []


func get_component_key() -> StringName:
	return &"EntitySocketComponent"


func add_snap_point(socket_key: String, local_position: Vector2) -> void:
	var key: String = socket_key.strip_edges()
	if not key.is_empty():
		snap_points[key] = local_position


func remove_snap_point(socket_key: String) -> void:
	snap_points.erase(socket_key)


func has_snap_point(socket_key: String) -> bool:
	return snap_points.has(socket_key)


func get_snap_point(socket_key: String) -> Vector2:
	var value: Variant = snap_points.get(socket_key, Vector2.ZERO)
	return value as Vector2 if value is Vector2 else Vector2.ZERO


func add_interaction_point(point_key: String, local_offset: Vector2, radius: float = DEFAULT_INTERACTION_RADIUS, point_type: Types.InteractionPointType = Types.InteractionPointType.DEFAULT) -> void:
	var key: String = point_key.strip_edges()
	if not key.is_empty():
		interaction_points[key] = {
			"offset": local_offset,
			"radius": maxf(radius, 0.0),
			"type": int(point_type)
		}


func is_socket_occupied(socket_key: String) -> bool:
	for child: OwnEntity in attached_children:
		if is_instance_valid(child) and child.attached_socket_key == socket_key:
			return true
	return false


func can_attach_to(target_parent: OwnEntity, socket_key: String) -> bool:
	if not is_instance_valid(target_parent) or target_parent == entity:
		return false
	if _would_create_cycle(target_parent) or is_socket_occupied(socket_key):
		return false
	return _is_attachment_valid(target_parent, socket_key)


func _would_create_cycle(potential_parent: Node) -> bool:
	var current: Node = potential_parent
	while is_instance_valid(current):
		if current == entity:
			return true
		current = current.get_parent()
	return false


func _is_attachment_valid(target_parent: OwnEntity, socket_key: String) -> bool:
	if not is_instance_valid(entity):
		return false
	var key: String = socket_key.to_lower()
	if key == "sit_point":
		return false

	if target_parent.entity_type == Types.EntityType.CHARACTER:
		if key.begins_with("hand") or key.begins_with("head") or key.begins_with("face") or key.begins_with("back") or key.begins_with("neck") or key.begins_with("hold"):
			return entity.entity_type == Types.EntityType.PROP
		return false

	if target_parent.entity_type == Types.EntityType.FURNITURE:
		if key.begins_with("seat") or key.begins_with("bed"):
			return entity.entity_type == Types.EntityType.CHARACTER
		if key.begins_with("surface") or key.begins_with("hang") or key.begins_with("hook") or key.begins_with("shelf"):
			return entity.entity_type == Types.EntityType.PROP
		return false

	if target_parent.entity_type == Types.EntityType.CONTAINER:
		return entity.entity_type == Types.EntityType.PROP

	return false


func get_incoming_anchor_world_position(socket_key: String) -> Vector2:
	if not is_instance_valid(entity):
		return Vector2.ZERO

	var key: String = socket_key.to_lower()

	if key.begins_with("seat") or key.begins_with("bed"):
		if snap_points.has("sit_point"):
			return entity.to_global(snap_points["sit_point"])
		return entity.global_position + Vector2(0.0, entity.get_visual_bottom_offset())

	if key.begins_with("hand") or key.begins_with("hold"):
		for grip_key: String in ["grip", "handle", "hold_point"]:
			if snap_points.has(grip_key):
				return entity.to_global(snap_points[grip_key])

	if key.begins_with("head") or key.begins_with("hat"):
		if snap_points.has("mount"):
			return entity.to_global(snap_points["mount"])

	if key.begins_with("surface") or key.begins_with("shelf"):
		return entity.global_position + Vector2(0.0, entity.get_visual_bottom_offset())

	return entity.global_position


func attach_to_socket(target_parent: OwnEntity, socket_key: String, is_instant: bool = false) -> bool:
	if not is_instance_valid(entity) or not can_attach_to(target_parent, socket_key):
		return false

	var previous_parent: OwnEntity = parent_socket_entity
	if is_instance_valid(previous_parent):
		previous_parent.attached_children.erase(entity)

	parent_socket_entity = target_parent
	attached_socket_key = socket_key

	if not target_parent.attached_children.has(entity):
		target_parent.attached_children.append(entity)

	var start_world_position: Vector2 = entity.global_position
	entity.reparent(target_parent, false)

	var anchor_position: Vector2 = target_parent.to_global(target_parent.snap_points.get(socket_key, Vector2.ZERO))
	var parent_scale_x: float = target_parent.scale.x if not is_zero_approx(target_parent.scale.x) else 1.0
	var parent_scale_y: float = target_parent.scale.y if not is_zero_approx(target_parent.scale.y) else 1.0

	var child_scale: Vector2 = Vector2(
		(-entity.entity_scale if entity.is_flipped_h else entity.entity_scale) / parent_scale_x,
		entity.entity_scale / parent_scale_y
	)

	var target_rotation: float = 0.0

	if target_parent.entity_type == Types.EntityType.FURNITURE:
		if socket_key.begins_with("seat"):
			entity.set_entity_state(Types.EntityState.SITTING)
			entity.set_pose_state("sitting")
			if snap_points.has("sit_point"):
				var sit_point: Vector2 = snap_points["sit_point"]
				var parent_abs_scale_x: float = absf(parent_scale_x) if not is_zero_approx(absf(parent_scale_x)) else 1.0
				anchor_position.x -= (sit_point.x if not entity.is_flipped_h else -sit_point.x) * (entity.entity_scale / parent_abs_scale_x)
				anchor_position.y -= (sit_point.y * entity.entity_scale / parent_scale_y)
		elif socket_key.begins_with("bed"):
			entity.set_entity_state(Types.EntityState.SLEEPING)
			entity.set_pose_state("sleeping")
			target_rotation = -PI * 0.5
	elif target_parent.entity_type == Types.EntityType.CHARACTER:
		entity.set_entity_state(Types.EntityState.HELD)

	var local_anchor: Vector2 = target_parent.to_local(anchor_position)
	entity.z_as_relative = true
	entity.z_index = 1
	entity.rotation = target_rotation
	entity.scale = child_scale

	_kill_entity_tween()

	if is_instant:
		entity.position = local_anchor
		return true

	entity.position = target_parent.to_local(start_world_position)
	entity.active_tween = entity.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	entity.active_tween.tween_property(entity, "position", local_anchor, 0.28)

	if socket_key.begins_with("seat"):
		entity.active_tween.chain().tween_property(entity, "scale", child_scale * Vector2(1.05, 0.95), 0.08).set_trans(Tween.TRANS_SINE)
		entity.active_tween.chain().tween_property(entity, "scale", child_scale, 0.12).set_trans(Tween.TRANS_SINE)

	return true


func detach_from_socket(new_canvas_parent: Node2D) -> void:
	if not is_instance_valid(new_canvas_parent) or not is_instance_valid(entity):
		return

	var previous_parent: OwnEntity = parent_socket_entity
	if is_instance_valid(previous_parent):
		previous_parent.attached_children.erase(entity)

	var world_position: Vector2 = entity.global_position
	entity.reparent(new_canvas_parent, false)
	entity.global_position = world_position

	entity.z_as_relative = false
	entity.z_index = entity.base_layer_band
	entity.rotation = 0.0
	entity.scale = Vector2(-entity.entity_scale if entity.is_flipped_h else entity.entity_scale, entity.entity_scale)

	parent_socket_entity = null
	attached_socket_key = ""
	entity.set_entity_state(Types.EntityState.IDLE)
	entity.set_pose_state("default")


func serialize() -> Dictionary:
	var serialized_snap_points: Dictionary = {}
	for key: String in snap_points.keys():
		var point: Vector2 = snap_points[key] as Vector2
		serialized_snap_points[key] = {"x": point.x, "y": point.y}

	var serialized_interactions: Dictionary = {}
	for key: String in interaction_points.keys():
		var data: Dictionary = interaction_points[key]
		var offset_pos: Vector2 = data.get("offset", Vector2.ZERO) as Vector2
		serialized_interactions[key] = {
			"offset_x": offset_pos.x,
			"offset_y": offset_pos.y,
			"radius": float(data.get("radius", DEFAULT_INTERACTION_RADIUS)),
			"type": int(data.get("type", 0))
		}

	return {
		"snap_points": serialized_snap_points,
		"interaction_points": serialized_interactions,
		"parent_socket_entity_id": parent_socket_entity.entity_id if is_instance_valid(parent_socket_entity) else "",
		"attached_socket_key": attached_socket_key
	}


func deserialize(data: Dictionary) -> void:
	snap_points.clear()
	interaction_points.clear()

	var raw_snap_points: Variant = data.get("snap_points", {})
	if raw_snap_points is Dictionary:
		for key: String in (raw_snap_points as Dictionary).keys():
			var raw_point: Variant = raw_snap_points[key]
			if raw_point is Dictionary:
				var point_data: Dictionary = raw_point as Dictionary
				snap_points[key] = Vector2(float(point_data.get("x", 0.0)), float(point_data.get("y", 0.0)))

	var raw_interactions: Variant = data.get("interaction_points", {})
	if raw_interactions is Dictionary:
		for key: String in (raw_interactions as Dictionary).keys():
			var raw_value: Variant = raw_interactions[key]
			if raw_value is Dictionary:
				var point_data: Dictionary = raw_value as Dictionary
				interaction_points[key] = {
					"offset": Vector2(float(point_data.get("offset_x", 0.0)), float(point_data.get("offset_y", 0.0))),
					"radius": float(point_data.get("radius", DEFAULT_INTERACTION_RADIUS)),
					"type": int(point_data.get("type", 0))
				}

	attached_socket_key = str(data.get("attached_socket_key", ""))


func _kill_entity_tween() -> void:
	if is_instance_valid(entity) and entity.active_tween != null and entity.active_tween.is_valid():
		entity.active_tween.kill()
