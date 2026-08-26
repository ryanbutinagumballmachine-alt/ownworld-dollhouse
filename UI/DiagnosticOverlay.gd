# ==============================================================================
# OWNWORLD — DIAGNOSTIC OVERLAY
# File: res://UI/DiagnosticOverlay.gd
# Base Class: CanvasLayer (class_name DiagnosticOverlay)
# ==============================================================================

class_name DiagnosticOverlay
extends CanvasLayer

const SESSION_FILE: String = "user://session.json"

var is_debug_active: bool = false
var main_ref: Node2D = null

var hud_panel: PanelContainer = null
var stats_label: Label = null
var btn_copy_state: Button = null
var debug_canvas: Control = null
var dev_pill_btn: Button = null

var _update_timer: float = 0.0


func _ready() -> void:
	name = "DiagnosticOverlay"
	layer = 126
	visible = false
	set_process(false)
	_build_diagnostic_hud()
	_connect_settings_signal()
	_sync_with_settings()


func setup(p_main: Node2D) -> void:
	main_ref = p_main
	if is_inside_tree(): _sync_with_settings()


func _connect_settings_signal() -> void:
	if not is_inside_tree(): return
	if SettingsManager.has_signal("developer_mode_changed"):
		if not SettingsManager.is_connected("developer_mode_changed", Callable(self, "_on_dev_mode_changed")):
			SettingsManager.developer_mode_changed.connect(_on_dev_mode_changed)


func _sync_with_settings() -> void:
	if not is_inside_tree(): return
	_on_dev_mode_changed(SettingsManager.is_developer_mode_enabled())


func _on_dev_mode_changed(enabled: bool) -> void:
	if dev_pill_btn: dev_pill_btn.visible = enabled
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
	if event.keycode == KEY_F1 and SettingsManager.is_developer_mode_enabled():
		toggle_diagnostic_hud()
		get_viewport().set_input_as_handled()


func toggle_diagnostic_hud() -> void:
	set_diagnostic_active(not is_debug_active)


func set_diagnostic_active(active: bool) -> void:
	is_debug_active = active
	visible = active
	set_process(active)

	if debug_canvas:
		debug_canvas.visible = active
		if active: debug_canvas.queue_redraw()

	if is_instance_valid(main_ref):
		var raw_ents: Variant = main_ref.get("all_entities")
		if raw_ents is Array:
			for ent_var: Variant in (raw_ents as Array):
				if ent_var is OwnEntity and is_instance_valid(ent_var):
					(ent_var as OwnEntity).update_gizmo_visibility(active)

	EventBus.notification_requested.emit("Diagnostics: " + ("ENABLED" if active else "DISABLED"), true)


