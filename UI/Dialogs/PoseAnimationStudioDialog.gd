# ============================================================
# File: res://UI/Dialogs/PoseAnimationStudioDialog.gd
# ============================================================

# ==============================================================================
# OWNWORLD — UNIFIED POSE & ANIMATION STUDIO (FULLY SYNCHRONIZED)
# File: res://UI/Dialogs/PoseAnimationStudioDialog.gd
# Base Class: CanvasLayer (class_name PoseAnimationStudioDialog)
#
# Responsibility: Master 3-tab studio dialog for Actor States, Wardrobe Outfits,
# Interactive Test Mannequin, GIF & Frame Timelines, and Sprite Sheet Slicing.
# Features direct natural blink test triggers and boundary-safe slice extractions.
# ==============================================================================

class_name PoseAnimationStudioDialog
extends CanvasLayer

const MAX_PANEL_WIDTH: float = 640.0
const MAX_PANEL_HEIGHT: float = 660.0

var root_backdrop: Control = null
var center_container: CenterContainer = null
var root_panel: PanelContainer = null
var active_entity: OwnEntity = null
var asset_picker: AssetPickerDialog = null

var header_lbl: Label = null
var tab_container: TabContainer = null

# Wardrobe Outfit Strip
var forms_hbox_container: HBoxContainer = null
var form_name_input: LineEdit = null
var selected_form_tex: Texture2D = null
var selected_form_path: String = ""
var btn_choose_form_art: Button = null
var btn_add_form: Button = null

# --- TAB 1: UNIFIED STATES & MANNEQUIN ---
var mannequin_card: PanelContainer = null
var mannequin_preview_rect: TextureRect = null
var mannequin_status_lbl: Label = null
var states_list_vbox: VBoxContainer = null
var new_state_name_input: LineEdit = null
var btn_add_custom_state: Button = null

# --- TAB 2: FRAME TIMELINE & GIF IMPORTER ---
var opt_edit_state_target: OptionButton = null
var clip_fps_slider: HSlider = null
var clip_fps_val_lbl: Label = null
var opt_playback_mode: OptionButton = null
var check_onion_skin: CheckBox = null

var timeline_preview_box: PanelContainer = null
var timeline_onion_rect: TextureRect = null
var timeline_preview_rect: TextureRect = null

var btn_import_gif: Button = null
var btn_add_timeline_frame: Button = null
var timeline_frames_vbox: VBoxContainer = null
var btn_save_timeline: Button = null

var working_timeline_frames: Array[Texture2D] = []
var working_timeline_paths: Array[String] = []
var timeline_preview_idx: int = 0
var timeline_preview_timer: float = 0.0
var timeline_ping_pong_forward: bool = true

# --- TAB 3: SPRITE SHEET & STRIP SLICER ---
var slicer_source_tex: Texture2D = null
var slicer_source_path: String = ""
var btn_choose_sheet_art: Button = null
var spin_cols: SpinBox = null
var spin_rows: SpinBox = null
var opt_slicer_dest_state: OptionButton = null
var slicer_preview_box: PanelContainer = null
var slicer_preview_rect: TextureRect = null
var slicer_grid_overlay: SlicerGridDraw = null
var btn_extract_slices: Button = null

const CORE_HOOK_DEFINITIONS: Array[Dictionary] = [
	{"key": Types.STATE_IDLE, "label": "Idle (Base Standing)", "icon": "icon_room", "hint": "Default resting stance"},
	{"key": Types.STATE_SPEAKING, "label": "Speaking (Mouth Open)", "icon": "icon_tag", "hint": "Talking / Dialogue state"},
	{"key": Types.STATE_EATING, "label": "Eating (Chewing / Sips)", "icon": "icon_food", "hint": "Food & drink consumption"},
	{"key": Types.STATE_SITTING, "label": "Sitting (Furniture Seated)", "icon": "icon_seat", "hint": "Snapped onto chairs & couches"},
	{"key": Types.STATE_SLEEPING, "label": "Sleeping (Bed Resting)", "icon": "icon_bed", "hint": "Horizontal sleeping on beds"}
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


func _update_responsive_layout() -> void:
	if not is_instance_valid(root_panel): return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280.0, 720.0)
	var target_w: float = clampf(vp_size.x * 0.94, 300.0, MAX_PANEL_WIDTH)
	var target_h: float = clampf(vp_size.y * 0.92, 340.0, MAX_PANEL_HEIGHT)
	root_panel.custom_minimum_size = Vector2(target_w, target_h)
	root_panel.size = Vector2(target_w, target_h)


func _on_theme_changed(_theme_data: Dictionary) -> void:
	_update_responsive_layout()
	if visible:
		_render_forms_bar()
		_render_states_list()
		_render_timeline_frames()


func _process(delta: float) -> void:
	if not visible: return

	# Process Timeline Tab Animation Preview
	if tab_container != null and tab_container.current_tab == 1 and not working_timeline_frames.is_empty():
		timeline_preview_timer += delta
		var fps_val: float = clip_fps_slider.value if clip_fps_slider != null else 6.0
		var frame_dur: float = 1.0 / maxf(fps_val, 1.0)

		if timeline_preview_timer >= frame_dur:
			timeline_preview_timer -= frame_dur
			var p_mode: int = opt_playback_mode.get_selected_id()

			match p_mode:
				int(Types.PlaybackMode.LOOP), int(Types.PlaybackMode.NATURAL_BLINK):
					timeline_preview_idx = (timeline_preview_idx + 1) % working_timeline_frames.size()
				int(Types.PlaybackMode.PING_PONG):
					if timeline_ping_pong_forward:
						timeline_preview_idx += 1
						if timeline_preview_idx >= working_timeline_frames.size() - 1:
							timeline_preview_idx = working_timeline_frames.size() - 1
							timeline_ping_pong_forward = false
					else:
						timeline_preview_idx -= 1
						if timeline_preview_idx <= 0:
							timeline_preview_idx = 0
							timeline_ping_pong_forward = true
				int(Types.PlaybackMode.ONE_SHOT), int(Types.PlaybackMode.ONE_SHOT_HOLD):
					if timeline_preview_idx < working_timeline_frames.size() - 1:
						timeline_preview_idx += 1

			_update_timeline_preview_display()


