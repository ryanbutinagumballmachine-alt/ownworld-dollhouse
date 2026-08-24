# ==============================================================================
# OWNWORLD — HISTORY SERVICE
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
	EventBus.history_state_restored.connect(_on_external_state_restored)


func record_snapshot(snapshot: Dictionary) -> void:
	if is_suppressed or snapshot.is_empty():
		return
	undo_stack.append(snapshot.duplicate(true))
	if undo_stack.size() > MAX_HISTORY:
		undo_stack.pop_front()
	redo_stack.clear()


func undo() -> void:
	if undo_stack.size() <= 1:
		return
	var current_snapshot: Dictionary = undo_stack.pop_back()
	redo_stack.append(current_snapshot)
	var previous_snapshot: Dictionary = undo_stack.back().duplicate(true)
	_restore_snapshot(previous_snapshot)
	EventBus.notification_requested.emit("Undone", true)


func redo() -> void:
	if redo_stack.is_empty():
		return
	var target_snapshot: Dictionary = redo_stack.pop_back().duplicate(true)
	undo_stack.append(target_snapshot.duplicate(true))
	_restore_snapshot(target_snapshot)
	EventBus.notification_requested.emit("Redone", true)


func can_undo() -> bool: return undo_stack.size() > 1
func can_redo() -> bool: return not redo_stack.is_empty()

func clear_history() -> void:
	undo_stack.clear()
	redo_stack.clear()
	is_suppressed = false

func get_history_size() -> int: return undo_stack.size()


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
