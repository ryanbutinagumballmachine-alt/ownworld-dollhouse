# ==============================================================================
# OWNWORLD — UNIVERSE JOURNAL & CHRONICLES (LANDSCAPE MASTER-DETAIL DUAL-OS)
# File: res://UI/Dialogs/UniverseJournalDialog.gd
# Base Class: CanvasLayer (class_name UniverseJournalDialog)
#
# Responsibility: Comprehensive universe lore chronicle. Manages dated story eras,
# historical event logs, participating character links, guild/faction hierarchies,
# leader appointments, headquarters assignments, and member roster ranking.
# ==============================================================================

class_name UniverseJournalDialog
extends CanvasLayer

signal dialog_closed()

const DEFAULT_UNIVERSE_ID: String = "default_universe"

enum TabMode { TIMELINE, FACTIONS }

const MAX_PANEL_WIDTH: float = 780.0
const MAX_PANEL_HEIGHT: float = 580.0

var current_tab: TabMode = TabMode.TIMELINE
var journal_data: Dictionary = {"timeline": [], "factions": []}

var active_timeline_idx: int = -1
var active_faction_idx: int = -1
var cached_roster: Array[Dictionary] = []

var root_backdrop: Control = null
var center_box: CenterContainer = null
var modal_panel: PanelContainer = null
var header_lbl: Label = null
var universe_title_lbl: Label = null
var btn_save_journal: Button = null
var btn_close_journal: Button = null
var tab_btn_timeline: Button = null
var tab_btn_factions: Button = null
var content_holder: PanelContainer = null

var timeline_tab_container: HBoxContainer = null
var timeline_list_vbox: VBoxContainer = null
var timeline_editor_vbox: VBoxContainer = null
var t_add_event_btn: Button = null
var t_era_input: LineEdit = null
var t_title_input: LineEdit = null
var t_room_opt: OptionButton = null
var t_chars_container: HFlowContainer = null
var t_content_edit: TextEdit = null
var t_delete_btn: Button = null

var factions_tab_container: HBoxContainer = null
var factions_list_vbox: VBoxContainer = null
var factions_editor_vbox: VBoxContainer = null
var f_add_faction_btn: Button = null
var f_name_input: LineEdit = null
var f_color_btn: ColorPickerButton = null
var f_type_opt: OptionButton = null
var f_leader_opt: OptionButton = null
var f_hq_opt: OptionButton = null
var f_motto_input: LineEdit = null
var f_members_vbox: VBoxContainer = null
var f_add_member_opt: OptionButton = null
var f_notes_edit: TextEdit = null
var f_delete_btn: Button = null

const FACTION_TYPES: Array[String] = [
	"Guild", "Order / Clan", "Syndicate / Alliance", "Coven / Circle",
	"Academy / Scholarly", "Kingdom / Court", "Rebellion / Freefolk", "Independent Collective"
]


func _ready() -> void:
	name = "UniverseJournalDialog"
	layer = 110
	visible = false
	add_to_group("modal_ui")
	_build_ui()
	_connect_system_signals()
	_apply_theme_styling()
	_update_responsive_layout()
	_setup_keyboard_dodging()


func _is_mobile() -> bool:
	return ThemeEngine.is_mobile_platform()


func _connect_system_signals() -> void:
	if not ThemeService.theme_changed.is_connected(_on_theme_changed):
		ThemeService.theme_changed.connect(_on_theme_changed)
	var tree: SceneTree = get_tree()
	if tree and tree.root and not tree.root.size_changed.is_connected(_update_responsive_layout):
		tree.root.size_changed.connect(_update_responsive_layout)


func _setup_keyboard_dodging() -> void:
	if not _is_mobile(): 
		return
	var inputs: Array[Control] = [t_era_input, t_title_input, t_content_edit, f_name_input, f_motto_input, f_notes_edit]
	for input in inputs:
		if input != null:
			input.focus_entered.connect(_on_input_focus_entered)
			input.focus_exited.connect(_on_input_focus_exited)


func _on_input_focus_entered() -> void:
	if _is_mobile() and center_box != null:
		await get_tree().process_frame
		await get_tree().process_frame
		var kb_height: float = DisplayServer.virtual_keyboard_get_height()
		if kb_height > 0:
			var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(center_box, "position:y", -kb_height * 0.4, 0.25)


func _on_input_focus_exited() -> void:
	if _is_mobile() and center_box != null:
		var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(center_box, "position:y", 0.0, 0.25)


func _update_responsive_layout() -> void:
	if not is_instance_valid(modal_panel): 
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280.0, 720.0)
	var is_mob: bool = _is_mobile()

	var target_w: float = clampf(vp_size.x * 0.94, 320.0, MAX_PANEL_WIDTH)
	var target_h: float = clampf(vp_size.y * (0.92 if is_mob else 0.88), 300.0, MAX_PANEL_HEIGHT)
	modal_panel.custom_minimum_size = Vector2(target_w, target_h)
	modal_panel.size = Vector2(target_w, target_h)


func _on_theme_changed(_theme_data: Dictionary) -> void:
	_apply_theme_styling()
	if visible: 
		_select_tab(current_tab)


func _load_journal_state() -> void:
	journal_data = SaveSystem.load_universe_journal(AppState.universe_id)
	cached_roster = GameManager.get_all_universe_character_data()

	if universe_title_lbl:
		universe_title_lbl.text = "Universe: %s" % (AppState.universe_name if not AppState.universe_name.is_empty() else "Universe")


func open_journal() -> void:
	_load_journal_state()
	_update_responsive_layout()
	_apply_theme_styling()
	_select_tab(current_tab)
	visible = true


func close_dialog() -> void:
	_save_silently()
	visible = false
	dialog_closed.emit()


