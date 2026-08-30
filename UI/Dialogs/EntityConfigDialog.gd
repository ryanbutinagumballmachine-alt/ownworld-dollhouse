# ==============================================================================
# OWNWORLD — ENTITY CONFIGURATION DIALOG (HYPER OPTIMIZED)
# File: res://UI/Dialogs/EntityConfigDialog.gd
# Base Class: HyperUIDialog
# ==============================================================================

class_name EntityConfigDialog
extends HyperUIDialog

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
var check_stairs: CheckBox = null
var check_elevator: CheckBox = null

var btn_save: Button = null


func _init() -> void:
	max_panel_width = 620.0
	max_panel_height = 580.0


func _build_content() -> void:
	name = "EntityConfigDialog"
	var is_mob: bool = is_mobile()
	var row_h: float = 34.0 if is_mob else 28.0

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 6)
	root_panel.add_child(main_vbox)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	header_lbl = Label.new()
	header_lbl.text = "Item Interactions & Capabilities"
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

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = false
	main_vbox.add_child(scroll)

	var form_vbox: VBoxContainer = VBoxContainer.new()
	form_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(form_vbox)

	_build_scale_section(form_vbox, row_h, is_mob)
	_build_type_section(form_vbox, row_h, is_mob)
	_build_physics_section(form_vbox, row_h, is_mob)
	_build_capabilities_section(form_vbox, row_h, is_mob)

	main_vbox.add_child(HSeparator.new())

	btn_save = Button.new()
	btn_save.text = " Save Interactions"
	btn_save.custom_minimum_size = Vector2(0.0, row_h + 4.0)
	btn_save.focus_mode = Control.FOCUS_NONE
	btn_save.add_theme_constant_override("icon_max_width", 16)
	btn_save.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	apply_button_icon(btn_save, "icon_save")
	btn_save.pressed.connect(_on_save_pressed)
	main_vbox.add_child(btn_save)


func _build_scale_section(parent: VBoxContainer, _row_h: float, _is_mob: bool) -> void:
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
	lbl_scale.add_theme_font_size_override("font_size", 11 if is_mobile() else 10)
	scale_header.add_child(lbl_scale)

	scale_val_lbl = Label.new()
	scale_val_lbl.text = "100%"
	scale_val_lbl.theme_type_variation = "HeaderLabel"
	scale_val_lbl.add_theme_font_size_override("font_size", 12 if is_mobile() else 11)
	scale_header.add_child(scale_val_lbl)

	scale_slider = HSlider.new()
	scale_slider.min_value = 0.1
	scale_slider.max_value = 3.0
	scale_slider.step = 0.05
	scale_slider.value = 1.0
	scale_slider.custom_minimum_size = Vector2(0.0, 24.0)
	scale_slider.value_changed.connect(_on_scale_slider_changed)
	scale_inner.add_child(scale_slider)


func _build_type_section(parent: VBoxContainer, row_h: float, _is_mob: bool) -> void:
	var type_card: PanelContainer = PanelContainer.new()
	type_card.theme_type_variation = "SubPanel"
	parent.add_child(type_card)

	var type_inner: VBoxContainer = VBoxContainer.new()
	type_inner.add_theme_constant_override("separation", 4)
	type_card.add_child(type_inner)

	lbl_type = Label.new()
	lbl_type.text = "Item Classification:"
	lbl_type.theme_type_variation = "HintLabel"
	lbl_type.add_theme_font_size_override("font_size", 11 if is_mobile() else 10)
	type_inner.add_child(lbl_type)

	type_option = OptionButton.new()
	type_option.custom_minimum_size = Vector2(0.0, row_h)
	type_inner.add_child(type_option)


