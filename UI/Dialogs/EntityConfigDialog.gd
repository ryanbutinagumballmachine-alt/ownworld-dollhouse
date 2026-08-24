# ==============================================================================
# OWNWORLD — ENTITY CONFIGURATION DIALOG
# File: res://UI/Dialogs/EntityConfigDialog.gd
# Base Class: CanvasLayer (class_name EntityConfigDialog)
# ==============================================================================

class_name EntityConfigDialog
extends CanvasLayer

const MAX_PANEL_WIDTH: float = 520.0
const MAX_PANEL_HEIGHT: float = 580.0

var root_backdrop: Control = null
var center_container: CenterContainer = null
var root_panel: PanelContainer = null
var active_entity: OwnEntity = null

var header_lbl: Label = null
var lbl_scale: Label = null
var scale_val_lbl: Label = null
var scale_slider: HSlider = null

var lbl_type: Label = null
var type_option: OptionButton = null

var lbl_phys: Label = null
var check_rug: CheckBox = null
var check_wall: CheckBox = null
var check_float: CheckBox = null

var lbl_caps: Label = null
var check_food: CheckBox = null
var check_drink: CheckBox = null
var check_cup: CheckBox = null
var check_faucet: CheckBox = null
var check_lamp: CheckBox = null
var check_portal: CheckBox = null
var check_elevator: CheckBox = null

var btn_save: Button = null


func _ready() -> void:
	name = "EntityConfigDialog"
	layer = 120
	visible = false
	add_to_group("modal_ui")
	_build_ui()
	_connect_system_signals()
	_update_responsive_layout()


func _connect_system_signals() -> void:
	var tree: SceneTree = get_tree()
	if tree and tree.root and not tree.root.size_changed.is_connected(_update_responsive_layout):
		tree.root.size_changed.connect(_update_responsive_layout)
	if not EventBus.theme_changed.is_connected(_on_theme_changed):
		EventBus.theme_changed.connect(_on_theme_changed)


func _on_theme_changed(_theme_data: Dictionary) -> void:
	_refresh_theme_icons()
	_update_responsive_layout()


