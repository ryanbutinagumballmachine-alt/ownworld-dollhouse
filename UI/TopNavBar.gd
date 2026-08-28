# ==============================================================================
# OWNWORLD — TOP NAVIGATION BAR (LANDSCAPE SAFE & OS-ADAPTIVE)
# File: res://UI/TopNavBar.gd
# Base Class: CanvasLayer (class_name TopNavBar)
#
# Responsibility: Floating top navigation capsule. Provides quick access to
# main menu, handbook, floor switcher, camera focus, world map, and undo history.
# Fully shielded against landscape camera notches and gesture bars.
# ==============================================================================

class_name TopNavBar
extends CanvasLayer

var root_container: CenterContainer = null
var capsule_panel: PanelContainer = null
var hbox: HBoxContainer = null

var btn_menu: Button = null
var btn_help: Button = null
var btn_floors: Button = null
var btn_zoom: Button = null
var btn_map: Button = null
var btn_room: Button = null
var btn_undo: Button = null

signal open_main_menu_requested()
signal open_world_map_requested()
signal open_room_studio_requested()
signal open_floor_switcher_requested()
signal toggle_zoom_mode_requested()
signal undo_requested()
signal open_tutorial_requested()


func _ready() -> void:
	name = "TopNavBar"
	layer = 100
	add_to_group("top_nav_bar")
	_build_nav_ui()
	_connect_system_signals()
	_apply_theme()
	_apply_hardware_safe_margins()


func _is_mobile() -> bool:
	return ThemeEngine.is_mobile_platform()


func _connect_system_signals() -> void:
	if not ThemeService.theme_changed.is_connected(_on_theme_changed):
		ThemeService.theme_changed.connect(_on_theme_changed)
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null and not tree.root.size_changed.is_connected(_apply_hardware_safe_margins):
		tree.root.size_changed.connect(_apply_hardware_safe_margins)


## Protects against top notches and punch-holes in landscape orientation.
func _apply_hardware_safe_margins() -> void:
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	var top_margin: float = float(safe_area.position.y)
	if root_container != null:
		root_container.offset_top = maxf(10.0, top_margin + (6.0 if _is_mobile() else 2.0))


func _build_nav_ui() -> void:
	var is_mob: bool = _is_mobile()
	var btn_height: float = 38.0 if is_mob else 28.0

	root_container = CenterContainer.new()
	root_container.name = "RootContainer"
	root_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root_container.offset_top = 10.0
	root_container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root_container)

	capsule_panel = PanelContainer.new()
	capsule_panel.name = "CapsulePanel"
	capsule_panel.theme_type_variation = "FloatingCapsule"
	capsule_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root_container.add_child(capsule_panel)

	hbox = HBoxContainer.new()
	hbox.name = "NavHBox"
	hbox.add_theme_constant_override("separation", 6 if is_mob else 4)
	capsule_panel.add_child(hbox)

	btn_menu = _create_nav_btn("Menu", "icon_menu", btn_height, func() -> void: open_main_menu_requested.emit(), "Main Menu (Esc)")
	hbox.add_child(btn_menu)

	btn_help = _create_nav_btn("Guide", "icon_lore", btn_height, func() -> void: open_tutorial_requested.emit(), "Creator Handbook")
	hbox.add_child(btn_help)

	btn_floors = _create_nav_btn("1F ▼", "icon_elevator", btn_height, func() -> void: open_floor_switcher_requested.emit(), "Switch Building Floor")
	hbox.add_child(btn_floors)

	btn_zoom = _create_nav_btn("Zoom", "icon_search", btn_height, func() -> void: toggle_zoom_mode_requested.emit(), "Focus & Zoom Mode")
	btn_zoom.toggle_mode = true
	hbox.add_child(btn_zoom)

	btn_map = _create_nav_btn("Map", "icon_map", btn_height, func() -> void: open_world_map_requested.emit(), "World Map")
	hbox.add_child(btn_map)

	btn_room = _create_nav_btn("Room", "icon_room", btn_height, func() -> void: open_room_studio_requested.emit(), "Room Studio")
	hbox.add_child(btn_room)

	btn_undo = _create_nav_btn("Undo", "icon_undo", btn_height, func() -> void: undo_requested.emit(), "Undo (Ctrl+Z)")
	hbox.add_child(btn_undo)


## Returns the exact bottom Y screen coordinate of the navigation capsule for dynamic toast positioning.
func get_nav_bottom_y() -> float:
	if capsule_panel != null and capsule_panel.is_inside_tree():
		var capsule_rect: Rect2 = capsule_panel.get_global_rect()
		if capsule_rect.size.y > 0.0:
			return capsule_rect.end.y

	if root_container != null and root_container.is_inside_tree():
		return root_container.offset_top + (48.0 if _is_mobile() else 36.0)

	return 54.0


func is_point_inside_nav(screen_pos: Vector2) -> bool:
	if capsule_panel != null and capsule_panel.is_visible_in_tree():
		return capsule_panel.get_global_rect().has_point(screen_pos)
	return false


func set_zoom_button_state(is_zoom_active: bool) -> void:
	if btn_zoom != null:
		btn_zoom.button_pressed = is_zoom_active
		btn_zoom.text = " Focus" if is_zoom_active else " Zoom"
		btn_zoom.modulate = Color(1.3, 1.3, 1.3) if is_zoom_active else Color.WHITE


func update_current_floor_display(floor_level: String, _floor_title: String = "") -> void:
	if btn_floors != null:
		btn_floors.text = " %s ▼ " % (floor_level if not floor_level.is_empty() else "1F")


func _create_nav_btn(title: String, icon_key: String, btn_height: float, on_click: Callable, tooltip: String = "") -> Button:
	var is_mob: bool = _is_mobile()
	var btn: Button = Button.new()
	btn.text = " " + title
	btn.tooltip_text = tooltip
	btn.custom_minimum_size = Vector2(0.0, btn_height)
	btn.focus_mode = Control.FOCUS_NONE
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	btn.add_theme_constant_override("icon_max_width", 18 if is_mob else 14)
	btn.add_theme_constant_override("h_separation", 6 if is_mob else 4)

	var icon_tex: Texture2D = ThemeService.get_icon(icon_key)
	if icon_tex != null:
		btn.icon = icon_tex
		btn.expand_icon = false

	btn.pressed.connect(on_click)
	return btn


func _on_theme_changed(_theme_data: Dictionary) -> void:
	_apply_theme()


func _apply_theme() -> void:
	if root_container != null:
		root_container.theme = ThemeService.create_theme()

	_apply_nav_icon(btn_menu, "icon_menu")
	_apply_nav_icon(btn_help, "icon_lore")
	_apply_nav_icon(btn_floors, "icon_elevator")
	_apply_nav_icon(btn_zoom, "icon_search")
	_apply_nav_icon(btn_map, "icon_map")
	_apply_nav_icon(btn_room, "icon_room")
	_apply_nav_icon(btn_undo, "icon_undo")


func _apply_nav_icon(button: Button, icon_key: String) -> void:
	if button == null: return
	var icon_tex: Texture2D = ThemeService.get_icon(icon_key)
	if icon_tex != null: button.icon = icon_tex
	button.expand_icon = false
