# ==============================================================================
# OWNWORLD — LIGHT & GLOW STUDIO (LANDSCAPE TOUCH & SLIDER ADAPTIVE)
# File: res://UI/Dialogs/LightStudioDialog.gd
# Base Class: CanvasLayer (class_name LightStudioDialog)
#
# Responsibility: 2D dynamic glow & lighting studio modal. Controls silhouette
# aura spread, breathing pulse frequencies, ambient radial room lighting, and color swatches.
# ==============================================================================

class_name LightStudioDialog
extends CanvasLayer

const MAX_PANEL_WIDTH: float = 620.0
const MAX_PANEL_HEIGHT: float = 580.0

var root_backdrop: Control = null
var center_container: CenterContainer = null
var root_panel: PanelContainer = null
var active_entity: OwnEntity = null

var header_lbl: Label = null
var chk_light_enabled: CheckBox = null
var opt_light_mode: OptionButton = null
var mode_hint_lbl: Label = null

var lbl_glow_style: Label = null
var lbl_glow_color: Label = null
var color_picker_btn: ColorPickerButton = null
var swatches_hbox: HBoxContainer = null

var lbl_brightness: Label = null
var sld_intensity: HSlider = null
var val_intensity_lbl: Label = null

var lbl_glow_size: Label = null
var sld_radius: HSlider = null
var val_radius_lbl: Label = null

var lbl_pulse: Label = null
var sld_pulse: HSlider = null
var val_pulse_lbl: Label = null

var btn_save: Button = null

const PRESET_SWATCHES: Array[Dictionary] = [
	{"name": "Candle", "color": Color("#ffe080"), "icon": "icon_cozy"},
	{"name": "Fairy Pink", "color": Color("#f472b6"), "icon": "icon_star"},
	{"name": "Sky Blue", "color": Color("#38bdf8"), "icon": "icon_sun"},
	{"name": "Violet", "color": Color("#c084fc"), "icon": "icon_night"},
	{"name": "Emerald", "color": Color("#34d399"), "icon": "icon_leaves"},
	{"name": "Sunlight", "color": Color("#fffbeb"), "icon": "icon_sun"}
]


func _ready() -> void:
	name = "LightStudioDialog"
	layer = 120
	visible = false
	add_to_group("modal_ui")
	_build_ui()
	_connect_system_signals()
	_update_responsive_layout()


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


func _update_responsive_layout() -> void:
	if not is_instance_valid(root_panel): return
	var viewport: Viewport = get_viewport()
	var viewport_size: Vector2 = viewport.get_visible_rect().size if viewport != null else Vector2(1280.0, 720.0)
	var is_mob: bool = _is_mobile()

	var target_width: float = clampf(viewport_size.x * 0.92, 320.0, MAX_PANEL_WIDTH)
	var target_height: float = clampf(viewport_size.y * (0.92 if is_mob else 0.88), 320.0, MAX_PANEL_HEIGHT)
	root_panel.custom_minimum_size = Vector2(target_width, target_height)
	root_panel.size = Vector2(target_width, target_height)