func _build_ui() -> void:
	root_backdrop = Control.new()
	root_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root_backdrop.gui_input.connect(_on_backdrop_gui_input)
	add_child(root_backdrop)

	var bg_dim: ColorRect = ColorRect.new()
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_dim.color = Color(0.0, 0.0, 0.0, 0.65)
	bg_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_backdrop.add_child(bg_dim)

	center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_PASS
	root_backdrop.add_child(center_container)

	root_panel = PanelContainer.new()
	root_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center_container.add_child(root_panel)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 6)
	root_panel.add_child(main_vbox)

	# --- Header ---
	var header_hbox: HBoxContainer = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	header_lbl = Label.new()
	header_lbl.text = "States & Animation Studio"
	header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_lbl.theme_type_variation = "HeaderLabel"
	header_lbl.add_theme_font_size_override("font_size", 13)
	header_hbox.add_child(header_lbl)

	var close_button: Button = Button.new()
	close_button.custom_minimum_size = Vector2(24.0, 24.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_constant_override("icon_max_width", 12)
	_apply_close_icon(close_button)
	close_button.pressed.connect(close_studio)
	header_hbox.add_child(close_button)

	main_vbox.add_child(HSeparator.new())

	# --- Wardrobe Forms & Outfits Bar ---
	var forms_scroll: ScrollContainer = ScrollContainer.new()
	forms_scroll.custom_minimum_size = Vector2(0.0, 32.0)
	forms_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	forms_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	forms_scroll.follow_focus = false
	main_vbox.add_child(forms_scroll)

	forms_hbox_container = HBoxContainer.new()
	forms_hbox_container.add_theme_constant_override("separation", 6)
	forms_scroll.add_child(forms_hbox_container)

	var add_form_row: HBoxContainer = HBoxContainer.new()
	add_form_row.add_theme_constant_override("separation", 6)
	main_vbox.add_child(add_form_row)

	form_name_input = LineEdit.new()
	form_name_input.placeholder_text = "New Outfit / Form Name (e.g. Armor, Pajamas)..."
	form_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_name_input.custom_minimum_size = Vector2(0.0, 30.0)
	add_form_row.add_child(form_name_input)

	btn_choose_form_art = Button.new()
	btn_choose_form_art.text = " Pick Art..."
	btn_choose_form_art.custom_minimum_size = Vector2(90.0, 30.0)
	btn_choose_form_art.focus_mode = Control.FOCUS_NONE
	btn_choose_form_art.add_theme_constant_override("icon_max_width", 14)
	_apply_button_icon(btn_choose_form_art, "icon_folder")
	btn_choose_form_art.pressed.connect(_on_pick_form_art_pressed)
	add_form_row.add_child(btn_choose_form_art)

	btn_add_form = Button.new()
	btn_add_form.text = " + Form"
	btn_add_form.custom_minimum_size = Vector2(80.0, 30.0)
	btn_add_form.focus_mode = Control.FOCUS_NONE
	btn_add_form.add_theme_constant_override("icon_max_width", 14)
	_apply_button_icon(btn_add_form, "icon_plus")
	btn_add_form.pressed.connect(_on_add_form_pressed)
	add_form_row.add_child(btn_add_form)

	main_vbox.add_child(HSeparator.new())

	# --- 3-Tab Main Studio Container ---
	tab_container = TabContainer.new()
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(tab_container)

	_build_states_and_mannequin_tab()
	_build_timeline_tab()
	_build_slicer_tab()


# --- TAB 1: UNIFIED STATES & MANNEQUIN ---

func _build_states_and_mannequin_tab() -> void:
	var tab_vbox: VBoxContainer = VBoxContainer.new()
	tab_vbox.name = "States & Mannequin"
	tab_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_vbox.add_theme_constant_override("separation", 6)
	tab_container.add_child(tab_vbox)

	# Mannequin Test Station Bar
	mannequin_card = PanelContainer.new()
	mannequin_card.theme_type_variation = "SubPanel"
	tab_vbox.add_child(mannequin_card)

	var m_hbox: HBoxContainer = HBoxContainer.new()
	m_hbox.add_theme_constant_override("separation", 10)
	mannequin_card.add_child(m_hbox)

	var prev_frame: PanelContainer = PanelContainer.new()
	prev_frame.theme_type_variation = "SubPanel"
	prev_frame.custom_minimum_size = Vector2(60.0, 60.0)
	prev_frame.clip_contents = true
	m_hbox.add_child(prev_frame)

	mannequin_preview_rect = TextureRect.new()
	mannequin_preview_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	mannequin_preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mannequin_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prev_frame.add_child(mannequin_preview_rect)

	var m_actions_vbox: VBoxContainer = VBoxContainer.new()
	m_actions_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_actions_vbox.add_theme_constant_override("separation", 4)
	m_hbox.add_child(m_actions_vbox)

	mannequin_status_lbl = Label.new()
	mannequin_status_lbl.text = "Interactive Test Mannequin — Active: Idle"
	mannequin_status_lbl.theme_type_variation = "HeaderLabel"
	mannequin_status_lbl.add_theme_font_size_override("font_size", 10)
	m_actions_vbox.add_child(mannequin_status_lbl)

	var test_btn_grid: GridContainer = GridContainer.new()
	test_btn_grid.columns = 4
	test_btn_grid.add_theme_constant_override("h_separation", 6)
	test_btn_grid.add_theme_constant_override("v_separation", 4)
	m_actions_vbox.add_child(test_btn_grid)

	_add_mannequin_test_btn(test_btn_grid, "Test Blink", func() -> void: if active_entity: active_entity.force_trigger_blink())
	_add_mannequin_test_btn(test_btn_grid, "Eat / Speak", func() -> void: if active_entity: active_entity.set_actor_state(Types.STATE_SPEAKING, 1.5))
	_add_mannequin_test_btn(test_btn_grid, "Sit", func() -> void: if active_entity: active_entity.set_actor_state(Types.STATE_SITTING, 2.5))
	_add_mannequin_test_btn(test_btn_grid, "Sleep", func() -> void: if active_entity: active_entity.set_actor_state(Types.STATE_SLEEPING, 2.5))

	# Custom State Adder
	var add_custom_row: HBoxContainer = HBoxContainer.new()
	add_custom_row.add_theme_constant_override("separation", 6)
	tab_vbox.add_child(add_custom_row)

	new_state_name_input = LineEdit.new()
	new_state_name_input.placeholder_text = "Create Custom State (e.g. dancing, happy, battle)..."
	new_state_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_state_name_input.custom_minimum_size = Vector2(0.0, 30.0)
	add_custom_row.add_child(new_state_name_input)

	btn_add_custom_state = Button.new()
	btn_add_custom_state.text = " + Add State"
	btn_add_custom_state.custom_minimum_size = Vector2(100.0, 30.0)
	btn_add_custom_state.focus_mode = Control.FOCUS_NONE
	btn_add_custom_state.add_theme_constant_override("icon_max_width", 14)
	_apply_button_icon(btn_add_custom_state, "icon_plus")
	btn_add_custom_state.pressed.connect(_on_add_custom_state_pressed)
	add_custom_row.add_child(btn_add_custom_state)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = false
	tab_vbox.add_child(scroll)

	states_list_vbox = VBoxContainer.new()
	states_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	states_list_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(states_list_vbox)


func _add_mannequin_test_btn(parent: GridContainer, label_text: String, callback: Callable) -> void:
	var btn: Button = Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(0.0, 24.0)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 9)
	btn.pressed.connect(callback)
	parent.add_child(btn)


