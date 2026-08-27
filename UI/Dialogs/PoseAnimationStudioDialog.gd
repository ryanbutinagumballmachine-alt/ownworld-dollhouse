# ==============================================================================
# OWNWORLD — POSE & ANIMATION STUDIO
# File: res://UI/Dialogs/PoseAnimationStudioDialog.gd
# Base Class: CanvasLayer (class_name PoseAnimationStudioDialog)
#
# Responsibility: 6-pose whole-sprite matrix studio and frame-by-frame animation
# loop editor. Configures outfit variations, expressive slots, and custom frame rates.
# ==============================================================================

class_name PoseAnimationStudioDialog
extends CanvasLayer

const MAX_PANEL_WIDTH: float = 580.0
const MAX_PANEL_HEIGHT: float = 580.0

var root_backdrop: Control = null
var center_container: CenterContainer = null
var root_panel: PanelContainer = null
var active_entity: OwnEntity = null
var asset_picker: AssetPickerDialog = null

var header_lbl: Label = null
var outfit_strip_lbl: Label = null
var forms_hbox_container: HBoxContainer = null
var form_name_input: LineEdit = null
var selected_form_tex: Texture2D = null
var selected_form_path: String = ""
var btn_choose_form_art: Button = null
var btn_add_form: Button = null

var tab_container: TabContainer = null
var pose_slots_vbox: VBoxContainer = null
var pose_hint_lbl: Label = null

var p_box: PanelContainer = null
var anim_preview_rect: TextureRect = null
var fps_slider: HSlider = null
var lbl_fps: Label = null
var fps_val_lbl: Label = null
var clip_name_edit: LineEdit = null
var opt_playback_mode: OptionButton = null
var saved_clips_container: HBoxContainer = null
var frames_list_vbox: VBoxContainer = null
var btn_browse_frame: Button = null
var btn_save_clip: Button = null

var selected_clip_frames: Array[Texture2D] = []
var selected_clip_paths: Array[String] = []
var preview_frame_idx: int = 0
var preview_timer: float = 0.0
var target_fps: float = 6.0
var current_loaded_clip_name: String = ""

const POSE_SLOTS: Array[Dictionary] = [
	{"key": "eyes_open", "label": "Eyes Open (Base Standing)"},
	{"key": "eyes_closed", "label": "Eyes Closed (Blink / Sleep)"},
	{"key": "mouth_open", "label": "Mouth Open (Talk / Eat)"},
	{"key": "sitting", "label": "Sitting (Eyes Open)"},
	{"key": "sitting_eyes_closed", "label": "Sitting (Eyes Closed)"},
	{"key": "sitting_eyes_mouth_open", "label": "Sitting (Eyes & Mouth Open)"}
]


func _ready() -> void:
	name = "PoseAnimationStudioDialog"
	layer = 120
	visible = false
	add_to_group("modal_ui")
	_build_ui()
	_connect_system_signals()
	_update_responsive_layout()

	asset_picker = AssetPickerDialog.new()
	add_child(asset_picker)


func _connect_system_signals() -> void:
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null and not tree.root.size_changed.is_connected(_update_responsive_layout):
		tree.root.size_changed.connect(_update_responsive_layout)
	if not EventBus.theme_changed.is_connected(_on_theme_changed):
		EventBus.theme_changed.connect(_on_theme_changed)


func _on_theme_changed(_theme_data: Dictionary) -> void:
	_render_forms_bar()
	_render_pose_slots()
	_load_active_outfit_clips()
	_render_frames_list()


func _update_responsive_layout() -> void:
	if not is_instance_valid(root_panel): return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280.0, 720.0)
	var target_width: float = clampf(viewport_size.x * 0.92, 290.0, MAX_PANEL_WIDTH)
	var target_height: float = clampf(viewport_size.y * 0.90, 330.0, MAX_PANEL_HEIGHT)
	root_panel.custom_minimum_size = Vector2(target_width, target_height)
	root_panel.size = Vector2(target_width, target_height)


