# ==============================================================================
# OWNWORLD — WORLD MAP CONTROLLER (LANDSCAPE SAFE & TOUCH OPTIMIZED)
# File: res://Systems/WorldMapController.gd
# Base Class: CanvasLayer (class_name WorldMapController)
#
# Responsibility: Interactive universe map navigation, cardless building pins,
# multi-floor registration, and direct room transitions.
# ==============================================================================

class_name WorldMapController
extends CanvasLayer

var map_root_panel: PanelContainer = null
var main_vbox: VBoxContainer = null
var toolbar: PanelContainer = null
var atmo_panel: PanelContainer = null
var map_display: Control = null
var map_background_rect: TextureRect = null
var empty_hint_label: Label = null
var pins_container: Control = null
var title_lbl: Label = null
var current_bg_image_path: String = ""

var modal_backdrop: Control = null
var center_modal_box: CenterContainer = null
var pin_editor_panel: PanelContainer = null
var edit_title_lbl: Label = null
var edit_name_lbl: Label = null
var edit_building_id_lbl: Label = null
var edit_img_lbl: Label = null
var edit_name_input: LineEdit = null
var edit_building_id_input: LineEdit = null
var btn_choose_pin_art: Button = null
var btn_clear_pin_art: Button = null
var edit_preview_rect: TextureRect = null
var selected_pin_art_path: String = ""

# Floor Management in Building Settings
var floors_vbox: VBoxContainer = null
var btn_add_floor_to_bldg: Button = null
var working_floors_list: Array[Dictionary] = []
var deleted_room_ids: Array[String] = []

var active_editing_pin: MapPin = null
var asset_picker: AssetPickerDialog = null

var is_edit_mode: bool = false
var map_pins: Array[MapPin] = []

signal reset_all_rooms_requested()

const MAP_DIRECTORY: String = "user://maps/"
const SESSION_FILE: String = "user://session.json"


func _get_current_map_path() -> String:
	return MAP_DIRECTORY + SaveSystem.get_current_universe_id() + "_map.json"


func _ready() -> void:
	name = "WorldMapController"
	layer = 110
	visible = false
	add_to_group("modal_ui")
	_build_map_ui()
	_build_pin_editor_dialog()
	_setup_keyboard_dodging()

	asset_picker = AssetPickerDialog.new()
	add_child(asset_picker)

	if not ThemeService.theme_changed.is_connected(_on_theme_changed):
		ThemeService.theme_changed.connect(_on_theme_changed)


func _is_mobile() -> bool:
	return ThemeEngine.is_mobile_platform()


func _setup_keyboard_dodging() -> void:
	if not _is_mobile(): return
	var inputs: Array[LineEdit] = [edit_name_input, edit_building_id_input]
	for input in inputs:
		if input != null:
			input.focus_entered.connect(_on_input_focus_entered)
			input.focus_exited.connect(_on_input_focus_exited)


func _on_input_focus_entered() -> void:
	if _is_mobile() and center_modal_box != null:
		await get_tree().process_frame
		await get_tree().process_frame
		var kb_height: float = DisplayServer.virtual_keyboard_get_height()
		if kb_height > 0:
			var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(center_modal_box, "position:y", -kb_height * 0.45, 0.25)


func _on_input_focus_exited() -> void:
	if _is_mobile() and center_modal_box != null:
		var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(center_modal_box, "position:y", 0.0, 0.25)


func _on_theme_changed(_theme_data: Dictionary) -> void:
	_refresh_existing_pin_icons()


func _refresh_existing_pin_icons() -> void:
	for pin: MapPin in map_pins:
		if is_instance_valid(pin): pin.refresh_theme_icons()