# --- TAB 2: FRAME TIMELINE & GIF IMPORTER ---

func _build_timeline_tab() -> void:
	var tab_vbox: VBoxContainer = VBoxContainer.new()
	tab_vbox.name = "Frames & GIF Timeline"
	tab_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_vbox.add_theme_constant_override("separation", 6)
	tab_container.add_child(tab_vbox)

	var top_controls_grid: GridContainer = GridContainer.new()
	top_controls_grid.columns = 3
	top_controls_grid.add_theme_constant_override("h_separation", 8)
	top_controls_grid.add_theme_constant_override("v_separation", 4)
	tab_vbox.add_child(top_controls_grid)

	var st_box: VBoxContainer = VBoxContainer.new()
	var lbl_st: Label = Label.new()
	lbl_st.text = "Target State to Animate:"
	lbl_st.theme_type_variation = "HintLabel"
	st_box.add_child(lbl_st)
	opt_edit_state_target = OptionButton.new()
	opt_edit_state_target.custom_minimum_size = Vector2(0.0, 30.0)
	opt_edit_state_target.item_selected.connect(_on_timeline_target_state_selected)
	st_box.add_child(opt_edit_state_target)
	top_controls_grid.add_child(st_box)

	var mode_box: VBoxContainer = VBoxContainer.new()
	var lbl_m: Label = Label.new()
	lbl_m.text = "Playback Mode:"
	lbl_m.theme_type_variation = "HintLabel"
	mode_box.add_child(lbl_m)
	opt_playback_mode = OptionButton.new()
	opt_playback_mode.custom_minimum_size = Vector2(0.0, 30.0)
	opt_playback_mode.add_item("Forward Loop", int(Types.PlaybackMode.LOOP))
	opt_playback_mode.add_item("Natural Blink (Frame 0 Idle, 1+ Blink)", int(Types.PlaybackMode.NATURAL_BLINK))
	opt_playback_mode.add_item("Ping-Pong (Bounce)", int(Types.PlaybackMode.PING_PONG))
	opt_playback_mode.add_item("One-Shot", int(Types.PlaybackMode.ONE_SHOT))
	opt_playback_mode.add_item("One-Shot & Hold", int(Types.PlaybackMode.ONE_SHOT_HOLD))
	mode_box.add_child(opt_playback_mode)
	top_controls_grid.add_child(mode_box)

	var fps_box: VBoxContainer = VBoxContainer.new()
	var fps_hdr: HBoxContainer = HBoxContainer.new()
	var lbl_fps: Label = Label.new()
	lbl_fps.text = "Speed:"
	lbl_fps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_fps.theme_type_variation = "HintLabel"
	fps_hdr.add_child(lbl_fps)
	clip_fps_val_lbl = Label.new()
	clip_fps_val_lbl.text = "6 FPS"
	clip_fps_val_lbl.theme_type_variation = "HeaderLabel"
	fps_hdr.add_child(clip_fps_val_lbl)
	fps_box.add_child(fps_hdr)

	clip_fps_slider = HSlider.new()
	clip_fps_slider.min_value = 1.0
	clip_fps_slider.max_value = 30.0
	clip_fps_slider.step = 1.0
	clip_fps_slider.value = 6.0
	clip_fps_slider.value_changed.connect(func(v: float) -> void: clip_fps_val_lbl.text = "%d FPS" % int(v))
	fps_box.add_child(clip_fps_slider)
	top_controls_grid.add_child(fps_box)

	# Live Timeline Preview Box with Onion Skinning
	var preview_row: HBoxContainer = HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 10)
	tab_vbox.add_child(preview_row)

	timeline_preview_box = PanelContainer.new()
	timeline_preview_box.theme_type_variation = "SubPanel"
	timeline_preview_box.custom_minimum_size = Vector2(64.0, 64.0)
	timeline_preview_box.clip_contents = true
	preview_row.add_child(timeline_preview_box)

	timeline_onion_rect = TextureRect.new()
	timeline_onion_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	timeline_onion_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	timeline_onion_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	timeline_onion_rect.modulate = Color(1.0, 1.0, 1.0, 0.25)
	timeline_onion_rect.visible = false
	timeline_preview_box.add_child(timeline_onion_rect)

	timeline_preview_rect = TextureRect.new()
	timeline_preview_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	timeline_preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	timeline_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	timeline_preview_box.add_child(timeline_preview_rect)

	var action_btns_vbox: VBoxContainer = VBoxContainer.new()
	action_btns_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_btns_vbox.add_theme_constant_override("separation", 4)
	preview_row.add_child(action_btns_vbox)

	var tool_row: HBoxContainer = HBoxContainer.new()
	tool_row.add_theme_constant_override("separation", 6)
	action_btns_vbox.add_child(tool_row)

	btn_import_gif = Button.new()
	btn_import_gif.text = " Import Animated GIF..."
	btn_import_gif.custom_minimum_size = Vector2(0.0, 28.0)
	btn_import_gif.focus_mode = Control.FOCUS_NONE
	btn_import_gif.add_theme_constant_override("icon_max_width", 14)
	_apply_button_icon(btn_import_gif, "icon_play")
	btn_import_gif.pressed.connect(_on_import_gif_pressed)
	tool_row.add_child(btn_import_gif)

	btn_add_timeline_frame = Button.new()
	btn_add_timeline_frame.text = " + Add Frame"
	btn_add_timeline_frame.custom_minimum_size = Vector2(0.0, 28.0)
	btn_add_timeline_frame.focus_mode = Control.FOCUS_NONE
	btn_add_timeline_frame.add_theme_constant_override("icon_max_width", 14)
	_apply_button_icon(btn_add_timeline_frame, "icon_plus")
	btn_add_timeline_frame.pressed.connect(_on_add_timeline_frame_pressed)
	tool_row.add_child(btn_add_timeline_frame)

	check_onion_skin = CheckBox.new()
	check_onion_skin.text = " Onion Skin Ghost Overlay"
	check_onion_skin.toggled.connect(func(v: bool) -> void: timeline_onion_rect.visible = v)
	action_btns_vbox.add_child(check_onion_skin)

	var frames_scroll: ScrollContainer = ScrollContainer.new()
	frames_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frames_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frames_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frames_scroll.follow_focus = false
	tab_vbox.add_child(frames_scroll)

	timeline_frames_vbox = VBoxContainer.new()
	timeline_frames_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline_frames_vbox.add_theme_constant_override("separation", 3)
	frames_scroll.add_child(timeline_frames_vbox)

	btn_save_timeline = Button.new()
	btn_save_timeline.text = " Save Frames to State"
	btn_save_timeline.custom_minimum_size = Vector2(0.0, 34.0)
	btn_save_timeline.focus_mode = Control.FOCUS_NONE
	btn_save_timeline.add_theme_constant_override("icon_max_width", 16)
	_apply_button_icon(btn_save_timeline, "icon_save")
	btn_save_timeline.pressed.connect(_on_save_timeline_to_state_pressed)
	tab_vbox.add_child(btn_save_timeline)


