# ==============================================================================
# OWNWORLD — DRAWER ORGANIZER & TAGGING MODAL (LANDSCAPE TWO-COLUMN DUAL-OS)
# File: res://UI/Drawer/DrawerOrganizeModal.gd
# Base Class: Control (class_name DrawerOrganizeModal)
#
# Responsibility: Single & batch item organization dialog. Handles folder routing,
# tag checkbox application, and custom hashtag creation/deletion with keyboard dodging.
# ==============================================================================

class_name DrawerOrganizeModal
extends Control

signal organization_saved(item_data: Dictionary, mode_type: String, item_index: int, target_folder: String, chosen_tags: Array[String])
signal batch_organization_saved(items: Array[Dictionary], mode_type: String, target_folder: String, chosen_tags: Array[String])
signal tag_deleted(tag_name: String)
signal custom_tag_added(tag_name: String)

var center_box: CenterContainer = null
var panel: PanelContainer = null
var item_label: Label = null
var folder_option: OptionButton = null
var tag_checkboxes_container: GridContainer = null
var tag_new_input: LineEdit = null
var btn_add_tag: Button = null
var btn_save: Button = null

var is_batch_mode: bool = false
var single_item_data: Dictionary = {}
var batch_items_data: Array[Dictionary] = []
var active_mode_type: String = "assets"
var single_item_index: int = -1
var current_available_tags: Array[String] = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()


func _is_mobile() -> bool:
	return ThemeEngine.is_mobile_platform()