func _build_ui() -> void:
	var is_mob: bool = _is_mobile()
	var row_h: float = 34.0 if is_mob else 28.0

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
	header_lbl.text = "Lighting & Glow Studio"
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

	var toggle_card: PanelContainer = PanelContainer.new()
	toggle_card.theme_type_variation = "SubPanel"
	form_vbox.add_child(toggle_card)

	chk_light_enabled = CheckBox.new()
	chk_light_enabled.text = " Enable Light & Glow"
	chk_light_enabled.custom_minimum_size = Vector2(0.0, row_h)
	chk_light_enabled.add_theme_constant_override("icon_max_width", 18 if is_mob else 16)
	chk_light_enabled.add_theme_font_size_override("font_size", 12 if is_mob else 10)
	_apply_checkbox_icon(chk_light_enabled, "icon_lighting")
	chk_light_enabled.toggled.connect(_on_light_toggled)
	toggle_card.add_child(chk_light_enabled)

	var mode_card: PanelContainer = PanelContainer.new()
	mode_card.theme_type_variation = "SubPanel"
	form_vbox.add_child(mode_card)

	var mode_inner: VBoxContainer = VBoxContainer.new()
	mode_inner.add_theme_constant_override("separation", 6)
	mode_card.add_child(mode_inner)

	var mode_hbox: HBoxContainer = HBoxContainer.new()
	mode_hbox.add_theme_constant_override("separation", 8)
	mode_inner.add_child(mode_hbox)

	lbl_glow_style = Label.new()
	lbl_glow_style.text = "Glow Style:"
	lbl_glow_style.custom_minimum_size = Vector2(90.0, 0.0)
	lbl_glow_style.theme_type_variation = "HintLabel"
	lbl_glow_style.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	mode_hbox.add_child(lbl_glow_style)

	opt_light_mode = OptionButton.new()
	opt_light_mode.custom_minimum_size = Vector2(0.0, row_h)
	opt_light_mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_icon_option(opt_light_mode, "icon_glow", "Silhouette Contour (Outline Glow)", Types.LightShapeMode.SILHOUETTE_CONTOUR)
	_add_icon_option(opt_light_mode, "icon_sun", "Ambient Room Glow", Types.LightShapeMode.RADIAL_ROOM)
	_add_icon_option(opt_light_mode, "icon_pin", "Light Anchors (Pin Emitters)", Types.LightShapeMode.ANCHOR_POINTS)
	opt_light_mode.item_selected.connect(_on_mode_selected)
	mode_hbox.add_child(opt_light_mode)

	mode_hint_lbl = Label.new()
	mode_hint_lbl.text = "Silhouette Glow: Illuminates the entire drawing and casts a soft outer aura."
	mode_hint_lbl.theme_type_variation = "HintLabel"
	mode_hint_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	mode_inner.add_child(mode_hint_lbl)

	var color_card: PanelContainer = PanelContainer.new()
	color_card.theme_type_variation = "SubPanel"
	form_vbox.add_child(color_card)

	var color_vbox: VBoxContainer = VBoxContainer.new()
	color_vbox.add_theme_constant_override("separation", 6)
	color_card.add_child(color_vbox)

	var color_top_hbox: HBoxContainer = HBoxContainer.new()
	color_vbox.add_child(color_top_hbox)

	lbl_glow_color = Label.new()
	lbl_glow_color.text = "Glow Color:"
	lbl_glow_color.custom_minimum_size = Vector2(90.0, 0.0)
	lbl_glow_color.theme_type_variation = "HintLabel"
	lbl_glow_color.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	color_top_hbox.add_child(lbl_glow_color)

	color_picker_btn = ColorPickerButton.new()
	color_picker_btn.text = " Custom Tint"
	color_picker_btn.custom_minimum_size = Vector2(140.0 if is_mob else 120.0, row_h)
	color_picker_btn.focus_mode = Control.FOCUS_NONE
	color_picker_btn.add_theme_constant_override("icon_max_width", 14)
	_apply_button_icon(color_picker_btn, "icon_palette")
	color_picker_btn.color_changed.connect(_on_color_changed)
	color_top_hbox.add_child(color_picker_btn)

	swatches_hbox = HBoxContainer.new()
	swatches_hbox.add_theme_constant_override("separation", 6)
	color_vbox.add_child(swatches_hbox)
	_build_preset_swatches()

	var sliders_card: PanelContainer = PanelContainer.new()
	sliders_card.theme_type_variation = "SubPanel"
	form_vbox.add_child(sliders_card)

	var sliders_vbox: VBoxContainer = VBoxContainer.new()
	sliders_vbox.add_theme_constant_override("separation", 6)
	sliders_card.add_child(sliders_vbox)

	var intensity_header: HBoxContainer = HBoxContainer.new()
	sliders_vbox.add_child(intensity_header)

	lbl_brightness = Label.new()
	lbl_brightness.text = "Brightness:"
	lbl_brightness.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_brightness.theme_type_variation = "HintLabel"
	lbl_brightness.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	intensity_header.add_child(lbl_brightness)

	val_intensity_lbl = Label.new()
	val_intensity_lbl.text = "2.0x"
	val_intensity_lbl.theme_type_variation = "HeaderLabel"
	val_intensity_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	intensity_header.add_child(val_intensity_lbl)

	sld_intensity = HSlider.new()
	sld_intensity.min_value = 0.2
	sld_intensity.max_value = 5.0
	sld_intensity.step = 0.1
	sld_intensity.value = 2.0
	sld_intensity.custom_minimum_size = Vector2(0.0, 24.0)
	sld_intensity.value_changed.connect(_on_intensity_changed)
	sliders_vbox.add_child(sld_intensity)

	var radius_header: HBoxContainer = HBoxContainer.new()
	sliders_vbox.add_child(radius_header)

	lbl_glow_size = Label.new()
	lbl_glow_size.text = "Glow Radius:"
	lbl_glow_size.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_glow_size.theme_type_variation = "HintLabel"
	lbl_glow_size.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	radius_header.add_child(lbl_glow_size)

	val_radius_lbl = Label.new()
	val_radius_lbl.text = "160 px"
	val_radius_lbl.theme_type_variation = "HeaderLabel"
	val_radius_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	radius_header.add_child(val_radius_lbl)

	sld_radius = HSlider.new()
	sld_radius.min_value = 20.0
	sld_radius.max_value = 450.0
	sld_radius.step = 5.0
	sld_radius.value = 160.0
	sld_radius.custom_minimum_size = Vector2(0.0, 24.0)
	sld_radius.value_changed.connect(_on_radius_changed)
	sliders_vbox.add_child(sld_radius)

	var pulse_header: HBoxContainer = HBoxContainer.new()
	sliders_vbox.add_child(pulse_header)

	lbl_pulse = Label.new()
	lbl_pulse.text = "Breathing Pulse:"
	lbl_pulse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_pulse.theme_type_variation = "HintLabel"
	lbl_pulse.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	pulse_header.add_child(lbl_pulse)

	val_pulse_lbl = Label.new()
	val_pulse_lbl.text = "2.0 Hz"
	val_pulse_lbl.theme_type_variation = "HeaderLabel"
	val_pulse_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	pulse_header.add_child(val_pulse_lbl)

	sld_pulse = HSlider.new()
	sld_pulse.min_value = 0.0
	sld_pulse.max_value = 8.0
	sld_pulse.step = 0.2
	sld_pulse.value = 2.0
	sld_pulse.custom_minimum_size = Vector2(0.0, 24.0)
	sld_pulse.value_changed.connect(_on_pulse_changed)
	sliders_vbox.add_child(sld_pulse)

	main_vbox.add_child(HSeparator.new())

	btn_save = Button.new()
	btn_save.text = " Save Lighting"
	btn_save.custom_minimum_size = Vector2(0.0, row_h + 4.0)
	btn_save.focus_mode = Control.FOCUS_NONE
	btn_save.add_theme_constant_override("icon_max_width", 16)
	btn_save.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	_apply_button_icon(btn_save, "icon_save")
	btn_save.pressed.connect(close_dialog)
	main_vbox.add_child(btn_save)


