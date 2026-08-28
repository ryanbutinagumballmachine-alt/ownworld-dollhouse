# ==============================================================================
# OWNWORLD — MOBILE VIEW & TOUCH SIMULATOR (DESKTOP / LAPTOP DEV TOOL)
# File: res://tools/MobileViewSimulator.gd
# Base Class: CanvasLayer (class_name MobileViewSimulator)
#
# Responsibility: On-device mobile landscape simulation for PC & laptop developers.
# Features live aspect ratio switching (16:9 to 21:9), camera punch-hole/notch
# simulation, mouse-to-touch emulation, and instant Mobile/Desktop UI profile toggles.
# Automatically disables itself on real mobile hardware for zero runtime overhead.
# ==============================================================================

class_name MobileViewSimulator
extends CanvasLayer

# Keyboard Shortcut Mapping
const KEY_TOGGLE_HUD: Key = KEY_F2
const KEY_CYCLE_RESOLUTION: Key = KEY_F3
const KEY_TOGGLE_NOTCH: Key = KEY_F4
const KEY_TOGGLE_MOBILE_UI: Key = KEY_F5

const RESOLUTION_PRESETS: Array[Dictionary] = [
	{
		"name": "Standard Phone (16:9)",
		"size": Vector2i(1280, 720),
		"aspect": "16:9",
		"notch_width": 0.0
	},
	{
		"name": "Modern Flagship (19.5:9 - iPhone 15 / Galaxy S24)",
		"size": Vector2i(1560, 720),
		"aspect": "19.5:9",
		"notch_width": 42.0
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

var active_preset_index: int = 1
var is_notch_visible: bool = true
var is_hud_visible: bool = true

var hud_panel: PanelContainer = null
var hud_vbox: VBoxContainer = null
var preset_opt: OptionButton = null
var btn_toggle_notch: Button = null
var btn_toggle_ui_mode: Button = null
var btn_center_window: Button = null
var status_lbl: Label = null

var notch_overlay: NotchDraw = null


func _ready() -> void:
	name = "MobileViewSimulator"
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Disable entirely on physical mobile devices
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		queue_free()
		return

	_enable_touch_emulation()
	_build_notch_overlay()
	_build_floating_hud()
	
	# Apply initial mobile simulation profile
	ThemeEngine.force_mobile_override = true
	call_deferred("_apply_preset", active_preset_index)


func _enable_touch_emulation() -> void:
	ProjectSettings.set_setting("input_devices/pointing/emulate_touch_from_mouse", true)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.keycode:
		KEY_TOGGLE_HUD:
			toggle_hud()
			get_viewport().set_input_as_handled()
		KEY_CYCLE_RESOLUTION:
			cycle_next_preset()
			get_viewport().set_input_as_handled()
		KEY_TOGGLE_NOTCH:
			toggle_notch()
			get_viewport().set_input_as_handled()
		KEY_TOGGLE_MOBILE_UI:
			toggle_ui_profile()
			get_viewport().set_input_as_handled()


func toggle_hud() -> void:
	is_hud_visible = not is_hud_visible
	if hud_panel: hud_panel.visible = is_hud_visible
	EventBus.notification_requested.emit("Simulator HUD: " + ("Shown" if is_hud_visible else "Hidden") + " (F2)", true)


func toggle_notch() -> void:
	is_notch_visible = not is_notch_visible
	if notch_overlay: notch_overlay.queue_redraw()
	EventBus.notification_requested.emit("Simulated Notch: " + ("ON" if is_notch_visible else "OFF") + " (F4)", true)


func toggle_ui_profile() -> void:
	ThemeEngine.force_mobile_override = not ThemeEngine.force_mobile_override
	ThemeService.apply_theme_globally()
	_update_status_display()
	EventBus.notification_requested.emit("UI Mode: " + ("Mobile (48dp Touch Targets)" if ThemeEngine.force_mobile_override else "Desktop (Precision Pointer)") + " (F5)", true)


func cycle_next_preset() -> void:
	active_preset_index = (active_preset_index + 1) % RESOLUTION_PRESETS.size()
	_apply_preset(active_preset_index)


func _apply_preset(index: int) -> void:
	if index < 0 or index >= RESOLUTION_PRESETS.size():
		return

	active_preset_index = index
	var preset: Dictionary = RESOLUTION_PRESETS[active_preset_index]
	var target_size: Vector2i = preset["size"] as Vector2i

	# Resize desktop window
	DisplayServer.window_set_size(target_size)
	_center_window_on_screen()

	if preset_opt:
		preset_opt.selected = active_preset_index

	if notch_overlay:
		notch_overlay.queue_redraw()

	_update_status_display()
	EventBus.notification_requested.emit("Resized to: %s [%dx%d]" % [str(preset["name"]), target_size.x, target_size.y], true)


func _center_window_on_screen() -> void:
	var screen_index: int = DisplayServer.window_get_current_screen()
	var screen_rect: Rect2i = DisplayServer.screen_get_usable_rect(screen_index)
	var window_size: Vector2i = DisplayServer.window_get_size()
	var centered_pos: Vector2i = screen_rect.position + (screen_rect.size - window_size) / 2
	DisplayServer.window_set_position(centered_pos)


func _build_notch_overlay() -> void:
	notch_overlay = NotchDraw.new()
	notch_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	notch_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notch_overlay.sim_ref = self
	add_child(notch_overlay)


func _build_floating_hud() -> void:
	hud_panel = PanelContainer.new()
	hud_panel.name = "SimulatorHUD"
	hud_panel.position = Vector2(16.0, 16.0)
	hud_panel.custom_minimum_size = Vector2(280.0, 120.0)
	hud_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#09090b", 0.92)
	style.border_color = Color("#ec4899")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	hud_panel.add_theme_stylebox_override("panel", style)
	add_child(hud_panel)

	hud_vbox = VBoxContainer.new()
	hud_vbox.add_theme_constant_override("separation", 6)
	hud_panel.add_child(hud_vbox)

	var title_hbox: HBoxContainer = HBoxContainer.new()
	hud_vbox.add_child(title_hbox)

	var title_lbl: Label = Label.new()
	title_lbl.text = "MOBILE SIMULATOR (PC DEV)"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 11)
	title_lbl.add_theme_color_override("font_color", Color("#ec4899"))
	title_hbox.add_child(title_lbl)

	var btn_hide: Button = Button.new()
	btn_hide.text = "–"
	btn_hide.custom_minimum_size = Vector2(22.0, 20.0)
	btn_hide.focus_mode = Control.FOCUS_NONE
	btn_hide.pressed.connect(toggle_hud)
	title_hbox.add_child(btn_hide)

	status_lbl = Label.new()
	status_lbl.text = "Preset: 19.5:9 | Mode: Mobile UI"
	status_lbl.add_theme_font_size_override("font_size", 10)
	status_lbl.add_theme_color_override("font_color", Color.WHITE)
	hud_vbox.add_child(status_lbl)

	preset_opt = OptionButton.new()
	preset_opt.custom_minimum_size = Vector2(0.0, 26.0)
	preset_opt.add_theme_font_size_override("font_size", 10)
	for i: int in range(RESOLUTION_PRESETS.size()):
		preset_opt.add_item(str(RESOLUTION_PRESETS[i]["name"]), i)
	preset_opt.selected = active_preset_index
	preset_opt.item_selected.connect(_on_dropdown_preset_selected)
	hud_vbox.add_child(preset_opt)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	hud_vbox.add_child(btn_row)

	btn_toggle_notch = Button.new()
	btn_toggle_notch.text = "Notch (F4)"
	btn_toggle_notch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_toggle_notch.custom_minimum_size = Vector2(0.0, 24.0)
	btn_toggle_notch.focus_mode = Control.FOCUS_NONE
	btn_toggle_notch.add_theme_font_size_override("font_size", 9)
	btn_toggle_notch.pressed.connect(toggle_notch)
	btn_row.add_child(btn_toggle_notch)

	btn_toggle_ui_mode = Button.new()
	btn_toggle_ui_mode.text = "UI Mode (F5)"
	btn_toggle_ui_mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_toggle_ui_mode.custom_minimum_size = Vector2(0.0, 24.0)
	btn_toggle_ui_mode.focus_mode = Control.FOCUS_NONE
	btn_toggle_ui_mode.add_theme_font_size_override("font_size", 9)
	btn_toggle_ui_mode.pressed.connect(toggle_ui_profile)
	btn_row.add_child(btn_toggle_ui_mode)

	btn_center_window = Button.new()
	btn_center_window.text = "Center"
	btn_center_window.custom_minimum_size = Vector2(50.0, 24.0)
	btn_center_window.focus_mode = Control.FOCUS_NONE
	btn_center_window.add_theme_font_size_override("font_size", 9)
	btn_center_window.pressed.connect(_center_window_on_screen)
	btn_row.add_child(btn_center_window)


func _on_dropdown_preset_selected(index: int) -> void:
	_apply_preset(index)


func _update_status_display() -> void:
	if not status_lbl: return
	var preset: Dictionary = RESOLUTION_PRESETS[active_preset_index]
	var mode_name: String = "Mobile UI (48dp)" if ThemeEngine.force_mobile_override else "Desktop UI (Compact)"
	status_lbl.text = "%s  |  %s" % [str(preset["aspect"]), mode_name]


# --- SIMULATED HARDWARE NOTCH & PUNCH-HOLE DRAWING ---

class NotchDraw extends Control:
	var sim_ref: MobileViewSimulator = null

	func _draw() -> void:
		if not sim_ref or not sim_ref.is_notch_visible:
			return

		var vp_size: Vector2 = get_viewport_rect().size
		var preset: Dictionary = sim_ref.RESOLUTION_PRESETS[sim_ref.active_preset_index]
		var notch_w: float = float(preset["notch_width"])

		if notch_w <= 0.0:
			return

		# 1. Left Hardware Camera Punch-Hole & Notch
		var punch_radius: float = 14.0
		var punch_pos: Vector2 = Vector2(notch_w * 0.5, vp_size.y * 0.5)
		draw_circle(punch_pos, punch_radius + 2.0, Color(0.0, 0.0, 0.0, 0.85))
		draw_circle(punch_pos, punch_radius, Color("#09090b"))
		draw_circle(punch_pos, punch_radius - 5.0, Color("#1e1b4b"))

		# 2. Simulated Safe Area Margin Boundaries (Dotted Lines)
		var safe_color: Color = Color("#ec4899", 0.45)
		draw_line(Vector2(notch_w, 0.0), Vector2(notch_w, vp_size.y), safe_color, 1.5)
		draw_line(Vector2(vp_size.x - notch_w, 0.0), Vector2(vp_size.x - notch_w, vp_size.y), safe_color, 1.5)
		draw_line(Vector2(0.0, 10.0), Vector2(vp_size.x, 10.0), safe_color, 1.0)
		draw_line(Vector2(0.0, vp_size.y - 12.0), Vector2(vp_size.x, vp_size.y - 12.0), safe_color, 1.0)

		# 3. Bottom Gesture Bar Indicator (Home Pill)
		var pill_w: float = 140.0
		var pill_h: float = 4.5
		var pill_pos: Vector2 = Vector2((vp_size.x - pill_w) * 0.5, vp_size.y - 8.0)
		draw_rect(Rect2(pill_pos, Vector2(pill_w, pill_h)), Color(1.0, 1.0, 1.0, 0.65), true)