func _apply_theme_styling() -> void:
	var c_bg: Color = ThemeService.get_color("panel_background", "#fff5f7")
	var c_border: Color = ThemeService.get_color("panel_border", "#f9a8d4")
	var c_accent: Color = ThemeService.get_color("accent_primary", "#ec4899")
	var c_muted: Color = ThemeService.get_color("text_muted", "#a36374")
	var c_text: Color = ThemeService.get_color("text_primary", "#6c2e3f")
	var radius: int = ThemeService.get_corner_radius()

	if modal_panel:
		var p_style: StyleBoxFlat = StyleBoxFlat.new()
		p_style.bg_color = c_bg
		p_style.border_color = c_border
		p_style.set_border_width_all(2)
		p_style.set_corner_radius_all(radius + 2)
		p_style.content_margin_left = 14
		p_style.content_margin_right = 14
		p_style.content_margin_top = 10
		p_style.content_margin_bottom = 10
		modal_panel.add_theme_stylebox_override("panel", p_style)

	if header_lbl: 
		header_lbl.add_theme_color_override("font_color", c_accent)
	if universe_title_lbl: 
		universe_title_lbl.add_theme_color_override("font_color", c_muted)

	var icon_timeline: Texture2D = ThemeService.get_icon("icon_room")
	if icon_timeline and tab_btn_timeline: 
		tab_btn_timeline.icon = icon_timeline

	var icon_factions: Texture2D = ThemeService.get_icon("icon_cast")
	if icon_factions and tab_btn_factions: 
		tab_btn_factions.icon = icon_factions

	_style_tab_button(tab_btn_timeline, current_tab == TabMode.TIMELINE, c_accent, c_text, radius)
	_style_tab_button(tab_btn_factions, current_tab == TabMode.FACTIONS, c_accent, c_text, radius)


func _build_ui() -> void:
	var is_mob: bool = _is_mobile()
	var row_h: float = 36.0 if is_mob else 30.0

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

	center_box = CenterContainer.new()
	center_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_box.mouse_filter = Control.MOUSE_FILTER_PASS
	root_backdrop.add_child(center_box)

	modal_panel = PanelContainer.new()
	modal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center_box.add_child(modal_panel)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 6)
	modal_panel.add_child(main_vbox)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(header_hbox)

	var title_vbox: VBoxContainer = VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_vbox)

	header_lbl = Label.new()
	header_lbl.text = "World Journal & Story Chronicles"
	header_lbl.add_theme_font_size_override("font_size", 15 if is_mob else 13)
	title_vbox.add_child(header_lbl)

	universe_title_lbl = Label.new()
	universe_title_lbl.text = "Universe: Default Universe"
	universe_title_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	title_vbox.add_child(universe_title_lbl)

	btn_save_journal = Button.new()
	btn_save_journal.text = "Save Journal"
	btn_save_journal.custom_minimum_size = Vector2(110.0 if is_mob else 95.0, row_h)
	btn_save_journal.focus_mode = Control.FOCUS_NONE
	btn_save_journal.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	btn_save_journal.pressed.connect(_on_save_button_pressed)
	header_hbox.add_child(btn_save_journal)

	btn_close_journal = Button.new()
	btn_close_journal.text = "Close"
	btn_close_journal.custom_minimum_size = Vector2(75.0 if is_mob else 65.0, row_h)
	btn_close_journal.focus_mode = Control.FOCUS_NONE
	btn_close_journal.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	btn_close_journal.pressed.connect(close_dialog)
	header_hbox.add_child(btn_close_journal)

	var tab_bar: HBoxContainer = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 8)
	main_vbox.add_child(tab_bar)

	tab_btn_timeline = Button.new()
	tab_btn_timeline.text = "Chronicles & Timeline"
	tab_btn_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_btn_timeline.custom_minimum_size = Vector2(0.0, row_h)
	tab_btn_timeline.focus_mode = Control.FOCUS_NONE
	tab_btn_timeline.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	tab_btn_timeline.pressed.connect(func() -> void: _select_tab(TabMode.TIMELINE))
	tab_bar.add_child(tab_btn_timeline)

	tab_btn_factions = Button.new()
	tab_btn_factions.text = "Factions & Guilds"
	tab_btn_factions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_btn_factions.custom_minimum_size = Vector2(0.0, row_h)
	tab_btn_factions.focus_mode = Control.FOCUS_NONE
	tab_btn_factions.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	tab_btn_factions.pressed.connect(func() -> void: _select_tab(TabMode.FACTIONS))
	tab_bar.add_child(tab_btn_factions)

	main_vbox.add_child(HSeparator.new())

	content_holder = PanelContainer.new()
	content_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_holder.theme_type_variation = "SubPanel"
	main_vbox.add_child(content_holder)

	timeline_tab_container = HBoxContainer.new()
	timeline_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	timeline_tab_container.add_theme_constant_override("separation", 10)
	content_holder.add_child(timeline_tab_container)
	_build_timeline_tab_ui()

	factions_tab_container = HBoxContainer.new()
	factions_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	factions_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	factions_tab_container.add_theme_constant_override("separation", 10)
	content_holder.add_child(factions_tab_container)
	_build_factions_tab_ui()


