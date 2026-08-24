# ==============================================================================
# Script: res://Systems/World/WorldController.gd
# Base Class: Node2D (class_name WorldController)
# ==============================================================================

class_name WorldController
extends Node2D

@export var room_bounds: Rect2 = Rect2(0, 0, 1920, 1080)

var entity_root: Node2D = null
var world_camera: Camera2D = null
var atmosphere: Node = null
var current_room_floor_y: float = 600.0
var current_room_title: String = "Main Room"
var current_wallpaper_path: String = ""
var current_wallpaper_fill_mode: String = "cover"

@onready var room_lifecycle: Node = get_node_or_null("RoomLifecycleController")
@onready var room_transition: Node = get_node_or_null("RoomTransitionController")
@onready var interaction_router: Node = get_node_or_null("EntityInteractionRouter")
@onready var interaction_controller: Node = get_node_or_null("WorldInteractionController")

signal room_presentation_changed
signal world_ready


func _ready() -> void:
	entity_root = get_node_or_null("EntityRoot") as Node2D
	world_camera = get_node_or_null("WorldCamera") as Camera2D
	atmosphere = get_node_or_null("Atmosphere")

	if room_lifecycle and room_lifecycle.has_method("configure"):
		room_lifecycle.configure(entity_root, world_camera, atmosphere, room_bounds)
	if interaction_controller:
		interaction_controller.set("entity_root", entity_root)
		interaction_controller.set("main_camera", world_camera)
		if interaction_router:
			interaction_controller.set("interaction_router", interaction_router)
		if interaction_controller.has_method("set_room_bounds"):
			interaction_controller.set_room_bounds(room_bounds)
	if room_transition and room_transition.has_method("configure") and room_lifecycle:
		var overlay: ColorRect = room_transition.get_node_or_null("TransitionOverlay") as ColorRect
		room_transition.configure(room_lifecycle, overlay)

	call_deferred("_initialize_world")


func _initialize_world() -> void:
	if room_lifecycle and room_lifecycle.has_method("load_room"):
		var room_id: String = AppState.room_id if not AppState.room_id.is_empty() else SaveSchema.DEFAULT_ROOM_ID
		room_lifecycle.load_room(room_id)
	world_ready.emit()


func set_room_bounds(new_bounds: Rect2) -> void:
	if new_bounds.size.x <= 0.0 or new_bounds.size.y <= 0.0:
		return
	room_bounds = new_bounds
	if room_lifecycle and room_lifecycle.has_method("set_room_bounds"): room_lifecycle.set_room_bounds(new_bounds)
	if world_camera and world_camera.has_method("update_room_bounds"): world_camera.update_room_bounds(new_bounds)
	if interaction_controller and interaction_controller.has_method("set_room_bounds"): interaction_controller.set_room_bounds(new_bounds)


func get_entities() -> Array:
	if room_lifecycle and room_lifecycle.has_method("get_entities"):
		return room_lifecycle.get_entities()
	return []


func get_current_room_state() -> Dictionary:
	if room_lifecycle and room_lifecycle.has_method("get_current_room_state"):
		return room_lifecycle.get_current_room_state()
	return SaveSchema.create_empty_room(AppState.room_id)


func save_active_room() -> bool:
	if room_lifecycle and room_lifecycle.has_method("save_active_room"):
		return bool(room_lifecycle.save_active_room())
	return SaveSystem.save_room_state(AppState.room_id, get_current_room_state())


func configure_room_presentation(wallpaper_path: String, _wallpaper_texture: Texture2D, floor_y: float, room_title: String, fill_mode: String) -> void:
	current_wallpaper_path = wallpaper_path
	current_room_floor_y = floor_y
	current_room_title = room_title if not room_title.is_empty() else AppState.room_id
	current_wallpaper_fill_mode = fill_mode if not fill_mode.is_empty() else "cover"
	room_presentation_changed.emit()


func clear_room_wallpaper() -> void:
	current_wallpaper_path = ""
	room_presentation_changed.emit()


func set_floor_preview(floor_y: float, _visible: bool) -> void:
	current_room_floor_y = floor_y


func request_elevator_travel(_elevator: OwnEntity, target_room_id: String, floor_name: String) -> void:
	if target_room_id.is_empty():
		return
	EventBus.room_change_requested.emit(target_room_id, {
		"bundle": [],
		"arrival_elevator": true,
		"floor_name": floor_name,
		"source": "elevator"
	})


func request_universe_room_reset() -> void:
	RoomRepository.clear_universe(AppState.universe_id)
	if room_lifecycle and room_lifecycle.has_method("load_room"):
		room_lifecycle.load_room(AppState.room_id)
