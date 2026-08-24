# ==============================================================================
# OWNWORLD — ENTITY COMPONENT BASE
# File: res://Core/Entities/Components/EntityComponent.gd
# Base Class: RefCounted (class_name EntityComponent)
# ==============================================================================

class_name EntityComponent
extends RefCounted

var entity: OwnEntity = null


func get_component_key() -> StringName:
	return &"EntityComponent"


func initialize(owner_entity: OwnEntity) -> void:
	entity = owner_entity


func shutdown() -> void:
	entity = null


func serialize() -> Dictionary:
	return {}


func deserialize(_data: Dictionary) -> void:
	pass
