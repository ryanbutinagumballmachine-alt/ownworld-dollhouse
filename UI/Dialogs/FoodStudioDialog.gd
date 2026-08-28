# ==============================================================================
# OWNWORLD — FOOD & DRINK STUDIO (LANDSCAPE DUAL-OS ADAPTIVE)
# File: res://UI/Dialogs/FoodStudioDialog.gd
# Base Class: CanvasLayer (class_name FoodStudioDialog)
#
# Responsibility: Interactive consumable configuration modal. Manages beverage
# modes, infinite snack toggles, and multi-stage bite / sip drawing progression.
# ==============================================================================

class_name FoodStudioDialog
extends CanvasLayer

const MAX_PANEL_WIDTH: float = 560.0
const MAX_PANEL_HEIGHT: float = 540.0

var root_backdrop: Control = null
var center_container: CenterContainer = null
var root_panel: PanelContainer = null

var active_entity: OwnEntity = null
var asset_picker: AssetPickerDialog = null

var header_lbl: Label = null
var check_is_drink: CheckBox = null
var check_is_infinite: CheckBox = null
var stages_vbox: VBoxContainer = null
var btn_add_stage: Button = null
var btn_save: Button = null

var custom_stage_paths: Array[String] = []
var custom_stage_textures: Array[Texture2D] = []


func _ready() -> void:
	name = "FoodStudioDialog"
	layer = 120
	visible = false
	add_to_group("modal_ui")
	_build_ui()
	_connect_system_signals()
	_update_responsive_layout()

	asset_picker = AssetPickerDialog.new()
	add_child(asset_picker)


func _is_mobile() -> bool:
	return ThemeEngine.is_mobile_platform()


func _connect_system_signals() -> void:
	var tree: SceneTree = get_tree()
	if tree and tree.root and not tree.root.size_changed.is_connected(_update_responsive_layout):
		tree.root.size_changed.connect(_update_responsive_layout)
	if not EventBus.theme_changed.is_connected(_on_theme_changed):
		EventBus.theme_changed.connect(_on_theme_changed)


func _on_theme_changed(_theme_data: Dictionary) -> void:
	_refresh_theme_icons()
	_update_responsive_layout()
	_render_stages_list()


func _update_responsive_layout() -> void:
	if not is_instance_valid(root_panel): return
	var viewport: Viewport = get_viewport()
	var viewport_size: Vector2 = viewport.get_visible_rect().size if viewport != null else Vector2(1280.0, 720.0)
	var is_mob: bool = _is_mobile()

	var target_width: float = clampf(viewport_size.x * 0.92, 300.0, MAX_PANEL_WIDTH)
	var target_height: float = clampf(viewport_size.y * (0.90 if is_mob else 0.84), 300.0, MAX_PANEL_HEIGHT)
	root_panel.custom_minimum_size = Vector2(target_width, target_height)
	root_panel.size = Vector2(target_width, target_height)


