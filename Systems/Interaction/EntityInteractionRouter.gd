# ==============================================================================
# OWNWORLD — ENTITY INTERACTION ROUTER (HYPER OPTIMIZED)
# File: res://Systems/Interaction/EntityInteractionRouter.gd
# Base Class: Node
#
# Responsibility: Decoupled routing of tap and drop interactions to appropriate
# entity capabilities (containers, portals, liquids, sockets, crafting merges).
# ==============================================================================

class_name EntityInteractionRouter
extends Node

signal interaction_handled(source: OwnEntity, action: StringName)


func handle_tap(entity: OwnEntity, all_entities: Array[OwnEntity]) -> void:
	if not is_instance_valid(entity):
		return

	LogicEngine.evaluate_trigger(Types.TriggerEvent.ON_TAPPED, entity)

	if entity.is_stairs:
		_handle_stairs_tap(entity, all_entities)
		interaction_handled.emit(entity, &"stairs_travel")
		return

	if entity.is_elevator:
		var elevator: EntityElevatorCapability = entity.get_component(&"EntityElevatorCapability") as EntityElevatorCapability
		if is_instance_valid(elevator):
			elevator.request_floor_selection()
			interaction_handled.emit(entity, &"elevator_floor_selection")
		return

	var container: EntityContainerCapability = entity.get_component(&"EntityContainerCapability") as EntityContainerCapability
	if is_instance_valid(container):
		container.toggle_open()
		interaction_handled.emit(entity, &"container_toggle")
		return

	var light: EntityLightCapability = entity.get_component(&"EntityLightCapability") as EntityLightCapability
	if is_instance_valid(light):
		light.toggle()
		interaction_handled.emit(entity, &"light_toggle")
		return

	if entity.has_method("toggle_active_state"):
		entity.toggle_active_state()

	interaction_handled.emit(entity, &"tap")


func handle_drop(source: OwnEntity, _world_position: Vector2, context: Dictionary) -> void:
	if not is_instance_valid(source):
		return

	var entities: Array[OwnEntity] = _extract_entities(context.get("entities", []))

	if _try_portal(source, entities): 
		return
	if _try_container(source, entities): 
		return
	if _try_liquid(source, entities): 
		return
	if _try_socket(source, entities): 
		return

	var canvas: Node2D = context.get("canvas", null) as Node2D
	if is_instance_valid(canvas) and InteractionSolver.check_and_execute_crafting(source, entities, canvas):
		EventBus.entity_state_changed.emit(source.entity_id)
		interaction_handled.emit(source, &"crafting")
		return

	interaction_handled.emit(source, &"default_drop")


func _try_portal(source: OwnEntity, entities: Array[OwnEntity]) -> bool:
	if source.entity_type != Types.EntityType.CHARACTER:
		return false

	for candidate: OwnEntity in entities:
		if candidate == source or not is_instance_valid(candidate) or not candidate.is_portal:
			continue
		if not candidate.contains_point(source.global_position):
			continue

		if candidate.is_stairs:
			_handle_stairs_travel(candidate, source)
			interaction_handled.emit(source, &"stairs_travel")
			return true
		elif candidate.is_elevator:
			var elevator: EntityElevatorCapability = candidate.get_component(&"EntityElevatorCapability") as EntityElevatorCapability
			if is_instance_valid(elevator):
				elevator.request_floor_selection()
				interaction_handled.emit(source, &"elevator_floor_selection")
			return true
		else:
			var capability: EntityPortalCapability = candidate.get_component(&"EntityPortalCapability") as EntityPortalCapability
			if capability == null:
				capability = EntityPortalCapability.new()
				capability.configure(candidate.target_room_id, candidate.display_name)
				candidate.add_component(capability)

			if capability.request_travel(source):
				interaction_handled.emit(source, &"portal_travel")
				return true

	return false


func _try_container(source: OwnEntity, entities: Array[OwnEntity]) -> bool:
	if source.entity_type != Types.EntityType.PROP:
		return false

	for candidate: OwnEntity in entities:
		if candidate == source or not is_instance_valid(candidate) or not candidate.is_container:
			continue
		if not candidate.contains_point(source.global_position):
			continue

		var capability: EntityContainerCapability = candidate.get_component(&"EntityContainerCapability") as EntityContainerCapability
		if capability == null:
			capability = EntityContainerCapability.new()
			capability.is_open = candidate.is_open
			for item: Dictionary in candidate.stored_item_data:
				capability.stored_items.append(item.duplicate(true))
			candidate.add_component(capability)

		if capability.store_item(source):
			EventBus.entity_removed.emit(source.entity_id)
			entities.erase(source)
			source.queue_free()
			EventBus.notification_requested.emit("Packed into: " + candidate.display_name, true)
			interaction_handled.emit(candidate, &"container_store")
			return true

	return false


