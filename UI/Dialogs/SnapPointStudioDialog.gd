# ==============================================================================
# OWNWORLD — MOBILE-FIRST ANCHOR & SNAP POINT STUDIO (HYPER OPTIMIZED)
# File: res://UI/Dialogs/SnapPointStudioDialog.gd
# Base Class: HyperUIDialog
# ==============================================================================

class_name SnapPointStudioDialog
extends HyperUIDialog

var active_entity: OwnEntity = null

var header_lbl: Label = null
var opt_family_category: OptionButton = null
var custom_name_input: LineEdit = null
var btn_add_anchor: Button = null

# Active Anchor Precision Toolbar
var coords_card: PanelContainer = null
var active_badge_lbl: Label = null
var spin_x: SpinBox = null
var spin_y: SpinBox = null
var btn_center_anchor: Button = null
var btn_delete_selected: Button = null

# Canvas & Visual Overlay
var canvas_panel: PanelContainer = null
var sprite_canvas: Control = null
var sprite_preview_rect: TextureRect = null
var marker_overlay: AnchorOverlayDraw = null

# Placed Anchors List
var anchors_count_lbl: Label = null
var anchors_list_vbox: VBoxContainer = null
var btn_save: Button = null

# Interaction & Drag State
var selected_anchor_key: String = ""
var is_selected_snap: bool = true
var is_dragging_anchor: bool = false
var active_touch_index: int = -1
var _is_updating_ui: bool = false

var PIN_TOUCH_RADIUS: float:
	get:
		return 38.0 if is_mobile() else 24.0

var family_definitions: Array[Dictionary] = [
	{"family": "hand", "label": "Hand Sockets (Hold Props)", "icon": "icon_hand", "is_snap": true, "color": Color("#0284c7")},
	{"family": "seat", "label": "Seat Sockets (Characters Sit)", "icon": "icon_seat", "is_snap": true, "color": Color("#0ea5e9")},
	{"family": "light", "label": "Light Anchor Emitters", "icon": "icon_lighting", "is_snap": true, "color": Color("#eab308")},
	{"family": "head", "label": "Head / Hats (Wear)", "icon": "icon_hat", "is_snap": true, "color": Color("#38bdf8")},
	{"family": "face", "label": "Face / Glasses (Wear)", "icon": "icon_glasses", "is_snap": true, "color": Color("#38bdf8")},
	{"family": "neck", "label": "Neck / Scarves (Wear)", "icon": "icon_necklace", "is_snap": true, "color": Color("#38bdf8")},
	{"family": "back", "label": "Back / Wings / Bags (Wear)", "icon": "icon_backpack", "is_snap": true, "color": Color("#38bdf8")},
	{"family": "surface", "label": "Table Surfaces (Place Props)", "icon": "icon_surface", "is_snap": true, "color": Color("#06b6d4")},
	{"family": "bed", "label": "Bed Sleep Anchors (Furniture)", "icon": "icon_bed", "is_snap": true, "color": Color("#0284c7")},
	{"family": "hang_hook", "label": "Wall Pegs / Hooks (Furniture)", "icon": "icon_anchors", "is_snap": true, "color": Color("#0284c7")},
	{"family": "sit_point", "label": "Sit Baseline (Character Body)", "icon": "icon_seat", "is_snap": true, "color": Color("#a855f7")},
	{"family": "mouth", "label": "Mouth Eating Zone (Interaction)", "icon": "icon_food", "is_snap": false, "color": Color("#d97706")},
	{"family": "faucet_stream", "label": "Water Stream (Interaction)", "icon": "icon_faucet", "is_snap": false, "color": Color("#d97706")},
	{"family": "custom", "label": "Custom Socket Key...", "icon": "icon_pin", "is_snap": true, "color": Color("#ec4899")}
]

func _init() -> void:
	max_panel_width = 680.0
	max_panel_height = 580.0

