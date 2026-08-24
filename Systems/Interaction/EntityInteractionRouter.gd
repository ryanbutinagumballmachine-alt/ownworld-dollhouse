# ==============================================================================
# OWNWORLD — ENTITY INTERACTION ROUTER
# File: res://Systems/Interaction/EntityInteractionRouter.gd
# Base Class: Node (class_name EntityInteractionRouter)
# ==============================================================================

class_name EntityInteractionRouter
extends Node

signal interaction_handled(source: OwnEntity, action: StringName)


func handle_tap(entity: OwnEntity) -> void:
	if entity == null or not is_instance_valid(entity):
		return

	LogicEngine.evaluate_trigger(Types.TriggerEvent.ON_TAPPED, entity)

	var container: EntityContainerCapability = entity.get_component(&"EntityContainerCapability") as EntityContainerCapability
	if container != null:
		container.toggle_open()
		interaction_handled.emit(entity, &"container_toggle")
		return

	var light: EntityLightCapability = entity.get_component(&"EntityLightCapability") as EntityLightCapability
	if light != null:
		light.toggle()
		interaction_handled.emit(entity, &"light_toggle")
		return

	var elevator: EntityElevatorCapability = entity.get_component(&"EntityElevatorCapability") as EntityElevatorCapability
	if elevator != null:
		elevator.request_floor_selection()
		interaction_handled.emit(entity, &"elevator_floor_selection")
		return

	interaction_handled.emit(entity, &"tap")


func handle_drop(source: OwnEntity, world_position: Vector2, context: Dictionary) -> void:
	if source == null or not is_instance_valid(source):
		return

	var entities: Array[OwnEntity] = _extract_entities(context.get("entities", []))

	if _try_portal(source, entities): return
	if _try_container(source, entities): return
	if _try_liquid(source, entities): return
	if _try_socket(source, entities): return

	var canvas: Node2D = context.get("canvas", null) as Node2D
	if canvas != null and InteractionSolver.check_and_execute_crafting(source, entities, canvas):
		EventBus.entity_state_changed.emit(source.entity_id)
		interaction_handled.emit(source, &"crafting")
		return

	_handle_default_drop(source, world_position)


func _try_portal(source: OwnEntity, entities: Array[OwnEntity]) -> bool:
	if source.entity_type != Types.EntityType.CHARACTER:
		return false

	for candidate: OwnEntity in entities:
		if candidate == source or not is_instance_valid(candidate) or not candidate.is_portal or candidate.is_elevator:
			continue
		if not candidate.contains_point(source.global_position):
			continue

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
			source.queue_free()
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


func _handle_default_drop(entity: OwnEntity, _world_position: Vector2) -> void:
	entity.on_drop()
	EventBus.entity_state_changed.emit(entity.entity_id)
	interaction_handled.emit(entity, &"default_drop")


func _extract_entities(value: Variant) -> Array[OwnEntity]:
	var result: Array[OwnEntity] = []
	if value is Array:
		for candidate: Variant in (value as Array):
			if candidate is OwnEntity and is_instance_valid(candidate as OwnEntity):
				result.append(candidate as OwnEntity)
	return result
