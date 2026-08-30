# ==============================================================================
# OWNWORLD — INTERACTION SOLVER & DYNAMIC HOVER PHYSICS
# File: res://Systems/InteractionSolver.gd
# Base Class: RefCounted (class_name InteractionSolver)
#
# Responsibility: Real-time proximity solver for solid food consumption,
# cup-to-cup liquid pouring tilts, faucet filling, and drag-and-drop recipe merging.
# Integrates granular SettingsManager juice checks for zero-overhead performance.
# ==============================================================================

class_name InteractionSolver
extends RefCounted

static var hover_eat_timer: float = 0.0
static var hover_drink_timer: float = 0.0
static var hover_pour_timer: float = 0.0

const MAX_POUR_DIST_SQ: float = 4900.0


static func process_live_interactions(delta: float, active_dragged: OwnEntity, all_entities: Array[OwnEntity]) -> void:
	if not is_instance_valid(active_dragged):
		hover_eat_timer = 0.0
		hover_drink_timer = 0.0
		hover_pour_timer = 0.0
		return

	# 1. Solid Food Proximity Eating
	if active_dragged.is_consumable and not active_dragged.is_drink:
		_process_food_eating_zone(delta, active_dragged, all_entities)

	if not is_instance_valid(active_dragged):
		return

	# 2. Drink Sipping with Physical Tilt
	if active_dragged.is_drink and (active_dragged.is_infinite or active_dragged.fill_level > 0):
		_process_drink_sipping_zone(delta, active_dragged, all_entities)
	elif not active_dragged.is_liquid_source:
		if not is_zero_approx(active_dragged.rotation):
			if SettingsManager.is_juice_physical_tilts_enabled():
				active_dragged.rotation = lerp_angle(active_dragged.rotation, 0.0, 10.0 * delta)
			else:
				active_dragged.rotation = 0.0

	# 3. Cup-to-Cup Liquid Pouring with Physical Tilt
	if active_dragged.is_liquid_source or (active_dragged.is_drink and (active_dragged.is_infinite or active_dragged.fill_level > 0)):
		_process_cup_to_cup_pouring(delta, active_dragged, all_entities)

	# 4. Dragging a Cup under a Running Faucet / Water Stream
	if active_dragged.is_liquid_container and active_dragged.fill_level < 2:
		_process_cup_under_faucet(delta, active_dragged, all_entities)


static func _get_character_mouth_data(character: OwnEntity) -> Dictionary:
	if not is_instance_valid(character):
		return {"found": false, "global_pos": Vector2.ZERO, "radius_sq": 0.0}

	if character.interaction_points.has("mouth_1"):
		var m_data: Dictionary = character.interaction_points["mouth_1"]
		var offset_pos: Vector2 = m_data.get("offset", Vector2(0.0, -32.0))
		var radius: float = float(m_data.get("radius", 60.0))
		return {
			"found": true,
			"global_pos": character.to_global(offset_pos),
			"radius_sq": radius * radius
		}

	for ik: String in character.interaction_points.keys():
		if ik.begins_with("mouth"):
			var m_data: Dictionary = character.interaction_points[ik]
			var offset_pos: Vector2 = m_data.get("offset", Vector2(0.0, -32.0))
			var radius: float = float(m_data.get("radius", 60.0))
			return {
				"found": true,
				"global_pos": character.to_global(offset_pos),
				"radius_sq": radius * radius
			}
	return {"found": false, "global_pos": Vector2.ZERO, "radius_sq": 0.0}


