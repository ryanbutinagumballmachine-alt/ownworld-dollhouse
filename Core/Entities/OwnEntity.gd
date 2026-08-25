# ==============================================================================
# OWNWORLD — ENTITY RUNTIME INSTANCE (HYPER-OPTIMIZED & ROBUST)
# File: res://Core/Entities/OwnEntity.gd
# Base Class: Area2D (class_name OwnEntity)
# ==============================================================================

class_name OwnEntity
extends Area2D

enum LightShapeMode {
	SILHOUETTE_CONTOUR = 0,
	RADIAL_ROOM = 1,
	ANCHOR_POINTS = 2
}

# Core Identity
var entity_id: String = ""
var display_name: String = "Item"
var entity_type: Types.EntityType = Types.EntityType.PROP
var state: Types.EntityState = Types.EntityState.IDLE
var base_layer_band: int = Types.LayerBands.PLAYFIELD
var is_locked: bool = false
var is_flipped_h: bool = false
var entity_scale: float = 1.0
var base_entity_scale: float = 1.0

# Physical Spatial Modifiers
var is_wall_mounted: bool = false
var can_float: bool = false
var is_floor_decor: bool = false

# Visual Presentation Nodes
var base_sprite: Sprite2D = null
var overlay_sprite: Sprite2D = null
var glow_sprite: Sprite2D = null
var door_label_node: Label = null
var collision_polygon_node: CollisionPolygon2D = null
var main_texture: Texture2D = null
var texture_path: String = ""
var texture_size: Vector2 = Vector2.ZERO
var collision_poly: PackedVector2Array = PackedVector2Array()
var collision_polygons: Array[PackedVector2Array] = []
var alpha_bitmap: BitMap = null
static var silhouette_glow_shader: Shader = null

# 6-Pose Whole-Sprite Matrix & Animation Clips
var wardrobe_forms: Dictionary = {}
var active_form_key: String = "Default"
var current_pose_state: String = "default"
var active_expression_name: String = "eyes_open"
var expression_timer: float = 0.0

# Intentional Logic-Driven Animation Playback
var active_clip_name: String = ""
var active_clip_frames: Array[Texture2D] = []
var active_clip_paths: Array[String] = []
var active_clip_fps: float = 6.0
var active_clip_mode: String = "loop"
var clip_frame_idx: int = 0
var clip_playback_timer: float = 0.0

# Natural Blinking Timer
var blink_timer: float = 3.5
var is_blinking_active: bool = false

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

# Interactive Liquids & Full-Spectrum Lighting
var is_liquid_container: bool = false
var fill_level: int = 0
var is_liquid_source: bool = false

var is_light_source: bool = false
var light_shape_mode: int = LightShapeMode.SILHOUETTE_CONTOUR
var light_color: Color = Color(1.0, 0.88, 0.50, 0.85)
var light_intensity: float = 2.0
var light_radius: float = 160.0
var light_pulse_speed: float = 2.0
var linked_light: PointLight2D = null
var anchor_light_nodes: Array[PointLight2D] = []

# Portals & Multi-Floor Elevators
var is_portal: bool = false
var target_room_id: String = ""
var is_door_open: bool = false
var is_elevator: bool = false
var elevator_floors: Array[Dictionary] = []

# Direct In-World Physical Containers
var is_container: bool = false
var is_open: bool = false
var container_open_texture: Texture2D = null
var container_open_path: String = ""
var stored_item_data: Array[Dictionary] = []

# Environmental Emitters
var is_active: bool = false
var linked_particles: CPUParticles2D = null

# Sockets & Interaction Zones
var snap_points: Dictionary = {}
var interaction_points: Dictionary = {}
var parent_socket_entity: OwnEntity = null
var attached_socket_key: String = ""
var attached_children: Array[OwnEntity] = []
var gizmo_root: Node2D = null

var logic_rules: Array[Dictionary] = []
var custom_fields: Dictionary = {}

# Component Container Architecture
var components: Dictionary = {}

# Dialogue Speech Bubbles & Tweens
var speech_bubble_node: PanelContainer = null
var speech_label: Label = null
var speech_tween: Tween = null
var active_tween: Tween = null

signal entity_tapped(entity: OwnEntity)
signal entity_long_pressed(entity: OwnEntity)
signal state_changed(entity: OwnEntity, new_state: Types.EntityState)

func _ready() -> void:
	y_sort_enabled = true
	add_to_group("entities")
	if entity_type == Types.EntityType.CHARACTER:
		add_to_group("characters")
	_setup_collision_layers()
	blink_timer = randf_range(2.5, 4.5)
	_update_process_state()

func _update_process_state() -> void:
	var needs_process: bool = (entity_type == Types.EntityType.CHARACTER) or (active_clip_frames.size() > 0)
	set_process(needs_process)

func _process(delta: float) -> void:
	if active_clip_frames.size() > 0:
		_process_animation_clip(delta)
	elif entity_type == Types.EntityType.CHARACTER:
		_process_expression_and_blinking(delta)

# COMPONENT LIFECYCLE API
func add_component(component: EntityComponent) -> void:
	if component == null: return
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

func notify_tapped() -> void: entity_tapped.emit(self)
func notify_long_pressed() -> void: entity_long_pressed.emit(self)

func set_entity_state(new_state: Types.EntityState) -> void:
	state = new_state
	state_changed.emit(self, new_state)

