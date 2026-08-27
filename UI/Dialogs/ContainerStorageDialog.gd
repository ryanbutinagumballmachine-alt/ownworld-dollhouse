# ==============================================================================
# OWNWORLD — CONTAINER STORAGE DIALOG
# File: res://UI/Dialogs/ContainerStorageDialog.gd
# Base Class: CanvasLayer (class_name ContainerStorageDialog)
#
# Responsibility: Inventory storage popup. Displays stored props inside bags,
# chests, and drawers, allowing single-tap unpacking into the active room.
# ==============================================================================

class_name ContainerStorageDialog
extends CanvasLayer

const MAX_PANEL_WIDTH: float = 480.0
const MAX_PANEL_HEIGHT: float = 260.0

var root_backdrop: Control = null
var center_container: CenterContainer = null
var root_panel: PanelContainer = null

var active_container_entity: OwnEntity = null
var title_lbl: Label = null
var hint_lbl: Label = null
var btn_close: Button = null
var items_grid: HBoxContainer = null

signal item_unpacked_requested(item_data: Dictionary, container_ent: OwnEntity)


func _ready() -> void:
	name = "ContainerStorageDialog"
	layer = 120
	visible = false
	add_to_group("modal_ui")
	_build_ui()
	_connect_system_signals()
	_apply_theme_styling()
	_update_responsive_layout()


func _connect_system_signals() -> void:
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null and not tree.root.size_changed.is_connected(_update_responsive_layout):
		tree.root.size_changed.connect(_update_responsive_layout)
	if not EventBus.theme_changed.is_connected(_on_theme_changed):
		EventBus.theme_changed.connect(_on_theme_changed)


func _update_responsive_layout() -> void:
	if not is_instance_valid(root_panel):
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280.0, 720.0)
	var target_width: float = clampf(viewport_size.x * 0.90, 280.0, MAX_PANEL_WIDTH)
	var target_height: float = clampf(viewport_size.y * 0.45, 200.0, MAX_PANEL_HEIGHT)
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

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	root_panel.add_child(vbox)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	vbox.add_child(header_hbox)

	title_lbl = Label.new()
	title_lbl.text = "Storage Inventory"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.theme_type_variation = "HeaderLabel"
	header_hbox.add_child(title_lbl)

	btn_close = Button.new()
	btn_close.custom_minimum_size = Vector2(24.0, 24.0)
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.add_theme_constant_override("icon_max_width", 12)
	_apply_close_icon(btn_close)
	btn_close.pressed.connect(close_dialog)
	header_hbox.add_child(btn_close)

	vbox.add_child(HSeparator.new())

	hint_lbl = Label.new()
	hint_lbl.text = "Click an item below to unpack it into the room:"
	hint_lbl.theme_type_variation = "HintLabel"
	vbox.add_child(hint_lbl)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = false
	vbox.add_child(scroll)

	items_grid = HBoxContainer.new()
	items_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	items_grid.add_theme_constant_override("separation", 10)
	scroll.add_child(items_grid)


func _on_theme_changed(_theme_data: Dictionary) -> void:
	_apply_theme_styling()
	if active_container_entity != null and is_instance_valid(active_container_entity):
		_render_stored_items()


func _apply_theme_styling() -> void:
	if root_panel == null: return
	var background_color: Color = ThemeService.get_color("panel_background", "#fff0f5")
	var border_color: Color = ThemeService.get_color("panel_border", "#f472b6")
	var button_normal: Color = ThemeService.get_color("button_normal", "#fce7f3")
	var button_hover: Color = ThemeService.get_color("button_hover", "#fbcfe8")
	var text_primary: Color = ThemeService.get_color("text_primary", "#4a1525")
	var text_muted: Color = ThemeService.get_color("text_muted", "#884d5e")
	var accent_color: Color = ThemeService.get_color("accent_primary", "#db2777")
	var corner_radius: int = ThemeService.get_corner_radius()

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = background_color
	panel_style.border_color = border_color
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(corner_radius)
	panel_style.content_margin_left = 14
	panel_style.content_margin_right = 14
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	root_panel.add_theme_stylebox_override("panel", panel_style)

	title_lbl.add_theme_color_override("font_color", accent_color)
	hint_lbl.add_theme_color_override("font_color", text_muted)

	if btn_close != null:
		var button_normal_style: StyleBoxFlat = StyleBoxFlat.new()
		button_normal_style.bg_color = button_normal
		button_normal_style.border_color = border_color
		button_normal_style.set_border_width_all(1)
		button_normal_style.set_corner_radius_all(corner_radius)
		button_normal_style.content_margin_left = 6
		button_normal_style.content_margin_right = 6
		btn_close.add_theme_stylebox_override("normal", button_normal_style)

		var button_hover_style: StyleBoxFlat = button_normal_style.duplicate() as StyleBoxFlat
		button_hover_style.bg_color = button_hover
		button_hover_style.border_color = accent_color
		btn_close.add_theme_stylebox_override("hover", button_hover_style)
		btn_close.add_theme_color_override("font_color", text_primary)
		_apply_close_icon(btn_close)