func _process(delta: float) -> void:
	if not visible or selected_clip_frames.is_empty():
		return

	preview_timer += delta
	var frame_duration: float = 1.0 / maxf(target_fps, 1.0)
	if preview_timer >= frame_duration:
		preview_timer = 0.0
		preview_frame_idx = (preview_frame_idx + 1) % selected_clip_frames.size()
		if anim_preview_rect != null and preview_frame_idx < selected_clip_frames.size():
			anim_preview_rect.texture = selected_clip_frames[preview_frame_idx]


func _build_ui() -> void:
	root_backdrop = Control.new()
	root_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root_backdrop.gui_input.connect(_on_backdrop_gui_input)
	add_child(root_backdrop)

	var background_dim: ColorRect = ColorRect.new()
	background_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	background_dim.color = Color(0.0, 0.0, 0.0, 0.65)
	background_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_backdrop.add_child(background_dim)

	center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_PASS
	root_backdrop.add_child(center_container)

	root_panel = PanelContainer.new()
	root_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center_container.add_child(root_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	root_panel.add_child(vbox)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	vbox.add_child(header_hbox)

	header_lbl = Label.new()
	header_lbl.text = "States & Animation Studio"
	header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_lbl.theme_type_variation = "HeaderLabel"
	header_hbox.add_child(header_lbl)

	var close_button: Button = Button.new()
	close_button.custom_minimum_size = Vector2(24.0, 24.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_constant_override("icon_max_width", 12)
	_apply_close_icon(close_button)
	close_button.pressed.connect(close_studio)
	header_hbox.add_child(close_button)

	vbox.add_child(HSeparator.new())

	outfit_strip_lbl = Label.new()
	outfit_strip_lbl.text = "State Variations & Outfits (Tap to Switch):"
	outfit_strip_lbl.theme_type_variation = "HintLabel"
	vbox.add_child(outfit_strip_lbl)

	var forms_scroll: ScrollContainer = ScrollContainer.new()
	forms_scroll.custom_minimum_size = Vector2(0.0, 36.0)
	forms_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	forms_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	forms_scroll.follow_focus = false
	vbox.add_child(forms_scroll)

	forms_hbox_container = HBoxContainer.new()
	forms_hbox_container.add_theme_constant_override("separation", 6)
	forms_scroll.add_child(forms_hbox_container)

	var add_form_row: HBoxContainer = HBoxContainer.new()
	add_form_row.add_theme_constant_override("separation", 6)
	vbox.add_child(add_form_row)

	form_name_input = LineEdit.new()
	form_name_input.placeholder_text = "New State Name (e.g. Armor)..."
	form_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_form_row.add_child(form_name_input)

	btn_choose_form_art = Button.new()
	btn_choose_form_art.text = " Pick Art..."
	btn_choose_form_art.custom_minimum_size = Vector2(95.0, 32.0)
	btn_choose_form_art.focus_mode = Control.FOCUS_NONE
	btn_choose_form_art.add_theme_constant_override("icon_max_width", 14)
	_apply_button_icon(btn_choose_form_art, "icon_folder")
	btn_choose_form_art.pressed.connect(_on_pick_form_art_pressed)
	add_form_row.add_child(btn_choose_form_art)

	btn_add_form = Button.new()
	btn_add_form.text = " Add"
	btn_add_form.custom_minimum_size = Vector2(75.0, 32.0)
	btn_add_form.focus_mode = Control.FOCUS_NONE
	btn_add_form.add_theme_constant_override("icon_max_width", 14)
	var state_icon: Texture2D = ThemeService.get_icon("icon_plus")
	if state_icon == null: state_icon = ThemeService.get_icon("icon_states")
	if state_icon != null: btn_add_form.icon = state_icon
	btn_add_form.pressed.connect(_on_add_outfit_form_pressed)
	add_form_row.add_child(btn_add_form)

	vbox.add_child(HSeparator.new())

	tab_container = TabContainer.new()
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tab_container)

	_build_poses_tab()
	_build_animations_tab()


func _build_poses_tab() -> void:
	var poses_tab_vbox: VBoxContainer = VBoxContainer.new()
	poses_tab_vbox.name = "Poses & Expressions"
	poses_tab_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	poses_tab_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	poses_tab_vbox.add_theme_constant_override("separation", 6)
	tab_container.add_child(poses_tab_vbox)

	pose_hint_lbl = Label.new()
	pose_hint_lbl.text = "Assign drawings for expressive poses. Skipped slots automatically use the base drawing:"
	pose_hint_lbl.theme_type_variation = "HintLabel"
	pose_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	poses_tab_vbox.add_child(pose_hint_lbl)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = false
	poses_tab_vbox.add_child(scroll)

	pose_slots_vbox = VBoxContainer.new()
	pose_slots_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pose_slots_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(pose_slots_vbox)


func _build_animations_tab() -> void:
	var anim_tab_vbox: VBoxContainer = VBoxContainer.new()
	anim_tab_vbox.name = "Clips & Loops"
	anim_tab_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	anim_tab_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	anim_tab_vbox.add_theme_constant_override("separation", 6)
	tab_container.add_child(anim_tab_vbox)

	var clips_scroll: ScrollContainer = ScrollContainer.new()
	clips_scroll.custom_minimum_size = Vector2(0.0, 36.0)
	clips_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	clips_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	clips_scroll.follow_focus = false
	anim_tab_vbox.add_child(clips_scroll)

	saved_clips_container = HBoxContainer.new()
	saved_clips_container.add_theme_constant_override("separation", 6)
	clips_scroll.add_child(saved_clips_container)

	var clip_row: HBoxContainer = HBoxContainer.new()
	clip_row.add_theme_constant_override("separation", 6)
	anim_tab_vbox.add_child(clip_row)

	clip_name_edit = LineEdit.new()
	clip_name_edit.text = "idle"
	clip_name_edit.placeholder_text = "Clip Name (e.g. spin)..."
	clip_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_row.add_child(clip_name_edit)

	opt_playback_mode = OptionButton.new()
	opt_playback_mode.custom_minimum_size = Vector2(110.0, 32.0)
	opt_playback_mode.add_item("Loop", 0)
	opt_playback_mode.add_item("Blink (3-5s)", 1)
	opt_playback_mode.add_item("One-Shot", 2)
	clip_row.add_child(opt_playback_mode)

	var preview_row: HBoxContainer = HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 8)
	anim_tab_vbox.add_child(preview_row)

	p_box = PanelContainer.new()
	p_box.theme_type_variation = "SubPanel"
	p_box.custom_minimum_size = Vector2(56.0, 56.0)
	p_box.clip_contents = true
	preview_row.add_child(p_box)

	anim_preview_rect = TextureRect.new()
	anim_preview_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	anim_preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	anim_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p_box.add_child(anim_preview_rect)

	var fps_vbox: VBoxContainer = VBoxContainer.new()
	fps_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fps_vbox.add_theme_constant_override("separation", 2)
	preview_row.add_child(fps_vbox)

	var fps_header: HBoxContainer = HBoxContainer.new()
	fps_vbox.add_child(fps_header)

	lbl_fps = Label.new()
	lbl_fps.text = "Speed:"
	lbl_fps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_fps.theme_type_variation = "HintLabel"
	fps_header.add_child(lbl_fps)

	fps_val_lbl = Label.new()
	fps_val_lbl.text = "6 FPS"
	fps_val_lbl.theme_type_variation = "HeaderLabel"
	fps_header.add_child(fps_val_lbl)

	fps_slider = HSlider.new()
	fps_slider.min_value = 1.0
	fps_slider.max_value = 24.0
	fps_slider.step = 1.0
	fps_slider.value = 6.0
	fps_slider.custom_minimum_size = Vector2(0.0, 22.0)
	fps_slider.value_changed.connect(func(value: float) -> void:
		target_fps = value
		fps_val_lbl.text = "%d FPS" % int(value)
	)
	fps_vbox.add_child(fps_slider)

	btn_browse_frame = Button.new()
	btn_browse_frame.text = " Add Animation Frame..."
	btn_browse_frame.custom_minimum_size = Vector2(0.0, 30.0)
	btn_browse_frame.focus_mode = Control.FOCUS_NONE
	btn_browse_frame.add_theme_constant_override("icon_max_width", 14)
	_apply_button_icon(btn_browse_frame, "icon_plus")
	btn_browse_frame.pressed.connect(_on_browse_clip_frame_pressed)
	anim_tab_vbox.add_child(btn_browse_frame)

	var frames_scroll: ScrollContainer = ScrollContainer.new()
	frames_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frames_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frames_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frames_scroll.follow_focus = false
	anim_tab_vbox.add_child(frames_scroll)

	frames_list_vbox = VBoxContainer.new()
	frames_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frames_list_vbox.add_theme_constant_override("separation", 4)
	frames_scroll.add_child(frames_list_vbox)

	btn_save_clip = Button.new()
	btn_save_clip.text = " Save Clip to State"
	btn_save_clip.custom_minimum_size = Vector2(0.0, 34.0)
	btn_save_clip.focus_mode = Control.FOCUS_NONE
	btn_save_clip.add_theme_constant_override("icon_max_width", 16)
	_apply_button_icon(btn_save_clip, "icon_save")
	btn_save_clip.pressed.connect(_on_save_clip_pressed)
	anim_tab_vbox.add_child(btn_save_clip)