func setup(p_id: String, p_display_name: String, p_tex: Texture2D, p_pos: Vector2, p_type: Types.EntityType = Types.EntityType.PROP, p_tex_path: String = "") -> void:
	entity_id = p_id
	display_name = p_display_name
	entity_type = p_type
	texture_path = p_tex_path
	position = p_pos
	main_texture = p_tex
	base_layer_band = Types.LayerBands.FLOOR_DECOR if is_floor_decor else Types.LayerBands.PLAYFIELD
	z_index = base_layer_band
	z_as_relative = false
	rotation = 0.0
	is_flipped_h = false
	entity_scale = 1.0
	base_entity_scale = 1.0

	_build_scene_tree()
	set_entity_type(p_type)

	if p_type == Types.EntityType.CHARACTER:
		_initialize_character_profile_defaults()

	wardrobe_forms["Default"] = {
		"tex": p_tex,
		"path": p_tex_path,
		"sprites": {
			"eyes_open": p_tex, "eyes_closed": null, "mouth_open": null,
			"sitting": null, "sitting_eyes_closed": null, "sitting_eyes_mouth_open": null
		},
		"sprite_paths": {
			"eyes_open": p_tex_path, "eyes_closed": "", "mouth_open": "",
			"sitting": "", "sitting_eyes_closed": "", "sitting_eyes_mouth_open": ""
		},
		"animations": {}
	}
	active_form_key = "Default"

	if p_tex:
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

# --- LIVE PROFILE / LORE REFRESH API ---
func update_character_profile(char_data: Dictionary) -> void:
	var new_name: String = str(char_data.get("display_name", "")).strip_edges()
	if not new_name.is_empty():
		display_name = new_name
		if door_label_node != null:
			door_label_node.text = display_name

	if char_data.has("custom_fields") and char_data["custom_fields"] is Dictionary:
		custom_fields = (char_data["custom_fields"] as Dictionary).duplicate(true)
	
	_initialize_character_profile_defaults()
	EventBus.entity_state_changed.emit(entity_id)

func apply_character_lore(p_display_name: String, p_custom_fields: Dictionary) -> void:
	if not p_display_name.is_empty():
		display_name = p_display_name
		if door_label_node != null:
			door_label_node.text = display_name
	custom_fields = p_custom_fields.duplicate(true)
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

# POSES & EXPRESSIONS
func set_pose_state(pose_name: String) -> void:
	current_pose_state = pose_name.to_lower()
	_update_active_render_texture(false)

func reset_to_default_pose() -> void:
	current_pose_state = "default"
	active_expression_name = "eyes_open"
	is_blinking_active = false
	stop_animation_clip()
	_update_active_render_texture(false)

func set_expression(expr_name: String, duration: float = 0.0) -> void:
	active_expression_name = expr_name
	expression_timer = duration
	_update_active_render_texture(false)

func _process_expression_and_blinking(delta: float) -> void:
	if active_clip_frames.size() > 0:
		return

	if expression_timer > 0.0:
		expression_timer -= delta
		if expression_timer <= 0.0:
			active_expression_name = "eyes_open"
			_update_active_render_texture(false)

	if current_pose_state != "sleeping" and expression_timer <= 0.0:
		blink_timer -= delta
		if blink_timer <= 0.0:
			if not is_blinking_active:
				is_blinking_active = true
				blink_timer = 0.16
				_update_active_render_texture(false)
			else:
				is_blinking_active = false
				blink_timer = randf_range(3.0, 5.0)
				_update_active_render_texture(false)

func _update_active_render_texture(recalculate_collision: bool = false) -> void:
	if active_clip_frames.size() > 0:
		return

	var chosen_tex: Texture2D = null
	if current_pose_state == "sitting":
		if is_blinking_active:
			chosen_tex = _get_slot_texture("sitting_eyes_closed")
			if not chosen_tex: chosen_tex = _get_slot_texture("eyes_closed")
			if not chosen_tex: chosen_tex = _get_slot_texture("sitting")
		elif active_expression_name == "mouth_open":
			chosen_tex = _get_slot_texture("sitting_eyes_mouth_open")
			if not chosen_tex: chosen_tex = _get_slot_texture("mouth_open")
			if not chosen_tex: chosen_tex = _get_slot_texture("sitting")
		else:
			chosen_tex = _get_slot_texture("sitting")
	elif current_pose_state == "sleeping":
		chosen_tex = _get_slot_texture("eyes_closed")
	else:
		if is_blinking_active:
			chosen_tex = _get_slot_texture("eyes_closed")
		elif active_expression_name == "mouth_open":
			chosen_tex = _get_slot_texture("mouth_open")
		else:
			chosen_tex = _get_slot_texture("eyes_open")

	_apply_active_texture(chosen_tex if chosen_tex != null else _get_active_form_base_texture(), recalculate_collision)

func _get_slot_texture(slot_name: String) -> Texture2D:
	if wardrobe_forms.has(active_form_key):
		var form_d: Dictionary = wardrobe_forms[active_form_key]
		var sprites: Dictionary = form_d.get("sprites", {})
		if sprites.has(slot_name) and sprites[slot_name] != null:
			return sprites[slot_name] as Texture2D
	return null

func assign_pose_slot_texture(form_key: String, slot_name: String, tex: Texture2D, path: String = "") -> void:
	if not wardrobe_forms.has(form_key):
		return
	var form_d: Dictionary = wardrobe_forms[form_key]
	if not form_d.has("sprites"): form_d["sprites"] = {}
	form_d["sprites"][slot_name] = tex
	if not form_d.has("sprite_paths"): form_d["sprite_paths"] = {}
	form_d["sprite_paths"][slot_name] = path

	if form_key == active_form_key:
		_update_active_render_texture(false)

