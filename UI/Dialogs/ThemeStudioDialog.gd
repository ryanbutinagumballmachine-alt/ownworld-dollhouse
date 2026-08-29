# ============================================================
# File: res://UI/Dialogs/ThemeStudioDialog.gd
# ============================================================

# ==============================================================================
# OWNWORLD — THEME STUDIO DIALOG (HYPER OPTIMIZED & LAYER 120)
# File: res://UI/Dialogs/ThemeStudioDialog.gd
# Base Class: HyperUIDialog
# ==============================================================================

class_name ThemeStudioDialog
extends HyperUIDialog

var font_file_dialog: FileDialog = null

var custom_theme_name_input: LineEdit = null
var saved_themes_container: HBoxContainer = null
var user_saved_themes: Dictionary = {}

var cp_panel_bg: ColorPickerButton = null
var cp_panel_border: ColorPickerButton = null
var cp_container_sub_bg: ColorPickerButton = null
var cp_btn_bg: ColorPickerButton = null
var cp_btn_hover: ColorPickerButton = null
var cp_input_bg: ColorPickerButton = null
var cp_text_primary: ColorPickerButton = null
var cp_text_muted: ColorPickerButton = null
var cp_accent_primary: ColorPickerButton = null
var cp_accent_danger: ColorPickerButton = null

var lbl_current_font: Label = null
var active_custom_font_path: String = ""

var header_lbl: Label = null
var preset_hdr: Label = null
var user_theme_hdr: Label = null
var lbl_font_title: Label = null
var btn_browse_font: Button = null
var btn_reset_font: Button = null
var btn_save_custom: Button = null
var btn_save_theme: Button = null

signal theme_applied(theme_data: Dictionary)


func _init() -> void:
	max_panel_width = 680.0
	max_panel_height = 580.0