func _build_map_ui() -> void:
	var is_mob: bool = _is_mobile()
	var btn_h: float = 36.0 if is_mob else 28.0

	map_root_panel = PanelContainer.new()
	map_root_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_root_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(map_root_panel)

	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	var margin_left: int = maxi(12, safe_area.position.x + 6) if is_mob else 0
	var margin_right: int = maxi(12, int(DisplayServer.screen_get_size().x - (safe_area.position.x + safe_area.size.x)) + 6) if is_mob else 0

	main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	main_vbox.add_theme_constant_override("separation", 0)
	map_root_panel.add_child(main_vbox)

	toolbar = PanelContainer.new()
	toolbar.theme_type_variation = "SubPanel"
	toolbar.custom_minimum_size = Vector2(0.0, 48.0 if is_mob else 40.0)
	main_vbox.add_child(toolbar)

	var tb_margin: MarginContainer = MarginContainer.new()
	tb_margin.add_theme_constant_override("margin_left", margin_left + 10)
	tb_margin.add_theme_constant_override("margin_right", margin_right + 10)
	tb_margin.add_theme_constant_override("margin_top", 6)
	tb_margin.add_theme_constant_override("margin_bottom", 6)
	toolbar.add_child(tb_margin)

	var tb_hbox: HBoxContainer = HBoxContainer.new()
	tb_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tb_hbox.add_theme_constant_override("separation", 10)
	tb_margin.add_child(tb_hbox)

	title_lbl = Label.new()
	title_lbl.theme_type_variation = "HeaderLabel"
	title_lbl.text = "DEFAULT UNIVERSE"
	title_lbl.add_theme_font_size_override("font_size", 14 if is_mob else 12)
	tb_hbox.add_child(title_lbl)

	var spacer_left: Control = Control.new()
	spacer_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb_hbox.add_child(spacer_left)

	var tb_tools_hbox: HBoxContainer = HBoxContainer.new()
	tb_tools_hbox.add_theme_constant_override("separation", 8)
	tb_hbox.add_child(tb_tools_hbox)

	var btn_mode: Button = Button.new()
	btn_mode.text = " Play"
	btn_mode.custom_minimum_size = Vector2(0.0, btn_h)
	btn_mode.focus_mode = Control.FOCUS_NONE
	btn_mode.add_theme_constant_override("icon_max_width", 14)
	btn_mode.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	var play_icon: Texture2D = ThemeService.get_icon("icon_play")
	if play_icon: btn_mode.icon = play_icon

	btn_mode.pressed.connect(func() -> void:
		is_edit_mode = not is_edit_mode
		btn_mode.text = " Edit" if is_edit_mode else " Play"
		var mode_icon: Texture2D = ThemeService.get_icon("icon_pencil" if is_edit_mode else "icon_play")
		if mode_icon: btn_mode.icon = mode_icon
		_update_pins_edit_mode()
		EventBus.notification_requested.emit("Mode: " + ("Edit Buildings" if is_edit_mode else "Play Exploration"), true)
	)
	tb_tools_hbox.add_child(btn_mode)

	var btn_add_pin: Button = Button.new()
	btn_add_pin.text = " + Building"
	btn_add_pin.custom_minimum_size = Vector2(0.0, btn_h)
	btn_add_pin.focus_mode = Control.FOCUS_NONE
	btn_add_pin.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	var bldg_icon: Texture2D = ThemeService.get_icon("icon_room")
	if bldg_icon: btn_add_pin.icon = bldg_icon
	btn_add_pin.pressed.connect(_on_add_building_pressed)
	tb_tools_hbox.add_child(btn_add_pin)

	var btn_change_bg: Button = Button.new()
	btn_change_bg.text = " Map Art"
	btn_change_bg.custom_minimum_size = Vector2(0.0, btn_h)
	btn_change_bg.focus_mode = Control.FOCUS_NONE
	btn_change_bg.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	var brush_icon: Texture2D = ThemeService.get_icon("icon_palette")
	if brush_icon: btn_change_bg.icon = brush_icon
	btn_change_bg.pressed.connect(_on_change_bg_pressed)
	tb_tools_hbox.add_child(btn_change_bg)

	var btn_reset: Button = Button.new()
	btn_reset.text = " Reset Rooms"
	btn_reset.theme_type_variation = "DangerButton"
	btn_reset.custom_minimum_size = Vector2(0.0, btn_h)
	btn_reset.focus_mode = Control.FOCUS_NONE
	btn_reset.add_theme_constant_override("icon_max_width", 14)
	btn_reset.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	var ref_icon: Texture2D = ThemeService.get_icon("icon_refresh")
	if ref_icon: btn_reset.icon = ref_icon
	btn_reset.pressed.connect(_on_reset_rooms_pressed)
	tb_tools_hbox.add_child(btn_reset)

	var spacer_right: Control = Control.new()
	spacer_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb_hbox.add_child(spacer_right)

	var btn_close: Button = Button.new()
	btn_close.text = " Close"
	btn_close.custom_minimum_size = Vector2(0.0, btn_h)
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.add_theme_constant_override("icon_max_width", 12)
	btn_close.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	var close_icon: Texture2D = ThemeService.get_icon("icon_close")
	if close_icon: btn_close.icon = close_icon
	btn_close.pressed.connect(close_map)
	tb_hbox.add_child(btn_close)

	map_display = Control.new()
	map_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_display.mouse_filter = Control.MOUSE_FILTER_PASS
	map_display.clip_contents = true
	main_vbox.add_child(map_display)

	map_background_rect = TextureRect.new()
	map_background_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_display.add_child(map_background_rect)

	empty_hint_label = Label.new()
	empty_hint_label.text = "Blank Map Canvas\nTap 'Map Art' above to choose a background illustration from your library."
	empty_hint_label.theme_type_variation = "HintLabel"
	empty_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_hint_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	empty_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	empty_hint_label.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	map_display.add_child(empty_hint_label)

	pins_container = Control.new()
	pins_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	pins_container.mouse_filter = Control.MOUSE_FILTER_PASS
	map_display.add_child(pins_container)

	_build_atmosphere_control_bar(main_vbox, margin_left, margin_right)


