# ==============================================================================
# OWNWORLD — ENTITY CAPABILITY BASE
# File: res://Core/Entities/EntityCapability.gd
# Base Class: EntityComponent (class_name EntityCapability)
# ==============================================================================

class_name EntityCapability
extends EntityComponent


func can_receive_interaction(_context: Dictionary) -> bool:
	return true


func handle_interaction(_action: StringName, _context: Dictionary) -> void:
	pass
