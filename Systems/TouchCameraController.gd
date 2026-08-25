# ============================================================
# File: res://Systems/TouchCameraController.gd
# ============================================================

# ==============================================================================
# OWNWORLD — TOUCH CAMERA CONTROLLER
# File: res://Systems/TouchCameraController.gd
# Base Class: Camera2D (class_name TouchCameraController)
# ==============================================================================

class_name TouchCameraController
extends Camera2D

const DEFAULT_ROOM_BOUNDS: Rect2 = Rect2(0.0, 0.0, 1920.0, 1080.0)
const DEFAULT_MAX_ZOOM: float = 2.5
const ZOOM_SPEED: float = 0.12
const MIN_VIEW_MARGIN: float = 0.0

var room_bounds: Rect2 = DEFAULT_ROOM_BOUNDS
var min_zoom_limit: float = 1.0
var max_zoom_limit: float = DEFAULT_MAX_ZOOM

var is_panning: bool = false
var pan_start_screen_pos: Vector2 = Vector2.ZERO
var pan_start_cam_pos: Vector2 = Vector2.ZERO

var touch_points: Dictionary = {}
var initial_pinch_distance: float = 0.0
var initial_pinch_zoom: float = 1.0
var initial_touch_midpoint: Vector2 = Vector2.ZERO
var initial_touch_cam_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	position = room_bounds.get_center()

	var viewport: Viewport = get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)

	call_deferred("_deferred_initial_update")

func _deferred_initial_update() -> void:
	update_room_bounds(room_bounds)

func reset_touch_state() -> void:
	touch_points.clear()
	initial_pinch_distance = 0.0
	is_panning = false

func update_room_bounds(new_bounds: Rect2) -> void:
	if new_bounds.size.x <= 0.0 or new_bounds.size.y <= 0.0:
		return
	room_bounds = new_bounds
	_recalculate_zoom_and_clamp()

func _on_viewport_size_changed() -> void:
	_recalculate_zoom_and_clamp()

func _recalculate_zoom_and_clamp() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or room_bounds.size.x <= 0.0 or room_bounds.size.y <= 0.0:
		return

	var min_zoom_x: float = viewport_size.x / room_bounds.size.x
	var min_zoom_y: float = viewport_size.y / room_bounds.size.y
	min_zoom_limit = maxf(min_zoom_x, min_zoom_y)

	var current_zoom: float = maxf(zoom.x, 0.001)
	var target_zoom: float = clampf(current_zoom, min_zoom_limit, max_zoom_limit)
	zoom = Vector2(target_zoom, target_zoom)
	_clamp_camera_position()

func _apply_zoom_step(factor: float, mouse_screen_pos: Vector2) -> void:
	var old_zoom: float = maxf(zoom.x, 0.001)
	var target_zoom_value: float = clampf(old_zoom * factor, min_zoom_limit, max_zoom_limit)
	if is_equal_approx(old_zoom, target_zoom_value):
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var pivot_offset: Vector2 = mouse_screen_pos - viewport_size * 0.5
	zoom = Vector2(target_zoom_value, target_zoom_value)
	position += pivot_offset * (1.0 / old_zoom - 1.0 / target_zoom_value)
	_clamp_camera_position()

func start_drag_pan(screen_pos: Vector2) -> void:
	is_panning = true
	pan_start_screen_pos = screen_pos
	pan_start_cam_pos = position

func update_drag_pan(screen_pos: Vector2) -> void:
	if not is_panning:
		return
	var current_zoom: float = maxf(zoom.x, 0.001)
	var delta_position: Vector2 = (screen_pos - pan_start_screen_pos) / current_zoom
	position = pan_start_cam_pos - delta_position
	_clamp_camera_position()

func end_drag_pan() -> void:
	is_panning = false

func handle_external_touch(touch_event: InputEventScreenTouch) -> void:
	if touch_event.pressed:
		touch_points[touch_event.index] = touch_event.position
		if touch_points.size() == 2:
			end_drag_pan()
			var points: Array = touch_points.values()
			var p0: Vector2 = points[0] as Vector2
			var p1: Vector2 = points[1] as Vector2
			initial_pinch_distance = p0.distance_to(p1)
			initial_pinch_zoom = maxf(zoom.x, 0.001)
			initial_touch_midpoint = (p0 + p1) * 0.5
			initial_touch_cam_pos = position
	else:
		touch_points.erase(touch_event.index)
		if touch_points.size() < 2:
			initial_pinch_distance = 0.0

func handle_external_drag(drag_event: InputEventScreenDrag) -> void:
	touch_points[drag_event.index] = drag_event.position
	if touch_points.size() < 2:
		return

	var points: Array = touch_points.values()
	var p0: Vector2 = points[0] as Vector2
	var p1: Vector2 = points[1] as Vector2

	var current_distance: float = p0.distance_to(p1)
	var current_midpoint: Vector2 = (p0 + p1) * 0.5

	if initial_pinch_distance > 0.0:
		var pinch_ratio: float = current_distance / initial_pinch_distance
		var target_zoom: float = clampf(initial_pinch_zoom * pinch_ratio, min_zoom_limit, max_zoom_limit)
		zoom = Vector2(target_zoom, target_zoom)

	var current_zoom: float = maxf(zoom.x, 0.001)
	var midpoint_delta: Vector2 = (current_midpoint - initial_touch_midpoint) / current_zoom
	position = initial_touch_cam_pos - midpoint_delta
	_clamp_camera_position()

func handle_unhandled_mouse(mouse_event: InputEventMouseButton) -> void:
	match mouse_event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if mouse_event.pressed: _apply_zoom_step(1.0 + ZOOM_SPEED, mouse_event.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			if mouse_event.pressed: _apply_zoom_step(1.0 - ZOOM_SPEED, mouse_event.position)
		MOUSE_BUTTON_MIDDLE:
			if mouse_event.pressed: start_drag_pan(mouse_event.position)
			else: end_drag_pan()

func _clamp_camera_position() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var current_zoom: float = maxf(zoom.x, 0.001)
	var half_view: Vector2 = (viewport_size * 0.5) / current_zoom

	var minimum_x: float = room_bounds.position.x + half_view.x - MIN_VIEW_MARGIN
	var maximum_x: float = room_bounds.end.x - half_view.x + MIN_VIEW_MARGIN
	var minimum_y: float = room_bounds.position.y + half_view.y - MIN_VIEW_MARGIN
	var maximum_y: float = room_bounds.end.y - half_view.y + MIN_VIEW_MARGIN

	var clamped_position: Vector2 = position
	clamped_position.x = room_bounds.get_center().x if minimum_x >= maximum_x else clampf(clamped_position.x, minimum_x, maximum_x)
	clamped_position.y = room_bounds.get_center().y if minimum_y >= maximum_y else clampf(clamped_position.y, minimum_y, maximum_y)
	position = clamped_position

func get_zoom_value() -> float: return zoom.x

func set_zoom_value(new_zoom: float) -> void:
	var target_zoom: float = clampf(new_zoom, min_zoom_limit, max_zoom_limit)
	zoom = Vector2(target_zoom, target_zoom)
	_clamp_camera_position()

func reset_to_room_center() -> void:
	position = room_bounds.get_center()
	_recalculate_zoom_and_clamp()

func is_within_room_bounds(world_position: Vector2) -> bool:
	return room_bounds.has_point(world_position)
