# ==============================================================================
# OWNWORLD — UNIFIED ACTOR ENTITY RUNTIME INSTANCE
# File: res://Core/Entities/OwnEntity.gd
# Base Class: Area2D (class_name OwnEntity)
#
# Responsibility: Interactive world entity runtime instance. Manages unified
# Actor States (static cutouts, multi-frame loops, GIFs, Natural Blinks), physical
# interaction states, modular components, procedural idle motion, and toggleable juice.
# ==============================================================================

class_name OwnEntity
extends Area2D

# --- Identity & Base Layering ---
var entity_id: String = ""
var display_name: String = "Item"
var entity_type: Types.EntityType = Types.EntityType.PROP
var state: Types.EntityState = Types.EntityState.IDLE
var base_layer_band: int = Types.LayerBands.PLAYFIELD
var is_locked: bool = false
var is_flipped_h: bool = false
var entity_scale: float = 1.0
var base_entity_scale: float = 1.0

# --- Spatial Placement Modifiers ---
var is_wall_mounted: bool = false
var can_float: bool = false
var is_floor_decor: bool = false

# --- Visual Nodes & Textures ---
var base_sprite: Sprite2D = null
var overlay_sprite: Sprite2D = null
var glow_sprite: Sprite2D = null
var collision_polygon_node: CollisionPolygon2D = null
var main_texture: Texture2D = null
var texture_path: String = ""
var texture_size: Vector2 = Vector2.ZERO
var collision_poly: PackedVector2Array = PackedVector2Array()
var collision_polygons: Array[PackedVector2Array] = []
var alpha_bitmap: BitMap = null
static var silhouette_glow_shader: Shader = null

# --- Unified Actor States & Wardrobe Forms ---
var wardrobe_forms: Dictionary = {}
var active_form_key: String = "Default"
var active_state_name: String = Types.STATE_IDLE
var current_pose_state: String = "default"

# Active State Playback Engine
var current_state_data: Dictionary = {}
var active_frames: Array[Texture2D] = []
var active_frame_delays: Array[float] = []
var active_playback_mode: int = Types.PlaybackMode.LOOP
var active_fps: float = 6.0
var state_frame_idx: int = 0
var state_playback_timer: float = 0.0
var ping_pong_forward: bool = true

# Natural Blink State Parameters
var blink_cycle_timer: float = 3.5
var is_in_blink_phase: bool = false
var expression_timer: float = 0.0

# Procedural Idle Juice (Breathing / Levitation Hover)
var idle_motion_timer: float = 0.0

# Dynamic Z-Sandwich Slicing
var slice_y_ratio: float = 0.0

# Consumables & Beverages
var is_consumable: bool = false
var is_drink: bool = false
var is_infinite: bool = false
var max_bites: int = 3
var current_state_idx: int = 0
var custom_stage_textures: Array[Texture2D] = []
var custom_stage_paths: Array[String] = []

# Liquids & Lighting
var is_liquid_container: bool = false
var fill_level: int = 0
var is_liquid_source: bool = false

var is_light_source: bool = false
var light_shape_mode: int = Types.LightShapeMode.SILHOUETTE_CONTOUR
var light_color: Color = Color(1.0, 0.88, 0.50, 0.85)
var light_intensity: float = 2.0
var light_radius: float = 160.0
var light_pulse_speed: float = 2.0
var linked_light: PointLight2D = null
var anchor_light_nodes: Array[PointLight2D] = []

# Portals, Stairs & Elevators
var is_portal: bool = false
var is_stairs: bool = false
var target_room_id: String = ""
var is_door_open: bool = false
var is_elevator: bool = false
var elevator_floors: Array[Dictionary] = []

# Containers
var is_container: bool = false
var is_open: bool = false
var container_open_texture: Texture2D = null
var container_open_path: String = ""
var stored_item_data: Array[Dictionary] = []

# Emitters & Particles
var is_active: bool = false
var linked_particles: CPUParticles2D = null

# Sockets & Anchors
var snap_points: Dictionary = {}
var interaction_points: Dictionary = {}
var parent_socket_entity: OwnEntity = null
var attached_socket_key: String = ""
var attached_children: Array[OwnEntity] = []
var gizmo_root: Node2D = null

var logic_rules: Array[Dictionary] = []
var custom_fields: Dictionary = {}
var components: Dictionary = {}

# UI Tweens & Speech
var speech_bubble_node: PanelContainer = null
var speech_label: Label = null
var speech_tween: Tween = null
var active_tween: Tween = null

signal entity_tapped(entity: OwnEntity)
signal entity_long_pressed(entity: OwnEntity)
signal state_changed(entity: OwnEntity, new_state: Types.EntityState)
signal actor_state_changed(entity: OwnEntity, state_name: String)


func _ready() -> void:
	y_sort_enabled = true
	add_to_group("entities")
	if entity_type == Types.EntityType.CHARACTER:
		add_to_group("characters")
	_setup_collision_layers()
	blink_cycle_timer = randf_range(2.5, 5.0)
	_update_process_state()


func _update_process_state() -> void:
	var is_animated_state: bool = (not active_frames.is_empty() and active_frames.size() > 1)
	var has_idle_juice: bool = (entity_type == Types.EntityType.CHARACTER or can_float) and SettingsManager.is_juice_idle_motion_enabled()
	var has_active_expression: bool = (expression_timer > 0.0)
	var needs_process: bool = is_animated_state or has_idle_juice or has_active_expression
	set_process(needs_process)


func _process(delta: float) -> void:
	# 1. Multi-Frame State Animation / GIF / Natural Blink Playback
	if not active_frames.is_empty() and active_frames.size() > 1:
		_process_state_animation(delta)

	# 2. Transient Expression Decay
	if expression_timer > 0.0:
		expression_timer -= delta
		if expression_timer <= 0.0:
			reset_to_default_pose()

	# 3. Procedural Idle Motion (Breathing & Levitation Hover applied strictly to visual sprites)
	if SettingsManager.is_juice_idle_motion_enabled() and parent_socket_entity == null and state != Types.EntityState.DRAGGING:
		_process_idle_motion(delta)


func _process_idle_motion(delta: float) -> void:
	idle_motion_timer += delta * 2.4
	var intensity: float = SettingsManager.get_juice_idle_intensity()
	if intensity <= 0.01:
		return

	if can_float:
		var hover_offset: float = sin(idle_motion_timer * 1.2) * (4.0 * intensity)
		if base_sprite != null:
			base_sprite.position.y = hover_offset
		if overlay_sprite != null and overlay_sprite.visible:
			overlay_sprite.position.y = -texture_size.y * 0.5 + hover_offset
	elif entity_type == Types.EntityType.CHARACTER and active_state_name == Types.STATE_IDLE:
		var breath: float = 1.0 + sin(idle_motion_timer) * (0.022 * intensity)
		if base_sprite != null:
			base_sprite.scale = Vector2(1.0, breath)
		if overlay_sprite != null and overlay_sprite.visible:
			overlay_sprite.scale = Vector2(1.0, breath)


# --- PHYSICAL ENTITY STATE & COMPONENT LIFECYCLE ---

func set_entity_state(new_state: Types.EntityState) -> void:
	state = new_state
	state_changed.emit(self, new_state)


func add_component(component: EntityComponent) -> void:
	if component == null: 
		return
	var key: StringName = component.get_component_key()
	components[key] = component
	component.initialize(self)


func get_component(key: StringName) -> EntityComponent:
	return components.get(key, null)


func has_component(key: StringName) -> bool:
	return components.has(key)


func remove_component(key: StringName) -> void:
	if components.has(key):
		var comp: EntityComponent = components[key]
		comp.shutdown()
		components.erase(key)


func notify_tapped() -> void: 
	entity_tapped.emit(self)

func notify_long_pressed() -> void: 
	entity_long_pressed.emit(self)


# --- UNIFIED ACTOR STATE MACHINE & NATURAL BLINK ENGINE ---

## Sets the active visual actor state (e.g. "idle", "sitting", "sleeping", "speaking", "eating", "dancing").
func set_actor_state(state_name: String, duration: float = 0.0) -> void:
	var clean_state: String = state_name.strip_edges().to_lower()
	if clean_state.is_empty():
		clean_state = Types.STATE_IDLE

	active_state_name = clean_state
	current_pose_state = clean_state
	expression_timer = duration

	_load_and_apply_state_data(active_state_name)
	_update_process_state()
	actor_state_changed.emit(self, active_state_name)
	EventBus.entity_state_changed.emit(entity_id)


## Legacy pose compatibility helper.
func set_pose_state(pose_name: String) -> void:
	set_actor_state(pose_name)


## Resets entity to base idle state.
func reset_to_default_pose() -> void:
	expression_timer = 0.0
	set_actor_state(Types.STATE_IDLE)


## Forces an immediate natural blink cycle for live studio mannequin testing.
func force_trigger_blink() -> void:
	if active_playback_mode == Types.PlaybackMode.NATURAL_BLINK and active_frames.size() > 1:
		is_in_blink_phase = true
		state_frame_idx = 1
		state_playback_timer = 0.0
		_apply_active_texture(active_frames[state_frame_idx], false)
	else:
		set_actor_state("blink", 0.5)