static func _get_faucet_stream_data(source: OwnEntity) -> Dictionary:
	if not is_instance_valid(source):
		return {"found": false, "global_pos": Vector2.ZERO, "radius_sq": 0.0}

	for ik: String in source.interaction_points.keys():
		if ik.begins_with("faucet") or ik.begins_with("liquid"):
			var f_data: Dictionary = source.interaction_points[ik]
			var offset_pos: Vector2 = f_data.get("offset", Vector2.ZERO)
			var radius: float = float(f_data.get("radius", 50.0))
			return {
				"found": true,
				"global_pos": source.to_global(offset_pos),
				"radius_sq": radius * radius
			}
	for sk: String in source.snap_points.keys():
		if sk.begins_with("faucet") or sk.begins_with("liquid"):
			var offset_pos: Vector2 = source.snap_points[sk]
			return {
				"found": true,
				"global_pos": source.to_global(offset_pos),
				"radius_sq": 2500.0
			}
	return {"found": true, "global_pos": source.global_position, "radius_sq": 2500.0}


static func _process_food_eating_zone(delta: float, food: OwnEntity, all_entities: Array[OwnEntity]) -> void:
	var eater: OwnEntity = null
	var food_pos: Vector2 = food.global_position

	for ent: OwnEntity in all_entities:
		if is_instance_valid(ent) and ent.entity_type == Types.EntityType.CHARACTER and ent != food:
			var mouth_info: Dictionary = _get_character_mouth_data(ent)
			if bool(mouth_info["found"]):
				var m_pos: Vector2 = mouth_info["global_pos"]
				var rad_sq: float = float(mouth_info["radius_sq"])
				if food_pos.distance_squared_to(m_pos) <= rad_sq:
					eater = ent
					break

	if eater != null and is_instance_valid(eater):
		eater.set_actor_state(Types.STATE_EATING, 0.4)
		hover_eat_timer -= delta
		if hover_eat_timer <= 0.0:
			hover_eat_timer = 0.45
			eater.spray_emotion("❤️")
			AudioManager.play_pop_grab()

			var is_finished: bool = food.take_bite()
			if is_finished and not food.is_infinite:
				_erase_entity_hierarchy(food, all_entities)
				food.queue_free()
	else:
		hover_eat_timer = 0.0


static func _process_drink_sipping_zone(delta: float, drink: OwnEntity, all_entities: Array[OwnEntity]) -> void:
	var drinker: OwnEntity = null
	var drink_pos: Vector2 = drink.global_position

	for ent: OwnEntity in all_entities:
		if is_instance_valid(ent) and ent.entity_type == Types.EntityType.CHARACTER and ent != drink:
			var mouth_info: Dictionary = _get_character_mouth_data(ent)
			if bool(mouth_info["found"]):
				var m_pos: Vector2 = mouth_info["global_pos"]
				var rad_sq: float = float(mouth_info["radius_sq"])
				if drink_pos.distance_squared_to(m_pos) <= rad_sq:
					drinker = ent
					break

	if drinker != null and is_instance_valid(drinker):
		drinker.set_actor_state(Types.STATE_SPEAKING, 0.4)
		if SettingsManager.is_juice_physical_tilts_enabled():
			var tilt_dir: float = -0.55 if drink_pos.x > drinker.global_position.x else 0.55
			drink.rotation = lerp_angle(drink.rotation, tilt_dir, 14.0 * delta)

		hover_drink_timer -= delta
		if hover_drink_timer <= 0.0:
			hover_drink_timer = 0.65
			AudioManager.play_pop_grab()
			drink.take_sip()
	else:
		hover_drink_timer = 0.1


