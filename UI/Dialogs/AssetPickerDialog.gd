# ============================================================
# File: res://UI/Dialogs/AssetPickerDialog.gd
# ============================================================

# ==============================================================================
# OWNWORLD — ASSET PICKER DIALOG (SUB-MODAL LAYER 125)
# File: res://UI/Dialogs/AssetPickerDialog.gd
# Base Class: HyperUIDialog
#
# Responsibility: High-speed user art and drawing selector. Configured with
# sub-modal priority (Layer 125) to stack cleanly above parent modal dialogs.
# ==============================================================================

class_name AssetPickerDialog
extends HyperUIDialog

var header_title_lbl: Label = null
var breadcrumbs_hbox: HBoxContainer = null
var btn_back_up: Button = null

var search_input: LineEdit = null
var filter_scroll_container: HBoxContainer = null

var scroll_container: ScrollContainer = null
var items_grid: GridContainer = null

var current_virtual_folder: String = ""
var active_search_query: String = ""
var active_tag_filter: String = "All"
var current_select_callback: Callable = Callable()

var all_art_files: Array[Dictionary] = []
var asset_tags_registry: Dictionary = {}
var user_available_tags: Array[String] = []

signal asset_selected(asset_name: String, texture: Texture2D, file_path: String)
signal picker_closed()


func _init() -> void:
	max_panel_width = 640.0
	max_panel_height = 560.0
	is_sub_modal = true
	set_sub_modal_priority(true)


func _build_content() -> void:
	name = "AssetPickerDialog"
	_load_tag_registry()

	var is_mob: bool = is_mobile()
	var row_h: float = 34.0 if is_mob else 28.0

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	root_panel.add_child(vbox)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	vbox.add_child(header_hbox)

	header_title_lbl = Label.new()
	header_title_lbl.text = "Select Artwork"
	header_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_title_lbl.theme_type_variation = "HeaderLabel"
	header_title_lbl.add_theme_font_size_override("font_size", 14 if is_mob else 12)
	header_hbox.add_child(header_title_lbl)

	var btn_close: Button = Button.new()
	btn_close.custom_minimum_size = Vector2(28.0 if is_mob else 22.0, 28.0 if is_mob else 22.0)
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.add_theme_constant_override("icon_max_width", 12)
	apply_close_icon(btn_close)
	btn_close.pressed.connect(_on_close_requested)
	header_hbox.add_child(btn_close)

	vbox.add_child(HSeparator.new())

	var nav_row: HBoxContainer = HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 6)
	vbox.add_child(nav_row)

	btn_back_up = Button.new()
	btn_back_up.text = " Up"
	btn_back_up.custom_minimum_size = Vector2(60.0 if is_mob else 50.0, row_h)
	btn_back_up.focus_mode = Control.FOCUS_NONE
	btn_back_up.add_theme_constant_override("icon_max_width", 14)
	btn_back_up.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	apply_button_icon(btn_back_up, "icon_up")
	btn_back_up.pressed.connect(_navigate_up_one_folder)
	nav_row.add_child(btn_back_up)

	var breadcrumbs_scroll: ScrollContainer = ScrollContainer.new()
	breadcrumbs_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	breadcrumbs_scroll.custom_minimum_size = Vector2(0.0, row_h)
	breadcrumbs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	breadcrumbs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	breadcrumbs_scroll.follow_focus = false
	nav_row.add_child(breadcrumbs_scroll)

	breadcrumbs_hbox = HBoxContainer.new()
	breadcrumbs_hbox.add_theme_constant_override("separation", 4)
	breadcrumbs_scroll.add_child(breadcrumbs_hbox)

	var search_row: HBoxContainer = HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 6)
	vbox.add_child(search_row)

	search_input = LineEdit.new()
	search_input.placeholder_text = "Search in folder or tags..."
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_input.custom_minimum_size = Vector2(100.0, row_h)
	search_input.text_changed.connect(_on_search_text_changed)
	register_keyboard_dodge(search_input)
	search_row.add_child(search_input)

	var filter_scroll: ScrollContainer = ScrollContainer.new()
	filter_scroll.custom_minimum_size = Vector2(0.0, row_h)
	filter_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	filter_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	filter_scroll.follow_focus = false
	vbox.add_child(filter_scroll)

	filter_scroll_container = HBoxContainer.new()
	filter_scroll_container.add_theme_constant_override("separation", 4)
	filter_scroll.add_child(filter_scroll_container)

	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.follow_focus = false
	vbox.add_child(scroll_container)

	items_grid = GridContainer.new()
	items_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_grid.add_theme_constant_override("h_separation", 6)
	items_grid.add_theme_constant_override("v_separation", 6)
	scroll_container.add_child(items_grid)


