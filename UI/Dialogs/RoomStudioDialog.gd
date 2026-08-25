# ==============================================================================
# OWNWORLD — ROOM & MULTI-SLICE EXPANSION STUDIO
# File: res://UI/Dialogs/RoomStudioDialog.gd
# Base Class: CanvasLayer (class_name RoomStudioDialog)
# ==============================================================================

class_name RoomStudioDialog
extends CanvasLayer

const MAX_SLICES: int = 10
const MAX_PANEL_WIDTH: float = 580.0
const MAX_PANEL_HEIGHT: float = 640.0

var root_backdrop: Control = null
var center_container: CenterContainer = null
var root_panel: PanelContainer = null

var header_lbl: Label = null
var room_name_edit: LineEdit = null

# Slice Expansion Controls
var slices_tab_container: HBoxContainer = null
var btn_add_slice: Button = null
var btn_remove_slice: Button = null
var current_selected_slice_idx: int = 0
var room_slices: Array[Dictionary] = []

# Active Slice Environment (Indoor vs Outdoor)
var opt_slice_environment: OptionButton = null
var slice_env_hint: Label = null

# Floor Baseline
var floor_slider: HSlider = null
var floor_val_lbl: Label = null
var check_show_floor_line: CheckBox = null

# Per-slice Wallpaper Controls
var art_option: OptionButton = null
var fill_mode_option: OptionButton = null
var preview_panel: PanelContainer = null
var preview_rect: TextureRect = null
var slice_status_lbl: Label = null

var btn_apply: Button = null
var btn_clear_slice: Button = null

var art_library: Array[Dictionary] = []

const FILL_MODES: Array[Dictionary] = [
	{"id": "cover", "label": "Fill / Cover (Aspect Cover)", "stretch": TextureRect.STRETCH_KEEP_ASPECT_COVERED},
	{"id": "fit", "label": "Fit / Center (Aspect Fit)", "stretch": TextureRect.STRETCH_KEEP_ASPECT_CENTERED},
	{"id": "stretch", "label": "Stretch (Fill Slice)", "stretch": TextureRect.STRETCH_SCALE},
	{"id": "tile", "label": "Tile / Pattern Repeat", "stretch": TextureRect.STRETCH_TILE},
	{"id": "original", "label": "1:1 Original Pixels", "stretch": TextureRect.STRETCH_KEEP_CENTERED}
]

signal room_configured(slices_data: Array[Dictionary], floor_y: float, room_title: String)
signal floor_preview_changed(floor_y: float, p_visible: bool)


func _ready() -> void:
	name = "RoomStudioDialog"
	layer = 120
	visible = false
	add_to_group("modal_ui")
	_build_ui()
	_connect_system_signals()
	_update_responsive_layout()
	_setup_keyboard_dodging()


func _connect_system_signals() -> void:
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null and not tree.root.size_changed.is_connected(_update_responsive_layout):
		tree.root.size_changed.connect(_update_responsive_layout)
	if not EventBus.theme_changed.is_connected(_on_theme_changed):
		EventBus.theme_changed.connect(_on_theme_changed)


func _setup_keyboard_dodging() -> void:
	if room_name_edit != null:
		room_name_edit.focus_entered.connect(_on_input_focus_entered)
		room_name_edit.focus_exited.connect(_on_input_focus_exited)


func _on_input_focus_entered() -> void:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		await get_tree().process_frame
		await get_tree().process_frame
		var kb_height: float = DisplayServer.virtual_keyboard_get_height()
		if kb_height > 0:
			var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(center_container, "position:y", -kb_height * 0.4, 0.25)


func _on_input_focus_exited() -> void:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(center_container, "position:y", 0.0, 0.25)


func _on_theme_changed(_theme_data: Dictionary) -> void:
	_refresh_theme_icons()
	_update_responsive_layout()
	_render_slice_tabs()


