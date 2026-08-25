# ==============================================================================
# OWNWORLD — WORLD MAP CONTROLLER
# File: res://Systems/WorldMapController.gd
# Base Class: CanvasLayer (class_name WorldMapController)
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
var pin_editor_panel: PanelContainer = null
var edit_title_lbl: Label = null
var edit_name_lbl: Label = null
var edit_room_lbl: Label = null
var edit_img_lbl: Label = null
var edit_name_input: LineEdit = null
var edit_room_input: LineEdit = null
var edit_image_option: OptionButton = null
var edit_preview_rect: TextureRect = null
var active_editing_pin: MapPin = null

var bg_select_dialog: FileDialog = null
var is_edit_mode: bool = false
var map_pins: Array[MapPin] = []

signal reset_all_rooms_requested()

const MAP_DIRECTORY: String = "user://maps/"
const SESSION_FILE: String = "user://session.json"

func _get_current_map_path() -> String:
	return MAP_DIRECTORY + SaveSystem.get_current_universe_id() + "_map.json"

func _request_room_transition(target_room_id: String) -> void:
	if target_room_id.is_empty():
		return
	EventBus.room_change_requested.emit(target_room_id, {})

func _set_global_time(preset_name: String) -> void:
	_set_atmosphere_state(preset_name.to_lower(), _get_current_atmosphere_weather())

func _set_global_weather(weather_name: String) -> void:
	_set_atmosphere_state(_get_current_atmosphere_time(), weather_name.to_lower())

func _get_current_atmosphere_time() -> String:
	var session: Dictionary = _load_session()
	return str(session.get("time_preset", "day"))

func _get_current_atmosphere_weather() -> String:
	var session: Dictionary = _load_session()
	return str(session.get("weather_preset", "none"))

func _set_atmosphere_state(time_preset: String, weather_preset: String) -> void:
	var session: Dictionary = _load_session()
	session["time_preset"] = time_preset
	session["weather_preset"] = weather_preset
	_save_session(session)
	EventBus.global_atmosphere_changed.emit(time_preset, weather_preset)

func _load_session() -> Dictionary:
	if not FileAccess.file_exists(SESSION_FILE):
		return {"universe_id": "default_universe", "universe_name": "Default Universe", "room_id": "room_main", "time_preset": "day", "weather_preset": "none"}
	var file: FileAccess = FileAccess.open(SESSION_FILE, FileAccess.READ)
	if file == null:
		return {"universe_id": "default_universe", "universe_name": "Default Universe", "room_id": "room_main", "time_preset": "day", "weather_preset": "none"}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {"universe_id": "default_universe", "universe_name": "Default Universe", "room_id": "room_main", "time_preset": "day", "weather_preset": "none"}

