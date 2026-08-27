# ==============================================================================
# OWNWORLD — RECIPE STUDIO
# File: res://UI/Dialogs/RecipeStudioDialog.gd
# Base Class: CanvasLayer (class_name RecipeStudioDialog)
#
# Responsibility: Visual crafting recipe creator modal. Matches Ingredient A +
# Ingredient B to produce crafted output entities with real-time thumbnail previews.
# ==============================================================================

class_name RecipeStudioDialog
extends CanvasLayer

const MAX_PANEL_WIDTH: float = 500.0
const MAX_PANEL_HEIGHT: float = 460.0

var root_backdrop: Control = null
var center_container: CenterContainer = null
var root_panel: PanelContainer = null

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


func _ready() -> void:
	name = "RecipeStudioDialog"
	layer = 120
	visible = false
	add_to_group("modal_ui")
	_build_ui()
	_connect_system_signals()
	_update_responsive_layout()
	if not ThemeService.theme_changed.is_connected(_on_theme_changed):
		ThemeService.theme_changed.connect(_on_theme_changed)


func _connect_system_signals() -> void:
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null and not tree.root.size_changed.is_connected(_update_responsive_layout):
		tree.root.size_changed.connect(_update_responsive_layout)


func _on_theme_changed(_theme_data: Dictionary) -> void:
	_apply_theme_icons()
	_apply_preview_theme()


func _update_responsive_layout() -> void:
	if not is_instance_valid(root_panel): return
	var viewport: Viewport = get_viewport()
	var viewport_size: Vector2 = viewport.get_visible_rect().size if viewport != null else Vector2(1280.0, 720.0)
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

	var bg_dim: ColorRect = ColorRect.new()
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_dim.color = Color(0.0, 0.0, 0.0, 0.65)
	bg_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_backdrop.add_child(bg_dim)

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
	main_vbox.add_child(header_hbox)

	header_lbl = Label.new()
	header_lbl.text = "Visual Recipe Creator"
	header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_lbl.theme_type_variation = "HeaderLabel"
	header_hbox.add_child(header_lbl)

	var btn_close: Button = Button.new()
	btn_close.custom_minimum_size = Vector2(24.0, 24.0)
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.add_theme_constant_override("icon_max_width", 12)
	var close_icon: Texture2D = ThemeService.get_icon("icon_close")
	if close_icon != null: btn_close.icon = close_icon
	else: btn_close.text = "✕"
	btn_close.pressed.connect(close_dialog)
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
	craft_row.add_theme_constant_override("separation", 12)
	form_vbox.add_child(craft_row)

	var v_a: VBoxContainer = VBoxContainer.new()
	v_a.alignment = BoxContainer.ALIGNMENT_CENTER
	v_a.add_theme_constant_override("separation", 6)
	craft_row.add_child(v_a)

	slot_panel_a = _create_preview_slot(v_a)
	preview_a = slot_panel_a.get_child(0) as TextureRect

	opt_ingredient_a = OptionButton.new()
	opt_ingredient_a.custom_minimum_size = Vector2(100.0, 30.0)
	opt_ingredient_a.item_selected.connect(func(index: int) -> void: _update_preview_from_opt(preview_a, index))
	v_a.add_child(opt_ingredient_a)

	plus_lbl = Label.new()
	plus_lbl.text = "+"
	plus_lbl.theme_type_variation = "HeaderLabel"
	plus_lbl.add_theme_font_size_override("font_size", 18)
	craft_row.add_child(plus_lbl)

	var v_b: VBoxContainer = VBoxContainer.new()
	v_b.alignment = BoxContainer.ALIGNMENT_CENTER
	v_b.add_theme_constant_override("separation", 6)
	craft_row.add_child(v_b)

	slot_panel_b = _create_preview_slot(v_b)
	preview_b = slot_panel_b.get_child(0) as TextureRect

	opt_ingredient_b = OptionButton.new()
	opt_ingredient_b.custom_minimum_size = Vector2(100.0, 30.0)
	opt_ingredient_b.item_selected.connect(func(index: int) -> void: _update_preview_from_opt(preview_b, index))
	v_b.add_child(opt_ingredient_b)

	equal_lbl = Label.new()
	equal_lbl.text = "➔"
	equal_lbl.theme_type_variation = "HeaderLabel"
	equal_lbl.add_theme_font_size_override("font_size", 16)
	craft_row.add_child(equal_lbl)

	var v_res: VBoxContainer = VBoxContainer.new()
	v_res.alignment = BoxContainer.ALIGNMENT_CENTER
	v_res.add_theme_constant_override("separation", 6)
	craft_row.add_child(v_res)

	slot_panel_res = _create_preview_slot(v_res)
	preview_res = slot_panel_res.get_child(0) as TextureRect

	opt_result_item = OptionButton.new()
	opt_result_item.custom_minimum_size = Vector2(100.0, 30.0)
	opt_result_item.item_selected.connect(func(index: int) -> void: _update_preview_from_opt(preview_res, index))
	v_res.add_child(opt_result_item)

	form_vbox.add_child(HSeparator.new())

	lbl_res_name = Label.new()
	lbl_res_name.text = "Crafted Result Name:"
	lbl_res_name.theme_type_variation = "HintLabel"
	form_vbox.add_child(lbl_res_name)

	result_name_edit = LineEdit.new()
	result_name_edit.placeholder_text = "e.g. Hot Pizza, Berry Smoothie, Magic Potion..."
	result_name_edit.custom_minimum_size = Vector2(0.0, 32.0)
	form_vbox.add_child(result_name_edit)

	main_vbox.add_child(HSeparator.new())

	btn_save = Button.new()
	btn_save.text = " Register & Save Recipe"
	btn_save.custom_minimum_size = Vector2(0.0, 36.0)
	btn_save.focus_mode = Control.FOCUS_NONE
	btn_save.add_theme_constant_override("icon_max_width", 16)

	var recipe_icon: Texture2D = ThemeService.get_icon("icon_recipes")
	if recipe_icon == null: recipe_icon = ThemeService.get_icon("icon_save")
	if recipe_icon != null: btn_save.icon = recipe_icon
	btn_save.pressed.connect(_on_save_recipe_pressed)
	main_vbox.add_child(btn_save)