func _build_preset_swatches() -> void:
	if swatches_hbox == null: return
	for child: Node in swatches_hbox.get_children():
		child.queue_free()

	var is_mob: bool = _is_mobile()

	for preset: Dictionary in PRESET_SWATCHES:
		var swatch_button: Button = Button.new()
		swatch_button.text = " " + str(preset.get("name", "Preset"))
		swatch_button.focus_mode = Control.FOCUS_NONE
		swatch_button.custom_minimum_size = Vector2(0.0, 32.0 if is_mob else 26.0)
		swatch_button.add_theme_constant_override("icon_max_width", 14 if is_mob else 12)
		swatch_button.add_theme_font_size_override("font_size", 10 if is_mob else 9)
		_apply_button_icon(swatch_button, str(preset.get("icon", "icon_star")))

		var preset_color: Color = preset.get("color", Color.WHITE) as Color
		swatch_button.pressed.connect(func() -> void:
			if color_picker_btn != null:
				color_picker_btn.color = preset_color
				_on_color_changed(preset_color)
		)
		swatches_hbox.add_child(swatch_button)


func _add_icon_option(option_button: OptionButton, icon_key: String, text_label: String, item_id: int) -> void:
	var icon_texture: Texture2D = ThemeService.get_popup_icon(icon_key)
	if icon_texture != null: option_button.add_icon_item(icon_texture, " " + text_label, item_id)
	else: option_button.add_item(text_label, item_id)


