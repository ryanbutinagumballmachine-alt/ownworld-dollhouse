# ==============================================================================
# OWNWORLD — LIGHT CAPABILITY
# File: res://Core/Entities/Capabilities/EntityLightCapability.gd
# ==============================================================================

class_name EntityLightCapability
extends EntityCapability

signal active_changed(active: bool)
signal configuration_changed

enum ShapeMode {
	SILHOUETTE_CONTOUR = 0,
	RADIAL_ROOM = 1,
	ANCHOR_POINTS = 2
}

var active: bool = false
var shape_mode: int = ShapeMode.SILHOUETTE_CONTOUR
var light_color: Color = Color(1.0, 0.88, 0.50, 0.85)
var intensity: float = 2.0
var radius: float = 160.0
var pulse_speed: float = 2.0


func get_component_key() -> StringName:
	return &"EntityLightCapability"


func configure(color: Color, new_intensity: float, new_radius: float, new_pulse_speed: float, new_shape_mode: int = ShapeMode.SILHOUETTE_CONTOUR) -> void:
	light_color = color
	intensity = maxf(new_intensity, 0.0)
	radius = maxf(new_radius, 0.0)
	pulse_speed = maxf(new_pulse_speed, 0.0)
	shape_mode = clampi(new_shape_mode, int(ShapeMode.SILHOUETTE_CONTOUR), int(ShapeMode.ANCHOR_POINTS))
	configuration_changed.emit()
	EventBus.entity_state_changed.emit(entity.entity_id)


func set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	active_changed.emit(active)
	EventBus.entity_state_changed.emit(entity.entity_id)


func toggle() -> void:
	set_active(not active)


func serialize() -> Dictionary:
	return {
		"active": active,
		"shape_mode": shape_mode,
		"light_color": "#" + light_color.to_html(true),
		"intensity": intensity,
		"radius": radius,
		"pulse_speed": pulse_speed
	}


func deserialize(data: Dictionary) -> void:
	active = bool(data.get("active", false))
	shape_mode = clampi(int(data.get("shape_mode", ShapeMode.SILHOUETTE_CONTOUR)), int(ShapeMode.SILHOUETTE_CONTOUR), int(ShapeMode.ANCHOR_POINTS))
	light_color = Color(str(data.get("light_color", "#ffe080")))
	intensity = maxf(float(data.get("intensity", 2.0)), 0.0)
	radius = maxf(float(data.get("radius", 160.0)), 0.0)
	pulse_speed = maxf(float(data.get("pulse_speed", 2.0)), 0.0)