func _build_ui() -> void:
	var is_mob: bool = _is_mobile()
	var row_h: float = 36.0 if is_mob else 28.0

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
	main_vbox.add_theme_constant_override("separation", 6)
	root_panel.add_child(main_vbox)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	header_lbl = Label.new()
	header_lbl.text = "Food & Drink Studio"
	header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_lbl.theme_type_variation = "HeaderLabel"
	header_lbl.add_theme_font_size_override("font_size", 14 if is_mob else 12)
	header_hbox.add_child(header_lbl)

	var close_button: Button = Button.new()
	close_button.custom_minimum_size = Vector2(28.0 if is_mob else 22.0, 28.0 if is_mob else 22.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_constant_override("icon_max_width", 12)
	_apply_close_icon(close_button)
	close_button.pressed.connect(close_dialog)
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

	var mode_card: PanelContainer = PanelContainer.new()
	mode_card.theme_type_variation = "SubPanel"
	form_vbox.add_child(mode_card)

	var mode_vbox: VBoxContainer = VBoxContainer.new()
	mode_vbox.add_theme_constant_override("separation", 6)
	mode_card.add_child(mode_vbox)

	check_is_drink = CheckBox.new()
	check_is_drink.text = " Beverage Mode (Supports Pouring & Fill Levels)"
	check_is_drink.custom_minimum_size = Vector2(0.0, row_h)
	check_is_drink.add_theme_constant_override("icon_max_width", 18 if is_mob else 16)
	check_is_drink.add_theme_font_size_override("font_size", 12 if is_mob else 10)
	mode_vbox.add_child(check_is_drink)

	check_is_infinite = CheckBox.new()
	check_is_infinite.text = " Infinite (Endless bites & sips without depleting)"
	check_is_infinite.custom_minimum_size = Vector2(0.0, row_h)
	check_is_infinite.add_theme_constant_override("icon_max_width", 18 if is_mob else 16)
	check_is_infinite.add_theme_font_size_override("font_size", 12 if is_mob else 10)
	mode_vbox.add_child(check_is_infinite)

	var stages_label: Label = Label.new()
	stages_label.text = "Sequential Bite / Sip Stages (Leave empty to use base art):"
	stages_label.theme_type_variation = "HintLabel"
	stages_label.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	form_vbox.add_child(stages_label)

	stages_vbox = VBoxContainer.new()
	stages_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stages_vbox.add_theme_constant_override("separation", 6)
	form_vbox.add_child(stages_vbox)

	btn_add_stage = Button.new()
	btn_add_stage.text = " Add Next Bite / Stage Drawing..."
	btn_add_stage.custom_minimum_size = Vector2(0.0, row_h)
	btn_add_stage.focus_mode = Control.FOCUS_NONE
	btn_add_stage.add_theme_constant_override("icon_max_width", 14)
	btn_add_stage.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	btn_add_stage.pressed.connect(_on_add_stage_pressed)
	form_vbox.add_child(btn_add_stage)

	main_vbox.add_child(HSeparator.new())

	btn_save = Button.new()
	btn_save.text = " Save Food / Drink State"
	btn_save.custom_minimum_size = Vector2(0.0, row_h + 4.0)
	btn_save.focus_mode = Control.FOCUS_NONE
	btn_save.add_theme_constant_override("icon_max_width", 16)
	btn_save.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	btn_save.pressed.connect(save_and_close)
	main_vbox.add_child(btn_save)

	_refresh_theme_icons()


func open_for_entity(entity: OwnEntity) -> void:
	if not is_instance_valid(entity): return
	active_entity = entity
	check_is_drink.button_pressed = entity.is_drink
	check_is_infinite.button_pressed = entity.is_infinite

	custom_stage_paths.clear()
	custom_stage_textures.clear()

	for path: String in entity.custom_stage_paths:
		if not path.is_empty() and FileAccess.file_exists(path):
			custom_stage_paths.append(path)
			custom_stage_textures.append(UGCManager.load_texture_from_file(path))

	_update_responsive_layout()
	_render_stages_list()
	visible = true


func close_dialog() -> void:
	visible = false
	active_entity = null
	custom_stage_paths.clear()
	custom_stage_textures.clear()


func _on_add_stage_pressed() -> void:
	if asset_picker == null: return
	asset_picker.open_picker("Choose Next Bite Stage Drawing", "", func(_art_name: String, texture: Texture2D, file_path: String) -> void:
		if not file_path.is_empty():
			custom_stage_paths.append(file_path)
			custom_stage_textures.append(texture)
			_render_stages_list()
	)


func _render_stages_list() -> void:
	if stages_vbox == null: return
	for child: Node in stages_vbox.get_children():
		child.queue_free()

	var is_mob: bool = _is_mobile()
	var border_color: Color = ThemeService.get_color("panel_border", "#f472b6")
	var input_background: Color = ThemeService.get_color("input_background", "#ffffff")

	for index: int in range(custom_stage_paths.size()):
		var card: PanelContainer = PanelContainer.new()
		card.theme_type_variation = "SubPanel"
		card.custom_minimum_size = Vector2(0.0, 42.0 if is_mob else 36.0)

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		card.add_child(hbox)

		var stage_label: Label = Label.new()
		stage_label.text = "Stage %d:" % (index + 1)
		stage_label.theme_type_variation = "HintLabel"
		stage_label.add_theme_font_size_override("font_size", 11 if is_mob else 10)
		hbox.add_child(stage_label)

		var thumbnail_frame: PanelContainer = PanelContainer.new()
		thumbnail_frame.custom_minimum_size = Vector2(34.0 if is_mob else 26.0, 34.0 if is_mob else 26.0)
		thumbnail_frame.clip_contents = true

		var thumbnail_style: StyleBoxFlat = StyleBoxFlat.new()
		thumbnail_style.bg_color = input_background
		thumbnail_style.border_color = border_color
		thumbnail_style.set_border_width_all(1)
		thumbnail_style.set_corner_radius_all(3)
		thumbnail_frame.add_theme_stylebox_override("panel", thumbnail_style)

		var thumbnail: TextureRect = TextureRect.new()
		thumbnail.set_anchors_preset(Control.PRESET_FULL_RECT)
		thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumbnail.texture = custom_stage_textures[index] if index < custom_stage_textures.size() else null
		thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumbnail_frame.add_child(thumbnail)
		hbox.add_child(thumbnail_frame)

		var path_label: Label = Label.new()
		path_label.text = custom_stage_paths[index].get_file()
		path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		path_label.add_theme_font_size_override("font_size", 11 if is_mob else 10)
		hbox.add_child(path_label)

		var delete_button: Button = Button.new()
		delete_button.custom_minimum_size = Vector2(28.0 if is_mob else 22.0, 28.0 if is_mob else 22.0)
		delete_button.theme_type_variation = "DangerButton"
		delete_button.focus_mode = Control.FOCUS_NONE
		delete_button.add_theme_constant_override("icon_max_width", 10)
		_apply_close_icon(delete_button)

		var captured_index: int = index
		delete_button.pressed.connect(func() -> void: _remove_stage(captured_index))
		hbox.add_child(delete_button)
		stages_vbox.add_child(card)


func _remove_stage(index: int) -> void:
	if index < 0 or index >= custom_stage_paths.size(): return
	custom_stage_paths.remove_at(index)
	if index < custom_stage_textures.size(): custom_stage_textures.remove_at(index)
	_render_stages_list()


func save_and_close() -> void:
	if active_entity == null or not is_instance_valid(active_entity):
		close_dialog()
		return

	active_entity.configure_as_consumable()
	active_entity.is_drink = check_is_drink.button_pressed
	active_entity.is_infinite = check_is_infinite.button_pressed
	active_entity.custom_stage_paths = custom_stage_paths.duplicate()
	active_entity.max_bites = maxi(custom_stage_paths.size(), 3)
	active_entity.current_state_idx = 0

	SaveSystem.update_character_in_cast(active_entity)
	SaveSystem.save_current_room_state()
	EventBus.entity_state_changed.emit(active_entity.entity_id)
	EventBus.notification_requested.emit("Saved Food State: " + active_entity.display_name, true)
	close_dialog()


func _refresh_theme_icons() -> void:
	if check_is_drink != null:
		var drink_icon: Texture2D = ThemeService.get_icon("icon_drink")
		if drink_icon != null: check_is_drink.icon = drink_icon
	if check_is_infinite != null:
		var infinite_icon: Texture2D = ThemeService.get_icon("icon_infinite")
		if infinite_icon != null: check_is_infinite.icon = infinite_icon
	if btn_add_stage != null:
		var plus_icon: Texture2D = ThemeService.get_icon("icon_plus")
		if plus_icon != null: btn_add_stage.icon = plus_icon
	if btn_save != null:
		var save_icon: Texture2D = ThemeService.get_icon("icon_save")
		if save_icon != null: btn_save.icon = save_icon
	if stages_vbox != null:
		_render_stages_list()


func _apply_close_icon(button: Button) -> void:
	if button == null: return
	var close_icon: Texture2D = ThemeService.get_icon("icon_close")
	if close_icon != null: button.icon = close_icon
	else: button.text = "✕"


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		close_dialog()