func _build_ui() -> void:
	var is_mob: bool = _is_mobile()
	var btn_h: float = 38.0 if is_mob else 30.0

	gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			close_modal()
	)

	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	center_box = CenterContainer.new()
	center_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_box.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center_box)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(460.0 if is_mob else 400.0, 380.0 if is_mob else 340.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center_box.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	item_label = Label.new()
	item_label.text = "Organize Item"
	item_label.theme_type_variation = "HeaderLabel"
	item_label.add_theme_font_size_override("font_size", 14 if is_mob else 12)
	vbox.add_child(item_label)

	var folder_lbl: Label = Label.new()
	folder_lbl.text = "Destination Folder:"
	folder_lbl.theme_type_variation = "HintLabel"
	folder_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	vbox.add_child(folder_lbl)

	folder_option = OptionButton.new()
	folder_option.custom_minimum_size = Vector2(0.0, btn_h)
	_enforce_dropdown_popup_limits(folder_option, 200)
	vbox.add_child(folder_option)

	var tag_section_lbl: Label = Label.new()
	tag_section_lbl.text = "Tags to Apply:"
	tag_section_lbl.theme_type_variation = "HintLabel"
	tag_section_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	vbox.add_child(tag_section_lbl)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 130.0 if is_mob else 110.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = false
	vbox.add_child(scroll)

	tag_checkboxes_container = GridContainer.new()
	tag_checkboxes_container.columns = 2
	tag_checkboxes_container.add_theme_constant_override("h_separation", 10)
	tag_checkboxes_container.add_theme_constant_override("v_separation", 6 if is_mob else 4)
	scroll.add_child(tag_checkboxes_container)

	var custom_row: HBoxContainer = HBoxContainer.new()
	custom_row.add_theme_constant_override("separation", 6)
	vbox.add_child(custom_row)

	tag_new_input = LineEdit.new()
	tag_new_input.placeholder_text = "New #tag (e.g. #magic)..."
	tag_new_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag_new_input.custom_minimum_size = Vector2(0.0, btn_h)
	tag_new_input.text_submitted.connect(func(_t: String) -> void: _on_add_tag_clicked())
	if is_mob:
		tag_new_input.focus_entered.connect(_on_input_focus_entered)
		tag_new_input.focus_exited.connect(_on_input_focus_exited)
	custom_row.add_child(tag_new_input)

	btn_add_tag = Button.new()
	btn_add_tag.text = " Tag"
	btn_add_tag.custom_minimum_size = Vector2(80.0 if is_mob else 70.0, btn_h)
	btn_add_tag.focus_mode = Control.FOCUS_NONE
	btn_add_tag.add_theme_constant_override("icon_max_width", 14)

	var tag_icon: Texture2D = ThemeService.get_icon("icon_tag")
	if tag_icon == null: 
		tag_icon = ThemeService.get_icon("icon_plus")
	if tag_icon != null: 
		btn_add_tag.icon = tag_icon
	btn_add_tag.pressed.connect(_on_add_tag_clicked)
	custom_row.add_child(btn_add_tag)

	btn_save = Button.new()
	btn_save.text = " Save Organization"
	btn_save.custom_minimum_size = Vector2(0.0, btn_h + 4.0)
	btn_save.focus_mode = Control.FOCUS_NONE
	btn_save.add_theme_constant_override("icon_max_width", 16)

	var s_icon: Texture2D = ThemeService.get_icon("icon_save")
	if s_icon != null: 
		btn_save.icon = s_icon
	btn_save.pressed.connect(_on_save_clicked)
	vbox.add_child(btn_save)


func _on_input_focus_entered() -> void:
	if _is_mobile() and is_instance_valid(center_box):
		await get_tree().process_frame
		await get_tree().process_frame
		var kb_height: float = DisplayServer.virtual_keyboard_get_height()
		if kb_height > 0:
			var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(center_box, "position:y", -kb_height * 0.4, 0.25)


func _on_input_focus_exited() -> void:
	if _is_mobile() and is_instance_valid(center_box):
		var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(center_box, "position:y", 0.0, 0.25)


func _enforce_dropdown_popup_limits(opt_btn: OptionButton, max_height: int = 200) -> void:
	if not is_instance_valid(opt_btn): 
		return
	var pop: PopupMenu = opt_btn.get_popup()
	if is_instance_valid(pop):
		pop.max_size = Vector2i(4000, max_height)
		pop.about_to_popup.connect(func() -> void: 
			if is_instance_valid(pop):
				pop.max_size = Vector2i(4000, max_height)
		)


func open_organizer(item_data: Dictionary, mode_type: String, item_index: int, available_tags: Array[String], current_tags: Array, folder_list: Array[String]) -> void:
	is_batch_mode = false
	single_item_data = item_data
	batch_items_data.clear()
	active_mode_type = mode_type
	single_item_index = item_index
	current_available_tags = available_tags

	var item_name: String = str(item_data.get("display_name", item_data.get("name", "Item")))
	var curr_folder: String = str(item_data.get("folder", "Root"))
	if curr_folder == "": 
		curr_folder = "Root"

	if is_instance_valid(item_label): item_label.text = "Organize: " + item_name
	if is_instance_valid(btn_save): btn_save.text = " Save Organization"

	if is_instance_valid(folder_option):
		folder_option.clear()
		folder_option.add_item("Root", 0)

		var sel_idx: int = 0
		for i: int in range(folder_list.size()):
			var f: String = folder_list[i]
			if f != "Root":
				folder_option.add_item(f, i + 1)
				if f == curr_folder: 
					sel_idx = i + 1
		folder_option.selected = sel_idx

	_populate_tag_checkboxes(current_tags)
	visible = true


func open_batch_organizer(items: Array[Dictionary], mode_type: String, available_tags: Array[String], folder_list: Array[String]) -> void:
	is_batch_mode = true
	single_item_data.clear()
	batch_items_data = items.duplicate(true)
	active_mode_type = mode_type
	single_item_index = -1
	current_available_tags = available_tags

	if is_instance_valid(item_label): item_label.text = "Batch Organize (" + str(items.size()) + " Items)"
	if is_instance_valid(btn_save): btn_save.text = " Apply to " + str(items.size()) + " Selected Items"

	if is_instance_valid(folder_option):
		folder_option.clear()
		folder_option.add_item("(Keep Existing Folders)", 0)
		folder_option.add_item("Root", 1)

		for i: int in range(folder_list.size()):
			var f: String = folder_list[i]
			if f != "Root":
				folder_option.add_item(f, i + 2)
		folder_option.selected = 0

	_populate_tag_checkboxes([])
	visible = true


func _populate_tag_checkboxes(preselected_tags: Array) -> void:
	if not is_instance_valid(tag_checkboxes_container):
		return
	for child: Node in tag_checkboxes_container.get_children():
		child.queue_free()

	var is_mob: bool = _is_mobile()
	var t_icon: Texture2D = ThemeService.get_icon("icon_tag")
	var del_icon: Texture2D = ThemeService.get_icon("icon_close")

	for t_str: String in current_available_tags:
		var tag_row: HBoxContainer = HBoxContainer.new()
		tag_row.add_theme_constant_override("separation", 4)
		tag_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var chk: CheckBox = CheckBox.new()
		chk.text = " " + t_str
		chk.button_pressed = (t_str in preselected_tags)
		chk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chk.custom_minimum_size = Vector2(0.0, 32.0 if is_mob else 26.0)
		chk.add_theme_constant_override("icon_max_width", 16 if is_mob else 14)
		chk.add_theme_font_size_override("font_size", 11 if is_mob else 10)
		if t_icon != null: 
			chk.icon = t_icon
		tag_row.add_child(chk)

		var btn_del_tag: Button = Button.new()
		btn_del_tag.custom_minimum_size = Vector2(24.0 if is_mob else 20.0, 24.0 if is_mob else 20.0)
		btn_del_tag.theme_type_variation = "DangerButton"
		btn_del_tag.focus_mode = Control.FOCUS_NONE
		btn_del_tag.add_theme_constant_override("icon_max_width", 10)
		if del_icon != null: 
			btn_del_tag.icon = del_icon
		else: 
			btn_del_tag.text = "✕"

		var cap_tag: String = t_str
		btn_del_tag.pressed.connect(func() -> void: tag_deleted.emit(cap_tag))
		tag_row.add_child(btn_del_tag)
		tag_checkboxes_container.add_child(tag_row)


func _on_add_tag_clicked() -> void:
	if is_instance_valid(tag_new_input):
		var t: String = tag_new_input.text.strip_edges().to_lower()
		if not t.is_empty():
			if not t.begins_with("#"): 
				t = "#" + t
			custom_tag_added.emit(t)
		tag_new_input.text = ""


func _on_save_clicked() -> void:
	var chosen_tags: Array[String] = []
	if is_instance_valid(tag_checkboxes_container):
		for child: Node in tag_checkboxes_container.get_children():
			if child is HBoxContainer:
				for sub_c: Node in child.get_children():
					if sub_c is CheckBox and (sub_c as CheckBox).button_pressed:
						chosen_tags.append((sub_c as CheckBox).text.strip_edges())

	if is_batch_mode:
		var target_folder: String = "__KEEP__"
		if is_instance_valid(folder_option) and folder_option.selected > 0:
			target_folder = folder_option.get_item_text(folder_option.selected)
		batch_organization_saved.emit(batch_items_data, active_mode_type, target_folder, chosen_tags)
	else:
		if single_item_data.is_empty():
			close_modal()
			return
		var target_folder: String = "Root"
		if is_instance_valid(folder_option) and folder_option.selected > 0:
			target_folder = folder_option.get_item_text(folder_option.selected)

		organization_saved.emit(single_item_data, active_mode_type, single_item_index, target_folder, chosen_tags)

	close_modal()


func close_modal() -> void:
	visible = false
	single_item_data.clear()
	batch_items_data.clear()
