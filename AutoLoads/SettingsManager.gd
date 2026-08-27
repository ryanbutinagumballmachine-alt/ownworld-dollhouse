# ============================================================
# File: res://AutoLoads/SettingsManager.gd
# ============================================================

# ==============================================================================
# OWNWORLD — SETTINGS SERVICE (JUICE & MOTION FX EXTENDED)
# File: res://AutoLoads/SettingsManager.gd
# Autoload Singleton: SettingsManager
# Base Class: Node
#
# Responsibility: User configuration persistence, audio server decibel mapping,
# DPI-aware display scaling, and master/granular procedural juice toggles.
# ==============================================================================

extends Node

const PATH_SETTINGS_FILE: String = "user://settings.json"

# Audio Defaults
const DEFAULT_MASTER_VOLUME: float = 1.0
const DEFAULT_MUSIC_VOLUME: float = 0.8
const DEFAULT_SFX_VOLUME: float = 1.0

# Editor & Interface Defaults
const DEFAULT_GRID_SNAP: bool = false
const DEFAULT_GRID_SIZE: int = 32
const DEFAULT_SHOW_TOASTS: bool = true
const DEFAULT_HAPTICS_ENABLED: bool = true
const DEFAULT_DEVELOPER_MODE: bool = false

# Touch & Scale Defaults
const DEFAULT_MOBILE_TOUCH_PADDING: float = 8.0
const MIN_TOUCH_PADDING: float = 0.0
const MAX_TOUCH_PADDING: float = 40.0
const MIN_UI_SCALE: float = 0.75
const MAX_UI_SCALE: float = 2.5
const DEFAULT_LONG_PRESS_DURATION: float = 0.35
const MIN_LONG_PRESS_DURATION: float = 0.15
const MAX_LONG_PRESS_DURATION: float = 1.20

# Master & Granular Juice Defaults
const DEFAULT_JUICE_ENABLED: bool = true
const DEFAULT_JUICE_IDLE_MOTION: bool = true
const DEFAULT_JUICE_IDLE_INTENSITY: float = 1.0
const DEFAULT_JUICE_PHYSICAL_TILTS: bool = true
const DEFAULT_JUICE_SQUASH_STRETCH: bool = true
const DEFAULT_JUICE_SPAWN_SPRINGS: bool = true

var settings_data: Dictionary = {}

signal developer_mode_changed(enabled: bool)
signal ui_scale_changed(new_scale: float)
signal juice_settings_changed(juice_data: Dictionary)
signal settings_changed(settings: Dictionary)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()


func load_settings() -> void:
	settings_data = {
		"master_vol": DEFAULT_MASTER_VOLUME,
		"music_vol": DEFAULT_MUSIC_VOLUME,
		"sfx_vol": DEFAULT_SFX_VOLUME,
		"grid_snap": DEFAULT_GRID_SNAP,
		"grid_size": DEFAULT_GRID_SIZE,
		"show_toasts": DEFAULT_SHOW_TOASTS,
		"haptics_enabled": DEFAULT_HAPTICS_ENABLED,
		"developer_mode": DEFAULT_DEVELOPER_MODE,
		"touch_padding": DEFAULT_MOBILE_TOUCH_PADDING,
		"long_press_duration": DEFAULT_LONG_PRESS_DURATION,
		"juice_enabled": DEFAULT_JUICE_ENABLED,
		"juice_idle_motion": DEFAULT_JUICE_IDLE_MOTION,
		"juice_idle_intensity": DEFAULT_JUICE_IDLE_INTENSITY,
		"juice_physical_tilts": DEFAULT_JUICE_PHYSICAL_TILTS,
		"juice_squash_stretch": DEFAULT_JUICE_SQUASH_STRETCH,
		"juice_spawn_springs": DEFAULT_JUICE_SPAWN_SPRINGS
	}

	var stored_data: Dictionary = JsonFileStore.read_dictionary(PATH_SETTINGS_FILE)
	for key: String in stored_data.keys():
		settings_data[key] = stored_data[key]

	_normalize_settings()

	if not stored_data.has("ui_scale"):
		settings_data["ui_scale"] = get_recommended_ui_scale()

	_apply_audio_volumes()
	_apply_ui_scale()
	_emit_settings_changed()