## Registers or updates a state within a wardrobe form.
func register_state(
	form_name: String,
	state_name: String,
	frames: Array[Texture2D],
	paths: Array[String],
	fps: float = 6.0,
	playback_mode: int = Types.PlaybackMode.LOOP,
	alt_texture: Texture2D = null,
	alt_path: String = ""
) -> void:
	var form_key: String = form_name.strip_edges()
	if form_key.is_empty(): 
		form_key = "Default"
	var clean_state: String = state_name.strip_edges().to_lower()
	if clean_state.is_empty(): 
		clean_state = Types.STATE_IDLE

	if not wardrobe_forms.has(form_key):
		wardrobe_forms[form_key] = {"path": "", "states": {}}

	var form_dict: Dictionary = wardrobe_forms[form_key]
	if not form_dict.has("states"):
		form_dict["states"] = {}

	form_dict["states"][clean_state] = {
		"frames": frames.duplicate(),
		"paths": paths.duplicate(),
		"fps": maxf(fps, 1.0),
		"mode": playback_mode,
		"alt_texture": alt_texture,
		"alt_path": alt_path
	}

	if form_key == active_form_key and clean_state == active_state_name:
		_load_and_apply_state_data(active_state_name)


## Loads state data from active wardrobe form and binds textures/timings.
func _load_and_apply_state_data(state_key: String) -> void:
	var form_dict: Dictionary = wardrobe_forms.get(active_form_key, {})
	var states_dict: Dictionary = form_dict.get("states", {})

	active_frames.clear()
	state_frame_idx = 0
	state_playback_timer = 0.0
	ping_pong_forward = true
	is_in_blink_phase = false
	blink_cycle_timer = randf_range(2.5, 5.0)

	if states_dict.has(state_key):
		current_state_data = states_dict[state_key]
		for f: Variant in current_state_data.get("frames", []):
			if f is Texture2D: 
				active_frames.append(f as Texture2D)

		active_fps = float(current_state_data.get("fps", 6.0))
		active_playback_mode = int(current_state_data.get("mode", Types.PlaybackMode.LOOP))
	else:
		current_state_data = {}
		active_fps = 6.0
		active_playback_mode = Types.PlaybackMode.LOOP
		var base_t: Texture2D = _get_active_form_base_texture()
		if base_t != null:
			active_frames.append(base_t)

	if not active_frames.is_empty():
		_apply_active_texture(active_frames[0], false)


func _process_state_animation(delta: float) -> void:
	if active_frames.size() <= 1:
		return

	# NATURAL BLINK ENGINE (Rests on Frame 0, blinks Frames 1+ every 2.5-5.0s)
	if active_playback_mode == Types.PlaybackMode.NATURAL_BLINK:
		if not is_in_blink_phase:
			blink_cycle_timer -= delta
			if blink_cycle_timer <= 0.0:
				is_in_blink_phase = true
				state_frame_idx = 1
				state_playback_timer = 0.0
				_apply_active_texture(active_frames[state_frame_idx], false)
		else:
			state_playback_timer += delta
			var blink_frame_dur: float = 1.0 / maxf(active_fps, 8.0)
			if state_playback_timer >= blink_frame_dur:
				state_playback_timer -= blink_frame_dur
				state_frame_idx += 1
				if state_frame_idx >= active_frames.size():
					state_frame_idx = 0
					is_in_blink_phase = false
					blink_cycle_timer = randf_range(2.5, 5.0)
				_apply_active_texture(active_frames[state_frame_idx], false)
		return

	# STANDARD PLAYBACK MODES (Loop, Ping-Pong, One-Shot, One-Shot & Hold)
	state_playback_timer += delta
	var frame_dur: float = 1.0 / maxf(active_fps, 1.0)

	if state_playback_timer >= frame_dur:
		state_playback_timer -= frame_dur

		match active_playback_mode:
			int(Types.PlaybackMode.LOOP):
				state_frame_idx = (state_frame_idx + 1) % active_frames.size()
				_apply_active_texture(active_frames[state_frame_idx], false)

			int(Types.PlaybackMode.PING_PONG):
				if ping_pong_forward:
					state_frame_idx += 1
					if state_frame_idx >= active_frames.size() - 1:
						state_frame_idx = active_frames.size() - 1
						ping_pong_forward = false
				else:
					state_frame_idx -= 1
					if state_frame_idx <= 0:
						state_frame_idx = 0
						ping_pong_forward = true
				_apply_active_texture(active_frames[state_frame_idx], false)

			int(Types.PlaybackMode.ONE_SHOT):
				state_frame_idx += 1
				if state_frame_idx >= active_frames.size():
					reset_to_default_pose()
					return
				_apply_active_texture(active_frames[state_frame_idx], false)

			int(Types.PlaybackMode.ONE_SHOT_HOLD):
				if state_frame_idx < active_frames.size() - 1:
					state_frame_idx += 1
					_apply_active_texture(active_frames[state_frame_idx], false)


func set_expression(expr_name: String, duration: float = 2.0) -> void:
	var clean: String = expr_name.strip_edges().to_lower()
	if clean == "mouth_open" or clean == Types.STATE_SPEAKING or clean == Types.STATE_EATING:
		set_actor_state(Types.STATE_SPEAKING, duration)
	else:
		set_actor_state(clean, duration)


func play_named_animation(anim_name: String) -> void:
	set_actor_state(anim_name)


func stop_animation_clip() -> void:
	reset_to_default_pose()


# --- SETUP & INITIALIZATION ---

func setup(p_id: String, p_display_name: String, p_tex: Texture2D, p_pos: Vector2, p_type: Types.EntityType = Types.EntityType.PROP, p_tex_path: String = "") -> void:
	entity_id = p_id.strip_edges()
	display_name = p_display_name.strip_edges()
	entity_type = p_type
	texture_path = p_tex_path.strip_edges()
	position = p_pos
	main_texture = p_tex
	base_layer_band = Types.LayerBands.FLOOR_DECOR if is_floor_decor else Types.LayerBands.PLAYFIELD
	z_index = base_layer_band
	z_as_relative = false
	rotation = 0.0
	is_flipped_h = false
	is_locked = false
	entity_scale = 1.0
	base_entity_scale = 1.0

	_build_scene_tree()
	set_entity_type(p_type)

	if p_type == Types.EntityType.CHARACTER:
		_initialize_character_profile_defaults()

	# Register Initial Default Form & Idle State
	wardrobe_forms["Default"] = {
		"path": p_tex_path,
		"states": {
			Types.STATE_IDLE: {
				"frames": [p_tex] if p_tex != null else [],
				"paths": [p_tex_path],
				"fps": 6.0,
				"mode": Types.PlaybackMode.LOOP,
				"alt_texture": null,
				"alt_path": ""
			}
		}
	}
	active_form_key = "Default"
	active_state_name = Types.STATE_IDLE

	if p_tex != null:
		texture_size = p_tex.get_size()
		_recalculate_collision_geometry(p_tex)
		_generate_default_starter_anchors_if_empty()

	rebuild_gizmos()
	_update_process_state()


func _initialize_character_profile_defaults() -> void:
	if not custom_fields.has("status"): custom_fields["status"] = "Living / Active"
	if not custom_fields.has("pronouns"): custom_fields["pronouns"] = ""
	if not custom_fields.has("role"): custom_fields["role"] = ""
	if not custom_fields.has("lore"): custom_fields["lore"] = ""
	if not custom_fields.has("avatar_path"): custom_fields["avatar_path"] = ""
	if not custom_fields.has("life_status"): custom_fields["life_status"] = "Living / Active"
	if not custom_fields.has("traits") or not (custom_fields["traits"] is Dictionary): custom_fields["traits"] = {}
	if not custom_fields.has("family_ties") or not (custom_fields["family_ties"] is Array): custom_fields["family_ties"] = []
	if not custom_fields.has("relationships") or not (custom_fields["relationships"] is Array): custom_fields["relationships"] = []


func update_character_profile(char_data: Dictionary) -> void:
	var new_name: String = str(char_data.get("display_name", "")).strip_edges()
	if not new_name.is_empty():
		display_name = new_name
	if char_data.has("custom_fields") and char_data["custom_fields"] is Dictionary:
		custom_fields = (char_data["custom_fields"] as Dictionary).duplicate(true)
	_initialize_character_profile_defaults()
	EventBus.entity_state_changed.emit(entity_id)


func _setup_collision_layers() -> void:
	collision_layer = 0
	collision_mask = 0
	match entity_type:
		Types.EntityType.PROP:
			set_collision_layer_value(1, true)
			set_collision_mask_value(2, true)
			set_collision_mask_value(3, true)
		Types.EntityType.CHARACTER:
			set_collision_layer_value(2, true)
			set_collision_mask_value(1, true)
			set_collision_mask_value(3, true)
		Types.EntityType.FURNITURE, Types.EntityType.CONTAINER, Types.EntityType.APPLIANCE:
			set_collision_layer_value(3, true)
			set_collision_mask_value(1, true)
			set_collision_mask_value(2, true)


func _build_scene_tree() -> void:
	base_sprite = Sprite2D.new()
	base_sprite.name = "BaseSprite"
	base_sprite.texture = main_texture
	base_sprite.centered = true
	add_child(base_sprite)

	glow_sprite = Sprite2D.new()
	glow_sprite.name = "SilhouetteGlow"
	glow_sprite.centered = true
	glow_sprite.visible = false
	glow_sprite.show_behind_parent = false
	glow_sprite.z_as_relative = true
	glow_sprite.z_index = 1
	add_child(glow_sprite)

	overlay_sprite = Sprite2D.new()
	overlay_sprite.name = "OverlaySprite"
	overlay_sprite.centered = false
	overlay_sprite.visible = false
	overlay_sprite.z_as_relative = true
	overlay_sprite.z_index = Types.LayerBands.FURNITURE_OVERLAY
	add_child(overlay_sprite)

	collision_polygon_node = CollisionPolygon2D.new()
	collision_polygon_node.name = "CollisionPolygon"
	add_child(collision_polygon_node)

	gizmo_root = Node2D.new()
	gizmo_root.name = "GizmoRoot"
	gizmo_root.visible = false
	gizmo_root.z_index = 700
	add_child(gizmo_root)

	_build_speech_bubble_ui()