func _on_theme_updated() -> void:
	apply_button_icon(btn_back_up, "icon_up")
	if root_panel == null: 
		return
	for node: Node in root_panel.find_children("*", "Button", true, false):
		if node is Button and (node as Button).text == "✕":
			apply_close_icon(node as Button)
	if visible:
		_build_tag_filter_pills()
		_render_breadcrumbs()
		_render_grid_view()


func _update_responsive_layout() -> void:
	super._update_responsive_layout()
	if items_grid and root_panel:
		var usable_w: float = root_panel.size.x - 28.0
		var card_w: float = 88.0 if is_mobile() else 72.0
		items_grid.columns = clampi(int(usable_w / (card_w + 6.0)), 3, 10)


func open_picker(prompt_title: String = "Select Artwork", default_folder: String = "", on_selected_callback: Callable = Callable()) -> void:
	set_sub_modal_priority(true)
	header_title_lbl.text = prompt_title
	current_virtual_folder = default_folder.strip_edges()
	current_select_callback = on_selected_callback
	active_search_query = ""
	active_tag_filter = "All"
	if search_input: 
		search_input.text = ""

	_load_tag_registry()
	all_art_files = UGCManager.scan_user_art_library()

	_build_tag_filter_pills()
	_render_breadcrumbs()
	_render_grid_view()
	open_dialog()


func _on_close_requested() -> void:
	current_select_callback = Callable()
	picker_closed.emit()
	super._on_close_requested()


func _render_breadcrumbs() -> void:
	for child: Node in breadcrumbs_hbox.get_children():
		child.queue_free()

	btn_back_up.disabled = (current_virtual_folder.is_empty() or current_virtual_folder == "Root")
	var btn_root: Button = _create_breadcrumb_pill("Root", "icon_room", current_virtual_folder.is_empty() or current_virtual_folder == "Root")
	btn_root.pressed.connect(func() -> void:
		current_virtual_folder = ""
		_render_breadcrumbs()
		_render_grid_view()
	)
	breadcrumbs_hbox.add_child(btn_root)

	if not current_virtual_folder.is_empty() and current_virtual_folder != "Root":
		var parts: PackedStringArray = current_virtual_folder.split("/", false)
		var accum_path: String = ""
		for i: int in range(parts.size()):
			var separator_lbl: Label = Label.new()
			separator_lbl.text = ">"
			separator_lbl.theme_type_variation = "HintLabel"
			breadcrumbs_hbox.add_child(separator_lbl)

			accum_path = parts[i] if accum_path.is_empty() else accum_path + "/" + parts[i]
			var is_current: bool = (i == parts.size() - 1)
			var btn_part: Button = _create_breadcrumb_pill(parts[i], "icon_folder", is_current)
			var target_p: String = accum_path
			btn_part.pressed.connect(func() -> void:
				current_virtual_folder = target_p
				_render_breadcrumbs()
				_render_grid_view()
			)
			breadcrumbs_hbox.add_child(btn_part)


func _create_breadcrumb_pill(label_text: String, icon_key: String, is_active: bool) -> Button:
	var is_mob: bool = is_mobile()
	var btn: Button = Button.new()
	btn.text = " " + label_text
	btn.focus_mode = Control.FOCUS_NONE
	btn.toggle_mode = true
	btn.button_pressed = is_active
	btn.theme_type_variation = "Breadcrumb"
	btn.add_theme_constant_override("icon_max_width", 14 if is_mob else 12)
	btn.add_theme_font_size_override("font_size", 10 if is_mob else 9)
	apply_button_icon(btn, icon_key)
	return btn


func _navigate_up_one_folder() -> void:
	if current_virtual_folder.is_empty() or current_virtual_folder == "Root":
		return
	if "/" in current_virtual_folder:
		var parts: PackedStringArray = current_virtual_folder.split("/", false)
		parts.remove_at(parts.size() - 1)
		current_virtual_folder = "/".join(parts)
	else:
		current_virtual_folder = ""
	_render_breadcrumbs()
	_render_grid_view()