func _save_session(session: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(SESSION_FILE, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(session, "\t"))
		file.flush()
		file.close()

func _ready() -> void:
	name = "WorldMapController"
	layer = 110
	visible = false
	add_to_group("modal_ui")
	_build_map_ui()
	_build_pin_editor_dialog()
	_build_bg_file_dialog()
	_setup_keyboard_dodging()

	if not ThemeService.theme_changed.is_connected(_on_theme_changed):
		ThemeService.theme_changed.connect(_on_theme_changed)

func _setup_keyboard_dodging() -> void:
	var inputs: Array[LineEdit] = [edit_name_input, edit_room_input]
	for input in inputs:
		if input != null:
			input.focus_entered.connect(_on_input_focus_entered)
			input.focus_exited.connect(_on_input_focus_exited)

func _on_input_focus_entered() -> void:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		await get_tree().process_frame
		await get_tree().process_frame
		var kb_height: float = DisplayServer.virtual_keyboard_get_height()
		if kb_height > 0:
			var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(pin_editor_panel, "position:y", -kb_height * 0.4, 0.25)

func _on_input_focus_exited() -> void:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(pin_editor_panel, "position:y", 0.0, 0.25)

func _on_theme_changed(_theme_data: Dictionary) -> void:
	_refresh_existing_pin_icons()

func _refresh_existing_pin_icons() -> void:
	for pin: MapPin in map_pins:
		if is_instance_valid(pin): pin.refresh_theme_icons()

func _build_map_ui() -> void:
	map_root_panel = PanelContainer.new()
	map_root_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_root_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(map_root_panel)

	main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	main_vbox.add_theme_constant_override("separation", 0)
	map_root_panel.add_child(main_vbox)

	toolbar = PanelContainer.new()
	toolbar.theme_type_variation = "SubPanel"
	toolbar.custom_minimum_size = Vector2(0.0, 48.0)
	main_vbox.add_child(toolbar)

	var tb_margin: MarginContainer = MarginContainer.new()
	tb_margin.add_theme_constant_override("margin_left", 16)
	tb_margin.add_theme_constant_override("margin_right", 16)
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
	tb_hbox.add_child(title_lbl)

	var spacer_left: Control = Control.new()
	spacer_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb_hbox.add_child(spacer_left)

	var tb_tools_hbox: HBoxContainer = HBoxContainer.new()
	tb_tools_hbox.add_theme_constant_override("separation", 8)
	tb_hbox.add_child(tb_tools_hbox)

	var btn_mode: Button = Button.new()
	btn_mode.text = " Play"
	btn_mode.custom_minimum_size = Vector2(0.0, 32.0)
	btn_mode.focus_mode = Control.FOCUS_NONE
	btn_mode.add_theme_constant_override("icon_max_width", 14)
	var play_icon: Texture2D = ThemeService.get_icon("icon_play")
	if play_icon: btn_mode.icon = play_icon

	btn_mode.pressed.connect(func() -> void:
		is_edit_mode = not is_edit_mode
		btn_mode.text = " Edit" if is_edit_mode else " Play"
		var mode_icon: Texture2D = ThemeService.get_icon("icon_pencil" if is_edit_mode else "icon_play")
		if mode_icon: btn_mode.icon = mode_icon
		_update_pins_edit_mode()
		EventBus.notification_requested.emit("Mode: " + ("Edit Pins" if is_edit_mode else "Play Navigation"), true)
	)
	tb_tools_hbox.add_child(btn_mode)

	var btn_add_pin: Button = Button.new()
	btn_add_pin.text = " Pin"
	btn_add_pin.custom_minimum_size = Vector2(0.0, 32.0)
	btn_add_pin.focus_mode = Control.FOCUS_NONE
	btn_add_theme_icon(btn_add_pin, "icon_pin", "icon_anchors")
	btn_add_pin.pressed.connect(_on_add_pin_pressed)
	tb_tools_hbox.add_child(btn_add_pin)

	var btn_change_bg: Button = Button.new()
	btn_change_bg.text = " Map Art"
	btn_change_bg.custom_minimum_size = Vector2(0.0, 32.0)
	btn_change_bg.focus_mode = Control.FOCUS_NONE
	btn_add_theme_icon(btn_change_bg, "icon_brush", "icon_palette")
	btn_change_bg.pressed.connect(_on_change_bg_pressed)
	tb_tools_hbox.add_child(btn_change_bg)

	var btn_reset: Button = Button.new()
	btn_reset.text = " Reset Rooms"
	btn_reset.theme_type_variation = "DangerButton"
	btn_reset.custom_minimum_size = Vector2(0.0, 32.0)
	btn_reset.focus_mode = Control.FOCUS_NONE
	btn_reset.add_theme_constant_override("icon_max_width", 14)
	var ref_icon: Texture2D = ThemeService.get_icon("icon_refresh")
	if ref_icon: btn_reset.icon = ref_icon
	btn_reset.pressed.connect(_on_reset_rooms_pressed)
	tb_tools_hbox.add_child(btn_reset)

	var spacer_right: Control = Control.new()
	spacer_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb_hbox.add_child(spacer_right)

	var btn_close: Button = Button.new()
	btn_close.text = " Close"
	btn_close.custom_minimum_size = Vector2(0.0, 32.0)
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.add_theme_constant_override("icon_max_width", 12)
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
	empty_hint_label.text = "Blank Map Canvas\nPlace custom map images into Documents/OwnWorld/Art to select."
	empty_hint_label.theme_type_variation = "HintLabel"
	empty_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_hint_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	empty_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_display.add_child(empty_hint_label)

	pins_container = Control.new()
	pins_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	pins_container.mouse_filter = Control.MOUSE_FILTER_PASS
	map_display.add_child(pins_container)

	_build_atmosphere_control_bar(main_vbox)

func btn_add_theme_icon(btn: Button, primary_icon: String, fallback_icon: String) -> void:
	btn.add_theme_constant_override("icon_max_width", 14)
	var icon: Texture2D = ThemeService.get_icon(primary_icon)
	if not icon: icon = ThemeService.get_icon(fallback_icon)
	if icon: btn.icon = icon

func _build_atmosphere_control_bar(parent_vbox: VBoxContainer) -> void:
	atmo_panel = PanelContainer.new()
	atmo_panel.theme_type_variation = "SubPanel"
	atmo_panel.custom_minimum_size = Vector2(0.0, 44.0)
	parent_vbox.add_child(atmo_panel)

	var atmo_margin: MarginContainer = MarginContainer.new()
	atmo_margin.add_theme_constant_override("margin_left", 16)
	atmo_margin.add_theme_constant_override("margin_right", 16)
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
	hbox.add_child(lbl_time)

	var times: Array[Dictionary] = [
		{"name": "Day", "icon": "icon_sun"}, {"name": "Sunset", "icon": "icon_sunset"},
		{"name": "Night", "icon": "icon_night"}, {"name": "Cozy", "icon": "icon_cozy"}
	]
	for t_data: Dictionary in times:
		var btn: Button = Button.new()
		btn.text = " " + str(t_data["name"])
		btn.custom_minimum_size = Vector2(0.0, 28.0)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_constant_override("icon_max_width", 14)
		btn.add_theme_font_size_override("font_size", 10)
		var t_icon: Texture2D = ThemeService.get_icon(str(t_data["icon"]))
		if t_icon: btn.icon = t_icon
		var cap_t: String = str(t_data["name"])
		btn.pressed.connect(func() -> void:
			_set_global_time(cap_t)
			EventBus.notification_requested.emit("Mood: " + cap_t, true)
		)
		hbox.add_child(btn)

	hbox.add_child(VSeparator.new())

	var lbl_weather: Label = Label.new()
	lbl_weather.text = "Weather:"
	lbl_weather.theme_type_variation = "HintLabel"
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
		btn.custom_minimum_size = Vector2(0.0, 28.0)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_constant_override("icon_max_width", 14)
		btn.add_theme_font_size_override("font_size", 10)
		var w_icon: Texture2D = ThemeService.get_icon(str(w_data["icon"]))
		if w_icon: btn.icon = w_icon
		var w_name: String = str(w_data["name"])
		var w_lbl: String = str(w_data["label"])
		btn.pressed.connect(func() -> void:
			_set_global_weather(w_name)
			EventBus.notification_requested.emit("Weather: " + w_lbl, true)
		)
		hbox.add_child(btn)

func _build_pin_editor_dialog() -> void:
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

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	modal_backdrop.add_child(center)

	pin_editor_panel = PanelContainer.new()
	pin_editor_panel.custom_minimum_size = Vector2(420.0, 380.0)
	pin_editor_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(pin_editor_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	pin_editor_panel.add_child(vbox)

	edit_title_lbl = Label.new()
	edit_title_lbl.text = "Configure Location Pin"
	edit_title_lbl.theme_type_variation = "HeaderLabel"
	edit_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(edit_title_lbl)

	vbox.add_child(HSeparator.new())

	var name_box: VBoxContainer = VBoxContainer.new()
	name_box.add_theme_constant_override("separation", 3)
	vbox.add_child(name_box)

	edit_name_lbl = Label.new()
	edit_name_lbl.text = "Location Name:"
	edit_name_lbl.theme_type_variation = "HintLabel"
	name_box.add_child(edit_name_lbl)

	edit_name_input = LineEdit.new()
	edit_name_input.placeholder_text = "e.g. Noodle Bar, Magic Guild..."
	edit_name_input.custom_minimum_size = Vector2(0.0, 32.0)
	name_box.add_child(edit_name_input)

	var room_box: VBoxContainer = VBoxContainer.new()
	room_box.add_theme_constant_override("separation", 3)
	vbox.add_child(room_box)

	edit_room_lbl = Label.new()
	edit_room_lbl.text = "Destination Room ID:"
	edit_room_lbl.theme_type_variation = "HintLabel"
	room_box.add_child(edit_room_lbl)

	edit_room_input = LineEdit.new()
	edit_room_input.placeholder_text = "e.g. room_noodle_bar"
	edit_room_input.custom_minimum_size = Vector2(0.0, 32.0)
	room_box.add_child(edit_room_input)

	var img_section: VBoxContainer = VBoxContainer.new()
	img_section.add_theme_constant_override("separation", 3)
	vbox.add_child(img_section)

	edit_img_lbl = Label.new()
	edit_img_lbl.text = "Pin Icon / Graphic:"
	edit_img_lbl.theme_type_variation = "HintLabel"
	img_section.add_child(edit_img_lbl)

	var img_hbox: HBoxContainer = HBoxContainer.new()
	img_hbox.add_theme_constant_override("separation", 10)
	img_section.add_child(img_hbox)

	var prev_card: PanelContainer = PanelContainer.new()
	prev_card.theme_type_variation = "SubPanel"
	prev_card.custom_minimum_size = Vector2(42.0, 42.0)
	prev_card.clip_contents = true
	img_hbox.add_child(prev_card)

	edit_preview_rect = TextureRect.new()
	edit_preview_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	edit_preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	edit_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prev_card.add_child(edit_preview_rect)

	edit_image_option = OptionButton.new()
	edit_image_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_image_option.custom_minimum_size = Vector2(0.0, 32.0)
	_enforce_dropdown_popup_limits(edit_image_option, 200)
	edit_image_option.item_selected.connect(_on_image_option_selected)
	img_hbox.add_child(edit_image_option)

	vbox.add_child(HSeparator.new())

	var btn_save: Button = Button.new()
	btn_save.text = " Save Pin"
	btn_save.custom_minimum_size = Vector2(0.0, 36.0)
	btn_save.focus_mode = Control.FOCUS_NONE
	btn_save.add_theme_constant_override("icon_max_width", 16)
	var s_icon: Texture2D = ThemeService.get_icon("icon_save")
	if s_icon: btn_save.icon = s_icon
	btn_save.pressed.connect(_on_save_pin_editor_pressed)
	vbox.add_child(btn_save)

func _enforce_dropdown_popup_limits(opt_btn: OptionButton, max_height: int = 200) -> void:
	if not is_instance_valid(opt_btn): return
	var pop: PopupMenu = opt_btn.get_popup()
	if pop:
		pop.max_size = Vector2i(4000, max_height)
		pop.about_to_popup.connect(func() -> void: pop.max_size = Vector2i(4000, max_height))

func open_pin_editor(pin: MapPin) -> void:
	active_editing_pin = pin
	edit_name_input.text = pin.location_name
	edit_room_input.text = pin.target_room_id

	edit_image_option.clear()
	edit_image_option.add_item("(Default Pin Icon)", 0)

	var art_files: Array[Dictionary] = UGCManager.scan_user_art_library()
	var selected_idx: int = 0
	for i: int in range(art_files.size()):
		var art_data: Dictionary = art_files[i]
		var a_name: String = str(art_data.get("name", "Art"))
		var a_path: String = str(art_data.get("file_path", ""))
		edit_image_option.add_item(a_name, i + 1)
		if a_path == pin.image_path: selected_idx = i + 1

	edit_image_option.selected = selected_idx
	_update_editor_preview(pin.pin_texture)
	modal_backdrop.visible = true

func _update_editor_preview(tex: Texture2D) -> void:
	edit_preview_rect.texture = tex

func _on_image_option_selected(idx: int) -> void:
	if idx == 0:
		_update_editor_preview(UGCManager.create_blank_starter_graphic(Vector2(64.0, 64.0), Color("#0284c7")))
	else:
		var art_files: Array[Dictionary] = UGCManager.scan_user_art_library()
		var chosen: Dictionary = art_files[idx - 1]
		var fpath: String = str(chosen.get("file_path", ""))
		_update_editor_preview(UGCManager.get_thumbnail_async(fpath, 128))

func _on_save_pin_editor_pressed() -> void:
	if active_editing_pin and is_instance_valid(active_editing_pin):
		active_editing_pin.location_name = edit_name_input.text.strip_edges() if edit_name_input.text.strip_edges() != "" else "Location"
		active_editing_pin.target_room_id = edit_room_input.text.strip_edges() if edit_room_input.text.strip_edges() != "" else "room_main"

		var sel_idx: int = edit_image_option.selected
		if sel_idx == 0:
			active_editing_pin.image_path = ""
			active_editing_pin.set_pin_image("", UGCManager.create_blank_starter_graphic(Vector2(64.0, 64.0), Color("#0284c7")))
		else:
			var art_files: Array[Dictionary] = UGCManager.scan_user_art_library()
			var chosen: Dictionary = art_files[sel_idx - 1]
			var fpath: String = str(chosen.get("file_path", ""))
			active_editing_pin.set_pin_image(fpath, UGCManager.get_thumbnail_async(fpath, 128))

		active_editing_pin.update_visuals()
		save_map_for_current_universe()
		EventBus.notification_requested.emit("Saved: " + active_editing_pin.location_name, true)

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
	bg_select_dialog.theme = ThemeService.create_theme()
	bg_select_dialog.current_dir = UGCManager.get_art_root_directory()
	bg_select_dialog.popup_centered_ratio(0.7)

func _on_bg_file_selected(fpath: String) -> void:
	if FileAccess.file_exists(fpath):
		current_bg_image_path = fpath
		map_background_rect.texture = UGCManager.load_texture_from_file(fpath)
		empty_hint_label.visible = false
		save_map_for_current_universe()

func _update_pins_edit_mode() -> void:
	for pin: MapPin in map_pins:
		if is_instance_valid(pin): pin.set_edit_mode(is_edit_mode)

func load_map_for_current_universe() -> void:
	if title_lbl: title_lbl.text = SaveSystem.get_current_universe_name().to_upper()
	for child: Node in pins_container.get_children(): child.queue_free()
	map_pins.clear()

	var map_file_path: String = _get_current_map_path()
	if FileAccess.file_exists(map_file_path):
		var f: FileAccess = FileAccess.open(map_file_path, FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed is Dictionary:
				current_bg_image_path = str(parsed.get("bg_image_path", ""))
				if current_bg_image_path != "" and FileAccess.file_exists(current_bg_image_path):
					map_background_rect.texture = UGCManager.load_texture_from_file(current_bg_image_path)
					empty_hint_label.visible = false
				else:
					map_background_rect.texture = null
					empty_hint_label.visible = true

				var pins_data: Array = parsed.get("pins", [])
				for p_dict_var: Variant in pins_data:
					if not (p_dict_var is Dictionary): continue
					var p_dict: Dictionary = p_dict_var as Dictionary
					var p_name: String = str(p_dict.get("name", "Location"))
					var p_room: String = str(p_dict.get("room_id", "room_main"))
					var p_img_path: String = str(p_dict.get("image_path", ""))
					var p_pos: Vector2 = Vector2(float(p_dict.get("x", 400.0)), float(p_dict.get("y", 200.0)))
					var tex: Texture2D = UGCManager.get_thumbnail_async(p_img_path, 128) if (p_img_path != "" and FileAccess.file_exists(p_img_path)) else UGCManager.create_blank_starter_graphic(Vector2(64.0, 64.0), Color("#0284c7"))
					create_pin(p_name, p_room, p_pos, p_img_path, tex)
				_update_pins_edit_mode()
				return

	current_bg_image_path = ""
	map_background_rect.texture = null
	empty_hint_label.visible = true
	create_pin(SaveSystem.get_current_universe_name() + " Main", "room_main", Vector2(400.0, 200.0))
	_update_pins_edit_mode()
	save_map_for_current_universe()

func save_map_for_current_universe() -> void:
	var pins_data: Array[Dictionary] = []
	for pin: MapPin in map_pins:
		if is_instance_valid(pin):
			pins_data.append({
				"name": pin.location_name, "room_id": pin.target_room_id,
				"image_path": pin.image_path, "x": pin.position.x, "y": pin.position.y
			})

	var map_payload: Dictionary = {
		"universe_id": SaveSystem.get_current_universe_id(),
		"universe_name": SaveSystem.get_current_universe_name(),
		"bg_image_path": current_bg_image_path,
		"pins": pins_data
	}
	var f: FileAccess = FileAccess.open(_get_current_map_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(map_payload, "\t"))
		f.close()

func create_pin(loc_name: String, target_room: String, pos: Vector2, img_path: String = "", tex: Texture2D = null) -> MapPin:
	var pin: MapPin = MapPin.new()
	var final_tex: Texture2D = tex if tex != null else UGCManager.create_blank_starter_graphic(Vector2(64.0, 64.0), Color("#0284c7"))
	pin.setup(loc_name, target_room, pos, img_path, final_tex, self)
	pin.pin_selected.connect(_on_pin_selected)
	pin.pin_deleted.connect(_on_pin_deleted)
	pin.pin_configure_requested.connect(open_pin_editor)
	pins_container.add_child(pin)
	map_pins.append(pin)
	return pin

func _on_add_pin_pressed() -> void:
	var count: int = map_pins.size() + 1
	var new_pin: MapPin = create_pin("Location " + str(count), "room_" + str(count), Vector2(250.0 + float(count * 40), 160.0))
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
	if not is_edit_mode:
		close_map()
		_request_room_transition(pin.target_room_id)

func _build_bg_file_dialog() -> void:
	bg_select_dialog = FileDialog.new()
	bg_select_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	bg_select_dialog.access = FileDialog.ACCESS_FILESYSTEM
	bg_select_dialog.use_native_dialog = true
	bg_select_dialog.filters = ["*.png, *.jpg, *.jpeg, *.webp ; Image Files"]
	bg_select_dialog.min_size = Vector2i(760, 480)
	bg_select_dialog.current_dir = UGCManager.get_art_root_directory()
	bg_select_dialog.file_selected.connect(_on_bg_file_selected)
	add_child(bg_select_dialog)

class MapPin extends Control:
	var location_name: String = ""
	var target_room_id: String = ""
	var image_path: String = ""
	var pin_texture: Texture2D = null

	var is_dragging: bool = false
	var drag_start_mouse: Vector2 = Vector2.ZERO
	var pin_start_pos: Vector2 = Vector2.ZERO

	var map_controller: WorldMapController = null
	var img_panel: PanelContainer = null
	var texture_rect: TextureRect = null
	var label_node: Label = null
	var delete_btn: Button = null
	var config_btn: Button = null

	signal pin_selected(pin: MapPin)
	signal pin_deleted(pin: MapPin)
	signal pin_configure_requested(pin: MapPin)

	func setup(p_name: String, p_room: String, p_pos: Vector2, p_img_path: String, p_tex: Texture2D, controller_ref: WorldMapController) -> void:
		location_name = p_name
		target_room_id = p_room
		position = p_pos
		image_path = p_img_path
		pin_texture = p_tex
		map_controller = controller_ref

		custom_minimum_size = Vector2(80.0, 90.0)
		size = Vector2(80.0, 90.0)
		mouse_filter = Control.MOUSE_FILTER_PASS
		_build_visuals()

	func set_pin_image(p_path: String, p_tex: Texture2D) -> void:
		image_path = p_path
		pin_texture = p_tex
		if texture_rect: texture_rect.texture = p_tex

	func _build_visuals() -> void:
		img_panel = PanelContainer.new()
		img_panel.theme_type_variation = "SubPanel"
		img_panel.custom_minimum_size = Vector2(56.0, 56.0)
		img_panel.size = Vector2(56.0, 56.0)
		img_panel.position = Vector2(12.0, 0.0)
		img_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(img_panel)

		texture_rect = TextureRect.new()
		texture_rect.texture = pin_texture
		texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img_panel.add_child(texture_rect)

		var lbl_panel: PanelContainer = PanelContainer.new()
		lbl_panel.theme_type_variation = "SubPanel"
		lbl_panel.position = Vector2(-15.0, 60.0)
		lbl_panel.custom_minimum_size = Vector2(110.0, 20.0)
		lbl_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lbl_panel)

		label_node = Label.new()
		label_node.text = location_name
		label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label_node.add_theme_font_size_override("font_size", 10)
		label_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl_panel.add_child(label_node)

		delete_btn = Button.new()
		delete_btn.custom_minimum_size = Vector2(20.0, 20.0)
		delete_btn.size = Vector2(20.0, 20.0)
		delete_btn.position = Vector2(58.0, -6.0)
		delete_btn.theme_type_variation = "DangerButton"
		delete_btn.focus_mode = Control.FOCUS_NONE
		delete_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		delete_btn.visible = false
		delete_btn.add_theme_constant_override("icon_max_width", 10)
		var del_icon: Texture2D = ThemeService.get_icon("icon_close")
		if del_icon: delete_btn.icon = del_icon
		else: delete_btn.text = "✕"
		delete_btn.pressed.connect(func() -> void: pin_deleted.emit(self))
		add_child(delete_btn)

		config_btn = Button.new()
		config_btn.custom_minimum_size = Vector2(20.0, 20.0)
		config_btn.size = Vector2(20.0, 20.0)
		config_btn.position = Vector2(2.0, -6.0)
		config_btn.focus_mode = Control.FOCUS_NONE
		config_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		config_btn.visible = false
		config_btn.add_theme_constant_override("icon_max_width", 10)
		var cfg_icon: Texture2D = ThemeService.get_icon("icon_settings")
		if cfg_icon: config_btn.icon = cfg_icon
		else: config_btn.text = "•"
		config_btn.pressed.connect(func() -> void: pin_configure_requested.emit(self))
		add_child(config_btn)

		gui_input.connect(_on_pin_gui_input)

	func update_visuals() -> void:
		if label_node: label_node.text = location_name
		if texture_rect and pin_texture: texture_rect.texture = pin_texture

	func set_edit_mode(enabled: bool) -> void:
		if delete_btn: delete_btn.visible = enabled
		if config_btn: config_btn.visible = enabled

	func refresh_theme_icons() -> void:
		if delete_btn != null:
			var refreshed_delete_icon: Texture2D = ThemeService.get_icon("icon_close")
			if refreshed_delete_icon != null: delete_btn.icon = refreshed_delete_icon
		if config_btn != null:
			var refreshed_config_icon: Texture2D = ThemeService.get_icon("icon_settings")
			if refreshed_config_icon != null: config_btn.icon = refreshed_config_icon

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