func _build_atmosphere_control_bar(parent_vbox: VBoxContainer, margin_left: int, margin_right: int) -> void:
	var is_mob: bool = _is_mobile()
	var atmo_h: float = 34.0 if is_mob else 28.0

	atmo_panel = PanelContainer.new()
	atmo_panel.theme_type_variation = "SubPanel"
	atmo_panel.custom_minimum_size = Vector2(0.0, 44.0 if is_mob else 38.0)
	parent_vbox.add_child(atmo_panel)

	var atmo_margin: MarginContainer = MarginContainer.new()
	atmo_margin.add_theme_constant_override("margin_left", margin_left + 10)
	atmo_margin.add_theme_constant_override("margin_right", margin_right + 10)
	atmo_margin.add_theme_constant_override("margin_top", 4)
	atmo_margin.add_theme_constant_override("margin_bottom", 4)
	atmo_panel.add_child(atmo_margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	atmo_margin.add_child(hbox)

	var lbl_time: Label = Label.new()
	lbl_time.text = "Mood:"
	lbl_time.theme_type_variation = "HintLabel"
	lbl_time.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	hbox.add_child(lbl_time)

	var times: Array[Dictionary] = [
		{"name": "Day", "icon": "icon_sun"}, {"name": "Sunset", "icon": "icon_sunset"},
		{"name": "Night", "icon": "icon_night"}, {"name": "Cozy", "icon": "icon_cozy"}
	]
	for t_data: Dictionary in times:
		var btn: Button = Button.new()
		btn.text = " " + str(t_data["name"])
		btn.custom_minimum_size = Vector2(0.0, atmo_h)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_constant_override("icon_max_width", 14)
		btn.add_theme_font_size_override("font_size", 11 if is_mob else 10)
		var t_icon: Texture2D = ThemeService.get_icon(str(t_data["icon"]))
		if t_icon: btn.icon = t_icon
		var cap_t: String = str(t_data["name"])
		btn.pressed.connect(func() -> void:
			EventBus.global_atmosphere_changed.emit(cap_t.to_lower(), "none")
			EventBus.notification_requested.emit("Mood: " + cap_t, true)
		)
		hbox.add_child(btn)

	hbox.add_child(VSeparator.new())

	var lbl_weather: Label = Label.new()
	lbl_weather.text = "Weather:"
	lbl_weather.theme_type_variation = "HintLabel"
	lbl_weather.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	hbox.add_child(lbl_weather)

	var weathers: Array[Dictionary] = [
		{"name": "None", "label": "Clear", "icon": "icon_sun"},
		{"name": "Rain", "label": "Rain", "icon": "icon_rain"},
		{"name": "Snow", "label": "Snow", "icon": "icon_snow"},
		{"name": "Leaves", "label": "Leaves", "icon": "icon_leaves"}
	]
	for w_data: Dictionary in weathers:
		var btn: Button = Button.new()
		btn.text = " " + str(w_data["label"])
		btn.custom_minimum_size = Vector2(0.0, atmo_h)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_constant_override("icon_max_width", 14)
		btn.add_theme_font_size_override("font_size", 11 if is_mob else 10)
		var w_icon: Texture2D = ThemeService.get_icon(str(w_data["icon"]))
		if w_icon: btn.icon = w_icon
		var w_name: String = str(w_data["name"]).to_lower()
		var w_lbl: String = str(w_data["label"])
		btn.pressed.connect(func() -> void:
			EventBus.global_atmosphere_changed.emit("day", w_name)
			EventBus.notification_requested.emit("Weather: " + w_lbl, true)
		)
		hbox.add_child(btn)


func _build_pin_editor_dialog() -> void:
	var is_mob: bool = _is_mobile()
	var row_h: float = 34.0 if is_mob else 28.0

	modal_backdrop = Control.new()
	modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_backdrop.visible = false
	modal_backdrop.gui_input.connect(_on_modal_backdrop_gui_input)
	add_child(modal_backdrop)

	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_backdrop.add_child(dim)

	center_modal_box = CenterContainer.new()
	center_modal_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_modal_box.mouse_filter = Control.MOUSE_FILTER_PASS
	modal_backdrop.add_child(center_modal_box)

	pin_editor_panel = PanelContainer.new()
	pin_editor_panel.custom_minimum_size = Vector2(540.0 if is_mob else 460.0, 480.0 if is_mob else 420.0)
	pin_editor_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center_modal_box.add_child(pin_editor_panel)

	var outer_vbox: VBoxContainer = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 6)
	pin_editor_panel.add_child(outer_vbox)

	edit_title_lbl = Label.new()
	edit_title_lbl.text = "Building Settings & Floor Management"
	edit_title_lbl.theme_type_variation = "HeaderLabel"
	edit_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit_title_lbl.add_theme_font_size_override("font_size", 14 if is_mob else 12)
	outer_vbox.add_child(edit_title_lbl)

	outer_vbox.add_child(HSeparator.new())

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = false
	outer_vbox.add_child(scroll)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	# --- Building Identity ---
	var id_grid: GridContainer = GridContainer.new()
	id_grid.columns = 2
	id_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_grid.add_theme_constant_override("h_separation", 8)
	vbox.add_child(id_grid)

	var name_box: VBoxContainer = VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_theme_constant_override("separation", 2)
	id_grid.add_child(name_box)

	edit_name_lbl = Label.new()
	edit_name_lbl.text = "Building Name:"
	edit_name_lbl.theme_type_variation = "HintLabel"
	name_box.add_child(edit_name_lbl)

	edit_name_input = LineEdit.new()
	edit_name_input.placeholder_text = "e.g. Castle, Bakery, Tower..."
	edit_name_input.custom_minimum_size = Vector2(0.0, row_h)
	name_box.add_child(edit_name_input)

	var bldg_id_box: VBoxContainer = VBoxContainer.new()
	bldg_id_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bldg_id_box.add_theme_constant_override("separation", 2)
	id_grid.add_child(bldg_id_box)

	edit_building_id_lbl = Label.new()
	edit_building_id_lbl.text = "Shared Building ID:"
	edit_building_id_lbl.theme_type_variation = "HintLabel"
	bldg_id_box.add_child(edit_building_id_lbl)

	edit_building_id_input = LineEdit.new()
	edit_building_id_input.placeholder_text = "e.g. building_castle"
	edit_building_id_input.custom_minimum_size = Vector2(0.0, row_h)
	bldg_id_box.add_child(edit_building_id_input)

	# --- Building Artwork Picker ---
	var img_section: VBoxContainer = VBoxContainer.new()
	img_section.add_theme_constant_override("separation", 3)
	vbox.add_child(img_section)

	edit_img_lbl = Label.new()
	edit_img_lbl.text = "Map Pin Illustration (Cardless Artwork):"
	edit_img_lbl.theme_type_variation = "HintLabel"
	img_section.add_child(edit_img_lbl)

	var img_hbox: HBoxContainer = HBoxContainer.new()
	img_hbox.add_theme_constant_override("separation", 8)
	img_section.add_child(img_hbox)

	var prev_card: PanelContainer = PanelContainer.new()
	prev_card.theme_type_variation = "SubPanel"
	prev_card.custom_minimum_size = Vector2(48.0 if is_mob else 40.0, 48.0 if is_mob else 40.0)
	prev_card.clip_contents = true
	img_hbox.add_child(prev_card)

	edit_preview_rect = TextureRect.new()
	edit_preview_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	edit_preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	edit_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prev_card.add_child(edit_preview_rect)

	btn_choose_pin_art = Button.new()
	btn_choose_pin_art.text = " Choose Drawing from Library..."
	btn_choose_pin_art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_choose_pin_art.custom_minimum_size = Vector2(0.0, row_h)
	btn_choose_pin_art.focus_mode = Control.FOCUS_NONE
	var f_icon: Texture2D = ThemeService.get_icon("icon_folder")
	if f_icon: btn_choose_pin_art.icon = f_icon
	btn_choose_pin_art.pressed.connect(_on_choose_pin_art_pressed)
	img_hbox.add_child(btn_choose_pin_art)

	btn_clear_pin_art = Button.new()
	btn_clear_pin_art.text = "Reset Art"
	btn_clear_pin_art.custom_minimum_size = Vector2(85.0 if is_mob else 75.0, row_h)
	btn_clear_pin_art.focus_mode = Control.FOCUS_NONE
	btn_clear_pin_art.pressed.connect(_on_clear_pin_art_pressed)
	img_hbox.add_child(btn_clear_pin_art)

	vbox.add_child(HSeparator.new())

	# --- Building Floors Management ---
	var floors_section: PanelContainer = PanelContainer.new()
	floors_section.theme_type_variation = "SubPanel"
	vbox.add_child(floors_section)

	var floors_inner_vbox: VBoxContainer = VBoxContainer.new()
	floors_inner_vbox.add_theme_constant_override("separation", 6)
	floors_section.add_child(floors_inner_vbox)

	var floors_hdr_hbox: HBoxContainer = HBoxContainer.new()
	floors_inner_vbox.add_child(floors_hdr_hbox)

	var lbl_floors: Label = Label.new()
	lbl_floors.text = "Building Floors & Elevator Levels:"
	lbl_floors.theme_type_variation = "HeaderLabel"
	lbl_floors.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_floors.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	floors_hdr_hbox.add_child(lbl_floors)

	btn_add_floor_to_bldg = Button.new()
	btn_add_floor_to_bldg.text = " + Add Floor"
	btn_add_floor_to_bldg.custom_minimum_size = Vector2(100.0 if is_mob else 85.0, 28.0 if is_mob else 24.0)
	btn_add_floor_to_bldg.focus_mode = Control.FOCUS_NONE
	btn_add_floor_to_bldg.add_theme_font_size_override("font_size", 10)
	btn_add_floor_to_bldg.pressed.connect(_on_add_floor_to_building_pressed)
	floors_hdr_hbox.add_child(btn_add_floor_to_bldg)

	var floor_col_header: HBoxContainer = HBoxContainer.new()
	floor_col_header.add_theme_constant_override("separation", 6)
	floors_inner_vbox.add_child(floor_col_header)

	var h_lvl: Label = Label.new()
	h_lvl.text = "Level (1F, 2F)"
	h_lvl.custom_minimum_size = Vector2(90.0, 0.0)
	h_lvl.theme_type_variation = "HintLabel"
	h_lvl.add_theme_font_size_override("font_size", 10 if is_mob else 9)
	floor_col_header.add_child(h_lvl)

	var h_title: Label = Label.new()
	h_title.text = "Room Name / Title"
	h_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_title.theme_type_variation = "HintLabel"
	h_title.add_theme_font_size_override("font_size", 10 if is_mob else 9)
	floor_col_header.add_child(h_title)

	var h_id: Label = Label.new()
	h_id.text = "Room ID (Key)"
	h_id.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_id.theme_type_variation = "HintLabel"
	h_id.add_theme_font_size_override("font_size", 10 if is_mob else 9)
	floor_col_header.add_child(h_id)

	var h_del: Control = Control.new()
	h_del.custom_minimum_size = Vector2(28.0 if is_mob else 22.0, 0.0)
	floor_col_header.add_child(h_del)

	floors_vbox = VBoxContainer.new()
	floors_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	floors_vbox.add_theme_constant_override("separation", 4)
	floors_inner_vbox.add_child(floors_vbox)

	outer_vbox.add_child(HSeparator.new())

	var btn_save: Button = Button.new()
	btn_save.text = " Save Building & Floors"
	btn_save.custom_minimum_size = Vector2(0.0, row_h + 4.0)
	btn_save.focus_mode = Control.FOCUS_NONE
	btn_save.add_theme_constant_override("icon_max_width", 16)
	btn_save.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	var s_icon: Texture2D = ThemeService.get_icon("icon_save")
	if s_icon: btn_save.icon = s_icon
	btn_save.pressed.connect(_on_save_pin_editor_pressed)
	outer_vbox.add_child(btn_save)