# --- TAB 3: SPRITE SHEET & STRIP SLICER ---

func _build_slicer_tab() -> void:
	var tab_vbox: VBoxContainer = VBoxContainer.new()
	tab_vbox.name = "Sprite Sheet Slicer"
	tab_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_vbox.add_theme_constant_override("separation", 6)
	tab_container.add_child(tab_vbox)

	var pick_row: HBoxContainer = HBoxContainer.new()
	pick_row.add_theme_constant_override("separation", 8)
	tab_vbox.add_child(pick_row)

	btn_choose_sheet_art = Button.new()
	btn_choose_sheet_art.text = " Choose Sprite Sheet / Strip Drawing..."
	btn_choose_sheet_art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_choose_sheet_art.custom_minimum_size = Vector2(0.0, 32.0)
	btn_choose_sheet_art.focus_mode = Control.FOCUS_NONE
	btn_choose_sheet_art.add_theme_constant_override("icon_max_width", 14)
	_apply_button_icon(btn_choose_sheet_art, "icon_folder")
	btn_choose_sheet_art.pressed.connect(_on_pick_sheet_art_pressed)
	pick_row.add_child(btn_choose_sheet_art)

	var grid_params_row: HBoxContainer = HBoxContainer.new()
	grid_params_row.add_theme_constant_override("separation", 10)
	tab_vbox.add_child(grid_params_row)

	var lbl_c: Label = Label.new()
	lbl_c.text = "Columns:"
	lbl_c.theme_type_variation = "HintLabel"
	grid_params_row.add_child(lbl_c)

	spin_cols = SpinBox.new()
	spin_cols.min_value = 1
	spin_cols.max_value = 16
	spin_cols.value = 4
	spin_cols.custom_minimum_size = Vector2(70.0, 28.0)
	spin_cols.value_changed.connect(func(_v: float) -> void: if slicer_grid_overlay: slicer_grid_overlay.queue_redraw())
	grid_params_row.add_child(spin_cols)

	var lbl_r: Label = Label.new()
	lbl_r.text = "Rows:"
	lbl_r.theme_type_variation = "HintLabel"
	grid_params_row.add_child(lbl_r)

	spin_rows = SpinBox.new()
	spin_rows.min_value = 1
	spin_rows.max_value = 16
	spin_rows.value = 1
	spin_rows.custom_minimum_size = Vector2(70.0, 28.0)
	spin_rows.value_changed.connect(func(_v: float) -> void: if slicer_grid_overlay: slicer_grid_overlay.queue_redraw())
	grid_params_row.add_child(spin_rows)

	var lbl_dest: Label = Label.new()
	lbl_dest.text = "Destination State:"
	lbl_dest.theme_type_variation = "HintLabel"
	grid_params_row.add_child(lbl_dest)

	opt_slicer_dest_state = OptionButton.new()
	opt_slicer_dest_state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt_slicer_dest_state.custom_minimum_size = Vector2(0.0, 28.0)
	grid_params_row.add_child(opt_slicer_dest_state)

	# Slicer Grid Canvas
	slicer_preview_box = PanelContainer.new()
	slicer_preview_box.theme_type_variation = "SubPanel"
	slicer_preview_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slicer_preview_box.custom_minimum_size = Vector2(0.0, 180.0)
	slicer_preview_box.clip_contents = true
	tab_vbox.add_child(slicer_preview_box)

	var canvas_holder: Control = Control.new()
	canvas_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	slicer_preview_box.add_child(canvas_holder)

	slicer_preview_rect = TextureRect.new()
	slicer_preview_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	slicer_preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slicer_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	canvas_holder.add_child(slicer_preview_rect)

	slicer_grid_overlay = SlicerGridDraw.new()
	slicer_grid_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	slicer_grid_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slicer_grid_overlay.studio_ref = self
	canvas_holder.add_child(slicer_grid_overlay)

	btn_extract_slices = Button.new()
	btn_extract_slices.text = " Extract All Slices into State"
	btn_extract_slices.custom_minimum_size = Vector2(0.0, 36.0)
	btn_extract_slices.focus_mode = Control.FOCUS_NONE
	btn_extract_slices.add_theme_constant_override("icon_max_width", 16)
	_apply_button_icon(btn_extract_slices, "icon_plus")
	btn_extract_slices.pressed.connect(_on_extract_slices_pressed)
	tab_vbox.add_child(btn_extract_slices)


