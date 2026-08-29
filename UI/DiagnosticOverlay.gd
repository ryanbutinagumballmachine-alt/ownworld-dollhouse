# ============================================================
# File: res://UI/DiagnosticOverlay.gd
# ============================================================

# ==============================================================================
# OWNWORLD — DIAGNOSTIC OVERLAY & INTEGRATED MOBILE SIMULATOR
# File: res://UI/DiagnosticOverlay.gd
# Base Class: CanvasLayer (class_name DiagnosticOverlay)
#
# Responsibility: Developer diagnostics heads-up display. Renders real-time FPS,
# coordinate metrics, collision polylines, socket links, and system state JSON dumps.
# Configured at Layer 130 to sit above modal dialogs.
# ==============================================================================

class_name DiagnosticOverlay
extends CanvasLayer

const SESSION_FILE: String = "user://session.json"
const DIAGNOSTIC_LAYER: int = 130

const RESOLUTION_PRESETS: Array[Dictionary] = [
	{
		"name": "Standard Phone (16:9)",
		"size": Vector2i(1280, 720),
		"aspect": "16:9",
		"notch_width": 0.0
	},
	{
		"name": "Flagship (19.5:9 - iPhone 15 / Galaxy S24)",
		"size": Vector2i(1560, 720),
		"aspect": "19.5:9",
		"notch_width": 44.0
	},
	{
		"name": "Tall Display (20:9 - Pixel / OnePlus)",
		"size": Vector2i(1600, 720),
		"aspect": "20:9",
		"notch_width": 48.0
	},
	{
		"name": "Cinema Ultrawide (21:9 - Sony Xperia)",
		"size": Vector2i(1680, 720),
		"aspect": "21:9",
		"notch_width": 54.0
	},
	{
		"name": "Tablet Landscape (4:3 - iPad)",
		"size": Vector2i(960, 720),
		"aspect": "4:3",
		"notch_width": 0.0
	}
]

var is_debug_active: bool = false
var is_notch_visible: bool = false
var active_preset_index: int = 0
var main_ref: Node2D = null

var hud_panel: PanelContainer = null
var stats_label: Label = null
var btn_copy_state: Button = null
var debug_canvas: Control = null
var dev_pill_btn: Button = null

var sim_box: VBoxContainer = null
var preset_opt: OptionButton = null
var btn_toggle_notch: Button = null
var btn_toggle_ui_mode: Button = null
var btn_center_window: Button = null

var _update_timer: float = 0.0


func _ready() -> void:
	name = "DiagnosticOverlay"
	layer = DIAGNOSTIC_LAYER
	visible = false
	set_process(false)
	_build_diagnostic_hud()
	_connect_settings_signal()
	_sync_with_settings()


func _is_mobile() -> bool:
	return ThemeEngine.is_mobile_platform()


func setup(p_main: Node2D) -> void:
	main_ref = p_main
	if is_inside_tree(): 
		_sync_with_settings()


func _connect_settings_signal() -> void:
	if not is_inside_tree(): 
		return
	if SettingsManager.has_signal("developer_mode_changed"):
		if not SettingsManager.is_connected("developer_mode_changed", Callable(self, "_on_dev_mode_changed")):
			SettingsManager.developer_mode_changed.connect(_on_dev_mode_changed)


func _sync_with_settings() -> void:
	if not is_inside_tree(): 
		return
	_on_dev_mode_changed(SettingsManager.is_developer_mode_enabled())


func _on_dev_mode_changed(enabled: bool) -> void:
	if dev_pill_btn: 
		dev_pill_btn.visible = enabled
	set_diagnostic_active(enabled)


func _process(delta: float) -> void:
	if not is_debug_active or not is_instance_valid(main_ref):
		set_process(false)
		return

	_update_timer += delta
	if _update_timer >= 0.25:
		_update_timer = 0.0
		_update_stats_display()

	if debug_canvas and debug_canvas.visible:
		debug_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if not SettingsManager.is_developer_mode_enabled():
		return

	match event.keycode:
		KEY_F1:
			toggle_diagnostic_hud()
			get_viewport().set_input_as_handled()
		KEY_F3:
			cycle_resolution_preset()
			get_viewport().set_input_as_handled()
		KEY_F4:
			toggle_simulated_notch()
			get_viewport().set_input_as_handled()
		KEY_F5:
			toggle_mobile_ui_mode()
			get_viewport().set_input_as_handled()


func toggle_diagnostic_hud() -> void:
	set_diagnostic_active(not is_debug_active)