func open_pin_editor(pin: MapPin) -> void:
	active_editing_pin = pin
	edit_name_input.text = pin.building_name
	edit_building_id_input.text = pin.building_id
	selected_pin_art_path = pin.image_path

	if not selected_pin_art_path.is_empty() and FileAccess.file_exists(selected_pin_art_path):
		edit_preview_rect.texture = UGCManager.get_thumbnail_async(selected_pin_art_path, 128)
		btn_choose_pin_art.text = " Art: " + selected_pin_art_path.get_file().get_basename()
	else:
		edit_preview_rect.texture = pin.pin_texture
		btn_choose_pin_art.text = " Choose Drawing from Library..."

	deleted_room_ids.clear()
	_load_floors_for_editing_building(pin.building_id, pin.building_name)
	modal_backdrop.visible = true


func _on_choose_pin_art_pressed() -> void:
	if asset_picker == null: return
	asset_picker.open_picker("Choose Building Pin Drawing", "", func(art_name: String, texture: Texture2D, file_path: String) -> void:
		selected_pin_art_path = file_path
		edit_preview_rect.texture = texture
		btn_choose_pin_art.text = " Art: " + art_name
	)


func _on_clear_pin_art_pressed() -> void:
	selected_pin_art_path = ""
	edit_preview_rect.texture = UGCManager.create_blank_starter_graphic(Vector2(64.0, 64.0), Color("#0284c7"))
	btn_choose_pin_art.text = " Choose Drawing from Library..."


