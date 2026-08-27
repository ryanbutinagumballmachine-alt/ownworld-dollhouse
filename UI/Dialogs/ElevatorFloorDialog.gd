# ==============================================================================
# OWNWORLD — ELEVATOR FLOOR ROUTING DIALOG
# File: res://UI/Dialogs/ElevatorFloorDialog.gd
# Base Class: CanvasLayer (class_name ElevatorFloorDialog)
#
# Responsibility: Interactive elevator floor keypad modal. Queries building floor
# rosters, highlights the active floor, and dispatches passenger travel requests.
# ==============================================================================

class_name ElevatorFloorDialog
extends CanvasLayer

const MAX_PANEL_WIDTH: float = 460.0
const MAX_PANEL_HEIGHT: float = 420.0
const SESSION_FILE: String = "user://session.json"

var root_backdrop: Control = null
var center_container: CenterContainer = null
var root_panel: PanelContainer = null

var active_elevator: OwnEntity = null
var header_lbl: Label = null
var current_floor_label: Label = null
var keypad_grid: GridContainer = null

signal floor_travel_requested(elevator: OwnEntity, target_room_id: String, floor_name: String)


func _ready() -> void:
	name = "ElevatorFloorDialog"
	layer = 120
	visible = false
	add_to_group("modal_ui")
	_build_ui()
	_connect_system_signals()
	_update_responsive_layout()


func _connect_system_signals() -> void:
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null and not tree.root.size_changed.is_connected(_update_responsive_layout):
		tree.root.size_changed.connect(_update_responsive_layout)
	if not EventBus.theme_changed.is_connected(_on_theme_changed):
		EventBus.theme_changed.connect(_on_theme_changed)


func _on_theme_changed(_theme_data: Dictionary) -> void:
	_update_responsive_layout()
	if active_elevator != null and is_instance_valid(active_elevator):
		_render_keypad_buttons()


func _update_responsive_layout() -> void:
	if not is_instance_valid(root_panel): return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280.0, 720.0)
	var target_width: float = clampf(viewport_size.x * 0.90, 280.0, MAX_PANEL_WIDTH)
	var target_height: float = clampf(viewport_size.y * 0.80, 240.0, MAX_PANEL_HEIGHT)
	root_panel.custom_minimum_size = Vector2(target_width, target_height)
	root_panel.size = Vector2(target_width, target_height)


