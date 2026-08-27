# ==============================================================================
# OWNWORLD — DRAWER TRAY ORCHESTRATOR (ZERO-LAG IN-MEMORY INDEXING)
# File: res://UI/Drawer/DrawerTray.gd
# Base Class: CanvasLayer (class_name DrawerTray)
# ==============================================================================

class_name DrawerTray
extends CanvasLayer

const DRAWER_MAX_WIDTH: float = 780.0
const DRAWER_HEIGHT: float = 230.0
const CARD_WIDTH: float = 76.0
const CARD_HEIGHT: float = 86.0
const GRID_SPACING: int = 6
const DRAG_CANCEL_THRESHOLD: float = 16.0

enum TrayMode { ASSETS, PROPS, FURNITURE, CAST }
var current_mode: TrayMode = TrayMode.ASSETS

var toggle_pill_container: CenterContainer = null
var btn_open_floating_pill: Button = null
var drawer_root_container: Control = null
var root_panel: PanelContainer = null
var main_drawer_vbox: VBoxContainer = null

var btn_back_up: Button = null
var breadcrumbs_hbox: HBoxContainer = null

var btn_toggle_drawer: Button = null
var btn_tab_assets: Button = null
var btn_tab_props: Button = null
var btn_tab_furniture: Button = null
var btn_tab_cast: Button = null
var btn_import_art: Button = null
var btn_new_folder: Button = null
var btn_batch_toggle: Button = null
var search_input: LineEdit = null
var filter_scroll_container: HBoxContainer = null
var art_import_dialog: FileDialog = null

var scroll_container: ScrollContainer = null
var items_grid: GridContainer = null

var batch_bar_panel: PanelContainer = null
var batch_count_lbl: Label = null
var btn_batch_select_all: Button = null
var btn_batch_deselect_all: Button = null
var btn_batch_organize: Button = null
var btn_batch_delete: Button = null
var btn_batch_done: Button = null

var is_drawer_open: bool = false
var is_batch_mode: bool = false
var selected_batch_items: Dictionary = {}
var current_folder_path: String = ""
var active_category_filter: String = "All"
var active_search_query: String = ""

var asset_tags_registry: Dictionary = {}
var user_available_tags: Array[String] = []
var user_registered_folders: Dictionary = {"props": [], "furniture": [], "cast": []}

var folder_modal: DrawerFolderModal = null
var organize_modal: DrawerOrganizeModal = null

signal spawn_ugc_requested(item_name: String, tex: Texture2D, file_path: String)
signal character_spawn_requested(char_data: Dictionary)
signal template_spawn_requested(template_data: Dictionary)


func _get_props_path() -> String:
	return DrawerMetadataService.get_props_path(SaveSystem.get_current_universe_id())


func _get_furniture_path() -> String:
	return DrawerMetadataService.get_furniture_path(SaveSystem.get_current_universe_id())


func _get_cast_path() -> String:
	return DrawerMetadataService.get_cast_path(SaveSystem.get_current_universe_id())


func _get_current_universe_id() -> String: return SaveSystem.get_current_universe_id()
func _generate_entity_uuid(base_name: String) -> String: return base_name.validate_node_name() + "_" + str(Time.get_ticks_usec())
func _notify(message: String, is_success: bool = true) -> void: EventBus.notification_requested.emit(message, is_success)


func _get_next_z_index() -> int:
	var max_z: int = 100
	for node: Node in get_tree().get_nodes_in_group("entities"):
		if node is Node2D: max_z = maxi(max_z, (node as Node2D).z_index)
	return max_z + 1