func _load_floors_for_editing_building(bldg_id: String, bldg_name: String) -> void:
	working_floors_list.clear()
	var raw_floors: Array[Dictionary] = SaveSystem.get_building_floors(bldg_id)

	if raw_floors.is_empty():
		var entry_room_id: String = "room_main" if bldg_id == "building_main" else bldg_id + "_1f"
		working_floors_list.append({
			"floor_level": "1F",
			"room_title": bldg_name + " (1F)",
			"room_id": entry_room_id
		})
	else:
		for fl_data: Dictionary in raw_floors:
			var r_id: String = str(fl_data.get("room_id", ""))
			var room_state: Dictionary = SaveSystem.load_room_state(r_id)
			working_floors_list.append({
				"floor_level": str(fl_data.get("floor_level", "1F")),
				"room_title": str(room_state.get("room_title", fl_data.get("label", "Floor"))),
				"room_id": r_id
			})

	_render_floors_list()


func _render_floors_list() -> void:
	if floors_vbox == null: return
	for child: Node in floors_vbox.get_children():
		child.queue_free()

	var is_mob: bool = _is_mobile()
	var row_h: float = 34.0 if is_mob else 28.0

	for index: int in range(working_floors_list.size()):
		var fl_data: Dictionary = working_floors_list[index]
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var lvl_edit: LineEdit = LineEdit.new()
		lvl_edit.text = str(fl_data.get("floor_level", "1F"))
		lvl_edit.placeholder_text = "1F, 2F..."
		lvl_edit.custom_minimum_size = Vector2(90.0, row_h)
		var target_idx: int = index
		lvl_edit.text_changed.connect(func(new_lvl: String) -> void:
			working_floors_list[target_idx]["floor_level"] = new_lvl.strip_edges()
		)
		row.add_child(lvl_edit)

		var title_edit: LineEdit = LineEdit.new()
		title_edit.text = str(fl_data.get("room_title", "Room"))
		title_edit.placeholder_text = "Room Name..."
		title_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_edit.custom_minimum_size = Vector2(0.0, row_h)
		title_edit.text_changed.connect(func(new_title: String) -> void:
			working_floors_list[target_idx]["room_title"] = new_title.strip_edges()
		)
		row.add_child(title_edit)

		var id_edit: LineEdit = LineEdit.new()
		id_edit.text = str(fl_data.get("room_id", ""))
		id_edit.placeholder_text = "Room ID..."
		id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		id_edit.custom_minimum_size = Vector2(0.0, row_h)
		id_edit.text_changed.connect(func(new_id: String) -> void:
			working_floors_list[target_idx]["room_id"] = new_id.strip_edges()
		)
		row.add_child(id_edit)

		var del_btn: Button = Button.new()
		del_btn.text = "✕"
		del_btn.custom_minimum_size = Vector2(28.0 if is_mob else 22.0, row_h)
		del_btn.theme_type_variation = "DangerButton"
		del_btn.focus_mode = Control.FOCUS_NONE
		del_btn.pressed.connect(func() -> void: _remove_floor_from_building(target_idx))
		row.add_child(del_btn)

		floors_vbox.add_child(row)