func _build_timeline_tab_ui() -> void:
	var is_mob: bool = _is_mobile()
	var row_h: float = 34.0 if is_mob else 28.0

	var left_vbox: VBoxContainer = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(240.0 if is_mob else 200.0, 0.0)
	left_vbox.size_flags_horizontal = Control.SIZE_FILL
	left_vbox.add_theme_constant_override("separation", 6)
	timeline_tab_container.add_child(left_vbox)

	t_add_event_btn = Button.new()
	t_add_event_btn.text = "+ Add Story Event"
	t_add_event_btn.custom_minimum_size = Vector2(0.0, row_h)
	t_add_event_btn.focus_mode = Control.FOCUS_NONE
	t_add_event_btn.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	t_add_event_btn.pressed.connect(_on_add_timeline_entry)
	left_vbox.add_child(t_add_event_btn)

	var scroll_left: ScrollContainer = ScrollContainer.new()
	scroll_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_left.follow_focus = false
	left_vbox.add_child(scroll_left)

	timeline_list_vbox = VBoxContainer.new()
	timeline_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline_list_vbox.add_theme_constant_override("separation", 4)
	scroll_left.add_child(timeline_list_vbox)

	timeline_tab_container.add_child(VSeparator.new())

	var right_scroll: ScrollContainer = ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.follow_focus = false
	timeline_tab_container.add_child(right_scroll)

	timeline_editor_vbox = VBoxContainer.new()
	timeline_editor_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline_editor_vbox.add_theme_constant_override("separation", 6)
	right_scroll.add_child(timeline_editor_vbox)

	var era_hbox: HBoxContainer = HBoxContainer.new()
	era_hbox.add_theme_constant_override("separation", 8)
	timeline_editor_vbox.add_child(era_hbox)

	var era_lbl: Label = Label.new()
	era_lbl.text = "Era / Date:"
	era_lbl.custom_minimum_size = Vector2(85.0, 0.0)
	era_lbl.theme_type_variation = "HintLabel"
	era_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	era_hbox.add_child(era_lbl)

	t_era_input = LineEdit.new()
	t_era_input.placeholder_text = "e.g. Year of the Starlight Eclipse"
	t_era_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_era_input.custom_minimum_size = Vector2(0.0, row_h)
	t_era_input.text_changed.connect(func(_new_t: String) -> void: _commit_active_timeline_field("era", _new_t))
	era_hbox.add_child(t_era_input)

	var title_hbox: HBoxContainer = HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 8)
	timeline_editor_vbox.add_child(title_hbox)

	var title_lbl: Label = Label.new()
	title_lbl.text = "Event Title:"
	title_lbl.custom_minimum_size = Vector2(85.0, 0.0)
	title_lbl.theme_type_variation = "HintLabel"
	title_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	title_hbox.add_child(title_lbl)

	t_title_input = LineEdit.new()
	t_title_input.placeholder_text = "e.g. Founding of the Sunken Library"
	t_title_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_title_input.custom_minimum_size = Vector2(0.0, row_h)
	t_title_input.text_changed.connect(func(_new_t: String) -> void: _commit_active_timeline_field("title", _new_t))
	title_hbox.add_child(t_title_input)

	var room_hbox: HBoxContainer = HBoxContainer.new()
	room_hbox.add_theme_constant_override("separation", 8)
	timeline_editor_vbox.add_child(room_hbox)

	var room_lbl: Label = Label.new()
	room_lbl.text = "Linked Room:"
	room_lbl.custom_minimum_size = Vector2(85.0, 0.0)
	room_lbl.theme_type_variation = "HintLabel"
	room_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	room_hbox.add_child(room_lbl)

	t_room_opt = OptionButton.new()
	t_room_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_room_opt.custom_minimum_size = Vector2(0.0, row_h)
	_clamp_popup(t_room_opt)
	t_room_opt.item_selected.connect(_on_timeline_room_selected)
	room_hbox.add_child(t_room_opt)

	var chars_lbl: Label = Label.new()
	chars_lbl.text = "Participating Characters:"
	chars_lbl.theme_type_variation = "HeaderLabel"
	chars_lbl.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	timeline_editor_vbox.add_child(chars_lbl)

	t_chars_container = HFlowContainer.new()
	t_chars_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_chars_container.add_theme_constant_override("h_separation", 6)
	t_chars_container.add_theme_constant_override("v_separation", 6)
	timeline_editor_vbox.add_child(t_chars_container)

	var desc_lbl: Label = Label.new()
	desc_lbl.text = "Chronicle Narrative Notes:"
	desc_lbl.theme_type_variation = "HeaderLabel"
	desc_lbl.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	timeline_editor_vbox.add_child(desc_lbl)

	t_content_edit = TextEdit.new()
	t_content_edit.custom_minimum_size = Vector2(0.0, 100.0)
	t_content_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_content_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	t_content_edit.placeholder_text = "Describe the story events that unfolded..."
	t_content_edit.text_changed.connect(func() -> void: _commit_active_timeline_field("content", t_content_edit.text))
	timeline_editor_vbox.add_child(t_content_edit)

	var t_footer: HBoxContainer = HBoxContainer.new()
	t_footer.alignment = BoxContainer.ALIGNMENT_END
	timeline_editor_vbox.add_child(t_footer)

	t_delete_btn = Button.new()
	t_delete_btn.text = "Delete Event"
	t_delete_btn.theme_type_variation = "DangerButton"
	t_delete_btn.custom_minimum_size = Vector2(110.0 if is_mob else 95.0, row_h)
	t_delete_btn.focus_mode = Control.FOCUS_NONE
	t_delete_btn.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	t_delete_btn.pressed.connect(_on_delete_timeline_entry)
	t_footer.add_child(t_delete_btn)


