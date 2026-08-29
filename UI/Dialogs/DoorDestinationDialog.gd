# ============================================================
# File: res://UI/Dialogs/DoorDestinationDialog.gd
# ============================================================

# ==============================================================================
# OWNWORLD — DOOR DESTINATION DIALOG (HYPER OPTIMIZED & LAYER 120)
# File: res://UI/Dialogs/DoorDestinationDialog.gd
# Base Class: HyperUIDialog
# ==============================================================================

class_name DoorDestinationDialog
extends HyperUIDialog

const MAP_DIRECTORY: String = "user://maps/"

var active_door_entity: OwnEntity = null
var header_lbl: Label = null
var lbl_name: Label = null
var lbl_target: Label = null
var lbl_custom: Label = null

var name_edit: LineEdit = null
var destination_option: OptionButton = null
var custom_room_edit: LineEdit = null
var btn_save: Button = null

var location_ids: Array[String] = []


func _init() -> void:
	max_panel_width = 500.0
	max_panel_height = 440.0


func _build_content() -> void:
	name = "DoorDestinationDialog"
	var is_mob: bool = is_mobile()
	var row_h: float = 34.0 if is_mob else 28.0

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	root_panel.add_child(vbox)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	vbox.add_child(header_hbox)

	header_lbl = Label.new()
	header_lbl.text = "Configure Doorway"
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

	vbox.add_child(HSeparator.new())

	lbl_name = Label.new()
	lbl_name.text = "Doorway Name / Label:"
	lbl_name.theme_type_variation = "HintLabel"
	lbl_name.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	vbox.add_child(lbl_name)

	name_edit = LineEdit.new()
	name_edit.placeholder_text = "e.g. Garden Entrance, Castle Gate..."
	name_edit.custom_minimum_size = Vector2(0.0, row_h)
	register_keyboard_dodge(name_edit)
	vbox.add_child(name_edit)

	lbl_target = Label.new()
	lbl_target.text = "Pick Map Location Destination:"
	lbl_target.theme_type_variation = "HintLabel"
	lbl_target.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	vbox.add_child(lbl_target)

	destination_option = OptionButton.new()
	destination_option.custom_minimum_size = Vector2(0.0, row_h)
	_enforce_dropdown_popup_limits(destination_option, 200)
	destination_option.item_selected.connect(_on_location_selected)
	vbox.add_child(destination_option)

	lbl_custom = Label.new()
	lbl_custom.text = "Or Custom Room ID:"
	lbl_custom.theme_type_variation = "HintLabel"
	lbl_custom.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	vbox.add_child(lbl_custom)

	custom_room_edit = LineEdit.new()
	custom_room_edit.placeholder_text = "e.g. room_secret_dungeon, room_balcony..."
	custom_room_edit.custom_minimum_size = Vector2(0.0, row_h)
	register_keyboard_dodge(custom_room_edit)
	vbox.add_child(custom_room_edit)

	vbox.add_child(HSeparator.new())

	btn_save = Button.new()
	btn_save.text = " Save Destination"
	btn_save.custom_minimum_size = Vector2(0.0, row_h + 4.0)
	btn_save.focus_mode = Control.FOCUS_NONE
	btn_save.add_theme_constant_override("icon_max_width", 16)
	btn_save.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	apply_button_icon(btn_save, "icon_save")
	btn_save.pressed.connect(_on_save_pressed)
	vbox.add_child(btn_save)


func _on_theme_updated() -> void:
	apply_button_icon(btn_save, "icon_save")
	if root_panel == null: 
		return
	for node: Node in root_panel.find_children("*", "Button", true, false):
		if node is Button and (node as Button).text == "✕":
			apply_close_icon(node as Button)
	if visible: 
		_populate_map_locations()


func open_for_door(door_ent: OwnEntity) -> void:
	if not is_instance_valid(door_ent):
		return
	active_door_entity = door_ent
	name_edit.text = door_ent.display_name
	custom_room_edit.text = door_ent.target_room_id
	_populate_map_locations()
	open_dialog()


func _on_close_requested() -> void:
	active_door_entity = null
	location_ids.clear()
	super._on_close_requested()


func _populate_map_locations() -> void:
	if destination_option == null: 
		return
	destination_option.clear()
	location_ids.clear()

	destination_option.add_item("(Use Custom Room ID Below)", 0)
	location_ids.append("")
	if active_door_entity == null: 
		return

	var current_universe_id: String = AppState.universe_id
	var current_room_id: String = AppState.room_id

	var pin_icon: Texture2D = ThemeService.get_icon("icon_pin")
	if pin_icon == null: 
		pin_icon = ThemeService.get_icon("icon_map")

	var map_path: String = MAP_DIRECTORY + current_universe_id + "_map.json"
	if not FileAccess.file_exists(map_path): 
		return

	var parsed: Dictionary = JsonFileStore.read_dictionary(map_path)
	if parsed.is_empty(): 
		return

	var pins: Variant = parsed.get("pins", [])
	if not pins is Array: 
		return

	var selected_index: int = 0
	for pin_variant: Variant in (pins as Array):
		if not pin_variant is Dictionary: 
			continue
		var pin_data: Dictionary = pin_variant as Dictionary
		var pin_name: String = str(pin_data.get("name", "Location")).strip_edges()
		var room_id: String = str(pin_data.get("room_id", "room_main")).strip_edges()
		if room_id.is_empty() or room_id == current_room_id: 
			continue

		var entry_label: String = "%s (%s)" % [pin_name, room_id]
		var item_id: int = location_ids.size()

		if pin_icon != null: 
			destination_option.add_icon_item(pin_icon, entry_label, item_id)
		else: 
			destination_option.add_item(entry_label, item_id)

		location_ids.append(room_id)
		if room_id == active_door_entity.target_room_id:
			selected_index = item_id

	destination_option.selected = selected_index


func _on_location_selected(index: int) -> void:
	if index > 0 and index < location_ids.size():
		custom_room_edit.text = location_ids[index]


func _on_save_pressed() -> void:
	if active_door_entity == null or not is_instance_valid(active_door_entity):
		_on_close_requested()
		return

	var current_room_id: String = AppState.room_id
	var new_name: String = name_edit.text.strip_edges()
	var new_target: String = custom_room_edit.text.strip_edges()

	if not new_target.is_empty() and new_target == current_room_id:
		new_target = "room_main" if current_room_id != "room_main" else "room_destination"
	if new_target.is_empty(): 
		new_target = "room_destination"
	if new_name.is_empty(): 
		new_name = "Doorway"

	active_door_entity.configure_as_portal(new_target, new_name)
	if active_door_entity.entity_type == Types.EntityType.CHARACTER:
		SaveSystem.update_character_in_cast(active_door_entity)

	SaveSystem.save_current_room_state()
	EventBus.entity_state_changed.emit(active_door_entity.entity_id)
	EventBus.notification_requested.emit("Door Leads to: " + active_door_entity.target_room_id, true)
	_on_close_requested()


func _enforce_dropdown_popup_limits(option_button: OptionButton, max_height: int = 200) -> void:
	if option_button == null: 
		return
	var popup: PopupMenu = option_button.get_popup()
	if popup == null: 
		return
	popup.max_size = Vector2i(4000, max_height)
	popup.about_to_popup.connect(func() -> void: popup.max_size = Vector2i(4000, max_height))