# --- STUDIO OPEN / CLOSE & POPULATION ---

func open_for_entity(entity: OwnEntity) -> void:
	if not is_instance_valid(entity): return
	active_entity = entity
	selected_form_tex = null
	selected_form_path = ""
	btn_choose_form_art.text = " Pick Art..."
	_update_responsive_layout()

	_render_forms_bar()
	_populate_state_dropdowns()
	_render_states_list()
	_load_state_into_timeline(active_entity.active_state_name)

	tab_container.current_tab = 0
	visible = true


func close_studio() -> void:
	if active_entity != null and is_instance_valid(active_entity):
		SaveSystem.update_character_in_cast(active_entity)
		SaveSystem.save_current_room_state()
	visible = false
	active_entity = null


func _render_forms_bar() -> void:
	if forms_hbox_container == null or active_entity == null: return
	for child: Node in forms_hbox_container.get_children(): child.queue_free()

	var c_accent: Color = ThemeService.get_color("accent_primary", "#ec4899")
	var rad: int = ThemeService.get_corner_radius()

	for form_name: String in active_entity.wardrobe_forms.keys():
		var is_active: bool = (form_name == active_entity.active_form_key)
		var btn: Button = Button.new()
		btn.text = " " + form_name
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(0.0, 30.0)
		btn.add_theme_constant_override("icon_max_width", 14)
		_apply_button_icon(btn, "icon_star" if is_active else "icon_states")

		if is_active:
			var s_act: StyleBoxFlat = StyleBoxFlat.new()
			s_act.bg_color = c_accent
			s_act.border_color = c_accent
			s_act.set_border_width_all(1)
			s_act.set_corner_radius_all(rad)
			s_act.content_margin_left = 10
			s_act.content_margin_right = 10
			btn.add_theme_stylebox_override("normal", s_act)
			btn.add_theme_stylebox_override("hover", s_act)
			btn.add_theme_stylebox_override("pressed", s_act)
			btn.add_theme_color_override("font_color", Color.WHITE)

		btn.pressed.connect(func() -> void:
			active_entity.switch_wardrobe_form(form_name)
			_render_forms_bar()
			_populate_state_dropdowns()
			_render_states_list()
			_load_state_into_timeline(active_entity.active_state_name)
		)
		forms_hbox_container.add_child(btn)

		if form_name != "Default":
			var del_btn: Button = Button.new()
			del_btn.custom_minimum_size = Vector2(22.0, 22.0)
			del_btn.theme_type_variation = "DangerButton"
			del_btn.focus_mode = Control.FOCUS_NONE
			_apply_close_icon(del_btn)
			del_btn.pressed.connect(func() -> void:
				active_entity.wardrobe_forms.erase(form_name)
				if active_entity.active_form_key == form_name:
					active_entity.switch_wardrobe_form("Default")
				_render_forms_bar()
				_populate_state_dropdowns()
				_render_states_list()
			)
			forms_hbox_container.add_child(del_btn)


func _populate_state_dropdowns() -> void:
	if active_entity == null: return
	var states: Dictionary = active_entity.wardrobe_forms.get(active_entity.active_form_key, {}).get("states", {})

	for opt: OptionButton in [opt_edit_state_target, opt_slicer_dest_state]:
		if opt == null: continue
		opt.clear()
		for definition: Dictionary in CORE_HOOK_DEFINITIONS:
			var k: String = str(definition["key"])
			opt.add_item(str(definition["label"]), opt.item_count)
			opt.set_item_metadata(opt.item_count - 1, k)

		for s_name: String in states.keys():
			var is_core: bool = false
			for def: Dictionary in CORE_HOOK_DEFINITIONS:
				if str(def["key"]) == s_name: is_core = true; break
			if not is_core:
				opt.add_item(s_name.capitalize(), opt.item_count)
				opt.set_item_metadata(opt.item_count - 1, s_name)


func _render_states_list() -> void:
	if states_list_vbox == null or active_entity == null: return
	for child: Node in states_list_vbox.get_children(): child.queue_free()

	var form_dict: Dictionary = active_entity.wardrobe_forms.get(active_entity.active_form_key, {})
	var states_dict: Dictionary = form_dict.get("states", {})

	mannequin_preview_rect.texture = active_entity.main_texture
	mannequin_status_lbl.text = "Interactive Test Mannequin — Active: %s" % active_entity.active_state_name.capitalize()

	# 1. Render Core Automated Engine Hooks
	for definition: Dictionary in CORE_HOOK_DEFINITIONS:
		var state_key: String = str(definition["key"])
		var state_label: String = str(definition["label"])
		var state_icon: String = str(definition["icon"])
		var is_assigned: bool = states_dict.has(state_key)
		var state_data: Dictionary = states_dict.get(state_key, {})
		_create_state_row(state_key, state_label, state_icon, is_assigned, state_data, false)

	# 2. Render Custom Action / Emote States
	for custom_state_name: String in states_dict.keys():
		var is_core: bool = false
		for def: Dictionary in CORE_HOOK_DEFINITIONS:
			if str(def["key"]) == custom_state_name: is_core = true; break
		if not is_core:
			_create_state_row(custom_state_name, custom_state_name.capitalize(), "icon_states", true, states_dict[custom_state_name], true)