func open_for_container(container_ent: OwnEntity) -> void:
	if not is_instance_valid(container_ent) or not container_ent.is_container:
		return
	active_container_entity = container_ent
	title_lbl.text = "Storage: " + container_ent.display_name
	_update_responsive_layout()
	_render_stored_items()
	_apply_theme_styling()
	visible = true
	AudioManager.play_pop_grab()


func close_dialog() -> void:
	visible = false
	active_container_entity = null


func _render_stored_items() -> void:
	if items_grid == null: return
	for child: Node in items_grid.get_children():
		child.queue_free()

	var container_background: Color = ThemeService.get_color("container_sub_bg", "#fdf2f4")
	var border_color: Color = ThemeService.get_color("panel_border", "#f472b6")
	var text_primary: Color = ThemeService.get_color("text_primary", "#4a1525")
	var text_muted: Color = ThemeService.get_color("text_muted", "#884d5e")
	var accent_color: Color = ThemeService.get_color("accent_primary", "#db2777")
	var corner_radius: int = ThemeService.get_corner_radius()

	if active_container_entity == null or active_container_entity.stored_item_data.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "This container is empty. Drag and drop any item onto it in the room to pack it away!"
		empty_label.theme_type_variation = "HintLabel"
		empty_label.add_theme_color_override("font_color", text_muted)
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.custom_minimum_size = Vector2(260.0, 70.0)
		items_grid.add_child(empty_label)
		return

	for index: int in range(active_container_entity.stored_item_data.size()):
		var item_data: Dictionary = active_container_entity.stored_item_data[index] as Dictionary
		var item_name: String = str(item_data.get("display_name", "Item"))
		var item_texture_path: String = str(item_data.get("texture_path", ""))

		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(70.0, 70.0)
		button.text = item_name
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.expand_icon = true
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_constant_override("icon_max_width", 44)

		if not item_texture_path.is_empty() and FileAccess.file_exists(item_texture_path):
			button.icon = UGCManager.load_texture_from_file(item_texture_path)
		else:
			button.icon = UGCManager.create_blank_starter_graphic(Vector2(40.0, 40.0), accent_color)

		var normal_style: StyleBoxFlat = StyleBoxFlat.new()
		normal_style.bg_color = container_background
		normal_style.border_color = border_color
		normal_style.set_border_width_all(1)
		normal_style.set_corner_radius_all(corner_radius)
		button.add_theme_stylebox_override("normal", normal_style)

		var hover_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
		hover_style.border_color = accent_color
		button.add_theme_stylebox_override("hover", hover_style)
		button.add_theme_stylebox_override("pressed", hover_style)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.add_theme_color_override("font_color", text_primary)
		button.add_theme_color_override("font_hover_color", text_primary)
		button.add_theme_color_override("font_pressed_color", text_primary)
		button.add_theme_font_size_override("font_size", 9)

		var captured_data: Dictionary = item_data.duplicate(true)
		var captured_index: int = index
		button.pressed.connect(func() -> void: _unpack_item(captured_index, captured_data))
		items_grid.add_child(button)


func _unpack_item(index: int, item_data: Dictionary) -> void:
	if active_container_entity == null or not is_instance_valid(active_container_entity):
		return
	if index < 0 or index >= active_container_entity.stored_item_data.size():
		return

	active_container_entity.stored_item_data.remove_at(index)
	item_unpacked_requested.emit(item_data, active_container_entity)
	EventBus.entity_state_changed.emit(active_container_entity.entity_id)
	_render_stored_items()


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		close_dialog()


func _apply_close_icon(button: Button) -> void:
	if button == null: return
	var close_icon: Texture2D = ThemeService.get_icon("icon_close")
	if close_icon != null: button.icon = close_icon
	else: button.text = "✕"
