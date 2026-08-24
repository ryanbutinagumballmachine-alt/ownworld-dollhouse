# ==============================================================================
# OWNWORLD — SNAP POINT / ANCHOR STUDIO
# File: res://UI/Dialogs/SnapPointStudioDialog.gd
# Base Class: CanvasLayer (class_name SnapPointStudioDialog)
# ==============================================================================

class_name SnapPointStudioDialog
extends CanvasLayer

const MAX_PANEL_WIDTH: float = 580.0
const MAX_PANEL_HEIGHT: float = 580.0

var root_backdrop: Control = null
var center_container: CenterContainer = null
var root_panel: PanelContainer = null
var active_entity: OwnEntity = null

var header_lbl: Label = null
var hint_lbl: Label = null

var sprite_canvas: Control = null
var sprite_preview_rect: TextureRect = null
var marker_overlay: Control = null

var opt_family_category: OptionButton = null
var active_key_lbl: Label = null
var custom_name_input: LineEdit = null
var btn_add_next_instance: Button = null
var anchors_list_vbox: VBoxContainer = null
var btn_save: Button = null

var current_target_key: String = "hand_1"
var is_current_target_snap: bool = true
var is_editing_existing: bool = false

var family_definitions: Array[Dictionary] = [
	{"family": "hand", "label": "Hand Sockets (Hold Props)", "icon": "icon_hand", "is_snap": true, "color": Color("#0284c7")},
	{"family": "seat", "label": "Seat Sockets (Characters Sit)", "icon": "icon_seat", "is_snap": true, "color": Color("#0ea5e9")},
	{"family": "light", "label": "Light Anchor Emitters", "icon": "icon_lighting", "is_snap": true, "color": Color("#eab308")},
	{"family": "head", "label": "Head / Hats / Pins (Wear)", "icon": "icon_hat", "is_snap": true, "color": Color("#38bdf8")},
	{"family": "face", "label": "Face / Glasses / Masks (Wear)", "icon": "icon_glasses", "is_snap": true, "color": Color("#38bdf8")},
	{"family": "neck", "label": "Neck / Scarves / Ties (Wear)", "icon": "icon_necklace", "is_snap": true, "color": Color("#38bdf8")},
	{"family": "back", "label": "Back / Capes / Wings (Wear)", "icon": "icon_backpack", "is_snap": true, "color": Color("#38bdf8")},
	{"family": "surface", "label": "Table Surfaces (Place Props)", "icon": "icon_surface", "is_snap": true, "color": Color("#06b6d4")},
	{"family": "bed", "label": "Bed Sleep Anchors (Furniture)", "icon": "icon_bed", "is_snap": true, "color": Color("#0284c7")},
	{"family": "hang_hook", "label": "Wall Pegs / Coat Hooks (Furniture)", "icon": "icon_anchors", "is_snap": true, "color": Color("#0284c7")},
	{"family": "sit_point", "label": "Character Sit Baseline (Body)", "icon": "icon_seat", "is_snap": true, "color": Color("#a855f7")},
	{"family": "mouth", "label": "Mouth Eating Zones (Interaction)", "icon": "icon_food", "is_snap": false, "color": Color("#d97706")},
	{"family": "faucet_stream", "label": "Water Stream Faucets (Interaction)", "icon": "icon_faucet", "is_snap": false, "color": Color("#d97706")},
	{"family": "custom", "label": "Custom Anchor Key...", "icon": "icon_pin", "is_snap": true, "color": Color("#ec4899")}
]


func _ready() -> void:
	name = "SnapPointStudioDialog"
	layer = 120
	visible = false
	add_to_group("modal_ui")
	_build_ui()
	_connect_system_signals()
	_update_responsive_layout()


func _connect_system_signals() -> void:
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null and not tree.root.size_changed.is_connected(_update_responsive_layout):
		tree.root.size_changed.connect(_update_responsive_layout)
	if not EventBus.theme_changed.is_connected(_on_theme_changed):
		EventBus.theme_changed.connect(_on_theme_changed)


func _on_theme_changed(_theme_data: Dictionary) -> void:
	if not is_instance_valid(root_panel): return
	_populate_family_dropdown()
	_update_responsive_layout()
	_refresh_visuals()


