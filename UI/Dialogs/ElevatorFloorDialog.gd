# ============================================================
# File: res://UI/Dialogs/ElevatorFloorDialog.gd
# ============================================================

# ==============================================================================
# OWNWORLD — ELEVATOR FLOOR ROUTING DIALOG (HYPER OPTIMIZED & LAYER 120)
# File: res://UI/Dialogs/ElevatorFloorDialog.gd
# Base Class: HyperUIDialog
# ==============================================================================

class_name ElevatorFloorDialog
extends HyperUIDialog

var active_elevator: OwnEntity = null
var header_lbl: Label = null
var current_floor_label: Label = null
var keypad_grid: GridContainer = null

signal floor_travel_requested(elevator: OwnEntity, target_room_id: String, floor_name: String)


func _init() -> void:
	max_panel_width = 520.0
	max_panel_height = 460.0


func _build_content() -> void:
	name = "ElevatorFloorDialog"
	var is_mob: bool = is_mobile()

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 6)
	root_panel.add_child(main_vbox)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	header_lbl = Label.new()
	header_lbl.text = "Elevator Keypad"
	header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_lbl.theme_type_variation = "HeaderLabel"
	header_lbl.add_theme_font_size_override("font_size", 14 if is_mob else 12)
	header_hbox.add_child(header_lbl)

	var close_button: Button = Button.new()
	close_button.custom_minimum_size = Vector2(28.0 if is_mob else 22.0, 28.0 if is_mob else 22.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_constant_override("icon_max_width", 12)
	apply_close_icon(close_button)
	close_button.pressed.connect(_on_close_requested)
	header_hbox.add_child(close_button)

	main_vbox.add_child(HSeparator.new())

	current_floor_label = Label.new()
	current_floor_label.text = "Active Building Floor: ..."
	current_floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_floor_label.theme_type_variation = "HintLabel"
	current_floor_label.add_theme_font_size_override("font_size", 12 if is_mob else 11)
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


func _on_theme_updated() -> void:
	if active_elevator != null and is_instance_valid(active_elevator):
		_render_keypad_buttons()
	if root_panel == null: 
		return
	for node: Node in root_panel.find_children("*", "Button", true, false):
		if node is Button and (node as Button).text == "✕":
			apply_close_icon(node as Button)


func open_keypad(elevator_ent: OwnEntity) -> void:
	if not is_instance_valid(elevator_ent): 
		return
	active_elevator = elevator_ent
	_render_keypad_buttons()
	open_dialog()


func _on_close_requested() -> void:
	active_elevator = null
	super._on_close_requested()


func _render_keypad_buttons() -> void:
	if keypad_grid == null: 
		return
	for child: Node in keypad_grid.get_children():
		child.queue_free()

	if active_elevator == null or not is_instance_valid(active_elevator):
		return

	var is_mob: bool = is_mobile()
	var current_room_id: String = AppState.room_id
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
		empty_label.add_theme_font_size_override("font_size", 11 if is_mob else 10)
		keypad_grid.add_child(empty_label)
		return

	var accent_color: Color = ThemeService.get_color("accent_primary", "#ec4899")
	var button_normal: Color = ThemeService.get_color("button_normal", "#fce7ed")
	var button_hover: Color = ThemeService.get_color("button_hover", "#fbcfe0")
	var panel_border: Color = ThemeService.get_color("panel_border", "#f9a8d4")
	var text_primary: Color = ThemeService.get_color("text_primary", "#6c2e3f")
	var corner_radius: int = ThemeService.get_corner_radius()
	var btn_h: float = 42.0 if is_mob else 34.0

	for floor_data: Dictionary in floors:
		var room_id: String = str(floor_data.get("room_id", "")).strip_edges()
		var floor_label: String = str(floor_data.get("label", room_id)).strip_edges()
		var is_current: bool = (room_id == current_room_id)

		var button: Button = Button.new()
		button.text = " " + floor_label
		button.custom_minimum_size = Vector2(0.0, btn_h)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = (is_current or room_id.is_empty())
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_constant_override("icon_max_width", 18 if is_mob else 14)
		button.add_theme_font_size_override("font_size", 12 if is_mob else 11)
		apply_button_icon(button, "icon_elevator" if is_current else "icon_door")

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
	var current_room_id: String = AppState.room_id
	if target_room_id.is_empty() or target_room_id == current_room_id or active_elevator == null or not is_instance_valid(active_elevator):
		return
	var elevator_ref: OwnEntity = active_elevator
	_on_close_requested()
	floor_travel_requested.emit(elevator_ref, target_room_id, floor_name)