func set_entity_type(p_type: Types.EntityType) -> void:
	entity_type = p_type
	_setup_collision_layers()
	is_container = (entity_type == Types.EntityType.CONTAINER)
	if p_type == Types.EntityType.CHARACTER:
		if not is_in_group("characters"): 
			add_to_group("characters")
		_initialize_character_profile_defaults()
	else:
		if is_in_group("characters"): 
			remove_from_group("characters")
	_update_process_state()


func _generate_default_starter_anchors_if_empty() -> void:
	if not snap_points.is_empty() or not interaction_points.is_empty():
		return

	match entity_type:
		Types.EntityType.CHARACTER:
			snap_points["hand_1"] = Vector2(texture_size.x * 0.35, texture_size.y * 0.1)
			snap_points["hand_2"] = Vector2(-texture_size.x * 0.35, texture_size.y * 0.1)
			snap_points["head_1"] = Vector2(0.0, -texture_size.y * 0.44)
			snap_points["face_1"] = Vector2(0.0, -texture_size.y * 0.32)
			snap_points["back_1"] = Vector2(0.0, -texture_size.y * 0.05)
			snap_points["sit_point"] = Vector2(0.0, texture_size.y * 0.35)
			interaction_points["mouth_1"] = {
				"offset": Vector2(0.0, -texture_size.y * 0.28),
				"radius": 55.0,
				"type": int(Types.InteractionPointType.MOUTH)
			}
		Types.EntityType.FURNITURE:
			snap_points["seat_1"] = Vector2(0.0, texture_size.y * 0.05)
			snap_points["surface_1"] = Vector2(0.0, -texture_size.y * 0.25)
			snap_points["bed_1"] = Vector2(0.0, 0.0)
			snap_points["hang_hook_1"] = Vector2(0.0, -texture_size.y * 0.2)
		Types.EntityType.CONTAINER:
			snap_points["slot_1"] = Vector2(0.0, 0.0)


# --- TEXTURE & WARDROBE SWITCHING ---

func _apply_active_texture(tex: Texture2D, recalculate_collision: bool = false) -> void:
	if tex == null:
		return
	main_texture = tex
	texture_size = tex.get_size()
	alpha_bitmap = UGCManager.generate_alpha_bitmap(main_texture)

	if glow_sprite != null:
		glow_sprite.texture = main_texture
		glow_sprite.position = Vector2.ZERO

	if slice_y_ratio > 0.01:
		set_slice_ratio(slice_y_ratio)
	elif base_sprite != null:
		base_sprite.texture = main_texture
		base_sprite.region_enabled = false
		base_sprite.centered = true
		base_sprite.position = Vector2.ZERO

	if recalculate_collision or collision_polygons.is_empty():
		_recalculate_collision_geometry(main_texture)


func _get_active_form_base_texture() -> Texture2D:
	var form_dict: Dictionary = wardrobe_forms.get(active_form_key, {})
	var states: Dictionary = form_dict.get("states", {})
	if states.has(Types.STATE_IDLE):
		var idle_frames: Array = states[Types.STATE_IDLE].get("frames", [])
		if not idle_frames.is_empty() and idle_frames[0] is Texture2D:
			return idle_frames[0] as Texture2D
	return main_texture


func add_wardrobe_form(form_name: String, tex: Texture2D, path: String) -> void:
	var form_key: String = form_name.strip_edges()
	if form_key.is_empty(): 
		form_key = "Form"

	wardrobe_forms[form_key] = {
		"path": path,
		"states": {
			Types.STATE_IDLE: {
				"frames": [tex] if tex != null else [],
				"paths": [path],
				"fps": 6.0,
				"mode": Types.PlaybackMode.LOOP,
				"alt_texture": null,
				"alt_path": ""
			}
		}
	}
	switch_wardrobe_form(form_key)


func switch_wardrobe_form(form_name: String) -> void:
	if not wardrobe_forms.has(form_name):
		return
	active_form_key = form_name
	_load_and_apply_state_data(active_state_name)
	rebuild_gizmos()

	if SettingsManager.is_juice_squash_stretch_enabled():
		_kill_active_tween()
		var rest_s: Vector2 = Vector2(-entity_scale if is_flipped_h else entity_scale, entity_scale)
		scale = rest_s * Vector2(1.1, 0.9)
		active_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(self, "scale", rest_s, 0.2)


# --- SOCKET ATTACHMENT & HIERARCHY ---

func attach_to_socket(target_parent: OwnEntity, socket_key: String, is_instant: bool = false) -> bool:
	if not target_parent or target_parent == self or _would_cause_parenting_cycle(target_parent):
		return false
	if not _is_socket_attachment_valid(target_parent, socket_key):
		return false

	parent_socket_entity = target_parent
	attached_socket_key = socket_key
	if not target_parent.attached_children.has(self):
		target_parent.attached_children.append(self)

	var start_world_pos: Vector2 = global_position
	reparent(target_parent, false)

	var anchor_pos: Vector2 = target_parent.snap_points.get(socket_key, Vector2.ZERO)
	z_as_relative = true
	z_index = 1

	var parent_s_x: float = target_parent.scale.x if not is_zero_approx(target_parent.scale.x) else 1.0
	var parent_s_y: float = target_parent.scale.y if not is_zero_approx(target_parent.scale.y) else 1.0
	var target_scale: Vector2 = Vector2(
		(-entity_scale if is_flipped_h else entity_scale) / parent_s_x,
		entity_scale / parent_s_y
	)

	var target_rot: float = 0.0

	if target_parent.entity_type == Types.EntityType.FURNITURE:
		if socket_key.begins_with("seat"):
			set_entity_state(Types.EntityState.SITTING)
			set_actor_state(Types.STATE_SITTING)
			target_rot = 0.0
			if snap_points.has("sit_point"):
				var my_sit_pt: Vector2 = snap_points["sit_point"]
				anchor_pos.y -= my_sit_pt.y * (entity_scale / parent_s_y)
				anchor_pos.x -= (my_sit_pt.x if not is_flipped_h else -my_sit_pt.x) * (entity_scale / absf(parent_s_x))
		elif socket_key.begins_with("bed"):
			set_entity_state(Types.EntityState.SLEEPING)
			set_actor_state(Types.STATE_SLEEPING)
			target_rot = -PI * 0.5
	elif target_parent.entity_type == Types.EntityType.CHARACTER:
		set_entity_state(Types.EntityState.HELD)

	position = target_parent.to_local(start_world_pos)
	rotation = target_rot
	scale = target_scale

	_kill_active_tween()
	if is_instant or not SettingsManager.is_juice_squash_stretch_enabled():
		position = anchor_pos
	else:
		active_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(self, "position", anchor_pos, 0.28)
		if socket_key.begins_with("seat"):
			active_tween.chain().tween_property(self, "scale", target_scale * Vector2(1.05, 0.95), 0.08).set_trans(Tween.TRANS_SINE)
			active_tween.chain().tween_property(self, "scale", target_scale, 0.12).set_trans(Tween.TRANS_SINE)

	return true


func detach_from_socket(new_canvas_parent: Node2D) -> void:
	if parent_socket_entity and is_instance_valid(parent_socket_entity):
		parent_socket_entity.attached_children.erase(self)

	var curr_world_pos: Vector2 = global_position
	reparent(new_canvas_parent, false)
	global_position = curr_world_pos

	z_as_relative = false
	z_index = base_layer_band
	rotation = 0.0
	scale = Vector2(-entity_scale if is_flipped_h else entity_scale, entity_scale)
	parent_socket_entity = null
	attached_socket_key = ""
	set_entity_state(Types.EntityState.IDLE)
	reset_to_default_pose()


func _would_cause_parenting_cycle(potential_parent: Node) -> bool:
	var current: Node = potential_parent
	while current != null:
		if current == self: 
			return true
		current = current.get_parent()
	return false


func _is_socket_attachment_valid(target_parent: OwnEntity, socket_key: String) -> bool:
	var sk_low: String = socket_key.to_lower()
	if sk_low == "sit_point": 
		return false

	if target_parent.entity_type == Types.EntityType.CHARACTER:
		if sk_low.begins_with("hand") or sk_low.begins_with("head") or sk_low.begins_with("face") or sk_low.begins_with("back") or sk_low.begins_with("neck") or sk_low.begins_with("hold"):
			return entity_type == Types.EntityType.PROP
		return false
	elif target_parent.entity_type == Types.EntityType.FURNITURE:
		if sk_low.begins_with("seat") or sk_low.begins_with("bed"):
			return entity_type == Types.EntityType.CHARACTER
		elif sk_low.begins_with("surface") or sk_low.begins_with("hang") or sk_low.begins_with("hook"):
			return entity_type == Types.EntityType.PROP
		return false
	elif target_parent.entity_type == Types.EntityType.CONTAINER:
		return entity_type == Types.EntityType.PROP

	return false


# --- CONTAINERS & CONSUMABLES ---

func toggle_container() -> void:
	if not is_container: 
		return
	is_open = not is_open

	if is_open and container_open_texture != null:
		_apply_active_texture(container_open_texture, false)
	else:
		_apply_active_texture(_get_active_form_base_texture(), false)

	for child: OwnEntity in attached_children:
		if is_instance_valid(child):
			child.visible = is_open
			child.process_mode = PROCESS_MODE_INHERIT if is_open else PROCESS_MODE_DISABLED

	AudioManager.play_pop_grab()


