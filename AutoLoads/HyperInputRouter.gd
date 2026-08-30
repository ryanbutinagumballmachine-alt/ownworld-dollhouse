# ==============================================================================
# OWNWORLD — HYPER INPUT ROUTER (SINGLE SOURCE OF TRUTH)
# File: res://AutoLoads/HyperInputRouter.gd
# Autoload Singleton: HyperInputRouter
# Base Class: Node
#
# Responsibility: Absolute single source of truth for all input events.
# Filters synthetic mobile mouse emulation, defers dragging until threshold
# breach, and cleanly delegates pure taps vs. physical drops.
# ==============================================================================

extends Node

var interaction_controller: WorldInteractionController = null
var camera_controller: TouchCameraController = null
var magic_wheel: MagicWheel = null
var drawer_tray: DrawerTray = null
var top_nav: TopNavBar = null

var is_pointer_down: bool = false
var is_active_dragging: bool = false
var long_press_triggered: bool = false
var has_drag_moved: bool = false
var press_start_time: float = 0.0
var press_start_screen_pos: Vector2 = Vector2.ZERO
var current_screen_pos: Vector2 = Vector2.ZERO

var active_touches: Dictionary = {}
var ui_touches: Dictionary = {}
var primary_touch_idx: int = -1

var TAP_THRESHOLD: float = 20.0
var _last_touch_msec: int = 0
const MOUSE_EMULATION_COOLDOWN_MSEC: int = 350


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false) # Hyper Optimization: Only process when a pointer is actively down
	if OS.has_feature("pc") or OS.has_feature("windows") or OS.has_feature("mac") or OS.has_feature("linux"):
		TAP_THRESHOLD = 12.0


func register_controllers(ic: WorldInteractionController, cam: TouchCameraController, mw: MagicWheel, dt: DrawerTray, tn: TopNavBar) -> void:
	interaction_controller = ic
	camera_controller = cam
	magic_wheel = mw
	drawer_tray = dt
	top_nav = tn


func _is_any_modal_open() -> bool:
	for ui: Node in get_tree().get_nodes_in_group(&"modal_ui"):
		if is_instance_valid(ui):
			if ui is CanvasLayer and (ui as CanvasLayer).visible: 
				return true
			elif ui is Control and (ui as Control).visible: 
				return true
			elif ui is Window and (ui as Window).visible: 
				return true
	return false