func set_diagnostic_active(active: bool) -> void:
	is_debug_active = active
	visible = active
	set_process(active)

	if debug_canvas:
		debug_canvas.visible = active
		if active: 
			debug_canvas.queue_redraw()

	if is_instance_valid(main_ref):
		var raw_ents: Variant = main_ref.get("all_entities")
		if raw_ents is Array:
			for ent_var: Variant in (raw_ents as Array):
				if ent_var is OwnEntity and is_instance_valid(ent_var):
					(ent_var as OwnEntity).update_gizmo_visibility(active)

	EventBus.notification_requested.emit("Diagnostics: " + ("ENABLED (F1)" if active else "DISABLED"), true)


func cycle_resolution_preset() -> void:
	active_preset_index = (active_preset_index + 1) % RESOLUTION_PRESETS.size()
	_apply_resolution_preset(active_preset_index)


func toggle_simulated_notch() -> void:
	is_notch_visible = not is_notch_visible
	if debug_canvas: 
		debug_canvas.queue_redraw()
	EventBus.notification_requested.emit("Camera Notch Overlay: " + ("ON (F4)" if is_notch_visible else "OFF"), true)


func toggle_mobile_ui_mode() -> void:
	var next_mode: bool = not SettingsManager.is_simulating_mobile_layout()
	SettingsManager.set_simulating_mobile_layout(next_mode)
	_update_sim_buttons_text()
	EventBus.notification_requested.emit("UI Mode: " + ("Mobile (48dp Touch Targets)" if next_mode else "Desktop (Precision Pointer)") + " (F5)", true)


func _apply_resolution_preset(index: int) -> void:
	if index < 0 or index >= RESOLUTION_PRESETS.size(): 
		return
	active_preset_index = index
	var preset: Dictionary = RESOLUTION_PRESETS[active_preset_index]
	var target_size: Vector2i = preset["size"] as Vector2i

	DisplayServer.window_set_size(target_size)
	_center_window_on_screen()

	if preset_opt:
		preset_opt.selected = active_preset_index

	if debug_canvas:
		debug_canvas.queue_redraw()

	EventBus.notification_requested.emit("Resized to: %s [%dx%d]" % [str(preset["name"]), target_size.x, target_size.y], true)


func _center_window_on_screen() -> void:
	var screen_index: int = DisplayServer.window_get_current_screen()
	var screen_rect: Rect2i = DisplayServer.screen_get_usable_rect(screen_index)
	var window_size: Vector2i = DisplayServer.window_get_size()
	var diff: Vector2i = screen_rect.size - window_size
	var centered_pos: Vector2i = screen_rect.position + Vector2i(int(float(diff.x) * 0.5), int(float(diff.y) * 0.5))
	DisplayServer.window_set_position(centered_pos)


