# ==============================================================================
# OWNWORLD — MAGIC WHEEL / CONTEXT ACTION CARD (SAFE-BOUNDED & ADAPTIVE)
# File: res://UI/MagicWheel.gd
# Base Class: CanvasLayer (class_name MagicWheel)
#
# Responsibility: Context action card summoned via timed long-press (mobile)
# or instant right-click (desktop). Guarantees complete viewport and safe-area bounds.
# ==============================================================================

class_name MagicWheel
extends CanvasLayer

var root_backdrop: Control = null
var card_panel: PanelContainer = null
var header_lbl: Label = null
var tools_grid: GridContainer = null
var active_target_entity: OwnEntity = null

const CARD_WIDTH_MOBILE: float = 320.0
const CARD_WIDTH_DESKTOP: float = 280.0

signal action_triggered(action_name: String, target_entity: OwnEntity)


func _ready() -> void:
	name = "MagicWheel"
	layer = 115
	visible = false
	add_to_group(&"modal_ui")
	_build_card_ui()

	if not ThemeService.theme_changed.is_connected(_on_theme_changed):
		ThemeService.theme_changed.connect(_on_theme_changed)


func _is_mobile() -> bool:
	return ThemeEngine.is_mobile_platform()


func _build_card_ui() -> void:
	var is_mob: bool = _is_mobile()
	var card_w: float = CARD_WIDTH_MOBILE if is_mob else CARD_WIDTH_DESKTOP

	root_backdrop = Control.new()
	root_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_backdrop.mouse_filter = Control.MOUSE_FILTER_PASS
	root_backdrop.gui_input.connect(_on_backdrop_gui_input)
	add_child(root_backdrop)

	card_panel = PanelContainer.new()
	card_panel.name = "ContextCardPanel"
	card_panel.theme_type_variation = "SubPanel"
	card_panel.custom_minimum_size = Vector2(card_w, 0.0)
	card_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root_backdrop.add_child(card_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card_panel.add_child(vbox)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	vbox.add_child(header_hbox)

	header_lbl = Label.new()
	header_lbl.text = "Item Actions"
	header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_lbl.theme_type_variation = "HeaderLabel"
	header_lbl.add_theme_font_size_override("font_size", 13 if is_mob else 12)
	header_hbox.add_child(header_lbl)

	var btn_close: Button = Button.new()
	btn_close.custom_minimum_size = Vector2(28.0 if is_mob else 22.0, 28.0 if is_mob else 22.0)
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.add_theme_constant_override("icon_max_width", 14 if is_mob else 12)
	var close_icon: Texture2D = ThemeService.get_icon("icon_close")
	if close_icon != null: 
		btn_close.icon = close_icon
	else: 
		btn_close.text = "✕"
	btn_close.pressed.connect(close_wheel)
	header_hbox.add_child(btn_close)

	vbox.add_child(HSeparator.new())

	tools_grid = GridContainer.new()
	tools_grid.columns = 2
	tools_grid.add_theme_constant_override("h_separation", 6)
	tools_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(tools_grid)


func open_wheel_for_entity(entity: OwnEntity, screen_pos: Vector2) -> void:
	if not is_instance_valid(entity): 
		return
	active_target_entity = entity
	header_lbl.text = entity.display_name

	for child: Node in tools_grid.get_children():
		child.queue_free()

	_populate_context_tools(entity)
	_position_card_safely(screen_pos)

	visible = true
	card_panel.pivot_offset = Vector2.ZERO
	card_panel.scale = Vector2(0.92, 0.92)
	card_panel.modulate.a = 0.0

	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_panel, "scale", Vector2.ONE, 0.14)
	tween.parallel().tween_property(card_panel, "modulate:a", 1.0, 0.14)
	AudioManager.play_pop_grab()