func _render_grid_view() -> void:
	for child: Node in items_grid.get_children():
		child.queue_free()

	var active_folder_norm: String = current_virtual_folder.replace("\\", "/").strip_edges().trim_prefix("/").trim_suffix("/")
	if active_folder_norm == "Root":
		active_folder_norm = ""

	var direct_subfolders: Array[String] = []
	if active_search_query.is_empty() and active_tag_filter == "All":
		direct_subfolders = UGCManager.get_subfolders_in_art_folder(active_folder_norm)
		for sub_name: String in direct_subfolders:
			_create_folder_card(sub_name)

	var items_rendered: int = 0
	for art_data: Dictionary in all_art_files:
		var fname: String = str(art_data.get("name", "Art"))
		var f_folder: String = str(art_data.get("folder", "")).replace("\\", "/").strip_edges().trim_prefix("/").trim_suffix("/")
		if f_folder == "Root": 
			f_folder = ""

		var tags: Array = asset_tags_registry.get(fname, ["#props"]) as Array
		var in_current_folder: bool = (f_folder == active_folder_norm)

		if not active_search_query.is_empty():
			var matches_query: bool = (active_search_query in fname.to_lower()) or (active_search_query in f_folder.to_lower())
			for t: Variant in tags:
				if active_search_query in str(t).to_lower():
					matches_query = true
					break
			if not matches_query: 
				continue
		elif active_tag_filter != "All":
			if not (active_tag_filter in tags): 
				continue
		else:
			if not in_current_folder: 
				continue

		_create_image_card(art_data)
		items_rendered += 1

	if items_rendered == 0 and direct_subfolders.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "(No drawings found in this folder)"
		empty_lbl.theme_type_variation = "HintLabel"
		empty_lbl.add_theme_font_size_override("font_size", 11 if is_mobile() else 10)
		items_grid.add_child(empty_lbl)


func _create_folder_card(folder_name: String) -> void:
	var is_mob: bool = is_mobile()
	var card_w: float = 88.0 if is_mob else 72.0
	var card_h: float = 100.0 if is_mob else 80.0

	var card: Button = Button.new()
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.focus_mode = Control.FOCUS_NONE
	
	var s_normal: StyleBoxFlat = StyleBoxFlat.new()
	s_normal.bg_color = ThemeService.get_color("container_sub_bg", "#fdf2f4")
	s_normal.border_color = ThemeService.get_color("panel_border", "#f472b6")
	s_normal.set_border_width_all(1)
	s_normal.set_corner_radius_all(4)
	card.add_theme_stylebox_override("normal", s_normal)
	
	var s_hover: StyleBoxFlat = s_normal.duplicate() as StyleBoxFlat
	s_hover.border_color = ThemeService.get_color("accent_primary", "#db2777")
	card.add_theme_stylebox_override("hover", s_hover)
	card.add_theme_stylebox_override("pressed", s_hover)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(36.0 if is_mob else 28.0, 36.0 if is_mob else 28.0)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var f_icon: Texture2D = ThemeService.get_icon("icon_folder")
	if f_icon:
		icon_rect.texture = f_icon
		icon_rect.modulate = ThemeService.get_color("accent_primary", "#db2777")
	vbox.add_child(icon_rect)

	var name_lbl: Label = Label.new()
	name_lbl.text = folder_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 10 if is_mob else 9)
	vbox.add_child(name_lbl)

	card.pressed.connect(func() -> void:
		if current_virtual_folder.is_empty() or current_virtual_folder == "Root":
			current_virtual_folder = folder_name
		else:
			current_virtual_folder = current_virtual_folder + "/" + folder_name
		_render_breadcrumbs()
		_render_grid_view()
	)
	items_grid.add_child(card)


