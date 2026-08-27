# ==============================================================================
# OWNWORLD — ENTITY CAPABILITY SYNCHRONIZER
# File: res://Core/Entities/CapabilitySynchronizer.gd
# Base Class: RefCounted (class_name CapabilitySynchronizer)
#
# Responsibility: Synchronizes entity flags and properties with modular
# EntityCapability components during spawning, deserialization, and runtime updates.
# ==============================================================================

class_name CapabilitySynchronizer
extends RefCounted


static func synchronize(entity: OwnEntity) -> void:
	if entity == null:
		return
	_synchronize_consumable(entity)
	_synchronize_liquid(entity)
	_synchronize_light(entity)
	_synchronize_container(entity)
	_synchronize_portal(entity)
	_synchronize_elevator(entity)


static func _synchronize_consumable(entity: OwnEntity) -> void:
	if not entity.is_consumable or entity.has_component(&"EntityConsumableCapability"):
		return
	var capability: EntityConsumableCapability = EntityConsumableCapability.new()
	capability.configure(entity.max_bites, entity.is_drink, entity.is_infinite)
	capability.remaining_bites = clampi(entity.current_state_idx, 0, capability.max_bites)
	entity.add_component(capability)


static func _synchronize_liquid(entity: OwnEntity) -> void:
	if not (entity.is_liquid_container or entity.is_liquid_source) or entity.has_component(&"EntityLiquidCapability"):
		return
	var capability: EntityLiquidCapability = EntityLiquidCapability.new()
	capability.configure(entity.is_liquid_source, entity.fill_level)
	entity.add_component(capability)


static func _synchronize_light(entity: OwnEntity) -> void:
	if not entity.is_light_source or entity.has_component(&"EntityLightCapability"):
		return
	var capability: EntityLightCapability = EntityLightCapability.new()
	capability.configure(entity.light_color, entity.light_intensity, entity.light_radius, entity.light_pulse_speed, entity.light_shape_mode)
	capability.set_active(entity.is_active)
	entity.add_component(capability)


static func _synchronize_container(entity: OwnEntity) -> void:
	if not entity.is_container or entity.has_component(&"EntityContainerCapability"):
		return
	var capability: EntityContainerCapability = EntityContainerCapability.new()
	capability.is_open = entity.is_open
	for item: Dictionary in entity.stored_item_data:
		capability.stored_items.append(item.duplicate(true))
	entity.add_component(capability)


static func _synchronize_portal(entity: OwnEntity) -> void:
	if not entity.is_portal or entity.is_elevator or entity.has_component(&"EntityPortalCapability"):
		return
	var capability: EntityPortalCapability = EntityPortalCapability.new()
	capability.configure(entity.target_room_id, entity.display_name)
	capability.door_open = entity.is_door_open
	entity.add_component(capability)


static func _synchronize_elevator(entity: OwnEntity) -> void:
	if not entity.is_elevator or entity.has_component(&"EntityElevatorCapability"):
		return
	var capability: EntityElevatorCapability = EntityElevatorCapability.new()
	capability.configure_floors(entity.elevator_floors)
	entity.add_component(capability)