func _populate_context_tools(entity: OwnEntity) -> void:
	if not is_instance_valid(entity):
		return
	var is_mob: bool = _is_mobile()
	var btn_h: float = 38.0 if is_mob else 30.0

	var tools: Array[Dictionary] = []
	tools.append({"name": "character_studio", "label": "States & Anims", "icon": "icon_states"})

	if entity.entity_type == Types.EntityType.CHARACTER:
		tools.append({"name": "lore", "label": "Profile", "icon": "icon_lore"})
		tools.append({"name": "anchors", "label": "Anchors", "icon": "icon_anchors"})
		tools.append({"name": "flip", "label": "Flip Horizontal", "icon": "icon_flip"})
	elif entity.is_stairs:
		tools.append({"name": "climb_stairs", "label": "Climb Above", "icon": "icon_up"})
		tools.append({"name": "save_template", "label": "Save Prefab", "icon": "icon_prefab"})
		tools.append({"name": "flip", "label": "Flip Horizontal", "icon": "icon_flip"})
	elif entity.is_elevator:
		tools.append({"name": "elevator", "label": "Keypad", "icon": "icon_elevator"})
		tools.append({"name": "save_template", "label": "Save Prefab", "icon": "icon_prefab"})
		tools.append({"name": "flip", "label": "Flip Horizontal", "icon": "icon_flip"})
	elif entity.is_portal:
		tools.append({"name": "edit_door", "label": "Destination", "icon": "icon_door"})
		tools.append({"name": "save_template", "label": "Save Prefab", "icon": "icon_prefab"})
		tools.append({"name": "flip", "label": "Flip Horizontal", "icon": "icon_flip"})
	else:
		tools.append({"name": "anchors", "label": "Anchors", "icon": "icon_anchors"})
		tools.append({"name": "save_template", "label": "Save Prefab", "icon": "icon_prefab"})
		tools.append({"name": "flip", "label": "Flip Horizontal", "icon": "icon_flip"})

	if entity.is_consumable or entity.is_drink or entity.is_liquid_container:
		tools.append({"name": "food_studio", "label": "Food & Drink", "icon": "icon_food"})

	if entity.is_light_source:
		tools.append({"name": "lighting", "label": "Lighting", "icon": "icon_lighting"})

	tools.append({"name": "config", "label": "Interactions", "icon": "icon_interactions"})
	tools.append({"name": "logic", "label": "Logic Rules", "icon": "icon_logic"})
	tools.append({"name": "clone", "label": "Clone", "icon": "icon_clone"})
	tools.append({"name": "lock", "label": ("Unlock" if entity.is_locked else "Lock"), "icon": "icon_lock"})

	if entity.entity_type == Types.EntityType.CHARACTER:
		tools.append({"name": "store", "label": "Return to Cast", "icon": "icon_cast"})
	else:
		tools.append({"name": "lore", "label": "Item Notes", "icon": "icon_lore"})

	tools.append({"name": "delete", "label": "Delete", "icon": "icon_delete"})

	for tool_data: Dictionary in tools:
		var btn: Button = Button.new()
		btn.text = " " + str(tool_data["label"])
		btn.custom_minimum_size = Vector2(0.0, btn_h)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 11 if is_mob else 10)
		btn.add_theme_constant_override("icon_max_width", 16 if is_mob else 14)

		var icon_texture: Texture2D = ThemeService.get_icon(str(tool_data["icon"]))
		if icon_texture == null and str(tool_data["icon"]) == "icon_up":
			icon_texture = ThemeService.get_icon("icon_stairs")
		if icon_texture != null:
			btn.icon = icon_texture
			btn.expand_icon = false

		var action_name: String = str(tool_data["name"])
		if action_name == "delete": 
			btn.theme_type_variation = "DangerButton"
		btn.pressed.connect(func() -> void: _execute_action(action_name))
		tools_grid.add_child(btn)


func _position_card_safely(screen_pos: Vector2) -> void:
	if not is_instance_valid(card_panel):
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()

	var min_safe_x: float = maxf(12.0, float(safe_area.position.x) + 6.0)
	var max_safe_x: float = minf(viewport_size.x - 12.0, float(safe_area.position.x + safe_area.size.x) - 6.0)
	var min_safe_y: float = maxf(12.0, float(safe_area.position.y) + 6.0)
	var max_safe_y: float = minf(viewport_size.y - 12.0, float(safe_area.position.y + safe_area.size.y) - 6.0)

	var is_mob: bool = _is_mobile()
	var card_w: float = CARD_WIDTH_MOBILE if is_mob else CARD_WIDTH_DESKTOP
	var estimated_h: float = card_panel.size.y if card_panel.size.y > 0.0 else 260.0

	var target_x: float = screen_pos.x + 20.0
	var target_y: float = screen_pos.y - 40.0

	if target_x + card_w > max_safe_x:
		target_x = screen_pos.x - card_w - 20.0

	target_x = clampf(target_x, min_safe_x, maxf(min_safe_x, max_safe_x - card_w))
	target_y = clampf(target_y, min_safe_y, maxf(min_safe_y, max_safe_y - estimated_h))
	card_panel.position = Vector2(target_x, target_y)


func _execute_action(action_name: String) -> void:
	var target: OwnEntity = active_target_entity
	close_wheel()
	if is_instance_valid(target):
		action_triggered.emit(action_name, target)


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		close_wheel()


func close_wheel() -> void:
	visible = false
	active_target_entity = null


func _on_theme_changed(_theme_data: Dictionary) -> void:
	pass
