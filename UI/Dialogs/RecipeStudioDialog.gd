# ==============================================================================
# OWNWORLD — RECIPE STUDIO (HYPER OPTIMIZED & LAYER 120)
# File: res://UI/Dialogs/RecipeStudioDialog.gd
# Base Class: HyperUIDialog
# ==============================================================================

class_name RecipeStudioDialog
extends HyperUIDialog

var header_lbl: Label = null
var plus_lbl: Label = null
var equal_lbl: Label = null
var lbl_res_name: Label = null

var opt_ingredient_a: OptionButton = null
var opt_ingredient_b: OptionButton = null
var opt_result_item: OptionButton = null
var result_name_edit: LineEdit = null
var btn_save: Button = null

var slot_panel_a: PanelContainer = null
var slot_panel_b: PanelContainer = null
var slot_panel_res: PanelContainer = null

var preview_a: TextureRect = null
var preview_b: TextureRect = null
var preview_res: TextureRect = null

var art_library: Array[Dictionary] = []


func _init() -> void:
	max_panel_width = 620.0
	max_panel_height = 520.0


func _build_content() -> void:
	name = "RecipeStudioDialog"
	var is_mob: bool = is_mobile()
	var row_h: float = 36.0 if is_mob else 28.0

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 6)
	root_panel.add_child(main_vbox)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	header_lbl = Label.new()
	header_lbl.text = "Visual Recipe Creator"
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

	var craft_row: HBoxContainer = HBoxContainer.new()
	craft_row.alignment = BoxContainer.ALIGNMENT_CENTER
	craft_row.add_theme_constant_override("separation", 12 if is_mob else 8)
	form_vbox.add_child(craft_row)

	var slot_dim: float = 72.0 if is_mob else 60.0

	var v_a: VBoxContainer = VBoxContainer.new()
	v_a.alignment = BoxContainer.ALIGNMENT_CENTER
	v_a.add_theme_constant_override("separation", 4)
	craft_row.add_child(v_a)

	slot_panel_a = _create_preview_slot(v_a, slot_dim)
	preview_a = slot_panel_a.get_child(0) as TextureRect

	opt_ingredient_a = OptionButton.new()
	opt_ingredient_a.custom_minimum_size = Vector2(110.0 if is_mob else 95.0, row_h)
	opt_ingredient_a.item_selected.connect(func(index: int) -> void: _update_preview_from_opt(preview_a, index))
	v_a.add_child(opt_ingredient_a)

	plus_lbl = Label.new()
	plus_lbl.text = "+"
	plus_lbl.theme_type_variation = "HeaderLabel"
	plus_lbl.add_theme_font_size_override("font_size", 20 if is_mob else 18)
	craft_row.add_child(plus_lbl)

	var v_b: VBoxContainer = VBoxContainer.new()
	v_b.alignment = BoxContainer.ALIGNMENT_CENTER
	v_b.add_theme_constant_override("separation", 4)
	craft_row.add_child(v_b)

	slot_panel_b = _create_preview_slot(v_b, slot_dim)
	preview_b = slot_panel_b.get_child(0) as TextureRect

	opt_ingredient_b = OptionButton.new()
	opt_ingredient_b.custom_minimum_size = Vector2(110.0 if is_mob else 95.0, row_h)
	opt_ingredient_b.item_selected.connect(func(index: int) -> void: _update_preview_from_opt(preview_b, index))
	v_b.add_child(opt_ingredient_b)

	equal_lbl = Label.new()
	equal_lbl.text = "➔"
	equal_lbl.theme_type_variation = "HeaderLabel"
	equal_lbl.add_theme_font_size_override("font_size", 18 if is_mob else 16)
	craft_row.add_child(equal_lbl)

	var v_res: VBoxContainer = VBoxContainer.new()
	v_res.alignment = BoxContainer.ALIGNMENT_CENTER
	v_res.add_theme_constant_override("separation", 4)
	craft_row.add_child(v_res)

	slot_panel_res = _create_preview_slot(v_res, slot_dim)
	preview_res = slot_panel_res.get_child(0) as TextureRect

	opt_result_item = OptionButton.new()
	opt_result_item.custom_minimum_size = Vector2(110.0 if is_mob else 95.0, row_h)
	opt_result_item.item_selected.connect(func(index: int) -> void: _update_preview_from_opt(preview_res, index))
	v_res.add_child(opt_result_item)

	form_vbox.add_child(HSeparator.new())

	lbl_res_name = Label.new()
	lbl_res_name.text = "Crafted Result Name:"
	lbl_res_name.theme_type_variation = "HintLabel"
	lbl_res_name.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	form_vbox.add_child(lbl_res_name)

	result_name_edit = LineEdit.new()
	result_name_edit.placeholder_text = "e.g. Hot Pizza, Berry Smoothie, Magic Potion..."
	result_name_edit.custom_minimum_size = Vector2(0.0, row_h)
	register_keyboard_dodge(result_name_edit)
	form_vbox.add_child(result_name_edit)

	main_vbox.add_child(HSeparator.new())

	btn_save = Button.new()
	btn_save.text = " Register & Save Recipe"
	btn_save.custom_minimum_size = Vector2(0.0, row_h + 4.0)
	btn_save.focus_mode = Control.FOCUS_NONE
	btn_save.add_theme_constant_override("icon_max_width", 16)
	btn_save.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	apply_button_icon(btn_save, "icon_recipes")
	btn_save.pressed.connect(_on_save_recipe_pressed)
	main_vbox.add_child(btn_save)