func _apply_active_texture(tex: Texture2D, recalculate_collision: bool = false) -> void:
	if not tex:
		return
	main_texture = tex
	texture_size = tex.get_size()

	# Instant cached alpha bitmap lookup
	alpha_bitmap = UGCManager.generate_alpha_bitmap(main_texture)

	if glow_sprite:
		glow_sprite.texture = main_texture
		glow_sprite.position = Vector2.ZERO

	if slice_y_ratio > 0.01:
		set_slice_ratio(slice_y_ratio)
	elif base_sprite:
		base_sprite.texture = main_texture
		base_sprite.region_enabled = false
		base_sprite.centered = true
		base_sprite.position = Vector2.ZERO

	if recalculate_collision or collision_polygons.is_empty():
		_recalculate_collision_geometry(main_texture)

func _get_active_form_base_texture() -> Texture2D:
	if wardrobe_forms.has(active_form_key):
		var t: Variant = wardrobe_forms[active_form_key].get("tex", null)
		if t is Texture2D:
			return t as Texture2D
	return main_texture

func register_animation_clip(form_key: String, clip_name: String, frames: Array[Texture2D], fps: float, paths: Array[String], mode: String = "loop") -> void:
	if not wardrobe_forms.has(form_key):
		return
	var form_d: Dictionary = wardrobe_forms[form_key]
	if not form_d.has("animations"):
		form_d["animations"] = {}

	form_d["animations"][clip_name] = {
		"fps": fps,
		"mode": mode,
		"frames": frames.duplicate(),
		"paths": paths.duplicate()
	}
	_update_process_state()

func delete_animation_clip(form_key: String, clip_name: String) -> void:
	if not wardrobe_forms.has(form_key):
		return
	var form_d: Dictionary = wardrobe_forms[form_key]
	if form_d.has("animations"):
		form_d["animations"].erase(clip_name)
		if active_clip_name == clip_name:
			stop_animation_clip()

func play_named_animation(anim_name: String) -> void:
	var clean_name: String = anim_name.strip_edges().to_lower()
	if clean_name == "":
		return

	if wardrobe_forms.has(active_form_key):
		var anims: Dictionary = wardrobe_forms[active_form_key].get("animations", {})
		if anims.has(clean_name):
			play_animation_clip(clean_name)
			return

	if clean_name in ["mouth_open", "eyes_closed", "eyes_open"]:
		set_expression(clean_name, 2.0)
	elif clean_name in ["sitting", "sleeping", "default"]:
		set_pose_state(clean_name)

func play_animation_clip(clip_name: String) -> void:
	if not wardrobe_forms.has(active_form_key):
		return
	var form_d: Dictionary = wardrobe_forms[active_form_key]
	var anims: Dictionary = form_d.get("animations", {})
	if not anims.has(clip_name):
		return

	var clip_data: Dictionary = anims[clip_name]
	active_clip_name = clip_name
	active_clip_fps = float(clip_data.get("fps", 6.0))
	active_clip_mode = str(clip_data.get("mode", "loop"))

	active_clip_frames.clear()
	for f: Variant in clip_data.get("frames", []):
		if f is Texture2D: active_clip_frames.append(f as Texture2D)

	active_clip_paths.clear()
	for p: Variant in clip_data.get("paths", []):
		active_clip_paths.append(str(p))

	clip_frame_idx = 0
	clip_playback_timer = 0.0
	_update_process_state()
	if not active_clip_frames.is_empty():
		_apply_active_texture(active_clip_frames[0], false)

func stop_animation_clip() -> void:
	active_clip_name = ""
	active_clip_frames.clear()
	active_clip_paths.clear()
	_update_process_state()
	_update_active_render_texture(false)

func _process_animation_clip(delta: float) -> void:
	if active_clip_frames.is_empty():
		return

	clip_playback_timer += delta
	var frame_dur: float = 1.0 / maxf(active_clip_fps, 1.0)
	
	if clip_playback_timer >= frame_dur:
		clip_playback_timer -= frame_dur
		clip_frame_idx += 1

		if clip_frame_idx >= active_clip_frames.size():
			if active_clip_mode == "one_shot":
				stop_animation_clip()
				return
			clip_frame_idx = 0

		if clip_frame_idx < active_clip_frames.size():
			_apply_active_texture(active_clip_frames[clip_frame_idx], false)

# SOCKET ATTACHMENT & HIERARCHY
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

	var parent_s_x: float = target_parent.scale.x if target_parent.scale.x != 0.0 else 1.0
	var parent_s_y: float = target_parent.scale.y if target_parent.scale.y != 0.0 else 1.0
	var target_scale: Vector2 = Vector2(
		(-entity_scale if is_flipped_h else entity_scale) / parent_s_x,
		entity_scale / parent_s_y
	)

	var target_rot: float = 0.0

	if target_parent.entity_type == Types.EntityType.FURNITURE:
		if socket_key.begins_with("seat"):
			set_entity_state(Types.EntityState.SITTING)
			set_pose_state("sitting")
			target_rot = 0.0
			if snap_points.has("sit_point"):
				var my_sit_pt: Vector2 = snap_points["sit_point"]
				anchor_pos.y -= my_sit_pt.y * (entity_scale / parent_s_y)
				anchor_pos.x -= (my_sit_pt.x if not is_flipped_h else -my_sit_pt.x) * (entity_scale / absf(parent_s_x))
		elif socket_key.begins_with("bed"):
			set_entity_state(Types.EntityState.SLEEPING)
			set_pose_state("sleeping")
			target_rot = -PI * 0.5
	elif target_parent.entity_type == Types.EntityType.CHARACTER:
		set_entity_state(Types.EntityState.HELD)

	position = target_parent.to_local(start_world_pos)
	rotation = target_rot
	scale = target_scale

	_kill_active_tween()
	if is_instant:
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
	set_pose_state("default")

