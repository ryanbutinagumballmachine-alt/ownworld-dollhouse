# ==============================================================================
# Script: res://Core/Types.gd
# Base Class: RefCounted (class_name Types)
# ==============================================================================

class_name Types
extends RefCounted

enum EntityType {
	PROP = 0,
	CHARACTER = 1,
	FURNITURE = 2,
	CONTAINER = 3,
	APPLIANCE = 4
}

enum EntityState {
	IDLE = 0,
	DRAGGING = 1,
	HELD = 2,
	STORED = 3,
	SITTING = 4,
	SLEEPING = 5,
	LOCKED = 6
}

enum InteractionPointType {
	DEFAULT = 0,
	MOUTH = 1,
	LIQUID_STREAM = 2,
	CONTAINER_SLOT = 3
}

enum TriggerEvent {
	ON_TAPPED = 0,
	ON_DRAG_STARTED = 1,
	ON_DRAG_ENDED = 2,
	ON_ITEM_RECEIVED = 3,
	ON_CONTAINER_OPENED = 4,
	ON_CONTAINER_CLOSED = 5,
	ON_PROXIMITY_ENTERED = 6
}

enum ActionCommand {
	SWAP_FORM = 0,
	PLAY_SOUND = 1,
	PLAY_ANIM = 2,
	TOGGLE_CONTAINER = 3,
	CHANGE_TEXTURE = 4,
	ADVANCE_STATE = 5,
	TELEPORT_ROOM = 6,
	TOGGLE_LIGHT = 7,
	SPAWN_ITEM = 8
}

enum LayerBands {
	BACKGROUND = -100,
	FLOOR_DECOR = -20,
	PLAYFIELD = 0,
	FURNITURE_OVERLAY = 20,
	DRAGGING = 100,
	FOREGROUND = 200
}