func _build_physics_section(parent: VBoxContainer, row_h: float, is_mob: bool) -> void:
	var physics_card: PanelContainer = PanelContainer.new()
	physics_card.theme_type_variation = "SubPanel"
	parent.add_child(physics_card)

	var physics_inner: VBoxContainer = VBoxContainer.new()
	physics_inner.add_theme_constant_override("separation", 4)
	physics_card.add_child(physics_inner)

	lbl_phys = Label.new()
	lbl_phys.text = "Placement & Movement:"
	lbl_phys.theme_type_variation = "HintLabel"
	lbl_phys.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	physics_inner.add_child(lbl_phys)

	check_rug = _create_icon_check("icon_rug", "Floor Decor / Rug (Stays under all furniture)", row_h, is_mob)
	physics_inner.add_child(check_rug)

	check_wall = _create_icon_check("icon_wall", "Wall Mounted (Ignores gravity baseline)", row_h, is_mob)
	physics_inner.add_child(check_wall)

	check_float = _create_icon_check("icon_float", "Can Float (Floats mid-air when dropped)", row_h, is_mob)
	physics_inner.add_child(check_float)


func _build_capabilities_section(parent: VBoxContainer, row_h: float, is_mob: bool) -> void:
	var capabilities_card: PanelContainer = PanelContainer.new()
	capabilities_card.theme_type_variation = "SubPanel"
	parent.add_child(capabilities_card)

	var capabilities_inner: VBoxContainer = VBoxContainer.new()
	capabilities_inner.add_theme_constant_override("separation", 6)
	capabilities_card.add_child(capabilities_inner)

	lbl_caps = Label.new()
	lbl_caps.text = "Interactive Features:"
	lbl_caps.theme_type_variation = "HintLabel"
	lbl_caps.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	capabilities_inner.add_child(lbl_caps)

	var roles_grid: GridContainer = GridContainer.new()
	roles_grid.columns = 2
	roles_grid.add_theme_constant_override("h_separation", 12)
	roles_grid.add_theme_constant_override("v_separation", 4)
	capabilities_inner.add_child(roles_grid)

	check_food = _create_icon_check("icon_apple", "Solid Food", row_h, is_mob)
	roles_grid.add_child(check_food)

	check_drink = _create_icon_check("icon_drink", "Beverage", row_h, is_mob)
	roles_grid.add_child(check_drink)

	check_cup = _create_icon_check("icon_cup", "Fillable Cup", row_h, is_mob)
	roles_grid.add_child(check_cup)

	check_faucet = _create_icon_check("icon_faucet", "Water Stream", row_h, is_mob)
	roles_grid.add_child(check_faucet)

	check_lamp = _create_icon_check("icon_lighting", "2D Light Glow", row_h, is_mob)
	roles_grid.add_child(check_lamp)

	check_portal = _create_icon_check("icon_door", "Doorway", row_h, is_mob)
	roles_grid.add_child(check_portal)

	check_stairs = _create_icon_check("icon_stairs", "Stairs (Auto-Climb)", row_h, is_mob)
	roles_grid.add_child(check_stairs)

	check_elevator = _create_icon_check("icon_elevator", "Elevator", row_h, is_mob)
	roles_grid.add_child(check_elevator)


func _populate_type_dropdown() -> void:
	if not is_instance_valid(type_option): 
		return
	type_option.clear()
	_add_icon_option(type_option, "icon_props", "Prop / Portable Item", int(Types.EntityType.PROP))
	_add_icon_option(type_option, "icon_cast", "Character", int(Types.EntityType.CHARACTER))
	_add_icon_option(type_option, "icon_furniture", "Furniture (Seat / Surface / Bed)", int(Types.EntityType.FURNITURE))
	_add_icon_option(type_option, "icon_backpack", "Bag / Storage Container", int(Types.EntityType.CONTAINER))


func _add_icon_option(option_button: OptionButton, icon_key: String, text_label: String, item_id: int) -> void:
	var icon_texture: Texture2D = ThemeService.get_popup_icon(icon_key)
	if icon_texture != null: 
		option_button.add_icon_item(icon_texture, " " + text_label, item_id)
	else: 
		option_button.add_item(text_label, item_id)


