# ==============================================================================
# OWNWORLD — LOGIC RULE EDITOR (NO-CODE CAUSE & EFFECT VISUAL SCRIPTING)
# File: res://UI/Dialogs/LogicRuleEditorDialog.gd
# Base Class: CanvasLayer (class_name LogicRuleEditorDialog)
#
# Responsibility: No-code cause-and-effect visual logic scripting modal.
# Configures (When Trigger -> Target Mode -> Action Execution) rules with dynamic
# parameter input fields, dialogue text boxes, emotion symbol bars, and asset spawners.
# ==============================================================================

class_name LogicRuleEditorDialog
extends CanvasLayer

const MAX_PANEL_WIDTH: float = 680.0
const MAX_PANEL_HEIGHT: float = 580.0
const SYMBOL_PRESETS: Array[String] = ["❤️", "⭐", "🎵", "💧", "🌸", "❓", "❗"]

var root_backdrop: Control = null
var center_container: CenterContainer = null
var root_panel: PanelContainer = null
var active_entity: OwnEntity = null
var asset_picker: AssetPickerDialog = null

var header_lbl: Label = null
var when_box: PanelContainer = null
var lbl_when: Label = null
var opt_when: OptionButton = null
var item_filter_edit: LineEdit = null

var target_box: PanelContainer = null
var lbl_target: Label = null
var opt_target: OptionButton = null

var then_box: PanelContainer = null
var lbl_then: Label = null
var opt_then: OptionButton = null

var param_container: VBoxContainer = null
var dynamic_opt_param: OptionButton = null
var dynamic_line_param: LineEdit = null
var emoji_bar_hbox: HBoxContainer = null
var btn_browse_spawn: Button = null

var selected_spawn_art_name: String = ""
var btn_add_rule: Button = null
var rules_list_vbox: VBoxContainer = null


func _ready() -> void:
	name = "LogicRuleEditorDialog"
	layer = 120
	visible = false
	add_to_group("modal_ui")
	_build_ui()
	_connect_system_signals()
	_update_responsive_layout()

	asset_picker = AssetPickerDialog.new()
	add_child(asset_picker)


func _is_mobile() -> bool:
	return ThemeEngine.is_mobile_platform()


func _connect_system_signals() -> void:
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null and not tree.root.size_changed.is_connected(_update_responsive_layout):
		tree.root.size_changed.connect(_update_responsive_layout)
	if not EventBus.theme_changed.is_connected(_on_theme_changed):
		EventBus.theme_changed.connect(_on_theme_changed)


func _on_theme_changed(_theme_data: Dictionary) -> void:
	_refresh_theme_icons()
	_update_responsive_layout()
	_render_rules_list()


func _update_responsive_layout() -> void:
	if not is_instance_valid(root_panel): return
	var viewport: Viewport = get_viewport()
	var viewport_size: Vector2 = viewport.get_visible_rect().size if viewport != null else Vector2(1280.0, 720.0)
	var is_mob: bool = _is_mobile()

	var target_width: float = clampf(viewport_size.x * 0.94, 320.0, MAX_PANEL_WIDTH)
	var target_height: float = clampf(viewport_size.y * (0.92 if is_mob else 0.88), 300.0, MAX_PANEL_HEIGHT)
	root_panel.custom_minimum_size = Vector2(target_width, target_height)
	root_panel.size = Vector2(target_width, target_height)