func _on_add_floor_to_building_pressed() -> void:
	var next_num: int = working_floors_list.size() + 1
	var b_id: String = edit_building_id_input.text.strip_edges()
	if b_id.is_empty(): b_id = "building_main"
	var b_name: String = edit_name_input.text.strip_edges()
	if b_name.is_empty(): b_name = "Building"

	var next_level_str: String = "%dF" % next_num
	var next_room_id: String = "%s_%df" % [b_id.to_lower().replace(" ", "_"), next_num]
	var next_title: String = "%s (%s)" % [b_name, next_level_str]

	working_floors_list.append({
		"floor_level": next_level_str,
		"room_title": next_title,
		"room_id": next_room_id
	})
	_render_floors_list()


func _remove_floor_from_building(index: int) -> void:
	if index < 0 or index >= working_floors_list.size(): return
	var r_id_to_delete: String = str(working_floors_list[index].get("room_id", "")).strip_edges()
	if not r_id_to_delete.is_empty() and r_id_to_delete != "room_main":
		deleted_room_ids.append(r_id_to_delete)

	working_floors_list.remove_at(index)
	_render_floors_list()


func _on_save_pin_editor_pressed() -> void:
	if active_editing_pin and is_instance_valid(active_editing_pin):
		var b_name: String = edit_name_input.text.strip_edges()
		if b_name.is_empty(): b_name = "Building"

		var b_id: String = edit_building_id_input.text.strip_edges().to_lower().replace(" ", "_")
		if b_id.is_empty(): b_id = "building_" + b_name.to_lower().replace(" ", "_")

		active_editing_pin.building_name = b_name
		active_editing_pin.building_id = b_id

		if not selected_pin_art_path.is_empty() and FileAccess.file_exists(selected_pin_art_path):
			active_editing_pin.set_pin_image(selected_pin_art_path, UGCManager.get_thumbnail_async(selected_pin_art_path, 128))
		else:
			active_editing_pin.image_path = ""
			active_editing_pin.set_pin_image("", UGCManager.create_blank_starter_graphic(Vector2(64.0, 64.0), Color("#0284c7")))

		active_editing_pin.update_visuals()

		var save_dir: String = SaveSystem.get_universe_save_dir()
		for del_id: String in deleted_room_ids:
			var del_path: String = save_dir.path_join(del_id + ".json")
			if FileAccess.file_exists(del_path):
				DirAccess.remove_absolute(del_path)

		for fl_data: Dictionary in working_floors_list:
			var r_id: String = str(fl_data.get("room_id", "")).strip_edges()
			if r_id.is_empty(): continue

			var r_level: String = str(fl_data.get("floor_level", "1F")).strip_edges()
			var r_title: String = str(fl_data.get("room_title", b_name + " (" + r_level + ")")).strip_edges()

			var existing_state: Dictionary = SaveSystem.load_room_state(r_id)
			if existing_state.is_empty():
				existing_state = SaveSchema.create_empty_room(r_id, b_id, b_name, r_level)
				existing_state["room_title"] = r_title
			else:
				existing_state["building_id"] = b_id
				existing_state["building_name"] = b_name
				existing_state["floor_level"] = r_level
				existing_state["room_title"] = r_title

			SaveSystem.save_room_state(r_id, existing_state)

		save_map_for_current_universe()
		EventBus.notification_requested.emit("Saved Building & Floors: " + b_name, true)

	modal_backdrop.visible = false
	active_editing_pin = null


func _on_modal_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		modal_backdrop.visible = false
		active_editing_pin = null


func open_map() -> void:
	visible = true
	if modal_backdrop: modal_backdrop.visible = false
	load_map_for_current_universe()


func close_map() -> void:
	save_map_for_current_universe()
	if modal_backdrop: modal_backdrop.visible = false
	visible = false


func _on_change_bg_pressed() -> void:
	if asset_picker == null: return
	asset_picker.open_picker("Choose Map Background Artwork", "", func(_name: String, texture: Texture2D, file_path: String) -> void:
		_on_bg_asset_selected(file_path, texture)
	)


func _on_bg_asset_selected(fpath: String, texture: Texture2D) -> void:
	current_bg_image_path = fpath.strip_edges()
	map_background_rect.texture = texture if texture != null else UGCManager.load_texture_from_file(current_bg_image_path)
	empty_hint_label.visible = false
	save_map_for_current_universe()
	EventBus.notification_requested.emit("Map background updated!", true)


func _update_pins_edit_mode() -> void:
	for pin: MapPin in map_pins:
		if is_instance_valid(pin): pin.set_edit_mode(is_edit_mode)