func _apply_button_icon(button: Button, icon_key: String) -> void:
	if button == null: return
	var icon_texture: Texture2D = ThemeService.get_icon(icon_key)
	if icon_texture != null: button.icon = icon_texture


func _apply_close_icon(button: Button) -> void:
	if button == null: return
	var icon_texture: Texture2D = ThemeService.get_icon("icon_close")
	if icon_texture != null: button.icon = icon_texture
	else: button.text = "✕"


func _apply_checkbox_icon(checkbox: CheckBox, icon_key: String) -> void:
	if checkbox == null: return
	var icon_texture: Texture2D = ThemeService.get_icon(icon_key)
	if icon_texture != null: checkbox.icon = icon_texture


func open_for_entity(entity: OwnEntity) -> void:
	if not is_instance_valid(entity): return
	active_entity = entity
	chk_light_enabled.button_pressed = entity.is_light_source

	opt_light_mode.clear()
	_add_icon_option(opt_light_mode, "icon_glow", "Silhouette Contour (Outline Glow)", Types.LightShapeMode.SILHOUETTE_CONTOUR)
	_add_icon_option(opt_light_mode, "icon_sun", "Ambient Room Glow", Types.LightShapeMode.RADIAL_ROOM)
	_add_icon_option(opt_light_mode, "icon_pin", "Light Anchors (Pin Emitters)", Types.LightShapeMode.ANCHOR_POINTS)

	var mode_index: int = _find_option_index_by_id(opt_light_mode, entity.light_shape_mode)
	opt_light_mode.selected = mode_index if mode_index >= 0 else 0

	color_picker_btn.color = entity.light_color
	sld_intensity.value = entity.light_intensity
	val_intensity_lbl.text = "%.1fx" % entity.light_intensity

	sld_radius.value = entity.light_radius
	val_radius_lbl.text = "%d px" % int(entity.light_radius)

	sld_pulse.value = entity.light_pulse_speed
	val_pulse_lbl.text = "%.1f Hz" % entity.light_pulse_speed

	_update_mode_hint_text()
	_update_control_interactivity(entity.is_light_source)
	_update_responsive_layout()
	visible = true


func _find_option_index_by_id(option_button: OptionButton, value: int) -> int:
	if option_button == null: return -1
	for index: int in range(option_button.item_count):
		if option_button.get_item_id(index) == value: return index
	return -1


func close_dialog() -> void:
	if active_entity != null and is_instance_valid(active_entity):
		_persist_entity_changes(active_entity)
		EventBus.notification_requested.emit("Saved Lighting: " + active_entity.display_name, true)
	visible = false
	active_entity = null


func _on_light_toggled(enabled: bool) -> void:
	if active_entity == null or not is_instance_valid(active_entity): return
	active_entity.is_light_source = enabled
	active_entity.is_active = enabled

	if enabled: _apply_live_lighting_updates()
	else: active_entity.unconfigure_light_source()

	_update_control_interactivity(enabled)
	_persist_entity_changes(active_entity)


