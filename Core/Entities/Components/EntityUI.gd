# ==============================================================================
# OWNWORLD — ENTITY UI COMPONENT
# File: res://Core/Entities/Components/EntityUI.gd
# Base Class: Node2D
#
# Responsibility: Manages speech bubbles, floating emote sprays, and their
# associated tweens, keeping the main entity script clean.
# ==============================================================================

class_name EntityUI
extends Node2D

var entity: OwnEntity = null

var speech_bubble_node: PanelContainer = null
var speech_label: Label = null
var speech_tween: Tween = null


func setup(parent_entity: OwnEntity) -> void:
	entity = parent_entity
	z_index = 650
	_build_speech_bubble()


func _build_speech_bubble() -> void:
	speech_bubble_node = PanelContainer.new()
	speech_bubble_node.name = "SpeechBubble"
	speech_bubble_node.visible = false

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
	if not is_instance_valid(speech_bubble_node) or not is_instance_valid(speech_label) or not is_instance_valid(entity): 
		return
	speech_label.text = text_to_say
	speech_bubble_node.visible = true
	speech_bubble_node.position = Vector2(-speech_bubble_node.size.x * 0.5, -entity.texture_size.y * 0.65 - 40.0)

	if speech_tween != null and speech_tween.is_valid():
		speech_tween.kill()

	if SettingsManager.is_juice_squash_stretch_enabled():
		speech_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		speech_bubble_node.scale = Vector2(0.2, 0.2)
		speech_tween.tween_property(speech_bubble_node, "scale", Vector2.ONE, 0.2)
		speech_tween.chain().tween_interval(3.5)
		speech_tween.chain().tween_property(speech_bubble_node, "scale", Vector2.ZERO, 0.15)
		speech_tween.chain().tween_callback(func() -> void:
			if is_instance_valid(speech_bubble_node):
				speech_bubble_node.visible = false
		)
	else:
		speech_bubble_node.scale = Vector2.ONE
		var timer: SceneTreeTimer = get_tree().create_timer(3.5)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(speech_bubble_node):
				speech_bubble_node.visible = false
		)


func spray_emotion(symbol_char: String) -> void:
	if symbol_char.is_empty() or not is_instance_valid(entity): 
		return
	var lbl: Label = Label.new()
	lbl.text = symbol_char
	lbl.position = Vector2(0.0, -entity.texture_size.y * 0.5)
	lbl.z_index = 680
	add_child(lbl)

	if SettingsManager.is_juice_squash_stretch_enabled():
		var tw: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(lbl, "position:y", -entity.texture_size.y * 0.5 - 60.0, 0.8)
		tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
		tw.chain().tween_callback(lbl.queue_free)
	else:
		var timer: SceneTreeTimer = get_tree().create_timer(0.8)
		timer.timeout.connect(lbl.queue_free)