func _build_factions_tab_ui() -> void:
	var is_mob: bool = _is_mobile()
	var row_h: float = 34.0 if is_mob else 28.0

	var left_vbox: VBoxContainer = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(240.0 if is_mob else 200.0, 0.0)
	left_vbox.size_flags_horizontal = Control.SIZE_FILL
	left_vbox.add_theme_constant_override("separation", 6)
	factions_tab_container.add_child(left_vbox)

	f_add_faction_btn = Button.new()
	f_add_faction_btn.text = "+ Add Faction / Guild"
	f_add_faction_btn.custom_minimum_size = Vector2(0.0, row_h)
	f_add_faction_btn.focus_mode = Control.FOCUS_NONE
	f_add_faction_btn.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	f_add_faction_btn.pressed.connect(_on_add_faction_entry)
	left_vbox.add_child(f_add_faction_btn)

	var scroll_left: ScrollContainer = ScrollContainer.new()
	scroll_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_left.follow_focus = false
	left_vbox.add_child(scroll_left)

	factions_list_vbox = VBoxContainer.new()
	factions_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	factions_list_vbox.add_theme_constant_override("separation", 4)
	scroll_left.add_child(factions_list_vbox)

	factions_tab_container.add_child(VSeparator.new())

	var right_scroll: ScrollContainer = ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.follow_focus = false
	factions_tab_container.add_child(right_scroll)

	factions_editor_vbox = VBoxContainer.new()
	factions_editor_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	factions_editor_vbox.add_theme_constant_override("separation", 6)
	right_scroll.add_child(factions_editor_vbox)

	var name_hbox: HBoxContainer = HBoxContainer.new()
	name_hbox.add_theme_constant_override("separation", 8)
	factions_editor_vbox.add_child(name_hbox)

	var name_lbl: Label = Label.new()
	name_lbl.text = "Faction Name:"
	name_lbl.custom_minimum_size = Vector2(95.0, 0.0)
	name_lbl.theme_type_variation = "HintLabel"
	name_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	name_hbox.add_child(name_lbl)

	f_name_input = LineEdit.new()
	f_name_input.placeholder_text = "e.g. Starlight Bakery Guild"
	f_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f_name_input.custom_minimum_size = Vector2(0.0, row_h)
	f_name_input.text_changed.connect(func(_new_t: String) -> void: _commit_active_faction_field("name", _new_t))
	name_hbox.add_child(f_name_input)

	f_color_btn = ColorPickerButton.new()
	f_color_btn.custom_minimum_size = Vector2(40.0 if is_mob else 36.0, row_h)
	f_color_btn.color = Color("#ec4899")
	f_color_btn.color_changed.connect(_on_faction_color_changed)
	name_hbox.add_child(f_color_btn)

	var type_hbox: HBoxContainer = HBoxContainer.new()
	type_hbox.add_theme_constant_override("separation", 8)
	factions_editor_vbox.add_child(type_hbox)

	var type_lbl: Label = Label.new()
	type_lbl.text = "Structure Type:"
	type_lbl.custom_minimum_size = Vector2(95.0, 0.0)
	type_lbl.theme_type_variation = "HintLabel"
	type_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	type_hbox.add_child(type_lbl)

	f_type_opt = OptionButton.new()
	f_type_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f_type_opt.custom_minimum_size = Vector2(0.0, row_h)
	_clamp_popup(f_type_opt)
	for i: int in range(FACTION_TYPES.size()):
		f_type_opt.add_item(FACTION_TYPES[i], i)
	f_type_opt.item_selected.connect(_on_faction_type_selected)
	type_hbox.add_child(f_type_opt)

	var lead_hq_grid: GridContainer = GridContainer.new()
	lead_hq_grid.columns = 2
	lead_hq_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lead_hq_grid.add_theme_constant_override("h_separation", 10)
	factions_editor_vbox.add_child(lead_hq_grid)

	var col_lead: VBoxContainer = VBoxContainer.new()
	col_lead.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lead_hq_grid.add_child(col_lead)

	var lead_lbl: Label = Label.new()
	lead_lbl.text = "Guild Leader:"
	lead_lbl.theme_type_variation = "HintLabel"
	lead_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	col_lead.add_child(lead_lbl)

	f_leader_opt = OptionButton.new()
	f_leader_opt.custom_minimum_size = Vector2(0.0, row_h)
	_clamp_popup(f_leader_opt)
	f_leader_opt.item_selected.connect(_on_faction_leader_selected)
	col_lead.add_child(f_leader_opt)

	var col_hq: VBoxContainer = VBoxContainer.new()
	col_hq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lead_hq_grid.add_child(col_hq)

	var hq_lbl: Label = Label.new()
	hq_lbl.text = "Headquarters:"
	hq_lbl.theme_type_variation = "HintLabel"
	hq_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	col_hq.add_child(hq_lbl)

	f_hq_opt = OptionButton.new()
	f_hq_opt.custom_minimum_size = Vector2(0.0, row_h)
	_clamp_popup(f_hq_opt)
	f_hq_opt.item_selected.connect(_on_faction_hq_selected)
	col_hq.add_child(f_hq_opt)

	var motto_hbox: HBoxContainer = HBoxContainer.new()
	motto_hbox.add_theme_constant_override("separation", 8)
	factions_editor_vbox.add_child(motto_hbox)

	var motto_lbl: Label = Label.new()
	motto_lbl.text = "Motto / Slogan:"
	motto_lbl.custom_minimum_size = Vector2(95.0, 0.0)
	motto_lbl.theme_type_variation = "HintLabel"
	motto_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	motto_hbox.add_child(motto_lbl)

	f_motto_input = LineEdit.new()
	f_motto_input.placeholder_text = "e.g. Baking warmth into every dark corner."
	f_motto_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f_motto_input.custom_minimum_size = Vector2(0.0, row_h)
	f_motto_input.text_changed.connect(func(_new_t: String) -> void: _commit_active_faction_field("motto", _new_t))
	motto_hbox.add_child(f_motto_input)

	factions_editor_vbox.add_child(HSeparator.new())

	var roster_header_hbox: HBoxContainer = HBoxContainer.new()
	roster_header_hbox.add_theme_constant_override("separation", 10)
	factions_editor_vbox.add_child(roster_header_hbox)

	var members_lbl: Label = Label.new()
	members_lbl.text = "Member Roster & Ranks:"
	members_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	members_lbl.theme_type_variation = "HeaderLabel"
	members_lbl.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	roster_header_hbox.add_child(members_lbl)

	f_add_member_opt = OptionButton.new()
	f_add_member_opt.text = "+ Enlist Member..."
	f_add_member_opt.custom_minimum_size = Vector2(150.0 if is_mob else 130.0, row_h)
	_clamp_popup(f_add_member_opt)
	f_add_member_opt.item_selected.connect(_on_add_member_selected)
	roster_header_hbox.add_child(f_add_member_opt)

	f_members_vbox = VBoxContainer.new()
	f_members_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f_members_vbox.add_theme_constant_override("separation", 4)
	factions_editor_vbox.add_child(f_members_vbox)

	factions_editor_vbox.add_child(HSeparator.new())

	var f_notes_lbl: Label = Label.new()
	f_notes_lbl.text = "History & Traditions:"
	f_notes_lbl.theme_type_variation = "HeaderLabel"
	f_notes_lbl.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	factions_editor_vbox.add_child(f_notes_lbl)

	f_notes_edit = TextEdit.new()
	f_notes_edit.custom_minimum_size = Vector2(0.0, 100.0)
	f_notes_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f_notes_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	f_notes_edit.placeholder_text = "Guild traditions, alliances, secrets, and territory..."
	f_notes_edit.text_changed.connect(func() -> void: _commit_active_faction_field("notes", f_notes_edit.text))
	factions_editor_vbox.add_child(f_notes_edit)

	var f_footer: HBoxContainer = HBoxContainer.new()
	f_footer.alignment = BoxContainer.ALIGNMENT_END
	factions_editor_vbox.add_child(f_footer)

	f_delete_btn = Button.new()
	f_delete_btn.text = "Delete Faction"
	f_delete_btn.theme_type_variation = "DangerButton"
	f_delete_btn.custom_minimum_size = Vector2(120.0 if is_mob else 100.0, row_h)
	f_delete_btn.focus_mode = Control.FOCUS_NONE
	f_delete_btn.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	f_delete_btn.pressed.connect(_on_delete_faction_entry)
	f_footer.add_child(f_delete_btn)


