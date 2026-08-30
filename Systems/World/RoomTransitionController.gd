# ==============================================================================
# OWNWORLD — ROOM TRANSITION CONTROLLER
# File: res://Systems/World/RoomTransitionController.gd
# Base Class: Node (class_name RoomTransitionController)
#
# Responsibility: Manages asynchronous room transitions with smooth cross-fade
# overlays, departure state saves, and destination loading.
# ==============================================================================

class_name RoomTransitionController
extends Node

enum State {
	IDLE,
	FADE_OUT,
	SAVE_DEPARTURE,
	CHANGE_STATE,
	LOAD_DESTINATION,
	FADE_IN
}

const FADE_OUT_DURATION: float = 0.22
const FADE_IN_DURATION: float = 0.22

@export var overlay: ColorRect
@export var room_lifecycle: RoomLifecycleController

var state: State = State.IDLE
var pending_room_id: String = ""
var pending_traveler_data: Dictionary = {}
var departing_room_id: String = ""
var _transition_serial: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_prepare_overlay()

	if not EventBus.room_change_requested.is_connected(_on_room_change_requested):
		EventBus.room_change_requested.connect(_on_room_change_requested)

	if is_instance_valid(room_lifecycle) and not room_lifecycle.room_loaded.is_connected(_on_room_loaded):
		room_lifecycle.room_loaded.connect(_on_room_loaded)


func configure(p_room_lifecycle: RoomLifecycleController, p_overlay: ColorRect) -> void:
	room_lifecycle = p_room_lifecycle
	overlay = p_overlay
	_prepare_overlay()
	if is_instance_valid(room_lifecycle) and not room_lifecycle.room_loaded.is_connected(_on_room_loaded):
		room_lifecycle.room_loaded.connect(_on_room_loaded)


func _prepare_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.color = Color(0.0, 0.0, 0.0, 0.0)
		overlay.visible = true


func request_transition(target_room_id: String, traveler_data: Dictionary = {}) -> void:
	var normalized_room_id: String = target_room_id.strip_edges()
	if normalized_room_id.is_empty() or state != State.IDLE:
		return
	if normalized_room_id == AppState.room_id and traveler_data.is_empty():
		return
	if not is_instance_valid(room_lifecycle):
		push_error("RoomTransitionController: RoomLifecycleController is not configured.")
		return

	departing_room_id = AppState.room_id
	if departing_room_id.is_empty():
		departing_room_id = room_lifecycle.get_active_room_id()

	pending_room_id = normalized_room_id
	pending_traveler_data = traveler_data.duplicate(true)

	_transition_serial += 1
	var transition_id: int = _transition_serial
	state = State.FADE_OUT
	_execute_transition(transition_id)


func _execute_transition(transition_id: int) -> void:
	await _fade_to(1.0, FADE_OUT_DURATION)
	if transition_id != _transition_serial: 
		return

	state = State.SAVE_DEPARTURE
	_save_departure()
	if transition_id != _transition_serial: 
		return

	state = State.CHANGE_STATE
	if not AppState.begin_room_transition(pending_room_id):
		_abort_transition()
		return

	state = State.LOAD_DESTINATION
	room_lifecycle.load_room(pending_room_id, pending_traveler_data)


func _save_departure() -> void:
	if departing_room_id.is_empty() or not is_instance_valid(room_lifecycle):
		return
	if not room_lifecycle.save_active_room():
		EventBus.notification_requested.emit("Could not save departing room.", false)


func _on_room_change_requested(room_id: String, traveler_data: Dictionary) -> void:
	request_transition(room_id, traveler_data)


func _on_room_loaded(room_id: String, _room_state: Dictionary) -> void:
	if state != State.LOAD_DESTINATION or room_id != pending_room_id:
		return

	state = State.FADE_IN
	var current_serial: int = _transition_serial
	await _fade_to(0.0, FADE_IN_DURATION)
	if current_serial != _transition_serial:
		return

	var previous_room_id: String = departing_room_id
	var traveler_data: Dictionary = pending_traveler_data.duplicate(true)
	var completed_room_id: String = pending_room_id

	_clear_pending_state()
	state = State.IDLE
	AppState.complete_room_transition()
	EventBus.room_changed.emit(completed_room_id, previous_room_id, traveler_data)
	AppState.save_session_to_disk()


func _abort_transition() -> void:
	_clear_pending_state()
	state = State.FADE_IN
	await _fade_to(0.0, FADE_IN_DURATION)
	state = State.IDLE
	AppState.complete_room_transition()
	EventBus.notification_requested.emit("Room transition cancelled.", false)


func _clear_pending_state() -> void:
	pending_room_id = ""
	pending_traveler_data.clear()
	departing_room_id = ""


func _fade_to(target_alpha: float, duration: float) -> void:
	if not is_instance_valid(overlay):
		return

	var normalized_alpha: float = clampf(target_alpha, 0.0, 1.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP if normalized_alpha > 0.5 else Control.MOUSE_FILTER_IGNORE

	var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN if normalized_alpha > 0.5 else Tween.EASE_OUT)
	tween.tween_property(overlay, "color:a", normalized_alpha, maxf(duration, 0.001))
	await tween.finished


func is_transitioning() -> bool: 
	return state != State.IDLE


func get_state() -> State: 
	return state