func _update_responsive_layout() -> void:
	if not is_instance_valid(root_panel): return
	var viewport: Viewport = get_viewport()
	var viewport_size: Vector2 = viewport.get_visible_rect().size if viewport != null else Vector2(1280.0, 720.0)
	var target_width: float = clampf(viewport_size.x * 0.90, 280.0, MAX_PANEL_WIDTH)
	var target_height: float = clampf(viewport_size.y * 0.90, 340.0, MAX_PANEL_HEIGHT)
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
	header_lbl.text = "Item Interactions & Capabilities"
	header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_lbl.theme_type_variation = "HeaderLabel"
	header_hbox.add_child(header_lbl)

	var close_button: Button = Button.new()
	close_button.custom_minimum_size = Vector2(24.0, 24.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_constant_override("icon_max_width", 12)
	_apply_close_icon(close_button)
	close_button.pressed.connect(save_and_close)
	header_hbox.add_child(close_button)

	main_vbox.add_child(HSeparator.new())

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = false
	main_vbox.add_child(scroll)

	var form_vbox: VBoxContainer = VBoxContainer.new()
	form_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(form_vbox)

	_build_scale_section(form_vbox)
	_build_type_section(form_vbox)
	_build_physics_section(form_vbox)
	_build_capabilities_section(form_vbox)

	main_vbox.add_child(HSeparator.new())

	btn_save = Button.new()
	btn_save.text = " Save Interactions"
	btn_save.custom_minimum_size = Vector2(0.0, 36.0)
	btn_save.focus_mode = Control.FOCUS_NONE
	btn_save.add_theme_constant_override("icon_max_width", 16)
	var save_icon: Texture2D = ThemeService.get_icon("icon_save")
	if save_icon != null: btn_save.icon = save_icon
	btn_save.pressed.connect(save_and_close)
	main_vbox.add_child(btn_save)


func _build_scale_section(parent: VBoxContainer) -> void:
	var scale_card: PanelContainer = PanelContainer.new()
	scale_card.theme_type_variation = "SubPanel"
	parent.add_child(scale_card)

	var scale_inner: VBoxContainer = VBoxContainer.new()
	scale_inner.add_theme_constant_override("separation", 4)
	scale_card.add_child(scale_inner)

	var scale_header: HBoxContainer = HBoxContainer.new()
	scale_inner.add_child(scale_header)

	lbl_scale = Label.new()
	lbl_scale.text = "Visual Size / Scale:"
	lbl_scale.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_scale.theme_type_variation = "HintLabel"
	scale_header.add_child(lbl_scale)

	scale_val_lbl = Label.new()
	scale_val_lbl.text = "100%"
	scale_val_lbl.theme_type_variation = "HeaderLabel"
	scale_header.add_child(scale_val_lbl)

	scale_slider = HSlider.new()
	scale_slider.min_value = 0.1
	scale_slider.max_value = 3.0
	scale_slider.step = 0.05
	scale_slider.value = 1.0
	scale_slider.custom_minimum_size = Vector2(0.0, 24.0)
	scale_slider.value_changed.connect(_on_scale_slider_changed)
	scale_inner.add_child(scale_slider)


func _build_type_section(parent: VBoxContainer) -> void:
	var type_card: PanelContainer = PanelContainer.new()
	type_card.theme_type_variation = "SubPanel"
	parent.add_child(type_card)

	var type_inner: VBoxContainer = VBoxContainer.new()
	type_inner.add_theme_constant_override("separation", 4)
	type_card.add_child(type_inner)

	lbl_type = Label.new()
	lbl_type.text = "Item Classification:"
	lbl_type.theme_type_variation = "HintLabel"
	type_inner.add_child(lbl_type)

	type_option = OptionButton.new()
	type_option.custom_minimum_size = Vector2(0.0, 34.0)
	type_inner.add_child(type_option)


func _build_physics_section(parent: VBoxContainer) -> void:
	var physics_card: PanelContainer = PanelContainer.new()
	physics_card.theme_type_variation = "SubPanel"
	parent.add_child(physics_card)

	var physics_inner: VBoxContainer = VBoxContainer.new()
	physics_inner.add_theme_constant_override("separation", 4)
	physics_card.add_child(physics_inner)

	lbl_phys = Label.new()
	lbl_phys.text = "Placement & Movement:"
	lbl_phys.theme_type_variation = "HintLabel"
	physics_inner.add_child(lbl_phys)

	check_rug = _create_icon_check("icon_rug", "Floor Decor / Rug (Stays under all furniture)")
	physics_inner.add_child(check_rug)

	check_wall = _create_icon_check("icon_wall", "Wall Mounted (Ignores gravity baseline)")
	physics_inner.add_child(check_wall)

	check_float = _create_icon_check("icon_float", "Can Float (Floats mid-air when dropped)")
	physics_inner.add_child(check_float)


func _build_capabilities_section(parent: VBoxContainer) -> void:
	var capabilities_card: PanelContainer = PanelContainer.new()
	capabilities_card.theme_type_variation = "SubPanel"
	parent.add_child(capabilities_card)

	var capabilities_inner: VBoxContainer = VBoxContainer.new()
	capabilities_inner.add_theme_constant_override("separation", 6)
	capabilities_card.add_child(capabilities_inner)

	lbl_caps = Label.new()
	lbl_caps.text = "Interactive Features:"
	lbl_caps.theme_type_variation = "HintLabel"
	capabilities_inner.add_child(lbl_caps)

	var roles_grid: GridContainer = GridContainer.new()
	roles_grid.columns = 2
	roles_grid.add_theme_constant_override("h_separation", 14)
	roles_grid.add_theme_constant_override("v_separation", 6)
	capabilities_inner.add_child(roles_grid)

	check_food = _create_icon_check("icon_apple", "Solid Food")
	roles_grid.add_child(check_food)

	check_drink = _create_icon_check("icon_drink", "Beverage")
	roles_grid.add_child(check_drink)

	check_cup = _create_icon_check("icon_cup", "Fillable Cup")
	roles_grid.add_child(check_cup)

	check_faucet = _create_icon_check("icon_faucet", "Water Stream")
	roles_grid.add_child(check_faucet)

	check_lamp = _create_icon_check("icon_lighting", "2D Light Glow")
	roles_grid.add_child(check_lamp)

	check_portal = _create_icon_check("icon_door", "Doorway")
	roles_grid.add_child(check_portal)

	check_elevator = _create_icon_check("icon_elevator", "Elevator")
	roles_grid.add_child(check_elevator)


func _populate_type_dropdown() -> void:
	if type_option == null: return
	type_option.clear()
	_add_icon_option(type_option, "icon_props", "Prop / Portable Item", int(Types.EntityType.PROP))
	_add_icon_option(type_option, "icon_cast", "Character (OC)", int(Types.EntityType.CHARACTER))
	_add_icon_option(type_option, "icon_furniture", "Furniture (Seat / Surface / Bed)", int(Types.EntityType.FURNITURE))
	_add_icon_option(type_option, "icon_backpack", "Bag / Storage Container", int(Types.EntityType.CONTAINER))


func _add_icon_option(option_button: OptionButton, icon_key: String, text_label: String, item_id: int) -> void:
	var icon_texture: Texture2D = ThemeService.get_popup_icon(icon_key)
	if icon_texture != null: option_button.add_icon_item(icon_texture, " " + text_label, item_id)
	else: option_button.add_item(text_label, item_id)


func _create_icon_check(icon_key: String, title: String) -> CheckBox:
	var checkbox: CheckBox = CheckBox.new()
	checkbox.text = " " + title
	checkbox.custom_minimum_size = Vector2(0.0, 28.0)
	checkbox.add_theme_constant_override("icon_max_width", 16)
	var icon_texture: Texture2D = ThemeService.get_icon(icon_key)
	if icon_texture != null: checkbox.icon = icon_texture
	return checkbox


func open_for_entity(entity: OwnEntity) -> void:
	if not is_instance_valid(entity): return
	active_entity = entity
	_populate_type_dropdown()
	_update_responsive_layout()

	scale_slider.value = entity.entity_scale
	scale_val_lbl.text = "%d%%" % int(entity.entity_scale * 100.0)

	for index: int in range(type_option.item_count):
		if type_option.get_item_id(index) == int(entity.entity_type):
			type_option.selected = index
			break

	check_rug.button_pressed = entity.is_floor_decor
	check_wall.button_pressed = entity.is_wall_mounted
	check_float.button_pressed = entity.can_float
	check_food.button_pressed = (entity.is_consumable and not entity.is_drink)
	check_drink.button_pressed = (entity.is_consumable and entity.is_drink)
	check_cup.button_pressed = entity.is_liquid_container
	check_faucet.button_pressed = entity.is_liquid_source
	check_lamp.button_pressed = entity.is_light_source
	check_portal.button_pressed = (entity.is_portal and not entity.is_elevator)
	check_elevator.button_pressed = entity.is_elevator
	visible = true


func _on_scale_slider_changed(value: float) -> void:
	if scale_val_lbl != null: scale_val_lbl.text = "%d%%" % int(value * 100.0)
	if active_entity != null and is_instance_valid(active_entity):
		active_entity.set_entity_scale(value)


func save_and_close() -> void:
	if active_entity != null and is_instance_valid(active_entity):
		var selected_type: Types.EntityType = type_option.get_selected_id() as Types.EntityType
		active_entity.set_entity_type(selected_type)
		active_entity.set_entity_scale(scale_slider.value)
		active_entity.base_entity_scale = scale_slider.value

		active_entity.configure_as_floor_decor(check_rug.button_pressed)
		active_entity.is_wall_mounted = check_wall.button_pressed
		active_entity.can_float = check_float.button_pressed

		if check_food.button_pressed:
			active_entity.configure_as_consumable()
			active_entity.is_drink = false
		elif check_drink.button_pressed:
			active_entity.configure_as_consumable()
			active_entity.is_drink = true
			if active_entity.fill_level <= 0: active_entity.fill_level = 2
		else:
			active_entity.unconfigure_consumable()

		active_entity.is_liquid_container = check_cup.button_pressed

		if check_faucet.button_pressed:
			if not active_entity.is_liquid_source: active_entity.configure_as_liquid_source()
		else:
			active_entity.unconfigure_liquid_source()

		if check_lamp.button_pressed:
			if not active_entity.is_light_source: active_entity.configure_as_light_source()
		else:
			active_entity.unconfigure_light_source()

		if check_elevator.button_pressed:
			if not active_entity.is_elevator: active_entity.configure_as_elevator(active_entity.elevator_floors, active_entity.display_name)
		elif check_portal.button_pressed:
			if not active_entity.is_portal or active_entity.is_elevator: active_entity.configure_as_portal(active_entity.target_room_id, active_entity.display_name)
		else:
			active_entity.unconfigure_portal_and_elevator()

		SaveSystem.update_character_in_cast(active_entity)
		SaveSystem.save_current_room_state()
		EventBus.entity_state_changed.emit(active_entity.entity_id)
		EventBus.notification_requested.emit("Saved: " + active_entity.display_name, true)

	visible = false
	active_entity = null


func _refresh_theme_icons() -> void:
	if btn_save != null:
		var save_icon: Texture2D = ThemeService.get_icon("icon_save")
		if save_icon != null: btn_save.icon = save_icon

	if check_rug != null: _apply_checkbox_icon(check_rug, "icon_rug")
	if check_wall != null: _apply_checkbox_icon(check_wall, "icon_wall")
	if check_float != null: _apply_checkbox_icon(check_float, "icon_float")
	if check_food != null: _apply_checkbox_icon(check_food, "icon_apple")
	if check_drink != null: _apply_checkbox_icon(check_drink, "icon_drink")
	if check_cup != null: _apply_checkbox_icon(check_cup, "icon_cup")
	if check_faucet != null: _apply_checkbox_icon(check_faucet, "icon_faucet")
	if check_lamp != null: _apply_checkbox_icon(check_lamp, "icon_lighting")
	if check_portal != null: _apply_checkbox_icon(check_portal, "icon_door")
	if check_elevator != null: _apply_checkbox_icon(check_elevator, "icon_elevator")


func _apply_checkbox_icon(checkbox: CheckBox, icon_key: String) -> void:
	if checkbox == null: return
	var icon_texture: Texture2D = ThemeService.get_icon(icon_key)
	if icon_texture != null: checkbox.icon = icon_texture


func _apply_close_icon(button: Button) -> void:
	if button == null: return
	var close_icon: Texture2D = ThemeService.get_icon("icon_close")
	if close_icon != null: button.icon = close_icon
	else: button.text = "✕"


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		save_and_close()
