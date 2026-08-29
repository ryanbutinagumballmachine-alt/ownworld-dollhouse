# ==============================================================================
# OWNWORLD — SETTINGS DIALOG (LANDSCAPE TWO-COLUMN & TOUCH ADAPTIVE)
# File: res://UI/Dialogs/SettingsDialog.gd
# Base Class: CanvasLayer (class_name SettingsDialog)
#
# Responsibility: User configuration dialog with audio sliders, UI scaling,
# touch margins, hold duration, and master/granular juice controls.
# Adapted for landscape dual-thumb ergonomics and high-density desktop precision.
# ==============================================================================

class_name SettingsDialog
extends CanvasLayer

const MAX_PANEL_WIDTH: float = 680.0
const MAX_PANEL_HEIGHT: float = 580.0
const FACTORY_RESET_MARKER: String = "user://.ownworld_factory_reset"

var root_backdrop: Control = null
var center_container: CenterContainer = null
var root_panel: PanelContainer = null
var header_lbl: Label = null

# Audio Controls
var m_lbl: Label = null
var sfx_lbl: Label = null
var music_lbl: Label = null
var master_slider: HSlider = null
var sfx_slider: HSlider = null
var music_slider: HSlider = null

# Interface & Touch Controls
var ui_scale_hdr: HBoxContainer = null
var lbl_ui_scale: Label = null
var ui_scale_val_lbl: Label = null
var ui_scale_slider: HSlider = null

var touch_padding_hdr: HBoxContainer = null
var lbl_touch_padding: Label = null
var touch_padding_val_lbl: Label = null
var touch_padding_slider: HSlider = null

var long_press_hdr: HBoxContainer = null
var lbl_long_press: Label = null
var long_press_val_lbl: Label = null
var long_press_slider: HSlider = null

var grid_check: CheckBox = null
var toasts_check: CheckBox = null
var dev_mode_check: CheckBox = null
var dev_simulate_mobile_check: CheckBox = null

# Master & Granular Juice Controls
var juice_card: PanelContainer = null
var check_juice_master: CheckBox = null
var juice_sub_container: VBoxContainer = null
var check_juice_idle: CheckBox = null
var juice_idle_intensity_hdr: HBoxContainer = null
var lbl_juice_intensity: Label = null
var val_juice_intensity_lbl: Label = null
var sld_juice_idle_intensity: HSlider = null
var check_juice_tilts: CheckBox = null
var check_juice_squash: CheckBox = null
var check_juice_springs: CheckBox = null

# Action & Danger Buttons
var btn_factory: Button = null
var btn_save: Button = null

var reset_modal_backdrop: Control = null
var reset_panel: PanelContainer = null
var reset_title_lbl: Label = null
var reset_desc_lbl: Label = null


func _ready() -> void:
	name = "SettingsDialog"
	layer = 120
	visible = false
	add_to_group("modal_ui")
	_build_ui()
	_build_reset_confirmation_modal()
	_connect_system_signals()
	_update_responsive_layout()


func _is_mobile() -> bool:
	return ThemeEngine.is_mobile_platform()


func _connect_system_signals() -> void:
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null and not tree.root.size_changed.is_connected(_update_responsive_layout):
		tree.root.size_changed.connect(_update_responsive_layout)
	if not EventBus.theme_changed.is_connected(_on_theme_changed):
		EventBus.theme_changed.connect(_on_theme_changed)


func _on_theme_changed(_theme_data: Dictionary) -> void:
	_refresh_theme_icons()
	_update_responsive_layout()


func _update_responsive_layout() -> void:
	if not is_instance_valid(root_panel): return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280.0, 720.0)
	var is_mob: bool = _is_mobile()

	var target_width: float = clampf(viewport_size.x * 0.94, 320.0, MAX_PANEL_WIDTH)
	var target_height: float = clampf(viewport_size.y * (0.92 if is_mob else 0.88), 300.0, MAX_PANEL_HEIGHT)
	root_panel.custom_minimum_size = Vector2(target_width, target_height)
	root_panel.size = Vector2(target_width, target_height)

	if reset_panel != null:
		var reset_width: float = clampf(viewport_size.x * 0.85, 280.0, 420.0)
		reset_panel.custom_minimum_size = Vector2(reset_width, 220.0)


