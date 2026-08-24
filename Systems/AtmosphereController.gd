# ==============================================================================
# Script: res://Systems/AtmosphereController.gd
# Base Class: Node2D (class_name AtmosphereController)
# ==============================================================================

class_name AtmosphereController
extends Node2D

const TINT_DAY: Color = Color(1.0, 1.0, 1.0, 1.0)
const TINT_SUNSET: Color = Color(1.0, 0.74, 0.58, 1.0)
const TINT_NIGHT: Color = Color(0.22, 0.26, 0.48, 1.0)
const TINT_COZY: Color = Color(1.0, 0.88, 0.72, 1.0)
const TINT_CYBERPUNK: Color = Color(0.35, 0.18, 0.55, 1.0)

var canvas_modulate: CanvasModulate = null
var weather_emitter: CPUParticles2D = null
var current_weather: String = "none"
var current_preset: String = "day"


func _ready() -> void:
	add_to_group("AtmosphereController")
	_setup_canvas_modulate()
	_setup_weather_emitter()


func _setup_canvas_modulate() -> void:
	canvas_modulate = CanvasModulate.new()
	canvas_modulate.name = "RoomCanvasModulate"
	canvas_modulate.color = TINT_DAY
	add_child(canvas_modulate)


func _setup_weather_emitter() -> void:
	weather_emitter = CPUParticles2D.new()
	weather_emitter.name = "WeatherParticles"
	weather_emitter.emitting = false
	weather_emitter.position = Vector2(960.0, -20.0)
	weather_emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	weather_emitter.emission_rect_extents = Vector2(1050.0, 10.0)
	weather_emitter.z_index = Types.LayerBands.FOREGROUND
	add_child(weather_emitter)


func set_atmosphere_tint(target_color: Color, duration: float = 0.8) -> void:
	if not canvas_modulate:
		return
	var tw: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(canvas_modulate, "color", target_color, duration)


func set_preset(preset_name: String) -> void:
	current_preset = preset_name.to_lower()
	match current_preset:
		"day": set_atmosphere_tint(TINT_DAY)
		"sunset": set_atmosphere_tint(TINT_SUNSET)
		"night": set_atmosphere_tint(TINT_NIGHT)
		"cozy": set_atmosphere_tint(TINT_COZY)
		"cyberpunk": set_atmosphere_tint(TINT_CYBERPUNK)


func set_weather(weather_name: String) -> void:
	current_weather = weather_name.to_lower()
	if not weather_emitter:
		return

	match current_weather:
		"none":
			weather_emitter.emitting = false
		"rain":
			weather_emitter.amount = 120
			weather_emitter.lifetime = 1.2
			weather_emitter.gravity = Vector2(-40.0, 750.0)
			weather_emitter.scale_amount_min = 1.5
			weather_emitter.scale_amount_max = 3.0
			weather_emitter.color = Color(0.6, 0.8, 1.0, 0.7)
			weather_emitter.emitting = true
		"snow":
			weather_emitter.amount = 80
			weather_emitter.lifetime = 3.5
			weather_emitter.gravity = Vector2(10.0, 120.0)
			weather_emitter.scale_amount_min = 2.5
			weather_emitter.scale_amount_max = 5.0
			weather_emitter.color = Color(1.0, 1.0, 1.0, 0.85)
			weather_emitter.emitting = true
		"leaves":
			weather_emitter.amount = 35
			weather_emitter.lifetime = 4.0
			weather_emitter.gravity = Vector2(-30.0, 80.0)
			weather_emitter.scale_amount_min = 3.0
			weather_emitter.scale_amount_max = 6.0
			weather_emitter.color = Color(0.9, 0.45, 0.15, 0.9)
			weather_emitter.emitting = true
		"dust":
			weather_emitter.amount = 40
			weather_emitter.lifetime = 3.0
			weather_emitter.gravity = Vector2(0.0, -15.0)
			weather_emitter.scale_amount_min = 2.0
			weather_emitter.scale_amount_max = 3.5
			weather_emitter.color = Color(1.0, 0.95, 0.6, 0.5)
			weather_emitter.emitting = true


static func create_radial_point_light(radius: int = 140, tint: Color = Color(1.0, 0.85, 0.5, 0.9)) -> PointLight2D:
	var light: PointLight2D = PointLight2D.new()
	var img: Image = Image.create(radius * 2, radius * 2, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(float(radius), float(radius))
	var rad_f: float = float(radius)

	for x: int in range(radius * 2):
		for y: int in range(radius * 2):
			var dist: float = Vector2(float(x), float(y)).distance_to(center)
			if dist < rad_f:
				var alpha: float = (1.0 - (dist / rad_f)) * tint.a
				img.set_pixel(x, y, Color(tint.r, tint.g, tint.b, alpha))
			else:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))

	light.texture = ImageTexture.create_from_image(img)
	light.blend_mode = PointLight2D.BLEND_MODE_ADD
	return light