func _would_cause_parenting_cycle(potential_parent: Node) -> bool:
	var current: Node = potential_parent
	while current != null:
		if current == self: return true
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

# CONTAINERS & CONSUMABLES
func toggle_container() -> void:
	if not is_container:
		return
	is_open = not is_open

	if is_open and container_open_texture:
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

	if custom_stages.size() > 0:
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
				var tw: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
				tw.tween_property(self, "scale", Vector2.ZERO, 0.15)
				tw.chain().tween_callback(queue_free)
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
				var tw: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
				tw.tween_property(self, "scale", Vector2.ZERO, 0.15)
				tw.chain().tween_callback(queue_free)
				return true
			else:
				var shrink_ratio: float = 1.0 - (float(current_state_idx) / float(max_bites)) * 0.7
				set_entity_scale(base_entity_scale * shrink_ratio)

	_kill_active_tween()
	var p_scale_x: float = 1.0
	var p_scale_y: float = 1.0
	if parent_socket_entity and is_instance_valid(parent_socket_entity):
		p_scale_x = parent_socket_entity.scale.x if parent_socket_entity.scale.x != 0.0 else 1.0
		p_scale_y = parent_socket_entity.scale.y if parent_socket_entity.scale.y != 0.0 else 1.0

	var target_s: Vector2 = Vector2(
		(-entity_scale if is_flipped_h else entity_scale) / p_scale_x,
		entity_scale / p_scale_y
	)

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
	_kill_active_tween()
	var p_scale_x: float = 1.0
	var p_scale_y: float = 1.0
	if parent_socket_entity and is_instance_valid(parent_socket_entity):
		p_scale_x = parent_socket_entity.scale.x if parent_socket_entity.scale.x != 0.0 else 1.0
		p_scale_y = parent_socket_entity.scale.y if parent_socket_entity.scale.y != 0.0 else 1.0

	var rest_s: Vector2 = Vector2(
		(-entity_scale if is_flipped_h else entity_scale) / p_scale_x,
		entity_scale / p_scale_y
	)
	scale = rest_s * Vector2(1.12, 0.9)
	active_tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(self, "scale", rest_s, 0.2)

func fill_with_liquid() -> void:
	fill_level = mini(fill_level + 1, 2)
	AudioManager.play_pour()

	_kill_active_tween()
	var p_scale_x: float = 1.0
	var p_scale_y: float = 1.0
	if parent_socket_entity and is_instance_valid(parent_socket_entity):
		p_scale_x = parent_socket_entity.scale.x if parent_socket_entity.scale.x != 0.0 else 1.0
		p_scale_y = parent_socket_entity.scale.y if parent_socket_entity.scale.y != 0.0 else 1.0

	var rest_s: Vector2 = Vector2(
		(-entity_scale if is_flipped_h else entity_scale) / p_scale_x,
		entity_scale / p_scale_y
	)
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
	get_parent().add_child(crumbs)

	var timer: SceneTreeTimer = get_tree().create_timer(0.5)
	timer.timeout.connect(crumbs.queue_free)

# LIGHTING & GPU OPTIMIZED SHADER
func _ensure_glow_shader() -> void:
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
		if is_instance_valid(al): al.queue_free()
	anchor_light_nodes.clear()

	if light_shape_mode == LightShapeMode.SILHOUETTE_CONTOUR:
		if not glow_sprite:
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
		if linked_light: linked_light.enabled = false

	elif light_shape_mode == LightShapeMode.RADIAL_ROOM:
		if glow_sprite: glow_sprite.visible = false
		if not linked_light:
			linked_light = AtmosphereController.create_radial_point_light(int(light_radius), light_color)
			linked_light.name = "PointLight"
			add_child(linked_light)
		linked_light.color = light_color
		linked_light.energy = light_intensity * 0.6
		var base_scale: float = (light_radius * 2.0) / 256.0
		linked_light.texture_scale = base_scale * clampf(light_radius / 100.0, 0.5, 8.0)
		linked_light.enabled = is_active

	elif light_shape_mode == LightShapeMode.ANCHOR_POINTS:
		if glow_sprite: glow_sprite.visible = false
		if linked_light: linked_light.enabled = false
		for s_key: String in snap_points.keys():
			if s_key.to_lower().begins_with("light"):
				var pt_pos: Vector2 = snap_points[s_key]
				var al: PointLight2D = AtmosphereController.create_radial_point_light(int(light_radius), light_color)
				al.position = pt_pos
				al.energy = light_intensity * 0.7
				var base_scale: float = (light_radius * 2.0) / 256.0
				al.texture_scale = base_scale * clampf(light_radius / 100.0, 0.3, 6.0)
				al.enabled = is_active
				add_child(al)
				anchor_light_nodes.append(al)

func unconfigure_light_source() -> void:
	is_light_source = false
	if glow_sprite: glow_sprite.visible = false
	if linked_light:
		linked_light.queue_free()
		linked_light = null
	for al: PointLight2D in anchor_light_nodes:
		if is_instance_valid(al): al.queue_free()
	anchor_light_nodes.clear()

