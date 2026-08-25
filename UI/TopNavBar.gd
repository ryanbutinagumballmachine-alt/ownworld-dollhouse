# ============================================================
# File: res://UI/TopNavBar.gd
# ============================================================

# ==============================================================================
# OWNWORLD — TOP NAVIGATION BAR
# File: res://UI/TopNavBar.gd
# Base Class: CanvasLayer (class_name TopNavBar)
# ==============================================================================

class_name TopNavBar
extends CanvasLayer

var root_container: CenterContainer = null
var capsule_panel: PanelContainer = null
var hbox: HBoxContainer = null

var btn_menu: Button = null
var btn_map: Button = null
var btn_room: Button = null
var btn_undo: Button = null

signal open_main_menu_requested()
signal open_world_map_requested()
signal open_room_studio_requested()
signal undo_requested()


func _ready() -> void:
	name = "TopNavBar"
	layer = 100
	_build_nav_ui()
	_connect_system_signals()
	_apply_theme()


func _connect_system_signals() -> void:
	if not ThemeService.theme_changed.is_connected(_on_theme_changed):
		ThemeService.theme_changed.connect(_on_theme_changed)


func _build_nav_ui() -> void:
	root_container = CenterContainer.new()
	root_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root_container.offset_top = 14.0
	root_container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root_container)

	capsule_panel = PanelContainer.new()
	capsule_panel.theme_type_variation = "FloatingCapsule"
	capsule_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root_container.add_child(capsule_panel)

	hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	capsule_panel.add_child(hbox)

	btn_menu = _create_nav_btn("Menu", "icon_menu", func() -> void: open_main_menu_requested.emit())
	hbox.add_child(btn_menu)

	btn_map = _create_nav_btn("Map", "icon_map", func() -> void: open_world_map_requested.emit())
	hbox.add_child(btn_map)

	btn_room = _create_nav_btn("Room", "icon_room", func() -> void: open_room_studio_requested.emit())
	hbox.add_child(btn_room)

	btn_undo = _create_nav_btn("Undo", "icon_undo", func() -> void: undo_requested.emit())
	hbox.add_child(btn_undo)


func is_point_inside_nav(screen_pos: Vector2) -> bool:
	if capsule_panel != null and capsule_panel.is_visible_in_tree():
		return capsule_panel.get_global_rect().has_point(screen_pos)
	return false


func _create_nav_btn(title: String, icon_key: String, on_click: Callable) -> Button:
	var btn: Button = Button.new()
	btn.text = " " + title
	btn.custom_minimum_size = Vector2(0.0, 28.0)
	btn.focus_mode = Control.FOCUS_NONE
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_constant_override("icon_max_width", 16)
	btn.add_theme_constant_override("h_separation", 4)

	var icon_tex: Texture2D = ThemeService.get_icon(icon_key)
	if icon_tex != null:
		btn.icon = icon_tex
		btn.expand_icon = false

	btn.pressed.connect(on_click)
	return btn


func _on_theme_changed(_theme_data: Dictionary) -> void:
	_apply_theme()


func _apply_theme() -> void:
	if root_container:
		root_container.theme = ThemeService.create_theme()

	_apply_nav_icon(btn_menu, "icon_menu")
	_apply_nav_icon(btn_map, "icon_map")
	_apply_nav_icon(btn_room, "icon_room")
	_apply_nav_icon(btn_undo, "icon_undo")


func _apply_nav_icon(button: Button, icon_key: String) -> void:
	if button == null: return
	var icon_tex: Texture2D = ThemeService.get_icon(icon_key)
	if icon_tex != null: button.icon = icon_tex
	button.expand_icon = false