func _create_preview_slot(parent_vbox: VBoxContainer) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = "SubPanel"
	panel.custom_minimum_size = Vector2(60.0, 60.0)
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
	if panel == null: return
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = ThemeService.get_color("input_background", "#ffffff")
	style.border_color = ThemeService.get_color("panel_border", "#f472b6")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)


func _apply_preview_theme() -> void:
	_apply_preview_style(slot_panel_a)
	_apply_preview_style(slot_panel_b)
	_apply_preview_style(slot_panel_res)


func open_studio() -> void:
	art_library = UGCManager.scan_user_art_library()
	_update_responsive_layout()
	_populate_dropdowns()
	visible = true


func close_dialog() -> void:
	visible = false


func _populate_dropdowns() -> void:
	for opt: OptionButton in [opt_ingredient_a, opt_ingredient_b, opt_result_item]:
		opt.clear()
		for index: int in range(art_library.size()):
			var item: Dictionary = art_library[index]
			opt.add_item(str(item.get("name", "Art")), index)

	if art_library.is_empty(): return
	opt_ingredient_a.selected = 0
	opt_ingredient_b.selected = mini(1, art_library.size() - 1)
	opt_result_item.selected = mini(2, art_library.size() - 1)

	_update_preview_from_opt(preview_a, opt_ingredient_a.selected)
	_update_preview_from_opt(preview_b, opt_ingredient_b.selected)
	_update_preview_from_opt(preview_res, opt_result_item.selected)
	result_name_edit.text = str(art_library[opt_result_item.selected].get("name", ""))


func _update_preview_from_opt(preview: TextureRect, index: int) -> void:
	if preview == null: return
	if index >= 0 and index < art_library.size():
		var texture_variant: Variant = art_library[index].get("texture", null)
		if texture_variant is Texture2D: preview.texture = texture_variant as Texture2D
		else:
			var fpath: String = str(art_library[index].get("file_path", ""))
			preview.texture = UGCManager.get_thumbnail(fpath)


func _on_save_recipe_pressed() -> void:
	if art_library.is_empty(): return
	var index_a: int = opt_ingredient_a.selected
	var index_b: int = opt_ingredient_b.selected
	var index_result: int = opt_result_item.selected
	if index_a < 0 or index_b < 0 or index_result < 0: return

	var name_a: String = str(art_library[index_a].get("name", "Item A"))
	var name_b: String = str(art_library[index_b].get("name", "Item B"))
	var typed_result_name: String = result_name_edit.text.strip_edges()
	var name_result: String = typed_result_name if not typed_result_name.is_empty() else str(art_library[index_result].get("name", "Result"))
	var result_texture_path: String = str(art_library[index_result].get("file_path", ""))

	RecipeCrafting.register_recipe(name_a, name_b, name_result, Types.EntityType.PROP, result_texture_path)
	EventBus.notification_requested.emit("Saved Recipe: %s + %s -> %s" % [name_a, name_b, name_result], true)
	visible = false


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		close_dialog()


func _apply_theme_icons() -> void:
	if btn_save == null: return
	var recipe_icon: Texture2D = ThemeService.get_icon("icon_recipes")
	if recipe_icon == null: recipe_icon = ThemeService.get_icon("icon_save")
	btn_save.icon = recipe_icon