func _create_image_card(art_data: Dictionary) -> void:
	var is_mob: bool = is_mobile()
	var card_w: float = 88.0 if is_mob else 72.0
	var card_h: float = 100.0 if is_mob else 80.0

	var fname: String = str(art_data.get("name", "Art"))
	var fpath: String = str(art_data.get("file_path", ""))

	var card: Button = Button.new()
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.focus_mode = Control.FOCUS_NONE
	
	var s_normal: StyleBoxFlat = StyleBoxFlat.new()
	s_normal.bg_color = ThemeService.get_color("container_sub_bg", "#fdf2f4")
	s_normal.border_color = ThemeService.get_color("panel_border", "#f472b6")
	s_normal.set_border_width_all(1)
	s_normal.set_corner_radius_all(4)
	card.add_theme_stylebox_override("normal", s_normal)
	
	var s_hover: StyleBoxFlat = s_normal.duplicate() as StyleBoxFlat
	s_hover.border_color = ThemeService.get_color("accent_primary", "#db2777")
	card.add_theme_stylebox_override("hover", s_hover)
	card.add_theme_stylebox_override("pressed", s_hover)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	var thumb_box: PanelContainer = PanelContainer.new()
	thumb_box.custom_minimum_size = Vector2(50.0 if is_mob else 40.0, 50.0 if is_mob else 40.0)
	thumb_box.clip_contents = true
	thumb_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var t_style: StyleBoxFlat = StyleBoxFlat.new()
	t_style.bg_color = ThemeService.get_color("input_background", "#ffffff")
	t_style.border_color = ThemeService.get_color("panel_border", "#f472b6")
	t_style.set_border_width_all(1)
	t_style.set_corner_radius_all(4)
	thumb_box.add_theme_stylebox_override("panel", t_style)

	var thumb: TextureRect = TextureRect.new()
	thumb.set_anchors_preset(Control.PRESET_FULL_RECT)
	thumb.texture = UGCManager.get_thumbnail(fpath)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb_box.add_child(thumb)
	vbox.add_child(thumb_box)

	var lbl: Label = Label.new()
	lbl.text = fname
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10 if is_mob else 9)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(lbl)

	card.pressed.connect(func() -> void:
		var chosen_tex: Texture2D = UGCManager.load_texture_from_file(fpath)
		if current_select_callback.is_valid():
			current_select_callback.call(fname, chosen_tex, fpath)
			current_select_callback = Callable()
		asset_selected.emit(fname, chosen_tex, fpath)
		close_dialog()
	)
	items_grid.add_child(card)


func _build_tag_filter_pills() -> void:
	for child: Node in filter_scroll_container.get_children():
		child.queue_free()
	_add_filter_pill("All", active_tag_filter == "All")
	for tag: String in user_available_tags:
		_add_filter_pill(tag, active_tag_filter == tag)


func _add_filter_pill(label_text: String, is_active: bool) -> void:
	var is_mob: bool = is_mobile()
	var btn: Button = Button.new()
	btn.text = label_text
	btn.focus_mode = Control.FOCUS_NONE
	btn.toggle_mode = true
	btn.button_pressed = is_active
	btn.add_theme_font_size_override("font_size", 11 if is_mob else 10)

	var c_accent: Color = ThemeService.get_color("accent_primary", "#db2777")
	var c_btn_n: Color = ThemeService.get_color("button_normal", "#fce7f3")
	var c_border: Color = ThemeService.get_color("panel_border", "#f472b6")
	var c_text: Color = ThemeService.get_color("text_primary", "#4a1525")
	var rad: int = ThemeService.get_corner_radius()

	var s_pill: StyleBoxFlat = StyleBoxFlat.new()
	s_pill.bg_color = c_accent if is_active else c_btn_n
	s_pill.border_color = c_accent if is_active else c_border
	s_pill.set_border_width_all(1)
	s_pill.set_corner_radius_all(rad)
	s_pill.content_margin_left = 8 if is_mob else 6
	s_pill.content_margin_right = 8 if is_mob else 6
	s_pill.content_margin_top = 4 if is_mob else 2
	s_pill.content_margin_bottom = 4 if is_mob else 2

	btn.add_theme_stylebox_override("normal", s_pill)
	btn.add_theme_stylebox_override("hover", s_pill)
	btn.add_theme_stylebox_override("pressed", s_pill)
	btn.add_theme_color_override("font_color", Color.WHITE if is_active else c_text)

	btn.pressed.connect(func() -> void:
		active_tag_filter = label_text
		_build_tag_filter_pills()
		_render_grid_view()
	)
	filter_scroll_container.add_child(btn)


func _on_search_text_changed(new_text: String) -> void:
	active_search_query = new_text.strip_edges().to_lower()
	_render_grid_view()


func _load_tag_registry() -> void:
	user_available_tags = DrawerMetadataService.load_tags_list()
	asset_tags_registry = DrawerMetadataService.load_asset_tags()
