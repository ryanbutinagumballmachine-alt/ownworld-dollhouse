# ==============================================================================
# OWNWORLD — WORLD INTERACTION CONTROLLER (HYPER OPTIMIZED)
# File: res://Systems/Interaction/WorldInteractionController.gd
# Base Class: Node
#
# Responsibility: Passive interaction API driven cleanly by HyperInputRouter.
# Decouples target selection from active physical dragging, eliminating
# premature audio triggers and double-tap sound spam.
# ==============================================================================

class_name WorldInteractionController
extends Node

var entity_root: Node2D = null
var interaction_router: EntityInteractionRouter = null
var all_entities: Array[OwnEntity] = []

var room_bounds: Rect2 = Rect2(0, 0, 1920, 1080)
var current_floor_y: float = 580.0

var active_dragged_entity: OwnEntity = null
var pressed_target_entity: OwnEntity = null
var drag_offset: Vector2 = Vector2.ZERO
var is_dragging: bool = false


func setup(p_entity_root: Node2D, p_router: EntityInteractionRouter, p_entities: Array[OwnEntity]) -> void:
	entity_root = p_entity_root
	interaction_router = p_router
	all_entities = p_entities
	set_process(false)


func _process(delta: float) -> void:
	if is_dragging and is_instance_valid(active_dragged_entity):
		InteractionSolver.process_live_interactions(delta, active_dragged_entity, all_entities)


func has_pressed_target() -> bool:
	return is_instance_valid(pressed_target_entity)


## Captures the topmost entity under the pointer without lifting it or playing grab audio.
func begin_press(world_pos: Vector2, is_multi_touch: bool) -> bool:
	var touch_padding: float = SettingsManager.get_touch_padding(is_multi_touch)
	pressed_target_entity = get_topmost_entity(world_pos, touch_padding)
	is_dragging = false
	active_dragged_entity = null

	if is_instance_valid(pressed_target_entity) and not pressed_target_entity.is_locked:
		drag_offset = pressed_target_entity.global_position - world_pos
		return true

	pressed_target_entity = null
	return false


## Initiates active physical dragging only when the movement threshold is crossed.
func start_dragging(world_pos: Vector2) -> void:
	if not is_instance_valid(pressed_target_entity) or pressed_target_entity.is_locked:
		return

	if pressed_target_entity.parent_socket_entity != null:
		pressed_target_entity.detach_from_socket(entity_root)

	var root_ent: OwnEntity = _get_ysort_root_entity(pressed_target_entity)
	if is_instance_valid(root_ent) and root_ent.get_parent() == entity_root:
		entity_root.move_child(root_ent, -1)

	active_dragged_entity = pressed_target_entity
	is_dragging = true
	drag_offset = active_dragged_entity.global_position - world_pos
	active_dragged_entity.on_grab()

	_trigger_haptic(25)
	LogicEngine.evaluate_trigger(Types.TriggerEvent.ON_DRAG_STARTED, active_dragged_entity)
	AudioManager.play_pop_grab()
	set_process(true)


func update_interaction(world_pos: Vector2) -> void:
	if not is_instance_valid(active_dragged_entity) or not is_dragging:
		return

	var target_pos: Vector2 = world_pos + drag_offset
	if SettingsManager.is_grid_snap_enabled():
		var grid_size: float = float(SettingsManager.get_grid_size())
		target_pos = target_pos.snapped(Vector2(grid_size, grid_size))

	var half_width: float = active_dragged_entity.get_visual_half_width()
	var bottom_offset: float = active_dragged_entity.get_visual_bottom_offset()
	var top_offset: float = active_dragged_entity.texture_size.y * 0.5 * active_dragged_entity.entity_scale

	target_pos.x = clampf(target_pos.x, room_bounds.position.x + half_width, room_bounds.end.x - half_width)

	if active_dragged_entity.is_wall_mounted:
		var max_wall_y: float = current_floor_y - bottom_offset - 4.0
		target_pos.y = clampf(target_pos.y, room_bounds.position.y + top_offset, maxf(room_bounds.position.y + top_offset, max_wall_y))
	else:
		target_pos.y = clampf(target_pos.y, room_bounds.position.y + top_offset, room_bounds.end.y - bottom_offset)

	active_dragged_entity.global_position = target_pos


