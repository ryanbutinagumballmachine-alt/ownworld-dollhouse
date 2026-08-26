# ==============================================================================
# OWNWORLD — GLOBAL EVENT BUS
# File: res://Core/Architecture/EventBus.gd
# Autoload Singleton: EventBus
# ==============================================================================

extends Node

# --- WORLD & UNIVERSE TRANSITIONS ---
@warning_ignore("unused_signal") signal universe_change_requested(universe_id: String, universe_name: String)
@warning_ignore("unused_signal") signal universe_changed(universe_id: String, universe_name: String)
@warning_ignore("unused_signal") signal room_change_requested(room_id: String, traveler_data: Dictionary)
@warning_ignore("unused_signal") signal room_changed(room_id: String, previous_room_id: String, traveler_data: Dictionary)
@warning_ignore("unused_signal") signal room_reset_requested()
@warning_ignore("unused_signal") signal room_reset_completed(rescued_count: int)

# --- ENTITY LIFECYCLE & MUTATION ---
@warning_ignore("unused_signal") signal entity_spawn_requested(request: Dictionary)
@warning_ignore("unused_signal") signal entity_spawned(entity_id: String)
@warning_ignore("unused_signal") signal entity_removed(entity_id: String)
@warning_ignore("unused_signal") signal entity_state_changed(entity_id: String)
@warning_ignore("unused_signal") signal entity_locked_state_changed(entity_id: String, is_locked: bool)
@warning_ignore("unused_signal") signal entity_cloned(source_entity_id: String, clone_entity_id: String)

# --- INTERACTION & LOGIC ENGINE ---
@warning_ignore("unused_signal") signal interaction_requested(source_entity_id: String, target_entity_id: String)
@warning_ignore("unused_signal") signal interaction_completed(source_entity_id: String, target_entity_id: String)
@warning_ignore("unused_signal") signal trigger_requested(event_type: int, source_entity_id: String, target_entity_id: String)
@warning_ignore("unused_signal") signal logic_rule_executed(rule_id: String, trigger_event: int)

# --- CRAFTING & RECIPES ---
@warning_ignore("unused_signal") signal recipe_crafted(recipe_id: String, result_entity_id: String)
@warning_ignore("unused_signal") signal recipe_discovered(recipe_id: String)

# --- PERSISTENCE & SERIALIZATION ---
@warning_ignore("unused_signal") signal room_save_requested(room_id: String)
@warning_ignore("unused_signal") signal room_saved(room_id: String)
@warning_ignore("unused_signal") signal room_load_requested(room_id: String)
@warning_ignore("unused_signal") signal room_loaded(room_id: String)
@warning_ignore("unused_signal") signal universe_save_requested(universe_id: String)
@warning_ignore("unused_signal") signal journal_save_requested(universe_id: String)
@warning_ignore("unused_signal") signal journal_saved(universe_id: String)

# --- CHARACTER / CAST ROSTER ---
@warning_ignore("unused_signal") signal character_data_changed(character_id: String, character_data: Dictionary)
@warning_ignore("unused_signal") signal character_stored_in_tray(character_id: String)
@warning_ignore("unused_signal") signal character_spawned_from_tray(character_id: String)

# --- PRESENTATION & UI ---
@warning_ignore("unused_signal") signal notification_requested(message: String, is_success: bool)
@warning_ignore("unused_signal") signal theme_changed(theme_data: Dictionary)
@warning_ignore("unused_signal") signal modal_opened(modal_name: String)
@warning_ignore("unused_signal") signal modal_closed(modal_name: String)

# --- ATMOSPHERE & ENVIRONMENT ---
@warning_ignore("unused_signal") signal global_atmosphere_changed(time_preset: String, weather_preset: String)

# --- HISTORY & UNDO / REDO ---
@warning_ignore("unused_signal") signal history_snapshot_requested()
@warning_ignore("unused_signal") signal history_state_restored(snapshot_data: Dictionary)
@warning_ignore("unused_signal") signal undo_requested()
@warning_ignore("unused_signal") signal redo_requested()

# --- SETTINGS, HAPTICS & AUDIO ---
@warning_ignore("unused_signal") signal settings_changed(settings_data: Dictionary)
@warning_ignore("unused_signal") signal haptic_requested(duration_ms: int)
@warning_ignore("unused_signal") signal sound_effect_requested(sfx_name: String)

# --- APPLICATION LIFECYCLE ---
@warning_ignore("unused_signal") signal application_state_changed()
@warning_ignore("unused_signal") signal shutdown_requested()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