func _on_mode_selected(index: int) -> void:
	if active_entity == null or not is_instance_valid(active_entity): return
	active_entity.light_shape_mode = opt_light_mode.get_item_id(index)
	_update_mode_hint_text()
	_apply_live_lighting_updates()
	_persist_entity_changes(active_entity)


func _update_mode_hint_text() -> void:
	if opt_light_mode == null: return
	match opt_light_mode.get_selected_id():
		int(Types.LightShapeMode.SILHOUETTE_CONTOUR):
			mode_hint_lbl.text = "Silhouette Glow: Illuminates the entire drawing and casts a soft outer aura."
		int(Types.LightShapeMode.RADIAL_ROOM):
			mode_hint_lbl.text = "Ambient Room: Fills the surrounding space with soft ambient light."
		int(Types.LightShapeMode.ANCHOR_POINTS):
			mode_hint_lbl.text = "Light Anchors: Emits light points directly from your placed light pins."
		_: mode_hint_lbl.text = ""


func _on_color_changed(new_color: Color) -> void:
	if active_entity == null or not is_instance_valid(active_entity): return
	active_entity.light_color = new_color
	_apply_live_lighting_updates()
	_persist_entity_changes(active_entity)


func _on_intensity_changed(value: float) -> void:
	val_intensity_lbl.text = "%.1fx" % value
	if active_entity == null or not is_instance_valid(active_entity): return
	active_entity.light_intensity = value
	_apply_live_lighting_updates()
	_persist_entity_changes(active_entity)


func _on_radius_changed(value: float) -> void:
	val_radius_lbl.text = "%d px" % int(value)
	if active_entity == null or not is_instance_valid(active_entity): return
	active_entity.light_radius = value
	_apply_live_lighting_updates()
	_persist_entity_changes(active_entity)


func _on_pulse_changed(value: float) -> void:
	val_pulse_lbl.text = "%.1f Hz" % value if value > 0.0 else "Steady"
	if active_entity == null or not is_instance_valid(active_entity): return
	active_entity.light_pulse_speed = value
	_apply_live_lighting_updates()
	_persist_entity_changes(active_entity)


func _apply_live_lighting_updates() -> void:
	if active_entity == null or not is_instance_valid(active_entity) or not active_entity.is_light_source:
		return
	active_entity.configure_lighting_settings(
		opt_light_mode.get_selected_id(),
		color_picker_btn.color,
		sld_intensity.value,
		sld_radius.value,
		sld_pulse.value
	)


func _update_control_interactivity(is_enabled: bool) -> void:
	if opt_light_mode != null: opt_light_mode.disabled = not is_enabled
	if color_picker_btn != null: color_picker_btn.disabled = not is_enabled
	if sld_intensity != null: sld_intensity.editable = is_enabled
	if sld_radius != null: sld_radius.editable = is_enabled
	if sld_pulse != null: sld_pulse.editable = is_enabled
	if swatches_hbox != null:
		for child: Node in swatches_hbox.get_children():
			if child is Button: (child as Button).disabled = not is_enabled


func _persist_entity_changes(entity: OwnEntity) -> void:
	if not is_instance_valid(entity): return
	SaveSystem.update_character_in_cast(entity)
	SaveSystem.save_current_room_state()
	EventBus.entity_state_changed.emit(entity.entity_id)


func _refresh_theme_icons() -> void:
	_apply_close_icon_from_tree()
	if chk_light_enabled != null: _apply_checkbox_icon(chk_light_enabled, "icon_lighting")
	if color_picker_btn != null: _apply_button_icon(color_picker_btn, "icon_palette")
	if btn_save != null: _apply_button_icon(btn_save, "icon_save")
	_build_preset_swatches()


func _apply_close_icon_from_tree() -> void:
	if root_panel == null: return
	for child: Node in root_panel.find_children("*", "Button", true, false):
		if child is Button and (child as Button).text == "✕":
			_apply_close_icon(child as Button)


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		close_dialog()