func open_for_entity(entity: OwnEntity) -> void:
	if not is_instance_valid(entity): return
	active_entity = entity
	selected_form_tex = null
	selected_form_path = ""
	btn_choose_form_art.text = " Pick Art..."

	tab_container.current_tab = 1 if entity.entity_type != Types.EntityType.CHARACTER else 0
	_update_responsive_layout()
	_render_forms_bar()
	_render_pose_slots()
	_load_active_outfit_clips()
	visible = true


func close_studio() -> void:
	if active_entity != null and is_instance_valid(active_entity):
		SaveSystem.update_character_in_cast(active_entity)
		SaveSystem.save_current_room_state()
	visible = false
	active_entity = null


func _render_forms_bar() -> void:
	if forms_hbox_container == null: return
	for child: Node in forms_hbox_container.get_children():
		child.queue_free()
	if active_entity == null: return

	var accent_color: Color = ThemeService.get_color("accent_primary", "#db2777")
	var button_normal: Color = ThemeService.get_color("button_normal", "#fce7f3")
	var panel_border: Color = ThemeService.get_color("panel_border", "#f472b6")
	var text_primary: Color = ThemeService.get_color("text_primary", "#4a1525")
	var corner_radius: int = ThemeService.get_corner_radius()

	for form_name: String in active_entity.wardrobe_forms.keys():
		var is_active: bool = (form_name == active_entity.active_form_key)
		var button: Button = Button.new()
		button.text = " " + form_name
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0.0, 30.0)
		button.add_theme_constant_override("icon_max_width", 14)

		var state_icon: Texture2D = ThemeService.get_icon("icon_star" if is_active else "icon_states")
		if state_icon != null: button.icon = state_icon

		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = accent_color if is_active else button_normal
		style.border_color = accent_color if is_active else panel_border
		style.set_border_width_all(1)
		style.set_corner_radius_all(corner_radius)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 4
		style.content_margin_bottom = 4

		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_color_override("font_color", Color.WHITE if is_active else text_primary)
		button.add_theme_color_override("icon_normal_color", Color.WHITE if is_active else text_primary)
		button.pressed.connect(_on_switch_outfit_pressed.bind(form_name))
		forms_hbox_container.add_child(button)

		if form_name != "Default":
			var delete_button: Button = Button.new()
			delete_button.custom_minimum_size = Vector2(22.0, 22.0)
			delete_button.theme_type_variation = "DangerButton"
			delete_button.focus_mode = Control.FOCUS_NONE
			delete_button.add_theme_constant_override("icon_max_width", 10)
			_apply_close_icon(delete_button)
			delete_button.pressed.connect(_on_delete_outfit_pressed.bind(form_name))
			forms_hbox_container.add_child(delete_button)