# GEOMETRY & WARDROBE
func add_wardrobe_form(form_name: String, tex: Texture2D, path: String) -> void:
	wardrobe_forms[form_name] = {
		"tex": tex,
		"path": path,
		"sprites": {
			"eyes_open": tex, "eyes_closed": null, "mouth_open": null,
			"sitting": null, "sitting_eyes_closed": null, "sitting_eyes_mouth_open": null
		},
		"sprite_paths": {
			"eyes_open": path, "eyes_closed": "", "mouth_open": "",
			"sitting": "", "sitting_eyes_closed": "", "sitting_eyes_mouth_open": ""
		},
		"animations": {}
	}
	switch_wardrobe_form(form_name)

func switch_wardrobe_form(form_name: String) -> void:
	if not wardrobe_forms.has(form_name):
		return
	active_form_key = form_name
	var data: Dictionary = wardrobe_forms[form_name]
	main_texture = data.get("tex", null)
	texture_path = data.get("path", "")

	if main_texture:
		texture_size = main_texture.get_size()
		_update_active_render_texture(true)
		rebuild_gizmos()
		_kill_active_tween()
		rotation = 0.0
		var p_scale_x: float = 1.0
		var p_scale_y: float = 1.0
		if parent_socket_entity and is_instance_valid(parent_socket_entity):
			p_scale_x = parent_socket_entity.scale.x if parent_socket_entity.scale.x != 0.0 else 1.0
			p_scale_y = parent_socket_entity.scale.y if parent_socket_entity.scale.y != 0.0 else 1.0

		var rest_s: Vector2 = Vector2(
			(-entity_scale if is_flipped_h else entity_scale) / p_scale_x,
			entity_scale / p_scale_y
		)
		scale = rest_s * Vector2(1.1, 0.9)
		active_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(self, "scale", rest_s, 0.2)

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
				if pt.y > max_y: max_y = pt.y
		if max_y > -900000.0:
			return max_y
	elif collision_poly.size() >= 3:
		var max_y: float = -999999.0
		for pt: Vector2 in collision_poly:
			if pt.y > max_y: max_y = pt.y
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
				if ax > max_x: max_x = ax
		if max_x > 0.0:
			return max_x * entity_scale
	elif collision_poly.size() >= 3:
		var max_x: float = 0.0
		for pt: Vector2 in collision_poly:
			var ax: float = absf(pt.x)
			if ax > max_x: max_x = ax
		return max_x * entity_scale
	return texture_size.x * 0.5 * entity_scale

func set_entity_scale(new_scale: float) -> void:
	entity_scale = clampf(new_scale, 0.05, 4.0)
	var p_scale_x: float = 1.0
	var p_scale_y: float = 1.0
	if parent_socket_entity and is_instance_valid(parent_socket_entity):
		p_scale_x = parent_socket_entity.scale.x if parent_socket_entity.scale.x != 0.0 else 1.0
		p_scale_y = parent_socket_entity.scale.y if parent_socket_entity.scale.y != 0.0 else 1.0
	scale = Vector2(
		(-entity_scale if is_flipped_h else entity_scale) / p_scale_x,
		entity_scale / p_scale_y
	)

func flip_horizontal() -> void:
	is_flipped_h = not is_flipped_h
	_kill_active_tween()
	var p_scale_x: float = 1.0
	if parent_socket_entity and is_instance_valid(parent_socket_entity):
		p_scale_x = parent_socket_entity.scale.x if parent_socket_entity.scale.x != 0.0 else 1.0
	var target_scale_x: float = (-entity_scale if is_flipped_h else entity_scale) / p_scale_x
	active_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(self, "scale:x", target_scale_x, 0.18)
	AudioManager.play_pop_grab()

func configure_as_floor_decor(enabled: bool) -> void:
	is_floor_decor = enabled
	base_layer_band = Types.LayerBands.FLOOR_DECOR if enabled else Types.LayerBands.PLAYFIELD
	z_index = base_layer_band

func configure_as_portal(p_target_room: String, p_portal_name: String) -> void:
	is_portal = true
	is_elevator = false
	is_wall_mounted = true
	target_room_id = p_target_room
	display_name = p_portal_name if p_portal_name != "" else display_name

	var base_tex: Texture2D = _get_active_form_base_texture()
	if base_tex:
		_apply_active_texture(base_tex, true)
	else:
		main_texture = UGCManager.create_door_frame_texture(Vector2(96.0, 160.0))
		_apply_active_texture(main_texture, true)

	_ensure_door_label_node()
	update_door_visuals()

func configure_as_elevator(floors: Array[Dictionary] = [], p_name: String = "Elevator") -> void:
	is_portal = true
	is_elevator = true
	is_wall_mounted = true
	display_name = p_name if p_name != "" else display_name

	if floors.is_empty():
		elevator_floors = [
			{"label": "1F Main Room", "room_id": "room_main"},
			{"label": "2F Upper Floor", "room_id": "room_destination"}
		]
	else:
		elevator_floors = floors.duplicate(true)

	var base_tex: Texture2D = _get_active_form_base_texture()
	if base_tex:
		_apply_active_texture(base_tex, true)
	else:
		main_texture = UGCManager.create_door_frame_texture(Vector2(110.0, 170.0))
		_apply_active_texture(main_texture, true)

	_ensure_door_label_node()
	update_door_visuals()

func unconfigure_portal_and_elevator() -> void:
	is_portal = false
	is_elevator = false
	elevator_floors.clear()
	target_room_id = ""
	if door_label_node:
		door_label_node.queue_free()
		door_label_node = null
	_apply_active_texture(_get_active_form_base_texture(), true)