func pack_item_inside(item: OwnEntity) -> void:
	if not is_container or not is_instance_valid(item): 
		return
	stored_item_data.append(item.to_dict())
	item.queue_free()


func configure_as_consumable(custom_stages: Array[Texture2D] = [], custom_paths: Array[String] = []) -> void:
	is_consumable = true
	is_drink = false
	current_state_idx = 0
	base_entity_scale = entity_scale

	custom_stage_textures.clear()
	custom_stage_paths.clear()

	if not custom_stages.is_empty():
		custom_stage_textures = custom_stages.duplicate()
		custom_stage_paths = custom_paths.duplicate()
		max_bites = custom_stage_textures.size() + 1
	else:
		max_bites = 3


func unconfigure_consumable() -> void:
	is_consumable = false
	is_drink = false
	is_infinite = false
	current_state_idx = 0
	custom_stage_paths.clear()
	custom_stage_textures.clear()
	set_entity_scale(base_entity_scale)
	_apply_active_texture(_get_active_form_base_texture(), false)


func take_bite() -> bool:
	if not is_consumable or is_drink: 
		return false

	AudioManager.play_chew()
	_spawn_crumb_burst()

	if not is_infinite:
		current_state_idx += 1
		if not custom_stage_textures.is_empty():
			if current_state_idx > custom_stage_textures.size():
				if SettingsManager.is_juice_squash_stretch_enabled():
					var tw: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
					tw.tween_property(self, "scale", Vector2.ZERO, 0.15)
					tw.chain().tween_callback(queue_free)
				else:
					queue_free()
				return true
			else:
				var stage_idx: int = current_state_idx - 1
				if stage_idx < custom_stage_textures.size() and custom_stage_textures[stage_idx] != null:
					main_texture = custom_stage_textures[stage_idx]
					if stage_idx < custom_stage_paths.size(): 
						texture_path = custom_stage_paths[stage_idx]
					_apply_active_texture(main_texture, false)
		else:
			if current_state_idx >= max_bites:
				if SettingsManager.is_juice_squash_stretch_enabled():
					var tw: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
					tw.tween_property(self, "scale", Vector2.ZERO, 0.15)
					tw.chain().tween_callback(queue_free)
				else:
					queue_free()
				return true
			else:
				var shrink_ratio: float = 1.0 - (float(current_state_idx) / float(max_bites)) * 0.7
				set_entity_scale(base_entity_scale * shrink_ratio)

	if SettingsManager.is_juice_squash_stretch_enabled():
		_kill_active_tween()
		var p_scale_x: float = 1.0
		var p_scale_y: float = 1.0
		if parent_socket_entity and is_instance_valid(parent_socket_entity):
			p_scale_x = parent_socket_entity.scale.x if not is_zero_approx(parent_socket_entity.scale.x) else 1.0
			p_scale_y = parent_socket_entity.scale.y if not is_zero_approx(parent_socket_entity.scale.y) else 1.0

		var target_s: Vector2 = Vector2((-entity_scale if is_flipped_h else entity_scale) / p_scale_x, entity_scale / p_scale_y)
		scale = target_s * Vector2(1.15, 0.85)
		active_tween = create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(self, "scale", target_s, 0.2)
	return false


func take_sip() -> void:
	if not is_drink or (not is_infinite and fill_level <= 0): 
		return
	if not is_infinite: 
		fill_level = maxi(fill_level - 1, 0)

	AudioManager.play_sip()
	if SettingsManager.is_juice_squash_stretch_enabled():
		_kill_active_tween()
		var p_scale_x: float = 1.0
		var p_scale_y: float = 1.0
		if parent_socket_entity and is_instance_valid(parent_socket_entity):
			p_scale_x = parent_socket_entity.scale.x if not is_zero_approx(parent_socket_entity.scale.x) else 1.0
			p_scale_y = parent_socket_entity.scale.y if not is_zero_approx(parent_socket_entity.scale.y) else 1.0

		var rest_s: Vector2 = Vector2((-entity_scale if is_flipped_h else entity_scale) / p_scale_x, entity_scale / p_scale_y)
		scale = rest_s * Vector2(1.12, 0.9)
		active_tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(self, "scale", rest_s, 0.2)


func fill_with_liquid() -> void:
	fill_level = mini(fill_level + 1, 2)
	AudioManager.play_pour()

	if SettingsManager.is_juice_squash_stretch_enabled():
		_kill_active_tween()
		var p_scale_x: float = 1.0
		var p_scale_y: float = 1.0
		if parent_socket_entity and is_instance_valid(parent_socket_entity):
			p_scale_x = parent_socket_entity.scale.x if not is_zero_approx(parent_socket_entity.scale.x) else 1.0
			p_scale_y = parent_socket_entity.scale.y if not is_zero_approx(parent_socket_entity.scale.y) else 1.0

		var rest_s: Vector2 = Vector2((-entity_scale if is_flipped_h else entity_scale) / p_scale_x, entity_scale / p_scale_y)
		scale = rest_s * Vector2(1.15, 0.88)
		active_tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(self, "scale", rest_s, 0.25)


func _spawn_crumb_burst() -> void:
	var crumbs: CPUParticles2D = CPUParticles2D.new()
	crumbs.position = global_position
	crumbs.emitting = true
	crumbs.one_shot = true
	crumbs.explosiveness = 0.8
	crumbs.amount = 8
	crumbs.lifetime = 0.4
	crumbs.spread = 180.0
	crumbs.gravity = Vector2(0.0, 150.0)
	crumbs.initial_velocity_min = 40.0
	crumbs.initial_velocity_max = 80.0
	crumbs.scale_amount_min = 2.0
	crumbs.scale_amount_max = 4.0
	crumbs.color = Color("#fde047")
	var parent_node: Node = get_parent()
	if parent_node != null:
		parent_node.add_child(crumbs)
		var timer: SceneTreeTimer = get_tree().create_timer(0.5)
		timer.timeout.connect(crumbs.queue_free)


# --- 2D LIGHTING ---

static func _ensure_glow_shader() -> void:
	if silhouette_glow_shader != null: 
		return
	silhouette_glow_shader = Shader.new()
	var is_mobile: bool = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")

	if is_mobile:
		silhouette_glow_shader.code = """
shader_type canvas_item;
render_mode blend_add;
uniform vec4 glow_color : source_color = vec4(1.0, 0.88, 0.50, 0.85);
uniform float glow_spread : hint_range(0.0, 30.0) = 10.0;
uniform float glow_intensity : hint_range(0.0, 5.0) = 2.2;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.2;
void fragment() {
	vec4 base_tex = texture(TEXTURE, UV);
	vec2 pixel_size = TEXTURE_PIXEL_SIZE * glow_spread;
	float alpha_sum = 0.0;
	for (float x = -1.0; x <= 1.0; x += 1.0) {
		for (float y = -1.0; y <= 1.0; y += 1.0) {
			vec2 offset = vec2(x, y) * pixel_size * 0.8;
			alpha_sum += texture(TEXTURE, UV + offset).a;
		}
	}
	alpha_sum /= 9.0;
	float combined_alpha = max(base_tex.a, alpha_sum);
	float pulse = (pulse_speed > 0.01) ? (0.88 + 0.12 * sin(TIME * pulse_speed)) : 1.0;
	COLOR = vec4(glow_color.rgb * glow_intensity, combined_alpha * glow_color.a * pulse);
}
"""
	else:
		silhouette_glow_shader.code = """
shader_type canvas_item;
render_mode blend_add;
uniform vec4 glow_color : source_color = vec4(1.0, 0.88, 0.50, 0.85);
uniform float glow_spread : hint_range(0.0, 30.0) = 10.0;
uniform float glow_intensity : hint_range(0.0, 5.0) = 2.2;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.2;
void fragment() {
	vec4 base_tex = texture(TEXTURE, UV);
	vec2 pixel_size = TEXTURE_PIXEL_SIZE * glow_spread;
	float alpha_sum = 0.0;
	for (float x = -2.0; x <= 2.0; x += 1.0) {
		for (float y = -2.0; y <= 2.0; y += 1.0) {
			vec2 offset = vec2(x, y) * pixel_size * 0.5;
			alpha_sum += texture(TEXTURE, UV + offset).a;
		}
	}
	alpha_sum /= 25.0;
	float combined_alpha = max(base_tex.a * 1.0, alpha_sum);
	float pulse = (pulse_speed > 0.01) ? (0.88 + 0.12 * sin(TIME * pulse_speed)) : 1.0;
	COLOR = vec4(glow_color.rgb * glow_intensity, combined_alpha * glow_color.a * pulse);
}
"""


func configure_lighting_settings(mode: int, color_val: Color, intensity_val: float, radius_val: float, pulse_val: float) -> void:
	is_light_source = true
	light_shape_mode = mode
	light_color = color_val
	light_intensity = intensity_val
	light_radius = radius_val
	light_pulse_speed = pulse_val
	_apply_current_lighting_state()


func configure_as_light_source(glow_radius: int = 150) -> void:
	is_light_source = true
	light_radius = float(glow_radius)
	_apply_current_lighting_state()


