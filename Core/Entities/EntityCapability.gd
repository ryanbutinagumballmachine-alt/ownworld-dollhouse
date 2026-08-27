# ==============================================================================
# OWNWORLD — ENTITY CAPABILITY BASE
# File: res://Core/Entities/EntityCapability.gd
# Base Class: EntityComponent (class_name EntityCapability)
#
# Responsibility: Semantic capability base class providing interaction querying
# and action dispatching interfaces for runtime entities.
# ==============================================================================

class_name EntityCapability
extends EntityComponent


func can_receive_interaction(_context: Dictionary) -> bool:
	return true


func handle_interaction(_action: StringName, _context: Dictionary) -> void:
	pass