func _update_responsive_layout() -> void:
	if not is_instance_valid(root_panel): return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280.0, 720.0)
	var target_width: float = clampf(viewport_size.x * 0.92, 280.0, MAX_PANEL_WIDTH)
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
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(header_hbox)

	header_lbl = Label.new()
	header_lbl.text = "Room Expansion & Layout Studio"
	header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_lbl.theme_type_variation = "HeaderLabel"
	header_lbl.add_theme_font_size_override("font_size", 14)
	header_hbox.add_child(header_lbl)

	var close_button: Button = Button.new()
	close_button.custom_minimum_size = Vector2(26.0, 26.0)
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

	# Name
	var name_box: VBoxContainer = VBoxContainer.new()
	name_box.add_theme_constant_override("separation", 3)
	form_vbox.add_child(name_box)

	var lbl_name: Label = Label.new()
	lbl_name.text = "Room Name / Label:"
	lbl_name.theme_type_variation = "HintLabel"
	name_box.add_child(lbl_name)

	room_name_edit = LineEdit.new()
	room_name_edit.placeholder_text = "e.g. Mansion Hall, Living Room & Patio..."
	room_name_edit.custom_minimum_size = Vector2(0.0, 32.0)
	name_box.add_child(room_name_edit)

	# Slices Expansion Bar
	var slices_card: PanelContainer = PanelContainer.new()
	slices_card.theme_type_variation = "SubPanel"
	form_vbox.add_child(slices_card)

	var slices_vbox: VBoxContainer = VBoxContainer.new()
	slices_vbox.add_theme_constant_override("separation", 6)
	slices_card.add_child(slices_vbox)

	var sec_hdr: HBoxContainer = HBoxContainer.new()
	slices_vbox.add_child(sec_hdr)

	var lbl_sec: Label = Label.new()
	lbl_sec.text = "Room Slices (1 Slice = 1 Device Screen Width):"
	lbl_sec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_sec.theme_type_variation = "HeaderLabel"
	sec_hdr.add_child(lbl_sec)

	var slice_scroll: ScrollContainer = ScrollContainer.new()
	slice_scroll.custom_minimum_size = Vector2(0.0, 36.0)
	slice_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	slice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	slice_scroll.follow_focus = false
	slices_vbox.add_child(slice_scroll)

	slices_tab_container = HBoxContainer.new()
	slices_tab_container.add_theme_constant_override("separation", 6)
	slice_scroll.add_child(slices_tab_container)

	var slice_actions_hbox: HBoxContainer = HBoxContainer.new()
	slice_actions_hbox.add_theme_constant_override("separation", 8)
	slices_vbox.add_child(slice_actions_hbox)

	btn_add_slice = Button.new()
	btn_add_slice.text = " + Add Room Slice"
	btn_add_slice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_add_slice.custom_minimum_size = Vector2(0.0, 30.0)
	btn_add_slice.focus_mode = Control.FOCUS_NONE
	btn_add_slice.pressed.connect(_on_add_slice_pressed)
	slice_actions_hbox.add_child(btn_add_slice)

	btn_remove_slice = Button.new()
	btn_remove_slice.text = " Remove Slice"
	btn_remove_slice.theme_type_variation = "DangerButton"
	btn_remove_slice.custom_minimum_size = Vector2(0.0, 30.0)
	btn_remove_slice.focus_mode = Control.FOCUS_NONE
	btn_remove_slice.pressed.connect(_on_remove_slice_pressed)
	slice_actions_hbox.add_child(btn_remove_slice)

	# Active Slice Environment: Indoor vs Outdoor
	var env_card: PanelContainer = PanelContainer.new()
	env_card.theme_type_variation = "SubPanel"
	form_vbox.add_child(env_card)

	var env_vbox: VBoxContainer = VBoxContainer.new()
	env_vbox.add_theme_constant_override("separation", 4)
	env_card.add_child(env_vbox)

	var env_hdr_hbox: HBoxContainer = HBoxContainer.new()
	env_hdr_hbox.add_theme_constant_override("separation", 8)
	env_vbox.add_child(env_hdr_hbox)

	var lbl_env: Label = Label.new()
	lbl_env.text = "Slice Environment:"
	lbl_env.theme_type_variation = "HeaderLabel"
	lbl_env.custom_minimum_size = Vector2(130.0, 0.0)
	env_hdr_hbox.add_child(lbl_env)

	opt_slice_environment = OptionButton.new()
	opt_slice_environment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt_slice_environment.custom_minimum_size = Vector2(0.0, 32.0)
	_add_icon_option(opt_slice_environment, "icon_room", "🏠 Indoors (Weather precipitation blocked)", 0)
	_add_icon_option(opt_slice_environment, "icon_sun", "🌳 Outdoors (Rain/snow falls on this slice)", 1)
	opt_slice_environment.item_selected.connect(_on_slice_environment_selected)
	env_hdr_hbox.add_child(opt_slice_environment)

	slice_env_hint = Label.new()
	slice_env_hint.text = "Indoors: Weather rain/snow will not fall inside this slice."
	slice_env_hint.theme_type_variation = "HintLabel"
	slice_env_hint.add_theme_font_size_override("font_size", 10)
	env_vbox.add_child(slice_env_hint)

	# Floor Baseline Slider
	var floor_card: PanelContainer = PanelContainer.new()
	floor_card.theme_type_variation = "SubPanel"
	form_vbox.add_child(floor_card)

	var floor_box: VBoxContainer = VBoxContainer.new()
	floor_box.add_theme_constant_override("separation", 6)
	floor_card.add_child(floor_box)

	var floor_header: HBoxContainer = HBoxContainer.new()
	floor_box.add_child(floor_header)

	var lbl_floor: Label = Label.new()
	lbl_floor.text = "Floor Baseline (Walk Level Across All Slices):"
	lbl_floor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_floor.theme_type_variation = "HeaderLabel"
	floor_header.add_child(lbl_floor)

	floor_val_lbl = Label.new()
	floor_val_lbl.text = "580 px"
	floor_val_lbl.theme_type_variation = "HintLabel"
	floor_header.add_child(floor_val_lbl)

	floor_slider = HSlider.new()
	floor_slider.min_value = 200.0
	floor_slider.max_value = 700.0
	floor_slider.step = 5.0
	floor_slider.value = 580.0
	floor_slider.custom_minimum_size = Vector2(0.0, 24.0)
	floor_slider.value_changed.connect(_on_floor_slider_changed)
	floor_box.add_child(floor_slider)

	check_show_floor_line = CheckBox.new()
	check_show_floor_line.text = " Show Floor Guide Line"
	check_show_floor_line.button_pressed = true
	check_show_floor_line.custom_minimum_size = Vector2(0.0, 28.0)
	_apply_checkbox_icon(check_show_floor_line, "icon_floor")
	check_show_floor_line.toggled.connect(func(is_toggled: bool) -> void: floor_preview_changed.emit(floor_slider.value, is_toggled))
	floor_box.add_child(check_show_floor_line)

	# Active Slice Artwork Selector
	var wall_box: VBoxContainer = VBoxContainer.new()
	wall_box.add_theme_constant_override("separation", 3)
	form_vbox.add_child(wall_box)

	slice_status_lbl = Label.new()
	slice_status_lbl.text = "Slice Artwork (Leave empty for procedural wall/floor):"
	slice_status_lbl.theme_type_variation = "HintLabel"
	wall_box.add_child(slice_status_lbl)

	art_option = OptionButton.new()
	art_option.custom_minimum_size = Vector2(0.0, 32.0)
	_enforce_dropdown_popup_limits(art_option, 200)
	art_option.item_selected.connect(_on_art_selected)
	wall_box.add_child(art_option)

	var fill_box: VBoxContainer = VBoxContainer.new()
	fill_box.add_theme_constant_override("separation", 3)
	form_vbox.add_child(fill_box)

	var lbl_fill: Label = Label.new()
	lbl_fill.text = "Slice Artwork Scaling:"
	lbl_fill.theme_type_variation = "HintLabel"
	fill_box.add_child(lbl_fill)

	fill_mode_option = OptionButton.new()
	fill_mode_option.custom_minimum_size = Vector2(0.0, 32.0)
	_enforce_dropdown_popup_limits(fill_mode_option, 200)
	for index: int in range(FILL_MODES.size()):
		fill_mode_option.add_item(str(FILL_MODES[index]["label"]), index)
	fill_mode_option.item_selected.connect(_on_fill_mode_selected)
	fill_box.add_child(fill_mode_option)

	preview_panel = PanelContainer.new()
	preview_panel.theme_type_variation = "SubPanel"
	preview_panel.custom_minimum_size = Vector2(0.0, 85.0)
	preview_panel.clip_contents = true
	form_vbox.add_child(preview_panel)

	preview_rect = TextureRect.new()
	preview_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.add_child(preview_rect)

	main_vbox.add_child(HSeparator.new())

	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 10)
	main_vbox.add_child(button_row)

	btn_apply = Button.new()
	btn_apply.text = " Apply & Save Room Layout"
	btn_apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_apply.custom_minimum_size = Vector2(0.0, 36.0)
	btn_apply.focus_mode = Control.FOCUS_NONE
	btn_apply.add_theme_constant_override("icon_max_width", 16)
	_apply_button_icon(btn_apply, "icon_save")
	btn_apply.pressed.connect(_on_save_pressed)
	button_row.add_child(btn_apply)

	btn_clear_slice = Button.new()
	btn_clear_slice.text = " Revert Slice to Wall"
	btn_clear_slice.theme_type_variation = "DangerButton"
	btn_clear_slice.custom_minimum_size = Vector2(160.0, 36.0)
	btn_clear_slice.focus_mode = Control.FOCUS_NONE
	btn_clear_slice.add_theme_constant_override("icon_max_width", 16)
	_apply_button_icon(btn_clear_slice, "icon_delete")
	btn_clear_slice.pressed.connect(_on_clear_slice_wallpaper_pressed)
	button_row.add_child(btn_clear_slice)