func _on_switch_outfit_pressed(form_name: String) -> void:
	if active_entity == null: return
	active_entity.switch_wardrobe_form(form_name)
	_render_forms_bar()
	_render_pose_slots()
	_load_active_outfit_clips()


func _on_delete_outfit_pressed(form_name: String) -> void:
	if active_entity == null: return
	active_entity.wardrobe_forms.erase(form_name)
	if active_entity.active_form_key == form_name:
		active_entity.switch_wardrobe_form("Default")
	_render_forms_bar()
	_render_pose_slots()
	_load_active_outfit_clips()


func _on_pick_form_art_pressed() -> void:
	if asset_picker == null: return
	asset_picker.open_picker("Choose State Drawing", "", func(art_name: String, texture: Texture2D, file_path: String) -> void:
		selected_form_tex = texture
		selected_form_path = file_path
		btn_choose_form_art.text = " " + art_name
	)


func _on_add_outfit_form_pressed() -> void:
	if active_entity == null or selected_form_tex == null: return
	var form_name: String = form_name_input.text.strip_edges()
	if form_name.is_empty(): return

	active_entity.add_wardrobe_form(form_name, selected_form_tex, selected_form_path)
	form_name_input.text = ""
	selected_form_tex = null
	selected_form_path = ""
	btn_choose_form_art.text = " Pick Art..."
	_render_forms_bar()
	_render_pose_slots()