func _create_icon_check(icon_key: String, title: String, row_h: float, is_mob: bool) -> CheckBox:
	var checkbox: CheckBox = CheckBox.new()
	checkbox.text = " " + title
	checkbox.custom_minimum_size = Vector2(0.0, row_h)
	checkbox.add_theme_constant_override("icon_max_width", 18 if is_mob else 16)
	checkbox.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	apply_checkbox_icon(checkbox, icon_key)
	return checkbox


func open_for_entity(entity: OwnEntity) -> void:
	if not is_instance_valid(entity): 
		return
	active_entity = entity
	_populate_type_dropdown()

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
	check_portal.button_pressed = (entity.is_portal and not entity.is_elevator and not entity.is_stairs)
	check_stairs.button_pressed = entity.is_stairs
	check_elevator.button_pressed = entity.is_elevator
	open_dialog()


func _on_scale_slider_changed(value: float) -> void:
	if is_instance_valid(scale_val_lbl): 
		scale_val_lbl.text = "%d%%" % int(value * 100.0)
	if is_instance_valid(active_entity):
		active_entity.set_entity_scale(value)


func _on_save_pressed() -> void:
	if is_instance_valid(active_entity):
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
			if active_entity.fill_level <= 0: 
				active_entity.fill_level = 2
		else:
			active_entity.unconfigure_consumable()

		active_entity.is_liquid_container = check_cup.button_pressed

		if check_faucet.button_pressed:
			if not active_entity.is_liquid_source: 
				active_entity.configure_as_liquid_source()
		else:
			active_entity.unconfigure_liquid_source()

		if check_lamp.button_pressed:
			if not active_entity.is_light_source: 
				active_entity.configure_as_light_source()
		else:
			active_entity.unconfigure_light_source()

		if check_stairs.button_pressed:
			if not active_entity.is_stairs: 
				active_entity.configure_as_stairs(active_entity.display_name)
		elif check_elevator.button_pressed:
			if not active_entity.is_elevator: 
				active_entity.configure_as_elevator(active_entity.elevator_floors, active_entity.display_name)
		elif check_portal.button_pressed:
			if not active_entity.is_portal or active_entity.is_elevator or active_entity.is_stairs:
				active_entity.configure_as_portal(active_entity.target_room_id, active_entity.display_name)
		else:
			active_entity.unconfigure_portal_and_elevator()

		CapabilitySynchronizer.synchronize(active_entity)
		SaveSystem.update_character_in_cast(active_entity)
		SaveSystem.save_current_room_state()
		EventBus.entity_state_changed.emit(active_entity.entity_id)
		EventBus.notification_requested.emit("Saved: " + active_entity.display_name, true)

	_on_close_requested()


func _on_close_requested() -> void:
	active_entity = null
	super._on_close_requested()


func _on_theme_updated() -> void:
	apply_button_icon(btn_save, "icon_save")
	if is_instance_valid(check_rug): apply_checkbox_icon(check_rug, "icon_rug")
	if is_instance_valid(check_wall): apply_checkbox_icon(check_wall, "icon_wall")
	if is_instance_valid(check_float): apply_checkbox_icon(check_float, "icon_float")
	if is_instance_valid(check_food): apply_checkbox_icon(check_food, "icon_apple")
	if is_instance_valid(check_drink): apply_checkbox_icon(check_drink, "icon_drink")
	if is_instance_valid(check_cup): apply_checkbox_icon(check_cup, "icon_cup")
	if is_instance_valid(check_faucet): apply_checkbox_icon(check_faucet, "icon_faucet")
	if is_instance_valid(check_lamp): apply_checkbox_icon(check_lamp, "icon_lighting")
	if is_instance_valid(check_portal): apply_checkbox_icon(check_portal, "icon_door")
	if is_instance_valid(check_stairs): apply_checkbox_icon(check_stairs, "icon_stairs")
	if is_instance_valid(check_elevator): apply_checkbox_icon(check_elevator, "icon_elevator")

	if not is_instance_valid(root_panel): 
		return
	for node: Node in root_panel.find_children("*", "Button", true, false):
		if node is Button and (node as Button).text == "✕":
			apply_close_icon(node as Button)