func _create_state_row(state_key: String, label_text: String, icon_key: String, is_customized: bool, data: Dictionary, can_delete: bool) -> void:
	var card: PanelContainer = PanelContainer.new()
	card.theme_type_variation = "SubPanel"
	card.custom_minimum_size = Vector2(0.0, 38.0)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	card.add_child(hbox)

	var thumb_frame: PanelContainer = PanelContainer.new()
	thumb_frame.theme_type_variation = "SubPanel"
	thumb_frame.custom_minimum_size = Vector2(28.0, 28.0)
	thumb_frame.clip_contents = true
	hbox.add_child(thumb_frame)

	var thumb: TextureRect = TextureRect.new()
	thumb.set_anchors_preset(Control.PRESET_FULL_RECT)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var frames: Array = data.get("frames", [])
	if not frames.is_empty() and frames[0] is Texture2D:
		thumb.texture = frames[0] as Texture2D
	else:
		thumb.texture = active_entity.main_texture
		thumb.modulate = Color(1, 1, 1, 0.4)
	thumb_frame.add_child(thumb)

	var title_lbl: Label = Label.new()
	var frame_count: int = frames.size()
	var type_str: String = " (Animated: %d frames)" % frame_count if frame_count > 1 else (" (1 Frame)" if is_customized else " (Fallback)")
	title_lbl.text = label_text + type_str
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 10)
	hbox.add_child(title_lbl)

	var btn_pick: Button = Button.new()
	btn_pick.text = " Pick Art..."
	btn_pick.custom_minimum_size = Vector2(75.0, 26.0)
	btn_pick.focus_mode = Control.FOCUS_NONE
	btn_pick.add_theme_font_size_override("font_size", 9)
	btn_pick.add_theme_constant_override("icon_max_width", 12)
	_apply_button_icon(btn_pick, "icon_folder")
	btn_pick.pressed.connect(func() -> void:
		asset_picker.open_picker("Assign Art for " + label_text, "", func(_a_name: String, tex: Texture2D, path: String) -> void:
			if path.get_extension().to_lower() == "gif":
				var g_data: Dictionary = UGCManager.load_gif(path)
				if bool(g_data.get("valid", false)):
					active_entity.register_state(active_entity.active_form_key, state_key, g_data.get("frames", []), [path], float(g_data.get("fps", 6.0)), Types.PlaybackMode.LOOP)
			else:
				active_entity.register_state(active_entity.active_form_key, state_key, [tex], [path], 6.0, Types.PlaybackMode.LOOP)
			_render_states_list()
		)
	)
	hbox.add_child(btn_pick)

	var btn_edit: Button = Button.new()
	btn_edit.text = " Timeline"
	btn_edit.custom_minimum_size = Vector2(70.0, 26.0)
	btn_edit.focus_mode = Control.FOCUS_NONE
	btn_edit.add_theme_font_size_override("font_size", 9)
	btn_edit.add_theme_constant_override("icon_max_width", 12)
	_apply_button_icon(btn_edit, icon_key)
	btn_edit.pressed.connect(func() -> void:
		_load_state_into_timeline(state_key)
		tab_container.current_tab = 1
	)
	hbox.add_child(btn_edit)

	if can_delete:
		var btn_del: Button = Button.new()
		btn_del.custom_minimum_size = Vector2(24.0, 26.0)
		btn_del.theme_type_variation = "DangerButton"
		btn_del.focus_mode = Control.FOCUS_NONE
		_apply_close_icon(btn_del)
		btn_del.pressed.connect(func() -> void:
			var form_dict_ref: Dictionary = active_entity.wardrobe_forms.get(active_entity.active_form_key, {})
			var states_ref: Dictionary = form_dict_ref.get("states", {})
			states_ref.erase(state_key)
			_populate_state_dropdowns()
			_render_states_list()
		)
		hbox.add_child(btn_del)

	states_list_vbox.add_child(card)


func _on_add_custom_state_pressed() -> void:
	var state_name: String = new_state_name_input.text.strip_edges().to_lower().replace(" ", "_")
	if state_name.is_empty() or active_entity == null: return
	active_entity.register_state(active_entity.active_form_key, state_name, [active_entity.main_texture], [active_entity.texture_path])
	new_state_name_input.text = ""
	_populate_state_dropdowns()
	_render_states_list()


func _on_pick_form_art_pressed() -> void:
	asset_picker.open_picker("Choose Outfit Base Drawing", "", func(art_name: String, tex: Texture2D, path: String) -> void:
		selected_form_tex = tex
		selected_form_path = path
		btn_choose_form_art.text = " " + art_name
	)


func _on_add_form_pressed() -> void:
	var form_name: String = form_name_input.text.strip_edges()
	if form_name.is_empty() or selected_form_tex == null or active_entity == null: return
	active_entity.add_wardrobe_form(form_name, selected_form_tex, selected_form_path)
	form_name_input.text = ""
	selected_form_tex = null
	selected_form_path = ""
	btn_choose_form_art.text = " Pick Art..."
	_render_forms_bar()
	_populate_state_dropdowns()
	_render_states_list()


# --- TIMELINE & GIF ACTIONS ---

func _load_state_into_timeline(state_key: String) -> void:
	if active_entity == null: return
	var form_dict: Dictionary = active_entity.wardrobe_forms.get(active_entity.active_form_key, {})
	var states: Dictionary = form_dict.get("states", {})
	var data: Dictionary = states.get(state_key, {})

	working_timeline_frames.clear()
	working_timeline_paths.clear()

	for f: Variant in data.get("frames", []):
		if f is Texture2D: working_timeline_frames.append(f as Texture2D)
	for p: Variant in data.get("paths", []):
		working_timeline_paths.append(str(p))

	if working_timeline_frames.is_empty() and active_entity.main_texture != null:
		working_timeline_frames.append(active_entity.main_texture)
		working_timeline_paths.append(active_entity.texture_path)

	clip_fps_slider.value = float(data.get("fps", 6.0))
	clip_fps_val_lbl.text = "%d FPS" % int(clip_fps_slider.value)

	var p_mode: int = int(data.get("mode", Types.PlaybackMode.LOOP))
	for idx: int in range(opt_playback_mode.item_count):
		if opt_playback_mode.get_item_id(idx) == p_mode:
			opt_playback_mode.selected = idx
			break

	# Select state in dropdown
	for idx: int in range(opt_edit_state_target.item_count):
		if str(opt_edit_state_target.get_item_metadata(idx)) == state_key:
			opt_edit_state_target.selected = idx
			break

	timeline_preview_idx = 0
	timeline_preview_timer = 0.0
	_update_timeline_preview_display()
	_render_timeline_frames()