func load_map_for_current_universe() -> void:
	if title_lbl: title_lbl.text = SaveSystem.get_current_universe_name().to_upper()
	for child: Node in pins_container.get_children(): child.queue_free()
	map_pins.clear()

	var map_file_path: String = _get_current_map_path()
	if FileAccess.file_exists(map_file_path):
		var parsed: Dictionary = JsonFileStore.read_dictionary(map_file_path)
		if not parsed.is_empty():
			current_bg_image_path = str(parsed.get("bg_image_path", "")).strip_edges()
			if not current_bg_image_path.is_empty() and FileAccess.file_exists(current_bg_image_path):
				map_background_rect.texture = UGCManager.load_texture_from_file(current_bg_image_path)
				empty_hint_label.visible = false
			else:
				map_background_rect.texture = null
				empty_hint_label.visible = true

			var pins_data: Array = parsed.get("pins", [])
			for p_dict_var: Variant in pins_data:
				if not (p_dict_var is Dictionary): continue
				var p_dict: Dictionary = p_dict_var as Dictionary
				var b_name: String = str(p_dict.get("name", p_dict.get("building_name", "Building"))).strip_edges()
				var b_id: String = str(p_dict.get("building_id", p_dict.get("room_id", "building_main"))).strip_edges()
				var p_img_path: String = str(p_dict.get("image_path", "")).strip_edges()
				var p_pos: Vector2 = Vector2(float(p_dict.get("x", 400.0)), float(p_dict.get("y", 200.0)))
				var tex: Texture2D = UGCManager.get_thumbnail_async(p_img_path, 128) if (not p_img_path.is_empty() and FileAccess.file_exists(p_img_path)) else UGCManager.create_blank_starter_graphic(Vector2(64.0, 64.0), Color("#0284c7"))
				create_pin(b_name, b_id, p_pos, p_img_path, tex)
			_update_pins_edit_mode()
			return

	current_bg_image_path = ""
	map_background_rect.texture = null
	empty_hint_label.visible = true
	create_pin(SaveSystem.get_current_universe_name() + " Main", "building_main", Vector2(400.0, 200.0))
	_update_pins_edit_mode()
	save_map_for_current_universe()


func save_map_for_current_universe() -> void:
	var pins_data: Array[Dictionary] = []
	for pin: MapPin in map_pins:
		if is_instance_valid(pin):
			pins_data.append({
				"name": pin.building_name,
				"building_name": pin.building_name,
				"building_id": pin.building_id,
				"room_id": pin.building_id,
				"image_path": pin.image_path,
				"x": pin.position.x,
				"y": pin.position.y
			})

	var map_payload: Dictionary = {
		"universe_id": SaveSystem.get_current_universe_id(),
		"universe_name": SaveSystem.get_current_universe_name(),
		"bg_image_path": current_bg_image_path,
		"pins": pins_data
	}
	JsonFileStore.write_dictionary(_get_current_map_path(), map_payload)


func create_pin(b_name: String, b_id: String, pos: Vector2, img_path: String = "", tex: Texture2D = null) -> MapPin:
	var pin: MapPin = MapPin.new()
	var final_tex: Texture2D = tex if tex != null else UGCManager.create_blank_starter_graphic(Vector2(64.0, 64.0), Color("#0284c7"))
	pin.setup(b_name, b_id, pos, img_path, final_tex, self)
	pin.pin_selected.connect(_on_pin_selected)
	pin.pin_deleted.connect(_on_pin_deleted)
	pin.pin_configure_requested.connect(open_pin_editor)
	pins_container.add_child(pin)
	map_pins.append(pin)
	return pin


func _on_add_building_pressed() -> void:
	var count: int = map_pins.size() + 1
	var new_pin: MapPin = create_pin("Building " + str(count), "building_" + str(count), Vector2(250.0 + float(count * 40), 160.0))
	new_pin.set_edit_mode(is_edit_mode)
	save_map_for_current_universe()
	open_pin_editor(new_pin)


func _on_pin_deleted(pin: MapPin) -> void:
	map_pins.erase(pin)
	pin.queue_free()
	save_map_for_current_universe()


func _on_reset_rooms_pressed() -> void:
	close_map()
	reset_all_rooms_requested.emit()


func _on_pin_selected(pin: MapPin) -> void:
	if is_edit_mode:
		return

	var floors: Array[Dictionary] = SaveSystem.get_building_floors(pin.building_id)

	if floors.size() > 1:
		var pop: PopupMenu = PopupMenu.new()
		pop.theme = ThemeService.create_theme()
		add_child(pop)

		for i: int in range(floors.size()):
			var fl: Dictionary = floors[i]
			var fl_label: String = str(fl.get("label", fl.get("room_id", "Floor")))
			pop.add_item(fl_label, i)

		pop.id_pressed.connect(func(id: int) -> void:
			if id >= 0 and id < floors.size():
				var chosen_fl: Dictionary = floors[id]
				var r_id: String = str(chosen_fl.get("room_id", ""))
				var fl_lvl: String = str(chosen_fl.get("floor_level", "1F"))
				var fl_label: String = str(chosen_fl.get("label", pin.building_name))
				pop.queue_free()
				close_map()

				var traveler_data: Dictionary = {
					"building_id": pin.building_id,
					"building_name": pin.building_name,
					"floor_level": fl_lvl,
					"room_title": fl_label,
					"source": "world_map"
				}
				EventBus.room_change_requested.emit(r_id, traveler_data)
		)

		pop.popup_hide.connect(pop.queue_free)
		var pin_global_pos: Vector2 = pin.get_global_rect().position
		pop.position = Vector2i(int(pin_global_pos.x - 20.0), int(pin_global_pos.y + 70.0))
		pop.popup()
	else:
		close_map()
		var target_entry_room: String = SaveSystem.get_building_entry_room_id(pin.building_id)
		var traveler_data: Dictionary = {
			"building_id": pin.building_id,
			"building_name": pin.building_name,
			"floor_level": "1F",
			"room_title": pin.building_name + " (1F)",
			"source": "world_map"
		}
		EventBus.room_change_requested.emit(target_entry_room, traveler_data)


# --- CARDLESS MAP BUILDING PIN (AUTO-CENTERED & RESPONSIVE) ---

