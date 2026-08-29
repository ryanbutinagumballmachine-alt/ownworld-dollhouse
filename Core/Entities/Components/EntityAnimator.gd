# ==============================================================================
# OWNWORLD — ENTITY ANIMATOR COMPONENT
# File: res://Core/Entities/Components/EntityAnimator.gd
# Base Class: Node
#
# Responsibility: Handles all multi-frame state animation, GIF playback,
# natural blinking logic, and transient expression decay.
# ==============================================================================

class_name EntityAnimator
extends Node

var entity: OwnEntity = null

var active_frames: Array[Texture2D] = []
var active_fps: float = 6.0
var active_playback_mode: int = Types.PlaybackMode.LOOP

var state_frame_idx: int = 0
var state_playback_timer: float = 0.0
var ping_pong_forward: bool = true

var blink_cycle_timer: float = 3.5
var is_in_blink_phase: bool = false
var expression_timer: float = 0.0

func setup(parent_entity: OwnEntity) -> void:
	entity = parent_entity
	blink_cycle_timer = randf_range(2.5, 5.0)
	set_process(false)

func load_state(state_data: Dictionary, base_texture: Texture2D) -> void:
	active_frames.clear()
	state_frame_idx = 0
	state_playback_timer = 0.0
	ping_pong_forward = true
	is_in_blink_phase = false
	blink_cycle_timer = randf_range(2.5, 5.0)

	if not state_data.is_empty():
		for f: Variant in state_data.get("frames", []):
			if f is Texture2D: 
				active_frames.append(f as Texture2D)
		active_fps = float(state_data.get("fps", 6.0))
		active_playback_mode = int(state_data.get("mode", Types.PlaybackMode.LOOP))
	else:
		active_fps = 6.0
		active_playback_mode = Types.PlaybackMode.LOOP
		if base_texture != null:
			active_frames.append(base_texture)

	if not active_frames.is_empty():
		entity._apply_active_texture(active_frames[0], false)

	_update_process_state()

func set_expression_timer(duration: float) -> void:
	expression_timer = duration
	_update_process_state()

func force_trigger_blink() -> void:
	if active_playback_mode == Types.PlaybackMode.NATURAL_BLINK and active_frames.size() > 1:
		is_in_blink_phase = true
		state_frame_idx = 1
		state_playback_timer = 0.0
		entity._apply_active_texture(active_frames[state_frame_idx], false)
	else:
		entity.set_actor_state("blink", 0.5)

func _update_process_state() -> void:
	var is_animated: bool = (not active_frames.is_empty() and active_frames.size() > 1)
	var has_expression: bool = (expression_timer > 0.0)
	set_process(is_animated or has_expression)

func _process(delta: float) -> void:
	if expression_timer > 0.0:
		expression_timer -= delta
		if expression_timer <= 0.0:
			entity.reset_to_default_pose()

	if active_frames.size() > 1:
		_process_animation(delta)

func _process_animation(delta: float) -> void:
	if active_playback_mode == Types.PlaybackMode.NATURAL_BLINK:
		if not is_in_blink_phase:
			blink_cycle_timer -= delta
			if blink_cycle_timer <= 0.0:
				is_in_blink_phase = true
				state_frame_idx = 1
				state_playback_timer = 0.0
				entity._apply_active_texture(active_frames[state_frame_idx], false)
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
				entity._apply_active_texture(active_frames[state_frame_idx], false)
		return

	state_playback_timer += delta
	var frame_dur: float = 1.0 / maxf(active_fps, 1.0)

	if state_playback_timer >= frame_dur:
		state_playback_timer -= frame_dur

		match active_playback_mode:
			int(Types.PlaybackMode.LOOP):
				state_frame_idx = (state_frame_idx + 1) % active_frames.size()
				entity._apply_active_texture(active_frames[state_frame_idx], false)

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
				entity._apply_active_texture(active_frames[state_frame_idx], false)

			int(Types.PlaybackMode.ONE_SHOT):
				state_frame_idx += 1
				if state_frame_idx >= active_frames.size():
					entity.reset_to_default_pose()
					return
				entity._apply_active_texture(active_frames[state_frame_idx], false)

			int(Types.PlaybackMode.ONE_SHOT_HOLD):
				if state_frame_idx < active_frames.size() - 1:
					state_frame_idx += 1
					entity._apply_active_texture(active_frames[state_frame_idx], false)