func _ensure_door_label_node() -> void:
	if not door_label_node:
		door_label_node = Label.new()
		door_label_node.name = "DoorLabel"
		door_label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var top_offset: float = -texture_size.y * 0.5 - 24.0
		door_label_node.position = Vector2(-75.0, top_offset)
		door_label_node.custom_minimum_size = Vector2(150.0, 24.0)
		door_label_node.add_theme_color_override("font_color", Color("#f8fafc"))

		var lbl_style: StyleBoxFlat = StyleBoxFlat.new()
		lbl_style.bg_color = Color("#0f172a", 0.9)
		lbl_style.set_corner_radius_all(6)
		lbl_style.content_margin_left = 6
		lbl_style.content_margin_right = 6
		door_label_node.add_theme_stylebox_override("normal", lbl_style)
		add_child(door_label_node)

func update_door_visuals() -> void:
	if door_label_node:
		door_label_node.text = display_name

func toggle_door() -> void:
	is_door_open = not is_door_open
	AudioManager.play_pop_grab()
	_kill_active_tween()
	active_tween = create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	var rest_s: Vector2 = Vector2(-entity_scale if is_flipped_h else entity_scale, entity_scale)
	if is_door_open:
		active_tween.tween_property(self, "modulate", Color(1.3, 1.3, 1.3, 0.85), 0.15)
		active_tween.parallel().tween_property(self, "scale", rest_s * Vector2(0.9, 1.05), 0.15)
	else:
		active_tween.tween_property(self, "modulate", Color.WHITE, 0.15)
		active_tween.parallel().tween_property(self, "scale", rest_s, 0.15)

func open_door_instant() -> void:
	is_door_open = true
	modulate = Color(1.2, 1.2, 1.2, 0.9)

func close_door_animated(callback: Callable = Callable()) -> void:
	is_door_open = false
	_kill_active_tween()
	active_tween = create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	var rest_s: Vector2 = Vector2(-entity_scale if is_flipped_h else entity_scale, entity_scale)
	active_tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	active_tween.parallel().tween_property(self, "scale", rest_s, 0.2)
	if callback.is_valid():
		active_tween.chain().tween_callback(callback)

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

func configure_as_liquid_source() -> void:
	is_liquid_source = true
	interaction_points["faucet_stream"] = {
		"offset": Vector2(0.0, texture_size.y * 0.35),
		"radius": 45.0,
		"type": int(Types.InteractionPointType.LIQUID_STREAM)
	}
	if not linked_particles:
		linked_particles = CPUParticles2D.new()
		linked_particles.name = "WaterStream"
		linked_particles.position = interaction_points["faucet_stream"]["offset"]
		linked_particles.emitting = false
		linked_particles.amount = 24
		linked_particles.lifetime = 0.4
		linked_particles.gravity = Vector2(0.0, 250.0)
		linked_particles.initial_velocity_min = 30.0
		linked_particles.initial_velocity_max = 50.0
		linked_particles.scale_amount_min = 2.0
		linked_particles.scale_amount_max = 3.5
		linked_particles.color = Color("#38bdf8")
		add_child(linked_particles)
	rebuild_gizmos()

func unconfigure_liquid_source() -> void:
	is_liquid_source = false
	if linked_particles:
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
	if is_liquid_source and linked_particles:
		linked_particles.emitting = is_active
		if is_active: AudioManager.play_pour()
	elif is_light_source:
		_apply_current_lighting_state()
		AudioManager.play_snap_chime()

	_kill_active_tween()
	var p_scale_x: float = 1.0
	var p_scale_y: float = 1.0
	if parent_socket_entity and is_instance_valid(parent_socket_entity):
		p_scale_x = parent_socket_entity.scale.x if parent_socket_entity.scale.x != 0.0 else 1.0
		p_scale_y = parent_socket_entity.scale.y if parent_socket_entity.scale.y != 0.0 else 1.0

	var rest_s: Vector2 = Vector2(
		(-entity_scale if is_flipped_h else entity_scale) / p_scale_x,
		entity_scale / p_scale_y
	)
	scale = rest_s * Vector2(1.08, 0.92)
	active_tween = create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(self, "scale", rest_s, 0.15)

func on_grab() -> void:
	set_entity_state(Types.EntityState.DRAGGING)
	z_as_relative = false
	z_index = Types.LayerBands.DRAGGING
	rotation = 0.0
	_kill_active_tween()
	active_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var rest_s: Vector2 = Vector2(-entity_scale if is_flipped_h else entity_scale, entity_scale)
	active_tween.tween_property(self, "scale", rest_s * 1.05, 0.08)

func on_drop() -> void:
	set_entity_state(Types.EntityState.IDLE)
	z_as_relative = false
	z_index = base_layer_band
	rotation = 0.0

	if parent_socket_entity == null and active_clip_name == "" and entity_type == Types.EntityType.CHARACTER:
		if current_pose_state in ["sitting", "sleeping"]:
			current_pose_state = "default"
			_update_active_render_texture(false)

	_kill_active_tween()
	active_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var rest_s: Vector2 = Vector2(-entity_scale if is_flipped_h else entity_scale, entity_scale)
	active_tween.tween_property(self, "scale", rest_s * Vector2(1.06, 0.94), 0.07)
	active_tween.tween_property(self, "scale", rest_s, 0.12)

func trigger_spawn_juice() -> void:
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