func end_interaction(world_pos: Vector2, is_quick_tap: bool) -> void:
	set_process(false)

	if is_dragging and is_instance_valid(active_dragged_entity):
		var released: OwnEntity = active_dragged_entity
		active_dragged_entity = null
		is_dragging = false
		pressed_target_entity = null

		released.on_drop()
		LogicEngine.evaluate_trigger(Types.TriggerEvent.ON_DRAG_ENDED, released)
		AudioManager.play_drop_cushion()

		if is_instance_valid(interaction_router):
			interaction_router.handle_drop(released, world_pos, {"entities": all_entities, "canvas": entity_root})
		_apply_physical_gravity_settle(released)
		
		_record_history()
		SaveSystem.save_current_room_state()

	elif is_quick_tap and is_instance_valid(pressed_target_entity):
		var tapped_entity: OwnEntity = pressed_target_entity
		pressed_target_entity = null
		active_dragged_entity = null
		is_dragging = false

		if is_instance_valid(interaction_router):
			interaction_router.handle_tap(tapped_entity, all_entities)
		_record_history()
		SaveSystem.save_current_room_state()
	else:
		cancel_press()


func cancel_press() -> void:
	if is_dragging and is_instance_valid(active_dragged_entity):
		active_dragged_entity.on_drop()
		_apply_physical_gravity_settle(active_dragged_entity)
	active_dragged_entity = null
	pressed_target_entity = null
	is_dragging = false
	set_process(false)


func get_topmost_entity(world_pos: Vector2, touch_padding: float = 0.0) -> OwnEntity:
	var exact_hits: Array[OwnEntity] = []
	var padded_hits: Array[OwnEntity] = []

	for entity: OwnEntity in all_entities:
		if is_instance_valid(entity) and entity.is_visible_in_tree():
			if entity.has_point_exact(world_pos):
				exact_hits.append(entity)
			elif entity.contains_point(world_pos, touch_padding):
				padded_hits.append(entity)

	var candidates: Array[OwnEntity] = exact_hits if not exact_hits.is_empty() else padded_hits
	var best: OwnEntity = null

	for entity: OwnEntity in candidates:
		if best == null or _is_entity_in_front_of(entity, best):
			best = entity
	return best


func _is_entity_in_front_of(a: OwnEntity, b: OwnEntity) -> bool:
	if a == b: 
		return false
	if not is_instance_valid(a): 
		return false
	if not is_instance_valid(b): 
		return true

	if a.parent_socket_entity == b: 
		return a.z_index >= 0
	if b.parent_socket_entity == a: 
		return b.z_index < 0

	var z_a: int = _calculate_effective_z(a)
	var z_b: int = _calculate_effective_z(b)
	if z_a != z_b: 
		return z_a > z_b

	var root_a: OwnEntity = _get_ysort_root_entity(a)
	var root_b: OwnEntity = _get_ysort_root_entity(b)

	if root_a != root_b:
		var y_a: float = root_a.global_position.y
		var y_b: float = root_b.global_position.y
		if not is_equal_approx(y_a, y_b) and absf(y_a - y_b) > 0.5:
			return y_a > y_b
		return root_a.get_index() > root_b.get_index()

	return a.get_index() > b.get_index()


func _get_ysort_root_entity(entity: OwnEntity) -> OwnEntity:
	var current: OwnEntity = entity
	while is_instance_valid(current.parent_socket_entity):
		current = current.parent_socket_entity
	return current


func _calculate_effective_z(entity: OwnEntity) -> int:
	if not is_instance_valid(entity): 
		return 0
	if entity.z_as_relative and entity.get_parent() is Node2D:
		var parent_node: Node2D = entity.get_parent() as Node2D
		if parent_node is OwnEntity:
			return _calculate_effective_z(parent_node as OwnEntity) + entity.z_index
		return parent_node.z_index + entity.z_index
	return entity.z_index


func _apply_physical_gravity_settle(entity: OwnEntity) -> void:
	if not is_instance_valid(entity) or entity.is_wall_mounted or entity.can_float or entity.is_floor_decor or entity.parent_socket_entity != null:
		return

	var bottom_offset: float = entity.get_visual_bottom_offset()
	var floor_baseline: float = current_floor_y - bottom_offset
	if entity.global_position.y < floor_baseline - 15.0:
		var drop_dist: float = floor_baseline - entity.global_position.y
		var fall_duration: float = clampf(drop_dist * 0.0008, 0.2, 0.4)

		if SettingsManager.is_juice_squash_stretch_enabled():
			var tween: Tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tween.tween_property(entity, "global_position:y", floor_baseline, fall_duration)
		else:
			entity.global_position.y = floor_baseline


func _trigger_haptic(duration_ms: int = 30) -> void:
	if SettingsManager.are_haptics_enabled() and (OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")):
		if Input.has_method("vibrate_handheld"):
			Input.vibrate_handheld(duration_ms)


func _record_history() -> void:
	var history: Node = get_node_or_null("/root/HistoryManager")
	if is_instance_valid(history) and history.has_method("record_snapshot"):
		var main_node: Node = get_tree().root.find_child("Main", true, false)
		if is_instance_valid(main_node) and main_node.has_method("_serialize_state"):
			history.call("record_snapshot", main_node.call("_serialize_state"))
