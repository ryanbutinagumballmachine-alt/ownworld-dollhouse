# ==============================================================================
# OWNWORLD — TOUCH CAMERA CONTROLLER (HORIZONTAL SIDE-SCROLLING & FOCUS ZOOM)
# File: res://Systems/TouchCameraController.gd
# Base Class: Camera2D (class_name TouchCameraController)
# ==============================================================================

class_name TouchCameraController
extends Camera2D

const MAX_ZOOM_INSPECT: float = 2.8
const MIN_ZOOM_INSPECT: float = 1.0
const ZOOM_STEP_SPEED: float = 0.15

var room_bounds: Rect2 = Rect2(0.0, 0.0, 1280.0, 720.0)
var is_zoom_mode: bool = false

var is_panning: bool = false
var pan_start_screen_pos: Vector2 = Vector2.ZERO
var pan_start_cam_pos: Vector2 = Vector2.ZERO

var touch_points: Dictionary = {}
var initial_pinch_distance: float = 0.0
var initial_pinch_zoom: float = 1.0
var initial_touch_midpoint: Vector2 = Vector2.ZERO
var initial_touch_cam_pos: Vector2 = Vector2.ZERO

signal zoom_mode_changed(p_is_active: bool)


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
	_recalculate_camera_mode()


func _on_viewport_size_changed() -> void:
	_recalculate_camera_mode()


func toggle_zoom_mode() -> bool:
	set_zoom_mode(not is_zoom_mode)
	return is_zoom_mode


func set_zoom_mode(p_zoom_enabled: bool) -> void:
	if is_zoom_mode == p_zoom_enabled:
		return
	is_zoom_mode = p_zoom_enabled
	reset_touch_state()

	if not is_zoom_mode:
		var tw: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "zoom", Vector2.ONE, 0.2)
		tw.parallel().tween_property(self, "position:y", room_bounds.get_center().y, 0.2)
		tw.chain().tween_callback(_clamp_camera_position)
	else:
		_clamp_camera_position()

	zoom_mode_changed.emit(is_zoom_mode)


func is_zoom_mode_enabled() -> bool:
	return is_zoom_mode


func _recalculate_camera_mode() -> void:
	if not is_zoom_mode:
		zoom = Vector2.ONE
		position.y = room_bounds.get_center().y
	_clamp_camera_position()


func _clamp_camera_position() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var current_zoom: float = maxf(zoom.x, 1.0)
	var half_view: Vector2 = (viewport_size * 0.5) / current_zoom

	var min_x: float = room_bounds.position.x + half_view.x
	var max_x: float = room_bounds.end.x - half_view.x
	var min_y: float = room_bounds.position.y + half_view.y
	var max_y: float = room_bounds.end.y - half_view.y

	var clamped_pos: Vector2 = position

	# Horizontal Side-Scrolling Clamping
	if min_x >= max_x:
		clamped_pos.x = room_bounds.get_center().x
	else:
		clamped_pos.x = clampf(clamped_pos.x, min_x, max_x)

	# Vertical Clamping (Locked in normal mode, 2D in zoom mode)
	if not is_zoom_mode or min_y >= max_y:
		clamped_pos.y = room_bounds.get_center().y
	else:
		clamped_pos.y = clampf(clamped_pos.y, min_y, max_y)

	position = clamped_pos


# ------------------------------------------------------------------------------
# SIDE-SCROLLING PANNING & ZOOM
# ------------------------------------------------------------------------------

func start_drag_pan(screen_pos: Vector2) -> void:
	is_panning = true
	pan_start_screen_pos = screen_pos
	pan_start_cam_pos = position


func update_drag_pan(screen_pos: Vector2) -> void:
	if not is_panning:
		return
	var current_zoom: float = maxf(zoom.x, 0.001)
	var delta_screen: Vector2 = (screen_pos - pan_start_screen_pos) / current_zoom

	if not is_zoom_mode:
		# Pure horizontal scroll across room slices
		position.x = pan_start_cam_pos.x - delta_screen.x
		position.y = room_bounds.get_center().y
	else:
		# Full 2D inspect pan
		position = pan_start_cam_pos - delta_screen

	_clamp_camera_position()


func end_drag_pan() -> void:
	is_panning = false


func handle_external_touch(touch_event: InputEventScreenTouch) -> void:
	if not is_zoom_mode:
		return

	if touch_event.pressed:
		touch_points[touch_event.index] = touch_event.position
		if touch_points.size() == 2:
			end_drag_pan()
			var points: Array = touch_points.values()
			var p0: Vector2 = points[0] as Vector2
			var p1: Vector2 = points[1] as Vector2
			initial_pinch_distance = p0.distance_to(p1)
			initial_pinch_zoom = maxf(zoom.x, 1.0)
			initial_touch_midpoint = (p0 + p1) * 0.5
			initial_touch_cam_pos = position
	else:
		touch_points.erase(touch_event.index)
		if touch_points.size() < 2:
			initial_pinch_distance = 0.0


func handle_external_drag(drag_event: InputEventScreenDrag) -> void:
	if not is_zoom_mode or touch_points.size() < 2 or initial_pinch_distance <= 0.0:
		return

	touch_points[drag_event.index] = drag_event.position
	var points: Array = touch_points.values()
	var p0: Vector2 = points[0] as Vector2
	var p1: Vector2 = points[1] as Vector2

	var current_distance: float = p0.distance_to(p1)
	var current_midpoint: Vector2 = (p0 + p1) * 0.5

	var pinch_ratio: float = current_distance / initial_pinch_distance
	var target_zoom: float = clampf(initial_pinch_zoom * pinch_ratio, MIN_ZOOM_INSPECT, MAX_ZOOM_INSPECT)
	zoom = Vector2(target_zoom, target_zoom)

	var current_zoom: float = maxf(zoom.x, 0.001)
	var midpoint_delta: Vector2 = (current_midpoint - initial_touch_midpoint) / current_zoom
	position = initial_touch_cam_pos - midpoint_delta
	_clamp_camera_position()


func handle_unhandled_mouse(mouse_event: InputEventMouseButton) -> void:
	if not is_zoom_mode:
		return

	match mouse_event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if mouse_event.pressed: _apply_zoom_step(1.0 + ZOOM_STEP_SPEED, mouse_event.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			if mouse_event.pressed: _apply_zoom_step(1.0 - ZOOM_STEP_SPEED, mouse_event.position)
		MOUSE_BUTTON_MIDDLE:
			if mouse_event.pressed: start_drag_pan(mouse_event.position)
			else: end_drag_pan()


func _apply_zoom_step(factor: float, mouse_screen_pos: Vector2) -> void:
	if not is_zoom_mode:
		return

	var old_zoom: float = maxf(zoom.x, 1.0)
	var target_zoom_val: float = clampf(old_zoom * factor, MIN_ZOOM_INSPECT, MAX_ZOOM_INSPECT)
	if is_equal_approx(old_zoom, target_zoom_val):
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var pivot_offset: Vector2 = mouse_screen_pos - (viewport_size * 0.5)
	zoom = Vector2(target_zoom_val, target_zoom_val)
	position += pivot_offset * (1.0 / old_zoom - 1.0 / target_zoom_val)
	_clamp_camera_position()