func _build_content() -> void:
	name = "ThemeStudioDialog"
	_ensure_theme_dir()
	_load_custom_themes_library()

	var is_mob: bool = is_mobile()
	var row_h: float = 34.0 if is_mob else 28.0

	var outer_vbox: VBoxContainer = VBoxContainer.new()
	outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_theme_constant_override("separation", 6)
	root_panel.add_child(outer_vbox)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	outer_vbox.add_child(header_hbox)

	header_lbl = Label.new()
	header_lbl.text = "Palette & Font Studio"
	header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_lbl.theme_type_variation = "HeaderLabel"
	header_lbl.add_theme_font_size_override("font_size", 14 if is_mob else 12)
	header_hbox.add_child(header_lbl)

	var btn_close: Button = Button.new()
	btn_close.custom_minimum_size = Vector2(28.0 if is_mob else 22.0, 28.0 if is_mob else 22.0)
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.add_theme_constant_override("icon_max_width", 12)
	apply_close_icon(btn_close)
	btn_close.pressed.connect(_on_close_requested)
	header_hbox.add_child(btn_close)

	outer_vbox.add_child(HSeparator.new())

	var scroll_body: ScrollContainer = ScrollContainer.new()
	scroll_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_body.follow_focus = false
	outer_vbox.add_child(scroll_body)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll_body.add_child(vbox)

	preset_hdr = Label.new()
	preset_hdr.text = "Curated Color Palettes (Tap to Preview):"
	preset_hdr.theme_type_variation = "HintLabel"
	preset_hdr.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	vbox.add_child(preset_hdr)

	var presets_grid: GridContainer = GridContainer.new()
	presets_grid.columns = 3
	presets_grid.add_theme_constant_override("h_separation", 6)
	presets_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(presets_grid)

	_add_preset_button(presets_grid, "Strawberry Milk", "#fff5f7", "#f9a8d4", "#fff0f3", "#fce7ed", "#fbcfe0", "#ffffff", "#6c2e3f", "#a36374", "#ec4899", "#f43f5e")
	_add_preset_button(presets_grid, "Matcha Latte", "#f4f8f4", "#86efac", "#eaf4eb", "#dcfce7", "#bbf7d0", "#ffffff", "#2d5a37", "#5c8a66", "#22c55e", "#f87171")
	_add_preset_button(presets_grid, "Lavender Mist", "#f8f6ff", "#c4b5fd", "#f1edff", "#e9e3ff", "#ddd4fe", "#ffffff", "#4c3474", "#7c63a6", "#8b5cf6", "#f43f5e")
	_add_preset_button(presets_grid, "Peach Sorbet", "#fff8f3", "#fdba74", "#ffede0", "#fedec8", "#fccbb0", "#ffffff", "#753820", "#aa684e", "#f97316", "#ef4444")
	_add_preset_button(presets_grid, "Baby Blue", "#f3f9fe", "#93c5fd", "#e7f2fd", "#dbeafe", "#bfdbfe", "#ffffff", "#1e4770", "#5279a0", "#3b82f6", "#f43f5e")
	_add_preset_button(presets_grid, "Honey Butter", "#fffef2", "#fde047", "#fef9d9", "#fef0a6", "#fde68a", "#ffffff", "#614316", "#967138", "#eab308", "#ef4444")
	_add_preset_button(presets_grid, "Midnight Velvet", "#16141e", "#4c3b6d", "#201c2b", "#2b263a", "#3b3350", "#1a1724", "#f3e8ff", "#a897c6", "#c084fc", "#fb7185")

	user_theme_hdr = Label.new()
	user_theme_hdr.text = "Your Saved Palettes:"
	user_theme_hdr.theme_type_variation = "HintLabel"
	user_theme_hdr.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	vbox.add_child(user_theme_hdr)

	var saved_themes_scroll: ScrollContainer = ScrollContainer.new()
	saved_themes_scroll.custom_minimum_size = Vector2(0.0, 34.0 if is_mob else 30.0)
	saved_themes_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	saved_themes_scroll.follow_focus = false
	vbox.add_child(saved_themes_scroll)

	saved_themes_container = HBoxContainer.new()
	saved_themes_container.add_theme_constant_override("separation", 6)
	saved_themes_scroll.add_child(saved_themes_container)
	_render_user_themes_bar()

	vbox.add_child(HSeparator.new())

	var color_grid: GridContainer = GridContainer.new()
	color_grid.columns = 2
	color_grid.add_theme_constant_override("h_separation", 14)
	color_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(color_grid)

	cp_panel_bg = _create_color_picker_row(color_grid, "1. Window Background:", Color("#fff5f7"), row_h)
	cp_panel_border = _create_color_picker_row(color_grid, "2. Window Outlines:", Color("#f9a8d4"), row_h)
	cp_container_sub_bg = _create_color_picker_row(color_grid, "3. Inner Slices / Slots:", Color("#fff0f3"), row_h)
	cp_btn_bg = _create_color_picker_row(color_grid, "4. Button Normal:", Color("#fce7ed"), row_h)
	cp_btn_hover = _create_color_picker_row(color_grid, "5. Button Hover:", Color("#fbcfe0"), row_h)
	cp_input_bg = _create_color_picker_row(color_grid, "6. Text Input Field:", Color("#ffffff"), row_h)
	cp_text_primary = _create_color_picker_row(color_grid, "7. Primary Text:", Color("#6c2e3f"), row_h)
	cp_text_muted = _create_color_picker_row(color_grid, "8. Secondary / Hint Text:", Color("#a36374"), row_h)
	cp_accent_primary = _create_color_picker_row(color_grid, "9. Primary Accent (Active):", Color("#ec4899"), row_h)
	cp_accent_danger = _create_color_picker_row(color_grid, "10. Danger / Delete:", Color("#f43f5e"), row_h)

	var font_hdr_hbox: HBoxContainer = HBoxContainer.new()
	vbox.add_child(font_hdr_hbox)

	lbl_font_title = Label.new()
	lbl_font_title.text = "Custom Typography (Documents/OwnWorld/Dollhouse/Font):"
	lbl_font_title.theme_type_variation = "HintLabel"
	lbl_font_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_font_title.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	font_hdr_hbox.add_child(lbl_font_title)

	lbl_current_font = Label.new()
	lbl_current_font.text = "Default Font"
	lbl_current_font.theme_type_variation = "HeaderLabel"
	lbl_current_font.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	font_hdr_hbox.add_child(lbl_current_font)

	var font_btns_hbox: HBoxContainer = HBoxContainer.new()
	font_btns_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(font_btns_hbox)

	btn_browse_font = Button.new()
	btn_browse_font.text = " Browse Font..."
	btn_browse_font.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_browse_font.focus_mode = Control.FOCUS_NONE
	btn_browse_font.custom_minimum_size = Vector2(0.0, row_h)
	btn_browse_font.add_theme_constant_override("icon_max_width", 14)
	btn_browse_font.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	apply_button_icon(btn_browse_font, "icon_font")
	btn_browse_font.pressed.connect(_on_browse_font_pressed)
	font_btns_hbox.add_child(btn_browse_font)

	btn_reset_font = Button.new()
	btn_reset_font.text = " Reset Font"
	btn_reset_font.focus_mode = Control.FOCUS_NONE
	btn_reset_font.custom_minimum_size = Vector2(0.0, row_h)
	btn_reset_font.add_theme_constant_override("icon_max_width", 14)
	btn_reset_font.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	apply_button_icon(btn_reset_font, "icon_refresh")
	btn_reset_font.pressed.connect(_on_reset_font_pressed)
	font_btns_hbox.add_child(btn_reset_font)

	var save_custom_row: HBoxContainer = HBoxContainer.new()
	save_custom_row.add_theme_constant_override("separation", 6)
	vbox.add_child(save_custom_row)

	custom_theme_name_input = LineEdit.new()
	custom_theme_name_input.placeholder_text = "Save Custom Palette As..."
	custom_theme_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_theme_name_input.custom_minimum_size = Vector2(0.0, row_h)
	register_keyboard_dodge(custom_theme_name_input)
	save_custom_row.add_child(custom_theme_name_input)

	btn_save_custom = Button.new()
	btn_save_custom.text = " Save"
	btn_save_custom.custom_minimum_size = Vector2(90.0 if is_mob else 80.0, row_h)
	btn_save_custom.focus_mode = Control.FOCUS_NONE
	btn_save_custom.add_theme_constant_override("icon_max_width", 14)
	btn_save_custom.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	apply_button_icon(btn_save_custom, "icon_save")
	btn_save_custom.pressed.connect(_on_save_custom_theme_pressed)
	save_custom_row.add_child(btn_save_custom)

	btn_save_theme = Button.new()
	btn_save_theme.text = " Apply Palette Globally"
	btn_save_theme.custom_minimum_size = Vector2(0.0, row_h + 4.0)
	btn_save_theme.focus_mode = Control.FOCUS_NONE
	btn_save_theme.add_theme_constant_override("icon_max_width", 16)
	btn_save_theme.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	apply_button_icon(btn_save_theme, "icon_palette")
	btn_save_theme.pressed.connect(func() -> void: _apply_and_persist_theme(true))
	outer_vbox.add_child(btn_save_theme)

	_build_font_file_dialog()


