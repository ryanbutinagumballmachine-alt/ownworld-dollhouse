# ==============================================================================
# OWNWORLD — ENTITY MOTION FX COMPONENT
# File: res://Core/Entities/Components/EntityMotionFX.gd
# Base Class: Node
#
# Responsibility: Handles procedural idle breathing, float hovering, drag/drop
# tweens, and squash/stretch juice. Integrates directly with SettingsManager.
# ==============================================================================

class_name EntityMotionFX
extends Node

var entity: OwnEntity = null
var active_tween: Tween = null
var idle_motion_timer: float = 0.0


func setup(parent_entity: OwnEntity) -> void:
	entity = parent_entity
	_update_process_state()


func _update_process_state() -> void:
	if not is_instance_valid(entity):
		set_process(false)
		return
	var has_idle_juice: bool = (entity.entity_type == Types.EntityType.CHARACTER or entity.can_float) and SettingsManager.is_juice_idle_motion_enabled()
	set_process(has_idle_juice)


func _process(delta: float) -> void:
	if not is_instance_valid(entity):
		set_process(false)
		return

	if not SettingsManager.is_juice_idle_motion_enabled() or entity.parent_socket_entity != null or entity.state == Types.EntityState.DRAGGING:
		return

	idle_motion_timer += delta * 2.4
	var intensity: float = SettingsManager.get_juice_idle_intensity()
	if intensity <= 0.01:
		return

	if entity.can_float:
		var hover_offset: float = sin(idle_motion_timer * 1.2) * (4.0 * intensity)
		if is_instance_valid(entity.base_sprite):
			entity.base_sprite.position.y = hover_offset
		if is_instance_valid(entity.overlay_sprite) and entity.overlay_sprite.visible:
			entity.overlay_sprite.position.y = -entity.texture_size.y * 0.5 + hover_offset
	elif entity.entity_type == Types.EntityType.CHARACTER and entity.active_state_name == Types.STATE_IDLE:
		var breath: float = 1.0 + sin(idle_motion_timer) * (0.022 * intensity)
		if is_instance_valid(entity.base_sprite):
			entity.base_sprite.scale = Vector2(1.0, breath)
		if is_instance_valid(entity.overlay_sprite) and entity.overlay_sprite.visible:
			entity.overlay_sprite.scale = Vector2(1.0, breath)


func get_target_scale() -> Vector2:
	if not is_instance_valid(entity):
		return Vector2.ONE
	var p_scale_x: float = 1.0
	var p_scale_y: float = 1.0
	if is_instance_valid(entity.parent_socket_entity):
		p_scale_x = entity.parent_socket_entity.scale.x if not is_zero_approx(entity.parent_socket_entity.scale.x) else 1.0
		p_scale_y = entity.parent_socket_entity.scale.y if not is_zero_approx(entity.parent_socket_entity.scale.y) else 1.0
	return Vector2((-entity.entity_scale if entity.is_flipped_h else entity.entity_scale) / p_scale_x, entity.entity_scale / p_scale_y)


func kill_tween() -> void:
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	active_tween = null


func on_grab() -> void:
	if not SettingsManager.is_juice_squash_stretch_enabled() or not is_instance_valid(entity):
		return
	kill_tween()
	active_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(entity, "scale", get_target_scale() * 1.05, 0.08)


func on_drop() -> void:
	if not SettingsManager.is_juice_squash_stretch_enabled() or not is_instance_valid(entity):
		return
	kill_tween()
	active_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var rest_s: Vector2 = get_target_scale()
	active_tween.tween_property(entity, "scale", rest_s * Vector2(1.06, 0.94), 0.07)
	active_tween.tween_property(entity, "scale", rest_s, 0.12)


func play_spawn_juice() -> void:
	if not SettingsManager.is_juice_spawn_springs_enabled() or not is_instance_valid(entity):
		return
	kill_tween()
	var rest_s: Vector2 = get_target_scale()
	entity.scale = rest_s * Vector2(0.85, 1.15)
	active_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(entity, "scale", rest_s, 0.22)


func play_squash_stretch(scale_mult: Vector2, duration: float, trans: Tween.TransitionType = Tween.TRANS_SPRING) -> void:
	if not SettingsManager.is_juice_squash_stretch_enabled() or not is_instance_valid(entity):
		return
	kill_tween()
	var rest_s: Vector2 = get_target_scale()
	entity.scale = rest_s * scale_mult
	active_tween = create_tween().set_trans(trans).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(entity, "scale", rest_s, duration)


func play_door_toggle(is_open: bool) -> void:
	if not is_instance_valid(entity):
		return
	kill_tween()
	var rest_s: Vector2 = get_target_scale()
	if SettingsManager.is_juice_squash_stretch_enabled():
		active_tween = create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		if is_open:
			active_tween.tween_property(entity, "modulate", Color(1.3, 1.3, 1.3, 0.85), 0.15)
			active_tween.parallel().tween_property(entity, "scale", rest_s * Vector2(0.9, 1.05), 0.15)
		else:
			active_tween.tween_property(entity, "modulate", Color.WHITE, 0.15)
			active_tween.parallel().tween_property(entity, "scale", rest_s, 0.15)
	else:
		entity.modulate = Color(1.3, 1.3, 1.3, 0.85) if is_open else Color.WHITE


func play_door_close_animated(callback: Callable) -> void:
	if not is_instance_valid(entity):
		if callback.is_valid(): callback.call()
		return
	kill_tween()
	var rest_s: Vector2 = get_target_scale()
	if SettingsManager.is_juice_squash_stretch_enabled():
		active_tween = create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(entity, "modulate", Color.WHITE, 0.2)
		active_tween.parallel().tween_property(entity, "scale", rest_s, 0.2)
		if callback.is_valid(): 
			active_tween.chain().tween_callback(callback)
	else:
		entity.modulate = Color.WHITE
		entity.scale = rest_s
		if callback.is_valid(): 
			callback.call()


func play_socket_attach(anchor_pos: Vector2, child_scale: Vector2, is_seat: bool) -> void:
	if not is_instance_valid(entity):
		return
	kill_tween()
	if not SettingsManager.is_juice_squash_stretch_enabled():
		entity.position = anchor_pos
		return

	active_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(entity, "position", anchor_pos, 0.28)

	if is_seat:
		active_tween.chain().tween_property(entity, "scale", child_scale * Vector2(1.05, 0.95), 0.08).set_trans(Tween.TRANS_SINE)
		active_tween.chain().tween_property(entity, "scale", child_scale, 0.12).set_trans(Tween.TRANS_SINE)


func play_flip() -> void:
	if not is_instance_valid(entity):
		return
	kill_tween()
	var target_scale_x: float = get_target_scale().x
	if SettingsManager.is_juice_squash_stretch_enabled():
		active_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(entity, "scale:x", target_scale_x, 0.18)
	else:
		entity.scale.x = target_scale_x


func play_shrink_destroy() -> void:
	if not is_instance_valid(entity):
		return
	if SettingsManager.is_juice_squash_stretch_enabled():
		kill_tween()
		active_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		active_tween.tween_property(entity, "scale", Vector2.ZERO, 0.15)
		active_tween.chain().tween_callback(entity.queue_free)
	else:
		entity.queue_free()