func _build_diagnostic_hud() -> void:
	var is_mob: bool = _is_mobile()
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()

	debug_canvas = DebugCanvasDraw.new()
	debug_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	debug_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_canvas.visible = false
	(debug_canvas as DebugCanvasDraw).overlay_ref = self
	add_child(debug_canvas)

	dev_pill_btn = Button.new()
	dev_pill_btn.text = " DEV"
	dev_pill_btn.custom_minimum_size = Vector2(80.0 if is_mob else 70.0, 32.0 if is_mob else 26.0)
	dev_pill_btn.anchor_left = 1.0
	dev_pill_btn.anchor_right = 1.0
	dev_pill_btn.offset_left = -maxf(100.0, float(DisplayServer.screen_get_size().x - (safe_area.position.x + safe_area.size.x)) + 80.0)
	dev_pill_btn.offset_top = maxf(18.0, float(safe_area.position.y) + 6.0)
	dev_pill_btn.offset_right = dev_pill_btn.offset_left + (80.0 if is_mob else 70.0)
	dev_pill_btn.offset_bottom = dev_pill_btn.offset_top + (32.0 if is_mob else 26.0)
	dev_pill_btn.focus_mode = Control.FOCUS_NONE
	dev_pill_btn.visible = false
	dev_pill_btn.theme_type_variation = "FloatingCapsule"
	dev_pill_btn.add_theme_constant_override("icon_max_width", 14)

	var dev_icon: Texture2D = ThemeService.get_icon("icon_dev")
	if dev_icon: 
		dev_pill_btn.icon = dev_icon
	dev_pill_btn.pressed.connect(toggle_diagnostic_hud)
	add_child(dev_pill_btn)

	hud_panel = PanelContainer.new()
	hud_panel.custom_minimum_size = Vector2(300.0 if is_mob else 270.0, 0.0)
	hud_panel.position = Vector2(maxf(16.0, float(safe_area.position.x) + 6.0), maxf(60.0, float(safe_area.position.y) + 48.0))
	hud_panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#09090b", 0.94)
	style.border_color = Color("#22c55e")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	hud_panel.add_theme_stylebox_override("panel", style)
	add_child(hud_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	hud_panel.add_child(vbox)

	stats_label = Label.new()
	stats_label.text = "DIAGNOSTICS ACTIVE (F1)\nFPS: 60"
	stats_label.add_theme_font_size_override("font_size", 11)
	stats_label.add_theme_color_override("font_color", Color("#22c55e"))
	vbox.add_child(stats_label)

	btn_copy_state = Button.new()
	btn_copy_state.text = " Copy System State (JSON)"
	btn_copy_state.custom_minimum_size = Vector2(0.0, 28.0 if is_mob else 24.0)
	btn_copy_state.focus_mode = Control.FOCUS_NONE
	btn_copy_state.add_theme_constant_override("icon_max_width", 14)
	btn_copy_state.add_theme_font_size_override("font_size", 10)

	var copy_icon: Texture2D = ThemeService.get_icon("icon_clone")
	if not copy_icon: 
		copy_icon = ThemeService.get_icon("icon_save")
	if copy_icon: 
		btn_copy_state.icon = copy_icon
	btn_copy_state.pressed.connect(_on_copy_state_json_pressed)

	var btn_s: StyleBoxFlat = StyleBoxFlat.new()
	btn_s.bg_color = Color("#1e293b")
	btn_s.border_color = Color("#22c55e")
	btn_s.set_border_width_all(1)
	btn_s.set_corner_radius_all(4)
	btn_copy_state.add_theme_stylebox_override("normal", btn_s)

	var btn_hov: StyleBoxFlat = btn_s.duplicate() as StyleBoxFlat
	btn_hov.bg_color = Color("#0f172a")
	btn_copy_state.add_theme_stylebox_override("hover", btn_hov)
	btn_copy_state.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_copy_state.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(btn_copy_state)

	vbox.add_child(HSeparator.new())

	sim_box = VBoxContainer.new()
	sim_box.add_theme_constant_override("separation", 4)
	vbox.add_child(sim_box)

	var sim_title: Label = Label.new()
	sim_title.text = "MOBILE SIMULATOR:"
	sim_title.theme_type_variation = "HintLabel"
	sim_title.add_theme_font_size_override("font_size", 10)
	sim_title.add_theme_color_override("font_color", Color("#ec4899"))
	sim_box.add_child(sim_title)

	preset_opt = OptionButton.new()
	preset_opt.custom_minimum_size = Vector2(0.0, 26.0)
	preset_opt.add_theme_font_size_override("font_size", 10)
	for i: int in range(RESOLUTION_PRESETS.size()):
		preset_opt.add_item(str(RESOLUTION_PRESETS[i]["name"]), i)
	preset_opt.selected = active_preset_index
	preset_opt.item_selected.connect(_on_dropdown_preset_selected)
	sim_box.add_child(preset_opt)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	sim_box.add_child(btn_row)

	btn_toggle_ui_mode = Button.new()
	btn_toggle_ui_mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_toggle_ui_mode.custom_minimum_size = Vector2(0.0, 24.0)
	btn_toggle_ui_mode.focus_mode = Control.FOCUS_NONE
	btn_toggle_ui_mode.add_theme_font_size_override("font_size", 9)
	btn_toggle_ui_mode.pressed.connect(toggle_mobile_ui_mode)
	btn_row.add_child(btn_toggle_ui_mode)

	btn_toggle_notch = Button.new()
	btn_toggle_notch.text = "Notch (F4)"
	btn_toggle_notch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_toggle_notch.custom_minimum_size = Vector2(0.0, 24.0)
	btn_toggle_notch.focus_mode = Control.FOCUS_NONE
	btn_toggle_notch.add_theme_font_size_override("font_size", 9)
	btn_toggle_notch.pressed.connect(toggle_simulated_notch)
	btn_row.add_child(btn_toggle_notch)

	btn_center_window = Button.new()
	btn_center_window.text = "Center"
	btn_center_window.custom_minimum_size = Vector2(48.0, 24.0)
	btn_center_window.focus_mode = Control.FOCUS_NONE
	btn_center_window.add_theme_font_size_override("font_size", 9)
	btn_center_window.pressed.connect(_center_window_on_screen)
	btn_row.add_child(btn_center_window)

	_update_sim_buttons_text()


func _update_sim_buttons_text() -> void:
	if btn_toggle_ui_mode != null:
		var is_sim_mob: bool = SettingsManager.is_simulating_mobile_layout()
		btn_toggle_ui_mode.text = "UI: " + ("Mobile (F5)" if is_sim_mob else "Desktop (F5)")


func _on_dropdown_preset_selected(index: int) -> void:
	_apply_resolution_preset(index)


func _update_stats_display() -> void:
	if not main_ref: 
		return

	var raw_ents: Variant = main_ref.get("all_entities")
	var entity_count: int = (raw_ents as Array).size() if raw_ents is Array else 0
	var fps: float = Engine.get_frames_per_second()
	var cam_pos: Vector2 = Vector2.ZERO
	var cam_zoom: float = 1.0

	if main_camera_valid():
		var camera: Camera2D = main_ref.get("main_camera") as Camera2D
		cam_pos = camera.position
		cam_zoom = camera.zoom.x

	stats_label.text = "DIAGNOSTICS (F1) | %d FPS\nRoom: %s | Entities: %d\nCam: (%d, %d) @ %.2fx" % [
		int(fps), AppState.room_id, entity_count, int(cam_pos.x), int(cam_pos.y), cam_zoom
	]


func main_camera_valid() -> bool:
	if main_ref == null: 
		return false
	var cam: Variant = main_ref.get("main_camera")
	return cam != null and is_instance_valid(cam as Node)


func _on_copy_state_json_pressed() -> void:
	if not is_instance_valid(main_ref): 
		return

	var cam_node: Camera2D = main_ref.get("main_camera") as Camera2D if main_camera_valid() else null
	var r_bounds: Rect2 = main_ref.get("room_bounds") as Rect2 if "room_bounds" in main_ref else Rect2(0.0, 0.0, 1920.0, 1080.0)

	var state_dump: Dictionary = {
		"timestamp": Time.get_datetime_string_from_system(),
		"engine_version": "Godot 4.x",
		"active_universe": {
			"id": AppState.universe_id,
			"name": AppState.universe_name
		},
		"room": {
			"id": AppState.room_id,
			"title": str(main_ref.get("current_room_title")),
			"floor_y": float(main_ref.get("current_room_floor_y")),
			"wallpaper": str(main_ref.get("current_wallpaper_path")),
			"fill_mode": str(main_ref.get("current_wallpaper_fill_mode"))
		},
		"atmosphere": {
			"time_preset": AppState.time_preset,
			"weather_preset": AppState.weather_preset
		},
		"camera": {
			"position": ({"x": cam_node.position.x, "y": cam_node.position.y} if cam_node else {}),
			"zoom": (cam_node.zoom.x if cam_node else 1.0),
			"room_bounds": {"x": r_bounds.position.x, "y": r_bounds.position.y, "w": r_bounds.size.x, "h": r_bounds.size.y}
		},
		"entities_state": ((main_ref.call("_serialize_state") as Dictionary).get("entities", []) if main_ref.has_method("_serialize_state") else [])
	}

	var json_payload: String = JSON.stringify(state_dump, "\t")
	DisplayServer.clipboard_set(json_payload)
	EventBus.notification_requested.emit("State Copied to Clipboard", true)


class DebugCanvasDraw extends Control:
	var overlay_ref: DiagnosticOverlay = null

	func _draw() -> void:
		if not overlay_ref or not overlay_ref.is_debug_active:
			return

		var vp_size: Vector2 = get_viewport_rect().size

		# 1. Simulated Camera Notch & Punch-Hole Overlay
		if overlay_ref.is_notch_visible:
			var preset: Dictionary = overlay_ref.RESOLUTION_PRESETS[overlay_ref.active_preset_index]
			var notch_w: float = float(preset["notch_width"])

			if notch_w > 0.0:
				var punch_radius: float = 14.0
				var punch_pos: Vector2 = Vector2(notch_w * 0.5, vp_size.y * 0.5)
				draw_circle(punch_pos, punch_radius + 2.0, Color(0.0, 0.0, 0.0, 0.85))
				draw_circle(punch_pos, punch_radius, Color("#09090b"))
				draw_circle(punch_pos, punch_radius - 5.0, Color("#1e1b4b"))

				var safe_color: Color = Color("#ec4899", 0.45)
				draw_line(Vector2(notch_w, 0.0), Vector2(notch_w, vp_size.y), safe_color, 1.5)
				draw_line(Vector2(vp_size.x - notch_w, 0.0), Vector2(vp_size.x - notch_w, vp_size.y), safe_color, 1.5)
				draw_line(Vector2(0.0, 10.0), Vector2(vp_size.x, 10.0), safe_color, 1.0)
				draw_line(Vector2(0.0, vp_size.y - 12.0), Vector2(vp_size.x, vp_size.y - 12.0), safe_color, 1.0)

				var pill_w: float = 140.0
				var pill_h: float = 4.5
				var pill_pos: Vector2 = Vector2((vp_size.x - pill_w) * 0.5, vp_size.y - 8.0)
				draw_rect(Rect2(pill_pos, Vector2(pill_w, pill_h)), Color(1.0, 1.0, 1.0, 0.65), true)

		# 2. Entity Gizmos & Collision Outlines
		if not is_instance_valid(overlay_ref.main_ref): 
			return
		var cam: Camera2D = overlay_ref.main_ref.get("main_camera") as Camera2D
		if not cam or not is_instance_valid(cam): 
			return

		var raw_ents: Variant = overlay_ref.main_ref.get("all_entities")
		if not (raw_ents is Array): 
			return

		for ent_var: Variant in (raw_ents as Array):
			if not ent_var is OwnEntity or not is_instance_valid(ent_var): 
				continue
			var ent: OwnEntity = ent_var as OwnEntity
			var ent_screen_pos: Vector2 = _world_to_screen(ent.global_position, cam)

			if not ent.collision_polygons.is_empty():
				for poly: PackedVector2Array in ent.collision_polygons:
					if poly.size() >= 3:
						var screen_pts: PackedVector2Array = PackedVector2Array()
						for pt: Vector2 in poly:
							screen_pts.append(_world_to_screen(ent.to_global(pt), cam))
						draw_polyline(screen_pts, Color("#000000", 0.9), 3.5, true)
						draw_polyline(screen_pts, Color("#22c55e", 0.95), 2.0, true)
			elif ent.collision_poly.size() >= 3:
				var screen_pts: PackedVector2Array = PackedVector2Array()
				for pt: Vector2 in ent.collision_poly:
					screen_pts.append(_world_to_screen(ent.to_global(pt), cam))
				draw_polyline(screen_pts, Color("#000000", 0.9), 3.5, true)
				draw_polyline(screen_pts, Color("#22c55e", 0.95), 2.0, true)
			else:
				var half_s: Vector2 = ent.texture_size * 0.5 * ent.entity_scale * cam.zoom
				var rect: Rect2 = Rect2(ent_screen_pos - half_s, half_s * 2.0)
				draw_rect(rect, Color("#000000", 0.8), false, 3.5)
				draw_rect(rect, Color("#22c55e", 0.9), false, 2.0)

			if ent.parent_socket_entity != null and is_instance_valid(ent.parent_socket_entity):
				var parent_p: Vector2 = _world_to_screen(ent.parent_socket_entity.global_position, cam)
				draw_line(parent_p, ent_screen_pos, Color("#000000", 0.8), 3.0)
				draw_line(parent_p, ent_screen_pos, Color("#00f2fe", 0.9), 1.5)
				draw_circle(ent_screen_pos, 4.0, Color("#00f2fe"))

			var badge_text: String = "Z:%d [%d]" % [ent.z_index, ent.base_layer_band]
			var font: Font = ThemeDB.fallback_font
			var font_sz: int = 10
			var text_w: float = font.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz).x
			var badge_pos: Vector2 = ent_screen_pos + Vector2(-text_w * 0.5, -(ent.texture_size.y * 0.5 * ent.entity_scale * cam.zoom.y) - 16.0)
			var badge_bg: Rect2 = Rect2(badge_pos - Vector2(4.0, 2.0), Vector2(text_w + 8.0, 15.0))

			draw_rect(badge_bg, Color("#09090b", 0.9), true)
			draw_rect(badge_bg, Color("#00f2fe", 0.8), false, 1.0)
			draw_string(font, badge_pos + Vector2(0.0, 10.0), badge_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz, Color.WHITE)


	func _world_to_screen(world_pos: Vector2, cam: Camera2D) -> Vector2:
		var vp_center: Vector2 = get_viewport_rect().size * 0.5
		return vp_center + (world_pos - cam.position) * cam.zoom