func _is_ui_touch(screen_pos: Vector2) -> bool:
	if _is_any_modal_open(): 
		return true
	if is_instance_valid(drawer_tray) and drawer_tray.is_point_inside_drawer(screen_pos): 
		return true
	if is_instance_valid(top_nav) and top_nav.is_point_inside_nav(screen_pos): 
		return true
	return false


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	if is_instance_valid(camera_controller):
		var vp_size: Vector2 = camera_controller.get_viewport_rect().size
		var cam_zoom: float = maxf(camera_controller.zoom.x, 0.001)
		return camera_controller.position + (screen_pos - (vp_size * 0.5)) / cam_zoom
	var vp: Viewport = get_viewport()
	return vp.get_canvas_transform().affine_inverse() * screen_pos if vp else screen_pos


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		var touch_idx: int = st.index
		var screen_pos: Vector2 = st.position
		var world_pos: Vector2 = _screen_to_world(screen_pos)

		_last_touch_msec = Time.get_ticks_msec()
		current_screen_pos = screen_pos

		if st.pressed:
			active_touches[touch_idx] = screen_pos
			var is_ui: bool = _is_ui_touch(screen_pos)
			if is_ui:
				ui_touches[touch_idx] = true
				if active_touches.size() >= 2: 
					_cancel_drag()
			else:
				ui_touches.erase(touch_idx)
				if active_touches.size() == 1:
					primary_touch_idx = touch_idx
					_begin_press(world_pos, screen_pos)
				elif active_touches.size() >= 2:
					_cancel_drag()
		else:
			active_touches.erase(touch_idx)
			var was_ui: bool = ui_touches.has(touch_idx)
			ui_touches.erase(touch_idx)

			if not was_ui:
				if touch_idx == primary_touch_idx or active_touches.is_empty():
					_end_press(world_pos)
					primary_touch_idx = -1

		if is_instance_valid(camera_controller): 
			camera_controller.handle_external_touch(st)

	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		var touch_idx: int = sd.index
		_last_touch_msec = Time.get_ticks_msec()
		active_touches[touch_idx] = sd.position

		if not ui_touches.has(touch_idx) and active_touches.size() == 1 and touch_idx == primary_touch_idx:
			current_screen_pos = sd.position
			var world_pos: Vector2 = _screen_to_world(sd.position)
			_process_drag_movement(world_pos, sd.position)

		if is_instance_valid(camera_controller) and active_touches.size() >= 2:
			camera_controller.handle_external_drag(sd)

	elif event is InputEventMouseButton:
		# Discard synthetic mouse events on mobile and during/after touch gestures
		if not active_touches.is_empty(): 
			return
		if Time.get_ticks_msec() - _last_touch_msec < MOUSE_EMULATION_COOLDOWN_MSEC:
			return
		if (OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")) and not OS.has_feature("pc"):
			return

		var mb: InputEventMouseButton = event as InputEventMouseButton
		var screen_pos: Vector2 = mb.position
		var world_pos: Vector2 = _screen_to_world(screen_pos)
		current_screen_pos = screen_pos

		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if not _is_ui_touch(screen_pos) and not is_pointer_down:
					_begin_press(world_pos, screen_pos)
			else:
				if is_pointer_down:
					_end_press(world_pos)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if not _is_any_modal_open():
				var clicked: OwnEntity = interaction_controller.get_topmost_entity(world_pos, 0.0) if is_instance_valid(interaction_controller) else null
				if clicked and is_instance_valid(magic_wheel):
					_trigger_haptic(40)
					magic_wheel.open_wheel_for_entity(clicked, screen_pos)
		elif mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_MIDDLE]:
			if is_instance_valid(camera_controller): 
				camera_controller.handle_unhandled_mouse(mb)

	elif event is InputEventMouseMotion:
		if not active_touches.is_empty(): 
			return
		if Time.get_ticks_msec() - _last_touch_msec < MOUSE_EMULATION_COOLDOWN_MSEC:
			return
		if (OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")) and not OS.has_feature("pc"):
			return

		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		current_screen_pos = mm.position
		var world_pos: Vector2 = _screen_to_world(mm.position)

		if is_pointer_down:
			_process_drag_movement(world_pos, mm.position)


func _process_drag_movement(world_pos: Vector2, screen_pos: Vector2) -> void:
	if not has_drag_moved and press_start_screen_pos.distance_to(screen_pos) > TAP_THRESHOLD:
		has_drag_moved = true
		if is_instance_valid(interaction_controller) and interaction_controller.has_pressed_target() and not is_active_dragging:
			is_active_dragging = true
			interaction_controller.start_dragging(world_pos)

	if is_active_dragging and is_instance_valid(interaction_controller):
		interaction_controller.update_interaction(world_pos)
	elif is_pointer_down and is_instance_valid(camera_controller) and camera_controller.is_panning:
		camera_controller.update_drag_pan(screen_pos)


func _begin_press(world_pos: Vector2, screen_pos: Vector2) -> void:
	is_pointer_down = true
	is_active_dragging = false
	long_press_triggered = false
	has_drag_moved = false
	press_start_time = Time.get_ticks_msec() / 1000.0
	press_start_screen_pos = screen_pos
	set_process(true) # Enable processing only when pointer is down

	if is_instance_valid(interaction_controller):
		var is_multi: bool = active_touches.size() > 1
		if not interaction_controller.begin_press(world_pos, is_multi):
			if is_instance_valid(camera_controller): 
				camera_controller.start_drag_pan(screen_pos)


func _end_press(world_pos: Vector2) -> void:
	is_pointer_down = false
	set_process(false) # Disable processing to save CPU
	
	if is_instance_valid(camera_controller): 
		camera_controller.end_drag_pan()

	if long_press_triggered:
		is_active_dragging = false
		if is_instance_valid(interaction_controller):
			interaction_controller.cancel_press()
		return

	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - press_start_time
	var drag_dist: float = press_start_screen_pos.distance_to(current_screen_pos)
	var hold_dur: float = SettingsManager.get_long_press_duration()
	var is_quick_tap: bool = (not has_drag_moved) and (drag_dist <= TAP_THRESHOLD) and (elapsed < hold_dur)

	if is_instance_valid(interaction_controller):
		interaction_controller.end_interaction(world_pos, is_quick_tap)

	is_active_dragging = false


func _cancel_drag() -> void:
	if is_instance_valid(interaction_controller):
		interaction_controller.cancel_press()
	if is_instance_valid(camera_controller): 
		camera_controller.end_drag_pan()
	is_pointer_down = false
	is_active_dragging = false
	has_drag_moved = false
	set_process(false) # Disable processing to save CPU


func _process(_delta: float) -> void:
	if is_pointer_down and not long_press_triggered and not has_drag_moved and is_instance_valid(interaction_controller) and interaction_controller.has_pressed_target():
		var elapsed: float = (Time.get_ticks_msec() / 1000.0) - press_start_time
		var drag_dist: float = press_start_screen_pos.distance_to(current_screen_pos)
		var lp_thresh: float = SettingsManager.get_long_press_duration()

		if elapsed >= lp_thresh and drag_dist <= TAP_THRESHOLD:
			long_press_triggered = true
			var target: OwnEntity = interaction_controller.pressed_target_entity
			_trigger_haptic(60)
			if is_instance_valid(magic_wheel): 
				magic_wheel.open_wheel_for_entity(target, current_screen_pos)
			_cancel_drag()


func _trigger_haptic(duration_ms: int = 30) -> void:
	if SettingsManager.are_haptics_enabled() and (OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")):
		if Input.has_method("vibrate_handheld"):
			Input.vibrate_handheld(duration_ms)