func _select_tab(tab: TabMode) -> void:
	current_tab = tab
	var c_accent: Color = ThemeService.get_color("accent_primary", "#ec4899")
	var c_text: Color = ThemeService.get_color("text_primary", "#6c2e3f")
	var rad: int = ThemeService.get_corner_radius()

	_style_tab_button(tab_btn_timeline, current_tab == TabMode.TIMELINE, c_accent, c_text, rad)
	_style_tab_button(tab_btn_factions, current_tab == TabMode.FACTIONS, c_accent, c_text, rad)

	timeline_tab_container.visible = (current_tab == TabMode.TIMELINE)
	factions_tab_container.visible = (current_tab == TabMode.FACTIONS)

	match current_tab:
		TabMode.TIMELINE: _render_timeline_list()
		TabMode.FACTIONS: _render_factions_list()


func _style_tab_button(btn: Button, is_active: bool, c_accent: Color, _c_text: Color, rad: int) -> void:
	if not btn: return
	btn.remove_theme_stylebox_override("normal")
	btn.remove_theme_stylebox_override("hover")
	btn.remove_theme_stylebox_override("pressed")
	btn.remove_theme_stylebox_override("focus")
	btn.remove_theme_color_override("font_color")
	btn.remove_theme_color_override("font_hover_color")
	btn.remove_theme_color_override("font_pressed_color")
	btn.remove_theme_color_override("icon_normal_color")
	btn.remove_theme_color_override("icon_hover_color")

	if is_active:
		var s_act: StyleBoxFlat = StyleBoxFlat.new()
		s_act.bg_color = c_accent
		s_act.border_color = c_accent
		s_act.set_border_width_all(1)
		s_act.set_corner_radius_all(rad)
		s_act.content_margin_left = 10
		s_act.content_margin_right = 10
		s_act.content_margin_top = 6
		s_act.content_margin_bottom = 6

		btn.add_theme_stylebox_override("normal", s_act)
		btn.add_theme_stylebox_override("hover", s_act)
		btn.add_theme_stylebox_override("pressed", s_act)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_color_override("icon_normal_color", Color.WHITE)


func _render_timeline_list() -> void:
	for c: Node in timeline_list_vbox.get_children():
		c.queue_free()
	var timeline_arr: Array = journal_data.get("timeline", [])
	if timeline_arr.is_empty():
		var hint: Label = Label.new()
		hint.text = "No events yet.\nTap + Add Story Event to begin your chronicle."
		hint.theme_type_variation = "HintLabel"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 11 if _is_mobile() else 10)
		timeline_list_vbox.add_child(hint)
		timeline_editor_vbox.visible = false
		active_timeline_idx = -1
		return

	timeline_editor_vbox.visible = true
	if active_timeline_idx < 0 or active_timeline_idx >= timeline_arr.size():
		active_timeline_idx = 0

	for i: int in range(timeline_arr.size()):
		var entry: Dictionary = timeline_arr[i] as Dictionary
		var btn: Button = Button.new()
		var e_era: String = str(entry.get("era", "")).strip_edges()
		var e_title: String = str(entry.get("title", "")).strip_edges()
		if e_title.is_empty(): e_title = "Untitled Event"

		btn.text = "%s\n%s" % [e_title, e_era if not e_era.is_empty() else "Undated"]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0.0, 48.0 if _is_mobile() else 40.0)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 11 if _is_mobile() else 10)
		if i == active_timeline_idx: btn.theme_type_variation = "Breadcrumb"
		var target_i: int = i
		btn.pressed.connect(func() -> void: _load_timeline_entry_to_editor(target_i))
		timeline_list_vbox.add_child(btn)

	_load_timeline_entry_to_editor(active_timeline_idx)


func _load_timeline_entry_to_editor(idx: int) -> void:
	var timeline_arr: Array = journal_data.get("timeline", [])
	if idx < 0 or idx >= timeline_arr.size(): return
	active_timeline_idx = idx

	var entry: Dictionary = timeline_arr[idx] as Dictionary
	t_era_input.text = str(entry.get("era", ""))
	t_title_input.text = str(entry.get("title", ""))
	t_content_edit.text = str(entry.get("content", ""))

	_populate_room_selector(t_room_opt, str(entry.get("room_id", "room_main")))
	_populate_character_chips(t_chars_container, entry.get("character_ids", []), func(c_id: String, active: bool) -> void:
		var ids: Array = entry.get("character_ids", [])
		if active and not ids.has(c_id): ids.append(c_id)
		elif not active and ids.has(c_id): ids.erase(c_id)
		entry["character_ids"] = ids
		_save_silently()
	)