func _apply_current_lighting_state() -> void:
	_ensure_glow_shader()
	for al: PointLight2D in anchor_light_nodes:
		if is_instance_valid(al): 
			al.queue_free()
	anchor_light_nodes.clear()

	if light_shape_mode == Types.LightShapeMode.SILHOUETTE_CONTOUR:
		if glow_sprite == null:
			glow_sprite = Sprite2D.new()
			glow_sprite.name = "SilhouetteGlow"
			glow_sprite.centered = true
			add_child(glow_sprite)
		glow_sprite.texture = main_texture
		glow_sprite.show_behind_parent = false
		glow_sprite.z_as_relative = true
		glow_sprite.z_index = 1

		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = silhouette_glow_shader
		mat.set_shader_parameter("glow_color", light_color)
		mat.set_shader_parameter("glow_spread", clampf(light_radius * 0.08, 2.0, 25.0))
		mat.set_shader_parameter("glow_intensity", light_intensity)
		mat.set_shader_parameter("pulse_speed", light_pulse_speed)
		glow_sprite.material = mat
		glow_sprite.visible = is_active
		if linked_light: 
			linked_light.enabled = false

	elif light_shape_mode == Types.LightShapeMode.RADIAL_ROOM:
		if glow_sprite: 
			glow_sprite.visible = false
		if not linked_light:
			linked_light = AtmosphereController.create_radial_point_light(int(light_radius), light_color)
			linked_light.name = "PointLight"
			add_child(linked_light)
		linked_light.color = light_color
		linked_light.energy = light_intensity * 0.6
		var b_scale: float = (light_radius * 2.0) / 256.0
		linked_light.texture_scale = b_scale * clampf(light_radius / 100.0, 0.5, 8.0)
		linked_light.enabled = is_active

	elif light_shape_mode == Types.LightShapeMode.ANCHOR_POINTS:
		if glow_sprite: 
			glow_sprite.visible = false
		if linked_light: 
			linked_light.enabled = false
		for s_key: String in snap_points.keys():
			if s_key.to_lower().begins_with("light"):
				var pt_pos: Vector2 = snap_points[s_key]
				var al: PointLight2D = AtmosphereController.create_radial_point_light(int(light_radius), light_color)
				al.position = pt_pos
				al.energy = light_intensity * 0.7
				var b_scale: float = (light_radius * 2.0) / 256.0
				al.texture_scale = b_scale * clampf(light_radius / 100.0, 0.3, 6.0)
				al.enabled = is_active
				add_child(al)
				anchor_light_nodes.append(al)


func unconfigure_light_source() -> void:
	is_light_source = false
	if glow_sprite: 
		glow_sprite.visible = false
	if linked_light:
		linked_light.queue_free()
		linked_light = null
	for al: PointLight2D in anchor_light_nodes:
		if is_instance_valid(al): 
			al.queue_free()
	anchor_light_nodes.clear()


# --- GEOMETRY, COLLISION & SCALE ---

func _recalculate_collision_geometry(tex: Texture2D) -> void:
	if not tex:
		collision_poly = PackedVector2Array()
		collision_polygons.clear()
		alpha_bitmap = null
		if collision_polygon_node: 
			collision_polygon_node.polygon = collision_poly
		return

	alpha_bitmap = UGCManager.generate_alpha_bitmap(tex, 0.05)
	collision_polygons = UGCManager.generate_alpha_collision_polygons(tex, 0.05, 4.0)
	collision_poly = UGCManager.generate_alpha_collision_polygon(tex, 0.05, 4.0)
	if collision_polygon_node:
		collision_polygon_node.polygon = collision_poly


func get_visual_bottom_offset_local() -> float:
	if not collision_polygons.is_empty():
		var max_y: float = -999999.0
		for poly: PackedVector2Array in collision_polygons:
			for pt: Vector2 in poly:
				if pt.y > max_y: 
					max_y = pt.y
		if max_y > -900000.0: 
			return max_y
	elif collision_poly.size() >= 3:
		var max_y: float = -999999.0
		for pt: Vector2 in collision_poly:
			if pt.y > max_y: 
				max_y = pt.y
		return max_y
	return texture_size.y * 0.5


func get_visual_bottom_offset() -> float:
	return get_visual_bottom_offset_local() * entity_scale


func get_visual_half_width() -> float:
	if not collision_polygons.is_empty():
		var max_x: float = 0.0
		for poly: PackedVector2Array in collision_polygons:
			for pt: Vector2 in poly:
				var ax: float = absf(pt.x)
				if ax > max_x: 
					max_x = ax
		if max_x > 0.0: 
			return max_x * entity_scale
	elif collision_poly.size() >= 3:
		var max_x: float = 0.0
		for pt: Vector2 in collision_poly:
			var ax: float = absf(pt.x)
			if ax > max_x: 
				max_x = ax
		return max_x * entity_scale
	return texture_size.x * 0.5 * entity_scale


func set_entity_scale(new_scale: float) -> void:
	entity_scale = clampf(new_scale, 0.05, 4.0)
	var p_scale_x: float = 1.0
	var p_scale_y: float = 1.0
	if parent_socket_entity and is_instance_valid(parent_socket_entity):
		p_scale_x = parent_socket_entity.scale.x if not is_zero_approx(parent_socket_entity.scale.x) else 1.0
		p_scale_y = parent_socket_entity.scale.y if not is_zero_approx(parent_socket_entity.scale.y) else 1.0
	scale = Vector2((-entity_scale if is_flipped_h else entity_scale) / p_scale_x, entity_scale / p_scale_y)


func flip_horizontal() -> void:
	is_flipped_h = not is_flipped_h
	_kill_active_tween()
	var p_scale_x: float = 1.0
	if parent_socket_entity and is_instance_valid(parent_socket_entity):
		p_scale_x = parent_socket_entity.scale.x if not is_zero_approx(parent_socket_entity.scale.x) else 1.0
	var target_scale_x: float = (-entity_scale if is_flipped_h else entity_scale) / p_scale_x

	if SettingsManager.is_juice_squash_stretch_enabled():
		active_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(self, "scale:x", target_scale_x, 0.18)
	else:
		scale.x = target_scale_x
	AudioManager.play_pop_grab()


func configure_as_floor_decor(enabled: bool) -> void:
	is_floor_decor = enabled
	base_layer_band = Types.LayerBands.FLOOR_DECOR if enabled else Types.LayerBands.PLAYFIELD
	z_index = base_layer_band


# --- PORTALS, STAIRS & ELEVATORS ---

func configure_as_portal(p_target_room: String, p_portal_name: String) -> void:
	is_portal = true
	is_stairs = false
	is_elevator = false
	is_wall_mounted = true
	target_room_id = p_target_room.strip_edges()
	display_name = p_portal_name.strip_edges() if not p_portal_name.strip_edges().is_empty() else display_name


func configure_as_stairs(p_name: String = "Stairs") -> void:
	is_portal = true
	is_stairs = true
	is_elevator = false
	display_name = p_name.strip_edges() if not p_name.strip_edges().is_empty() else display_name


func configure_as_elevator(floors: Array[Dictionary] = [], p_name: String = "Elevator") -> void:
	is_portal = true
	is_stairs = false
	is_elevator = true
	is_wall_mounted = true
	display_name = p_name.strip_edges() if not p_name.strip_edges().is_empty() else display_name

	if floors.is_empty():
		elevator_floors = [
			{"label": "1F Main Room", "room_id": "room_main"},
			{"label": "2F Upper Floor", "room_id": "room_destination"}
		]
	else:
		elevator_floors = floors.duplicate(true)


func unconfigure_portal_and_elevator() -> void:
	is_portal = false
	is_stairs = false
	is_elevator = false
	elevator_floors.clear()
	target_room_id = ""


func toggle_door() -> void:
	is_door_open = not is_door_open
	AudioManager.play_pop_grab()
	_kill_active_tween()
	var rest_s: Vector2 = Vector2(-entity_scale if is_flipped_h else entity_scale, entity_scale)

	if SettingsManager.is_juice_squash_stretch_enabled():
		active_tween = create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		if is_door_open:
			active_tween.tween_property(self, "modulate", Color(1.3, 1.3, 1.3, 0.85), 0.15)
			active_tween.parallel().tween_property(self, "scale", rest_s * Vector2(0.9, 1.05), 0.15)
		else:
			active_tween.tween_property(self, "modulate", Color.WHITE, 0.15)
			active_tween.parallel().tween_property(self, "scale", rest_s, 0.15)
	else:
		modulate = Color(1.3, 1.3, 1.3, 0.85) if is_door_open else Color.WHITE


func open_door_instant() -> void:
	is_door_open = true
	modulate = Color(1.2, 1.2, 1.2, 0.9)


func close_door_animated(callback: Callable = Callable()) -> void:
	is_door_open = false
	_kill_active_tween()
	var rest_s: Vector2 = Vector2(-entity_scale if is_flipped_h else entity_scale, entity_scale)

	if SettingsManager.is_juice_squash_stretch_enabled():
		active_tween = create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(self, "modulate", Color.WHITE, 0.2)
		active_tween.parallel().tween_property(self, "scale", rest_s, 0.2)
		if callback.is_valid(): 
			active_tween.chain().tween_callback(callback)
	else:
		modulate = Color.WHITE
		scale = rest_s
		if callback.is_valid(): 
			callback.call()


func get_passengers_in_cab(all_entities_list: Array[OwnEntity]) -> Array[OwnEntity]:
	var passengers: Array[OwnEntity] = []
	var half_w: float = texture_size.x * 0.5 * entity_scale + 30.0
	var half_h: float = texture_size.y * 0.5 * entity_scale + 30.0
	var cab_rect: Rect2 = Rect2(global_position - Vector2(half_w, half_h), Vector2(half_w * 2.0, half_h * 2.0))

	for ent: OwnEntity in all_entities_list:
		if is_instance_valid(ent) and ent != self and ent.parent_socket_entity == null:
			if cab_rect.has_point(ent.global_position): 
				passengers.append(ent)
	return passengers