func _enforce_dropdown_popup_limits(option_button: OptionButton, max_height: int = 200) -> void:
	if option_button == null: return
	var popup: PopupMenu = option_button.get_popup()
	if popup == null: return
	popup.max_size = Vector2i(4000, max_height)
	popup.about_to_popup.connect(func() -> void: popup.max_size = Vector2i(4000, max_height))


func open_studio(current_room_title: String, current_floor_y: float, current_slices_data: Array[Dictionary]) -> void:
	art_library = UGCManager.scan_user_art_library()
	room_name_edit.text = current_room_title
	floor_slider.value = current_floor_y
	floor_val_lbl.text = "%d px" % int(current_floor_y)
	check_show_floor_line.button_pressed = true

	room_slices = current_slices_data.duplicate(true)
	if room_slices.is_empty():
		room_slices.append({"wallpaper_path": "", "fill_mode": "cover", "is_outdoor": false})

	current_selected_slice_idx = 0
	_update_responsive_layout()
	_render_slice_tabs()
	_sync_active_slice_controls()

	floor_preview_changed.emit(current_floor_y, true)
	visible = true


func close_dialog() -> void:
	if floor_slider != null: floor_preview_changed.emit(floor_slider.value, false)
	visible = false


func _render_slice_tabs() -> void:
	if slices_tab_container == null: return
	for child: Node in slices_tab_container.get_children():
		child.queue_free()

	var c_accent: Color = ThemeService.get_color("accent_primary", "#db2777")
	var rad: int = ThemeService.get_corner_radius()

	for i: int in range(room_slices.size()):
		var is_selected: bool = (i == current_selected_slice_idx)
		var is_outdoor: bool = bool(room_slices[i].get("is_outdoor", false))
		var has_art: bool = not str(room_slices[i].get("wallpaper_path", "")).is_empty()

		var env_tag: String = " (🌳)" if is_outdoor else " (🏠)"
		var art_tag: String = " 🖼️" if has_art else ""
		var btn: Button = Button.new()
		btn.text = " Slice %d%s%s " % [(i + 1), env_tag, art_tag]
		btn.custom_minimum_size = Vector2(0.0, 30.0)
		btn.focus_mode = Control.FOCUS_NONE
		btn.theme_type_variation = "Breadcrumb"
		btn.add_theme_font_size_override("font_size", 10)

		if is_selected:
			var s_act: StyleBoxFlat = StyleBoxFlat.new()
			s_act.bg_color = c_accent
			s_act.border_color = c_accent
			s_act.set_border_width_all(1)
			s_act.set_corner_radius_all(rad)
			s_act.content_margin_left = 10
			s_act.content_margin_right = 10
			btn.add_theme_stylebox_override("normal", s_act)
			btn.add_theme_stylebox_override("hover", s_act)
			btn.add_theme_color_override("font_color", Color.WHITE)

		var target_idx: int = i
		btn.pressed.connect(func() -> void:
			current_selected_slice_idx = target_idx
			_render_slice_tabs()
			_sync_active_slice_controls()
		)
		slices_tab_container.add_child(btn)

	btn_remove_slice.disabled = (room_slices.size() <= 1)