func _on_theme_updated() -> void:
	if visible: 
		_sync_ui_from_theme_service()
	if root_panel == null: 
		return
	for node: Node in root_panel.find_children("*", "Button", true, false):
		if node is Button and (node as Button).text == "✕":
			apply_close_icon(node as Button)


func _ensure_theme_dir() -> void:
	UGCManager.get_theme_root_directory()
	UGCManager.get_font_root_directory()


func _build_font_file_dialog() -> void:
	font_file_dialog = FileDialog.new()
	font_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	font_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	font_file_dialog.use_native_dialog = true
	font_file_dialog.filters = ["*.ttf, *.otf ; TrueType & OpenType Fonts"]
	font_file_dialog.current_dir = UGCManager.get_font_root_directory()
	font_file_dialog.file_selected.connect(_on_font_file_selected)
	add_child(font_file_dialog)


func open_studio() -> void:
	_sync_ui_from_theme_service()
	_render_user_themes_bar()
	open_dialog()


func _create_color_picker_row(parent: GridContainer, label_text: String, default_color: Color, row_h: float) -> ColorPickerButton:
	var is_mob: bool = is_mobile()
	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	parent.add_child(lbl)

	var c_btn: ColorPickerButton = ColorPickerButton.new()
	c_btn.color = default_color
	c_btn.custom_minimum_size = Vector2(70.0 if is_mob else 60.0, row_h)
	parent.add_child(c_btn)
	return c_btn