static func _process_cup_to_cup_pouring(delta: float, source_cup: OwnEntity, all_entities: Array[OwnEntity]) -> void:
	var target_cup: OwnEntity = null
	var source_stream_pos: Vector2 = source_cup.global_position
	if source_cup.is_liquid_source:
		source_stream_pos = source_cup.to_global(source_cup.get_faucet_stream_offset())

	for ent: OwnEntity in all_entities:
		if is_instance_valid(ent) and ent != source_cup and ent.is_liquid_container and ent.fill_level < 2:
			if source_stream_pos.y < ent.global_position.y:
				if source_stream_pos.distance_squared_to(ent.global_position) <= MAX_POUR_DIST_SQ:
					target_cup = ent
					break

	if target_cup != null and is_instance_valid(target_cup):
		if SettingsManager.is_juice_physical_tilts_enabled():
			var pour_tilt: float = 0.65 if source_stream_pos.x < target_cup.global_position.x else -0.65
			source_cup.rotation = lerp_angle(source_cup.rotation, pour_tilt, 14.0 * delta)

		hover_pour_timer -= delta
		if hover_pour_timer <= 0.0:
			hover_pour_timer = 0.6
			target_cup.fill_with_liquid()
			if source_cup.is_drink and not source_cup.is_infinite:
				source_cup.fill_level = maxi(source_cup.fill_level - 1, 0)
	else:
		hover_pour_timer = 0.15


static func _process_cup_under_faucet(delta: float, cup: OwnEntity, all_entities: Array[OwnEntity]) -> void:
	var running_faucet: OwnEntity = null
	var cup_pos: Vector2 = cup.global_position

	for ent: OwnEntity in all_entities:
		if is_instance_valid(ent) and ent != cup and ent.is_liquid_source and ent.is_active:
			var f_data: Dictionary = _get_faucet_stream_data(ent)
			var f_pos: Vector2 = f_data["global_pos"]
			var rad_sq: float = float(f_data["radius_sq"])
			if cup_pos.distance_squared_to(f_pos) <= rad_sq:
				running_faucet = ent
				break

	if running_faucet != null and is_instance_valid(running_faucet):
		hover_pour_timer -= delta
		if hover_pour_timer <= 0.0:
			hover_pour_timer = 0.6
			cup.fill_with_liquid()


static func _erase_entity_hierarchy(ent: OwnEntity, entities_list: Array[OwnEntity]) -> void:
	if not is_instance_valid(ent):
		return
	entities_list.erase(ent)
	for child: OwnEntity in ent.attached_children:
		if is_instance_valid(child):
			_erase_entity_hierarchy(child, entities_list)


static func check_and_execute_crafting(dropped: OwnEntity, all_entities: Array[OwnEntity], canvas: Node2D) -> bool:
	if not is_instance_valid(dropped) or not is_instance_valid(canvas):
		return false

	var drop_pos: Vector2 = dropped.global_position
	for target: OwnEntity in all_entities:
		if is_instance_valid(target) and target != dropped:
			if target.contains_point(drop_pos):
				var craft_result: Dictionary = RecipeCrafting.check_and_craft(dropped, target)
				if not craft_result.is_empty():
					var spawn_pos: Vector2 = target.global_position
					RecipeCrafting.spawn_merge_poof(canvas, spawn_pos)

					_erase_entity_hierarchy(dropped, all_entities)
					_erase_entity_hierarchy(target, all_entities)
					dropped.queue_free()
					target.queue_free()

					var res_name: String = str(craft_result.get("name", "Crafted Item"))
					var res_type: Types.EntityType = int(craft_result.get("type", Types.EntityType.PROP)) as Types.EntityType
					var res_path: String = str(craft_result.get("tex_path", ""))
					var uid: String = AppState.generate_entity_uuid(res_name)

					var res_tex: Texture2D = null
					if not res_path.is_empty() and FileAccess.file_exists(res_path):
						res_tex = UGCManager.load_texture_from_file(res_path)
					else:
						res_tex = UGCManager.create_blank_starter_graphic(Vector2(48.0, 48.0), Color("#b45309"))

					var new_item: OwnEntity = OwnEntity.new()
					new_item.setup(uid, res_name, res_tex, spawn_pos, res_type, res_path)
					new_item.configure_as_consumable()
					canvas.add_child(new_item)
					all_entities.append(new_item)
					new_item.trigger_spawn_juice()

					AudioManager.play_snap_chime()
					EventBus.notification_requested.emit("Crafted: " + res_name, true)
					return true
	return false