func _on_timeline_target_state_selected(index: int) -> void:
	var state_key: String = str(opt_edit_state_target.get_item_metadata(index))
	_load_state_into_timeline(state_key)


func _on_import_gif_pressed() -> void:
	asset_picker.open_picker("Choose Animated GIF to Import", "", func(_a_name: String, _tex: Texture2D, file_path: String) -> void:
		if file_path.get_extension().to_lower() != "gif":
			EventBus.notification_requested.emit("Please select a .gif file", false)
			return
		var gif_data: Dictionary = UGCManager.load_gif(file_path)
		if not bool(gif_data.get("valid", false)):
			EventBus.notification_requested.emit("GIF Decoding Failed", false)
			return

		working_timeline_frames.clear()
		working_timeline_paths.clear()

		for f: Variant in gif_data.get("frames", []):
			if f is Texture2D:
				working_timeline_frames.append(f as Texture2D)
				working_timeline_paths.append(file_path)

		var detected_fps: float = float(gif_data.get("fps", 10.0))
		clip_fps_slider.value = clampf(detected_fps, 1.0, 30.0)
		clip_fps_val_lbl.text = "%d FPS" % int(clip_fps_slider.value)
		opt_playback_mode.selected = 0

		timeline_preview_idx = 0
		timeline_preview_timer = 0.0
		_update_timeline_preview_display()
		_render_timeline_frames()
		EventBus.notification_requested.emit("Imported GIF (%d frames @ %d FPS)" % [working_timeline_frames.size(), int(detected_fps)], true)
	)


func _on_add_timeline_frame_pressed() -> void:
	asset_picker.open_picker("Choose Frame Drawing", "", func(_a_name: String, tex: Texture2D, path: String) -> void:
		working_timeline_frames.append(tex)
		working_timeline_paths.append(path)
		_update_timeline_preview_display()
		_render_timeline_frames()
	)


func _update_timeline_preview_display() -> void:
	if working_timeline_frames.is_empty():
		timeline_preview_rect.texture = null
		timeline_onion_rect.texture = null
		return

	timeline_preview_idx = clampi(timeline_preview_idx, 0, working_timeline_frames.size() - 1)
	timeline_preview_rect.texture = working_timeline_frames[timeline_preview_idx]

	if check_onion_skin.button_pressed and working_timeline_frames.size() > 1:
		var prev_idx: int = (timeline_preview_idx - 1 + working_timeline_frames.size()) % working_timeline_frames.size()
		timeline_onion_rect.texture = working_timeline_frames[prev_idx]
	else:
		timeline_onion_rect.texture = null


func _render_timeline_frames() -> void:
	if timeline_frames_vbox == null: return
	for child: Node in timeline_frames_vbox.get_children(): child.queue_free()

	for i: int in range(working_timeline_frames.size()):
		var row: PanelContainer = PanelContainer.new()
		row.theme_type_variation = "SubPanel"
		row.custom_minimum_size = Vector2(0.0, 32.0)

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		row.add_child(hbox)

		var lbl_idx: Label = Label.new()
		lbl_idx.text = "#%d" % (i + 1)
		lbl_idx.custom_minimum_size = Vector2(26.0, 0.0)
		lbl_idx.theme_type_variation = "HintLabel"
		hbox.add_child(lbl_idx)

		var thumb_frame: PanelContainer = PanelContainer.new()
		thumb_frame.custom_minimum_size = Vector2(24.0, 24.0)
		thumb_frame.clip_contents = true
		hbox.add_child(thumb_frame)

		var thumb: TextureRect = TextureRect.new()
		thumb.set_anchors_preset(Control.PRESET_FULL_RECT)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.texture = working_timeline_frames[i]
		thumb_frame.add_child(thumb)

		var fname_lbl: Label = Label.new()
		var p_str: String = working_timeline_paths[i] if i < working_timeline_paths.size() else "Frame"
		fname_lbl.text = p_str.get_file()
		fname_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fname_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		fname_lbl.add_theme_font_size_override("font_size", 9)
		hbox.add_child(fname_lbl)

		var target_idx: int = i

		# Move Up
		var btn_up: Button = Button.new()
		btn_up.text = "▲"
		btn_up.custom_minimum_size = Vector2(22.0, 22.0)
		btn_up.focus_mode = Control.FOCUS_NONE
		btn_up.disabled = (i == 0)
		btn_up.pressed.connect(func() -> void: _swap_timeline_frames(target_idx, target_idx - 1))
		hbox.add_child(btn_up)

		# Move Down
		var btn_down: Button = Button.new()
		btn_down.text = "▼"
		btn_down.custom_minimum_size = Vector2(22.0, 22.0)
		btn_down.focus_mode = Control.FOCUS_NONE
		btn_down.disabled = (i == working_timeline_frames.size() - 1)
		btn_down.pressed.connect(func() -> void: _swap_timeline_frames(target_idx, target_idx + 1))
		hbox.add_child(btn_down)

		# Duplicate Frame
		var btn_dup: Button = Button.new()
		btn_dup.custom_minimum_size = Vector2(22.0, 22.0)
		btn_dup.focus_mode = Control.FOCUS_NONE
		btn_dup.add_theme_constant_override("icon_max_width", 10)
		_apply_button_icon(btn_dup, "icon_clone")
		btn_dup.pressed.connect(func() -> void:
			working_timeline_frames.insert(target_idx + 1, working_timeline_frames[target_idx])
			working_timeline_paths.insert(target_idx + 1, working_timeline_paths[target_idx])
			_render_timeline_frames()
		)
		hbox.add_child(btn_dup)

		# Delete Frame
		var btn_del: Button = Button.new()
		btn_del.custom_minimum_size = Vector2(22.0, 22.0)
		btn_del.theme_type_variation = "DangerButton"
		btn_del.focus_mode = Control.FOCUS_NONE
		_apply_close_icon(btn_del)
		btn_del.pressed.connect(func() -> void:
			if working_timeline_frames.size() > 1:
				working_timeline_frames.remove_at(target_idx)
				working_timeline_paths.remove_at(target_idx)
				_update_timeline_preview_display()
				_render_timeline_frames()
		)
		hbox.add_child(btn_del)

		timeline_frames_vbox.add_child(row)