func _build_content() -> void:
	name = "SnapPointStudioDialog"
	var is_mob: bool = is_mobile()
	var row_h: float = 34.0 if is_mob else 28.0

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 6)
	root_panel.add_child(main_vbox)

	# --- Header ---
	var header_hbox: HBoxContainer = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	header_lbl = Label.new()
	header_lbl.text = "Anchor & Socket Studio"
	header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_lbl.theme_type_variation = "HeaderLabel"
	header_lbl.add_theme_font_size_override("font_size", 14 if is_mob else 12)
	header_hbox.add_child(header_lbl)

	var close_button: Button = Button.new()
	close_button.custom_minimum_size = Vector2(28.0 if is_mob else 22.0, 28.0 if is_mob else 22.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_constant_override("icon_max_width", 12)
	apply_close_icon(close_button)
	close_button.pressed.connect(_on_close_requested)
	header_hbox.add_child(close_button)

	main_vbox.add_child(HSeparator.new())

	# --- Category & New Anchor Creator Bar ---
	var creator_hbox: HBoxContainer = HBoxContainer.new()
	creator_hbox.add_theme_constant_override("separation", 6)
	main_vbox.add_child(creator_hbox)

	opt_family_category = OptionButton.new()
	opt_family_category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt_family_category.custom_minimum_size = Vector2(0.0, row_h)
	opt_family_category.item_selected.connect(_on_family_selected)
	creator_hbox.add_child(opt_family_category)

	custom_name_input = LineEdit.new()
	custom_name_input.placeholder_text = "Key (e.g. tail_1)..."
	custom_name_input.custom_minimum_size = Vector2(120.0 if is_mob else 100.0, row_h)
	custom_name_input.visible = false
	register_keyboard_dodge(custom_name_input)
	creator_hbox.add_child(custom_name_input)

	btn_add_anchor = Button.new()
	btn_add_anchor.text = " + Add Slot"
	btn_add_anchor.custom_minimum_size = Vector2(110.0 if is_mob else 90.0, row_h)
	btn_add_anchor.focus_mode = Control.FOCUS_NONE
	btn_add_anchor.add_theme_constant_override("icon_max_width", 14)
	btn_add_anchor.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	apply_button_icon(btn_add_anchor, "icon_plus")
	btn_add_anchor.pressed.connect(_on_add_anchor_pressed)
	creator_hbox.add_child(btn_add_anchor)

	# --- Precision Coordinates Bar ---
	coords_card = PanelContainer.new()
	coords_card.theme_type_variation = "SubPanel"
	main_vbox.add_child(coords_card)

	var coords_hbox: HBoxContainer = HBoxContainer.new()
	coords_hbox.add_theme_constant_override("separation", 6)
	coords_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	coords_card.add_child(coords_hbox)

	active_badge_lbl = Label.new()
	active_badge_lbl.text = "No anchor selected"
	active_badge_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_badge_lbl.theme_type_variation = "HintLabel"
	active_badge_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	coords_hbox.add_child(active_badge_lbl)

	var lbl_x: Label = Label.new()
	lbl_x.text = "X:"
	lbl_x.theme_type_variation = "HintLabel"
	lbl_x.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	coords_hbox.add_child(lbl_x)

	spin_x = SpinBox.new()
	spin_x.min_value = -2000
	spin_x.max_value = 2000
	spin_x.step = 1.0
	spin_x.custom_minimum_size = Vector2(80.0 if is_mob else 68.0, row_h)
	spin_x.value_changed.connect(_on_coordinate_spin_changed)
	coords_hbox.add_child(spin_x)

	var lbl_y: Label = Label.new()
	lbl_y.text = "Y:"
	lbl_y.theme_type_variation = "HintLabel"
	lbl_y.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	coords_hbox.add_child(lbl_y)

	spin_y = SpinBox.new()
	spin_y.min_value = -2000
	spin_y.max_value = 2000
	spin_y.step = 1.0
	spin_y.custom_minimum_size = Vector2(80.0 if is_mob else 68.0, row_h)
	spin_y.value_changed.connect(_on_coordinate_spin_changed)
	coords_hbox.add_child(spin_y)

	btn_center_anchor = Button.new()
	btn_center_anchor.text = "Center"
	btn_center_anchor.custom_minimum_size = Vector2(58.0 if is_mob else 48.0, row_h)
	btn_center_anchor.focus_mode = Control.FOCUS_NONE
	btn_center_anchor.add_theme_font_size_override("font_size", 10 if is_mob else 9)
	btn_center_anchor.pressed.connect(_on_center_selected_pressed)
	coords_hbox.add_child(btn_center_anchor)

	btn_delete_selected = Button.new()
	btn_delete_selected.text = "✕"
	btn_delete_selected.custom_minimum_size = Vector2(30.0 if is_mob else 26.0, row_h)
	btn_delete_selected.theme_type_variation = "DangerButton"
	btn_delete_selected.focus_mode = Control.FOCUS_NONE
	btn_delete_selected.pressed.connect(_on_delete_selected_pressed)
	coords_hbox.add_child(btn_delete_selected)

	# --- Canvas Area with Dragging ---
	canvas_panel = PanelContainer.new()
	canvas_panel.theme_type_variation = "SubPanel"
	canvas_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_panel.custom_minimum_size = Vector2(0.0, 170.0 if is_mob else 140.0)
	canvas_panel.clip_contents = true
	main_vbox.add_child(canvas_panel)

	sprite_canvas = Control.new()
	sprite_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	sprite_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	sprite_canvas.gui_input.connect(_on_canvas_gui_input)
	canvas_panel.add_child(sprite_canvas)

	sprite_preview_rect = TextureRect.new()
	sprite_preview_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	sprite_preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite_preview_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite_canvas.add_child(sprite_preview_rect)

	marker_overlay = AnchorOverlayDraw.new()
	marker_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	marker_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker_overlay.studio_ref = self
	sprite_canvas.add_child(marker_overlay)

	main_vbox.add_child(HSeparator.new())

	# --- Placed Anchors Header & List ---
	var list_hdr_hbox: HBoxContainer = HBoxContainer.new()
	main_vbox.add_child(list_hdr_hbox)

	anchors_count_lbl = Label.new()
	anchors_count_lbl.text = "Placed Anchors (Tap row to select & drag):"
	anchors_count_lbl.theme_type_variation = "HintLabel"
	anchors_count_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	anchors_count_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_hdr_hbox.add_child(anchors_count_lbl)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 90.0 if is_mob else 75.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = false
	main_vbox.add_child(scroll)

	anchors_list_vbox = VBoxContainer.new()
	anchors_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	anchors_list_vbox.add_theme_constant_override("separation", 3)
	scroll.add_child(anchors_list_vbox)

	main_vbox.add_child(HSeparator.new())

	btn_save = Button.new()
	btn_save.text = " Save Anchors & Close"
	btn_save.custom_minimum_size = Vector2(0.0, row_h + 4.0)
	btn_save.focus_mode = Control.FOCUS_NONE
	btn_save.add_theme_constant_override("icon_max_width", 16)
	btn_save.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	apply_button_icon(btn_save, "icon_save")
	btn_save.pressed.connect(_on_close_requested)
	main_vbox.add_child(btn_save)

func _on_theme_updated() -> void:
	_populate_family_dropdown()
	_refresh_all()
	if root_panel == null: return
	for node: Node in root_panel.find_children("*", "Button", true, false):
		if node is Button and (node as Button).text == "✕":
			apply_close_icon(node as Button)

func _populate_family_dropdown() -> void:
	if opt_family_category == null: return
	var prev_idx: int = opt_family_category.selected
	opt_family_category.clear()

	for index: int in range(family_definitions.size()):
		var definition: Dictionary = family_definitions[index]
		var icon_texture: Texture2D = ThemeService.get_popup_icon(str(definition.get("icon", "")))
		if icon_texture != null:
			opt_family_category.add_icon_item(icon_texture, " " + str(definition["label"]), index)
		else:
			opt_family_category.add_item(str(definition["label"]), index)

	if not family_definitions.is_empty():
		opt_family_category.selected = clampi(prev_idx, 0, family_definitions.size() - 1)

func open_for_entity(entity: OwnEntity) -> void:
	if not is_instance_valid(entity): return
	active_entity = entity
	sprite_preview_rect.texture = entity.main_texture
	_populate_family_dropdown()
	opt_family_category.selected = 0
	_on_family_selected(0)

	selected_anchor_key = ""
	if not entity.snap_points.is_empty():
		selected_anchor_key = entity.snap_points.keys()[0]
		is_selected_snap = true
	elif not entity.interaction_points.is_empty():
		selected_anchor_key = entity.interaction_points.keys()[0]
		is_selected_snap = false

	open_dialog()
	await get_tree().process_frame
	_refresh_all()

func _on_close_requested() -> void:
	if active_entity != null and is_instance_valid(active_entity):
		active_entity.rebuild_gizmos()
		CapabilitySynchronizer.synchronize(active_entity)
		SaveSystem.update_character_in_cast(active_entity)
		SaveSystem.save_current_room_state()
		EventBus.notification_requested.emit("Anchors Saved!", true)
	active_entity = null
	selected_anchor_key = ""
	super._on_close_requested()

func _on_family_selected(index: int) -> void:
	if index < 0 or index >= family_definitions.size(): return
	var definition: Dictionary = family_definitions[index]
	var family: String = str(definition["family"])
	var is_custom: bool = (family == "custom")
	custom_name_input.visible = is_custom

	var next_key: String = _find_next_incremental_key(family, bool(definition["is_snap"]))
	btn_add_anchor.text = " + Add " + next_key

func _on_add_anchor_pressed() -> void:
	if active_entity == null or opt_family_category.selected < 0 or opt_family_category.selected >= family_definitions.size():
		return

	var def: Dictionary = family_definitions[opt_family_category.selected]
	var family: String = str(def["family"])
	var is_snap: bool = bool(def["is_snap"])
	var new_key: String = ""

	if family == "custom":
		var custom_txt: String = custom_name_input.text.strip_edges().to_lower().replace(" ", "_")
		if custom_txt.is_empty(): custom_txt = "custom_1"
		new_key = custom_txt
	elif family == "sit_point":
		new_key = "sit_point"
	else:
		new_key = _find_next_incremental_key(family, is_snap)

	var initial_pos: Vector2 = Vector2.ZERO
	var tex_size: Vector2 = active_entity.texture_size

	match family:
		"sit_point": initial_pos = Vector2(0.0, tex_size.y * 0.35)
		"head", "hat": initial_pos = Vector2(0.0, -tex_size.y * 0.44)
		"face", "glasses": initial_pos = Vector2(0.0, -tex_size.y * 0.32)
		"neck", "necklace": initial_pos = Vector2(0.0, -tex_size.y * 0.20)
		"back", "backpack": initial_pos = Vector2(0.0, -tex_size.y * 0.05)
		"hand":
			var count: int = _count_family_instances("hand", is_snap)
			initial_pos = Vector2(tex_size.x * 0.35 if count % 2 == 0 else -tex_size.x * 0.35, tex_size.y * 0.1)
		"seat": initial_pos = Vector2(0.0, tex_size.y * 0.05)
		"surface": initial_pos = Vector2(0.0, -tex_size.y * 0.25)
		"mouth": initial_pos = Vector2(0.0, -tex_size.y * 0.28)
		"faucet_stream": initial_pos = Vector2(0.0, -tex_size.y * 0.1)
		_: initial_pos = Vector2.ZERO

	initial_pos = Vector2(roundf(initial_pos.x), roundf(initial_pos.y))
	_set_anchor_local_pos(new_key, is_snap, initial_pos)
	_select_anchor(new_key, is_snap)
	_trigger_haptic(30)
	_on_family_selected(opt_family_category.selected)
	EventBus.notification_requested.emit("Added %s. Drag on canvas to position." % new_key, true)

func _find_next_incremental_key(family_prefix: String, is_snap: bool) -> String:
	if active_entity == null: return family_prefix + "_1"
	if family_prefix == "sit_point": return "sit_point"

	var pool: Dictionary = active_entity.snap_points if is_snap else active_entity.interaction_points
	var max_index: int = 0

	for key_name: String in pool.keys():
		if key_name == family_prefix: max_index = maxi(max_index, 1)
		elif key_name.begins_with(family_prefix + "_"):
			var suffix: String = key_name.trim_prefix(family_prefix + "_")
			if suffix.is_valid_int(): max_index = maxi(max_index, suffix.to_int())

	return "%s_%d" % [family_prefix, max_index + 1]

func _count_family_instances(family_prefix: String, is_snap: bool) -> int:
	if active_entity == null: return 0
	var pool: Dictionary = active_entity.snap_points if is_snap else active_entity.interaction_points
	var count: int = 0
	for k: String in pool.keys():
		if k.begins_with(family_prefix): count += 1
	return count

func _on_canvas_gui_input(event: InputEvent) -> void:
	if active_entity == null: return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed: _handle_pointer_down(mb.position)
			else: _handle_pointer_up(mb.position)

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if is_dragging_anchor:
			_handle_pointer_move(mm.position)

	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			active_touch_index = st.index
			_handle_pointer_down(st.position)
		else:
			if st.index == active_touch_index:
				active_touch_index = -1
				_handle_pointer_up(st.position)

	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		if sd.index == active_touch_index and is_dragging_anchor:
			_handle_pointer_move(sd.position)

func _handle_pointer_down(ui_pos: Vector2) -> void:
	if active_entity == null: return

	var touched_key: String = ""
	var touched_is_snap: bool = true
	var closest_dist: float = PIN_TOUCH_RADIUS

	for s_key: String in active_entity.snap_points.keys():
		var p_ui: Vector2 = _sprite_offset_to_ui(active_entity.snap_points[s_key])
		var d: float = ui_pos.distance_to(p_ui)
		if d < closest_dist:
			closest_dist = d
			touched_key = s_key
			touched_is_snap = true

	for i_key: String in active_entity.interaction_points.keys():
		var i_data: Dictionary = active_entity.interaction_points[i_key]
		var point_offset: Vector2 = i_data.get("offset", Vector2.ZERO)
		var p_ui: Vector2 = _sprite_offset_to_ui(point_offset)
		var d: float = ui_pos.distance_to(p_ui)
		if d < closest_dist:
			closest_dist = d
			touched_key = i_key
			touched_is_snap = false

	if not touched_key.is_empty():
		_select_anchor(touched_key, touched_is_snap)
		is_dragging_anchor = true
		_trigger_haptic(20)
	else:
		if not selected_anchor_key.is_empty():
			var local_offset: Vector2 = _ui_to_sprite_offset(ui_pos)
			local_offset = Vector2(roundf(local_offset.x), roundf(local_offset.y))
			_set_anchor_local_pos(selected_anchor_key, is_selected_snap, local_offset)
			is_dragging_anchor = true
			_trigger_haptic(15)
		else:
			EventBus.notification_requested.emit("Tap '+ Add Slot' to create an anchor, or select an existing one below.", true)

func _handle_pointer_move(ui_pos: Vector2) -> void:
	if not is_dragging_anchor or selected_anchor_key.is_empty() or active_entity == null:
		return

	var local_offset: Vector2 = _ui_to_sprite_offset(ui_pos)
	local_offset = Vector2(roundf(local_offset.x), roundf(local_offset.y))
	_set_anchor_local_pos(selected_anchor_key, is_selected_snap, local_offset)

func _handle_pointer_up(_ui_pos: Vector2) -> void:
	if is_dragging_anchor:
		is_dragging_anchor = false
		if active_entity != null and is_instance_valid(active_entity):
			active_entity.rebuild_gizmos()
			EventBus.entity_state_changed.emit(active_entity.entity_id)
		_sync_coordinate_inputs()
		if marker_overlay != null: marker_overlay.queue_redraw()

func _set_anchor_local_pos(key: String, is_snap: bool, local_pos: Vector2) -> void:
	if active_entity == null: return

	if is_snap:
		active_entity.snap_points[key] = local_pos
	else:
		var cur_data: Dictionary = active_entity.interaction_points.get(key, {})
		var type_val: int = int(cur_data.get("type", Types.InteractionPointType.MOUTH))
		var rad_val: float = float(cur_data.get("radius", 55.0))
		if key.begins_with("faucet") or key.begins_with("liquid"):
			type_val = int(Types.InteractionPointType.LIQUID_STREAM)
		active_entity.interaction_points[key] = {
			"offset": local_pos,
			"radius": rad_val,
			"type": type_val
		}

	if active_entity.is_liquid_source:
		active_entity.update_faucet_particles()

	_sync_coordinate_inputs()
	if marker_overlay != null: marker_overlay.queue_redraw()
	_render_anchors_list()

func _select_anchor(key: String, is_snap: bool) -> void:
	selected_anchor_key = key
	is_selected_snap = is_snap
	_match_category_dropdown(key)
	_sync_coordinate_inputs()
	if marker_overlay != null: marker_overlay.queue_redraw()
	_render_anchors_list()

func _match_category_dropdown(key: String) -> void:
	if opt_family_category == null: return
	for index: int in range(family_definitions.size()):
		var family: String = str(family_definitions[index]["family"])
		if family != "custom" and key.begins_with(family):
			opt_family_category.selected = index
			custom_name_input.visible = false
			_on_family_selected(index)
			return

	opt_family_category.selected = family_definitions.size() - 1
	custom_name_input.visible = true
	custom_name_input.text = key

func _sync_coordinate_inputs() -> void:
	if _is_updating_ui or spin_x == null or spin_y == null: return
	_is_updating_ui = true

	var has_selection: bool = not selected_anchor_key.is_empty() and active_entity != null
	spin_x.editable = has_selection
	spin_y.editable = has_selection
	btn_center_anchor.disabled = not has_selection
	btn_delete_selected.disabled = not has_selection

	if has_selection:
		var current_pos: Vector2 = Vector2.ZERO
		if is_selected_snap: current_pos = active_entity.snap_points.get(selected_anchor_key, Vector2.ZERO)
		else: current_pos = active_entity.interaction_points.get(selected_anchor_key, {}).get("offset", Vector2.ZERO)

		active_badge_lbl.text = "Selected: [ %s ]" % selected_anchor_key
		active_badge_lbl.add_theme_color_override("font_color", ThemeService.get_color("accent_primary", "#ec4899"))
		spin_x.value = current_pos.x
		spin_y.value = current_pos.y
	else:
		active_badge_lbl.text = "Select an anchor or tap '+ Add Slot'"
		active_badge_lbl.remove_theme_color_override("font_color")
		spin_x.value = 0
		spin_y.value = 0

	_is_updating_ui = false

func _on_coordinate_spin_changed(_val: float) -> void:
	if _is_updating_ui or selected_anchor_key.is_empty() or active_entity == null:
		return
	var new_local_pos: Vector2 = Vector2(roundf(spin_x.value), roundf(spin_y.value))
	_set_anchor_local_pos(selected_anchor_key, is_selected_snap, new_local_pos)

func _on_center_selected_pressed() -> void:
	if selected_anchor_key.is_empty() or active_entity == null: return
	_set_anchor_local_pos(selected_anchor_key, is_selected_snap, Vector2.ZERO)
	_trigger_haptic(15)

func _on_delete_selected_pressed() -> void:
	if selected_anchor_key.is_empty() or active_entity == null: return
	var key_to_del: String = selected_anchor_key
	var was_snap: bool = is_selected_snap
	selected_anchor_key = ""

	if was_snap: active_entity.snap_points.erase(key_to_del)
	else: active_entity.interaction_points.erase(key_to_del)

	active_entity.rebuild_gizmos()
	EventBus.entity_state_changed.emit(active_entity.entity_id)
	_sync_coordinate_inputs()
	_refresh_all()
	EventBus.notification_requested.emit("Deleted: " + key_to_del, true)

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

func _get_color_for_key(key_name: String, is_snap: bool) -> Color:
	var lowercase_key: String = key_name.to_lower()
	for definition: Dictionary in family_definitions:
		var family: String = str(definition["family"])
		if family != "custom" and lowercase_key.begins_with(family):
			return definition["color"] as Color
	return Color("#ec4899") if is_snap else Color("#d97706")

func _get_icon_for_key(key_name: String, is_snap: bool) -> String:
	var lowercase_key: String = key_name.to_lower()
	for definition: Dictionary in family_definitions:
		var family: String = str(definition["family"])
		if family != "custom" and lowercase_key.begins_with(family):
			return str(definition.get("icon", "icon_anchors"))
	return "icon_anchors" if is_snap else "icon_food"

func _refresh_all() -> void:
	_sync_coordinate_inputs()
	if marker_overlay != null: marker_overlay.queue_redraw()
	_render_anchors_list()

func _render_anchors_list() -> void:
	if anchors_list_vbox == null: return
	for child: Node in anchors_list_vbox.get_children():
		child.queue_free()

	if active_entity == null: return
	var total_count: int = active_entity.snap_points.size() + active_entity.interaction_points.size()
	anchors_count_lbl.text = "Placed Anchors (%d):" % total_count

	if total_count == 0:
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "No anchors placed yet. Select a category and tap '+ Add Slot'."
		empty_lbl.theme_type_variation = "HintLabel"
		empty_lbl.add_theme_font_size_override("font_size", 11 if is_mobile() else 10)
		anchors_list_vbox.add_child(empty_lbl)
		return

	for socket_name: String in active_entity.snap_points.keys():
		var pos: Vector2 = active_entity.snap_points[socket_name]
		var is_sel: bool = (socket_name == selected_anchor_key and is_selected_snap)
		var icon_key: String = _get_icon_for_key(socket_name, true)
		_create_anchor_list_row(socket_name, pos, true, icon_key, is_sel)

	for inter_name: String in active_entity.interaction_points.keys():
		var data: Dictionary = active_entity.interaction_points[inter_name]
		var pos: Vector2 = data.get("offset", Vector2.ZERO)
		var is_sel: bool = (inter_name == selected_anchor_key and not is_selected_snap)
		var icon_key: String = _get_icon_for_key(inter_name, false)
		_create_anchor_list_row(inter_name, pos, false, icon_key, is_sel)

func _create_anchor_list_row(anchor_key: String, pos: Vector2, is_snap: bool, icon_key: String, is_selected: bool) -> void:
	var is_mob: bool = is_mobile()
	var card: PanelContainer = PanelContainer.new()
	card.theme_type_variation = "SubPanel"
	card.custom_minimum_size = Vector2(0.0, 36.0 if is_mob else 30.0)

	var c_accent: Color = ThemeService.get_color("accent_primary", "#ec4899")
	var c_border: Color = ThemeService.get_color("panel_border", "#f472b6")
	var c_sub_bg: Color = ThemeService.get_color("container_sub_bg", "#fff0f3")
	var rad: int = ThemeService.get_corner_radius()

	var row_style: StyleBoxFlat = StyleBoxFlat.new()
	row_style.bg_color = Color(c_accent.r, c_accent.g, c_accent.b, 0.12) if is_selected else c_sub_bg
	row_style.border_color = c_accent if is_selected else c_border
	row_style.set_border_width_all(2 if is_selected else 1)
	row_style.set_corner_radius_all(rad)
	row_style.content_margin_left = 8
	row_style.content_margin_right = 8
	row_style.content_margin_top = 2
	row_style.content_margin_bottom = 2
	card.add_theme_stylebox_override("panel", row_style)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	card.add_child(hbox)

	var select_btn: Button = Button.new()
	select_btn.text = " %s  (X: %d, Y: %d)" % [anchor_key, int(pos.x), int(pos.y)]
	select_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_btn.flat = true
	select_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	select_btn.focus_mode = Control.FOCUS_NONE
	select_btn.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	select_btn.add_theme_constant_override("icon_max_width", 16 if is_mob else 14)

	var row_icon: Texture2D = ThemeService.get_icon(icon_key)
	if row_icon != null: select_btn.icon = row_icon
	if is_selected:
		select_btn.add_theme_color_override("font_color", c_accent)

	select_btn.pressed.connect(func() -> void:
		_select_anchor(anchor_key, is_snap)
		_trigger_haptic(15)
	)
	hbox.add_child(select_btn)

	var delete_btn: Button = Button.new()
	delete_btn.custom_minimum_size = Vector2(26.0 if is_mob else 20.0, 26.0 if is_mob else 20.0)
	delete_btn.theme_type_variation = "DangerButton"
	delete_btn.focus_mode = Control.FOCUS_NONE
	delete_btn.add_theme_constant_override("icon_max_width", 10)
	apply_close_icon(delete_btn)
	delete_btn.pressed.connect(func() -> void:
		if is_snap: active_entity.snap_points.erase(anchor_key)
		else: active_entity.interaction_points.erase(anchor_key)
		if selected_anchor_key == anchor_key: selected_anchor_key = ""
		active_entity.rebuild_gizmos()
		EventBus.entity_state_changed.emit(active_entity.entity_id)
		_refresh_all()
	)
	hbox.add_child(delete_btn)
	anchors_list_vbox.add_child(card)

func _trigger_haptic(duration_ms: int = 25) -> void:
	if SettingsManager.are_haptics_enabled() and (OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")):
		if Input.has_method("vibrate_handheld"):
			Input.vibrate_handheld(duration_ms)

class AnchorOverlayDraw extends Control:
	var studio_ref: SnapPointStudioDialog = null

	func _draw() -> void:
		if studio_ref == null or studio_ref.active_entity == null:
			return

		var render_rect: Rect2 = studio_ref._get_texture_render_rect()
		var center: Vector2 = render_rect.position + (render_rect.size * 0.5)

		draw_rect(render_rect, Color(1.0, 1.0, 1.0, 0.15), false, 1.0)
		draw_line(Vector2(center.x - 8.0, center.y), Vector2(center.x + 8.0, center.y), Color(1.0, 1.0, 1.0, 0.35), 1.0)
		draw_line(Vector2(center.x, center.y - 8.0), Vector2(center.x, center.y + 8.0), Color(1.0, 1.0, 1.0, 0.35), 1.0)

		var font: Font = ThemeDB.fallback_font
		var ent: OwnEntity = studio_ref.active_entity
		var sel_key: String = studio_ref.selected_anchor_key
		var sel_is_snap: bool = studio_ref.is_selected_snap

		for i_key: String in ent.interaction_points.keys():
			var data: Dictionary = ent.interaction_points[i_key]
			var pt_offset: Vector2 = data.get("offset", Vector2.ZERO)
			var radius: float = float(data.get("radius", 55.0))
			var p_ui: Vector2 = studio_ref._sprite_offset_to_ui(pt_offset)
			var scale_f: float = render_rect.size.x / maxf(ent.texture_size.x, 1.0)
			var scaled_rad: float = radius * scale_f
			var is_sel: bool = (i_key == sel_key and not sel_is_snap)
			var col: Color = studio_ref._get_color_for_key(i_key, false)
			draw_arc(p_ui, scaled_rad, 0.0, TAU, 32, Color(col.r, col.g, col.b, 0.35 if not is_sel else 0.7), 1.5)

		if not sel_key.is_empty():
			var active_local_pos: Vector2 = Vector2.ZERO
			if sel_is_snap: active_local_pos = ent.snap_points.get(sel_key, Vector2.ZERO)
			else: active_local_pos = ent.interaction_points.get(sel_key, {}).get("offset", Vector2.ZERO)

			var active_ui_pos: Vector2 = studio_ref._sprite_offset_to_ui(active_local_pos)
			var c_accent: Color = ThemeService.get_color("accent_primary", "#ec4899")

			draw_line(Vector2(0.0, active_ui_pos.y), Vector2(size.x, active_ui_pos.y), Color(c_accent.r, c_accent.g, c_accent.b, 0.45), 1.0)
			draw_line(Vector2(active_ui_pos.x, 0.0), Vector2(active_ui_pos.x, size.y), Color(c_accent.r, c_accent.g, c_accent.b, 0.45), 1.0)
			draw_circle(active_ui_pos, 16.0, Color(c_accent.r, c_accent.g, c_accent.b, 0.2))
			draw_arc(active_ui_pos, 14.0, 0.0, TAU, 24, c_accent, 2.0)

		var all_anchors: Array[Dictionary] = []
		for s_key: String in ent.snap_points.keys():
			all_anchors.append({"key": s_key, "pos": ent.snap_points[s_key], "is_snap": true})
		for i_key: String in ent.interaction_points.keys():
			var data: Dictionary = ent.interaction_points[i_key]
			all_anchors.append({"key": i_key, "pos": data.get("offset", Vector2.ZERO), "is_snap": false})

		for anchor: Dictionary in all_anchors:
			var key: String = str(anchor["key"])
			var local_pos: Vector2 = anchor["pos"] as Vector2
			var is_snap: bool = bool(anchor["is_snap"])
			var ui_pos: Vector2 = studio_ref._sprite_offset_to_ui(local_pos)
			var is_sel: bool = (key == sel_key and is_snap == sel_is_snap)
			var pin_color: Color = studio_ref._get_color_for_key(key, is_snap)

			draw_circle(ui_pos + Vector2(1.0, 1.0), 7.5, Color(0.0, 0.0, 0.0, 0.6))
			draw_circle(ui_pos, 6.5, pin_color)
			draw_circle(ui_pos, 2.5, Color.WHITE)

			var text_str: String = key
			var font_sz: int = 10 if studio_ref.is_mobile() else 9
			var text_w: float = font.get_string_size(text_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz).x
			var badge_rect: Rect2 = Rect2(ui_pos.x + 10.0, ui_pos.y - 8.0, text_w + 8.0, 16.0)

			var bg_color: Color = Color("#09090b", 0.90) if is_sel else Color("#18181b", 0.65)
			var border_color: Color = Color.WHITE if is_sel else Color(pin_color.r, pin_color.g, pin_color.b, 0.7)
			draw_rect(badge_rect, bg_color, true)
			draw_rect(badge_rect, border_color, false, 1.0)
			draw_string(font, Vector2(badge_rect.position.x + 4.0, badge_rect.position.y + 11.5), text_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, Color.WHITE)

			if is_sel and studio_ref.is_dragging_anchor:
				var coord_str: String = "(X: %d, Y: %d)" % [int(local_pos.x), int(local_pos.y)]
				var c_text_w: float = font.get_string_size(coord_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz).x
				var coord_rect: Rect2 = Rect2(ui_pos.x - (c_text_w * 0.5) - 4.0, ui_pos.y - 28.0, c_text_w + 8.0, 15.0)
				draw_rect(coord_rect, Color("#ec4899", 0.95), true)
				draw_string(font, Vector2(coord_rect.position.x + 4.0, coord_rect.position.y + 11.5), coord_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, Color.WHITE)