func _render_pose_slots() -> void:
	if pose_slots_vbox == null: return
	for child: Node in pose_slots_vbox.get_children():
		child.queue_free()

	if active_entity == null or not active_entity.wardrobe_forms.has(active_entity.active_form_key):
		return

	var form_data: Dictionary = active_entity.wardrobe_forms[active_entity.active_form_key]
	var sprites: Dictionary = form_data.get("sprites", {})

	var sub_background: Color = ThemeService.get_color("container_sub_bg", "#fdf2f4")
	var panel_border: Color = ThemeService.get_color("panel_border", "#f472b6")
	var accent_color: Color = ThemeService.get_color("accent_primary", "#db2777")
	var text_primary: Color = ThemeService.get_color("text_primary", "#4a1525")
	var input_background: Color = ThemeService.get_color("input_background", "#ffffff")
	var corner_radius: int = ThemeService.get_corner_radius()

	for slot_data: Dictionary in POSE_SLOTS:
		var slot_key: String = str(slot_data["key"])
		var slot_label: String = str(slot_data["label"])
		var current_texture: Texture2D = sprites.get(slot_key, null) as Texture2D

		var row: PanelContainer = PanelContainer.new()
		row.theme_type_variation = "SubPanel"
		row.custom_minimum_size = Vector2(0.0, 42.0)

		var row_style: StyleBoxFlat = StyleBoxFlat.new()
		row_style.bg_color = sub_background
		row_style.border_color = accent_color if current_texture != null else panel_border
		row_style.set_border_width_all(2 if current_texture != null else 1)
		row_style.set_corner_radius_all(corner_radius)
		row_style.content_margin_left = 8
		row_style.content_margin_right = 8
		row_style.content_margin_top = 4
		row_style.content_margin_bottom = 4
		row.add_theme_stylebox_override("panel", row_style)

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		row.add_child(hbox)

		var thumbnail_frame: PanelContainer = PanelContainer.new()
		thumbnail_frame.custom_minimum_size = Vector2(32.0, 32.0)
		thumbnail_frame.clip_contents = true

		var thumbnail_style: StyleBoxFlat = StyleBoxFlat.new()
		thumbnail_style.bg_color = input_background
		thumbnail_style.border_color = panel_border
		thumbnail_style.set_border_width_all(1)
		thumbnail_style.set_corner_radius_all(4)
		thumbnail_frame.add_theme_stylebox_override("panel", thumbnail_style)

		var thumbnail: TextureRect = TextureRect.new()
		thumbnail.set_anchors_preset(Control.PRESET_FULL_RECT)
		thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumbnail.texture = current_texture if current_texture != null else active_entity.main_texture
		thumbnail.modulate = Color.WHITE if current_texture != null else Color(1.0, 1.0, 1.0, 0.4)
		thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumbnail_frame.add_child(thumbnail)
		hbox.add_child(thumbnail_frame)

		var label: Label = Label.new()
		label.text = slot_label + (" (Custom)" if current_texture != null else " (Fallback)")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_color_override("font_color", accent_color if current_texture != null else text_primary)
		hbox.add_child(label)

		var pick_button: Button = Button.new()
		pick_button.text = " Pick..."
		pick_button.custom_minimum_size = Vector2(80.0, 26.0)
		pick_button.focus_mode = Control.FOCUS_NONE
		pick_button.add_theme_constant_override("icon_max_width", 14)
		_apply_button_icon(pick_button, "icon_folder")
		pick_button.pressed.connect(_on_slot_browse_pressed.bind(slot_key, slot_label))
		hbox.add_child(pick_button)

		if current_texture != null and slot_key != "eyes_open":
			var clear_button: Button = Button.new()
			clear_button.custom_minimum_size = Vector2(24.0, 24.0)
			clear_button.theme_type_variation = "DangerButton"
			clear_button.focus_mode = Control.FOCUS_NONE
			clear_button.add_theme_constant_override("icon_max_width", 10)
			_apply_close_icon(clear_button)
			clear_button.pressed.connect(_on_slot_clear_pressed.bind(slot_key))
			hbox.add_child(clear_button)

		pose_slots_vbox.add_child(row)