func _swap_timeline_frames(idx_a: int, idx_b: int) -> void:
	if idx_a < 0 or idx_b < 0 or idx_a >= working_timeline_frames.size() or idx_b >= working_timeline_frames.size():
		return
	var temp_f: Texture2D = working_timeline_frames[idx_a]
	working_timeline_frames[idx_a] = working_timeline_frames[idx_b]
	working_timeline_frames[idx_b] = temp_f

	var temp_p: String = working_timeline_paths[idx_a]
	working_timeline_paths[idx_a] = working_timeline_paths[idx_b]
	working_timeline_paths[idx_b] = temp_p

	_update_timeline_preview_display()
	_render_timeline_frames()


func _on_save_timeline_to_state_pressed() -> void:
	if active_entity == null or working_timeline_frames.is_empty(): return
	var target_state_key: String = ""
	if opt_edit_state_target.selected >= 0:
		target_state_key = str(opt_edit_state_target.get_item_metadata(opt_edit_state_target.selected)).strip_edges()
	if target_state_key.is_empty():
		target_state_key = Types.STATE_IDLE

	var p_mode: int = opt_playback_mode.get_selected_id()
	var fps_val: float = clip_fps_slider.value

	active_entity.register_state(active_entity.active_form_key, target_state_key, working_timeline_frames, working_timeline_paths, fps_val, p_mode)
	_render_states_list()
	EventBus.notification_requested.emit("Saved %d frames to State: %s" % [working_timeline_frames.size(), target_state_key], true)


# --- SPRITE SHEET SLICER ---

func _on_pick_sheet_art_pressed() -> void:
	asset_picker.open_picker("Choose Sprite Sheet / Strip", "", func(art_name: String, tex: Texture2D, path: String) -> void:
		slicer_source_tex = tex
		slicer_source_path = path
		btn_choose_sheet_art.text = " Sheet: " + art_name
		slicer_preview_rect.texture = tex

		var suggested: Vector2i = SpriteSheetSlicer.suggest_grid_layout(tex.get_width(), tex.get_height())
		spin_cols.value = suggested.x
		spin_rows.value = suggested.y
		if slicer_grid_overlay != null: slicer_grid_overlay.queue_redraw()
	)


func _on_extract_slices_pressed() -> void:
	if slicer_source_tex == null or active_entity == null:
		EventBus.notification_requested.emit("Please select a sprite sheet graphic first.", false)
		return

	var cols: int = int(spin_cols.value)
	var rows: int = int(spin_rows.value)
	var sliced_textures: Array[ImageTexture] = SpriteSheetSlicer.slice_by_grid(slicer_source_tex, cols, rows)

	if sliced_textures.is_empty():
		EventBus.notification_requested.emit("Slicing failed: Invalid dimensions", false)
		return

	var dest_state_key: String = ""
	if opt_slicer_dest_state.selected >= 0:
		dest_state_key = str(opt_slicer_dest_state.get_item_metadata(opt_slicer_dest_state.selected)).strip_edges()
	if dest_state_key.is_empty():
		dest_state_key = Types.STATE_IDLE

	var paths_arr: Array[String] = []
	var tex_arr: Array[Texture2D] = []

	for tex: ImageTexture in sliced_textures:
		tex_arr.append(tex)
		paths_arr.append(slicer_source_path)

	active_entity.register_state(active_entity.active_form_key, dest_state_key, tex_arr, paths_arr, 6.0, Types.PlaybackMode.LOOP)

	_load_state_into_timeline(dest_state_key)
	_render_states_list()
	tab_container.current_tab = 1
	EventBus.notification_requested.emit("Extracted %d frames into State: %s" % [tex_arr.size(), dest_state_key], true)


# --- HELPERS & THEME ---

func _apply_button_icon(btn: Button, key: String) -> void:
	if btn == null: return
	var tex: Texture2D = ThemeService.get_icon(key)
	if tex != null: btn.icon = tex


func _apply_close_icon(btn: Button) -> void:
	if btn == null: return
	var tex: Texture2D = ThemeService.get_icon("icon_close")
	if tex != null: btn.icon = tex
	else: btn.text = "✕"


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		close_studio()


# --- SLICER GRID OVERLAY DRAW ---

class SlicerGridDraw extends Control:
	var studio_ref: PoseAnimationStudioDialog = null

	func _draw() -> void:
		if studio_ref == null or studio_ref.slicer_source_tex == null: return

		var canvas_size: Vector2 = size
		var tex_size: Vector2 = studio_ref.slicer_source_tex.get_size()
		if tex_size.x <= 0.0 or tex_size.y <= 0.0: return

		var scale_f: float = minf(canvas_size.x / tex_size.x, canvas_size.y / tex_size.y)
		var drawn_size: Vector2 = tex_size * scale_f
		var start_pos: Vector2 = (canvas_size - drawn_size) * 0.5
		var rect: Rect2 = Rect2(start_pos, drawn_size)

		draw_rect(rect, Color("#ec4899", 0.35), false, 2.0)

		var cols: int = int(studio_ref.spin_cols.value)
		var rows: int = int(studio_ref.spin_rows.value)

		var cell_w: float = drawn_size.x / float(maxi(cols, 1))
		var cell_h: float = drawn_size.y / float(maxi(rows, 1))

		# Vertical Column Cutting Lines
		for c: int in range(1, cols):
			var x_pos: float = start_pos.x + float(c) * cell_w
			draw_line(Vector2(x_pos, start_pos.y), Vector2(x_pos, start_pos.y + drawn_size.y), Color("#00f2fe", 0.85), 1.5)

		# Horizontal Row Cutting Lines
		for r: int in range(1, rows):
			var y_pos: float = start_pos.y + float(r) * cell_h
			draw_line(Vector2(start_pos.x, y_pos), Vector2(start_pos.x + drawn_size.x, y_pos), Color("#00f2fe", 0.85), 1.5)