func save_settings() -> bool:
	_normalize_settings()
	var success: bool = JsonFileStore.write_dictionary(PATH_SETTINGS_FILE, settings_data)
	if success:
		_apply_audio_volumes()
		_apply_ui_scale()
		_emit_settings_changed()
	return success


func _normalize_settings() -> void:
	settings_data["master_vol"] = clampf(float(settings_data.get("master_vol", DEFAULT_MASTER_VOLUME)), 0.0, 1.0)
	settings_data["music_vol"] = clampf(float(settings_data.get("music_vol", DEFAULT_MUSIC_VOLUME)), 0.0, 1.0)
	settings_data["sfx_vol"] = clampf(float(settings_data.get("sfx_vol", DEFAULT_SFX_VOLUME)), 0.0, 1.0)
	settings_data["grid_snap"] = bool(settings_data.get("grid_snap", DEFAULT_GRID_SNAP))
	settings_data["grid_size"] = maxi(int(settings_data.get("grid_size", DEFAULT_GRID_SIZE)), 1)
	settings_data["ui_scale"] = clampf(float(settings_data.get("ui_scale", get_recommended_ui_scale())), MIN_UI_SCALE, MAX_UI_SCALE)
	settings_data["show_toasts"] = bool(settings_data.get("show_toasts", DEFAULT_SHOW_TOASTS))
	settings_data["haptics_enabled"] = bool(settings_data.get("haptics_enabled", DEFAULT_HAPTICS_ENABLED))
	settings_data["developer_mode"] = bool(settings_data.get("developer_mode", DEFAULT_DEVELOPER_MODE))
	settings_data["touch_padding"] = clampf(float(settings_data.get("touch_padding", DEFAULT_MOBILE_TOUCH_PADDING)), MIN_TOUCH_PADDING, MAX_TOUCH_PADDING)
	settings_data["long_press_duration"] = clampf(float(settings_data.get("long_press_duration", DEFAULT_LONG_PRESS_DURATION)), MIN_LONG_PRESS_DURATION, MAX_LONG_PRESS_DURATION)

	# Normalize Juice Settings
	settings_data["juice_enabled"] = bool(settings_data.get("juice_enabled", DEFAULT_JUICE_ENABLED))
	settings_data["juice_idle_motion"] = bool(settings_data.get("juice_idle_motion", DEFAULT_JUICE_IDLE_MOTION))
	settings_data["juice_idle_intensity"] = clampf(float(settings_data.get("juice_idle_intensity", DEFAULT_JUICE_IDLE_INTENSITY)), 0.0, 2.0)
	settings_data["juice_physical_tilts"] = bool(settings_data.get("juice_physical_tilts", DEFAULT_JUICE_PHYSICAL_TILTS))
	settings_data["juice_squash_stretch"] = bool(settings_data.get("juice_squash_stretch", DEFAULT_JUICE_SQUASH_STRETCH))
	settings_data["juice_spawn_springs"] = bool(settings_data.get("juice_spawn_springs", DEFAULT_JUICE_SPAWN_SPRINGS))


# --- JUICE & MOTION FX GETTERS & SETTERS ---

func is_juice_enabled() -> bool:
	return bool(settings_data.get("juice_enabled", DEFAULT_JUICE_ENABLED))

func set_juice_enabled(enabled: bool) -> void:
	settings_data["juice_enabled"] = enabled
	save_settings()
	juice_settings_changed.emit(get_all_juice_settings())

func is_juice_idle_motion_enabled() -> bool:
	return is_juice_enabled() and bool(settings_data.get("juice_idle_motion", DEFAULT_JUICE_IDLE_MOTION))