func _on_add_slice_pressed() -> void:
	if room_slices.size() >= MAX_SLICES:
		EventBus.notification_requested.emit("Max room length reached (%d slices)" % MAX_SLICES, true)
		return
	room_slices.append({"wallpaper_path": "", "fill_mode": "cover", "is_outdoor": false})
	current_selected_slice_idx = room_slices.size() - 1
	_render_slice_tabs()
	_sync_active_slice_controls()
	EventBus.notification_requested.emit("Added Slice %d (Screen %d)" % [room_slices.size(), room_slices.size()], true)


func _on_remove_slice_pressed() -> void:
	if room_slices.size() <= 1:
		return
	room_slices.remove_at(current_selected_slice_idx)
	current_selected_slice_idx = clampi(current_selected_slice_idx, 0, room_slices.size() - 1)
	_render_slice_tabs()
	_sync_active_slice_controls()
	EventBus.notification_requested.emit("Removed slice.", true)


func _sync_active_slice_controls() -> void:
	if current_selected_slice_idx < 0 or current_selected_slice_idx >= room_slices.size():
		return

	var current_sec: Dictionary = room_slices[current_selected_slice_idx]
	var current_wall_path: String = str(current_sec.get("wallpaper_path", ""))
	var current_fill_mode: String = str(current_sec.get("fill_mode", "cover"))
	var is_outdoor: bool = bool(current_sec.get("is_outdoor", false))

	slice_status_lbl.text = "Slice %d Artwork (Leave empty for procedural wall/floor):" % (current_selected_slice_idx + 1)
	
	opt_slice_environment.selected = 1 if is_outdoor else 0
	_update_environment_hint(is_outdoor)

	_select_fill_mode(current_fill_mode)
	_populate_art_dropdown(current_wall_path)