func contains_point(world_p: Vector2, touch_padding: float = 0.0) -> bool:
	var local_p: Vector2 = to_local(world_p)
	var scale_mag: float = absf(entity_scale) if entity_scale != 0.0 else 1.0
	var scaled_padding: float = touch_padding / scale_mag

	# 1. FAST EARLY EXIT: Bounding box check in O(1)
	if texture_size.x > 0.0 and texture_size.y > 0.0:
		var half_box: Vector2 = (texture_size * 0.5) + Vector2(scaled_padding + 8.0, scaled_padding + 8.0)
		if not Rect2(-half_box, half_box * 2.0).has_point(local_p):
			return false

	# 2. O(1) DIRECT BITMAP LOOKUP (Mapped accurately to texture space)
	if alpha_bitmap != null and texture_size.x > 0.0 and texture_size.y > 0.0:
		var bm_size: Vector2i = alpha_bitmap.get_size()
		if bm_size.x > 0 and bm_size.y > 0:
			var norm_x: float = (local_p.x + (texture_size.x * 0.5)) / texture_size.x
			var norm_y: float = (local_p.y + (texture_size.y * 0.5)) / texture_size.y
			
			var px: int = int(norm_x * bm_size.x)
			var py: int = int(norm_y * bm_size.y)

			if px >= 0 and px < bm_size.x and py >= 0 and py < bm_size.y:
				if alpha_bitmap.get_bit(px, py):
					return true

	# 3. FAST POLYGON CHECK
	if not collision_polygons.is_empty():
		for poly: PackedVector2Array in collision_polygons:
			if poly.size() >= 3 and Geometry2D.is_point_in_polygon(local_p, poly):
				return true
	elif collision_poly.size() >= 3:
		if Geometry2D.is_point_in_polygon(local_p, collision_poly):
			return true

	# 4. Fallback for touch padding around bounds
	if scaled_padding > 0.0 and texture_size.x > 0.0 and texture_size.y > 0.0:
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
	speech_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	speech_bubble_node.scale = Vector2(0.2, 0.2)
	speech_tween.tween_property(speech_bubble_node, "scale", Vector2.ONE, 0.2)
	speech_tween.chain().tween_interval(3.5)
	speech_tween.chain().tween_property(speech_bubble_node, "scale", Vector2.ZERO, 0.15)
	speech_tween.chain().tween_callback(func() -> void: speech_bubble_node.visible = false)

func spray_emotion(symbol_char: String) -> void:
	if symbol_char == "":
		return
	var lbl: Label = Label.new()
	lbl.text = symbol_char
	lbl.position = Vector2(0.0, -texture_size.y * 0.5)
	lbl.z_index = 680
	add_child(lbl)

	var tw: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position:y", -texture_size.y * 0.5 - 60.0, 0.8)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(lbl.queue_free)

func get_full_hierarchy_bundle() -> Array[Dictionary]:
	var bundle: Array[Dictionary] = [to_dict()]
	for child: OwnEntity in attached_children:
		if is_instance_valid(child):
			bundle.append_array(child.get_full_hierarchy_bundle())
	return bundle

# PROFILE & CUSTOM FIELDS
func get_profile_field(field_key: String, default_val: String = "") -> String:
	return str(custom_fields.get(field_key, default_val))

func set_profile_field(field_key: String, val: String) -> void:
	custom_fields[field_key] = val

func get_traits() -> Dictionary:
	var traits_data: Variant = custom_fields.get("traits", {})
	return (traits_data as Dictionary).duplicate(true) if traits_data is Dictionary else {}

func set_trait(trait_name: String, val: String) -> void:
	if not custom_fields.has("traits") or not (custom_fields["traits"] is Dictionary):
		custom_fields["traits"] = {}
	custom_fields["traits"][trait_name] = val

func get_family_ties() -> Array[Dictionary]:
	var raw_ties: Variant = custom_fields.get("family_ties", [])
	var list: Array[Dictionary] = []
	if raw_ties is Array:
		for b: Variant in (raw_ties as Array):
			if b is Dictionary: list.append((b as Dictionary).duplicate(true))
	return list

func set_family_ties(ties: Array[Dictionary]) -> void:
	custom_fields["family_ties"] = ties.duplicate(true)

func get_relationships() -> Array[Dictionary]:
	var raw_bonds: Variant = custom_fields.get("relationships", [])
	var list: Array[Dictionary] = []
	if raw_bonds is Array:
		for b: Variant in (raw_bonds as Array):
			if b is Dictionary: list.append((b as Dictionary).duplicate(true))
	return list

func set_relationships(bonds: Array[Dictionary]) -> void:
	custom_fields["relationships"] = bonds.duplicate(true)