func set_juice_idle_motion_enabled(enabled: bool) -> void:
	settings_data["juice_idle_motion"] = enabled
	save_settings()
	juice_settings_changed.emit(get_all_juice_settings())

func get_juice_idle_intensity() -> float:
	if not is_juice_enabled(): return 0.0
	return float(settings_data.get("juice_idle_intensity", DEFAULT_JUICE_IDLE_INTENSITY))

func set_juice_idle_intensity(value: float) -> void:
	settings_data["juice_idle_intensity"] = clampf(value, 0.0, 2.0)
	save_settings()
	juice_settings_changed.emit(get_all_juice_settings())

func is_juice_physical_tilts_enabled() -> bool:
	return is_juice_enabled() and bool(settings_data.get("juice_physical_tilts", DEFAULT_JUICE_PHYSICAL_TILTS))

func set_juice_physical_tilts_enabled(enabled: bool) -> void:
	settings_data["juice_physical_tilts"] = enabled
	save_settings()
	juice_settings_changed.emit(get_all_juice_settings())

func is_juice_squash_stretch_enabled() -> bool:
	return is_juice_enabled() and bool(settings_data.get("juice_squash_stretch", DEFAULT_JUICE_SQUASH_STRETCH))

func set_juice_squash_stretch_enabled(enabled: bool) -> void:
	settings_data["juice_squash_stretch"] = enabled
	save_settings()
	juice_settings_changed.emit(get_all_juice_settings())

func is_juice_spawn_springs_enabled() -> bool:
	return is_juice_enabled() and bool(settings_data.get("juice_spawn_springs", DEFAULT_JUICE_SPAWN_SPRINGS))

func set_juice_spawn_springs_enabled(enabled: bool) -> void:
	settings_data["juice_spawn_springs"] = enabled
	save_settings()
	juice_settings_changed.emit(get_all_juice_settings())

func get_all_juice_settings() -> Dictionary:
	return {
		"juice_enabled": is_juice_enabled(),
		"juice_idle_motion": is_juice_idle_motion_enabled(),
		"juice_idle_intensity": get_juice_idle_intensity(),
		"juice_physical_tilts": is_juice_physical_tilts_enabled(),
		"juice_squash_stretch": is_juice_squash_stretch_enabled(),
		"juice_spawn_springs": is_juice_spawn_springs_enabled()
	}


# --- STANDARD SETTINGS ---

func get_long_press_duration() -> float:
	return float(settings_data.get("long_press_duration", DEFAULT_LONG_PRESS_DURATION))

func set_long_press_duration(value: float) -> void:
	settings_data["long_press_duration"] = clampf(value, MIN_LONG_PRESS_DURATION, MAX_LONG_PRESS_DURATION)
	save_settings()

func get_mobile_touch_padding() -> float:
	return float(settings_data.get("touch_padding", DEFAULT_MOBILE_TOUCH_PADDING))

func set_mobile_touch_padding(value: float) -> void:
	settings_data["touch_padding"] = clampf(value, MIN_TOUCH_PADDING, MAX_TOUCH_PADDING)
	save_settings()

func get_touch_padding(has_active_touch: bool = false) -> float:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or has_active_touch:
		return get_mobile_touch_padding()
	return 0.0

func get_recommended_ui_scale() -> float:
	var screen_dpi: float = DisplayServer.screen_get_dpi()
	var screen_size: Vector2i = DisplayServer.screen_get_size()

	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		if screen_dpi > 400.0: return 1.6
		if screen_dpi > 280.0: return 1.4
		if minf(float(screen_size.x), float(screen_size.y)) >= 900.0: return 1.4
		return 1.2

	if screen_size.x >= 3840: return 1.75
	if screen_size.x >= 2560: return 1.25
	return 1.0