func _on_slot_browse_pressed(slot_key: String, slot_label: String) -> void:
	if asset_picker == null or active_entity == null: return
	asset_picker.open_picker("Choose Pose: " + slot_label, "", func(_a_name: String, texture: Texture2D, file_path: String) -> void:
		active_entity.assign_pose_slot_texture(active_entity.active_form_key, slot_key, texture, file_path)
		_render_pose_slots()
	)


func _on_slot_clear_pressed(slot_key: String) -> void:
	if active_entity == null: return
	active_entity.assign_pose_slot_texture(active_entity.active_form_key, slot_key, null, "")
	_render_pose_slots()


func _load_active_outfit_clips() -> void:
	if saved_clips_container == null: return
	for child: Node in saved_clips_container.get_children():
		child.queue_free()
	if active_entity == null: return

	var form_data: Dictionary = active_entity.wardrobe_forms.get(active_entity.active_form_key, {})
	var animations: Dictionary = form_data.get("animations", {})
	var accent_color: Color = ThemeService.get_color("accent_primary", "#db2777")

	var new_button: Button = Button.new()
	new_button.text = " New Clip"
	new_button.focus_mode = Control.FOCUS_NONE
	new_button.custom_minimum_size = Vector2(0.0, 30.0)
	new_button.add_theme_constant_override("icon_max_width", 14)
	_apply_button_icon(new_button, "icon_plus")
	new_button.pressed.connect(func() -> void: _start_fresh_clip("custom"))
	saved_clips_container.add_child(new_button)

	for clip_name: String in animations.keys():
		var is_loaded: bool = (clip_name == current_loaded_clip_name)
		var clip_row: HBoxContainer = HBoxContainer.new()
		clip_row.add_theme_constant_override("separation", 2)

		var clip_button: Button = Button.new()
		clip_button.text = " " + clip_name
		clip_button.custom_minimum_size = Vector2(0.0, 30.0)
		clip_button.focus_mode = Control.FOCUS_NONE
		clip_button.add_theme_constant_override("icon_max_width", 14)
		_apply_button_icon(clip_button, "icon_states")

		if is_loaded:
			var active_style: StyleBoxFlat = StyleBoxFlat.new()
			active_style.bg_color = accent_color
			active_style.border_color = accent_color
			active_style.set_border_width_all(1)
			active_style.set_corner_radius_all(ThemeService.get_corner_radius())
			active_style.content_margin_left = 8
			active_style.content_margin_right = 8
			clip_button.add_theme_stylebox_override("normal", active_style)
			clip_button.add_theme_stylebox_override("hover", active_style)
			clip_button.add_theme_color_override("font_color", Color.WHITE)
			clip_button.add_theme_color_override("icon_normal_color", Color.WHITE)

		clip_button.pressed.connect(_load_existing_clip.bind(clip_name))
		clip_row.add_child(clip_button)

		var delete_button: Button = Button.new()
		delete_button.custom_minimum_size = Vector2(22.0, 22.0)
		delete_button.theme_type_variation = "DangerButton"
		delete_button.focus_mode = Control.FOCUS_NONE
		delete_button.add_theme_constant_override("icon_max_width", 10)
		_apply_close_icon(delete_button)
		delete_button.pressed.connect(_on_delete_clip_pressed.bind(clip_name))
		clip_row.add_child(delete_button)

		saved_clips_container.add_child(clip_row)