func _render_factions_list() -> void:
	for c: Node in factions_list_vbox.get_children():
		c.queue_free()
	var factions_arr: Array = journal_data.get("factions", [])
	if factions_arr.is_empty():
		var hint: Label = Label.new()
		hint.text = "No factions registered.\nTap + Add Faction to build a guild."
		hint.theme_type_variation = "HintLabel"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 11 if _is_mobile() else 10)
		factions_list_vbox.add_child(hint)
		factions_editor_vbox.visible = false
		active_faction_idx = -1
		return

	factions_editor_vbox.visible = true
	if active_faction_idx < 0 or active_faction_idx >= factions_arr.size():
		active_faction_idx = 0

	for i: int in range(factions_arr.size()):
		var f_dict: Dictionary = factions_arr[i] as Dictionary
		var btn: Button = Button.new()
		var f_name: String = str(f_dict.get("name", "")).strip_edges()
		if f_name.is_empty(): f_name = "Unnamed Faction"
		var f_motto: String = str(f_dict.get("motto", "")).strip_edges()

		btn.text = "%s\n%s" % [f_name, f_motto if not f_motto.is_empty() else "No motto"]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0.0, 48.0 if _is_mobile() else 40.0)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 11 if _is_mobile() else 10)
		if i == active_faction_idx: btn.theme_type_variation = "Breadcrumb"
		var target_i: int = i
		btn.pressed.connect(func() -> void: _load_faction_entry_to_editor(target_i))
		factions_list_vbox.add_child(btn)

	_load_faction_entry_to_editor(active_faction_idx)


func _load_faction_entry_to_editor(idx: int) -> void:
	var factions_arr: Array = journal_data.get("factions", [])
	if idx < 0 or idx >= factions_arr.size(): return
	active_faction_idx = idx

	var f_dict: Dictionary = factions_arr[idx] as Dictionary
	f_name_input.text = str(f_dict.get("name", ""))
	f_motto_input.text = str(f_dict.get("motto", ""))
	f_notes_edit.text = str(f_dict.get("notes", ""))
	f_color_btn.color = Color(str(f_dict.get("badge_color", "#ec4899")))

	var curr_type: String = str(f_dict.get("type", "Guild"))
	var type_idx: int = FACTION_TYPES.find(curr_type)
	f_type_opt.select(maxi(type_idx, 0))

	_populate_faction_leader_selector(f_leader_opt, str(f_dict.get("leader_id", "")))
	_populate_room_selector(f_hq_opt, str(f_dict.get("headquarters_room_id", "room_main")))
	_populate_add_member_dropdown()
	_render_faction_member_cards(f_dict)


func _render_faction_member_cards(f_dict: Dictionary) -> void:
	for c: Node in f_members_vbox.get_children():
		c.queue_free()
	var members_raw: Array = f_dict.get("members", [])
	var normalized_members: Array[Dictionary] = []
	for m_var: Variant in members_raw:
		if m_var is Dictionary:
			normalized_members.append((m_var as Dictionary).duplicate(true))
		elif m_var is String:
			normalized_members.append({"character_id": str(m_var), "rank": "Member"})

	f_dict["members"] = normalized_members

	if normalized_members.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "No enlisted members in this guild yet."
		empty_lbl.theme_type_variation = "HintLabel"
		empty_lbl.add_theme_font_size_override("font_size", 11 if _is_mobile() else 10)
		f_members_vbox.add_child(empty_lbl)
		return

	var is_mob: bool = _is_mobile()
	var row_h: float = 34.0 if is_mob else 28.0

	for i: int in range(normalized_members.size()):
		var m_data: Dictionary = normalized_members[i]
		var c_id: String = str(m_data.get("character_id", ""))
		var c_rank: String = str(m_data.get("rank", "Member"))
		var char_dict: Dictionary = _find_character_by_id(c_id)
		if char_dict.is_empty(): continue

		var card: PanelContainer = PanelContainer.new()
		card.theme_type_variation = "SubPanel"
		card.custom_minimum_size = Vector2(0.0, 42.0 if is_mob else 34.0)
		f_members_vbox.add_child(card)

		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		card.add_child(row)

		var avatar_rect: TextureRect = TextureRect.new()
		avatar_rect.custom_minimum_size = Vector2(36.0 if is_mob else 28.0, 36.0 if is_mob else 28.0)
		avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar_rect.texture = _resolve_character_portrait(char_dict)
		row.add_child(avatar_rect)

		var name_lbl: Label = Label.new()
		name_lbl.text = str(char_dict.get("display_name", "Character"))
		name_lbl.custom_minimum_size = Vector2(110.0 if is_mob else 95.0, 0.0)
		name_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
		row.add_child(name_lbl)

		var rank_input: LineEdit = LineEdit.new()
		rank_input.text = c_rank
		rank_input.placeholder_text = "Rank..."
		rank_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rank_input.custom_minimum_size = Vector2(0.0, row_h)
		rank_input.add_theme_font_size_override("font_size", 11 if is_mob else 10)
		var target_idx: int = i
		rank_input.text_changed.connect(func(new_rank: String) -> void:
			normalized_members[target_idx]["rank"] = new_rank
			_save_silently()
		)
		row.add_child(rank_input)

		var inspect_btn: Button = Button.new()
		inspect_btn.text = "Inspect"
		inspect_btn.custom_minimum_size = Vector2(65.0 if is_mob else 55.0, row_h)
		inspect_btn.focus_mode = Control.FOCUS_NONE
		inspect_btn.add_theme_font_size_override("font_size", 10 if is_mob else 9)
		inspect_btn.pressed.connect(func() -> void: _open_character_lore_card(char_dict))
		row.add_child(inspect_btn)

		var remove_btn: Button = Button.new()
		remove_btn.text = "✕"
		remove_btn.theme_type_variation = "DangerButton"
		remove_btn.custom_minimum_size = Vector2(28.0 if is_mob else 24.0, row_h)
		remove_btn.focus_mode = Control.FOCUS_NONE
		remove_btn.pressed.connect(func() -> void:
			normalized_members.remove_at(target_idx)
			f_dict["members"] = normalized_members
			_save_silently()
			_load_faction_entry_to_editor(active_faction_idx)
		)
		row.add_child(remove_btn)