func _build_ui() -> void:
	var is_mob: bool = _is_mobile()
	var row_h: float = 34.0 if is_mob else 28.0

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

	var outer_vbox: VBoxContainer = VBoxContainer.new()
	outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_theme_constant_override("separation", 6)
	root_panel.add_child(outer_vbox)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	outer_vbox.add_child(header_hbox)

	header_lbl = Label.new()
	header_lbl.text = "Cause & Effect Logic Studio"
	header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_lbl.theme_type_variation = "HeaderLabel"
	header_lbl.add_theme_font_size_override("font_size", 14 if is_mob else 12)
	header_hbox.add_child(header_lbl)

	var close_button: Button = Button.new()
	close_button.custom_minimum_size = Vector2(28.0 if is_mob else 22.0, 28.0 if is_mob else 22.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_constant_override("icon_max_width", 12)
	close_button.pressed.connect(close_dialog)
	_apply_close_icon(close_button)
	header_hbox.add_child(close_button)

	outer_vbox.add_child(HSeparator.new())

	var body_scroll: ScrollContainer = ScrollContainer.new()
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.follow_focus = false
	outer_vbox.add_child(body_scroll)

	var body_vbox: VBoxContainer = VBoxContainer.new()
	body_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_vbox.add_theme_constant_override("separation", 8)
	body_scroll.add_child(body_vbox)

	_build_when_section(body_vbox, row_h)
	_build_target_section(body_vbox, row_h)
	_build_action_section(body_vbox, row_h)

	btn_add_rule = Button.new()
	btn_add_rule.text = " Add Cause & Effect Rule"
	btn_add_rule.custom_minimum_size = Vector2(0.0, row_h + 4.0)
	btn_add_rule.focus_mode = Control.FOCUS_NONE
	btn_add_rule.add_theme_constant_override("icon_max_width", 16)
	btn_add_rule.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	btn_add_rule.pressed.connect(_on_add_rule_pressed)
	body_vbox.add_child(btn_add_rule)

	outer_vbox.add_child(HSeparator.new())

	var rules_scroll: ScrollContainer = ScrollContainer.new()
	rules_scroll.custom_minimum_size = Vector2(0.0, 110.0 if is_mob else 90.0)
	rules_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rules_scroll.follow_focus = false
	outer_vbox.add_child(rules_scroll)

	rules_list_vbox = VBoxContainer.new()
	rules_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rules_list_vbox.add_theme_constant_override("separation", 4)
	rules_scroll.add_child(rules_list_vbox)

	_refresh_theme_icons()


func _build_when_section(parent: VBoxContainer, row_h: float) -> void:
	var is_mob: bool = _is_mobile()
	when_box = PanelContainer.new()
	when_box.theme_type_variation = "SubPanel"
	parent.add_child(when_box)

	var when_vbox: VBoxContainer = VBoxContainer.new()
	when_vbox.add_theme_constant_override("separation", 4)
	when_box.add_child(when_vbox)

	lbl_when = Label.new()
	lbl_when.text = "1. When This Happens:"
	lbl_when.theme_type_variation = "HeaderLabel"
	lbl_when.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	when_vbox.add_child(lbl_when)

	opt_when = OptionButton.new()
	opt_when.custom_minimum_size = Vector2(0.0, row_h)
	opt_when.add_item("When Tapped / Clicked", int(Types.TriggerEvent.ON_TAPPED))
	opt_when.add_item("When an Item is Dropped Onto It", int(Types.TriggerEvent.ON_ITEM_RECEIVED))
	opt_when.add_item("When Grabbed / Picked Up", int(Types.TriggerEvent.ON_DRAG_STARTED))
	opt_when.add_item("When Released / Dropped", int(Types.TriggerEvent.ON_DRAG_ENDED))
	opt_when.item_selected.connect(_on_when_trigger_changed)
	when_vbox.add_child(opt_when)

	item_filter_edit = LineEdit.new()
	item_filter_edit.placeholder_text = "(Optional) Only if dropped item is named: e.g. Magic Key"
	item_filter_edit.custom_minimum_size = Vector2(0.0, row_h)
	item_filter_edit.visible = false
	when_vbox.add_child(item_filter_edit)


func _build_target_section(parent: VBoxContainer, row_h: float) -> void:
	var is_mob: bool = _is_mobile()
	target_box = PanelContainer.new()
	target_box.theme_type_variation = "SubPanel"
	parent.add_child(target_box)

	var target_vbox: VBoxContainer = VBoxContainer.new()
	target_vbox.add_theme_constant_override("separation", 4)
	target_box.add_child(target_vbox)

	lbl_target = Label.new()
	lbl_target.text = "2. Apply Action To:"
	lbl_target.theme_type_variation = "HeaderLabel"
	lbl_target.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	target_vbox.add_child(lbl_target)

	opt_target = OptionButton.new()
	opt_target.custom_minimum_size = Vector2(0.0, row_h)
	opt_target.add_item("This Item / Self", int(Types.ActionTarget.SELF))
	opt_target.add_item("The Item Dropped Onto It", int(Types.ActionTarget.TRIGGER_ITEM))
	opt_target.add_item("All Characters in Room", int(Types.ActionTarget.ROOM_ALL_CHARACTERS))
	opt_target.add_item("Room Environment (Mood / Weather)", int(Types.ActionTarget.ENVIRONMENT))
	target_vbox.add_child(opt_target)


func _build_action_section(parent: VBoxContainer, row_h: float) -> void:
	var is_mob: bool = _is_mobile()
	then_box = PanelContainer.new()
	then_box.theme_type_variation = "SubPanel"
	parent.add_child(then_box)

	var then_vbox: VBoxContainer = VBoxContainer.new()
	then_vbox.add_theme_constant_override("separation", 4)
	then_box.add_child(then_vbox)

	lbl_then = Label.new()
	lbl_then.text = "3. Then Execute Action:"
	lbl_then.theme_type_variation = "HeaderLabel"
	lbl_then.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	then_vbox.add_child(lbl_then)

	opt_then = OptionButton.new()
	opt_then.custom_minimum_size = Vector2(0.0, row_h)
	opt_then.add_item("Play Animation / Pose", int(Types.ActionCommand.PLAY_ANIM))
	opt_then.add_item("Stop Animation", int(Types.ActionCommand.STOP_ANIM))
	opt_then.add_item("Swap Outfit Form", int(Types.ActionCommand.SWAP_FORM))
	opt_then.add_item("Set Transient Expression", int(Types.ActionCommand.SET_EXPRESSION))
	opt_then.add_item("Say Dialogue (Speech Bubble)", int(Types.ActionCommand.SAY_DIALOGUE))
	opt_then.add_item("Spray Emotion Symbol", int(Types.ActionCommand.SPRAY_EMOTION))
	opt_then.add_item("Play Sound Effect", int(Types.ActionCommand.PLAY_SOUND))
	opt_then.add_item("Change Room Mood (Day/Sunset/Night)", int(Types.ActionCommand.SET_MOOD))
	opt_then.add_item("Set Weather (Rain/Snow/Dust)", int(Types.ActionCommand.SET_WEATHER))
	opt_then.add_item("Spawn Item from Art Library", int(Types.ActionCommand.SPAWN_ITEM_UGC))
	opt_then.add_item("Advance State / Take Bite", int(Types.ActionCommand.ADVANCE_STATE))
	opt_then.add_item("Teleport to Another Room", int(Types.ActionCommand.TELEPORT_ROOM_CUSTOM))
	opt_then.item_selected.connect(_on_then_action_changed)
	then_vbox.add_child(opt_then)

	param_container = VBoxContainer.new()
	param_container.add_theme_constant_override("separation", 6)
	then_vbox.add_child(param_container)

	dynamic_opt_param = OptionButton.new()
	dynamic_opt_param.custom_minimum_size = Vector2(0.0, row_h)
	dynamic_opt_param.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	param_container.add_child(dynamic_opt_param)

	dynamic_line_param = LineEdit.new()
	dynamic_line_param.custom_minimum_size = Vector2(0.0, row_h)
	dynamic_line_param.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	param_container.add_child(dynamic_line_param)

	emoji_bar_hbox = HBoxContainer.new()
	emoji_bar_hbox.add_theme_constant_override("separation", 6)
	param_container.add_child(emoji_bar_hbox)

	var emoji_btn_size: float = 38.0 if is_mob else 30.0
	for symbol: String in SYMBOL_PRESETS:
		var emoji_button: Button = Button.new()
		emoji_button.text = symbol
		emoji_button.custom_minimum_size = Vector2(emoji_btn_size, emoji_btn_size)
		emoji_button.focus_mode = Control.FOCUS_NONE
		emoji_button.add_theme_font_size_override("font_size", 14 if is_mob else 12)
		var captured_symbol: String = symbol
		emoji_button.pressed.connect(func() -> void: dynamic_line_param.text = captured_symbol)
		emoji_bar_hbox.add_child(emoji_button)

	btn_browse_spawn = Button.new()
	btn_browse_spawn.text = " Browse Art to Spawn..."
	btn_browse_spawn.custom_minimum_size = Vector2(0.0, row_h)
	btn_browse_spawn.focus_mode = Control.FOCUS_NONE
	btn_browse_spawn.add_theme_constant_override("icon_max_width", 14)
	btn_browse_spawn.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	btn_browse_spawn.pressed.connect(_on_browse_spawn_pressed)
	param_container.add_child(btn_browse_spawn)


func open_for_entity(entity: OwnEntity) -> void:
	if not is_instance_valid(entity): return
	active_entity = entity
	selected_spawn_art_name = ""
	if btn_browse_spawn != null: btn_browse_spawn.text = " Browse Art to Spawn..."
	_update_responsive_layout()
	_on_when_trigger_changed(0)
	_on_then_action_changed(0)
	_render_rules_list()
	visible = true


func close_dialog() -> void:
	visible = false
	active_entity = null
	selected_spawn_art_name = ""


func _on_when_trigger_changed(index: int) -> void:
	if opt_when == null: return
	var trigger_id: int = opt_when.get_item_id(index)
	if item_filter_edit != null:
		item_filter_edit.visible = (trigger_id == int(Types.TriggerEvent.ON_ITEM_RECEIVED))


func _on_then_action_changed(index: int) -> void:
	if opt_then == null: return
	var action_id: int = opt_then.get_item_id(index)

	dynamic_opt_param.visible = false
	dynamic_line_param.visible = false
	emoji_bar_hbox.visible = false
	btn_browse_spawn.visible = false

	match action_id:
		int(Types.ActionCommand.PLAY_ANIM):
			dynamic_opt_param.clear()
			dynamic_opt_param.visible = true
			if active_entity != null and active_entity.wardrobe_forms.has(active_entity.active_form_key):
				var form_data: Dictionary = active_entity.wardrobe_forms[active_entity.active_form_key]
				var states: Dictionary = form_data.get("states", {})
				for state_name: String in states.keys():
					dynamic_opt_param.add_item(state_name, dynamic_opt_param.item_count)
			for fallback_animation: String in ["mouth_open", "eyes_closed", "sitting", "sleeping"]:
				dynamic_opt_param.add_item(fallback_animation, dynamic_opt_param.item_count)
		int(Types.ActionCommand.SWAP_FORM):
			dynamic_opt_param.clear()
			dynamic_opt_param.visible = true
			if active_entity != null:
				for form_name: String in active_entity.wardrobe_forms.keys():
					dynamic_opt_param.add_item(form_name, dynamic_opt_param.item_count)
		int(Types.ActionCommand.SET_EXPRESSION):
			dynamic_opt_param.clear()
			dynamic_opt_param.visible = true
			dynamic_opt_param.add_item("mouth_open", 0)
			dynamic_opt_param.add_item("eyes_closed", 1)
			dynamic_opt_param.add_item("eyes_open", 2)
		int(Types.ActionCommand.SAY_DIALOGUE):
			dynamic_line_param.visible = true
			dynamic_line_param.text = "Hello!"
			dynamic_line_param.placeholder_text = "Type dialogue text here..."
		int(Types.ActionCommand.SPRAY_EMOTION):
			dynamic_line_param.visible = true
			emoji_bar_hbox.visible = true
			dynamic_line_param.text = "❤️"
		int(Types.ActionCommand.PLAY_SOUND):
			dynamic_opt_param.clear()
			dynamic_opt_param.visible = true
			dynamic_opt_param.add_item("Chime", 0)
			dynamic_opt_param.add_item("Pop", 1)
			dynamic_opt_param.add_item("Chew / Bite", 2)
			dynamic_opt_param.add_item("Sip", 3)
			dynamic_opt_param.add_item("Pour", 4)
		int(Types.ActionCommand.SET_MOOD):
			dynamic_opt_param.clear()
			dynamic_opt_param.visible = true
			for i: int in range(5):
				dynamic_opt_param.add_item(["Day", "Sunset", "Night", "Cozy", "Cyberpunk"][i], i)
		int(Types.ActionCommand.SET_WEATHER):
			dynamic_opt_param.clear()
			dynamic_opt_param.visible = true
			for i: int in range(5):
				dynamic_opt_param.add_item(["Clear", "Rain", "Snow", "Leaves", "Dust"][i], i)
		int(Types.ActionCommand.SPAWN_ITEM_UGC):
			btn_browse_spawn.visible = true
			btn_browse_spawn.text = " " + (selected_spawn_art_name if not selected_spawn_art_name.is_empty() else "Browse Art to Spawn...")
		int(Types.ActionCommand.TELEPORT_ROOM_CUSTOM):
			dynamic_line_param.visible = true
			dynamic_line_param.text = "room_main"
			dynamic_line_param.placeholder_text = "Target Room ID (e.g. room_garden)..."


func _on_browse_spawn_pressed() -> void:
	if asset_picker == null: return
	asset_picker.open_picker("Choose Item to Spawn", "", func(art_name: String, _tex: Texture2D, _file_path: String) -> void:
		selected_spawn_art_name = art_name
		btn_browse_spawn.text = " Spawn: " + art_name
	)


func _on_add_rule_pressed() -> void:
	if active_entity == null or not is_instance_valid(active_entity):
		return

	var when_id: int = opt_when.get_selected_id()
	var target_id: int = opt_target.get_selected_id()
	var then_id: int = opt_then.get_selected_id()
	var resolved_parameter: String = ""

	if dynamic_opt_param.visible and dynamic_opt_param.item_count > 0:
		resolved_parameter = dynamic_opt_param.get_item_text(dynamic_opt_param.selected)
	elif dynamic_line_param.visible:
		resolved_parameter = dynamic_line_param.text.strip_edges()
	elif btn_browse_spawn.visible:
		resolved_parameter = selected_spawn_art_name

	var new_rule: Dictionary = {
		"when": when_id,
		"target": target_id,
		"then": then_id,
		"val": resolved_parameter,
		"item_filter": (item_filter_edit.text.strip_edges() if item_filter_edit.visible else "")
	}

	active_entity.logic_rules.append(new_rule)
	_render_rules_list()
	_persist_active_entity()
	EventBus.notification_requested.emit("Logic Rule Added!", true)


func _persist_active_entity() -> void:
	if active_entity == null or not is_instance_valid(active_entity):
		return
	if active_entity.entity_type == Types.EntityType.CHARACTER:
		SaveSystem.update_character_in_cast(active_entity)
	SaveSystem.save_current_room_state()
	EventBus.entity_state_changed.emit(active_entity.entity_id)


func _render_rules_list() -> void:
	if rules_list_vbox == null: return
	for child: Node in rules_list_vbox.get_children():
		child.queue_free()

	var is_mob: bool = _is_mobile()

	if active_entity == null or active_entity.logic_rules.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No active rules. Add a rule above to build cause-and-effect puzzles!"
		empty_label.theme_type_variation = "HintLabel"
		empty_label.add_theme_font_size_override("font_size", 11 if is_mob else 10)
		rules_list_vbox.add_child(empty_label)
		return

	for index: int in range(active_entity.logic_rules.size()):
		var rule: Dictionary = active_entity.logic_rules[index]
		var card: PanelContainer = PanelContainer.new()
		card.theme_type_variation = "SubPanel"
		card.custom_minimum_size = Vector2(0.0, 38.0 if is_mob else 32.0)

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		card.add_child(hbox)

		var when_text: String = _get_when_label(int(rule.get("when", 0)))
		var filter_text: String = str(rule.get("item_filter", "")).strip_edges()
		if not filter_text.is_empty(): when_text += " (" + filter_text + ")"

		var target_text: String = _get_target_label(int(rule.get("target", 0)))
		var action_text: String = _get_then_label(int(rule.get("then", 0)))
		var parameter_text: String = str(rule.get("val", "")).strip_edges()
		var summary: String = "%s ➔ %s ➔ %s%s" % [
			when_text, target_text, action_text,
			(" (" + parameter_text + ")" if not parameter_text.is_empty() else "")
		]

		var label: Label = Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = summary
		label.add_theme_font_size_override("font_size", 11 if is_mob else 10)
		hbox.add_child(label)

		var delete_button: Button = Button.new()
		delete_button.custom_minimum_size = Vector2(28.0 if is_mob else 22.0, 28.0 if is_mob else 22.0)
		delete_button.theme_type_variation = "DangerButton"
		delete_button.focus_mode = Control.FOCUS_NONE
		delete_button.add_theme_constant_override("icon_max_width", 10)
		_apply_close_icon(delete_button)

		var captured_index: int = index
		delete_button.pressed.connect(func() -> void: _remove_rule(captured_index))
		hbox.add_child(delete_button)
		rules_list_vbox.add_child(card)


func _remove_rule(rule_index: int) -> void:
	if active_entity == null or not is_instance_valid(active_entity): return
	if rule_index < 0 or rule_index >= active_entity.logic_rules.size(): return
	active_entity.logic_rules.remove_at(rule_index)
	_render_rules_list()
	_persist_active_entity()
	EventBus.notification_requested.emit("Logic Rule Removed.", true)


func _get_when_label(id: int) -> String:
	match id:
		int(Types.TriggerEvent.ON_TAPPED): return "Tapped"
		int(Types.TriggerEvent.ON_ITEM_RECEIVED): return "Item Dropped"
		int(Types.TriggerEvent.ON_DRAG_STARTED): return "Picked Up"
		int(Types.TriggerEvent.ON_DRAG_ENDED): return "Released"
	return "Event"


func _get_target_label(id: int) -> String:
	match id:
		int(Types.ActionTarget.SELF): return "Self"
		int(Types.ActionTarget.TRIGGER_ITEM): return "Dropped Item"
		int(Types.ActionTarget.ROOM_ALL_CHARACTERS): return "All Characters"
		int(Types.ActionTarget.ENVIRONMENT): return "Environment"
	return "Target"


func _get_then_label(id: int) -> String:
	match id:
		int(Types.ActionCommand.PLAY_ANIM): return "Play Anim"
		int(Types.ActionCommand.STOP_ANIM): return "Stop Anim"
		int(Types.ActionCommand.SWAP_FORM): return "Swap Outfit"
		int(Types.ActionCommand.SET_EXPRESSION): return "Expression"
		int(Types.ActionCommand.SAY_DIALOGUE): return "Say Dialogue"
		int(Types.ActionCommand.SPRAY_EMOTION): return "Spray Symbol"
		int(Types.ActionCommand.PLAY_SOUND): return "Play Sound"
		int(Types.ActionCommand.SET_MOOD): return "Change Mood"
		int(Types.ActionCommand.SET_WEATHER): return "Set Weather"
		int(Types.ActionCommand.SPAWN_ITEM), int(Types.ActionCommand.SPAWN_ITEM_UGC): return "Spawn Item"
		int(Types.ActionCommand.ADVANCE_STATE): return "Advance State"
		int(Types.ActionCommand.TELEPORT_ROOM), int(Types.ActionCommand.TELEPORT_ROOM_CUSTOM): return "Teleport"
	return "Action"


func _refresh_theme_icons() -> void:
	if btn_add_rule != null:
		var logic_icon: Texture2D = ThemeService.get_icon("icon_logic")
		if logic_icon == null: logic_icon = ThemeService.get_icon("icon_plus")
		if logic_icon != null: btn_add_rule.icon = logic_icon

	if btn_browse_spawn != null:
		var folder_icon: Texture2D = ThemeService.get_icon("icon_folder")
		if folder_icon != null: btn_browse_spawn.icon = folder_icon

	_render_rules_list()


func _apply_close_icon(button: Button) -> void:
	if button == null: return
	var close_icon: Texture2D = ThemeService.get_icon("icon_close")
	if close_icon != null: button.icon = close_icon
	else: button.text = "✕"


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		close_dialog()