class MapPin extends Control:
	var building_name: String = ""
	var building_id: String = ""
	var image_path: String = ""
	var pin_texture: Texture2D = null

	var is_dragging: bool = false
	var drag_start_mouse: Vector2 = Vector2.ZERO
	var pin_start_pos: Vector2 = Vector2.ZERO

	var map_controller: WorldMapController = null
	var center_vbox: VBoxContainer = null
	var texture_rect: TextureRect = null
	var label_node: Label = null
	var delete_btn: Button = null
	var config_btn: Button = null

	signal pin_selected(pin: MapPin)
	signal pin_deleted(pin: MapPin)
	signal pin_configure_requested(pin: MapPin)


	func setup(p_name: String, p_bldg_id: String, p_pos: Vector2, p_img_path: String, p_tex: Texture2D, controller_ref: WorldMapController) -> void:
		building_name = p_name.strip_edges()
		building_id = p_bldg_id.strip_edges()
		position = p_pos
		image_path = p_img_path.strip_edges()
		pin_texture = p_tex
		map_controller = controller_ref

		custom_minimum_size = Vector2(96.0, 100.0)
		size = Vector2(96.0, 100.0)
		mouse_filter = Control.MOUSE_FILTER_PASS
		_build_visuals()


	func set_pin_image(p_path: String, p_tex: Texture2D) -> void:
		image_path = p_path.strip_edges()
		pin_texture = p_tex
		if texture_rect: texture_rect.texture = p_tex


	func _build_visuals() -> void:
		center_vbox = VBoxContainer.new()
		center_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		center_vbox.add_theme_constant_override("separation", 4)
		center_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(center_vbox)

		var icon_container: CenterContainer = CenterContainer.new()
		icon_container.custom_minimum_size = Vector2(64.0, 64.0)
		icon_container.mouse_filter = Control.MOUSE_FILTER_PASS
		center_vbox.add_child(icon_container)

		texture_rect = TextureRect.new()
		texture_rect.texture = pin_texture
		texture_rect.custom_minimum_size = Vector2(64.0, 64.0)
		texture_rect.size = Vector2(64.0, 64.0)
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_container.add_child(texture_rect)

		label_node = Label.new()
		label_node.text = building_name
		label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label_node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label_node.add_theme_font_size_override("font_size", 11 if ThemeEngine.is_mobile_platform() else 10)
		label_node.add_theme_color_override("font_color", Color.WHITE)
		label_node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		label_node.add_theme_constant_override("shadow_offset_x", 1)
		label_node.add_theme_constant_override("shadow_offset_y", 1)
		label_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center_vbox.add_child(label_node)

		delete_btn = Button.new()
		delete_btn.custom_minimum_size = Vector2(28.0, 28.0)
		delete_btn.size = Vector2(28.0, 28.0)
		delete_btn.position = Vector2(70.0, -6.0)
		delete_btn.theme_type_variation = "DangerButton"
		delete_btn.focus_mode = Control.FOCUS_NONE
		delete_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		delete_btn.visible = false
		delete_btn.add_theme_constant_override("icon_max_width", 12)
		var del_icon: Texture2D = ThemeService.get_icon("icon_close")
		if del_icon: delete_btn.icon = del_icon
		else: delete_btn.text = "✕"
		delete_btn.pressed.connect(func() -> void: pin_deleted.emit(self))
		add_child(delete_btn)

		config_btn = Button.new()
		config_btn.custom_minimum_size = Vector2(28.0, 28.0)
		config_btn.size = Vector2(28.0, 28.0)
		config_btn.position = Vector2(-2.0, -6.0)
		config_btn.focus_mode = Control.FOCUS_NONE
		config_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		config_btn.visible = false
		config_btn.add_theme_constant_override("icon_max_width", 12)
		var cfg_icon: Texture2D = ThemeService.get_icon("icon_settings")
		if cfg_icon: config_btn.icon = cfg_icon
		else: config_btn.text = "•"
		config_btn.pressed.connect(func() -> void: pin_configure_requested.emit(self))
		add_child(config_btn)

		gui_input.connect(_on_pin_gui_input)


	func update_visuals() -> void:
		if label_node: label_node.text = building_name
		if texture_rect and pin_texture: texture_rect.texture = pin_texture


	func set_edit_mode(enabled: bool) -> void:
		if delete_btn: delete_btn.visible = enabled
		if config_btn: config_btn.visible = enabled


	func refresh_theme_icons() -> void:
		if delete_btn != null:
			var del_i: Texture2D = ThemeService.get_icon("icon_close")
			if del_i: delete_btn.icon = del_i
		if config_btn != null:
			var cfg_i: Texture2D = ThemeService.get_icon("icon_settings")
			if cfg_i: config_btn.icon = cfg_i


	func _on_pin_gui_input(event: InputEvent) -> void:
		if not map_controller: return
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					if map_controller.is_edit_mode:
						is_dragging = true
						drag_start_mouse = mb.global_position
						pin_start_pos = position
					else:
						pin_selected.emit(self)
				else:
					if is_dragging and map_controller.is_edit_mode:
						is_dragging = false
						map_controller.save_map_for_current_universe()
		elif event is InputEventMouseMotion and is_dragging and map_controller.is_edit_mode:
			position = pin_start_pos + (event.global_position - drag_start_mouse)