func _on_slice_environment_selected(index: int) -> void:
	if current_selected_slice_idx < 0 or current_selected_slice_idx >= room_slices.size():
		return
	var is_outdoor: bool = (index == 1)
	room_slices[current_selected_slice_idx]["is_outdoor"] = is_outdoor
	_update_environment_hint(is_outdoor)
	_render_slice_tabs()


func _update_environment_hint(is_outdoor: bool) -> void:
	if slice_env_hint != null:
		if is_outdoor:
			slice_env_hint.text = "Outdoors: Weather precipitation (rain, snow, leaves) will fall across this slice."
		else:
			slice_env_hint.text = "Indoors: Weather precipitation is blocked inside this slice."


func _select_fill_mode(mode_id: String) -> void:
	for index: int in range(FILL_MODES.size()):
		if str(FILL_MODES[index]["id"]) == mode_id:
			fill_mode_option.selected = index
			_update_preview_stretch_mode(int(FILL_MODES[index]["stretch"]))
			return
	fill_mode_option.selected = 0
	_update_preview_stretch_mode(int(FILL_MODES[0]["stretch"]))


func _populate_art_dropdown(current_wall_path: String) -> void:
	if art_option == null: return
	art_option.clear()
	art_option.add_item("(Procedural Wall & Floor / No Custom Art)", 0)

	var selected_index: int = 0
	for index: int in range(art_library.size()):
		var art: Dictionary = art_library[index]
		var art_name: String = str(art.get("name", "Art"))
		var art_path: String = str(art.get("file_path", ""))
		art_option.add_item(art_name, index + 1)
		if art_path == current_wall_path: selected_index = index + 1

	art_option.selected = selected_index
	if selected_index > 0:
		var chosen_texture: Variant = art_library[selected_index - 1].get("texture", null)
		if chosen_texture is Texture2D: _update_preview_texture(chosen_texture as Texture2D)
		elif FileAccess.file_exists(current_wall_path):
			_update_preview_texture(UGCManager.load_texture_from_file(current_wall_path))
		else:
			preview_rect.texture = null
	else:
		preview_rect.texture = null