func _add_preset_button(
	parent: GridContainer, btn_name: String,
	bg: String, border: String, sub_bg: String,
	btn_n: String, btn_h: String, input_bg: String,
	text_p: String, text_m: String, accent: String, danger: String
) -> void:
	var is_mob: bool = is_mobile()
	var btn: Button = Button.new()
	btn.text = btn_name
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0.0, 32.0 if is_mob else 26.0)

	var p_style: StyleBoxFlat = StyleBoxFlat.new()
	p_style.bg_color = Color(bg)
	p_style.border_color = Color(border)
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", p_style)
	btn.add_theme_color_override("font_color", Color(text_p))
	btn.add_theme_font_size_override("font_size", 11 if is_mob else 10)

	btn.pressed.connect(func() -> void:
		cp_panel_bg.color = Color(bg)
		cp_panel_border.color = Color(border)
		cp_container_sub_bg.color = Color(sub_bg)
		cp_btn_bg.color = Color(btn_n)
		cp_btn_hover.color = Color(btn_h)
		cp_input_bg.color = Color(input_bg)
		cp_text_primary.color = Color(text_p)
		cp_text_muted.color = Color(text_m)
		cp_accent_primary.color = Color(accent)
		cp_accent_danger.color = Color(danger)
		_apply_and_persist_theme(false)
	)
	parent.add_child(btn)


func _render_user_themes_bar() -> void:
	for child: Node in saved_themes_container.get_children():
		child.queue_free()

	var is_mob: bool = is_mobile()

	if user_saved_themes.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "(No custom palettes saved)"
		empty_lbl.theme_type_variation = "HintLabel"
		empty_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
		saved_themes_container.add_child(empty_lbl)
		return

	for theme_name: String in user_saved_themes.keys():
		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 2)

		var btn: Button = Button.new()
		btn.text = " " + theme_name
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 11 if is_mob else 10)
		btn.add_theme_constant_override("icon_max_width", 14 if is_mob else 12)
		btn.custom_minimum_size = Vector2(0.0, 30.0 if is_mob else 26.0)
		apply_button_icon(btn, "icon_palette")
		var cap_name: String = theme_name
		btn.pressed.connect(func() -> void: _load_named_custom_theme(cap_name))
		hbox.add_child(btn)

		var btn_del: Button = Button.new()
		btn_del.custom_minimum_size = Vector2(26.0 if is_mob else 22.0, 30.0 if is_mob else 26.0)
		btn_del.theme_type_variation = "DangerButton"
		btn_del.focus_mode = Control.FOCUS_NONE
		btn_del.add_theme_constant_override("icon_max_width", 10)
		apply_close_icon(btn_del)
		btn_del.pressed.connect(func() -> void: _delete_named_custom_theme(cap_name))
		hbox.add_child(btn_del)

		saved_themes_container.add_child(hbox)


func _on_save_custom_theme_pressed() -> void:
	var t_name: String = custom_theme_name_input.text.strip_edges()
	if t_name.is_empty(): 
		return

	user_saved_themes[t_name] = {
		"colors": {
			"panel_background": "#" + cp_panel_bg.color.to_html(false),
			"panel_border": "#" + cp_panel_border.color.to_html(false),
			"container_sub_bg": "#" + cp_container_sub_bg.color.to_html(false),
			"button_normal": "#" + cp_btn_bg.color.to_html(false),
			"button_hover": "#" + cp_btn_hover.color.to_html(false),
			"button_pressed": "#" + cp_accent_primary.color.to_html(false),
			"button_focus": "#" + cp_panel_border.color.to_html(false),
			"input_background": "#" + cp_input_bg.color.to_html(false),
			"text_primary": "#" + cp_text_primary.color.to_html(false),
			"text_muted": "#" + cp_text_muted.color.to_html(false),
			"accent_primary": "#" + cp_accent_primary.color.to_html(false),
			"accent_danger": "#" + cp_accent_danger.color.to_html(false),
			"window_background": "#" + cp_panel_bg.color.to_html(false)
		},
		"font_path": active_custom_font_path
	}
	_save_custom_themes_library()
	custom_theme_name_input.text = ""
	_render_user_themes_bar()
	_apply_and_persist_theme(true)


func _load_named_custom_theme(t_name: String) -> void:
	if user_saved_themes.has(t_name):
		var t_data: Dictionary = (user_saved_themes[t_name] as Dictionary).duplicate(true)
		var colors: Dictionary = t_data.get("colors", {})
		cp_panel_bg.color = Color(colors.get("panel_background", "#fff5f7"))
		cp_panel_border.color = Color(colors.get("panel_border", "#f9a8d4"))
		cp_container_sub_bg.color = Color(colors.get("container_sub_bg", "#fff0f3"))
		cp_btn_bg.color = Color(colors.get("button_normal", "#fce7ed"))
		cp_btn_hover.color = Color(colors.get("button_hover", "#fbcfe0"))
		cp_input_bg.color = Color(colors.get("input_background", "#ffffff"))
		cp_text_primary.color = Color(colors.get("text_primary", "#6c2e3f"))
		cp_text_muted.color = Color(colors.get("text_muted", "#a36374"))
		cp_accent_primary.color = Color(colors.get("accent_primary", "#ec4899"))
		cp_accent_danger.color = Color(colors.get("accent_danger", "#f43f5e"))
		_apply_and_persist_theme(true)