func _build_ui() -> void:
	var is_mob: bool = _is_mobile()
	var row_h: float = 34.0 if is_mob else 26.0

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

	var outer_vbox: VBoxContainer = VBoxContainer.new()
	outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_theme_constant_override("separation", 6)
	root_panel.add_child(outer_vbox)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	outer_vbox.add_child(header_hbox)

	header_lbl = Label.new()
	header_lbl.text = "Settings"
	header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_lbl.theme_type_variation = "HeaderLabel"
	header_lbl.add_theme_font_size_override("font_size", 14 if is_mob else 12)
	header_hbox.add_child(header_lbl)

	var close_button: Button = Button.new()
	close_button.custom_minimum_size = Vector2(28.0 if is_mob else 22.0, 28.0 if is_mob else 22.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_constant_override("icon_max_width", 12)
	_apply_close_icon(close_button)
	close_button.pressed.connect(close_settings)
	header_hbox.add_child(close_button)

	outer_vbox.add_child(HSeparator.new())

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = false
	outer_vbox.add_child(scroll)

	var categories_grid: GridContainer = GridContainer.new()
	categories_grid.columns = 2
	categories_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	categories_grid.add_theme_constant_override("h_separation", 10)
	categories_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(categories_grid)

	# --- Column 1: Audio & Display Settings ---
	var col_left: VBoxContainer = VBoxContainer.new()
	col_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_left.add_theme_constant_override("separation", 8)
	categories_grid.add_child(col_left)

	# 1. Audio Section Card
	var audio_card: PanelContainer = PanelContainer.new()
	audio_card.theme_type_variation = "SubPanel"
	col_left.add_child(audio_card)

	var audio_inner: VBoxContainer = VBoxContainer.new()
	audio_inner.add_theme_constant_override("separation", 4)
	audio_card.add_child(audio_inner)

	var audio_title: Label = Label.new()
	audio_title.text = "Audio Volume:"
	audio_title.theme_type_variation = "HeaderLabel"
	audio_title.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	audio_inner.add_child(audio_title)

	m_lbl = Label.new()
	m_lbl.text = "Master Volume:"
	m_lbl.theme_type_variation = "HintLabel"
	m_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	audio_inner.add_child(m_lbl)

	master_slider = HSlider.new()
	master_slider.min_value = 0.0
	master_slider.max_value = 1.0
	master_slider.step = 0.05
	master_slider.custom_minimum_size = Vector2(0.0, 24.0)
	master_slider.value = SettingsManager.get_master_volume()
	master_slider.value_changed.connect(_on_master_volume_changed)
	audio_inner.add_child(master_slider)

	sfx_lbl = Label.new()
	sfx_lbl.text = "Sound Effects:"
	sfx_lbl.theme_type_variation = "HintLabel"
	sfx_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	audio_inner.add_child(sfx_lbl)

	sfx_slider = HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.custom_minimum_size = Vector2(0.0, 24.0)
	sfx_slider.value = SettingsManager.get_sfx_volume()
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	audio_inner.add_child(sfx_slider)

	music_lbl = Label.new()
	music_lbl.text = "Music Volume:"
	music_lbl.theme_type_variation = "HintLabel"
	music_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	audio_inner.add_child(music_lbl)

	music_slider = HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.05
	music_slider.custom_minimum_size = Vector2(0.0, 24.0)
	music_slider.value = SettingsManager.get_music_volume()
	music_slider.value_changed.connect(_on_music_volume_changed)
	audio_inner.add_child(music_slider)

	# 2. Display & Touch Section Card
	var display_card: PanelContainer = PanelContainer.new()
	display_card.theme_type_variation = "SubPanel"
	col_left.add_child(display_card)

	var display_inner: VBoxContainer = VBoxContainer.new()
	display_inner.add_theme_constant_override("separation", 4)
	display_card.add_child(display_inner)

	var display_title: Label = Label.new()
	display_title.text = "Display & Touch Controls:"
	display_title.theme_type_variation = "HeaderLabel"
	display_title.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	display_inner.add_child(display_title)

	ui_scale_hdr = HBoxContainer.new()
	display_inner.add_child(ui_scale_hdr)

	lbl_ui_scale = Label.new()
	lbl_ui_scale.text = "Interface Scale:"
	lbl_ui_scale.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_ui_scale.theme_type_variation = "HintLabel"
	lbl_ui_scale.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	ui_scale_hdr.add_child(lbl_ui_scale)

	var current_scale: float = SettingsManager.get_ui_scale()
	ui_scale_val_lbl = Label.new()
	ui_scale_val_lbl.text = "%d%%" % int(current_scale * 100.0)
	ui_scale_val_lbl.theme_type_variation = "HeaderLabel"
	ui_scale_val_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	ui_scale_hdr.add_child(ui_scale_val_lbl)

	ui_scale_slider = HSlider.new()
	ui_scale_slider.min_value = 0.75
	ui_scale_slider.max_value = 2.0
	ui_scale_slider.step = 0.05
	ui_scale_slider.custom_minimum_size = Vector2(0.0, 24.0)
	ui_scale_slider.value = current_scale
	ui_scale_slider.value_changed.connect(_on_ui_scale_changed)
	display_inner.add_child(ui_scale_slider)

	touch_padding_hdr = HBoxContainer.new()
	display_inner.add_child(touch_padding_hdr)

	lbl_touch_padding = Label.new()
	lbl_touch_padding.text = "Touch Grab Padding:"
	lbl_touch_padding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_touch_padding.theme_type_variation = "HintLabel"
	lbl_touch_padding.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	touch_padding_hdr.add_child(lbl_touch_padding)

	var current_padding: float = SettingsManager.get_mobile_touch_padding()
	touch_padding_val_lbl = Label.new()
	touch_padding_val_lbl.text = "0 px" if int(current_padding) == 0 else "%d px" % int(current_padding)
	touch_padding_val_lbl.theme_type_variation = "HeaderLabel"
	touch_padding_val_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	touch_padding_hdr.add_child(touch_padding_val_lbl)

	touch_padding_slider = HSlider.new()
	touch_padding_slider.min_value = 0.0
	touch_padding_slider.max_value = 35.0
	touch_padding_slider.step = 1.0
	touch_padding_slider.custom_minimum_size = Vector2(0.0, 24.0)
	touch_padding_slider.value = current_padding
	touch_padding_slider.value_changed.connect(_on_touch_padding_changed)
	display_inner.add_child(touch_padding_slider)

	long_press_hdr = HBoxContainer.new()
	display_inner.add_child(long_press_hdr)

	lbl_long_press = Label.new()
	lbl_long_press.text = "Magic Wheel Hold Time:"
	lbl_long_press.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_long_press.theme_type_variation = "HintLabel"
	lbl_long_press.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	long_press_hdr.add_child(lbl_long_press)

	var current_long_press: float = SettingsManager.get_long_press_duration()
	long_press_val_lbl = Label.new()
	long_press_val_lbl.text = "%.2fs" % current_long_press
	long_press_val_lbl.theme_type_variation = "HeaderLabel"
	long_press_val_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	long_press_hdr.add_child(long_press_val_lbl)

	long_press_slider = HSlider.new()
	long_press_slider.min_value = 0.15
	long_press_slider.max_value = 1.20
	long_press_slider.step = 0.05
	long_press_slider.custom_minimum_size = Vector2(0.0, 24.0)
	long_press_slider.value = current_long_press
	long_press_slider.value_changed.connect(_on_long_press_duration_changed)
	display_inner.add_child(long_press_slider)

	grid_check = _create_icon_check("icon_grid", "Magnetic Grid Snapping (32px)", row_h)
	grid_check.button_pressed = SettingsManager.is_grid_snap_enabled()
	grid_check.toggled.connect(_on_grid_snap_toggled)
	display_inner.add_child(grid_check)

	toasts_check = _create_icon_check("icon_toast", "Show Floating Notifications", row_h)
	toasts_check.button_pressed = SettingsManager.are_toasts_enabled()
	toasts_check.toggled.connect(_on_toasts_toggled)
	display_inner.add_child(toasts_check)

	dev_mode_check = _create_icon_check("icon_dev", "Developer Mode (Diagnostics HUD & Simulator)", row_h)
	dev_mode_check.button_pressed = SettingsManager.is_developer_mode_enabled()
	dev_mode_check.toggled.connect(_on_dev_mode_toggled)
	display_inner.add_child(dev_mode_check)

	# Direct Mobile Simulator Toggle on PC
	if not OS.has_feature("mobile") and not OS.has_feature("android") and not OS.has_feature("ios"):
		dev_simulate_mobile_check = _create_icon_check("icon_states", "Simulate Mobile Layout (48dp Touch Targets)", row_h)
		dev_simulate_mobile_check.button_pressed = SettingsManager.is_simulating_mobile_layout()
		dev_simulate_mobile_check.toggled.connect(func(v: bool) -> void: SettingsManager.set_simulating_mobile_layout(v))
		display_inner.add_child(dev_simulate_mobile_check)

	# --- Column 2: Motion FX & Danger Zone ---
	var col_right: VBoxContainer = VBoxContainer.new()
	col_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_right.add_theme_constant_override("separation", 8)
	categories_grid.add_child(col_right)

	# 3. Juice & Dynamic Motion FX Section
	_build_juice_section(col_right, row_h)

	# 4. Danger Zone Card
	var danger_card: PanelContainer = PanelContainer.new()
	danger_card.theme_type_variation = "SubPanel"
	col_right.add_child(danger_card)

	var danger_inner: VBoxContainer = VBoxContainer.new()
	danger_inner.add_theme_constant_override("separation", 6)
	danger_card.add_child(danger_inner)

	var danger_title: Label = Label.new()
	danger_title.text = "Danger Zone:"
	danger_title.theme_type_variation = "HeaderLabel"
	danger_title.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	danger_inner.add_child(danger_title)

	btn_factory = Button.new()
	btn_factory.text = " Factory Reset Entire Game"
	btn_factory.custom_minimum_size = Vector2(0.0, 38.0 if is_mob else 32.0)
	btn_factory.theme_type_variation = "DangerButton"
	btn_factory.focus_mode = Control.FOCUS_NONE
	btn_factory.add_theme_constant_override("icon_max_width", 16)
	btn_factory.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	_apply_button_icon(btn_factory, "icon_warning")
	btn_factory.pressed.connect(func() -> void: reset_modal_backdrop.visible = true)
	danger_inner.add_child(btn_factory)

	outer_vbox.add_child(HSeparator.new())

	btn_save = Button.new()
	btn_save.text = " Save Settings"
	btn_save.custom_minimum_size = Vector2(0.0, 42.0 if is_mob else 34.0)
	btn_save.focus_mode = Control.FOCUS_NONE
	btn_save.add_theme_constant_override("icon_max_width", 16)
	btn_save.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	_apply_button_icon(btn_save, "icon_save")
	btn_save.pressed.connect(close_settings)
	outer_vbox.add_child(btn_save)


func _build_juice_section(parent: VBoxContainer, row_h: float) -> void:
	var is_mob: bool = _is_mobile()
	juice_card = PanelContainer.new()
	juice_card.theme_type_variation = "SubPanel"
	parent.add_child(juice_card)

	var juice_vbox: VBoxContainer = VBoxContainer.new()
	juice_vbox.add_theme_constant_override("separation", 4)
	juice_card.add_child(juice_vbox)

	var juice_title: Label = Label.new()
	juice_title.text = "Motion FX & Dynamic Juice:"
	juice_title.theme_type_variation = "HeaderLabel"
	juice_title.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	juice_vbox.add_child(juice_title)

	check_juice_master = _create_icon_check("icon_states", "Enable Dynamic Juice & Motion FX", row_h)
	check_juice_master.button_pressed = SettingsManager.is_juice_enabled()
	check_juice_master.toggled.connect(_on_juice_master_toggled)
	juice_vbox.add_child(check_juice_master)

	juice_sub_container = VBoxContainer.new()
	juice_sub_container.add_theme_constant_override("separation", 4)
	juice_sub_container.visible = check_juice_master.button_pressed
	juice_vbox.add_child(juice_sub_container)

	check_juice_idle = _create_icon_check("icon_sun", "Gentle Idle Breathing & Levitation", row_h)
	check_juice_idle.button_pressed = SettingsManager.is_juice_idle_motion_enabled()
	check_juice_idle.toggled.connect(func(v: bool) -> void: SettingsManager.set_juice_idle_motion_enabled(v))
	juice_sub_container.add_child(check_juice_idle)

	juice_idle_intensity_hdr = HBoxContainer.new()
	juice_sub_container.add_child(juice_idle_intensity_hdr)

	lbl_juice_intensity = Label.new()
	lbl_juice_intensity.text = "Breathing Intensity:"
	lbl_juice_intensity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_juice_intensity.theme_type_variation = "HintLabel"
	lbl_juice_intensity.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	juice_idle_intensity_hdr.add_child(lbl_juice_intensity)

	var current_intensity: float = SettingsManager.get_juice_idle_intensity()
	val_juice_intensity_lbl = Label.new()
	val_juice_intensity_lbl.text = "%.1fx" % current_intensity
	val_juice_intensity_lbl.theme_type_variation = "HeaderLabel"
	val_juice_intensity_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	juice_idle_intensity_hdr.add_child(val_juice_intensity_lbl)

	sld_juice_idle_intensity = HSlider.new()
	sld_juice_idle_intensity.min_value = 0.0
	sld_juice_idle_intensity.max_value = 2.0
	sld_juice_idle_intensity.step = 0.1
	sld_juice_idle_intensity.custom_minimum_size = Vector2(0.0, 22.0)
	sld_juice_idle_intensity.value = current_intensity
	sld_juice_idle_intensity.value_changed.connect(_on_juice_intensity_changed)
	juice_sub_container.add_child(sld_juice_idle_intensity)

	check_juice_tilts = _create_icon_check("icon_drink", "Physical Tilting (Pouring & Sips)", row_h)
	check_juice_tilts.button_pressed = SettingsManager.is_juice_physical_tilts_enabled()
	check_juice_tilts.toggled.connect(func(v: bool) -> void: SettingsManager.set_juice_physical_tilts_enabled(v))
	juice_sub_container.add_child(check_juice_tilts)

	check_juice_squash = _create_icon_check("icon_food", "Squash & Stretch (Chewing & Drops)", row_h)
	check_juice_squash.button_pressed = SettingsManager.is_juice_squash_stretch_enabled()
	check_juice_squash.toggled.connect(func(v: bool) -> void: SettingsManager.set_juice_squash_stretch_enabled(v))
	juice_sub_container.add_child(check_juice_squash)

	check_juice_springs = _create_icon_check("icon_plus", "Elastic Spring Juice on Spawns", row_h)
	check_juice_springs.button_pressed = SettingsManager.is_juice_spawn_springs_enabled()
	check_juice_springs.toggled.connect(func(v: bool) -> void: SettingsManager.set_juice_spawn_springs_enabled(v))
	juice_sub_container.add_child(check_juice_springs)


func _on_juice_master_toggled(enabled: bool) -> void:
	SettingsManager.set_juice_enabled(enabled)
	if juice_sub_container != null:
		juice_sub_container.visible = enabled


func _on_juice_intensity_changed(value: float) -> void:
	if val_juice_intensity_lbl != null:
		val_juice_intensity_lbl.text = "%.1fx" % value
	SettingsManager.set_juice_idle_intensity(value)


func _create_icon_check(icon_key: String, title: String, row_h: float) -> CheckBox:
	var is_mob: bool = _is_mobile()
	var checkbox: CheckBox = CheckBox.new()
	checkbox.text = " " + title
	checkbox.custom_minimum_size = Vector2(0.0, row_h)
	checkbox.add_theme_constant_override("icon_max_width", 18 if is_mob else 16)
	checkbox.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	_apply_checkbox_icon(checkbox, icon_key)
	return checkbox


func _build_reset_confirmation_modal() -> void:
	var is_mob: bool = _is_mobile()

	reset_modal_backdrop = Control.new()
	reset_modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	reset_modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	reset_modal_backdrop.visible = false
	reset_modal_backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
			reset_modal_backdrop.visible = false
	)
	add_child(reset_modal_backdrop)

	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.75)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reset_modal_backdrop.add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	reset_modal_backdrop.add_child(center)

	reset_panel = PanelContainer.new()
	reset_panel.custom_minimum_size = Vector2(400.0 if is_mob else 340.0, 200.0)
	center.add_child(reset_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	reset_panel.add_child(vbox)

	reset_title_lbl = Label.new()
	reset_title_lbl.text = "FACTORY RESET GAME?"
	reset_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reset_title_lbl.theme_type_variation = "HeaderLabel"
	reset_title_lbl.add_theme_font_size_override("font_size", 14 if is_mob else 12)
	vbox.add_child(reset_title_lbl)

	reset_desc_lbl = Label.new()
	reset_desc_lbl.text = "This will permanently delete all custom story universes, rooms, custom drawings, and settings."
	reset_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reset_desc_lbl.theme_type_variation = "HintLabel"
	reset_desc_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	vbox.add_child(reset_desc_lbl)

	var button_hbox: HBoxContainer = HBoxContainer.new()
	button_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(button_hbox)

	var btn_h: float = 40.0 if is_mob else 32.0

	var cancel_button: Button = Button.new()
	cancel_button.text = " Cancel"
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_button.custom_minimum_size = Vector2(0.0, btn_h)
	cancel_button.add_theme_constant_override("icon_max_width", 14)
	cancel_button.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	_apply_button_icon(cancel_button, "icon_close")
	cancel_button.pressed.connect(func() -> void: reset_modal_backdrop.visible = false)
	button_hbox.add_child(cancel_button)

	var confirm_button: Button = Button.new()
	confirm_button.text = " Wipe Everything"
	confirm_button.theme_type_variation = "DangerButton"
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_button.custom_minimum_size = Vector2(0.0, btn_h)
	confirm_button.add_theme_constant_override("icon_max_width", 14)
	confirm_button.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	_apply_button_icon(confirm_button, "icon_delete")
	confirm_button.pressed.connect(_execute_factory_reset)
	button_hbox.add_child(confirm_button)


func open_settings() -> void:
	master_slider.value = SettingsManager.get_master_volume()
	sfx_slider.value = SettingsManager.get_sfx_volume()
	music_slider.value = SettingsManager.get_music_volume()
	grid_check.button_pressed = SettingsManager.is_grid_snap_enabled()
	toasts_check.button_pressed = SettingsManager.are_toasts_enabled()
	dev_mode_check.button_pressed = SettingsManager.is_developer_mode_enabled()

	if dev_simulate_mobile_check != null:
		dev_simulate_mobile_check.button_pressed = SettingsManager.is_simulating_mobile_layout()

	var is_juice: bool = SettingsManager.is_juice_enabled()
	check_juice_master.button_pressed = is_juice
	if juice_sub_container != null: juice_sub_container.visible = is_juice
	check_juice_idle.button_pressed = SettingsManager.is_juice_idle_motion_enabled()
	sld_juice_idle_intensity.value = SettingsManager.get_juice_idle_intensity()
	val_juice_intensity_lbl.text = "%.1fx" % sld_juice_idle_intensity.value
	check_juice_tilts.button_pressed = SettingsManager.is_juice_physical_tilts_enabled()
	check_juice_squash.button_pressed = SettingsManager.is_juice_squash_stretch_enabled()
	check_juice_springs.button_pressed = SettingsManager.is_juice_spawn_springs_enabled()

	var current_scale: float = SettingsManager.get_ui_scale()
	ui_scale_slider.value = current_scale
	ui_scale_val_lbl.text = "%d%%" % int(current_scale * 100.0)

	var current_padding: float = SettingsManager.get_mobile_touch_padding()
	touch_padding_slider.value = current_padding
	touch_padding_val_lbl.text = "0 px" if int(current_padding) == 0 else "%d px" % int(current_padding)

	var current_long_press: float = SettingsManager.get_long_press_duration()
	long_press_slider.value = current_long_press
	long_press_val_lbl.text = "%.2fs" % current_long_press

	_update_responsive_layout()
	visible = true


func close_settings() -> void:
	SettingsManager.save_settings()
	EventBus.notification_requested.emit("Settings saved.", true)
	visible = false


func _on_master_volume_changed(value: float) -> void: SettingsManager.set_master_volume(value)
func _on_sfx_volume_changed(value: float) -> void: SettingsManager.set_sfx_volume(value)
func _on_music_volume_changed(value: float) -> void: SettingsManager.set_music_volume(value)
func _on_ui_scale_changed(value: float) -> void:
	ui_scale_val_lbl.text = "%d%%" % int(value * 100.0)
	SettingsManager.set_ui_scale(value)
func _on_touch_padding_changed(value: float) -> void:
	touch_padding_val_lbl.text = "0 px" if int(value) == 0 else "%d px" % int(value)
	SettingsManager.set_mobile_touch_padding(value)
func _on_long_press_duration_changed(value: float) -> void:
	long_press_val_lbl.text = "%.2fs" % value
	SettingsManager.set_long_press_duration(value)
func _on_grid_snap_toggled(toggled_on: bool) -> void: SettingsManager.set_grid_snap_enabled(toggled_on)
func _on_toasts_toggled(toggled_on: bool) -> void: SettingsManager.set_toasts_enabled(toggled_on)
func _on_dev_mode_toggled(toggled_on: bool) -> void: SettingsManager.set_developer_mode(toggled_on)


func _execute_factory_reset() -> void:
	reset_modal_backdrop.visible = false
	visible = false
	GameManager.factory_reset_entire_game()


func _refresh_theme_icons() -> void:
	_apply_button_icon(btn_factory, "icon_warning")
	_apply_button_icon(btn_save, "icon_save")
	_apply_checkbox_icon(grid_check, "icon_grid")
	_apply_checkbox_icon(toasts_check, "icon_toast")
	_apply_checkbox_icon(dev_mode_check, "icon_dev")
	if dev_simulate_mobile_check: _apply_checkbox_icon(dev_simulate_mobile_check, "icon_states")
	if check_juice_master: _apply_checkbox_icon(check_juice_master, "icon_states")
	if check_juice_idle: _apply_checkbox_icon(check_juice_idle, "icon_sun")
	if check_juice_tilts: _apply_checkbox_icon(check_juice_tilts, "icon_drink")
	if check_juice_squash: _apply_checkbox_icon(check_juice_squash, "icon_food")
	if check_juice_springs: _apply_checkbox_icon(check_juice_springs, "icon_plus")

	if root_panel != null:
		for node: Node in root_panel.find_children("*", "Button", true, false):
			if node is Button and (node as Button).text == "✕":
				_apply_close_icon(node as Button)


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


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		close_settings()
