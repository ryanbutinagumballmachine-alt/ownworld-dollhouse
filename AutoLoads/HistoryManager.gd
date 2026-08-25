# ==============================================================================
# OWNWORLD — HISTORY SERVICE (FULL-SCOPE UNDO / REDO)
# File: res://AutoLoads/HistoryManager.gd
# Autoload: HistoryManager
# ==============================================================================

extends Node

const MAX_HISTORY: int = 30

var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var is_suppressed: bool = false

signal state_restored(snapshot_data: Dictionary)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_event_bus_signals()


func _connect_event_bus_signals() -> void:
	if EventBus.has_signal("history_state_restored") and not EventBus.history_state_restored.is_connected(_on_external_state_restored):
		EventBus.history_state_restored.connect(_on_external_state_restored)
	if EventBus.has_signal("undo_requested") and not EventBus.undo_requested.is_connected(undo):
		EventBus.undo_requested.connect(undo)
	if EventBus.has_signal("redo_requested") and not EventBus.redo_requested.is_connected(redo):
		EventBus.redo_requested.connect(redo)


func record_snapshot(snapshot: Dictionary) -> void:
	if is_suppressed or snapshot.is_empty():
		return

	# Avoid duplicate identical snapshots
	if not undo_stack.is_empty() and undo_stack.back() == snapshot:
		return

	undo_stack.append(snapshot.duplicate(true))
	if undo_stack.size() > MAX_HISTORY:
		undo_stack.pop_front()

	redo_stack.clear()


func undo() -> void:
	if undo_stack.size() <= 1:
		EventBus.notification_requested.emit("Nothing to undo", true)
		return

	var current_snapshot: Dictionary = undo_stack.pop_back()
	redo_stack.append(current_snapshot)

	var previous_snapshot: Dictionary = undo_stack.back().duplicate(true)
	_restore_snapshot(previous_snapshot)
	EventBus.notification_requested.emit("Undone", true)


func redo() -> void:
	if redo_stack.is_empty():
		EventBus.notification_requested.emit("Nothing to redo", true)
		return

	var target_snapshot: Dictionary = redo_stack.pop_back().duplicate(true)
	undo_stack.append(target_snapshot.duplicate(true))

	_restore_snapshot(target_snapshot)
	EventBus.notification_requested.emit("Redone", true)


func can_undo() -> bool:
	return undo_stack.size() > 1


func can_redo() -> bool:
	return not redo_stack.is_empty()


func clear_history() -> void:
	undo_stack.clear()
	redo_stack.clear()
	is_suppressed = false


func get_history_size() -> int:
	return undo_stack.size()


func _restore_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	is_suppressed = true
	state_restored.emit(snapshot.duplicate(true))
	is_suppressed = false


func _on_external_state_restored(snapshot: Dictionary) -> void:
	if is_suppressed or snapshot.is_empty():
		return
	_restore_snapshot(snapshot)