func _try_liquid(source: OwnEntity, entities: Array[OwnEntity]) -> bool:
	var source_liquid: EntityLiquidCapability = source.get_component(&"EntityLiquidCapability") as EntityLiquidCapability
	if source_liquid == null or not source_liquid.can_pour():
		return false

	for candidate: OwnEntity in entities:
		if candidate == source or not is_instance_valid(candidate) or not candidate.contains_point(source.global_position):
			continue

		var target_liquid: EntityLiquidCapability = candidate.get_component(&"EntityLiquidCapability") as EntityLiquidCapability
		if target_liquid == null or not target_liquid.can_receive():
			continue

		if target_liquid.fill_one():
			if not source_liquid.is_source:
				source_liquid.consume_one()
			interaction_handled.emit(source, &"liquid_transfer")
			return true

	return false


func _try_socket(source: OwnEntity, entities: Array[OwnEntity]) -> bool:
	if SocketManager.evaluate_and_snap(source, entities):
		interaction_handled.emit(source, &"socket_attach")
		return true
	return false


func _extract_entities(value: Variant) -> Array[OwnEntity]:
	var result: Array[OwnEntity] = []
	if value is Array:
		for candidate: Variant in (value as Array):
			if candidate is OwnEntity and is_instance_valid(candidate as OwnEntity):
				result.append(candidate as OwnEntity)
	return result


func _handle_stairs_tap(stairs: OwnEntity, all_entities: Array[OwnEntity]) -> void:
	var current_room: String = AppState.room_id
	var bldg_id: String = AppState.building_id
	var bldg_floors: Array[Dictionary] = SaveSystem.get_building_floors(bldg_id)

	if bldg_floors.size() <= 1:
		EventBus.notification_requested.emit("There are no other floors in this building.", true)
		return

	var next_floor: Dictionary = SaveSystem.get_next_floor_above(bldg_id, current_room)
	if next_floor.is_empty():
		EventBus.notification_requested.emit("There are no other floors above in this building.", true)
		return

	var target_room_id: String = str(next_floor.get("room_id", "")).strip_edges()
	var target_floor_label: String = str(next_floor.get("label", next_floor.get("floor_level", "Floor Above")))

	var passengers: Array[OwnEntity] = stairs.get_passengers_in_cab(all_entities)
	var bundle: Array[Dictionary] = []
	for p: OwnEntity in passengers:
		if is_instance_valid(p):
			bundle.append_array(p.get_full_hierarchy_bundle())
			p.queue_free()

	AudioManager.play_snap_chime()
	EventBus.notification_requested.emit("Climbing to: " + target_floor_label, true)
	EventBus.room_change_requested.emit(target_room_id, {
		"bundle": bundle,
		"arrival_stairs": true,
		"floor_name": target_floor_label,
		"building_id": bldg_id,
		"building_name": AppState.building_name,
		"source": "stairs"
	})


func _handle_stairs_travel(_stairs: OwnEntity, traveler: OwnEntity) -> void:
	var current_room: String = AppState.room_id
	var bldg_id: String = AppState.building_id
	var bldg_floors: Array[Dictionary] = SaveSystem.get_building_floors(bldg_id)

	if bldg_floors.size() <= 1:
		EventBus.notification_requested.emit("There are no other floors in this building.", true)
		return

	var next_floor: Dictionary = SaveSystem.get_next_floor_above(bldg_id, current_room)
	if next_floor.is_empty():
		EventBus.notification_requested.emit("There are no other floors above in this building.", true)
		return

	var target_room_id: String = str(next_floor.get("room_id", "")).strip_edges()
	var target_floor_label: String = str(next_floor.get("label", next_floor.get("floor_level", "Floor Above")))

	var bundle: Array[Dictionary] = traveler.get_full_hierarchy_bundle()
	traveler.queue_free()

	for item: Dictionary in bundle:
		var c_id: String = str(item.get("id", ""))
		var c_name: String = str(item.get("display_name", ""))
		if not c_id.is_empty():
			DrawerMetadataService.scrub_character_from_universe_rooms(c_id, c_name)

	AudioManager.play_snap_chime()
	EventBus.notification_requested.emit("Climbing to: " + target_floor_label, true)
	EventBus.room_change_requested.emit(target_room_id, {
		"bundle": bundle,
		"arrival_stairs": true,
		"floor_name": target_floor_label,
		"building_id": bldg_id,
		"building_name": AppState.building_name,
		"source": "stairs"
	})
