# ==============================================================================
# OWNWORLD — LOGIC ENGINE
# File: res://Systems/LogicEngine.gd
# Base Class: RefCounted (class_name LogicEngine)
# ==============================================================================

class_name LogicEngine
extends RefCounted


static func evaluate_trigger(trigger_event: Types.TriggerEvent, source_entity: OwnEntity, context: Dictionary = {}) -> void:
	if source_entity == null or not is_instance_valid(source_entity) or source_entity.logic_rules.is_empty():
		return

	for rule: Dictionary in source_entity.logic_rules:
		if int(rule.get("when", -1)) != int(trigger_event):
			continue
		if not _passes_item_filter(rule, context) or not _passes_condition(rule, source_entity):
			continue
		_dispatch_action(rule, source_entity, context)


static func _passes_item_filter(rule: Dictionary, context: Dictionary) -> bool:
	var item_filter: String = str(rule.get("item_filter", "")).strip_edges().to_lower()
	if item_filter.is_empty():
		return true

	var received_item: OwnEntity = context.get("item", null) as OwnEntity
	if received_item == null or not is_instance_valid(received_item):
		return false

	var item_name: String = received_item.display_name.strip_edges().to_lower()
	var item_id: String = received_item.entity_id.strip_edges().to_lower()
	return item_name == item_filter or item_id == item_filter


static func _passes_condition(rule: Dictionary, source_entity: OwnEntity) -> bool:
	var condition_field: String = str(rule.get("condition_field", "")).strip_edges()
	var condition_value: String = str(rule.get("condition_val", "")).strip_edges()
	if condition_field.is_empty() or condition_value.is_empty():
		return true
	return _evaluate_condition(source_entity, condition_field, condition_value)


static func _evaluate_condition(entity: OwnEntity, field: String, expected_value: String) -> bool:
	var expected: String = expected_value.strip_edges().to_lower()
	match field.strip_edges().to_lower():
		"active_form": return entity.active_form_key.strip_edges().to_lower() == expected
		"current_pose": return entity.current_pose_state.strip_edges().to_lower() == expected
		"is_active": return str(entity.is_active).to_lower() == expected
		"is_locked": return str(entity.is_locked).to_lower() == expected
		_: return true


static func _dispatch_action(rule: Dictionary, source_entity: OwnEntity, context: Dictionary) -> void:
	var target_mode: int = int(rule.get("target", Types.ActionTarget.SELF))
	var action_command: int = int(rule.get("then", -1))
	var value: String = str(rule.get("val", "")).strip_edges()

	match target_mode:
		int(Types.ActionTarget.SELF):
			_execute_single_target_action(action_command, value, source_entity, context)
		int(Types.ActionTarget.TRIGGER_ITEM):
			var received_item: OwnEntity = context.get("item", null) as OwnEntity
			if received_item != null and is_instance_valid(received_item):
				_execute_single_target_action(action_command, value, received_item, context)
		int(Types.ActionTarget.ROOM_ALL_CHARACTERS):
			_execute_room_character_action(action_command, value, context)
		int(Types.ActionTarget.ENVIRONMENT):
			_execute_environment_action(action_command, value)

	_publish_rule_notification(rule, source_entity)


static func _execute_single_target_action(action_command: int, value: String, target: OwnEntity, _context: Dictionary) -> void:
	if target == null or not is_instance_valid(target):
		return

	match action_command:
		int(Types.ActionCommand.PLAY_ANIM): target.play_named_animation(value)
		101: target.reset_to_default_pose()
		int(Types.ActionCommand.SWAP_FORM): target.switch_wardrobe_form(value)
		102: target.set_expression(value.to_lower(), 2.0)
		103: target.show_speech_bubble(value)
		104: target.spray_emotion(value if not value.is_empty() else "✨")
		int(Types.ActionCommand.PLAY_SOUND): _play_sound(value)
		int(Types.ActionCommand.TOGGLE_LIGHT), 105: _apply_mood_action(value)
		106: AppState.set_weather_preset(value if not value.is_empty() else "rain")
		107: _request_spawn_item(value, target.global_position + Vector2(randf_range(-30.0, 30.0), -40.0))
		int(Types.ActionCommand.ADVANCE_STATE):
			if target.is_consumable: target.take_bite()
			elif target.has_method("toggle_active_state"): target.toggle_active_state()
		108: _request_room_transition(value)
		_: pass


static func _execute_room_character_action(action_command: int, value: String, context: Dictionary) -> void:
	var raw_entities: Variant = context.get("entities", [])
	if raw_entities is Array:
		for value_variant: Variant in (raw_entities as Array):
			if value_variant is OwnEntity and is_instance_valid(value_variant as OwnEntity):
				var entity: OwnEntity = value_variant as OwnEntity
				if entity.entity_type == Types.EntityType.CHARACTER:
					_execute_single_target_action(action_command, value, entity, context)


static func _execute_environment_action(action_command: int, value: String) -> void:
	match action_command:
		int(Types.ActionCommand.TOGGLE_LIGHT), 105: AppState.set_time_preset(value if not value.is_empty() else "sunset")
		106: AppState.set_weather_preset(value if not value.is_empty() else "rain")
		108: _request_room_transition(value)
		_: pass


static func _play_sound(value: String) -> void:
	match value.to_lower():
		"pop": AudioManager.play_pop_grab()
		"chew", "bite": AudioManager.play_chew()
		"sip": AudioManager.play_sip()
		"pour": AudioManager.play_pour()
		"drop": AudioManager.play_drop_cushion()
		_: AudioManager.play_snap_chime()


static func _apply_mood_action(value: String) -> void:
	AppState.set_time_preset(value if not value.is_empty() else "sunset")


static func _request_room_transition(room_id: String) -> void:
	var normalized_room_id: String = room_id.strip_edges()
	if normalized_room_id.is_empty(): normalized_room_id = AppState.DEFAULT_ROOM_ID
	EventBus.room_change_requested.emit(normalized_room_id, {})


static func _request_spawn_item(art_name_or_path: String, spawn_position: Vector2) -> void:
	var requested_name: String = art_name_or_path.strip_edges()
	if requested_name.is_empty():
		return

	var art_files: Array[Dictionary] = UGCManager.scan_user_art_library()
	var chosen_texture: Texture2D = null
	var chosen_path: String = ""
	var chosen_name: String = requested_name

	for art: Dictionary in art_files:
		var art_name: String = str(art.get("name", "")).strip_edges()
		var file_path: String = str(art.get("file_path", ""))
		if art_name.to_lower() == requested_name.to_lower() or file_path == requested_name:
			if art.get("texture", null) is Texture2D:
				chosen_texture = art["texture"] as Texture2D
			chosen_path = file_path
			chosen_name = art_name if not art_name.is_empty() else "Item"
			break

	if chosen_texture == null:
		chosen_texture = UGCManager.create_blank_starter_graphic(Vector2(64.0, 64.0), Color.GOLD)

	EventBus.entity_spawn_requested.emit({
		"source": "logic_engine",
		"item_name": chosen_name,
		"texture": chosen_texture,
		"file_path": chosen_path,
		"position": {"x": spawn_position.x, "y": spawn_position.y}
	})


static func _publish_rule_notification(rule: Dictionary, source_entity: OwnEntity) -> void:
	var message: String = str(rule.get("toast_msg", "")).strip_edges()
	if message.is_empty(): message = "Triggered: " + source_entity.display_name
	EventBus.notification_requested.emit(message, true)