func get_passengers_for_elevator() -> Array[OwnEntity]:
	var tree: SceneTree = get_tree()
	if tree == null: 
		return []
	var list: Array[OwnEntity] = []
	for node: Node in tree.get_nodes_in_group("entities"):
		if node is OwnEntity: 
			list.append(node as OwnEntity)
	return get_passengers_in_cab(list)


# --- LIQUIDS & PARTICLES ---

func get_faucet_stream_offset() -> Vector2:
	for ik: String in interaction_points.keys():
		if ik.begins_with("faucet") or ik.begins_with("liquid"):
			return interaction_points[ik].get("offset", Vector2.ZERO)
	for sk: String in snap_points.keys():
		if sk.begins_with("faucet") or sk.begins_with("liquid"):
			return snap_points[sk]
	return Vector2(0.0, -texture_size.y * 0.1 if texture_size.y > 0 else 0.0)


func _create_water_stream_particles(pos: Vector2) -> CPUParticles2D:
	var stream: CPUParticles2D = CPUParticles2D.new()
	stream.name = "WaterStream"
	stream.position = pos
	stream.emitting = false
	stream.amount = 24
	stream.lifetime = 0.4
	stream.gravity = Vector2(0.0, 250.0)
	stream.initial_velocity_min = 30.0
	stream.initial_velocity_max = 50.0
	stream.scale_amount_min = 2.0
	stream.scale_amount_max = 3.5
	stream.color = Color("#38bdf8")
	stream.z_index = 5
	return stream


func update_faucet_particles() -> void:
	if not is_liquid_source:
		if linked_particles and is_instance_valid(linked_particles):
			linked_particles.queue_free()
			linked_particles = null
		return

	var offset_pos: Vector2 = get_faucet_stream_offset()

	if not linked_particles or not is_instance_valid(linked_particles):
		linked_particles = _create_water_stream_particles(offset_pos)
		add_child(linked_particles)
	else:
		linked_particles.position = offset_pos

	linked_particles.emitting = is_active


func configure_as_liquid_source() -> void:
	is_liquid_source = true
	var has_faucet_anchor: bool = false
	for k: String in interaction_points.keys():
		if k.begins_with("faucet") or k.begins_with("liquid"):
			has_faucet_anchor = true
			break
	if not has_faucet_anchor:
		for k: String in snap_points.keys():
			if k.begins_with("faucet") or k.begins_with("liquid"):
				has_faucet_anchor = true
				break

	if not has_faucet_anchor:
		interaction_points["faucet_stream"] = {
			"offset": Vector2(0.0, -texture_size.y * 0.1 if texture_size.y > 0 else 0.0),
			"radius": 45.0,
			"type": int(Types.InteractionPointType.LIQUID_STREAM)
		}

	update_faucet_particles()
	rebuild_gizmos()


func unconfigure_liquid_source() -> void:
	is_liquid_source = false
	if linked_particles and is_instance_valid(linked_particles):
		linked_particles.queue_free()
		linked_particles = null
	interaction_points.erase("faucet_stream")
	rebuild_gizmos()


func toggle_active_state() -> void:
	if is_portal or is_elevator:
		toggle_door()
		return
	if is_container:
		toggle_container()
		return

	is_active = not is_active
	if is_liquid_source:
		update_faucet_particles()
		if is_active: 
			AudioManager.play_pour()
	elif is_light_source:
		_apply_current_lighting_state()
		AudioManager.play_snap_chime()

	if SettingsManager.is_juice_squash_stretch_enabled():
		_kill_active_tween()
		var p_scale_x: float = 1.0
		var p_scale_y: float = 1.0
		if parent_socket_entity and is_instance_valid(parent_socket_entity):
			p_scale_x = parent_socket_entity.scale.x if not is_zero_approx(parent_socket_entity.scale.x) else 1.0
			p_scale_y = parent_socket_entity.scale.y if not is_zero_approx(parent_socket_entity.scale.y) else 1.0

		var rest_s: Vector2 = Vector2((-entity_scale if is_flipped_h else entity_scale) / p_scale_x, entity_scale / p_scale_y)
		scale = rest_s * Vector2(1.08, 0.92)
		active_tween = create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(self, "scale", rest_s, 0.15)


# --- DRAGGING & JUICE GESTURES ---

func on_grab() -> void:
	set_entity_state(Types.EntityState.DRAGGING)
	z_as_relative = false
	z_index = Types.LayerBands.DRAGGING
	rotation = 0.0

	if SettingsManager.is_juice_squash_stretch_enabled():
		_kill_active_tween()
		active_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var rest_s: Vector2 = Vector2(-entity_scale if is_flipped_h else entity_scale, entity_scale)
		active_tween.tween_property(self, "scale", rest_s * 1.05, 0.08)


func on_drop() -> void:
	set_entity_state(Types.EntityState.IDLE)
	z_as_relative = false
	z_index = base_layer_band
	rotation = 0.0

	if parent_socket_entity == null and entity_type == Types.EntityType.CHARACTER:
		if active_state_name in [Types.STATE_SITTING, Types.STATE_SLEEPING]:
			reset_to_default_pose()

	if SettingsManager.is_juice_squash_stretch_enabled():
		_kill_active_tween()
		active_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var rest_s: Vector2 = Vector2(-entity_scale if is_flipped_h else entity_scale, entity_scale)
		active_tween.tween_property(self, "scale", rest_s * Vector2(1.06, 0.94), 0.07)
		active_tween.tween_property(self, "scale", rest_s, 0.12)


func trigger_spawn_juice() -> void:
	if not SettingsManager.is_juice_spawn_springs_enabled():
		return
	_kill_active_tween()
	var rest_s: Vector2 = Vector2(-entity_scale if is_flipped_h else entity_scale, entity_scale)
	scale = rest_s * Vector2(0.85, 1.15)
	active_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(self, "scale", rest_s, 0.22)


func set_slice_ratio(ratio: float) -> void:
	slice_y_ratio = ratio
	if ratio <= 0.01:
		if base_sprite:
			base_sprite.texture = main_texture
			base_sprite.region_enabled = false
			base_sprite.centered = true
			base_sprite.position = Vector2.ZERO
		if overlay_sprite: 
			overlay_sprite.visible = false
		return

	if not main_texture: 
		return
	var w: float = texture_size.x
	var h: float = texture_size.y
	var split_y: float = h * ratio

	var base_atlas: AtlasTexture = AtlasTexture.new()
	base_atlas.atlas = main_texture
	base_atlas.region = Rect2(0.0, split_y, w, h - split_y)
	base_sprite.texture = base_atlas
	base_sprite.centered = false
	base_sprite.position = Vector2(-w * 0.5, -h * 0.5 + split_y)

	var overlay_atlas: AtlasTexture = AtlasTexture.new()
	overlay_atlas.atlas = main_texture
	overlay_atlas.region = Rect2(0.0, 0.0, w, split_y)
	overlay_sprite.texture = overlay_atlas
	overlay_sprite.position = Vector2(-w * 0.5, -h * 0.5)
	overlay_sprite.visible = true


func has_point_exact(world_p: Vector2) -> bool:
	var local_p: Vector2 = to_local(world_p)

	if texture_size.x > 0.0 and texture_size.y > 0.0:
		var half_box: Vector2 = texture_size * 0.5
		if not Rect2(-half_box, texture_size).has_point(local_p):
			return false

	if alpha_bitmap != null and texture_size.x > 0.0 and texture_size.y > 0.0:
		var bm_size: Vector2i = alpha_bitmap.get_size()
		if bm_size.x > 0 and bm_size.y > 0:
			var norm_x: float = (local_p.x + (texture_size.x * 0.5)) / texture_size.x
			var norm_y: float = (local_p.y + (texture_size.y * 0.5)) / texture_size.y
			var px: int = int(norm_x * float(bm_size.x))
			var py: int = int(norm_y * float(bm_size.y))
			if px >= 0 and px < bm_size.x and py >= 0 and py < bm_size.y:
				return alpha_bitmap.get_bit(px, py)

	if not collision_polygons.is_empty():
		for poly: PackedVector2Array in collision_polygons:
			if poly.size() >= 3 and Geometry2D.is_point_in_polygon(local_p, poly):
				return true
		return false
	elif collision_poly.size() >= 3:
		return Geometry2D.is_point_in_polygon(local_p, collision_poly)

	if texture_size.x > 0.0 and texture_size.y > 0.0:
		var half_box: Vector2 = texture_size * 0.5
		return Rect2(-half_box, texture_size).has_point(local_p)

	return false


func contains_point(world_p: Vector2, touch_padding: float = 0.0) -> bool:
	if has_point_exact(world_p):
		return true

	if touch_padding > 0.0 and texture_size.x > 0.0 and texture_size.y > 0.0:
		var local_p: Vector2 = to_local(world_p)
		var scale_mag: float = absf(entity_scale) if not is_zero_approx(entity_scale) else 1.0
		var scaled_padding: float = touch_padding / scale_mag
		var half_pad_box: Vector2 = (texture_size * 0.5) + Vector2(scaled_padding, scaled_padding)
		return Rect2(-half_pad_box, half_pad_box * 2.0).has_point(local_p)

	return false


func _kill_active_tween() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()


