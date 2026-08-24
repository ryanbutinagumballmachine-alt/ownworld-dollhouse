# ==============================================================================
# OWNWORLD — SESSION STORE
# File: res://Core/Persistence/SessionStore.gd
# Autoload: SessionStore
# ==============================================================================

extends Node

const SESSION_PATH: String = "user://session.json"
const TEMP_SESSION_PATH: String = "user://session.json.tmp"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func load_session() -> Dictionary:
	if not FileAccess.file_exists(SESSION_PATH):
		return {}

	var file: FileAccess = FileAccess.open(SESSION_PATH, FileAccess.READ)
	if file == null:
		return {}

	var content: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(content)
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func save_session(session_data: Dictionary) -> bool:
	if session_data.is_empty():
		return false

	var file: FileAccess = FileAccess.open(TEMP_SESSION_PATH, FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(JSON.stringify(session_data, "\t"))
	file.flush()
	file.close()

	if FileAccess.file_exists(SESSION_PATH):
		if DirAccess.remove_absolute(SESSION_PATH) != OK:
			DirAccess.remove_absolute(TEMP_SESSION_PATH)
			return false

	if DirAccess.rename_absolute(TEMP_SESSION_PATH, SESSION_PATH) != OK:
		if FileAccess.file_exists(TEMP_SESSION_PATH):
			DirAccess.remove_absolute(TEMP_SESSION_PATH)
		return false

	return true


func save_current_app_state() -> bool:
	return save_session(AppState.export_session_state())