func _trigger_haptic(duration_ms: int = 35) -> void:
	if SettingsManager.are_haptics_enabled() and (OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")):
		if Input.has_method("vibrate_handheld"):
			Input.vibrate_handheld(duration_ms)


func _ready() -> void:
	layer = 105
	_load_all_metadata()
	_build_ui()
	_build_import_dialogs()
	_build_modals()
	_apply_theme()
	_connect_theme_signals()
	_setup_keyboard_dodging()

	var tree: SceneTree = get_tree()
	if tree and tree.root:
		tree.root.size_changed.connect(_update_responsive_columns)
	_update_responsive_columns()


func _connect_theme_signals() -> void:
	if not ThemeService.theme_changed.is_connected(_on_theme_changed):
		ThemeService.theme_changed.connect(_on_theme_changed)


func _on_theme_changed(_theme_data: Dictionary) -> void:
	_apply_theme()
	if is_drawer_open: refresh_tray()


func is_point_inside_drawer(screen_point: Vector2) -> bool:
	if not is_drawer_open:
		if btn_open_floating_pill and btn_open_floating_pill.is_visible_in_tree():
			return btn_open_floating_pill.get_global_rect().has_point(screen_point)
		return false
	if root_panel and root_panel.is_visible_in_tree():
		return root_panel.get_global_rect().has_point(screen_point)
	return false


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
			tween.tween_property(drawer_root_container, "position:y", -kb_height, 0.25)


func _on_input_focus_exited() -> void:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(drawer_root_container, "position:y", 0.0, 0.25)


func _build_ui() -> void:
	toggle_pill_container = CenterContainer.new()
	toggle_pill_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	toggle_pill_container.offset_top = -32.0
	toggle_pill_container.offset_bottom = 0.0
	toggle_pill_container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(toggle_pill_container)

	btn_open_floating_pill = Button.new()
	btn_open_floating_pill.text = " ▲ "
	btn_open_floating_pill.tooltip_text = "Open Drawer"
	btn_open_floating_pill.custom_minimum_size = Vector2(76.0, 32.0)
	btn_open_floating_pill.theme_type_variation = "FloatingCapsule"
	btn_open_floating_pill.focus_mode = Control.FOCUS_NONE
	btn_open_floating_pill.pressed.connect(_toggle_drawer_state)
	toggle_pill_container.add_child(btn_open_floating_pill)

	drawer_root_container = Control.new()
	drawer_root_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	drawer_root_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawer_root_container.visible = false
	add_child(drawer_root_container)

	root_panel = PanelContainer.new()
	root_panel.name = "DrawerRootPanel"
	root_panel.anchor_left = 0.5
	root_panel.anchor_right = 0.5
	root_panel.anchor_top = 1.0
	root_panel.anchor_bottom = 1.0
	root_panel.offset_left = -DRAWER_MAX_WIDTH * 0.5
	root_panel.offset_right = DRAWER_MAX_WIDTH * 0.5
	root_panel.offset_top = -DRAWER_HEIGHT
	root_panel.offset_bottom = 0.0
	root_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	drawer_root_container.add_child(root_panel)

	main_drawer_vbox = VBoxContainer.new()
	main_drawer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_drawer_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_drawer_vbox.add_theme_constant_override("separation", 4)
	main_drawer_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	root_panel.add_child(main_drawer_vbox)

	var strip_hbox: HBoxContainer = HBoxContainer.new()
	strip_hbox.add_theme_constant_override("separation", 6)
	strip_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	main_drawer_vbox.add_child(strip_hbox)

	btn_tab_assets = _create_compact_tab_btn("Assets", "icon_assets", func() -> void: _set_tray_mode(TrayMode.ASSETS))
	strip_hbox.add_child(btn_tab_assets)

	btn_tab_props = _create_compact_tab_btn("Props", "icon_props", func() -> void: _set_tray_mode(TrayMode.PROPS))
	strip_hbox.add_child(btn_tab_props)

	btn_tab_furniture = _create_compact_tab_btn("Furniture", "icon_furniture", func() -> void: _set_tray_mode(TrayMode.FURNITURE))
	strip_hbox.add_child(btn_tab_furniture)

	btn_tab_cast = _create_compact_tab_btn("Cast", "icon_cast", func() -> void: _set_tray_mode(TrayMode.CAST))
	strip_hbox.add_child(btn_tab_cast)

	strip_hbox.add_child(VSeparator.new())

	btn_import_art = _create_compact_tab_btn("Import", "icon_import", func() -> void:
		art_import_dialog.theme = ThemeService.create_theme()
		art_import_dialog.current_dir = UGCManager.get_default_import_directory()
		art_import_dialog.popup_centered_ratio(0.7)
	)
	strip_hbox.add_child(btn_import_art)

	btn_new_folder = _create_compact_tab_btn("Folder", "icon_folder", func() -> void:
		if folder_modal: folder_modal.open_modal()
	)
	strip_hbox.add_child(btn_new_folder)

	btn_batch_toggle = _create_compact_tab_btn("Select", "icon_clone", _toggle_batch_mode)
	strip_hbox.add_child(btn_batch_toggle)

	search_input = LineEdit.new()
	search_input.placeholder_text = "Search..."
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_input.custom_minimum_size = Vector2(100.0, 30.0)
	search_input.text_changed.connect(_on_search_query_changed)
	strip_hbox.add_child(search_input)

	btn_toggle_drawer = Button.new()
	btn_toggle_drawer.text = " ▼ "
	btn_toggle_drawer.tooltip_text = "Hide Drawer"
	btn_toggle_drawer.custom_minimum_size = Vector2(40.0, 30.0)
	btn_toggle_drawer.focus_mode = Control.FOCUS_NONE
	btn_toggle_drawer.pressed.connect(_toggle_drawer_state)
	strip_hbox.add_child(btn_toggle_drawer)

	var breadcrumb_row: HBoxContainer = HBoxContainer.new()
	breadcrumb_row.add_theme_constant_override("separation", 6)
	breadcrumb_row.mouse_filter = Control.MOUSE_FILTER_PASS
	main_drawer_vbox.add_child(breadcrumb_row)

	btn_back_up = Button.new()
	btn_back_up.text = " Up"
	btn_back_up.custom_minimum_size = Vector2(60.0, 26.0)
	btn_back_up.focus_mode = Control.FOCUS_NONE
	btn_back_up.add_theme_constant_override("icon_max_width", 14)
	btn_back_up.add_theme_font_size_override("font_size", 10)
	var up_icon: Texture2D = ThemeService.get_icon("icon_up")
	if up_icon: btn_back_up.icon = up_icon
	btn_back_up.pressed.connect(_navigate_up_one_folder)
	breadcrumb_row.add_child(btn_back_up)

	var breadcrumb_scroll: ScrollContainer = ScrollContainer.new()
	breadcrumb_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	breadcrumb_scroll.custom_minimum_size = Vector2(0.0, 26.0)
	breadcrumb_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	breadcrumb_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	breadcrumb_scroll.follow_focus = false
	breadcrumb_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	breadcrumb_row.add_child(breadcrumb_scroll)

	breadcrumbs_hbox = HBoxContainer.new()
	breadcrumbs_hbox.add_theme_constant_override("separation", 4)
	breadcrumbs_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	breadcrumb_scroll.add_child(breadcrumbs_hbox)

	var filter_scroll: ScrollContainer = ScrollContainer.new()
	filter_scroll.custom_minimum_size = Vector2(0.0, 28.0)
	filter_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	filter_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	filter_scroll.follow_focus = false
	filter_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	main_drawer_vbox.add_child(filter_scroll)

	filter_scroll_container = HBoxContainer.new()
	filter_scroll_container.add_theme_constant_override("separation", 4)
	filter_scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS
	filter_scroll.add_child(filter_scroll_container)

	_build_batch_action_bar()

	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.follow_focus = false
	scroll_container.scroll_deadzone = 12
	scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS
	main_drawer_vbox.add_child(scroll_container)

	items_grid = GridContainer.new()
	items_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_grid.add_theme_constant_override("h_separation", GRID_SPACING)
	items_grid.add_theme_constant_override("v_separation", GRID_SPACING)
	items_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll_container.add_child(items_grid)

	_set_tray_mode(TrayMode.ASSETS)


func _build_batch_action_bar() -> void:
	batch_bar_panel = PanelContainer.new()
	batch_bar_panel.theme_type_variation = "SubPanel"
	batch_bar_panel.custom_minimum_size = Vector2(0.0, 32.0)
	batch_bar_panel.visible = false
	main_drawer_vbox.add_child(batch_bar_panel)

	var bar_hbox: HBoxContainer = HBoxContainer.new()
	bar_hbox.add_theme_constant_override("separation", 8)
	bar_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	batch_bar_panel.add_child(bar_hbox)

	batch_count_lbl = Label.new()
	batch_count_lbl.text = "0 Selected"
	batch_count_lbl.theme_type_variation = "HeaderLabel"
	batch_count_lbl.add_theme_font_size_override("font_size", 10)
	bar_hbox.add_child(batch_count_lbl)

	btn_batch_select_all = Button.new()
	btn_batch_select_all.text = "All"
	btn_batch_select_all.focus_mode = Control.FOCUS_NONE
	btn_batch_select_all.add_theme_font_size_override("font_size", 9)
	btn_batch_select_all.pressed.connect(_select_all_visible_items)
	bar_hbox.add_child(btn_batch_select_all)

	btn_batch_deselect_all = Button.new()
	btn_batch_deselect_all.text = "None"
	btn_batch_deselect_all.focus_mode = Control.FOCUS_NONE
	btn_batch_deselect_all.add_theme_font_size_override("font_size", 9)
	btn_batch_deselect_all.pressed.connect(_deselect_all_items)
	bar_hbox.add_child(btn_batch_deselect_all)

	bar_hbox.add_child(VSeparator.new())

	btn_batch_organize = Button.new()
	btn_batch_organize.text = " Organize..."
	btn_batch_organize.focus_mode = Control.FOCUS_NONE
	btn_batch_organize.add_theme_font_size_override("font_size", 10)
	btn_batch_organize.add_theme_constant_override("icon_max_width", 12)
	var tag_icon: Texture2D = ThemeService.get_icon("icon_tag")
	if tag_icon: btn_batch_organize.icon = tag_icon
	btn_batch_organize.pressed.connect(_on_batch_organize_pressed)
	bar_hbox.add_child(btn_batch_organize)

	btn_batch_delete = Button.new()
	btn_batch_delete.text = " Delete Batch"
	btn_batch_delete.theme_type_variation = "DangerButton"
	btn_batch_delete.focus_mode = Control.FOCUS_NONE
	btn_batch_delete.add_theme_font_size_override("font_size", 10)
	btn_batch_delete.add_theme_constant_override("icon_max_width", 12)
	var del_icon: Texture2D = ThemeService.get_icon("icon_close")
	if del_icon: btn_batch_delete.icon = del_icon
	btn_batch_delete.pressed.connect(_on_batch_delete_pressed)
	bar_hbox.add_child(btn_batch_delete)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_hbox.add_child(spacer)

	btn_batch_done = Button.new()
	btn_batch_done.text = " Done"
	btn_batch_done.custom_minimum_size = Vector2(60.0, 24.0)
	btn_batch_done.focus_mode = Control.FOCUS_NONE
	btn_batch_done.add_theme_font_size_override("font_size", 10)
	btn_batch_done.pressed.connect(func() -> void: _set_batch_mode(false))
	bar_hbox.add_child(btn_batch_done)


func _apply_theme() -> void:
	var global_theme: Theme = ThemeService.create_theme()
	if toggle_pill_container: toggle_pill_container.theme = global_theme
	if drawer_root_container: drawer_root_container.theme = global_theme

	var c_bg: Color = ThemeService.get_color("panel_background", "#fff5f7")
	var c_border: Color = ThemeService.get_color("panel_border", "#f9a8d4")
	var rad: int = ThemeService.get_corner_radius()

	var dock_style: StyleBoxFlat = StyleBoxFlat.new()
	dock_style.bg_color = c_bg
	dock_style.border_color = c_border
	dock_style.border_width_left = 2
	dock_style.border_width_right = 2
	dock_style.border_width_top = 2
	dock_style.border_width_bottom = 0
	dock_style.corner_radius_top_left = rad + 2
	dock_style.corner_radius_top_right = rad + 2
	dock_style.content_margin_left = 10
	dock_style.content_margin_right = 10
	dock_style.content_margin_top = 8
	dock_style.content_margin_bottom = 6
	root_panel.add_theme_stylebox_override("panel", dock_style)

	_update_tab_buttons_appearance()
	_render_breadcrumbs()
	_build_category_filter_buttons()


func _build_modals() -> void:
	folder_modal = DrawerFolderModal.new()
	folder_modal.folder_create_confirmed.connect(_on_folder_created_by_modal)
	add_child(folder_modal)

	organize_modal = DrawerOrganizeModal.new()
	organize_modal.organization_saved.connect(_on_organization_saved_by_modal)
	organize_modal.batch_organization_saved.connect(_on_batch_organization_saved)
	organize_modal.tag_deleted.connect(_delete_tag_globally)
	organize_modal.custom_tag_added.connect(_on_custom_tag_added_by_modal)
	add_child(organize_modal)


func _create_compact_tab_btn(title: String, icon_key: String, callback: Callable) -> Button:
	var btn: Button = Button.new()
	btn.text = " " + title
	btn.custom_minimum_size = Vector2(0.0, 30.0)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_constant_override("icon_max_width", 14)
	btn.add_theme_font_size_override("font_size", 10)
	var icon_tex: Texture2D = ThemeService.get_icon(icon_key)
	if icon_tex: btn.icon = icon_tex
	btn.pressed.connect(callback)
	return btn


func _toggle_drawer_state() -> void:
	is_drawer_open = not is_drawer_open
	toggle_pill_container.visible = not is_drawer_open
	drawer_root_container.visible = is_drawer_open
	if is_drawer_open:
		_update_responsive_columns()
		refresh_tray()


func _toggle_batch_mode() -> void:
	_set_batch_mode(not is_batch_mode)


func _set_batch_mode(enabled: bool) -> void:
	is_batch_mode = enabled
	selected_batch_items.clear()
	batch_bar_panel.visible = is_batch_mode
	_update_batch_count_label()
	_update_tab_buttons_appearance()
	refresh_tray()


func _update_batch_count_label() -> void:
	if batch_count_lbl:
		batch_count_lbl.text = str(selected_batch_items.size()) + " Selected"


func _set_tray_mode(mode: TrayMode) -> void:
	current_mode = mode
	current_folder_path = ""
	active_category_filter = "All"
	active_search_query = ""
	selected_batch_items.clear()
	if search_input: search_input.text = ""

	_update_tab_buttons_appearance()
	btn_import_art.visible = (mode == TrayMode.ASSETS)
	_render_breadcrumbs()
	_build_category_filter_buttons()
	if is_drawer_open:
		_update_responsive_columns()
		refresh_tray()


func _update_tab_buttons_appearance() -> void:
	var c_accent: Color = ThemeService.get_color("accent_primary", "#ec4899")
	var rad: int = ThemeService.get_corner_radius()

	var tabs: Array[Dictionary] = [
		{"btn": btn_tab_assets, "active": current_mode == TrayMode.ASSETS},
		{"btn": btn_tab_props, "active": current_mode == TrayMode.PROPS},
		{"btn": btn_tab_furniture, "active": current_mode == TrayMode.FURNITURE},
		{"btn": btn_tab_cast, "active": current_mode == TrayMode.CAST},
		{"btn": btn_batch_toggle, "active": is_batch_mode}
	]

	for t: Dictionary in tabs:
		var btn: Button = t["btn"] as Button
		if not is_instance_valid(btn): continue
		var is_active: bool = bool(t["active"])

		btn.remove_theme_stylebox_override("normal")
		btn.remove_theme_stylebox_override("hover")
		btn.remove_theme_stylebox_override("pressed")
		btn.remove_theme_color_override("font_color")
		btn.remove_theme_color_override("icon_normal_color")

		if is_active:
			var s_act: StyleBoxFlat = StyleBoxFlat.new()
			s_act.bg_color = c_accent
			s_act.border_color = c_accent
			s_act.set_border_width_all(1)
			s_act.set_corner_radius_all(rad)
			s_act.content_margin_left = 8
			s_act.content_margin_right = 8
			s_act.content_margin_top = 4
			s_act.content_margin_bottom = 4

			btn.add_theme_stylebox_override("normal", s_act)
			btn.add_theme_stylebox_override("hover", s_act)
			btn.add_theme_stylebox_override("pressed", s_act)
			btn.add_theme_color_override("font_color", Color.WHITE)
			btn.add_theme_color_override("icon_normal_color", Color.WHITE)


func _update_responsive_columns() -> void:
	if not is_instance_valid(root_panel) or not is_instance_valid(items_grid): return
	var win_w: float = get_viewport().get_visible_rect().size.x if get_viewport() else 1152.0
	var target_w: float = minf(DRAWER_MAX_WIDTH, win_w - 24.0)
	if target_w < 300.0: target_w = 300.0

	root_panel.offset_left = -target_w * 0.5
	root_panel.offset_right = target_w * 0.5
	root_panel.offset_top = -DRAWER_HEIGHT
	root_panel.offset_bottom = 0.0
	root_panel.custom_minimum_size = Vector2(target_w, DRAWER_HEIGHT)

	var usable_w: float = target_w - 28.0
	var col_stride: float = CARD_WIDTH + float(GRID_SPACING)
	var max_cols: int = int((usable_w + float(GRID_SPACING)) / col_stride)
	items_grid.columns = clampi(max_cols, 3, 10)


func _render_breadcrumbs() -> void:
	for child: Node in breadcrumbs_hbox.get_children():
		child.queue_free()

	btn_back_up.disabled = (current_folder_path == "" or current_folder_path == "Root")
	var btn_root: Button = _create_breadcrumb_pill("Root", "icon_room", current_folder_path == "" or current_folder_path == "Root")
	btn_root.pressed.connect(func() -> void:
		current_folder_path = ""
		_render_breadcrumbs()
		refresh_tray()
	)
	breadcrumbs_hbox.add_child(btn_root)

	if current_folder_path != "" and current_folder_path != "Root":
		var parts: PackedStringArray = current_folder_path.split("/", false)
		var accum: String = ""
		for i: int in range(parts.size()):
			var sep: Label = Label.new()
			sep.text = ">"
			sep.theme_type_variation = "HintLabel"
			breadcrumbs_hbox.add_child(sep)

			accum = parts[i] if accum == "" else accum + "/" + parts[i]
			var is_current: bool = (i == parts.size() - 1)
			var btn_part: Button = _create_breadcrumb_pill(parts[i], "icon_folder", is_current)
			var target_p: String = accum
			btn_part.pressed.connect(func() -> void:
				current_folder_path = target_p
				_render_breadcrumbs()
				refresh_tray()
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
	if current_folder_path == "" or current_folder_path == "Root": return
	if "/" in current_folder_path:
		var parts: PackedStringArray = current_folder_path.split("/", false)
		parts.remove_at(parts.size() - 1)
		current_folder_path = "/".join(parts)
	else:
		current_folder_path = ""
	_render_breadcrumbs()
	refresh_tray()


func _create_folder_grid_card(folder_name: String) -> void:
	var card: Button = Button.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
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
	vbox.offset_left = 3.0
	vbox.offset_top = 3.0
	vbox.offset_right = -3.0
	vbox.offset_bottom = -3.0
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_theme_constant_override("separation", 2)
	action_row.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(action_row)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_row.add_child(spacer)

	var btn_del_folder: Button = _create_card_icon_btn("icon_close", true)
	var cap_fname: String = folder_name
	btn_del_folder.pressed.connect(func() -> void: _request_delete_folder(cap_fname))
	action_row.add_child(btn_del_folder)

	var icon_box: PanelContainer = PanelContainer.new()
	icon_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_box.custom_minimum_size = Vector2(0.0, 34.0)
	icon_box.clip_contents = true
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var t_style: StyleBoxFlat = StyleBoxFlat.new()
	t_style.bg_color = ThemeService.get_color("input_background", "#ffffff")
	t_style.border_color = ThemeService.get_color("panel_border", "#f472b6")
	t_style.set_border_width_all(1)
	t_style.set_corner_radius_all(4)
	icon_box.add_theme_stylebox_override("panel", t_style)

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var f_icon: Texture2D = ThemeService.get_icon("icon_folder")
	if f_icon:
		icon_rect.texture = f_icon
		icon_rect.modulate = ThemeService.get_color("accent_primary", "#db2777")
	icon_box.add_child(icon_rect)
	vbox.add_child(icon_box)

	var label_box: PanelContainer = PanelContainer.new()
	label_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_box.custom_minimum_size = Vector2(0.0, 18.0)
	label_box.clip_contents = true
	label_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var l_style: StyleBoxFlat = t_style.duplicate() as StyleBoxFlat
	l_style.content_margin_left = 2
	l_style.content_margin_right = 2
	l_style.content_margin_top = 1
	l_style.content_margin_bottom = 1
	label_box.add_theme_stylebox_override("panel", l_style)

	var name_lbl: Label = Label.new()
	name_lbl.text = folder_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.clip_text = true
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_box.add_child(name_lbl)
	vbox.add_child(label_box)

	card.pressed.connect(func() -> void:
		if current_folder_path == "" or current_folder_path == "Root": current_folder_path = cap_fname
		else: current_folder_path = current_folder_path + "/" + cap_fname
		_render_breadcrumbs()
		refresh_tray()
	)
	items_grid.add_child(card)


func refresh_tray() -> void:
	for child: Node in items_grid.get_children():
		child.queue_free()

	match current_mode:
		TrayMode.ASSETS: _render_assets_tab()
		TrayMode.PROPS: _render_templates_tab(_get_props_path(), Types.EntityType.PROP, "props")
		TrayMode.FURNITURE: _render_templates_tab(_get_furniture_path(), Types.EntityType.FURNITURE, "furniture")
		TrayMode.CAST: _render_cast_tab()


func _render_assets_tab() -> void:
	var norm_folder: String = current_folder_path.replace("\\", "/").strip_edges().trim_prefix("/").trim_suffix("/")
	if norm_folder == "Root": norm_folder = ""

	if not is_batch_mode and active_search_query == "" and active_category_filter == "All":
		var direct_subfolders: Array[String] = UGCManager.get_subfolders_in_art_folder(norm_folder)
		for sub: String in direct_subfolders:
			_create_folder_grid_card(sub)

	var art_files: Array[Dictionary] = []
	if active_search_query != "" or active_category_filter != "All":
		art_files = UGCManager.scan_user_art_library()
	else:
		art_files = UGCManager.get_files_in_art_folder(norm_folder)

	for art_data: Dictionary in art_files:
		var fname: String = str(art_data.get("name", "Art"))
		var f_path: String = str(art_data.get("folder", "")).replace("\\", "/").strip_edges().trim_prefix("/").trim_suffix("/")
		var tags: Array = asset_tags_registry.get(fname, ["#props"]) as Array

		if active_search_query != "":
			var matches: bool = (active_search_query in fname.to_lower()) or (active_search_query in f_path.to_lower())
			for t: Variant in tags:
				if active_search_query in str(t).to_lower():
					matches = true
					break
			if not matches: continue
		elif active_category_filter != "All":
			if not (active_category_filter in tags): continue
		else:
			if f_path != norm_folder: continue

		_create_asset_card(art_data)


func _create_asset_card(art_data: Dictionary) -> void:
	var fname: String = str(art_data.get("name", "Art"))
	var fpath: String = str(art_data.get("file_path", ""))
	var item_key: String = fpath
	var is_selected: bool = selected_batch_items.has(item_key)

	var card: Button = Button.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	card.focus_mode = Control.FOCUS_NONE
	_apply_card_selection_style(card, is_selected)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 3.0
	vbox.offset_top = 3.0
	vbox.offset_right = -3.0
	vbox.offset_bottom = -3.0
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_theme_constant_override("separation", 2)
	action_row.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(action_row)

	if is_batch_mode:
		var chk: CheckBox = CheckBox.new()
		chk.button_pressed = is_selected
		chk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chk.custom_minimum_size = Vector2(16.0, 16.0)
		action_row.add_child(chk)
	else:
		var btn_tag: Button = _create_card_icon_btn("icon_tag", false)
		btn_tag.pressed.connect(func() -> void: _open_organizer_for_item(art_data, "assets"))
		action_row.add_child(btn_tag)

		var spacer: Control = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		action_row.add_child(spacer)

		var btn_del: Button = _create_card_icon_btn("icon_close", true)
		btn_del.pressed.connect(func() -> void: _delete_art_file(fpath, fname))
		action_row.add_child(btn_del)

	var tex: Texture2D = UGCManager.get_thumbnail(fpath)
	_attach_card_visuals(vbox, tex, fname)

	card.pressed.connect(func() -> void:
		if is_batch_mode:
			_toggle_item_batch_selection(item_key, art_data)
		else:
			var full_tex: Texture2D = UGCManager.load_texture_from_file(fpath)
			spawn_ugc_requested.emit(fname, full_tex, fpath)
			_notify("Spawned: " + fname, true)
	)
	items_grid.add_child(card)


func _render_templates_tab(file_path: String, type: Types.EntityType, category_key: String) -> void:
	var templates: Array[Dictionary] = DrawerMetadataService.load_template_array(file_path)
	var norm_folder: String = current_folder_path.strip_edges().trim_prefix("/").trim_suffix("/")
	if norm_folder == "Root": norm_folder = ""

	var subfolders: Array[String] = []
	var raw_folders: Array = user_registered_folders.get(category_key, [])
	for reg_f_var: Variant in raw_folders:
		var reg_f: String = str(reg_f_var).strip_edges().trim_prefix("/").trim_suffix("/")
		if norm_folder == "" and reg_f != "":
			var direct_c: String = reg_f.split("/")[0]
			if not direct_c in subfolders: subfolders.append(direct_c)
		elif norm_folder != "" and reg_f.begins_with(norm_folder + "/"):
			var rem: String = reg_f.trim_prefix(norm_folder + "/")
			var direct_c: String = rem.split("/")[0]
			if not direct_c in subfolders: subfolders.append(direct_c)

	if not is_batch_mode and active_search_query == "" and active_category_filter == "All":
		for sub: String in subfolders:
			_create_folder_grid_card(sub)

	for i: int in range(templates.size()):
		var data: Dictionary = templates[i]
		var item_name: String = str(data.get("display_name", "Template"))
		var img_path: String = str(data.get("texture_path", ""))
		var f_path: String = str(data.get("folder", "")).strip_edges().trim_prefix("/").trim_suffix("/")
		var tags: Array = data.get("tags", ["#props" if type == Types.EntityType.PROP else "#furniture"])
		var item_key: String = str(data.get("id", str(i)))
		var is_selected: bool = selected_batch_items.has(item_key)

		if active_search_query != "":
			var matches: bool = (active_search_query in item_name.to_lower()) or (active_search_query in f_path.to_lower())
			for t: Variant in tags:
				if active_search_query in str(t).to_lower():
					matches = true
					break
			if not matches: continue
		elif active_category_filter != "All":
			if not (active_category_filter in tags): continue
		else:
			if f_path != norm_folder: continue

		var tex: Texture2D = UGCManager.get_thumbnail(img_path)
		
		var card: Button = Button.new()
		card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.clip_contents = true
		card.focus_mode = Control.FOCUS_NONE
		_apply_card_selection_style(card, is_selected)

		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.offset_left = 3.0
		vbox.offset_top = 3.0
		vbox.offset_right = -3.0
		vbox.offset_bottom = -3.0
		vbox.add_theme_constant_override("separation", 2)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(vbox)

		var action_row: HBoxContainer = HBoxContainer.new()
		action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_row.add_theme_constant_override("separation", 2)
		action_row.mouse_filter = Control.MOUSE_FILTER_PASS
		vbox.add_child(action_row)

		var cap_data: Dictionary = data
		var cap_idx: int = i

		if is_batch_mode:
			var chk: CheckBox = CheckBox.new()
			chk.button_pressed = is_selected
			chk.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chk.custom_minimum_size = Vector2(16.0, 16.0)
			action_row.add_child(chk)
		else:
			var btn_tag: Button = _create_card_icon_btn("icon_tag", false)
			btn_tag.pressed.connect(func() -> void: _open_organizer_for_item(cap_data, category_key, cap_idx))
			action_row.add_child(btn_tag)

			var btn_dup: Button = _create_card_icon_btn("icon_clone", false)
			btn_dup.pressed.connect(func() -> void: _duplicate_template_in_file(file_path, cap_data))
			action_row.add_child(btn_dup)

			var btn_del: Button = _create_card_icon_btn("icon_close", true)
			btn_del.pressed.connect(func() -> void: _delete_template_from_file(file_path, cap_idx))
			action_row.add_child(btn_del)

		_attach_card_visuals(vbox, tex, item_name)

		card.pressed.connect(func() -> void:
			if is_batch_mode:
				var payload: Dictionary = cap_data.duplicate(true)
				payload["__index"] = cap_idx
				_toggle_item_batch_selection(item_key, payload)
			else:
				template_spawn_requested.emit(cap_data)
				_notify("Spawned: " + item_name, true)
		)
		items_grid.add_child(card)


func _render_cast_tab() -> void:
	var raw_cast_list: Array[Dictionary] = _load_cast_data()
	var norm_folder: String = current_folder_path.strip_edges().trim_prefix("/").trim_suffix("/")
	if norm_folder == "Root": norm_folder = ""

	var subfolders: Array[String] = []
	var raw_folders: Array = user_registered_folders.get("cast", [])
	for reg_f_var: Variant in raw_folders:
		var reg_f: String = str(reg_f_var).strip_edges().trim_prefix("/").trim_suffix("/")
		if norm_folder == "" and reg_f != "":
			var direct_c: String = reg_f.split("/")[0]
			if not direct_c in subfolders: subfolders.append(direct_c)
		elif norm_folder != "" and reg_f.begins_with(norm_folder + "/"):
			var rem: String = reg_f.trim_prefix(norm_folder + "/")
			var direct_c: String = rem.split("/")[0]
			if not direct_c in subfolders: subfolders.append(direct_c)

	if not is_batch_mode and active_search_query == "" and active_category_filter == "All":
		for sub: String in subfolders:
			_create_folder_grid_card(sub)

	var seen_characters: Dictionary = {}

	for i: int in range(raw_cast_list.size()):
		var char_data: Dictionary = raw_cast_list[i]
		var c_name: String = str(char_data.get("display_name", "Character"))
		var c_id: String = str(char_data.get("id", ""))
		var name_key: String = c_name.strip_edges().to_lower()
		var item_key: String = c_id if not c_id.is_empty() else name_key
		var is_selected: bool = selected_batch_items.has(item_key)

		if seen_characters.has(c_id) or (not name_key.is_empty() and seen_characters.has(name_key)):
			continue
		if not c_id.is_empty(): seen_characters[c_id] = true
		if not name_key.is_empty(): seen_characters[name_key] = true

		var c_path: String = str(char_data.get("texture_path", ""))
		var f_path: String = str(char_data.get("folder", "")).strip_edges().trim_prefix("/").trim_suffix("/")
		var tags: Array = char_data.get("tags", ["#characters"])

		if active_search_query != "":
			var matches: bool = (active_search_query in c_name.to_lower()) or (active_search_query in f_path.to_lower())
			for t: Variant in tags:
				if active_search_query in str(t).to_lower():
					matches = true
					break
			if not matches: continue
		elif active_category_filter != "All":
			if not (active_category_filter in tags): continue
		else:
			if f_path != norm_folder: continue

		var tex: Texture2D = UGCManager.get_thumbnail(c_path)
		
		var card: Button = Button.new()
		card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.clip_contents = true
		card.focus_mode = Control.FOCUS_NONE
		_apply_card_selection_style(card, is_selected)

		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.offset_left = 3.0
		vbox.offset_top = 3.0
		vbox.offset_right = -3.0
		vbox.offset_bottom = -3.0
		vbox.add_theme_constant_override("separation", 2)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(vbox)

		var action_row: HBoxContainer = HBoxContainer.new()
		action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_row.add_theme_constant_override("separation", 2)
		action_row.mouse_filter = Control.MOUSE_FILTER_PASS
		vbox.add_child(action_row)

		var cap_data: Dictionary = char_data
		var cap_idx: int = i

		if is_batch_mode:
			var chk: CheckBox = CheckBox.new()
			chk.button_pressed = is_selected
			chk.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chk.custom_minimum_size = Vector2(16.0, 16.0)
			action_row.add_child(chk)
		else:
			var btn_tag: Button = _create_card_icon_btn("icon_tag", false)
			btn_tag.pressed.connect(func() -> void: _open_organizer_for_item(cap_data, "cast", cap_idx))
			action_row.add_child(btn_tag)

			var btn_dup: Button = _create_card_icon_btn("icon_clone", false)
			btn_dup.pressed.connect(func() -> void: _duplicate_cast_character(cap_idx, cap_data))
			action_row.add_child(btn_dup)

			var btn_del: Button = _create_card_icon_btn("icon_close", true)
			btn_del.pressed.connect(func() -> void: _delete_character_from_cast(cap_data))
			action_row.add_child(btn_del)

		_attach_card_visuals(vbox, tex, c_name)

		# Setup Hold-Down (Long-Press) to recall character from room to tray
		_setup_cast_card_gestures(card, cap_data, item_key, cap_idx)
		items_grid.add_child(card)


## Attaches hold-down detection to Cast character cards cleanly using by-reference state
func _setup_cast_card_gestures(card: Button, cap_data: Dictionary, item_key: String, cap_idx: int) -> void:
	var press_state: Dictionary = {
		"is_holding": false,
		"fired": false,
		"start_pos": Vector2.ZERO,
		"timer": null
	}

	card.gui_input.connect(func(event: InputEvent) -> void:
		if is_batch_mode:
			return

		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					press_state["is_holding"] = true
					press_state["fired"] = false
					press_state["start_pos"] = mb.global_position
					var hold_dur: float = SettingsManager.get_long_press_duration()

					var timer: SceneTreeTimer = get_tree().create_timer(hold_dur)
					press_state["timer"] = timer
					timer.timeout.connect(func() -> void:
						if bool(press_state.get("is_holding", false)) and not bool(press_state.get("fired", false)):
							press_state["fired"] = true
							_recall_character_to_tray(cap_data)
					)
				else:
					var was_fired: bool = bool(press_state.get("fired", false))
					press_state["is_holding"] = false
					if was_fired:
						card.release_focus()

		elif event is InputEventMouseMotion:
			var mm: InputEventMouseMotion = event as InputEventMouseMotion
			if bool(press_state.get("is_holding", false)):
				var start_p: Vector2 = press_state.get("start_pos", Vector2.ZERO) as Vector2
				if start_p.distance_to(mm.global_position) > DRAG_CANCEL_THRESHOLD:
					press_state["is_holding"] = false

		elif event is InputEventScreenTouch:
			var st: InputEventScreenTouch = event as InputEventScreenTouch
			if st.pressed:
				press_state["is_holding"] = true
				press_state["fired"] = false
				press_state["start_pos"] = st.position
				var hold_dur: float = SettingsManager.get_long_press_duration()

				var timer: SceneTreeTimer = get_tree().create_timer(hold_dur)
				press_state["timer"] = timer
				timer.timeout.connect(func() -> void:
					if bool(press_state.get("is_holding", false)) and not bool(press_state.get("fired", false)):
						press_state["fired"] = true
						_recall_character_to_tray(cap_data)
				)
			else:
				var was_fired: bool = bool(press_state.get("fired", false))
				press_state["is_holding"] = false
				if was_fired:
					card.release_focus()

		elif event is InputEventScreenDrag:
			var sd: InputEventScreenDrag = event as InputEventScreenDrag
			if bool(press_state.get("is_holding", false)):
				var start_p: Vector2 = press_state.get("start_pos", Vector2.ZERO) as Vector2
				if start_p.distance_to(sd.position) > DRAG_CANCEL_THRESHOLD:
					press_state["is_holding"] = false
	)

	card.pressed.connect(func() -> void:
		if bool(press_state.get("fired", false)):
			press_state["fired"] = false
			return
		if is_batch_mode:
			var payload: Dictionary = cap_data.duplicate(true)
			payload["__index"] = cap_idx
			_toggle_item_batch_selection(item_key, payload)
		else:
			_spawn_and_relocate_character_from_cast(cap_data)
	)


## Recalls an active character from the room back into the Cast Tray
func _recall_character_to_tray(char_data: Dictionary) -> void:
	var c_name: String = str(char_data.get("display_name", "Character"))
	var c_id: String = str(char_data.get("id", ""))
	var name_key: String = c_name.strip_edges().to_lower()

	var tree: SceneTree = get_tree()
	var live_character_node: OwnEntity = null

	if tree != null:
		for node: Node in tree.get_nodes_in_group("characters"):
			if node is OwnEntity:
				var ent: OwnEntity = node as OwnEntity
				var is_id_match: bool = not c_id.is_empty() and ent.entity_id == c_id
				var is_name_match: bool = not name_key.is_empty() and ent.display_name.strip_edges().to_lower() == name_key
				if is_id_match or is_name_match:
					live_character_node = ent
					break

	if live_character_node != null and is_instance_valid(live_character_node):
		# Store the character back into cast data with updated fields
		store_character_in_tray(live_character_node)
		SaveSystem.save_current_room_state()
		_trigger_haptic(45)
		AudioManager.play_drop_cushion()
		_notify("Recalled %s to Cast Tray" % c_name, true)
	else:
		# If not in active room, scrub from room files and ensure safely saved in Cast
		DrawerMetadataService.scrub_character_from_universe_rooms(c_id, c_name)
		var cast_list: Array[Dictionary] = _load_cast_data()
		var found: bool = false
		for item in cast_list:
			if str(item.get("id", "")) == c_id or str(item.get("display_name", "")).strip_edges().to_lower() == name_key:
				found = true
				break
		if not found:
			cast_list.append(char_data.duplicate(true))
			_save_cast_data(cast_list)

		_trigger_haptic(30)
		AudioManager.play_pop_grab()
		_notify("%s is ready in Cast Tray" % c_name, true)

	refresh_tray()


func _apply_card_selection_style(card: Button, is_selected: bool) -> void:
	var c_bg: Color = ThemeService.get_color("container_sub_bg", "#fdf2f4")
	var c_border: Color = ThemeService.get_color("panel_border", "#f472b6")
	var c_accent: Color = ThemeService.get_color("accent_primary", "#db2777")
	
	var s_normal: StyleBoxFlat = StyleBoxFlat.new()
	s_normal.bg_color = Color(c_accent.r, c_accent.g, c_accent.b, 0.15) if is_selected else c_bg
	s_normal.border_color = c_accent if is_selected else c_border
	s_normal.set_border_width_all(2 if is_selected else 1)
	s_normal.set_corner_radius_all(4)
	
	card.add_theme_stylebox_override("normal", s_normal)
	
	var s_hover: StyleBoxFlat = s_normal.duplicate() as StyleBoxFlat
	s_hover.border_color = c_accent
	card.add_theme_stylebox_override("hover", s_hover)
	card.add_theme_stylebox_override("pressed", s_hover)
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _toggle_item_batch_selection(key: String, data: Dictionary) -> void:
	if selected_batch_items.has(key): selected_batch_items.erase(key)
	else: selected_batch_items[key] = data
	_update_batch_count_label()
	refresh_tray()


func _select_all_visible_items() -> void:
	match current_mode:
		TrayMode.ASSETS:
			var art_files: Array[Dictionary] = UGCManager.scan_user_art_library()
			for art: Dictionary in art_files:
				selected_batch_items[str(art.get("file_path", ""))] = art
		TrayMode.PROPS, TrayMode.FURNITURE:
			var path: String = _get_props_path() if current_mode == TrayMode.PROPS else _get_furniture_path()
			var templates: Array[Dictionary] = DrawerMetadataService.load_template_array(path)
			for i: int in range(templates.size()):
				var d: Dictionary = templates[i].duplicate(true)
				d["__index"] = i
				selected_batch_items[str(d.get("id", str(i)))] = d
		TrayMode.CAST:
			var cast_list: Array[Dictionary] = _load_cast_data()
			for i: int in range(cast_list.size()):
				var d: Dictionary = cast_list[i].duplicate(true)
				d["__index"] = i
				selected_batch_items[str(d.get("id", str(i)))] = d
	_update_batch_count_label()
	refresh_tray()


func _deselect_all_items() -> void:
	selected_batch_items.clear()
	_update_batch_count_label()
	refresh_tray()


func _on_batch_organize_pressed() -> void:
	if selected_batch_items.is_empty():
		_notify("Please select at least 1 item first.", true)
		return

	var mode_key: String = "assets" if current_mode == TrayMode.ASSETS else ("props" if current_mode == TrayMode.PROPS else ("furniture" if current_mode == TrayMode.FURNITURE else "cast"))
	var folder_list: Array[String] = []
	if current_mode == TrayMode.ASSETS:
		folder_list = UGCManager.get_all_art_folders()
	else:
		var raw_folders: Array = user_registered_folders.get(mode_key, [])
		for f: Variant in raw_folders: folder_list.append(str(f))

	var item_arr: Array[Dictionary] = []
	for k: String in selected_batch_items.keys():
		item_arr.append(selected_batch_items[k] as Dictionary)

	organize_modal.open_batch_organizer(item_arr, mode_key, user_available_tags, folder_list)


func _on_batch_delete_pressed() -> void:
	if selected_batch_items.is_empty(): return
	var count: int = selected_batch_items.size()

	if current_mode == TrayMode.ASSETS:
		for k: String in selected_batch_items.keys():
			var item: Dictionary = selected_batch_items[k]
			_delete_art_file(str(item.get("file_path", "")), str(item.get("name", "")))
	elif current_mode == TrayMode.PROPS or current_mode == TrayMode.FURNITURE:
		var file_path: String = _get_props_path() if current_mode == TrayMode.PROPS else _get_furniture_path()
		var templates: Array[Dictionary] = DrawerMetadataService.load_template_array(file_path)
		var ids_to_remove: Dictionary = {}
		for k: String in selected_batch_items.keys(): ids_to_remove[k] = true
		for i: int in range(templates.size() - 1, -1, -1):
			if ids_to_remove.has(str(templates[i].get("id", ""))):
				templates.remove_at(i)
		DrawerMetadataService.save_template_array(file_path, templates)
	elif current_mode == TrayMode.CAST:
		for k: String in selected_batch_items.keys():
			_delete_character_from_cast(selected_batch_items[k])

	selected_batch_items.clear()
	_update_batch_count_label()
	_notify("Batch Deleted " + str(count) + " items.", true)
	refresh_tray()


func _on_batch_organization_saved(items: Array[Dictionary], mode_type: String, target_folder: String, chosen_tags: Array[String]) -> void:
	if mode_type == "assets":
		for item: Dictionary in items:
			var fname: String = str(item.get("name", ""))
			var fpath: String = str(item.get("file_path", ""))
			if not chosen_tags.is_empty():
				var existing: Array = asset_tags_registry.get(fname, []).duplicate()
				for t: String in chosen_tags:
					if not (t in existing): existing.append(t)
				asset_tags_registry[fname] = existing
			if target_folder != "__KEEP__":
				UGCManager.move_art_file(fpath, target_folder)
	elif mode_type == "props" or mode_type == "furniture":
		var file_path: String = _get_props_path() if mode_type == "props" else _get_furniture_path()
		var templates: Array[Dictionary] = DrawerMetadataService.load_template_array(file_path)
		var id_map: Dictionary = {}
		for item: Dictionary in items: id_map[str(item.get("id", ""))] = true
		for t_entry: Dictionary in templates:
			if id_map.has(str(t_entry.get("id", ""))):
				if target_folder != "__KEEP__":
					t_entry["folder"] = "" if target_folder == "Root" else target_folder
				if not chosen_tags.is_empty():
					var cur_t: Array = t_entry.get("tags", []).duplicate()
					for t: String in chosen_tags:
						if not (t in cur_t): cur_t.append(t)
					t_entry["tags"] = cur_t
		DrawerMetadataService.save_template_array(file_path, templates)
	elif mode_type == "cast":
		var cast_list: Array[Dictionary] = _load_cast_data()
		var id_map: Dictionary = {}
		for item: Dictionary in items: id_map[str(item.get("id", ""))] = true
		for c_entry: Dictionary in cast_list:
			if id_map.has(str(c_entry.get("id", ""))):
				if target_folder != "__KEEP__":
					c_entry["folder"] = "" if target_folder == "Root" else target_folder
				if not chosen_tags.is_empty():
					var cur_t: Array = c_entry.get("tags", []).duplicate()
					for t: String in chosen_tags:
						if not (t in cur_t): cur_t.append(t)
					c_entry["tags"] = cur_t
		_save_cast_data(cast_list)

	_save_all_metadata()
	selected_batch_items.clear()
	_update_batch_count_label()
	_notify("Batch organization saved (" + str(items.size()) + " items)", true)
	refresh_tray()


func _create_card_icon_btn(icon_key: String, is_danger: bool = false) -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(18.0, 18.0)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.add_theme_constant_override("icon_max_width", 12)

	var s_btn: StyleBoxFlat = StyleBoxFlat.new()
	s_btn.bg_color = ThemeService.get_color("danger_color", "#f43f5e") if is_danger else ThemeService.get_color("container_sub_bg", "#fdf2f4")
	s_btn.border_color = ThemeService.get_color("panel_border", "#f472b6")
	s_btn.set_border_width_all(1)
	s_btn.set_corner_radius_all(3)
	s_btn.content_margin_left = 1
	s_btn.content_margin_right = 1
	s_btn.content_margin_top = 1
	s_btn.content_margin_bottom = 1
	btn.add_theme_stylebox_override("normal", s_btn)

	var s_hover: StyleBoxFlat = s_btn.duplicate() as StyleBoxFlat
	s_hover.border_color = ThemeService.get_color("accent_primary", "#db2777")
	if not is_danger:
		s_hover.bg_color = ThemeService.get_color("accent_primary", "#db2777")
	btn.add_theme_stylebox_override("hover", s_hover)
	btn.add_theme_stylebox_override("pressed", s_hover)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var icon_tex: Texture2D = ThemeService.get_icon(icon_key)
	if icon_tex:
		btn.icon = icon_tex
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	else:
		btn.text = "✕" if is_danger else "•"
		btn.add_theme_font_size_override("font_size", 9)
	return btn


func _attach_card_visuals(vbox: VBoxContainer, tex: Texture2D, label_text: String) -> void:
	var thumb_box: PanelContainer = PanelContainer.new()
	thumb_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thumb_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	thumb_box.custom_minimum_size = Vector2(0.0, 34.0)
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

	var label_box: PanelContainer = PanelContainer.new()
	label_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_box.custom_minimum_size = Vector2(0.0, 18.0)
	label_box.clip_contents = true
	label_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var l_style: StyleBoxFlat = t_style.duplicate() as StyleBoxFlat
	l_style.content_margin_left = 2
	l_style.content_margin_right = 2
	l_style.content_margin_top = 1
	l_style.content_margin_bottom = 1
	label_box.add_theme_stylebox_override("panel", l_style)

	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.clip_text = true
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_box.add_child(lbl)
	vbox.add_child(label_box)


func _build_category_filter_buttons() -> void:
	for child: Node in filter_scroll_container.get_children():
		child.queue_free()
	_add_filter_pill("All", active_category_filter == "All")
	for tag: String in user_available_tags:
		_add_filter_pill(tag, active_category_filter == tag)


func _add_filter_pill(label_text: String, is_active: bool) -> void:
	var btn: Button = Button.new()
	btn.text = label_text
	btn.focus_mode = Control.FOCUS_NONE
	btn.toggle_mode = true
	btn.button_pressed = is_active
	btn.theme_type_variation = "Breadcrumb"
	btn.add_theme_font_size_override("font_size", 10)
	btn.pressed.connect(func() -> void:
		active_category_filter = label_text
		_build_category_filter_buttons()
		refresh_tray()
	)
	filter_scroll_container.add_child(btn)


func _on_search_query_changed(query: String) -> void:
	active_search_query = query.strip_edges().to_lower()
	refresh_tray()


func _build_import_dialogs() -> void:
	art_import_dialog = FileDialog.new()
	art_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	art_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	art_import_dialog.use_native_dialog = true
	art_import_dialog.filters = ["*.png, *.jpg, *.jpeg, *.webp ; Image Files"]
	art_import_dialog.min_size = Vector2i(760, 480)
	art_import_dialog.current_dir = UGCManager.get_default_import_directory()
	art_import_dialog.file_selected.connect(func(path: String) -> void: _on_art_files_imported([path]))
	art_import_dialog.files_selected.connect(_on_art_files_imported)
	add_child(art_import_dialog)


func _on_art_files_imported(paths: PackedStringArray) -> void:
	var imported_items: Array[Dictionary] = UGCManager.import_art_files(paths, current_folder_path)
	for item: Dictionary in imported_items:
		var fname: String = str(item.get("name", ""))
		if not asset_tags_registry.has(fname):
			asset_tags_registry[fname] = ["#props"]

	_save_all_metadata()
	refresh_tray()


func _on_folder_created_by_modal(folder_name: String) -> void:
	var full_f_path: String = folder_name
	if current_folder_path != "" and current_folder_path != "Root":
		full_f_path = current_folder_path + "/" + folder_name

	if current_mode == TrayMode.ASSETS:
		UGCManager.create_art_folder(full_f_path)
	else:
		var key: String = "props" if current_mode == TrayMode.PROPS else ("furniture" if current_mode == TrayMode.FURNITURE else "cast")
		var raw_arr: Array = user_registered_folders[key]
		if not full_f_path in raw_arr:
			raw_arr.append(full_f_path)
			_save_all_metadata()
	refresh_tray()


func _request_delete_folder(folder_name: String) -> void:
	var full_rel_path: String = folder_name
	if current_folder_path != "" and current_folder_path != "Root":
		full_rel_path = current_folder_path + "/" + folder_name
	full_rel_path = full_rel_path.strip_edges().trim_prefix("/").trim_suffix("/")

	if current_mode == TrayMode.ASSETS:
		UGCManager.delete_art_folder(full_rel_path)
	elif current_mode == TrayMode.PROPS:
		user_registered_folders["props"].erase(full_rel_path)
		var p_path: String = _get_props_path()
		var templates: Array[Dictionary] = DrawerMetadataService.load_template_array(p_path)
		for item: Dictionary in templates:
			if str(item.get("folder", "")).begins_with(full_rel_path): item["folder"] = ""
		DrawerMetadataService.save_template_array(p_path, templates)
	elif current_mode == TrayMode.FURNITURE:
		user_registered_folders["furniture"].erase(full_rel_path)
		var f_path: String = _get_furniture_path()
		var templates: Array[Dictionary] = DrawerMetadataService.load_template_array(f_path)
		for item: Dictionary in templates:
			if str(item.get("folder", "")).begins_with(full_rel_path): item["folder"] = ""
		DrawerMetadataService.save_template_array(f_path, templates)
	elif current_mode == TrayMode.CAST:
		user_registered_folders["cast"].erase(full_rel_path)
		var cast_list: Array[Dictionary] = _load_cast_data()
		for char_d: Dictionary in cast_list:
			if str(char_d.get("folder", "")).begins_with(full_rel_path): char_d["folder"] = ""
		_save_cast_data(cast_list)

	_save_all_metadata()
	_notify("Deleted Folder: " + folder_name, true)
	refresh_tray()


func _open_organizer_for_item(item_data: Dictionary, mode_type: String, item_index: int = -1) -> void:
	if not organize_modal: return
	var item_name: String = str(item_data.get("display_name", item_data.get("name", "Item")))
	var folder_list: Array[String] = []

	if mode_type == "assets":
		var art_folders: Array[String] = UGCManager.get_all_art_folders()
		for f: String in art_folders: folder_list.append(f)
	else:
		var raw_folders: Array = user_registered_folders.get(mode_type, [])
		for f: Variant in raw_folders: folder_list.append(str(f))

	var curr_tags: Array = asset_tags_registry.get(item_name, []) if mode_type == "assets" else item_data.get("tags", [])
	organize_modal.open_organizer(item_data, mode_type, item_index, user_available_tags, curr_tags, folder_list)


func _on_organization_saved_by_modal(item_data: Dictionary, mode_type: String, item_idx: int, target_folder: String, chosen_tags: Array[String]) -> void:
	if mode_type == "assets":
		var fname: String = str(item_data["name"])
		var fpath: String = str(item_data["file_path"])
		asset_tags_registry[fname] = chosen_tags
		UGCManager.move_art_file(fpath, target_folder)
	elif mode_type == "props":
		var p_path: String = _get_props_path()
		var templates: Array[Dictionary] = DrawerMetadataService.load_template_array(p_path)
		if item_idx >= 0 and item_idx < templates.size():
			templates[item_idx]["folder"] = "" if target_folder == "Root" else target_folder
			templates[item_idx]["tags"] = chosen_tags
			DrawerMetadataService.save_template_array(p_path, templates)
	elif mode_type == "furniture":
		var f_path: String = _get_furniture_path()
		var templates: Array[Dictionary] = DrawerMetadataService.load_template_array(f_path)
		if item_idx >= 0 and item_idx < templates.size():
			templates[item_idx]["folder"] = "" if target_folder == "Root" else target_folder
			templates[item_idx]["tags"] = chosen_tags
			DrawerMetadataService.save_template_array(f_path, templates)
	elif mode_type == "cast":
		var cast_list: Array[Dictionary] = _load_cast_data()
		if item_idx >= 0 and item_idx < cast_list.size():
			cast_list[item_idx]["folder"] = "" if target_folder == "Root" else target_folder
			cast_list[item_idx]["tags"] = chosen_tags
			_save_cast_data(cast_list)

	_save_all_metadata()
	refresh_tray()


func _delete_tag_globally(tag_name: String) -> void:
	user_available_tags.erase(tag_name)
	for k: String in asset_tags_registry.keys():
		var t_list: Array = asset_tags_registry[k]
		if tag_name in t_list: t_list.erase(tag_name)

	_save_all_metadata()
	_build_category_filter_buttons()
	_notify("Deleted Tag: " + tag_name, true)
	refresh_tray()


func _on_custom_tag_added_by_modal(tag_name: String) -> void:
	if not tag_name in user_available_tags:
		user_available_tags.append(tag_name)
		_save_all_metadata()
		_build_category_filter_buttons()


func _spawn_and_relocate_character_from_cast(char_data: Dictionary) -> void:
	var c_name: String = str(char_data.get("display_name", "Character"))
	var c_id: String = str(char_data.get("id", ""))

	var tree: SceneTree = get_tree()
	var existing_live_char: OwnEntity = null
	if tree:
		for node: Node in tree.get_nodes_in_group("characters"):
			if node is OwnEntity:
				var ent: OwnEntity = node as OwnEntity
				if ent.entity_id == c_id or (not c_name.is_empty() and ent.display_name.strip_edges().to_lower() == c_name.strip_edges().to_lower()):
					existing_live_char = ent
					break

	if existing_live_char and is_instance_valid(existing_live_char):
		existing_live_char.z_index = _get_next_z_index()
		if existing_live_char.has_method(&"trigger_spawn_juice"):
			existing_live_char.call(&"trigger_spawn_juice")
		_notify(c_name + " is already in this room! (Hold card to recall)", true)
		return

	DrawerMetadataService.scrub_character_from_universe_rooms(c_id, c_name)

	var cast_list: Array[Dictionary] = _load_cast_data()
	var cast_mod: bool = false
	for i: int in range(cast_list.size() - 1, -1, -1):
		if str(cast_list[i].get("id", "")) == c_id or (not c_name.is_empty() and str(cast_list[i].get("display_name", "")).strip_edges().to_lower() == c_name.strip_edges().to_lower()):
			cast_list.remove_at(i)
			cast_mod = true
	if cast_mod: _save_cast_data(cast_list)

	character_spawn_requested.emit(char_data)
	_notify("Summoned: " + c_name, true)
	refresh_tray()


func _duplicate_cast_character(_idx: int, char_data: Dictionary) -> void:
	var clone_d: Dictionary = char_data.duplicate(true)
	var orig_name: String = str(clone_d.get("display_name", "Character"))
	clone_d["id"] = _generate_entity_uuid(orig_name)
	clone_d["display_name"] = orig_name + " (Copy)"

	var cast_list: Array[Dictionary] = _load_cast_data()
	cast_list.append(clone_d)
	_save_cast_data(cast_list)
	refresh_tray()


func store_character_in_tray(char_ent: OwnEntity) -> void:
	if not is_instance_valid(char_ent): return
	var cast_list: Array[Dictionary] = _load_cast_data()
	var d: Dictionary = char_ent.to_dict()
	d["folder"] = current_folder_path

	var found: bool = false
	for i: int in range(cast_list.size()):
		var match_id: bool = (str(cast_list[i].get("id", "")) == char_ent.entity_id)
		var match_name: bool = (str(cast_list[i].get("display_name", "")).strip_edges().to_lower() == char_ent.display_name.strip_edges().to_lower())
		if match_id or match_name:
			cast_list[i] = d
			found = true
			break
	if not found:
		cast_list.append(d)

	_save_cast_data(cast_list)
	char_ent.queue_free()
	_notify("Returned to Cast: " + char_ent.display_name, true)
	refresh_tray()


func store_entity_as_template(entity: OwnEntity) -> void:
	if not is_instance_valid(entity): return
	var file_path: String = _get_props_path() if entity.entity_type == Types.EntityType.PROP else _get_furniture_path()
	var templates: Array[Dictionary] = DrawerMetadataService.load_template_array(file_path)
	var d: Dictionary = entity.to_dict()
	d["folder"] = current_folder_path
	templates.append(d)
	DrawerMetadataService.save_template_array(file_path, templates)
	_notify("Saved Template: " + entity.display_name, true)
	refresh_tray()


func _duplicate_template_in_file(file_path: String, data: Dictionary) -> void:
	var templates: Array[Dictionary] = DrawerMetadataService.load_template_array(file_path)
	var clone_d: Dictionary = data.duplicate(true)
	var orig_name: String = str(clone_d.get("display_name", "Template"))
	clone_d["id"] = _generate_entity_uuid(orig_name)
	clone_d["display_name"] = orig_name + " (Copy)"
	templates.append(clone_d)
	DrawerMetadataService.save_template_array(file_path, templates)
	refresh_tray()


func _delete_template_from_file(file_path: String, idx: int) -> void:
	var templates: Array[Dictionary] = DrawerMetadataService.load_template_array(file_path)
	if idx >= 0 and idx < templates.size():
		templates.remove_at(idx)
		DrawerMetadataService.save_template_array(file_path, templates)
		refresh_tray()


func _delete_character_from_cast(char_data: Dictionary) -> void:
	var char_id: String = str(char_data.get("id", ""))
	var char_name: String = str(char_data.get("display_name", ""))

	var cast_list: Array[Dictionary] = _load_cast_data()
	for i: int in range(cast_list.size() - 1, -1, -1):
		if str(cast_list[i].get("id", "")) == char_id or (not char_name.is_empty() and str(cast_list[i].get("display_name", "")).strip_edges().to_lower() == char_name.strip_edges().to_lower()):
			cast_list.remove_at(i)
	_save_cast_data(cast_list)

	var tree: SceneTree = get_tree()
	if tree:
		for node: Node in tree.get_nodes_in_group("characters"):
			if node is OwnEntity:
				var ent: OwnEntity = node as OwnEntity
				if ent.entity_id == char_id or (not char_name.is_empty() and ent.display_name.strip_edges().to_lower() == char_name.strip_edges().to_lower()):
					ent.queue_free()

	DrawerMetadataService.scrub_character_from_universe_rooms(char_id, char_name)
	refresh_tray()


func _delete_art_file(fpath: String, fname: String) -> void:
	if UGCManager.delete_art_file(fpath):
		asset_tags_registry.erase(fname)
		_save_all_metadata()
		refresh_tray()


func _load_all_metadata() -> void:
	user_available_tags = DrawerMetadataService.load_tags_list()
	asset_tags_registry = DrawerMetadataService.load_asset_tags()
	user_registered_folders = DrawerMetadataService.load_registered_folders()


func _save_all_metadata() -> void:
	DrawerMetadataService.save_tags_list(user_available_tags)
	DrawerMetadataService.save_asset_tags(asset_tags_registry)
	DrawerMetadataService.save_registered_folders(user_registered_folders)


func _load_cast_data() -> Array[Dictionary]:
	return DrawerMetadataService.load_template_array(SaveSystem.get_universe_cast_path(_get_current_universe_id()))


func _save_cast_data(cast_list: Array[Dictionary]) -> void:
	DrawerMetadataService.save_template_array(SaveSystem.get_universe_cast_path(_get_current_universe_id()), cast_list)


func save_cast_tray_for_current_universe() -> void: _save_all_metadata()
func load_cast_tray_for_current_universe() -> void:
	_load_all_metadata()
	refresh_tray()