func _build_diagnostic_hud() -> void:
	debug_canvas = DebugCanvasDraw.new()
	debug_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	debug_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_canvas.visible = false
	(debug_canvas as DebugCanvasDraw).overlay_ref = self
	add_child(debug_canvas)

	dev_pill_btn = Button.new()
	dev_pill_btn.text = " DEV"
	dev_pill_btn.custom_minimum_size = Vector2(75.0, 26.0)
	dev_pill_btn.anchor_left = 1.0
	dev_pill_btn.anchor_right = 1.0
	dev_pill_btn.offset_left = -95.0
	dev_pill_btn.offset_top = 18.0
	dev_pill_btn.offset_right = -20.0
	dev_pill_btn.offset_bottom = 44.0
	dev_pill_btn.focus_mode = Control.FOCUS_NONE
	dev_pill_btn.visible = false
	dev_pill_btn.theme_type_variation = "FloatingCapsule"
	dev_pill_btn.add_theme_constant_override("icon_max_width", 14)

	var dev_icon: Texture2D = ThemeService.get_icon("icon_dev")
	if dev_icon: dev_pill_btn.icon = dev_icon
	dev_pill_btn.pressed.connect(toggle_diagnostic_hud)
	add_child(dev_pill_btn)

	hud_panel = PanelContainer.new()
	hud_panel.custom_minimum_size = Vector2(280.0, 80.0)
	hud_panel.position = Vector2(16.0, 60.0)
	hud_panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#09090b", 0.94)
	style.border_color = Color("#22c55e")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	hud_panel.add_theme_stylebox_override("panel", style)
	add_child(hud_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	hud_panel.add_child(vbox)

	stats_label = Label.new()
	stats_label.text = "DIAGNOSTICS ACTIVE\nEntities: 0 | Z-Counter: 100\nFPS: 60"
	stats_label.add_theme_font_size_override("font_size", 11)
	stats_label.add_theme_color_override("font_color", Color("#22c55e"))
	vbox.add_child(stats_label)

	btn_copy_state = Button.new()
	btn_copy_state.text = " Copy System State (JSON)"
	btn_copy_state.custom_minimum_size = Vector2(0.0, 26.0)
	btn_copy_state.focus_mode = Control.FOCUS_NONE
	btn_copy_state.add_theme_constant_override("icon_max_width", 14)

	var copy_icon: Texture2D = ThemeService.get_icon("icon_clone")
	if not copy_icon: copy_icon = ThemeService.get_icon("icon_save")
	if copy_icon: btn_copy_state.icon = copy_icon
	btn_copy_state.pressed.connect(_on_copy_state_json_pressed)

	var btn_s: StyleBoxFlat = StyleBoxFlat.new()
	btn_s.bg_color = Color("#1e293b")
	btn_s.border_color = Color("#22c55e")
	btn_s.set_border_width_all(1)
	btn_s.set_corner_radius_all(6)
	btn_copy_state.add_theme_stylebox_override("normal", btn_s)

	var btn_hov: StyleBoxFlat = btn_s.duplicate() as StyleBoxFlat
	btn_hov.bg_color = Color("#0f172a")
	btn_copy_state.add_theme_stylebox_override("hover", btn_hov)
	btn_copy_state.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_copy_state.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(btn_copy_state)


func _update_stats_display() -> void:
	if not main_ref: return

	var raw_ents: Variant = main_ref.get("all_entities")
	var entity_count: int = (raw_ents as Array).size() if raw_ents is Array else 0
	var fps: float = Engine.get_frames_per_second()
	var cam_pos: Vector2 = Vector2.ZERO
	var cam_zoom: float = 1.0

	if main_camera_valid():
		var camera: Camera2D = main_ref.get("main_camera") as Camera2D
		cam_pos = camera.position
		cam_zoom = camera.zoom.x

	var session: Dictionary = _load_session()
	var room_id: String = str(session.get("room_id", str(main_ref.get("current_room_id"))))
	if room_id.is_empty(): room_id = "room_main"

	stats_label.text = "DIAGNOSTICS | %d FPS\nRoom: %s | Entities: %d\nCam: (%d, %d) @ %.2fx" % [
		int(fps), room_id, entity_count, int(cam_pos.x), int(cam_pos.y), cam_zoom
	]


func main_camera_valid() -> bool:
	if main_ref == null: return false
	var cam: Variant = main_ref.get("main_camera")
	return cam != null and is_instance_valid(cam as Node)


func _on_copy_state_json_pressed() -> void:
	if not is_instance_valid(main_ref): return

	var cam_node: Camera2D = main_ref.get("main_camera") as Camera2D if main_camera_valid() else null
	var r_bounds: Rect2 = main_ref.get("room_bounds") as Rect2 if "room_bounds" in main_ref else Rect2(0.0, 0.0, 1920.0, 1080.0)
	var session: Dictionary = _load_session()

	var state_dump: Dictionary = {
		"timestamp": Time.get_datetime_string_from_system(),
		"engine_version": "Godot 4.x",
		"active_universe": {
			"id": str(session.get("universe_id", "default_universe")),
			"name": str(session.get("universe_name", "Default Universe"))
		},
		"room": {
			"id": str(session.get("room_id", str(main_ref.get("current_room_id")))),
			"title": str(main_ref.get("current_room_title")),
			"floor_y": float(main_ref.get("current_room_floor_y")),
			"wallpaper": str(main_ref.get("current_wallpaper_path")),
			"fill_mode": str(main_ref.get("current_wallpaper_fill_mode"))
		},
		"atmosphere": {
			"time_preset": str(session.get("time_preset", "day")),
			"weather_preset": str(session.get("weather_preset", "none"))
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


func _load_session() -> Dictionary:
	return JsonFileStore.read_dictionary(SESSION_FILE)


class DebugCanvasDraw extends Control:
	var overlay_ref: DiagnosticOverlay = null

	func _draw() -> void:
		if not overlay_ref or not overlay_ref.is_debug_active or not is_instance_valid(overlay_ref.main_ref):
			return

		var cam: Camera2D = overlay_ref.main_ref.get("main_camera") as Camera2D
		if not cam or not is_instance_valid(cam): return

		var raw_ents: Variant = overlay_ref.main_ref.get("all_entities")
		if not (raw_ents is Array): return

		for ent_var: Variant in (raw_ents as Array):
			if not ent_var is OwnEntity or not is_instance_valid(ent_var): continue
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
