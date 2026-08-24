# ==============================================================================
# Script: res://UI/Dialogs/AssetPickerDialog.gd
# Base Class: CanvasLayer (class_name AssetPickerDialog)
# ==============================================================================

class_name AssetPickerDialog
extends CanvasLayer

const PATH_ITEM_TAGS_FILE: String = "user://my_art_tags.json"
const PATH_TAGS_LIST_FILE: String = "user://my_art_tags_list.json"

const MAX_PANEL_WIDTH: float = 580.0
const MAX_PANEL_HEIGHT: float = 520.0

var root_backdrop: Control = null
var center_container: CenterContainer = null
var root_panel: PanelContainer = null

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

func _ready() -> void:
	name = "AssetPickerDialog"
	layer = 130
	visible = false
	add_to_group("modal_ui")
	_load_tag_registry()
	_build_ui()
	_connect_system_signals()
	_update_responsive_layout()
	_setup_keyboard_dodging()

func _connect_system_signals() -> void:
	var tree: SceneTree = get_tree()
	if tree and tree.root and not tree.root.size_changed.is_connected(_update_responsive_layout):
		tree.root.size_changed.connect(_update_responsive_layout)

func _update_responsive_layout() -> void:
	if not is_instance_valid(root_panel):
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280.0, 720.0)
	var target_w: float = clampf(vp_size.x * 0.92, 290.0, MAX_PANEL_WIDTH)
	var target_h: float = clampf(vp_size.y * 0.90, 330.0, MAX_PANEL_HEIGHT)
	root_panel.custom_minimum_size = Vector2(target_w, target_h)
	root_panel.size = Vector2(target_w, target_h)

	if items_grid:
		var usable_w: float = target_w - 28.0
		items_grid.columns = clampi(int(usable_w / 76.0), 3, 10)

func _setup_keyboard_dodging() -> void:
	if search_input:
		search_input.focus_entered.connect(_on_input_focus_entered)
		search_input.focus_exited.connect(_on_input_focus_exited)

func _on_input_focus_entered() -> void:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		await get_tree().process_frame
		await get_tree().process_frame
		var kb_height: float = DisplayServer.virtual_keyboard_get_height()
		if kb_height > 0:
			var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(center_container, "position:y", -kb_height * 0.5, 0.25)

func _on_input_focus_exited() -> void:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(center_container, "position:y", 0.0, 0.25)

func _build_ui() -> void:
	root_backdrop = Control.new()
	root_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root_backdrop.gui_input.connect(_on_backdrop_gui_input)
	add_child(root_backdrop)

	var bg_dim: ColorRect = ColorRect.new()
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_dim.color = Color(0.0, 0.0, 0.0, 0.6)
	bg_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_backdrop.add_child(bg_dim)

	center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_PASS
	root_backdrop.add_child(center_container)

	root_panel = PanelContainer.new()
	root_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center_container.add_child(root_panel)

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
	header_hbox.add_child(header_title_lbl)

	var btn_close: Button = Button.new()
	btn_close.custom_minimum_size = Vector2(24.0, 24.0)
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.add_theme_constant_override("icon_max_width", 12)
	var close_icon: Texture2D = ThemeService.get_icon("icon_close")
	if close_icon: btn_close.icon = close_icon
	else: btn_close.text = "✕"
	btn_close.pressed.connect(close_picker)
	header_hbox.add_child(btn_close)

	vbox.add_child(HSeparator.new())

	var nav_row: HBoxContainer = HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 6)
	vbox.add_child(nav_row)

	btn_back_up = Button.new()
	btn_back_up.text = " Up"
	btn_back_up.custom_minimum_size = Vector2(55.0, 26.0)
	btn_back_up.focus_mode = Control.FOCUS_NONE
	btn_back_up.add_theme_constant_override("icon_max_width", 14)
	btn_back_up.add_theme_font_size_override("font_size", 10)
	var up_icon: Texture2D = ThemeService.get_icon("icon_up")
	if up_icon: btn_back_up.icon = up_icon
	btn_back_up.pressed.connect(_navigate_up_one_folder)
	nav_row.add_child(btn_back_up)

	var breadcrumbs_scroll: ScrollContainer = ScrollContainer.new()
	breadcrumbs_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	breadcrumbs_scroll.custom_minimum_size = Vector2(0.0, 26.0)
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
	search_input.custom_minimum_size = Vector2(100.0, 28.0)
	search_input.text_changed.connect(_on_search_text_changed)
	search_row.add_child(search_input)

	var filter_scroll: ScrollContainer = ScrollContainer.new()
	filter_scroll.custom_minimum_size = Vector2(0.0, 28.0)
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

