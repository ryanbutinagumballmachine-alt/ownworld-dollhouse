# ==============================================================================
# OWNWORLD — ROOM & WALLPAPER STUDIO
# File: res://UI/Dialogs/RoomStudioDialog.gd
# Base Class: CanvasLayer (class_name RoomStudioDialog)
# ==============================================================================

class_name RoomStudioDialog
extends CanvasLayer

const MAX_PANEL_WIDTH: float = 520.0
const MAX_PANEL_HEIGHT: float = 560.0

var root_backdrop: Control = null
var center_container: CenterContainer = null
var root_panel: PanelContainer = null

var header_lbl: Label = null
var lbl_name: Label = null
var lbl_floor: Label = null
var floor_val_lbl: Label = null
var lbl_select: Label = null
var lbl_fill: Label = null

var room_name_edit: LineEdit = null
var check_show_floor_line: CheckBox = null
var floor_slider: HSlider = null
var art_option: OptionButton = null
var fill_mode_option: OptionButton = null

var preview_panel: PanelContainer = null
var preview_rect: TextureRect = null
var btn_apply: Button = null
var btn_clear: Button = null

var art_library: Array[Dictionary] = []

const FILL_MODES: Array[Dictionary] = [
	{"id": "cover", "label": "Fill / Cover (Aspect Cover)", "stretch": TextureRect.STRETCH_KEEP_ASPECT_COVERED},
	{"id": "fit", "label": "Fit / Center (Aspect Fit)", "stretch": TextureRect.STRETCH_KEEP_ASPECT_CENTERED},
	{"id": "stretch", "label": "Stretch (Fill Viewport)", "stretch": TextureRect.STRETCH_SCALE},
	{"id": "tile", "label": "Tile / Pattern Repeat", "stretch": TextureRect.STRETCH_TILE},
	{"id": "original", "label": "1:1 Original Pixels", "stretch": TextureRect.STRETCH_KEEP_CENTERED}
]

signal room_configured(wallpaper_path: String, wallpaper_tex: Texture2D, floor_y: float, room_title: String, fill_mode: String)
signal floor_preview_changed(floor_y: float, p_visible: bool)
signal room_cleared()

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
	_populate_art_dropdown(_get_selected_art_path())

func _update_responsive_layout() -> void:
	if not is_instance_valid(root_panel): return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280.0, 720.0)
	var target_width: float = clampf(viewport_size.x * 0.90, 280.0, MAX_PANEL_WIDTH)
	var target_height: float = clampf(viewport_size.y * 0.90, 320.0, MAX_PANEL_HEIGHT)
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
	header_lbl.text = "Room & Wallpaper Studio"
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

	var name_box: VBoxContainer = VBoxContainer.new()
	name_box.add_theme_constant_override("separation", 3)
	form_vbox.add_child(name_box)

	lbl_name = Label.new()
	lbl_name.text = "Room Name / Label:"
	lbl_name.theme_type_variation = "HintLabel"
	name_box.add_child(lbl_name)

	room_name_edit = LineEdit.new()
	room_name_edit.placeholder_text = "e.g. Master Bedroom, Sunlit Garden, Cozy Cafe..."
	room_name_edit.custom_minimum_size = Vector2(0.0, 32.0)
	name_box.add_child(room_name_edit)

	var floor_card: PanelContainer = PanelContainer.new()
	floor_card.theme_type_variation = "SubPanel"
	form_vbox.add_child(floor_card)

	var floor_box: VBoxContainer = VBoxContainer.new()
	floor_box.add_theme_constant_override("separation", 6)
	floor_card.add_child(floor_box)

	var floor_header: HBoxContainer = HBoxContainer.new()
	floor_box.add_child(floor_header)

	lbl_floor = Label.new()
	lbl_floor.text = "Floor Baseline:"
	lbl_floor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_floor.theme_type_variation = "HeaderLabel"
	floor_header.add_child(lbl_floor)

	floor_val_lbl = Label.new()
	floor_val_lbl.text = "600 px"
	floor_val_lbl.theme_type_variation = "HintLabel"
	floor_header.add_child(floor_val_lbl)

	floor_slider = HSlider.new()
	floor_slider.min_value = 250.0
	floor_slider.max_value = 950.0
	floor_slider.step = 10.0
	floor_slider.value = 600.0
	floor_slider.custom_minimum_size = Vector2(0.0, 24.0)
	floor_slider.value_changed.connect(_on_floor_slider_changed)
	floor_box.add_child(floor_slider)

	check_show_floor_line = CheckBox.new()
	check_show_floor_line.text = " Show Floor Guide Line"
	check_show_floor_line.button_pressed = true
	check_show_floor_line.custom_minimum_size = Vector2(0.0, 28.0)
	check_show_floor_line.add_theme_constant_override("icon_max_width", 14)
	_apply_checkbox_icon(check_show_floor_line, "icon_floor")
	check_show_floor_line.toggled.connect(func(is_toggled: bool) -> void: floor_preview_changed.emit(floor_slider.value, is_toggled))
	floor_box.add_child(check_show_floor_line)

	var wall_box: VBoxContainer = VBoxContainer.new()
	wall_box.add_theme_constant_override("separation", 3)
	form_vbox.add_child(wall_box)

	lbl_select = Label.new()
	lbl_select.text = "Room Background Drawing (Documents/OwnWorld/Art):"
	lbl_select.theme_type_variation = "HintLabel"
	wall_box.add_child(lbl_select)

	art_option = OptionButton.new()
	art_option.custom_minimum_size = Vector2(0.0, 32.0)
	_enforce_dropdown_popup_limits(art_option, 200)
	art_option.item_selected.connect(_on_art_selected)
	wall_box.add_child(art_option)

	var fill_box: VBoxContainer = VBoxContainer.new()
	fill_box.add_theme_constant_override("separation", 3)
	form_vbox.add_child(fill_box)

	lbl_fill = Label.new()
	lbl_fill.text = "Background Fill & Scaling Mode:"
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
	btn_apply.text = " Apply & Save Room"
	btn_apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_apply.custom_minimum_size = Vector2(0.0, 36.0)
	btn_apply.focus_mode = Control.FOCUS_NONE
	btn_apply.add_theme_constant_override("icon_max_width", 16)
	_apply_button_icon(btn_apply, "icon_save")
	btn_apply.pressed.connect(_on_save_pressed)
	button_row.add_child(btn_apply)

	btn_clear = Button.new()
	btn_clear.text = " Clear Art"
	btn_clear.theme_type_variation = "DangerButton"
	btn_clear.custom_minimum_size = Vector2(110.0, 36.0)
	btn_clear.focus_mode = Control.FOCUS_NONE
	btn_clear.add_theme_constant_override("icon_max_width", 16)
	_apply_button_icon(btn_clear, "icon_delete")
	btn_clear.pressed.connect(_on_clear_wallpaper_pressed)
	button_row.add_child(btn_clear)

