# ==============================================================================
# OWNWORLD — WORLD INTERACTION CONTROLLER
# File: res://Systems/Interaction/WorldInteractionController.gd
# Base Class: Node (class_name WorldInteractionController)
#
# Responsibility: Low-level input mediation, touch vs mouse isolation,
# topmost entity picking with pixel alpha testing, and drag-and-drop routing.
# ==============================================================================

class_name WorldInteractionController
extends Node

@export var entity_root: Node2D
@export var main_camera: Camera2D
@export var interaction_router: Node
@export var magic_wheel_ui: Node
@export var room_bounds: Rect2 = Rect2(0, 0, 1920, 1080)

var is_pointer_down: bool = false
var active_dragged_entity: OwnEntity = null
var pressed_target_entity: OwnEntity = null
var drag_offset: Vector2 = Vector2.ZERO
var active_touch_count: int = 0


func _ready() -> void:
	set_process(false)


func set_room_bounds(bounds: Rect2) -> void:
	room_bounds = bounds


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed: 
			active_touch_count += 1
		else: 
			active_touch_count = maxi(0, active_touch_count - 1)
		
	# STRICT INPUT SEPARATION: Ignore emulated mouse events if a touch is active
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and active_touch_count > 0:
		return

	if event is InputEventMouseButton:
		var e: InputEventMouseButton = event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed: 
				_press(_screen_to_world(e.position))
			else: 
				_release(_screen_to_world(e.position))
		elif e.button_index == MOUSE_BUTTON_MIDDLE:
			if main_camera != null and is_instance_valid(main_camera):
				if e.pressed and main_camera.has_method("start_drag_pan"): 
					main_camera.start_drag_pan(e.position)
				elif not e.pressed and main_camera.has_method("end_drag_pan"): 
					main_camera.end_drag_pan()
	elif event is InputEventMouseMotion and active_dragged_entity != null:
		_move(_screen_to_world((event as InputEventMouseMotion).position))


func _process(_delta: float) -> void:
	if active_dragged_entity != null:
		_move(_screen_to_world(get_viewport().get_mouse_position()))


func _press(world_pos: Vector2) -> void:
	is_pointer_down = true
	pressed_target_entity = _find_topmost(world_pos)
	if pressed_target_entity == null:
		if main_camera != null and is_instance_valid(main_camera) and main_camera.has_method("start_drag_pan"):
			main_camera.start_drag_pan(get_viewport().get_mouse_position())
		return
	if pressed_target_entity.is_locked:
		return
	active_dragged_entity = pressed_target_entity
	drag_offset = active_dragged_entity.global_position - world_pos
	active_dragged_entity.on_grab()
	AudioManager.play_pop_grab()
	set_process(true)


func _move(world_pos: Vector2) -> void:
	if active_dragged_entity == null or not is_instance_valid(active_dragged_entity):
		return
	var target_position: Vector2 = world_pos + drag_offset
	if SettingsManager.is_grid_snap_enabled():
		var grid_size: float = float(SettingsManager.get_grid_size())
		target_position = target_position.snapped(Vector2(grid_size, grid_size))
	active_dragged_entity.global_position = target_position


func _release(world_pos: Vector2) -> void:
	is_pointer_down = false
	if main_camera != null and is_instance_valid(main_camera) and main_camera.has_method("end_drag_pan"):
		main_camera.end_drag_pan()

	if active_dragged_entity == null:
		if pressed_target_entity != null and is_instance_valid(pressed_target_entity):
			if interaction_router != null and interaction_router.has_method("handle_tap"):
				interaction_router.handle_tap(pressed_target_entity)
		set_process(false)
		return

	var entity: OwnEntity = active_dragged_entity
	active_dragged_entity = null
	entity.on_drop()
	if interaction_router != null and interaction_router.has_method("handle_drop"):
		var entities: Array[OwnEntity] = []
		if entity_root != null:
			for child: Node in entity_root.get_children():
				if child is OwnEntity and is_instance_valid(child):
					entities.append(child as OwnEntity)
		interaction_router.handle_drop(entity, world_pos, {"entities": entities, "canvas": entity_root})
	set_process(false)


func _find_topmost(world_pos: Vector2) -> OwnEntity:
	if entity_root == null:
		return null

	var touch_padding: float = SettingsManager.get_touch_padding(active_touch_count > 0)
	var exact_hits: Array[OwnEntity] = []
	var padded_hits: Array[OwnEntity] = []

	for child: Node in entity_root.get_children():
		if not child is OwnEntity or not is_instance_valid(child): 
			continue
		var entity: OwnEntity = child as OwnEntity
		if not entity.visible: 
			continue
		
		if entity.has_point_exact(world_pos):
			exact_hits.append(entity)
		elif entity.contains_point(world_pos, touch_padding):
			padded_hits.append(entity)

	var candidates: Array[OwnEntity] = exact_hits if not exact_hits.is_empty() else padded_hits
	var best: OwnEntity = null

	for entity: OwnEntity in candidates:
		if best == null or _is_entity_in_front(entity, best):
			best = entity

	return best


func _is_entity_in_front(a: OwnEntity, b: OwnEntity) -> bool:
	if a == b: return false
	if not is_instance_valid(a): return false
	if not is_instance_valid(b): return true
	if a.z_index != b.z_index:
		return a.z_index > b.z_index
	if not is_equal_approx(a.global_position.y, b.global_position.y) and absf(a.global_position.y - b.global_position.y) > 0.5:
		return a.global_position.y > b.global_position.y
	return a.get_index() > b.get_index()


func _screen_to_world(screen_position: Vector2) -> Vector2:
	var viewport: Viewport = get_viewport()
	return viewport.get_canvas_transform().affine_inverse() * screen_position if viewport != null else screen_position