# SERIALIZATION
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

	var forms_dict: Dictionary = {}
	for fk: String in wardrobe_forms.keys():
		var form_d: Dictionary = wardrobe_forms[fk]
		var raw_paths: Dictionary = form_d.get("sprite_paths", {})
		var sprites_save: Dictionary = {}
		for s_key: String in ["eyes_open", "eyes_closed", "mouth_open", "sitting", "sitting_eyes_closed", "sitting_eyes_mouth_open"]:
			sprites_save[s_key] = raw_paths.get(s_key, "")

		var anims_save: Dictionary = {}
		var raw_anims: Dictionary = form_d.get("animations", {})
		for c_name: String in raw_anims.keys():
			var clip_data: Dictionary = raw_anims[c_name]
			anims_save[c_name] = {
				"fps": float(clip_data.get("fps", 6.0)),
				"mode": str(clip_data.get("mode", "loop")),
				"paths": (clip_data.get("paths", []) as Array).duplicate()
			}

		forms_dict[fk] = {
			"path": form_d.get("path", ""),
			"sprite_paths": sprites_save,
			"animations": anims_save
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
		"layer_band": base_layer_band,
		"slice_y_ratio": slice_y_ratio,
		"active_form_key": active_form_key,
		"current_pose_state": current_pose_state,
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
		"target_room_id": target_room_id,
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
	display_name = d.get("display_name", entity_id)
	entity_type = int(d.get("entity_type", Types.EntityType.PROP)) as Types.EntityType
	_setup_collision_layers()

	is_floor_decor = bool(d.get("is_floor_decor", false))
	base_layer_band = Types.LayerBands.FLOOR_DECOR if is_floor_decor else Types.LayerBands.PLAYFIELD
	z_index = base_layer_band
	z_as_relative = false

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
	light_shape_mode = int(d.get("light_shape_mode", LightShapeMode.SILHOUETTE_CONTOUR))
	light_color = Color(str(d.get("light_color", "#ffe080")))
	light_intensity = float(d.get("light_intensity", 2.0))
	light_radius = float(d.get("light_radius", 160.0))
	light_pulse_speed = float(d.get("light_pulse_speed", 2.0))

	is_portal = bool(d.get("is_portal", false))
	target_room_id = str(d.get("target_room_id", ""))
	is_elevator = bool(d.get("is_elevator", false))

	elevator_floors.clear()
	var raw_floors: Array = d.get("elevator_floors", [])
	for f_obj: Variant in raw_floors:
		if f_obj is Dictionary:
			elevator_floors.append((f_obj as Dictionary).duplicate(true))

	is_active = bool(d.get("is_active", false))
	is_container = bool(d.get("is_container", false))
	is_open = bool(d.get("is_open", false))
	container_open_path = str(d.get("container_open_path", ""))
	if container_open_path != "" and FileAccess.file_exists(container_open_path):
		container_open_texture = UGCManager.load_texture_from_file(container_open_path)

	custom_fields = d.get("custom_fields", {}).duplicate(true)
	if entity_type == Types.EntityType.CHARACTER:
		_initialize_character_profile_defaults()

	wardrobe_forms.clear()
	var raw_forms: Dictionary = d.get("wardrobe_forms", {})
	for f_key: String in raw_forms.keys():
		var f_val: Variant = raw_forms[f_key]
		var f_path: String = ""
		var f_sprite_paths: Dictionary = {}
		var f_sprites: Dictionary = {}
		var f_anims: Dictionary = {}

		if f_val is Dictionary:
			var f_dict: Dictionary = f_val as Dictionary
			f_path = str(f_dict.get("path", ""))
			f_sprite_paths = f_dict.get("sprite_paths", {})
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
				f_anims[c_name] = {
					"fps": float(c_info.get("fps", 6.0)),
					"mode": str(c_info.get("mode", "loop")),
					"paths": valid_paths,
					"frames": loaded_frames
				}
		else:
			f_path = str(f_val)

		var form_base_tex: Texture2D = null
		if f_path != "" and FileAccess.file_exists(f_path):
			form_base_tex = UGCManager.load_texture_from_file(f_path)
		else:
			form_base_tex = main_texture

		for s_key: String in ["eyes_open", "eyes_closed", "mouth_open", "sitting", "sitting_eyes_closed", "sitting_eyes_mouth_open"]:
			var p: String = str(f_sprite_paths.get(s_key, ""))
			if p != "" and FileAccess.file_exists(p):
				f_sprites[s_key] = UGCManager.load_texture_from_file(p)
			elif s_key == "eyes_open":
				f_sprites[s_key] = form_base_tex
			else:
				f_sprites[s_key] = null

		wardrobe_forms[f_key] = {
			"tex": form_base_tex, "path": f_path,
			"sprites": f_sprites, "sprite_paths": f_sprite_paths,
			"animations": f_anims
		}

	active_form_key = str(d.get("active_form_key", "Default"))
	current_pose_state = str(d.get("current_pose_state", "default"))
	_update_active_render_texture(true)

	stored_item_data.clear()
	var raw_stored: Array = d.get("stored_item_data", [])
	for s_item: Variant in raw_stored:
		if s_item is Dictionary:
			stored_item_data.append((s_item as Dictionary).duplicate(true))

	configure_as_floor_decor(is_floor_decor)
	set_slice_ratio(slice_y_ratio)
	set_entity_scale(entity_scale)

	if is_elevator: configure_as_elevator(elevator_floors, display_name)
	elif is_portal: configure_as_portal(target_room_id, display_name)

	if is_liquid_source:
		configure_as_liquid_source()
		if is_active and linked_particles: linked_particles.emitting = true

	if is_light_source: _apply_current_lighting_state()

	logic_rules.clear()
	var raw_rules: Array = d.get("logic_rules", [])
	for r: Variant in raw_rules:
		if r is Dictionary: logic_rules.append((r as Dictionary).duplicate(true))

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

	var components_dict: Dictionary = d.get("components", {})
	for c_key: StringName in components.keys():
		if components.has(StringName(c_key)):
			var comp: EntityComponent = components[StringName(c_key)]
			comp.deserialize(components_dict[c_key])

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

		if anchor_name != "":
			var font: Font = ThemeDB.fallback_font
			var lbl_str: String = anchor_name
			var font_sz: int = 10
			var text_w: float = font.get_string_size(lbl_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz).x
			var bg_rect: Rect2 = Rect2(Vector2(-text_w * 0.5 - 4.0, radius + 4.0), Vector2(text_w + 8.0, 14.0))
			draw_rect(bg_rect, Color("#000000", 0.85), true)
			draw_rect(bg_rect, marker_color, false, 1.0)
			draw_string(font, Vector2(-text_w * 0.5, radius + 15.0), lbl_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz, Color.WHITE)