func _populate_faction_leader_selector(opt_btn: OptionButton, selected_leader_id: String) -> void:
	opt_btn.clear()
	opt_btn.add_item("None / Unassigned", 0)
	opt_btn.set_item_metadata(0, "")
	var sel_idx: int = 0
	for i: int in range(cached_roster.size()):
		var c_dict: Dictionary = cached_roster[i]
		var c_id: String = str(c_dict.get("id", ""))
		var c_name: String = str(c_dict.get("display_name", "Character"))
		var item_idx: int = i + 1
		opt_btn.add_item(c_name, item_idx)
		opt_btn.set_item_metadata(item_idx, c_id)
		if c_id == selected_leader_id: sel_idx = item_idx
	opt_btn.select(sel_idx)


func _populate_add_member_dropdown() -> void:
	f_add_member_opt.clear()
	f_add_member_opt.add_item("+ Enlist...", 0)
	f_add_member_opt.set_item_metadata(0, "")

	var factions_arr: Array = journal_data.get("factions", [])
	var active_f: Dictionary = factions_arr[active_faction_idx] if (active_faction_idx >= 0 and active_faction_idx < factions_arr.size()) else {}
	var enlisted_ids: Array = []
	for m: Variant in active_f.get("members", []):
		if m is Dictionary: enlisted_ids.append(str((m as Dictionary).get("character_id", "")))

	var item_counter: int = 1
	for char_dict: Dictionary in cached_roster:
		var c_id: String = str(char_dict.get("id", ""))
		var c_name: String = str(char_dict.get("display_name", "Character"))
		if not enlisted_ids.has(c_id):
			f_add_member_opt.add_item(c_name, item_counter)
			f_add_member_opt.set_item_metadata(item_counter, c_id)
			item_counter += 1


func _on_add_member_selected(index: int) -> void:
	if index <= 0: return
	var c_id: String = str(f_add_member_opt.get_item_metadata(index))
	if c_id.is_empty(): return

	var factions_arr: Array = journal_data.get("factions", [])
	if active_faction_idx >= 0 and active_faction_idx < factions_arr.size():
		var members_arr: Array = factions_arr[active_faction_idx].get("members", [])
		members_arr.append({"character_id": c_id, "rank": "Member"})
		factions_arr[active_faction_idx]["members"] = members_arr
		_save_silently()
		_load_faction_entry_to_editor(active_faction_idx)


func _on_faction_type_selected(index: int) -> void:
	if index >= 0 and index < FACTION_TYPES.size():
		_commit_active_faction_field("type", FACTION_TYPES[index])


func _on_faction_leader_selected(index: int) -> void:
	var leader_id: String = str(f_leader_opt.get_item_metadata(index))
	_commit_active_faction_field("leader_id", leader_id)


func _on_faction_hq_selected(index: int) -> void:
	var hq_id: String = str(f_hq_opt.get_item_metadata(index))
	_commit_active_faction_field("headquarters_room_id", hq_id)


func _resolve_character_portrait(char_dict: Dictionary) -> Texture2D:
	var custom_f: Dictionary = char_dict.get("custom_fields", {})
	var av_path: String = str(custom_f.get("avatar_path", ""))
	if not av_path.is_empty() and FileAccess.file_exists(av_path):
		return UGCManager.load_texture_from_file(av_path)

	for k: String in ["ugc_texture_path", "texture_path", "path_to_texture", "ugc_tex"]:
		var path_str: String = str(char_dict.get(k, ""))
		if not path_str.is_empty() and FileAccess.file_exists(path_str):
			return UGCManager.load_texture_from_file(path_str)
	return null


func _populate_character_chips(container: Control, active_id_list: Array, on_toggle_callback: Callable) -> void:
	for c: Node in container.get_children():
		c.queue_free()
	if cached_roster.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "No characters in this universe yet."
		empty_lbl.theme_type_variation = "HintLabel"
		empty_lbl.add_theme_font_size_override("font_size", 11 if _is_mobile() else 10)
		container.add_child(empty_lbl)
		return

	var is_mob: bool = _is_mobile()

	for char_dict: Dictionary in cached_roster:
		var c_id: String = str(char_dict.get("id", ""))
		var c_name: String = str(char_dict.get("display_name", "Character"))
		if c_id.is_empty(): continue

		var is_selected: bool = active_id_list.has(c_id)
		var chip_btn: Button = Button.new()
		chip_btn.text = c_name
		chip_btn.toggle_mode = true
		chip_btn.button_pressed = is_selected
		chip_btn.custom_minimum_size = Vector2(0.0, 28.0 if is_mob else 24.0)
		chip_btn.focus_mode = Control.FOCUS_NONE
		chip_btn.add_theme_font_size_override("font_size", 11 if is_mob else 10)
		if is_selected: chip_btn.theme_type_variation = "Breadcrumb"
		var target_cid: String = c_id
		chip_btn.toggled.connect(func(pressed: bool) -> void:
			chip_btn.theme_type_variation = "Breadcrumb" if pressed else ""
			on_toggle_callback.call(target_cid, pressed)
		)
		container.add_child(chip_btn)