func _build_ui() -> void:
	root_backdrop = Control.new()
	root_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root_backdrop.gui_input.connect(_on_backdrop_gui_input)
	add_child(root_backdrop)

	var background_dim: ColorRect = ColorRect.new()
	background_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	background_dim.color = Color(0.0, 0.0, 0.0, 0.65)
	background_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_backdrop.add_child(background_dim)

	center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_PASS
	root_backdrop.add_child(center_container)

	root_panel = PanelContainer.new()
	root_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center_container.add_child(root_panel)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 8)
	root_panel.add_child(main_vbox)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	header_lbl = Label.new()
	header_lbl.text = "Elevator Keypad"
	header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_lbl.theme_type_variation = "HeaderLabel"
	header_hbox.add_child(header_lbl)

	var close_button: Button = Button.new()
	close_button.custom_minimum_size = Vector2(24.0, 24.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_constant_override("icon_max_width", 12)
	_apply_close_icon(close_button)
	close_button.pressed.connect(close_dialog)
	header_hbox.add_child(close_button)

	main_vbox.add_child(HSeparator.new())

	current_floor_label = Label.new()
	current_floor_label.text = "Active Building Floor: ..."
	current_floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_floor_label.theme_type_variation = "HintLabel"
	current_floor_label.add_theme_font_size_override("font_size", 11)
	main_vbox.add_child(current_floor_label)

	var keypad_scroll: ScrollContainer = ScrollContainer.new()
	keypad_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	keypad_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keypad_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	keypad_scroll.follow_focus = false
	main_vbox.add_child(keypad_scroll)

	keypad_grid = GridContainer.new()
	keypad_grid.columns = 2
	keypad_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keypad_grid.add_theme_constant_override("h_separation", 8)
	keypad_grid.add_theme_constant_override("v_separation", 8)
	keypad_scroll.add_child(keypad_grid)


func open_keypad(elevator_ent: OwnEntity) -> void:
	if not is_instance_valid(elevator_ent): return
	active_elevator = elevator_ent
	_update_responsive_layout()
	_render_keypad_buttons()
	visible = true


func close_dialog() -> void:
	visible = false
	active_elevator = null


func _render_keypad_buttons() -> void:
	if keypad_grid == null: return
	for child: Node in keypad_grid.get_children():
		child.queue_free()

	if active_elevator == null or not is_instance_valid(active_elevator):
		return

	var current_room_id: String = _get_current_room_id()
	var current_room_state: Dictionary = SaveSystem.load_room_state(current_room_id)
	var bldg_id: String = str(current_room_state.get("building_id", "building_main")).strip_edges()
	var bldg_name: String = str(current_room_state.get("building_name", "Main Building")).strip_edges()
	var current_floor_level: String = str(current_room_state.get("floor_level", "1F")).strip_edges()
	var current_title: String = str(current_room_state.get("room_title", "Main Room")).strip_edges()

	header_lbl.text = "Elevator — " + bldg_name
	current_floor_label.text = "Current Location: %s [%s]" % [current_title, current_floor_level]

	var floors: Array[Dictionary] = SaveSystem.get_building_floors(bldg_id)

	if floors.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No additional floors registered for %s.\nOpen the World Map in Edit Mode to add floors!" % bldg_name
		empty_label.theme_type_variation = "HintLabel"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		keypad_grid.add_child(empty_label)
		return

	var accent_color: Color = ThemeService.get_color("accent_primary", "#ec4899")
	var button_normal: Color = ThemeService.get_color("button_normal", "#fce7ed")
	var button_hover: Color = ThemeService.get_color("button_hover", "#fbcfe0")
	var panel_border: Color = ThemeService.get_color("panel_border", "#f9a8d4")
	var text_primary: Color = ThemeService.get_color("text_primary", "#6c2e3f")
	var corner_radius: int = ThemeService.get_corner_radius()

	for floor_data: Dictionary in floors:
		var room_id: String = str(floor_data.get("room_id", "")).strip_edges()
		var floor_label: String = str(floor_data.get("label", room_id)).strip_edges()
		var is_current: bool = (room_id == current_room_id)

		var button: Button = Button.new()
		button.text = " " + floor_label
		button.custom_minimum_size = Vector2(160.0, 38.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = (is_current or room_id.is_empty())
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_constant_override("icon_max_width", 16)
		_apply_button_icon(button, "icon_elevator" if is_current else "icon_door")

		var normal_style: StyleBoxFlat = StyleBoxFlat.new()
		normal_style.bg_color = button_normal
		normal_style.border_color = panel_border
		normal_style.set_border_width_all(1)
		normal_style.set_corner_radius_all(corner_radius)
		button.add_theme_stylebox_override("normal", normal_style)

		var hover_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
		hover_style.bg_color = button_hover
		hover_style.border_color = accent_color
		button.add_theme_stylebox_override("hover", hover_style)

		if is_current:
			var active_style: StyleBoxFlat = StyleBoxFlat.new()
			active_style.bg_color = accent_color
			active_style.border_color = accent_color
			active_style.set_border_width_all(1)
			active_style.set_corner_radius_all(corner_radius)
			button.add_theme_stylebox_override("disabled", active_style)
			button.add_theme_color_override("font_disabled_color", Color.WHITE)
			button.add_theme_color_override("icon_disabled_color", Color.WHITE)
		else:
			button.add_theme_color_override("font_color", text_primary)
			button.add_theme_color_override("font_hover_color", text_primary)

		var captured_room_id: String = room_id
		var captured_floor_name: String = floor_label
		button.pressed.connect(func() -> void: _on_floor_selected(captured_room_id, captured_floor_name))
		keypad_grid.add_child(button)


func _on_floor_selected(target_room_id: String, floor_name: String) -> void:
	var current_room_id: String = _get_current_room_id()
	if target_room_id.is_empty() or target_room_id == current_room_id or active_elevator == null or not is_instance_valid(active_elevator):
		return
	var elevator_ref: OwnEntity = active_elevator
	close_dialog()
	floor_travel_requested.emit(elevator_ref, target_room_id, floor_name)


func _get_current_room_id() -> String:
	var session: Dictionary = JsonFileStore.read_dictionary(SESSION_FILE)
	return str(session.get("room_id", "room_main"))


func _apply_button_icon(button: Button, icon_key: String) -> void:
	if button == null: return
	var icon_texture: Texture2D = ThemeService.get_icon(icon_key)
	if icon_texture != null: button.icon = icon_texture


func _apply_close_icon(button: Button) -> void:
	if button == null: return
	var icon_texture: Texture2D = ThemeService.get_icon("icon_close")
	if icon_texture != null: button.icon = icon_texture
	else: button.text = "✕"


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		close_dialog()