func open_picker(prompt_title: String = "Select Artwork", default_folder: String = "", on_selected_callback: Callable = Callable()) -> void:
	header_title_lbl.text = prompt_title
	current_virtual_folder = default_folder
	current_select_callback = on_selected_callback
	active_search_query = ""
	active_tag_filter = "All"
	if search_input: search_input.text = ""

	_load_tag_registry()
	all_art_files = UGCManager.scan_user_art_library()

	_update_responsive_layout()
	_build_tag_filter_pills()
	_render_breadcrumbs()
	_render_grid_view()
	visible = true

func close_picker() -> void:
	current_select_callback = Callable()
	visible = false
	picker_closed.emit()

func _render_breadcrumbs() -> void:
	for child: Node in breadcrumbs_hbox.get_children():
		child.queue_free()

	btn_back_up.disabled = (current_virtual_folder == "" or current_virtual_folder == "Root")
	var btn_root: Button = _create_breadcrumb_pill("Root", "icon_room", current_virtual_folder == "" or current_virtual_folder == "Root")
	btn_root.pressed.connect(func() -> void:
		current_virtual_folder = ""
		_render_breadcrumbs()
		_render_grid_view()
	)
	breadcrumbs_hbox.add_child(btn_root)

	if current_virtual_folder != "" and current_virtual_folder != "Root":
		var parts: PackedStringArray = current_virtual_folder.split("/", false)
		var accum_path: String = ""
		for i: int in range(parts.size()):
			var separator_lbl: Label = Label.new()
			separator_lbl.text = ">"
			separator_lbl.theme_type_variation = "HintLabel"
			breadcrumbs_hbox.add_child(separator_lbl)

			accum_path = parts[i] if accum_path == "" else accum_path + "/" + parts[i]
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
	var btn: Button = Button.new()
	btn.text = " " + label_text
	btn.focus_mode = Control.FOCUS_NONE
	btn.toggle_mode = true
	btn.button_pressed = is_active
	btn.theme_type_variation = "Breadcrumb"
	btn.add_theme_constant_override("icon_max_width", 12)
	btn.add_theme_font_size_override("font_size", 9)
	var icon_tex: Texture2D = ThemeService.get_icon(icon_key)
	if icon_tex: btn.icon = icon_tex
	return btn

func _navigate_up_one_folder() -> void:
	if current_virtual_folder == "" or current_virtual_folder == "Root":
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
	if active_search_query == "" and active_tag_filter == "All":
		direct_subfolders = UGCManager.get_subfolders_in_art_folder(active_folder_norm)
		for sub_name: String in direct_subfolders:
			_create_folder_card(sub_name)

	var items_rendered: int = 0
	for art_data: Dictionary in all_art_files:
		var fname: String = str(art_data.get("name", "Art"))
		var f_folder: String = str(art_data.get("folder", "")).replace("\\", "/").strip_edges().trim_prefix("/").trim_suffix("/")
		if f_folder == "Root": f_folder = ""

		var tags: Array = asset_tags_registry.get(fname, ["#props"]) as Array
		var tex: Texture2D = art_data.get("texture", null) as Texture2D
		var in_current_folder: bool = (f_folder == active_folder_norm)

		if active_search_query != "":
			var matches_query: bool = (active_search_query in fname.to_lower()) or (active_search_query in f_folder.to_lower())
			for t: Variant in tags:
				if active_search_query in str(t).to_lower():
					matches_query = true
					break
			if not matches_query: continue
		elif active_tag_filter != "All":
			if not (active_tag_filter in tags): continue
		else:
			if not in_current_folder: continue

		_create_image_card(art_data, tex)
		items_rendered += 1

	if items_rendered == 0 and direct_subfolders.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "(No drawings found in this folder)"
		empty_lbl.theme_type_variation = "HintLabel"
		empty_lbl.add_theme_font_size_override("font_size", 10)
		items_grid.add_child(empty_lbl)