func _enforce_dropdown_popup_limits(option_button: OptionButton, max_height: int = 200) -> void:
	if option_button == null: return
	var popup: PopupMenu = option_button.get_popup()
	if popup == null: return
	popup.max_size = Vector2i(4000, max_height)
	popup.about_to_popup.connect(func() -> void: popup.max_size = Vector2i(4000, max_height))

func open_studio(current_room_title: String, current_floor_y: float, current_wall_path: String, current_fill_mode: String = "cover") -> void:
	art_library = UGCManager.scan_user_art_library()
	room_name_edit.text = current_room_title
	floor_slider.value = current_floor_y
	floor_val_lbl.text = "%d px" % int(current_floor_y)
	check_show_floor_line.button_pressed = true

	_update_responsive_layout()
	_select_fill_mode(current_fill_mode)
	_populate_art_dropdown(current_wall_path)

	floor_preview_changed.emit(current_floor_y, true)
	visible = true

func close_dialog() -> void:
	if floor_slider != null: floor_preview_changed.emit(floor_slider.value, false)
	visible = false

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
	art_option.add_item("(No Background Art / Clear)", 0)

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
		else: preview_rect.texture = null
	else:
		preview_rect.texture = null

func _on_art_selected(index: int) -> void:
	if index > 0 and index <= art_library.size():
		var chosen_texture: Variant = art_library[index - 1].get("texture", null)
		if chosen_texture is Texture2D: _update_preview_texture(chosen_texture as Texture2D)
		else: preview_rect.texture = null
	else:
		preview_rect.texture = null

func _get_selected_art_path() -> String:
	if art_option == null or art_option.selected <= 0 or art_option.selected > art_library.size():
		return ""
	return str(art_library[art_option.selected - 1].get("file_path", ""))

func _on_fill_mode_selected(index: int) -> void:
	if index >= 0 and index < FILL_MODES.size():
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
	var chosen_path: String = ""
	var chosen_texture: Texture2D = null
	var selected_index: int = art_option.selected

	if selected_index > 0 and selected_index <= art_library.size():
		chosen_path = str(art_library[selected_index - 1].get("file_path", ""))
		var texture_value: Variant = art_library[selected_index - 1].get("texture", null)
		if texture_value is Texture2D: chosen_texture = texture_value as Texture2D

	var room_title: String = room_name_edit.text.strip_edges()
	var mode_index: int = fill_mode_option.selected
	var mode_id: String = str(FILL_MODES[mode_index]["id"]) if (mode_index >= 0 and mode_index < FILL_MODES.size()) else "cover"

	floor_preview_changed.emit(floor_slider.value, false)
	room_configured.emit(chosen_path, chosen_texture, floor_slider.value, room_title, mode_id)
	EventBus.notification_requested.emit("Room presentation updated.", true)
	visible = false

func _on_clear_wallpaper_pressed() -> void:
	if art_option != null: art_option.selected = 0
	if preview_rect != null: preview_rect.texture = null
	room_cleared.emit()
	EventBus.notification_requested.emit("Room background cleared.", true)

func _refresh_theme_icons() -> void:
	_apply_close_icon_to_header()
	_apply_button_icon(btn_apply, "icon_save")
	_apply_button_icon(btn_clear, "icon_delete")
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
	# STRICT INPUT SEPARATION
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_dialog()