func rebuild_gizmos() -> void:
	if not gizmo_root: 
		return
	for child: Node in gizmo_root.get_children():
		child.queue_free()

	for s_key: String in snap_points.keys():
		var g_pos: Vector2 = snap_points[s_key]
		var gizmo: AnchorMarker = AnchorMarker.new()
		gizmo.name = "snap_" + s_key
		gizmo.anchor_name = s_key
		gizmo.position = g_pos
		gizmo.marker_color = Color("#ec4899") if s_key.begins_with("sit") else Color("#00f2fe")
		gizmo.radius = 12.0
		gizmo_root.add_child(gizmo)

	for i_key: String in interaction_points.keys():
		var p_data: Dictionary = interaction_points[i_key]
		var i_pos: Vector2 = p_data.get("offset", Vector2.ZERO)
		var gizmo: AnchorMarker = AnchorMarker.new()
		gizmo.name = "inter_" + i_key
		gizmo.anchor_name = i_key
		gizmo.position = i_pos
		gizmo.marker_color = Color("#f59e0b")
		gizmo.radius = 14.0
		gizmo_root.add_child(gizmo)

	if is_liquid_source:
		update_faucet_particles()


func update_gizmo_visibility(show_gizmos: bool) -> void:
	if gizmo_root: 
		gizmo_root.visible = show_gizmos


func _build_speech_bubble_ui() -> void:
	speech_bubble_node = PanelContainer.new()
	speech_bubble_node.name = "SpeechBubble"
	speech_bubble_node.visible = false
	speech_bubble_node.z_index = 650

	var c_sub_bg: Color = ThemeService.get_color("container_sub_bg", "#ffffff")
	var c_border: Color = ThemeService.get_color("accent_primary", "#db2777")
	var c_text: Color = ThemeService.get_color("text_primary", "#4a1525")
	var rad: int = ThemeService.get_corner_radius()

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = c_sub_bg
	style.border_color = c_border
	style.set_border_width_all(2)
	style.set_corner_radius_all(rad)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	speech_bubble_node.add_theme_stylebox_override("panel", style)

	speech_label = Label.new()
	speech_label.add_theme_color_override("font_color", c_text)
	speech_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech_bubble_node.add_child(speech_label)
	add_child(speech_bubble_node)


func show_speech_bubble(text_to_say: String) -> void:
	if not speech_bubble_node or not speech_label: 
		return
	speech_label.text = text_to_say
	speech_bubble_node.visible = true
	speech_bubble_node.position = Vector2(-speech_bubble_node.size.x * 0.5, -texture_size.y * 0.65 - 40.0)

	if speech_tween and speech_tween.is_valid():
		speech_tween.kill()

	if SettingsManager.is_juice_squash_stretch_enabled():
		speech_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		speech_bubble_node.scale = Vector2(0.2, 0.2)
		speech_tween.tween_property(speech_bubble_node, "scale", Vector2.ONE, 0.2)
		speech_tween.chain().tween_interval(3.5)
		speech_tween.chain().tween_property(speech_bubble_node, "scale", Vector2.ZERO, 0.15)
		speech_tween.chain().tween_callback(func() -> void: speech_bubble_node.visible = false)
	else:
		speech_bubble_node.scale = Vector2.ONE
		var timer: SceneTreeTimer = get_tree().create_timer(3.5)
		timer.timeout.connect(func() -> void: if speech_bubble_node: speech_bubble_node.visible = false)


func spray_emotion(symbol_char: String) -> void:
	if symbol_char.is_empty(): 
		return
	var lbl: Label = Label.new()
	lbl.text = symbol_char
	lbl.position = Vector2(0.0, -texture_size.y * 0.5)
	lbl.z_index = 680
	add_child(lbl)

	if SettingsManager.is_juice_squash_stretch_enabled():
		var tw: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(lbl, "position:y", -texture_size.y * 0.5 - 60.0, 0.8)
		tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
		tw.chain().tween_callback(lbl.queue_free)
	else:
		var timer: SceneTreeTimer = get_tree().create_timer(0.8)
		timer.timeout.connect(lbl.queue_free)


func get_full_hierarchy_bundle() -> Array[Dictionary]:
	var bundle: Array[Dictionary] = [to_dict()]
	for child: OwnEntity in attached_children:
		if is_instance_valid(child): 
			bundle.append_array(child.get_full_hierarchy_bundle())
	return bundle


# --- SERIALIZATION & PERSISTENCE ---

func to_dict() -> Dictionary:
	var snap_dict: Dictionary = {}
	for k: String in snap_points.keys():
		var v: Vector2 = snap_points[k]
		snap_dict[k] = {"x": v.x, "y": v.y}

	var inter_dict: Dictionary = {}
	for ik: String in interaction_points.keys():
		var idata: Dictionary = interaction_points[ik]
		var offset_v: Vector2 = idata.get("offset", Vector2.ZERO)
		inter_dict[ik] = {
			"offset_x": offset_v.x, "offset_y": offset_v.y,
			"radius": float(idata.get("radius", 55.0)),
			"type": int(idata.get("type", 0))
		}

	# Serialize Unified Wardrobe States
	var forms_dict: Dictionary = {}
	for fk: String in wardrobe_forms.keys():
		var form_d: Dictionary = wardrobe_forms[fk]
		var raw_states: Dictionary = form_d.get("states", {})
		var states_save: Dictionary = {}

		for s_key: String in raw_states.keys():
			var s_info: Dictionary = raw_states[s_key]
			states_save[s_key] = {
				"paths": (s_info.get("paths", []) as Array).duplicate(),
				"fps": float(s_info.get("fps", 6.0)),
				"mode": int(s_info.get("mode", Types.PlaybackMode.LOOP)),
				"alt_path": str(s_info.get("alt_path", ""))
			}

		forms_dict[fk] = {
			"path": form_d.get("path", ""),
			"states": states_save
		}

	var components_dict: Dictionary = {}
	for c_key: StringName in components.keys():
		var comp: EntityComponent = components[c_key]
		components_dict[str(c_key)] = comp.serialize()

	return {
		"id": entity_id,
		"display_name": display_name,
		"entity_type": int(entity_type),
		"texture_path": texture_path,
		"x": global_position.x,
		"y": global_position.y,
		"rotation": rotation,
		"z_index": z_index,
		"z_as_relative": z_as_relative,
		"modulate": "#" + modulate.to_html(true),
		"layer_band": base_layer_band,
		"slice_y_ratio": slice_y_ratio,
		"active_form_key": active_form_key,
		"active_state_name": active_state_name,
		"current_pose_state": active_state_name,
		"is_locked": is_locked,
		"is_flipped_h": is_flipped_h,
		"entity_scale": entity_scale,
		"base_entity_scale": base_entity_scale,
		"is_wall_mounted": is_wall_mounted,
		"can_float": can_float,
		"is_floor_decor": is_floor_decor,
		"is_consumable": is_consumable,
		"is_drink": is_drink,
		"is_infinite": is_infinite,
		"max_bites": max_bites,
		"current_state_idx": current_state_idx,
		"custom_stage_paths": custom_stage_paths.duplicate(),
		"is_liquid_container": is_liquid_container,
		"fill_level": fill_level,
		"is_liquid_source": is_liquid_source,
		"is_light_source": is_light_source,
		"light_shape_mode": light_shape_mode,
		"light_color": "#" + light_color.to_html(true),
		"light_intensity": light_intensity,
		"light_radius": light_radius,
		"light_pulse_speed": light_pulse_speed,
		"is_portal": is_portal,
		"is_stairs": is_stairs,
		"target_room_id": target_room_id,
		"is_door_open": is_door_open,
		"is_elevator": is_elevator,
		"elevator_floors": elevator_floors.duplicate(true),
		"is_active": is_active,
		"is_container": is_container,
		"is_open": is_open,
		"container_open_path": container_open_path,
		"stored_item_data": stored_item_data.duplicate(true),
		"snap_points": snap_dict,
		"interaction_points": inter_dict,
		"wardrobe_forms": forms_dict,
		"custom_fields": custom_fields.duplicate(true),
		"logic_rules": logic_rules.duplicate(true),
		"components": components_dict,
		"parent_socket_entity_id": parent_socket_entity.entity_id if parent_socket_entity else "",
		"attached_socket_key": attached_socket_key
	}


