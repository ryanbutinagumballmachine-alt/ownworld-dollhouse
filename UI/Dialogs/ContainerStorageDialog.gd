# ============================================================
# File: res://UI/Dialogs/ContainerStorageDialog.gd
# ============================================================

# ==============================================================================
# OWNWORLD — CONTAINER STORAGE DIALOG (HYPER OPTIMIZED & LAYER 120)
# File: res://UI/Dialogs/ContainerStorageDialog.gd
# Base Class: HyperUIDialog
# ==============================================================================

class_name ContainerStorageDialog
extends HyperUIDialog

var active_container_entity: OwnEntity = null
var title_lbl: Label = null
var hint_lbl: Label = null
var btn_close: Button = null
var items_grid: HBoxContainer = null

signal item_unpacked_requested(item_data: Dictionary, container_ent: OwnEntity)


func _init() -> void:
	max_panel_width = 520.0
	max_panel_height = 280.0


func _build_content() -> void:
	name = "ContainerStorageDialog"
	
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	root_panel.add_child(vbox)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	vbox.add_child(header_hbox)

	title_lbl = Label.new()
	title_lbl.text = "Storage Inventory"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.theme_type_variation = "HeaderLabel"
	title_lbl.add_theme_font_size_override("font_size", 14 if is_mobile() else 12)
	header_hbox.add_child(title_lbl)

	btn_close = Button.new()
	btn_close.custom_minimum_size = Vector2(28.0 if is_mobile() else 22.0, 28.0 if is_mobile() else 22.0)
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.add_theme_constant_override("icon_max_width", 12)
	apply_close_icon(btn_close)
	btn_close.pressed.connect(_on_close_requested)
	header_hbox.add_child(btn_close)

	vbox.add_child(HSeparator.new())

	hint_lbl = Label.new()
	hint_lbl.text = "Tap any item below to unpack it into the room:"
	hint_lbl.theme_type_variation = "HintLabel"
	hint_lbl.add_theme_font_size_override("font_size", 11 if is_mobile() else 10)
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


func _on_theme_updated() -> void:
	if active_container_entity != null and is_instance_valid(active_container_entity):
		_render_stored_items()


func open_for_container(container_ent: OwnEntity) -> void:
	if not is_instance_valid(container_ent) or not container_ent.is_container:
		return
	active_container_entity = container_ent
	title_lbl.text = "Storage: " + container_ent.display_name
	_render_stored_items()
	open_dialog()
	AudioManager.play_pop_grab()


func _on_close_requested() -> void:
	active_container_entity = null
	super._on_close_requested()


func _render_stored_items() -> void:
	if items_grid == null: 
		return
	for child: Node in items_grid.get_children():
		child.queue_free()

	var is_mob: bool = is_mobile()
	var btn_size: float = 84.0 if is_mob else 70.0

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
		empty_label.custom_minimum_size = Vector2(280.0, 70.0)
		empty_label.add_theme_font_size_override("font_size", 11 if is_mob else 10)
		items_grid.add_child(empty_label)
		return

	for index: int in range(active_container_entity.stored_item_data.size()):
		var item_data: Dictionary = active_container_entity.stored_item_data[index] as Dictionary
		var item_name: String = str(item_data.get("display_name", "Item"))
		var item_texture_path: String = str(item_data.get("texture_path", ""))

		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(btn_size, btn_size)
		button.text = item_name
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.expand_icon = true
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_constant_override("icon_max_width", 50 if is_mob else 44)

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
		button.add_theme_font_size_override("font_size", 10 if is_mob else 9)

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