func _update_responsive_layout() -> void:
	if not is_instance_valid(root_panel): return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280.0, 720.0)
	var target_width: float = clampf(viewport_size.x * 0.92, 290.0, MAX_PANEL_WIDTH)
	var target_height: float = clampf(viewport_size.y * 0.90, 340.0, MAX_PANEL_HEIGHT)
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
	main_vbox.add_child(header_hbox)

	header_lbl = Label.new()
	header_lbl.text = "Attachment & Dress-up Anchors"
	header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_lbl.theme_type_variation = "HeaderLabel"
	header_hbox.add_child(header_lbl)

	var close_button: Button = Button.new()
	close_button.custom_minimum_size = Vector2(24.0, 24.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_constant_override("icon_max_width", 12)
	_apply_close_icon(close_button)
	close_button.pressed.connect(close_dialog)
	header_hbox.add_child(close_button)

	main_vbox.add_child(HSeparator.new())

	var selector_hbox: HBoxContainer = HBoxContainer.new()
	selector_hbox.add_theme_constant_override("separation", 6)
	main_vbox.add_child(selector_hbox)

	opt_family_category = OptionButton.new()
	opt_family_category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt_family_category.custom_minimum_size = Vector2(0.0, 32.0)
	opt_family_category.item_selected.connect(_on_family_selected)
	selector_hbox.add_child(opt_family_category)

	btn_add_next_instance = Button.new()
	btn_add_next_instance.text = " Next Slot"
	btn_add_next_instance.custom_minimum_size = Vector2(100.0, 32.0)
	btn_add_next_instance.focus_mode = Control.FOCUS_NONE
	btn_add_next_instance.add_theme_constant_override("icon_max_width", 14)
	_apply_button_icon(btn_add_next_instance, "icon_plus")
	btn_add_next_instance.pressed.connect(_on_add_next_instance_pressed)
	selector_hbox.add_child(btn_add_next_instance)

	custom_name_input = LineEdit.new()
	custom_name_input.placeholder_text = "Type custom key (e.g. tail_1)..."
	custom_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_name_input.custom_minimum_size = Vector2(0.0, 32.0)
	custom_name_input.visible = false
	custom_name_input.text_changed.connect(_on_custom_name_changed)
	main_vbox.add_child(custom_name_input)

	var active_slot_hbox: HBoxContainer = HBoxContainer.new()
	main_vbox.add_child(active_slot_hbox)

	active_key_lbl = Label.new()
	active_key_lbl.text = "Ready to place: [ hand_1 ] — Tap on illustration below:"
	active_key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_key_lbl.theme_type_variation = "HeaderLabel"
	active_key_lbl.add_theme_font_size_override("font_size", 10)
	active_slot_hbox.add_child(active_key_lbl)

	var canvas_panel: PanelContainer = PanelContainer.new()
	canvas_panel.theme_type_variation = "SubPanel"
	canvas_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_panel.custom_minimum_size = Vector2(0.0, 160.0)
	main_vbox.add_child(canvas_panel)

	sprite_canvas = Control.new()
	sprite_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	sprite_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	sprite_canvas.gui_input.connect(_on_canvas_clicked)
	canvas_panel.add_child(sprite_canvas)

	sprite_preview_rect = TextureRect.new()
	sprite_preview_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	sprite_preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite_preview_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite_canvas.add_child(sprite_preview_rect)

	marker_overlay = Control.new()
	marker_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	marker_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite_canvas.add_child(marker_overlay)

	main_vbox.add_child(HSeparator.new())

	hint_lbl = Label.new()
	hint_lbl.text = "Placed Sockets (Tap any row to reposition it):"
	hint_lbl.theme_type_variation = "HintLabel"
	hint_lbl.add_theme_font_size_override("font_size", 10)
	main_vbox.add_child(hint_lbl)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 95.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = false
	main_vbox.add_child(scroll)

	anchors_list_vbox = VBoxContainer.new()
	anchors_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	anchors_list_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(anchors_list_vbox)

	main_vbox.add_child(HSeparator.new())

	btn_save = Button.new()
	btn_save.text = " Save Anchors & Close"
	btn_save.custom_minimum_size = Vector2(0.0, 36.0)
	btn_save.focus_mode = Control.FOCUS_NONE
	btn_save.add_theme_constant_override("icon_max_width", 16)
	_apply_button_icon(btn_save, "icon_save")
	btn_save.pressed.connect(close_dialog)
	main_vbox.add_child(btn_save)


func _populate_family_dropdown() -> void:
	if opt_family_category == null: return
	var previous_index: int = opt_family_category.selected
	opt_family_category.clear()

	for index: int in range(family_definitions.size()):
		var definition: Dictionary = family_definitions[index]
		var icon_texture: Texture2D = ThemeService.get_popup_icon(str(definition.get("icon", "")))
		if icon_texture != null:
			opt_family_category.add_icon_item(icon_texture, " " + str(definition["label"]), index)
		else:
			opt_family_category.add_item(str(definition["label"]), index)

	if not family_definitions.is_empty():
		opt_family_category.selected = clampi(previous_index, 0, family_definitions.size() - 1)


func open_for_entity(entity: OwnEntity) -> void:
	if not is_instance_valid(entity): return
	active_entity = entity
	sprite_preview_rect.texture = entity.main_texture
	_populate_family_dropdown()
	opt_family_category.selected = 0
	_on_family_selected(0)
	_update_responsive_layout()
	visible = true

	await get_tree().process_frame
	_refresh_visuals()


func close_dialog() -> void:
	if active_entity != null and is_instance_valid(active_entity):
		active_entity.rebuild_gizmos()
		SaveSystem.update_character_in_cast(active_entity)
		SaveSystem.save_current_room_state()
		EventBus.notification_requested.emit("Anchors Saved Successfully!", true)
	visible = false
	active_entity = null


func _on_family_selected(index: int) -> void:
	if index < 0 or index >= family_definitions.size(): return
	var definition: Dictionary = family_definitions[index]
	var family: String = str(definition["family"])
	is_current_target_snap = bool(definition["is_snap"])
	is_editing_existing = false

	if family == "custom":
		custom_name_input.visible = true
		current_target_key = custom_name_input.text.strip_edges().to_lower()
		if current_target_key.is_empty(): current_target_key = "custom_1"
		btn_add_next_instance.visible = false
	elif family == "sit_point":
		custom_name_input.visible = false
		current_target_key = "sit_point"
		btn_add_next_instance.visible = false
	else:
		custom_name_input.visible = false
		btn_add_next_instance.visible = true
		current_target_key = _find_next_unused_family_key(family)

	_update_active_key_indicator()
	_refresh_visuals()


func _on_add_next_instance_pressed() -> void:
	if opt_family_category == null or opt_family_category.selected < 0 or opt_family_category.selected >= family_definitions.size():
		return
	var family: String = str(family_definitions[opt_family_category.selected]["family"])
	is_editing_existing = false
	if family != "custom" and family != "sit_point":
		current_target_key = _find_next_available_incremental_key(family)
		_update_active_key_indicator()
		_refresh_visuals()


func _on_custom_name_changed(new_text: String) -> void:
	var clean_name: String = new_text.strip_edges().to_lower().replace(" ", "_")
	current_target_key = clean_name if not clean_name.is_empty() else "custom_1"
	is_editing_existing = false
	_update_active_key_indicator()


func _find_next_unused_family_key(family_prefix: String) -> String:
	if active_entity == null: return family_prefix + "_1"
	var pool: Dictionary = active_entity.snap_points if is_current_target_snap else active_entity.interaction_points
	var index: int = 1
	while pool.has("%s_%d" % [family_prefix, index]):
		index += 1
	return "%s_%d" % [family_prefix, index]


func _find_next_available_incremental_key(family_prefix: String) -> String:
	if active_entity == null: return family_prefix + "_1"
	var pool: Dictionary = active_entity.snap_points if is_current_target_snap else active_entity.interaction_points
	var max_index: int = 0
	for key_name: String in pool.keys():
		if key_name.begins_with(family_prefix + "_"):
			var suffix: String = key_name.trim_prefix(family_prefix + "_")
			if suffix.is_valid_int():
				max_index = maxi(max_index, suffix.to_int())
	return "%s_%d" % [family_prefix, max_index + 1]


func _select_existing_anchor(anchor_key: String, is_snap: bool) -> void:
	current_target_key = anchor_key
	is_current_target_snap = is_snap
	is_editing_existing = true
	var matched: bool = false

	for index: int in range(family_definitions.size()):
		var family: String = str(family_definitions[index]["family"])
		if family != "custom" and anchor_key.to_lower().begins_with(family):
			opt_family_category.selected = index
			custom_name_input.visible = false
			btn_add_next_instance.visible = (family != "sit_point")
			matched = true
			break

	if not matched:
		opt_family_category.selected = family_definitions.size() - 1
		custom_name_input.visible = true
		custom_name_input.text = anchor_key
		btn_add_next_instance.visible = false

	_update_active_key_indicator()
	_refresh_visuals()


func _update_active_key_indicator() -> void:
	if active_key_lbl == null: return
	if is_editing_existing:
		active_key_lbl.text = "Editing: [ %s ] — Tap canvas to reposition:" % current_target_key
	else:
		active_key_lbl.text = "Ready to place: [ %s ] — Tap illustration:" % current_target_key


func _on_canvas_clicked(event: InputEvent) -> void:
	if active_entity == null: return
	var click_position: Vector2 = Vector2.ZERO
	var is_valid_click: bool = false

	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		click_position = event.position
		is_valid_click = true

	if not is_valid_click: return
	var local_sprite_offset: Vector2 = _ui_to_sprite_offset(click_position)

	if is_current_target_snap:
		active_entity.snap_points[current_target_key] = local_sprite_offset
	else:
		var interaction_type: int = int(Types.InteractionPointType.MOUTH)
		if current_target_key.begins_with("faucet") or current_target_key.begins_with("liquid"):
			interaction_type = int(Types.InteractionPointType.LIQUID_STREAM)
		active_entity.interaction_points[current_target_key] = {
			"offset": local_sprite_offset,
			"radius": 55.0,
			"type": interaction_type
		}

	active_entity.rebuild_gizmos()
	_refresh_visuals()

	if not is_editing_existing and opt_family_category != null and opt_family_category.selected >= 0 and opt_family_category.selected < family_definitions.size():
		var family: String = str(family_definitions[opt_family_category.selected]["family"])
		if family != "custom" and family != "sit_point":
			current_target_key = _find_next_unused_family_key(family)
			_update_active_key_indicator()


func _refresh_visuals() -> void:
	_render_anchors_list()
	_draw_visual_pins_on_preview()


func _draw_visual_pins_on_preview() -> void:
	if marker_overlay == null: return
	for child: Node in marker_overlay.get_children():
		child.queue_free()
	if active_entity == null: return

	for socket_name: String in active_entity.snap_points.keys():
		var anchor_offset: Vector2 = active_entity.snap_points[socket_name]
		var ui_position: Vector2 = _sprite_offset_to_ui(anchor_offset)
		var pin_color: Color = _get_color_for_key(socket_name, true)
		var selected: bool = (socket_name == current_target_key and is_current_target_snap)
		_spawn_pin_badge(ui_position, socket_name, pin_color, selected, true)

	for interaction_name: String in active_entity.interaction_points.keys():
		var interaction_data: Dictionary = active_entity.interaction_points[interaction_name]
		var anchor_offset: Vector2 = interaction_data.get("offset", Vector2.ZERO)
		var ui_position: Vector2 = _sprite_offset_to_ui(anchor_offset)
		var pin_color: Color = _get_color_for_key(interaction_name, false)
		var selected: bool = (interaction_name == current_target_key and not is_current_target_snap)
		_spawn_pin_badge(ui_position, interaction_name, pin_color, selected, false)


func _get_color_for_key(key_name: String, is_snap: bool) -> Color:
	var lowercase_key: String = key_name.to_lower()
	for definition: Dictionary in family_definitions:
		var family: String = str(definition["family"])
		if family != "custom" and lowercase_key.begins_with(family):
			return definition["color"] as Color
	return Color("#ec4899") if is_snap else Color("#d97706")


func _spawn_pin_badge(ui_position: Vector2, tag_name: String, pin_color: Color, is_selected: bool, is_snap: bool) -> void:
	var pin_button: Button = Button.new()
	pin_button.position = ui_position - Vector2(10.0, 10.0)
	pin_button.custom_minimum_size = Vector2(20.0, 20.0)
	pin_button.flat = true
	pin_button.mouse_filter = Control.MOUSE_FILTER_PASS
	pin_button.pressed.connect(func() -> void: _select_existing_anchor(tag_name, is_snap))

	var marker: PinDot = PinDot.new()
	marker.dot_color = pin_color
	marker.is_active_selected = is_selected
	marker.position = Vector2(10.0, 10.0)
	pin_button.add_child(marker)

	var badge: Label = Label.new()
	badge.text = tag_name
	badge.position = Vector2(18.0, 0.0)
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.add_theme_font_size_override("font_size", 10)

	var badge_style: StyleBoxFlat = StyleBoxFlat.new()
	badge_style.bg_color = Color(pin_color.r * 0.25, pin_color.g * 0.25, pin_color.b * 0.25, 0.92)
	badge_style.border_color = ThemeService.get_color("accent_primary", "#db2777") if is_selected else pin_color
	badge_style.set_border_width_all(2 if is_selected else 1)
	badge_style.set_corner_radius_all(4)
	badge_style.content_margin_left = 5
	badge_style.content_margin_right = 5
	badge.add_theme_stylebox_override("normal", badge_style)

	pin_button.add_child(badge)
	marker_overlay.add_child(pin_button)


func _get_texture_render_rect() -> Rect2:
	if active_entity == null or active_entity.texture_size == Vector2.ZERO or sprite_canvas.size == Vector2.ZERO:
		return Rect2(Vector2.ZERO, sprite_canvas.size)
	var texture_size: Vector2 = active_entity.texture_size
	var canvas_size: Vector2 = sprite_canvas.size
	var scale_factor: float = minf(canvas_size.x / texture_size.x, canvas_size.y / texture_size.y)
	var drawn_size: Vector2 = texture_size * scale_factor
	var drawn_position: Vector2 = (canvas_size - drawn_size) * 0.5
	return Rect2(drawn_position, drawn_size)


func _sprite_offset_to_ui(sprite_offset: Vector2) -> Vector2:
	var render_rect: Rect2 = _get_texture_render_rect()
	var center: Vector2 = render_rect.position + (render_rect.size * 0.5)
	if active_entity == null or active_entity.texture_size.x == 0.0: return center
	var scale_factor: float = render_rect.size.x / active_entity.texture_size.x
	return center + (sprite_offset * scale_factor)


func _ui_to_sprite_offset(ui_position: Vector2) -> Vector2:
	var render_rect: Rect2 = _get_texture_render_rect()
	var center: Vector2 = render_rect.position + (render_rect.size * 0.5)
	if active_entity == null or active_entity.texture_size.x == 0.0: return Vector2.ZERO
	var scale_factor: float = render_rect.size.x / active_entity.texture_size.x
	return (ui_position - center) / (scale_factor if scale_factor != 0.0 else 1.0)


func _render_anchors_list() -> void:
	if anchors_list_vbox == null: return
	for child: Node in anchors_list_vbox.get_children():
		child.queue_free()
	if active_entity == null: return

	for socket_name: String in active_entity.snap_points.keys():
		var pos: Vector2 = active_entity.snap_points[socket_name]
		var badge_color: Color = _get_color_for_key(socket_name, true)
		var selected: bool = (socket_name == current_target_key and is_current_target_snap)
		var icon_key: String = _get_icon_for_key(socket_name, true)

		_create_interactive_row(socket_name, pos, badge_color, icon_key, selected,
			func() -> void: _select_existing_anchor(socket_name, true),
			func() -> void:
				active_entity.snap_points.erase(socket_name)
				if current_target_key == socket_name:
					_on_family_selected(opt_family_category.selected)
				active_entity.rebuild_gizmos()
				_refresh_visuals()
		)

	for interaction_name: String in active_entity.interaction_points.keys():
		var interaction_data: Dictionary = active_entity.interaction_points[interaction_name]
		var pos: Vector2 = interaction_data.get("offset", Vector2.ZERO)
		var badge_color: Color = _get_color_for_key(interaction_name, false)
		var selected: bool = (interaction_name == current_target_key and not is_current_target_snap)
		var icon_key: String = _get_icon_for_key(interaction_name, false)

		_create_interactive_row(interaction_name, pos, badge_color, icon_key, selected,
			func() -> void: _select_existing_anchor(interaction_name, false),
			func() -> void:
				active_entity.interaction_points.erase(interaction_name)
				if current_target_key == interaction_name:
					_on_family_selected(opt_family_category.selected)
				active_entity.rebuild_gizmos()
				_refresh_visuals()
		)


func _get_icon_for_key(key_name: String, is_snap: bool) -> String:
	var lowercase_key: String = key_name.to_lower()
	for definition: Dictionary in family_definitions:
		var family: String = str(definition["family"])
		if family != "custom" and lowercase_key.begins_with(family):
			return str(definition.get("icon", "icon_anchors"))
	return "icon_anchors" if is_snap else "icon_food"


func _create_interactive_row(label_text: String, position: Vector2, _tag_color: Color, icon_key: String, is_selected: bool, on_select_callback: Callable, on_delete_callback: Callable) -> void:
	var row_panel: PanelContainer = PanelContainer.new()
	row_panel.theme_type_variation = "SubPanel"

	var row_style: StyleBoxFlat = StyleBoxFlat.new()
	row_style.bg_color = ThemeService.get_color("container_sub_bg", "#fdf2f4")
	row_style.border_color = ThemeService.get_color("accent_primary", "#db2777") if is_selected else ThemeService.get_color("panel_border", "#f472b6")
	row_style.set_border_width_all(2 if is_selected else 1)
	row_style.set_corner_radius_all(ThemeService.get_corner_radius())
	row_style.content_margin_left = 8
	row_style.content_margin_right = 8
	row_style.content_margin_top = 4
	row_style.content_margin_bottom = 4
	row_panel.add_theme_stylebox_override("panel", row_style)

	var hbox: HBoxContainer = HBoxContainer.new()
	row_panel.add_child(hbox)

	var select_button: Button = Button.new()
	select_button.text = " %s (X: %d, Y: %d)" % [label_text, int(position.x), int(position.y)]
	select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_button.flat = true
	select_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	select_button.add_theme_font_size_override("font_size", 10)
	select_button.add_theme_constant_override("icon_max_width", 14)
	select_button.add_theme_color_override("font_color", ThemeService.get_color("accent_primary", "#db2777") if is_selected else ThemeService.get_color("text_primary", "#4a1525"))

	var row_icon: Texture2D = ThemeService.get_icon(icon_key)
	if row_icon != null: select_button.icon = row_icon
	select_button.pressed.connect(on_select_callback)
	hbox.add_child(select_button)

	var delete_button: Button = Button.new()
	delete_button.custom_minimum_size = Vector2(22.0, 22.0)
	delete_button.theme_type_variation = "DangerButton"
	delete_button.focus_mode = Control.FOCUS_NONE
	delete_button.add_theme_constant_override("icon_max_width", 10)
	_apply_close_icon(delete_button)
	delete_button.pressed.connect(on_delete_callback)
	hbox.add_child(delete_button)

	anchors_list_vbox.add_child(row_panel)


func _apply_button_icon(button: Button, icon_key: String) -> void:
	if button == null: return
	var icon_texture: Texture2D = ThemeService.get_icon(icon_key)
	if icon_texture != null: button.icon = icon_texture


func _apply_close_icon(button: Button) -> void:
	if button == null: return
	var icon_texture: Texture2D = ThemeService.get_icon("icon_close")
	if icon_texture != null: button.icon = icon_texture
	else: button.text = "✕"


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		close_dialog()


class PinDot extends Control:
	var dot_color: Color = Color("#00f2fe")
	var is_active_selected: bool = false

	func _draw() -> void:
		var radius: float = 6.0 if is_active_selected else 5.0
		draw_circle(Vector2.ZERO, radius + 2.0, Color(0.0, 0.0, 0.0, 0.75))
		draw_circle(Vector2.ZERO, radius, dot_color)
		if is_active_selected:
			draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 16, Color.WHITE, 1.8)
