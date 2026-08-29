# ==============================================================================
# OWNWORLD — CORE TYPES & ENUMS
# File: res://Core/Types.gd
# Base Class: RefCounted (class_name Types)
#
# Responsibility: Central type definitions, classifications, layer bands,
# lighting modes, and animation playback behaviors across all game systems.
# ==============================================================================

class_name Types
extends RefCounted

## Standard Unified Actor State Constants (Automated Engine Hooks)
const STATE_IDLE: String = "idle"
const STATE_SITTING: String = "sitting"
const STATE_SLEEPING: String = "sleeping"
const STATE_SPEAKING: String = "speaking"
const STATE_EATING: String = "eating"

## Classification of interactive runtime entities.
enum EntityType {
	PROP = 0,
	CHARACTER = 1,
	FURNITURE = 2,
	CONTAINER = 3,
	APPLIANCE = 4
}

## Primary physical and behavioral states for an entity.
enum EntityState {
	IDLE = 0,
	DRAGGING = 1,
	HELD = 2,
	STORED = 3,
	SITTING = 4,
	SLEEPING = 5,
	LOCKED = 6
}

## Semantic types for custom interaction zones and socket points.
enum InteractionPointType {
	DEFAULT = 0,
	MOUTH = 1,
	LIQUID_STREAM = 2,
	CONTAINER_SLOT = 3
}

## Trigger conditions evaluated by the visual Logic Engine.
enum TriggerEvent {
	ON_TAPPED = 0,
	ON_DRAG_STARTED = 1,
	ON_DRAG_ENDED = 2,
	ON_ITEM_RECEIVED = 3,
	ON_CONTAINER_OPENED = 4,
	ON_CONTAINER_CLOSED = 5,
	ON_PROXIMITY_ENTERED = 6
}

## Action commands executed upon trigger condition satisfaction.
enum ActionCommand {
	SWAP_FORM = 0,
	PLAY_SOUND = 1,
	PLAY_ANIM = 2,
	TOGGLE_CONTAINER = 3,
	CHANGE_TEXTURE = 4,
	ADVANCE_STATE = 5,
	TELEPORT_ROOM = 6,
	TOGGLE_LIGHT = 7,
	SPAWN_ITEM = 8,
	STOP_ANIM = 101,
	SET_EXPRESSION = 102,
	SAY_DIALOGUE = 103,
	SPRAY_EMOTION = 104,
	SET_MOOD = 105,
	SET_WEATHER = 106,
	SPAWN_ITEM_UGC = 107,
	TELEPORT_ROOM_CUSTOM = 108
}

## Target categories for action execution in Logic Rules.
enum ActionTarget {
	SELF = 0,
	TRIGGER_ITEM = 1,
	ROOM_ALL_CHARACTERS = 2,
	ENVIRONMENT = 3
}

## Discrete Z-index layer bands for predictable 2D depth sorting.
enum LayerBands {
	BACKGROUND = -100,
	FLOOR_DECOR = -20,
	PLAYFIELD = 0,
	FURNITURE_OVERLAY = 20,
	DRAGGING = 100,
	FOREGROUND = 200
}

## Visual lighting shape configurations.
enum LightShapeMode {
	SILHOUETTE_CONTOUR = 0,
	RADIAL_ROOM = 1,
	ANCHOR_POINTS = 2
}

## Playback behaviors for custom animation clips and state loops.
enum PlaybackMode {
	LOOP = 0,
	NATURAL_BLINK = 1,
	ONE_SHOT = 2,
	PING_PONG = 3,
	ONE_SHOT_HOLD = 4
}