func from_dict(d: Dictionary) -> void:
	if d.has("id"): 
		entity_id = str(d["id"]).strip_edges()
	display_name = str(d.get("display_name", entity_id)).strip_edges()
	entity_type = int(d.get("entity_type", Types.EntityType.PROP)) as Types.EntityType
	_setup_collision_layers()

	is_locked = bool(d.get("is_locked", false))
	is_floor_decor = bool(d.get("is_floor_decor", false))
	base_layer_band = int(d.get("layer_band", Types.LayerBands.FLOOR_DECOR if is_floor_decor else Types.LayerBands.PLAYFIELD))
	z_index = int(d.get("z_index", base_layer_band))
	z_as_relative = bool(d.get("z_as_relative", false))

	if d.has("rotation"): 
		rotation = float(d["rotation"])
	if d.has("modulate"): 
		modulate = Color(str(d["modulate"]))

	slice_y_ratio = float(d.get("slice_y_ratio", 0.0))
	is_flipped_h = bool(d.get("is_flipped_h", false))
	entity_scale = float(d.get("entity_scale", 1.0))
	base_entity_scale = float(d.get("base_entity_scale", entity_scale))
	is_wall_mounted = bool(d.get("is_wall_mounted", false))
	can_float = bool(d.get("can_float", false))

	is_consumable = bool(d.get("is_consumable", false))
	is_drink = bool(d.get("is_drink", false))
	is_infinite = bool(d.get("is_infinite", false))
	max_bites = int(d.get("max_bites", 3))
	current_state_idx = int(d.get("current_state_idx", 0))

	custom_stage_paths.clear()
	custom_stage_textures.clear()
	var raw_c_paths: Array = d.get("custom_stage_paths", [])
	for p_v: Variant in raw_c_paths:
		var p_str: String = str(p_v)
		custom_stage_paths.append(p_str)
		if FileAccess.file_exists(p_str):
			custom_stage_textures.append(UGCManager.load_texture_from_file(p_str))

	is_liquid_container = bool(d.get("is_liquid_container", false))
	fill_level = int(d.get("fill_level", 0))
	is_liquid_source = bool(d.get("is_liquid_source", false))

	is_light_source = bool(d.get("is_light_source", false))
	light_shape_mode = int(d.get("light_shape_mode", Types.LightShapeMode.SILHOUETTE_CONTOUR))
	light_color = Color(str(d.get("light_color", "#ffe080")))
	light_intensity = float(d.get("light_intensity", 2.0))
	light_radius = float(d.get("light_radius", 160.0))
	light_pulse_speed = float(d.get("light_pulse_speed", 2.0))

	is_portal = bool(d.get("is_portal", false))
	is_stairs = bool(d.get("is_stairs", false))
	target_room_id = str(d.get("target_room_id", "")).strip_edges()
	is_door_open = bool(d.get("is_door_open", false))
	is_elevator = bool(d.get("is_elevator", false))

	elevator_floors.clear()
	var raw_floors: Array = d.get("elevator_floors", [])
	for f_obj: Variant in raw_floors:
		if f_obj is Dictionary: 
			elevator_floors.append((f_obj as Dictionary).duplicate(true))

	is_active = bool(d.get("is_active", false))
	is_container = bool(d.get("is_container", false))
	is_open = bool(d.get("is_open", false))
	container_open_path = str(d.get("container_open_path", "")).strip_edges()
	if not container_open_path.is_empty() and FileAccess.file_exists(container_open_path):
		container_open_texture = UGCManager.load_texture_from_file(container_open_path)

	custom_fields = d.get("custom_fields", {}).duplicate(true)
	if entity_type == Types.EntityType.CHARACTER: 
		_initialize_character_profile_defaults()

	# Deserialize Unified States with Full Legacy Upgrade Support
	wardrobe_forms.clear()
	var raw_forms: Dictionary = d.get("wardrobe_forms", {})

	for f_key: String in raw_forms.keys():
		var f_val: Variant = raw_forms[f_key]
		var f_path: String = ""
		var parsed_states: Dictionary = {}

		if f_val is Dictionary:
			var f_dict: Dictionary = f_val as Dictionary
			f_path = str(f_dict.get("path", ""))

			if f_dict.has("states"):
				var raw_st: Dictionary = f_dict["states"]
				for s_name: String in raw_st.keys():
					var s_info: Dictionary = raw_st[s_name]
					var frames: Array[Texture2D] = []
					var paths: Array[String] = []
					for p: Variant in s_info.get("paths", []):
						var p_str: String = str(p)
						paths.append(p_str)
						if FileAccess.file_exists(p_str):
							if p_str.get_extension().to_lower() == "gif":
								var g_data: Dictionary = UGCManager.load_gif(p_str)
								for gf: Variant in g_data.get("frames", []):
									if gf is Texture2D: 
										frames.append(gf as Texture2D)
							else:
								frames.append(UGCManager.load_texture_from_file(p_str))

					var alt_p: String = str(s_info.get("alt_path", ""))
					var alt_t: Texture2D = UGCManager.load_texture_from_file(alt_p) if FileAccess.file_exists(alt_p) else null

					parsed_states[s_name] = {
						"frames": frames,
						"paths": paths,
						"fps": float(s_info.get("fps", 6.0)),
						"mode": int(s_info.get("mode", Types.PlaybackMode.LOOP)),
						"alt_texture": alt_t,
						"alt_path": alt_p
					}
			else:
				# Upgrade legacy sprite_paths
				var sprite_paths: Dictionary = f_dict.get("sprite_paths", {})
				for s_key: String in ["eyes_open", "eyes_closed", "mouth_open", "sitting", "sitting_eyes_closed", "sitting_eyes_mouth_open"]:
					var p_str: String = str(sprite_paths.get(s_key, ""))
					var t_tex: Texture2D = UGCManager.load_texture_from_file(p_str) if FileAccess.file_exists(p_str) else null
					if t_tex != null:
						parsed_states[s_key] = {
							"frames": [t_tex],
							"paths": [p_str],
							"fps": 6.0,
							"mode": Types.PlaybackMode.LOOP,
							"alt_texture": null,
							"alt_path": ""
						}

				# Upgrade legacy animations dictionary
				var raw_saved_anims: Dictionary = f_dict.get("animations", {})
				for c_name: String in raw_saved_anims.keys():
					var c_info: Dictionary = raw_saved_anims[c_name]
					var loaded_frames: Array[Texture2D] = []
					var p_arr: Array = c_info.get("paths", [])
					var valid_paths: Array[String] = []
					for p_val: Variant in p_arr:
						var p_str: String = str(p_val)
						valid_paths.append(p_str)
						if FileAccess.file_exists(p_str):
							loaded_frames.append(UGCManager.load_texture_from_file(p_str))
					parsed_states[c_name.to_lower()] = {
						"frames": loaded_frames,
						"paths": valid_paths,
						"fps": float(c_info.get("fps", 6.0)),
						"mode": Types.PlaybackMode.LOOP,
						"alt_texture": null,
						"alt_path": ""
					}

		wardrobe_forms[f_key] = {
			"path": f_path,
			"states": parsed_states
		}

	active_form_key = str(d.get("active_form_key", "Default"))
	active_state_name = str(d.get("active_state_name", d.get("current_pose_state", Types.STATE_IDLE)))
	set_actor_state(active_state_name)

	if is_open and container_open_texture != null:
		_apply_active_texture(container_open_texture, false)

	stored_item_data.clear()
	for s_item: Variant in d.get("stored_item_data", []):
		if s_item is Dictionary: 
			stored_item_data.append((s_item as Dictionary).duplicate(true))

	configure_as_floor_decor(is_floor_decor)
	set_slice_ratio(slice_y_ratio)
	set_entity_scale(entity_scale)

	if is_elevator: 
		configure_as_elevator(elevator_floors, display_name)
	elif is_stairs: 
		configure_as_stairs(display_name)
	elif is_portal: 
		configure_as_portal(target_room_id, display_name)

	if is_door_open: 
		open_door_instant()

	logic_rules.clear()
	for r: Variant in d.get("logic_rules", []):
		if r is Dictionary: 
			logic_rules.append((r as Dictionary).duplicate(true))

	snap_points.clear()
	var snap_data: Dictionary = d.get("snap_points", {})
	for k: String in snap_data.keys():
		var v: Dictionary = snap_data[k]
		snap_points[k] = Vector2(float(v.get("x", 0.0)), float(v.get("y", 0.0)))

	interaction_points.clear()
	var inter_data: Dictionary = d.get("interaction_points", {})
	for ik: String in inter_data.keys():
		var iv: Dictionary = inter_data[ik]
		interaction_points[ik] = {
			"offset": Vector2(float(iv.get("offset_x", 0.0)), float(iv.get("offset_y", 0.0))),
			"radius": float(iv.get("radius", 55.0)),
			"type": int(iv.get("type", 0))
		}

	if is_liquid_source:
		configure_as_liquid_source()
		if is_active and linked_particles: 
			linked_particles.emitting = true

	if is_light_source: 
		_apply_current_lighting_state()

	var components_dict: Dictionary = d.get("components", {})
	for c_key: StringName in components.keys():
		if components.has(StringName(c_key)):
			var comp: EntityComponent = components[StringName(c_key)]
			comp.deserialize(components_dict.get(c_key, {}))

	rebuild_gizmos()
	_update_process_state()


class AnchorMarker extends Node2D:
	var anchor_name: String = ""
	var marker_color: Color = Color("#00f2fe")
	var radius: float = 12.0

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius + 4.0, Color(marker_color.r, marker_color.g, marker_color.b, 0.25))
		draw_arc(Vector2.ZERO, radius + 1.0, 0.0, TAU, 28, Color("#000000", 0.85), 3.5)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, marker_color, 2.5)
		draw_circle(Vector2.ZERO, 4.0, Color.WHITE)
		draw_circle(Vector2.ZERO, 2.0, marker_color)
		draw_line(Vector2(-radius - 3.0, 0.0), Vector2(-4.0, 0.0), marker_color, 2.0)
		draw_line(Vector2(4.0, 0.0), Vector2(radius + 3.0, 0.0), marker_color, 2.0)
		draw_line(Vector2(0.0, -radius - 3.0), Vector2(0.0, -4.0), marker_color, 2.0)
		draw_line(Vector2(0.0, 4.0), Vector2(0.0, radius + 3.0), marker_color, 2.0)

		if not anchor_name.is_empty():
			var font: Font = ThemeDB.fallback_font
			var lbl_str: String = anchor_name
			var font_sz: int = 10
			var text_w: float = font.get_string_size(lbl_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz).x
			var badge_rect: Rect2 = Rect2(Vector2(-text_w * 0.5 - 4.0, radius + 4.0), Vector2(text_w + 8.0, 14.0))
			draw_rect(badge_rect, Color("#000000", 0.85), true)
			draw_rect(badge_rect, marker_color, false, 1.0)
			draw_string(font, Vector2(-text_w * 0.5, radius + 15.0), lbl_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz, Color.WHITE)