func _create_folder_card(folder_name: String) -> void:
	# BUTTON-BASED SCROLLING: Using Button instead of PanelContainer fixes mobile scroll blocking
	var card: Button = Button.new()
	card.custom_minimum_size = Vector2(68.0, 76.0)
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
	icon_rect.custom_minimum_size = Vector2(28.0, 28.0)
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
	name_lbl.add_theme_font_size_override("font_size", 9)
	vbox.add_child(name_lbl)

	card.pressed.connect(func() -> void:
		if current_virtual_folder == "" or current_virtual_folder == "Root":
			current_virtual_folder = folder_name
		else:
			current_virtual_folder = current_virtual_folder + "/" + folder_name
		_render_breadcrumbs()
		_render_grid_view()
	)
	items_grid.add_child(card)

func _create_image_card(art_data: Dictionary, tex: Texture2D) -> void:
	var fname: String = str(art_data.get("name", "Art"))
	var fpath: String = str(art_data.get("file_path", ""))

	# BUTTON-BASED SCROLLING: Using Button instead of PanelContainer fixes mobile scroll blocking
	var card: Button = Button.new()
	card.custom_minimum_size = Vector2(68.0, 76.0)
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
	thumb_box.custom_minimum_size = Vector2(40.0, 40.0)
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
	thumb.texture = tex
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb_box.add_child(thumb)
	vbox.add_child(thumb_box)

	var lbl: Label = Label.new()
	lbl.text = fname
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(lbl)

	card.pressed.connect(func() -> void:
		if current_select_callback.is_valid():
			current_select_callback.call(fname, tex, fpath)
			current_select_callback = Callable()
		asset_selected.emit(fname, tex, fpath)
		visible = false
	)
	items_grid.add_child(card)

func _build_tag_filter_pills() -> void:
	for child: Node in filter_scroll_container.get_children():
		child.queue_free()
	_add_filter_pill("All", active_tag_filter == "All")
	for tag: String in user_available_tags:
		_add_filter_pill(tag, active_tag_filter == tag)

func _add_filter_pill(label_text: String, is_active: bool) -> void:
	var btn: Button = Button.new()
	btn.text = label_text
	btn.focus_mode = Control.FOCUS_NONE
	btn.toggle_mode = true
	btn.button_pressed = is_active
	btn.add_theme_font_size_override("font_size", 10)

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
	s_pill.content_margin_left = 6
	s_pill.content_margin_right = 6
	s_pill.content_margin_top = 2
	s_pill.content_margin_bottom = 2

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
	if FileAccess.file_exists(PATH_TAGS_LIST_FILE):
		var f: FileAccess = FileAccess.open(PATH_TAGS_LIST_FILE, FileAccess.READ)
		if f:
			var p: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if p is Array:
				user_available_tags.clear()
				for item: Variant in (p as Array):
					user_available_tags.append(str(item))

	if user_available_tags.is_empty():
		user_available_tags = ["#props", "#food", "#furniture", "#characters", "#decor", "#clothing"]

	if FileAccess.file_exists(PATH_ITEM_TAGS_FILE):
		var f: FileAccess = FileAccess.open(PATH_ITEM_TAGS_FILE, FileAccess.READ)
		if f:
			var p: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if p is Dictionary:
				asset_tags_registry = (p as Dictionary).duplicate(true)

func _on_backdrop_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		close_picker()
