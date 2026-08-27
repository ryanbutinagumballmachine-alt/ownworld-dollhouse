# ==============================================================================
# OWNWORLD — SESSION STORE
# File: res://Core/Persistence/SessionStore.gd
# Autoload Singleton: SessionStore
# Base Class: Node
#
# Responsibility: Atomic session persistence and recovery coordination delegating
# to JsonFileStore with transactional temporary file swap protection.
# ==============================================================================

extends Node

const SESSION_PATH: String = "user://session.json"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func load_session() -> Dictionary:
	return JsonFileStore.read_dictionary(SESSION_PATH)


func save_session(session_data: Dictionary) -> bool:
	if session_data.is_empty():
		return false
	return JsonFileStore.write_dictionary(SESSION_PATH, session_data)


func save_current_app_state() -> bool:
	return save_session(AppState.export_session_state())