func _delete_named_custom_theme(t_name: String) -> void:
	user_saved_themes.erase(t_name)
	_save_custom_themes_library()
	_render_user_themes_bar()


func _sync_ui_from_theme_service() -> void:
	var cached: Dictionary = ThemeService.get_theme_data()
	var colors: Dictionary = cached.get("colors", {})

	cp_panel_bg.color = Color(colors.get("panel_background", "#fff5f7"))
	cp_panel_border.color = Color(colors.get("panel_border", "#f9a8d4"))
	cp_container_sub_bg.color = Color(colors.get("container_sub_bg", "#fff0f3"))
	cp_btn_bg.color = Color(colors.get("button_normal", "#fce7ed"))
	cp_btn_hover.color = Color(colors.get("button_hover", "#fbcfe0"))
	cp_input_bg.color = Color(colors.get("input_background", "#ffffff"))
	cp_text_primary.color = Color(colors.get("text_primary", "#6c2e3f"))
	cp_text_muted.color = Color(colors.get("text_muted", "#a36374"))
	cp_accent_primary.color = Color(colors.get("accent_primary", "#ec4899"))
	cp_accent_danger.color = Color(colors.get("accent_danger", "#f43f5e"))

	active_custom_font_path = str(cached.get("font_path", ""))
	lbl_current_font.text = active_custom_font_path.get_file() if (not active_custom_font_path.is_empty() and FileAccess.file_exists(active_custom_font_path)) else "Default Font"


func _on_browse_font_pressed() -> void:
	font_file_dialog.theme = ThemeService.create_theme()
	font_file_dialog.current_dir = UGCManager.get_font_root_directory()
	font_file_dialog.popup_centered_ratio(0.6)


func _on_font_file_selected(fpath: String) -> void:
	active_custom_font_path = fpath.strip_edges()
	lbl_current_font.text = fpath.get_file()
	_apply_and_persist_theme(true)


func _on_reset_font_pressed() -> void:
	active_custom_font_path = ""
	lbl_current_font.text = "Default Font"
	_apply_and_persist_theme(true)


func _apply_and_persist_theme(show_toast: bool) -> void:
	var theme_payload: Dictionary = {
		"colors": {
			"panel_background": "#" + cp_panel_bg.color.to_html(false),
			"panel_border": "#" + cp_panel_border.color.to_html(false),
			"container_sub_bg": "#" + cp_container_sub_bg.color.to_html(false),
			"button_normal": "#" + cp_btn_bg.color.to_html(false),
			"button_hover": "#" + cp_btn_hover.color.to_html(false),
			"button_pressed": "#" + cp_accent_primary.color.to_html(false),
			"button_focus": "#" + cp_panel_border.color.to_html(false),
			"input_background": "#" + cp_input_bg.color.to_html(false),
			"text_primary": "#" + cp_text_primary.color.to_html(false),
			"text_muted": "#" + cp_text_muted.color.to_html(false),
			"accent_primary": "#" + cp_accent_primary.color.to_html(false),
			"accent_danger": "#" + cp_accent_danger.color.to_html(false),
			"window_background": "#" + cp_panel_bg.color.to_html(false)
		},
		"font_path": active_custom_font_path
	}

	ThemeService.apply_theme(theme_payload)
	theme_applied.emit(theme_payload)

	if show_toast:
		EventBus.notification_requested.emit("Applied Palette Globally!", true)


func _load_custom_themes_library() -> void:
	var custom_path: String = UGCManager.get_custom_themes_file_path()
	user_saved_themes = JsonFileStore.read_dictionary(custom_path)


func _save_custom_themes_library() -> void:
	_ensure_theme_dir()
	var custom_path: String = UGCManager.get_custom_themes_file_path()
	JsonFileStore.write_dictionary(custom_path, user_saved_themes)