func _create_preview_slot(parent_vbox: VBoxContainer, dim: float) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = "SubPanel"
	panel.custom_minimum_size = Vector2(dim, dim)
	panel.clip_contents = true
	parent_vbox.add_child(panel)

	var rect: TextureRect = TextureRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(rect)

	_apply_preview_style(panel)
	return panel


func _apply_preview_style(panel: PanelContainer) -> void:
	if not is_instance_valid(panel): 
		return
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = ThemeService.get_color("input_background", "#ffffff")
	style.border_color = ThemeService.get_color("panel_border", "#f472b6")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)


func _on_theme_updated() -> void:
	_apply_preview_style(slot_panel_a)
	_apply_preview_style(slot_panel_b)
	_apply_preview_style(slot_panel_res)
	apply_button_icon(btn_save, "icon_recipes")
	if not is_instance_valid(root_panel): 
		return
	for node: Node in root_panel.find_children("*", "Button", true, false):
		if node is Button and (node as Button).text == "✕":
			apply_close_icon(node as Button)


func open_studio() -> void:
	art_library = UGCManager.scan_user_art_library()
	_populate_dropdowns()
	open_dialog()


func _populate_dropdowns() -> void:
	for opt: OptionButton in [opt_ingredient_a, opt_ingredient_b, opt_result_item]:
		if not is_instance_valid(opt):
			continue
		opt.clear()
		for index: int in range(art_library.size()):
			var item: Dictionary = art_library[index]
			opt.add_item(str(item.get("name", "Art")), index)

	if art_library.is_empty(): 
		return
	if is_instance_valid(opt_ingredient_a): opt_ingredient_a.selected = 0
	if is_instance_valid(opt_ingredient_b): opt_ingredient_b.selected = mini(1, art_library.size() - 1)
	if is_instance_valid(opt_result_item): opt_result_item.selected = mini(2, art_library.size() - 1)

	if is_instance_valid(opt_ingredient_a): _update_preview_from_opt(preview_a, opt_ingredient_a.selected)
	if is_instance_valid(opt_ingredient_b): _update_preview_from_opt(preview_b, opt_ingredient_b.selected)
	if is_instance_valid(opt_result_item): _update_preview_from_opt(preview_res, opt_result_item.selected)
	if is_instance_valid(result_name_edit) and is_instance_valid(opt_result_item):
		result_name_edit.text = str(art_library[opt_result_item.selected].get("name", ""))


func _update_preview_from_opt(preview: TextureRect, index: int) -> void:
	if not is_instance_valid(preview): 
		return
	if index >= 0 and index < art_library.size():
		var texture_variant: Variant = art_library[index].get("texture", null)
		if texture_variant is Texture2D and is_instance_valid(texture_variant): 
			preview.texture = texture_variant as Texture2D
		else:
			var fpath: String = str(art_library[index].get("file_path", ""))
			preview.texture = UGCManager.get_thumbnail(fpath)


func _on_save_recipe_pressed() -> void:
	if art_library.is_empty() or not is_instance_valid(opt_ingredient_a) or not is_instance_valid(opt_ingredient_b) or not is_instance_valid(opt_result_item): 
		return
	var index_a: int = opt_ingredient_a.selected
	var index_b: int = opt_ingredient_b.selected
	var index_result: int = opt_result_item.selected
	if index_a < 0 or index_b < 0 or index_result < 0: 
		return

	var name_a: String = str(art_library[index_a].get("name", "Item A"))
	var name_b: String = str(art_library[index_b].get("name", "Item B"))
	var typed_result_name: String = result_name_edit.text.strip_edges() if is_instance_valid(result_name_edit) else ""
	var name_result: String = typed_result_name if not typed_result_name.is_empty() else str(art_library[index_result].get("name", "Result"))
	var result_texture_path: String = str(art_library[index_result].get("file_path", ""))

	RecipeCrafting.register_recipe(name_a, name_b, name_result, Types.EntityType.PROP, result_texture_path)
	EventBus.notification_requested.emit("Saved Recipe: %s + %s -> %s" % [name_a, name_b, name_result], true)
	_on_close_requested()