func _on_art_selected(index: int) -> void:
	if current_selected_slice_idx < 0 or current_selected_slice_idx >= room_slices.size():
		return

	if index > 0 and index <= art_library.size():
		var chosen_path: String = str(art_library[index - 1].get("file_path", ""))
		room_slices[current_selected_slice_idx]["wallpaper_path"] = chosen_path
		_update_preview_texture(UGCManager.load_texture_from_file(chosen_path))
	else:
		room_slices[current_selected_slice_idx]["wallpaper_path"] = ""
		preview_rect.texture = null

	_render_slice_tabs()


func _on_fill_mode_selected(index: int) -> void:
	if current_selected_slice_idx < 0 or current_selected_slice_idx >= room_slices.size():
		return

	if index >= 0 and index < FILL_MODES.size():
		var mode_id: String = str(FILL_MODES[index]["id"])
		room_slices[current_selected_slice_idx]["fill_mode"] = mode_id
		_update_preview_stretch_mode(int(FILL_MODES[index]["stretch"]))


func _update_preview_texture(texture: Texture2D) -> void:
	if preview_rect != null: preview_rect.texture = texture


func _update_preview_stretch_mode(stretch_mode: int) -> void:
	if preview_rect != null: preview_rect.stretch_mode = stretch_mode as TextureRect.StretchMode


func _on_floor_slider_changed(value: float) -> void:
	if floor_val_lbl != null: floor_val_lbl.text = "%d px" % int(value)
	if check_show_floor_line != null:
		floor_preview_changed.emit(value, check_show_floor_line.button_pressed)


func _on_save_pressed() -> void:
	var room_title: String = room_name_edit.text.strip_edges()
	floor_preview_changed.emit(floor_slider.value, false)
	room_configured.emit(room_slices.duplicate(true), floor_slider.value, room_title)
	EventBus.notification_requested.emit("Saved room layout (%d slice%s)" % [
		room_slices.size(), ("s" if room_slices.size() > 1 else "")
	], true)
	visible = false


func _on_clear_slice_wallpaper_pressed() -> void:
	if current_selected_slice_idx >= 0 and current_selected_slice_idx < room_slices.size():
		room_slices[current_selected_slice_idx]["wallpaper_path"] = ""
		_render_slice_tabs()
		_sync_active_slice_controls()


func _add_icon_option(option_button: OptionButton, icon_key: String, text_label: String, item_id: int) -> void:
	var icon_texture: Texture2D = ThemeService.get_popup_icon(icon_key)
	if icon_texture != null: option_button.add_icon_item(icon_texture, " " + text_label, item_id)
	else: option_button.add_item(text_label, item_id)


func _refresh_theme_icons() -> void:
	_apply_close_icon_to_header()
	_apply_button_icon(btn_apply, "icon_save")
	_apply_button_icon(btn_clear_slice, "icon_delete")
	_apply_checkbox_icon(check_show_floor_line, "icon_floor")


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


func _apply_close_icon_to_header() -> void:
	if root_panel == null: return
	for node: Node in root_panel.find_children("*", "Button", true, false):
		if node is Button and (node as Button).text == "✕":
			_apply_close_icon(node as Button)
			return


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_dialog()
