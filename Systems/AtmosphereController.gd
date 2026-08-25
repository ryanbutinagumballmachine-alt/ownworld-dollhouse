# ==============================================================================
# Script: res://Systems/AtmosphereController.gd (PER-SLICE WEATHER ZONES)
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
var current_weather: String = "none"
var current_preset: String = "day"

var slice_emitters: Array[CPUParticles2D] = []
var cached_slices: Array[Dictionary] = []
var cached_slice_width: float = 1280.0


func _ready() -> void:
	add_to_group("AtmosphereController")
	_setup_canvas_modulate()


func _setup_canvas_modulate() -> void:
	canvas_modulate = CanvasModulate.new()
	canvas_modulate.name = "RoomCanvasModulate"
	canvas_modulate.color = TINT_DAY
	add_child(canvas_modulate)


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
	_update_all_slice_weather_emitters()


func configure_weather_slices(slices: Array[Dictionary], slice_width: float) -> void:
	cached_slices = slices.duplicate(true)
	cached_slice_width = slice_width

	for emitter: CPUParticles2D in slice_emitters:
		if is_instance_valid(emitter):
			emitter.queue_free()
	slice_emitters.clear()

	for i: int in range(cached_slices.size()):
		var sec_data: Dictionary = cached_slices[i]
		var is_outdoor: bool = bool(sec_data.get("is_outdoor", false))

		if is_outdoor:
			var emitter: CPUParticles2D = CPUParticles2D.new()
			emitter.name = "WeatherSlice_%d" % i
			emitter.position = Vector2(float(i) * slice_width + (slice_width * 0.5), -20.0)
			emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			emitter.emission_rect_extents = Vector2(slice_width * 0.5, 10.0)
			emitter.z_index = Types.LayerBands.FOREGROUND
			add_child(emitter)
			slice_emitters.append(emitter)

	_update_all_slice_weather_emitters()


func _update_all_slice_weather_emitters() -> void:
	var is_mobile: bool = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")

	for emitter: CPUParticles2D in slice_emitters:
		if not is_instance_valid(emitter):
			continue

		if current_weather == "none":
			emitter.emitting = false
			continue

		match current_weather:
			"rain":
				emitter.amount = 45 if is_mobile else 85
				emitter.lifetime = 1.2
				emitter.gravity = Vector2(-40.0, 750.0)
				emitter.scale_amount_min = 1.5
				emitter.scale_amount_max = 3.0
				emitter.color = Color(0.6, 0.8, 1.0, 0.7)
				emitter.emitting = true
			"snow":
				emitter.amount = 30 if is_mobile else 60
				emitter.lifetime = 3.5
				emitter.gravity = Vector2(10.0, 120.0)
				emitter.scale_amount_min = 2.5
				emitter.scale_amount_max = 5.0
				emitter.color = Color(1.0, 1.0, 1.0, 0.85)
				emitter.emitting = true
			"leaves":
				emitter.amount = 18 if is_mobile else 30
				emitter.lifetime = 4.0
				emitter.gravity = Vector2(-30.0, 80.0)
				emitter.scale_amount_min = 3.0
				emitter.scale_amount_max = 6.0
				emitter.color = Color(0.9, 0.45, 0.15, 0.9)
				emitter.emitting = true
			"dust":
				emitter.amount = 20 if is_mobile else 35
				emitter.lifetime = 3.0
				emitter.gravity = Vector2(0.0, -15.0)
				emitter.scale_amount_min = 2.0
				emitter.scale_amount_max = 3.5
				emitter.color = Color(1.0, 0.95, 0.6, 0.5)
				emitter.emitting = true


static var _cached_radial_texture: ImageTexture = null

static func get_cached_radial_texture() -> ImageTexture:
	if _cached_radial_texture != null:
		return _cached_radial_texture
	
	const TEX_SIZE: int = 256
	const HALF_SIZE: float = 128.0
	var img: Image = Image.create(TEX_SIZE, TEX_SIZE, true, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(HALF_SIZE, HALF_SIZE)
	
	for x: int in range(TEX_SIZE):
		for y: int in range(TEX_SIZE):
			var dist: float = Vector2(float(x), float(y)).distance_to(center)
			if dist < HALF_SIZE:
				var alpha: float = 1.0 - (dist / HALF_SIZE)
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
			else:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
	
	_cached_radial_texture = ImageTexture.create_from_image(img)
	return _cached_radial_texture


static func create_radial_point_light(radius: int = 140, tint: Color = Color(1.0, 0.85, 0.5, 0.9)) -> PointLight2D:
	var light: PointLight2D = PointLight2D.new()
	light.texture = get_cached_radial_texture()
	light.color = tint
	light.texture_scale = (float(radius) * 2.0) / 256.0
	light.blend_mode = PointLight2D.BLEND_MODE_ADD
	return light