func _on_delete_clip_pressed(clip_name: String) -> void:
	if active_entity == null: return
	active_entity.delete_animation_clip(active_entity.active_form_key, clip_name)
	if current_loaded_clip_name == clip_name: current_loaded_clip_name = ""
	_load_active_outfit_clips()
	_start_fresh_clip("idle")


func _load_existing_clip(clip_name: String) -> void:
	if active_entity == null: return
	var form_data: Dictionary = active_entity.wardrobe_forms.get(active_entity.active_form_key, {})
	var animations: Dictionary = form_data.get("animations", {})
	if not animations.has(clip_name): return

	current_loaded_clip_name = clip_name
	var clip_data: Dictionary = animations[clip_name]

	clip_name_edit.text = clip_name
	target_fps = float(clip_data.get("fps", 6.0))
	fps_slider.value = target_fps
	fps_val_lbl.text = "%d FPS" % int(target_fps)

	match str(clip_data.get("mode", "loop")):
		"loop": opt_playback_mode.selected = 0
		"blink": opt_playback_mode.selected = 1
		"one_shot": opt_playback_mode.selected = 2

	selected_clip_frames.clear()
	for value: Variant in clip_data.get("frames", []):
		if value is Texture2D: selected_clip_frames.append(value as Texture2D)

	selected_clip_paths.clear()
	for value: Variant in clip_data.get("paths", []):
		selected_clip_paths.append(str(value))

	preview_frame_idx = 0
	preview_timer = 0.0
	if not selected_clip_frames.is_empty():
		anim_preview_rect.texture = selected_clip_frames[0]

	_render_frames_list()
	_load_active_outfit_clips()


func _start_fresh_clip(default_name: String) -> void:
	current_loaded_clip_name = ""
	clip_name_edit.text = default_name
	selected_clip_frames.clear()
	selected_clip_paths.clear()

	if active_entity != null and active_entity.main_texture != null:
		selected_clip_frames.append(active_entity.main_texture)
		selected_clip_paths.append(active_entity.texture_path)

	target_fps = 6.0
	fps_slider.value = 6.0
	fps_val_lbl.text = "6 FPS"
	opt_playback_mode.selected = 0

	preview_frame_idx = 0
	preview_timer = 0.0
	if not selected_clip_frames.is_empty():
		anim_preview_rect.texture = selected_clip_frames[0]

	_render_frames_list()
	_load_active_outfit_clips()


func _on_browse_clip_frame_pressed() -> void:
	if asset_picker == null: return
	asset_picker.open_picker("Choose Animation Frame", "", func(_a_name: String, texture: Texture2D, file_path: String) -> void:
		selected_clip_frames.append(texture)
		selected_clip_paths.append(file_path)
		preview_frame_idx = 0
		preview_timer = 0.0
		_render_frames_list()
	)