func set_ui_scale(scale_value: float) -> void:
	var normalized_scale: float = clampf(scale_value, MIN_UI_SCALE, MAX_UI_SCALE)
	var previous_scale: float = get_ui_scale()
	if is_equal_approx(previous_scale, normalized_scale):
		return
	settings_data["ui_scale"] = normalized_scale
	_apply_ui_scale()
	ui_scale_changed.emit(normalized_scale)
	save_settings()

func get_ui_scale() -> float:
	return float(settings_data.get("ui_scale", get_recommended_ui_scale()))

func _apply_ui_scale() -> void:
	var window: Window = get_window()
	if window != null:
		window.content_scale_factor = clampf(get_ui_scale(), MIN_UI_SCALE, MAX_UI_SCALE)

func get_master_volume() -> float: return float(settings_data.get("master_vol", DEFAULT_MASTER_VOLUME))
func get_music_volume() -> float: return float(settings_data.get("music_vol", DEFAULT_MUSIC_VOLUME))
func get_sfx_volume() -> float: return float(settings_data.get("sfx_vol", DEFAULT_SFX_VOLUME))

func set_master_volume(value: float) -> void:
	settings_data["master_vol"] = clampf(value, 0.0, 1.0)
	save_settings()

func set_music_volume(value: float) -> void:
	settings_data["music_vol"] = clampf(value, 0.0, 1.0)
	save_settings()

func set_sfx_volume(value: float) -> void:
	settings_data["sfx_vol"] = clampf(value, 0.0, 1.0)
	save_settings()

func _apply_audio_volumes() -> void:
	_set_bus_volume(&"Master", get_master_volume())
	_set_bus_volume(&"Music", get_music_volume())
	_set_bus_volume(&"SFX", get_sfx_volume())

func _set_bus_volume(bus_name: StringName, linear_value: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0: return
	var normalized_value: float = clampf(linear_value, 0.0, 1.0)
	var decibel_value: float = linear_to_db(normalized_value) if normalized_value > 0.0 else -80.0
	AudioServer.set_bus_volume_db(bus_index, decibel_value)

func is_grid_snap_enabled() -> bool: return bool(settings_data.get("grid_snap", DEFAULT_GRID_SNAP))
func set_grid_snap_enabled(enabled: bool) -> void:
	settings_data["grid_snap"] = enabled
	save_settings()

func get_grid_size() -> int: return maxi(int(settings_data.get("grid_size", DEFAULT_GRID_SIZE)), 1)
func set_grid_size(size_value: int) -> void:
	settings_data["grid_size"] = maxi(size_value, 1)
	save_settings()

func are_toasts_enabled() -> bool: return bool(settings_data.get("show_toasts", DEFAULT_SHOW_TOASTS))
func set_toasts_enabled(enabled: bool) -> void:
	settings_data["show_toasts"] = enabled
	save_settings()

func are_haptics_enabled() -> bool: return bool(settings_data.get("haptics_enabled", DEFAULT_HAPTICS_ENABLED))
func set_haptics_enabled(enabled: bool) -> void:
	settings_data["haptics_enabled"] = enabled
	save_settings()

func is_developer_mode_enabled() -> bool: return bool(settings_data.get("developer_mode", DEFAULT_DEVELOPER_MODE))
func set_developer_mode(enabled: bool) -> void:
	var changed: bool = is_developer_mode_enabled() != enabled
	settings_data["developer_mode"] = enabled
	if save_settings() and changed:
		developer_mode_changed.emit(enabled)

func get_setting(key: String, default_value: Variant = null) -> Variant:
	return settings_data.get(key, default_value)

func set_setting(key: String, value: Variant) -> void:
	var normalized_key: String = key.strip_edges()
	if not normalized_key.is_empty():
		settings_data[normalized_key] = value
		save_settings()

func get_all_settings() -> Dictionary: return settings_data.duplicate(true)
func _emit_settings_changed() -> void: settings_changed.emit(settings_data.duplicate(true))