func _populate_room_selector(opt_btn: OptionButton, selected_room_id: String) -> void:
	opt_btn.clear()
	var save_dir: String = SaveSystem.get_universe_save_dir(AppState.universe_id)
	var rooms: Array[String] = ["room_main"]

	if not save_dir.is_empty() and DirAccess.dir_exists_absolute(save_dir):
		var dir: DirAccess = DirAccess.open(save_dir)
		if dir:
			dir.list_dir_begin()
			var fname: String = dir.get_next()
			while not fname.is_empty():
				if not dir.current_is_dir() and fname.ends_with(".json"):
					var r_id: String = fname.get_basename()
					if not rooms.has(r_id): rooms.append(r_id)
				fname = dir.get_next()

	var sel_idx: int = 0
	for i: int in range(rooms.size()):
		var r_id: String = rooms[i]
		opt_btn.add_item(r_id.capitalize(), i)
		opt_btn.set_item_metadata(i, r_id)
		if r_id == selected_room_id: sel_idx = i

	opt_btn.select(sel_idx)


func _on_timeline_room_selected(index: int) -> void:
	var timeline_arr: Array = journal_data.get("timeline", [])
	if active_timeline_idx >= 0 and active_timeline_idx < timeline_arr.size():
		timeline_arr[active_timeline_idx]["room_id"] = str(t_room_opt.get_item_metadata(index))
		_save_silently()


func _on_add_timeline_entry() -> void:
	var timeline_arr: Array = journal_data.get("timeline", [])
	var new_entry: Dictionary = {
		"id": "event_%d" % int(Time.get_unix_time_from_system()),
		"era": "New Era",
		"title": "New Story Event",
		"room_id": "room_main",
		"character_ids": [],
		"content": ""
	}
	timeline_arr.insert(0, new_entry)
	journal_data["timeline"] = timeline_arr
	active_timeline_idx = 0
	_save_silently()
	_render_timeline_list()


func _on_delete_timeline_entry() -> void:
	var timeline_arr: Array = journal_data.get("timeline", [])
	if active_timeline_idx >= 0 and active_timeline_idx < timeline_arr.size():
		timeline_arr.remove_at(active_timeline_idx)
		journal_data["timeline"] = timeline_arr
		active_timeline_idx = maxi(active_timeline_idx - 1, 0)
		_save_silently()
		_render_timeline_list()


func _commit_active_timeline_field(field_key: String, value: Variant) -> void:
	var timeline_arr: Array = journal_data.get("timeline", [])
	if active_timeline_idx >= 0 and active_timeline_idx < timeline_arr.size():
		timeline_arr[active_timeline_idx][field_key] = value
		_save_silently()
		if field_key == "title" or field_key == "era":
			var btn_node: Button = timeline_list_vbox.get_child(active_timeline_idx) as Button
			if btn_node:
				var e_title: String = str(timeline_arr[active_timeline_idx].get("title", "Untitled Event"))
				var e_era: String = str(timeline_arr[active_timeline_idx].get("era", "Undated"))
				btn_node.text = "%s\n%s" % [e_title if not e_title.is_empty() else "Untitled Event", e_era if not e_era.is_empty() else "Undated"]


func _on_add_faction_entry() -> void:
	var factions_arr: Array = journal_data.get("factions", [])
	var new_faction: Dictionary = {
		"id": "faction_%d" % int(Time.get_unix_time_from_system()),
		"name": "New Faction",
		"badge_color": "#ec4899",
		"type": "Guild",
		"leader_id": "",
		"headquarters_room_id": "room_main",
		"motto": "",
		"notes": "",
		"members": []
	}
	factions_arr.insert(0, new_faction)
	journal_data["factions"] = factions_arr
	active_faction_idx = 0
	_save_silently()
	_render_factions_list()


func _on_delete_faction_entry() -> void:
	var factions_arr: Array = journal_data.get("factions", [])
	if active_faction_idx >= 0 and active_faction_idx < factions_arr.size():
		factions_arr.remove_at(active_faction_idx)
		journal_data["factions"] = factions_arr
		active_faction_idx = maxi(active_faction_idx - 1, 0)
		_save_silently()
		_render_factions_list()


func _commit_active_faction_field(field_key: String, value: Variant) -> void:
	var factions_arr: Array = journal_data.get("factions", [])
	if active_faction_idx >= 0 and active_faction_idx < factions_arr.size():
		factions_arr[active_faction_idx][field_key] = value
		_save_silently()
		if field_key == "name" or field_key == "motto":
			var btn_node: Button = factions_list_vbox.get_child(active_faction_idx) as Button
			if btn_node:
				var f_name: String = str(factions_arr[active_faction_idx].get("name", "Unnamed Faction"))
				var f_motto: String = str(factions_arr[active_faction_idx].get("motto", "No motto"))
				btn_node.text = "%s\n%s" % [f_name if not f_name.is_empty() else "Unnamed Faction", f_motto if not f_motto.is_empty() else "No motto"]


func _on_faction_color_changed(new_color: Color) -> void:
	_commit_active_faction_field("badge_color", new_color.to_html(false))


func _find_character_by_id(char_id: String) -> Dictionary:
	for c: Dictionary in cached_roster:
		if str(c.get("id", "")) == char_id: return c
	return {}


func _open_character_lore_card(char_dict: Dictionary) -> void:
	if char_dict.is_empty(): return
	var lore_cards: Array[Node] = get_tree().get_nodes_in_group("character_lore_card")
	var card_ui: Node = lore_cards[0] if not lore_cards.is_empty() else get_tree().root.find_child("CharacterLoreCard", true, false)
	if card_ui and card_ui.has_method("open_card_for_character_dict"):
		card_ui.call("open_card_for_character_dict", char_dict)


func _save_silently() -> void:
	SaveSystem.save_universe_journal(AppState.universe_id, journal_data)


func _on_save_button_pressed() -> void:
	_save_silently()
	EventBus.notification_requested.emit("Saved: World Journal", true)


func _clamp_popup(opt_btn: OptionButton) -> void:
	if not opt_btn: return
	var p: PopupMenu = opt_btn.get_popup()
	if p:
		p.max_size = Vector2i(4000, 200)
		p.about_to_popup.connect(func() -> void: p.max_size = Vector2i(4000, 200))


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		close_dialog()