func _render_frames_list() -> void:
	if frames_list_vbox == null: return
	for child: Node in frames_list_vbox.get_children():
		child.queue_free()

	var panel_border: Color = ThemeService.get_color("panel_border", "#f472b6")
	var input_background: Color = ThemeService.get_color("input_background", "#ffffff")

	for index: int in range(selected_clip_frames.size()):
		var card: PanelContainer = PanelContainer.new()
		card.theme_type_variation = "SubPanel"
		card.custom_minimum_size = Vector2(0.0, 36.0)

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		card.add_child(hbox)

		var label: Label = Label.new()
		label.text = "Frame %d:" % (index + 1)
		label.theme_type_variation = "HintLabel"
		hbox.add_child(label)

		var thumbnail_frame: PanelContainer = PanelContainer.new()
		thumbnail_frame.custom_minimum_size = Vector2(26.0, 26.0)
		thumbnail_frame.clip_contents = true

		var thumbnail_style: StyleBoxFlat = StyleBoxFlat.new()
		thumbnail_style.bg_color = input_background
		thumbnail_style.border_color = panel_border
		thumbnail_style.set_border_width_all(1)
		thumbnail_style.set_corner_radius_all(3)
		thumbnail_frame.add_theme_stylebox_override("panel", thumbnail_style)

		var thumbnail: TextureRect = TextureRect.new()
		thumbnail.set_anchors_preset(Control.PRESET_FULL_RECT)
		thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumbnail.texture = selected_clip_frames[index]
		thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumbnail_frame.add_child(thumbnail)
		hbox.add_child(thumbnail_frame)

		var path_label: Label = Label.new()
		path_label.text = selected_clip_paths[index].get_file() if index < selected_clip_paths.size() else "Frame"
		path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(path_label)

		if selected_clip_frames.size() > 1:
			var delete_button: Button = Button.new()
			delete_button.custom_minimum_size = Vector2(22.0, 22.0)
			delete_button.theme_type_variation = "DangerButton"
			delete_button.focus_mode = Control.FOCUS_NONE
			delete_button.add_theme_constant_override("icon_max_width", 10)
			_apply_close_icon(delete_button)
			delete_button.pressed.connect(_on_delete_clip_frame_pressed.bind(index))
			hbox.add_child(delete_button)

		frames_list_vbox.add_child(card)


func _on_delete_clip_frame_pressed(index: int) -> void:
	if selected_clip_frames.size() > 1 and index >= 0 and index < selected_clip_frames.size():
		selected_clip_frames.remove_at(index)
		if index < selected_clip_paths.size(): selected_clip_paths.remove_at(index)
		preview_frame_idx = 0
		preview_timer = 0.0
		_render_frames_list()


func _on_save_clip_pressed() -> void:
	if active_entity == null or selected_clip_frames.is_empty():
		return

	var clip_name: String = clip_name_edit.text.strip_edges().to_lower()
	if clip_name.is_empty(): clip_name = "idle"

	var mode_string: String = "loop"
	match opt_playback_mode.selected:
		0: mode_string = "loop"
		1: mode_string = "blink"
		2: mode_string = "one_shot"

	active_entity.register_animation_clip(
		active_entity.active_form_key, clip_name, selected_clip_frames.duplicate(),
		target_fps, selected_clip_paths.duplicate(), mode_string
	)

	current_loaded_clip_name = clip_name
	_load_active_outfit_clips()
	EventBus.notification_requested.emit("Saved: %s" % clip_name, true)


func _apply_button_icon(button: Button, icon_key: String) -> void:
	if button == null: return
	var icon_texture: Texture2D = ThemeService.get_icon(icon_key)
	if icon_texture != null: button.icon = icon_texture


func _apply_close_icon(button: Button) -> void:
	if button == null: return
	var icon_texture: Texture2D = ThemeService.get_icon("icon_close")
	if icon_texture != null: button.icon = icon_texture
	else: button.text = "✕"


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		close_studio()
