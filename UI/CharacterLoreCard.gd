# ==============================================================================
# OWNWORLD — CHARACTER LORE CARD & PROFILE STUDIO (LANDSCAPE DUAL-OS ADAPTIVE)
# File: res://UI/CharacterLoreCard.gd
# Base Class: CanvasLayer (class_name CharacterLoreCard)
#
# Responsibility: Comprehensive character profile management. Features 3-tab
# identity editing (Bio/Status/Traits, Symmetrical Family Trees & Directional
# Feelings, Story Notes), custom avatar picking, and mobile keyboard dodging.
# ==============================================================================

class_name CharacterLoreCard
extends CanvasLayer

enum CardTab { PROFILE, BONDS, NOTES }
var current_tab: CardTab = CardTab.PROFILE

const MAX_CARD_WIDTH: float = 760.0
const MAX_CARD_HEIGHT: float = 580.0

var root_backdrop: Control = null
var center_container: CenterContainer = null
var root_panel: PanelContainer = null
var active_entity: OwnEntity = null
var fallback_char_dict: Dictionary = {}
var asset_picker: AssetPickerDialog = null

# Header Controls
var header_lbl: Label = null
var btn_journal: Button = null
var btn_close: Button = null

# Tab Navigation Buttons
var btn_tab_profile: Button = null
var btn_tab_bonds: Button = null
var btn_tab_notes: Button = null

# Tab Content Containers
var tab_profile_container: VBoxContainer = null
var tab_bonds_container: VBoxContainer = null
var tab_notes_container: VBoxContainer = null

# Tab 1: Profile & Identity Controls
var avatar_btn: Button = null
var avatar_texture_rect: TextureRect = null
var avatar_path_stored: String = ""

var name_edit: LineEdit = null
var pronouns_edit: LineEdit = null
var role_edit: LineEdit = null
var status_opt: OptionButton = null
var traits_vbox: VBoxContainer = null
var btn_add_trait: Button = null

# Tab 2: Family & Relationships Controls
var family_vbox: VBoxContainer = null
var btn_add_family: Button = null
var feelings_vbox: VBoxContainer = null
var btn_add_feeling: Button = null

# Tab 3: Backstory & Notes Controls
var lore_text_edit: TextEdit = null

# Action Buttons
var btn_save: Button = null

var initial_family_snapshot: Array[Dictionary] = []
var initial_feelings_snapshot: Array[Dictionary] = []

const LIFE_STATUSES: Array[String] = [
	"Living / Active",
	"Passed Away / In Spirit",
	"Unknown / Missing"
]

const FAMILY_PRESETS: Array[String] = [
	"Parent (Biological)",
	"Parent (Adoptive / Guardian)",
	"Child (Biological)",
	"Child (Adopted / Ward)",
	"Sibling",
	"Twin",
	"Spouse / Married",
	"Partner / Committed",
	"Ex-Partner / Divorced",
	"Separated"
]

const FEELING_PRESETS: Array[String] = [
	"Best Friend",
	"Close Friend",
	"Friend / Ally",
	"In Love / Deep Bond",
	"Secret Crush",
	"Rival / Friendly Competition",
	"Fierce Rival (Clashing)",
	"Enemy / Hostile",
	"Distant / Acquaintance",
	"Estranged / Cutoff",
	"Mentor / Teacher",
	"Student / Apprentice",
	"Caretaker / Guide",
	"Protective Of",
	"Guarded / Suspicious Of"
]


func _ready() -> void:
	name = "CharacterLoreCard"
	layer = 130
	visible = false
	add_to_group("modal_ui")
	add_to_group("character_lore_card")
	_build_ui()
	_connect_system_signals()
	_apply_theme_styling()
	_update_responsive_layout()
	_setup_keyboard_dodging()

	asset_picker = AssetPickerDialog.new()
	add_child(asset_picker)


func _is_mobile() -> bool:
	return ThemeEngine.is_mobile_platform()


func _connect_system_signals() -> void:
	if not ThemeService.theme_changed.is_connected(_on_theme_changed):
		ThemeService.theme_changed.connect(_on_theme_changed)

	var tree: SceneTree = get_tree()
	if tree and tree.root and not tree.root.size_changed.is_connected(_update_responsive_layout):
		tree.root.size_changed.connect(_update_responsive_layout)


func _setup_keyboard_dodging() -> void:
	if not _is_mobile(): return
	var inputs: Array[Control] = [name_edit, pronouns_edit, role_edit, lore_text_edit]
	for input in inputs:
		if input != null:
			input.focus_entered.connect(_on_input_focus_entered)
			input.focus_exited.connect(_on_input_focus_exited)


func _on_input_focus_entered() -> void:
	if _is_mobile() and center_container != null:
		await get_tree().process_frame
		await get_tree().process_frame
		var kb_height: float = DisplayServer.virtual_keyboard_get_height()
		if kb_height > 0:
			var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(center_container, "position:y", -kb_height * 0.45, 0.25)


func _on_input_focus_exited() -> void:
	if _is_mobile() and center_container != null:
		var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(center_container, "position:y", 0.0, 0.25)


func _update_responsive_layout() -> void:
	if not is_instance_valid(root_panel): return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280.0, 720.0)
	var is_mob: bool = _is_mobile()

	var target_w: float = clampf(vp_size.x * 0.94, 320.0, MAX_CARD_WIDTH)
	var target_h: float = clampf(vp_size.y * (0.92 if is_mob else 0.88), 300.0, MAX_CARD_HEIGHT)
	root_panel.custom_minimum_size = Vector2(target_w, target_h)
	root_panel.size = Vector2(target_w, target_h)


func _on_theme_changed(_theme_data: Dictionary) -> void:
	_apply_theme_styling()
	if visible: _switch_tab(current_tab)


func _apply_theme_styling() -> void:
	var c_bg: Color = ThemeService.get_color("panel_background", "#fff5f7")
	var c_border: Color = ThemeService.get_color("panel_border", "#f9a8d4")
	var c_accent: Color = ThemeService.get_color("accent_primary", "#ec4899")
	var radius: int = ThemeService.get_corner_radius()

	if root_panel:
		var p_style: StyleBoxFlat = StyleBoxFlat.new()
		p_style.bg_color = c_bg
		p_style.border_color = c_border
		p_style.set_border_width_all(2)
		p_style.set_corner_radius_all(radius + 2)
		p_style.content_margin_left = 14
		p_style.content_margin_right = 14
		p_style.content_margin_top = 10
		p_style.content_margin_bottom = 10
		root_panel.add_theme_stylebox_override("panel", p_style)

	if header_lbl: header_lbl.add_theme_color_override("font_color", c_accent)

	var save_icon: Texture2D = ThemeService.get_icon("icon_save")
	if save_icon and btn_save: btn_save.icon = save_icon

	var close_icon: Texture2D = ThemeService.get_icon("icon_close")
	if close_icon and btn_close: btn_close.icon = close_icon

	_switch_tab(current_tab)


func _build_ui() -> void:
	var is_mob: bool = _is_mobile()
	var row_h: float = 34.0 if is_mob else 28.0

	root_backdrop = Control.new()
	root_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root_backdrop.gui_input.connect(_on_backdrop_gui_input)

	var bg_dim: ColorRect = ColorRect.new()
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_dim.color = Color(0.0, 0.0, 0.0, 0.65)
	bg_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_backdrop.add_child(bg_dim)
	add_child(root_backdrop)

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

	var header_hbox: HBoxContainer = HBoxContainer.new()
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	header_hbox.add_theme_constant_override("separation", 6)
	main_vbox.add_child(header_hbox)

	header_lbl = Label.new()
	header_lbl.text = "Character Profile"
	header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_lbl.theme_type_variation = "HeaderLabel"
	header_lbl.add_theme_font_size_override("font_size", 14 if is_mob else 12)
	header_hbox.add_child(header_lbl)

	btn_journal = Button.new()
	btn_journal.text = " Open World Journal"
	btn_journal.custom_minimum_size = Vector2(160.0 if is_mob else 135.0, row_h)
	btn_journal.focus_mode = Control.FOCUS_NONE
	btn_journal.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	btn_journal.add_theme_constant_override("icon_max_width", 12)
	var book_icon: Texture2D = ThemeService.get_icon("icon_room")
	if book_icon: btn_journal.icon = book_icon
	btn_journal.pressed.connect(_on_open_journal_from_card)
	header_hbox.add_child(btn_journal)

	btn_close = Button.new()
	btn_close.custom_minimum_size = Vector2(28.0 if is_mob else 22.0, 28.0 if is_mob else 22.0)
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.add_theme_constant_override("icon_max_width", 12)
	var close_icon: Texture2D = ThemeService.get_icon("icon_close")
	if close_icon: btn_close.icon = close_icon
	else: btn_close.text = "✕"
	btn_close.pressed.connect(save_and_close)
	header_hbox.add_child(btn_close)

	var tab_strip: HBoxContainer = HBoxContainer.new()
	tab_strip.add_theme_constant_override("separation", 6)
	main_vbox.add_child(tab_strip)

	btn_tab_profile = _create_tab_button("Profile & Identity", "icon_assets", CardTab.PROFILE, row_h)
	tab_strip.add_child(btn_tab_profile)

	btn_tab_bonds = _create_tab_button("Family & Relationships", "icon_cast", CardTab.BONDS, row_h)
	tab_strip.add_child(btn_tab_bonds)

	btn_tab_notes = _create_tab_button("Backstory & Notes", "icon_tag", CardTab.NOTES, row_h)
	tab_strip.add_child(btn_tab_notes)

	main_vbox.add_child(HSeparator.new())

	var content_holder: PanelContainer = PanelContainer.new()
	content_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_holder.theme_type_variation = "SubPanel"
	main_vbox.add_child(content_holder)

	tab_profile_container = VBoxContainer.new()
	tab_profile_container.add_theme_constant_override("separation", 6)
	tab_profile_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_profile_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_holder.add_child(tab_profile_container)
	_build_profile_tab(row_h)

	tab_bonds_container = VBoxContainer.new()
	tab_bonds_container.add_theme_constant_override("separation", 6)
	tab_bonds_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_bonds_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_bonds_container.visible = false
	content_holder.add_child(tab_bonds_container)
	_build_bonds_tab(row_h)

	tab_notes_container = VBoxContainer.new()
	tab_notes_container.add_theme_constant_override("separation", 6)
	tab_notes_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_notes_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_notes_container.visible = false
	content_holder.add_child(tab_notes_container)
	_build_notes_tab()

	main_vbox.add_child(HSeparator.new())

	btn_save = Button.new()
	btn_save.text = " Save Profile & Close"
	btn_save.custom_minimum_size = Vector2(0.0, row_h + 4.0)
	btn_save.focus_mode = Control.FOCUS_NONE
	btn_save.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	btn_save.add_theme_constant_override("icon_max_width", 16)
	var save_icon: Texture2D = ThemeService.get_icon("icon_save")
	if save_icon: btn_save.icon = save_icon
	btn_save.pressed.connect(save_and_close)
	main_vbox.add_child(btn_save)

	_switch_tab(CardTab.PROFILE)


func _create_tab_button(title: String, icon_key: String, tab_target: CardTab, row_h: float) -> Button:
	var is_mob: bool = _is_mobile()
	var btn: Button = Button.new()
	btn.text = " " + title
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0.0, row_h)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_constant_override("icon_max_width", 14)
	btn.add_theme_constant_override("h_separation", 6)
	btn.add_theme_font_size_override("font_size", 11 if is_mob else 10)

	var icon_tex: Texture2D = ThemeService.get_icon(icon_key)
	if icon_tex: btn.icon = icon_tex

	btn.pressed.connect(func() -> void: _switch_tab(tab_target))
	return btn


func _switch_tab(target: CardTab) -> void:
	current_tab = target
	tab_profile_container.visible = (target == CardTab.PROFILE)
	tab_bonds_container.visible = (target == CardTab.BONDS)
	tab_notes_container.visible = (target == CardTab.NOTES)

	var c_accent: Color = ThemeService.get_color("accent_primary", "#ec4899")
	var rad: int = ThemeService.get_corner_radius()

	var tab_buttons: Array[Dictionary] = [
		{"btn": btn_tab_profile, "active": target == CardTab.PROFILE},
		{"btn": btn_tab_bonds, "active": target == CardTab.BONDS},
		{"btn": btn_tab_notes, "active": target == CardTab.NOTES}
	]

	for entry: Dictionary in tab_buttons:
		var btn: Button = entry["btn"] as Button
		var is_act: bool = bool(entry["active"])

		btn.remove_theme_stylebox_override("normal")
		btn.remove_theme_stylebox_override("hover")
		btn.remove_theme_stylebox_override("pressed")
		btn.remove_theme_stylebox_override("focus")
		btn.remove_theme_color_override("font_color")
		btn.remove_theme_color_override("icon_normal_color")

		if is_act:
			var s_act: StyleBoxFlat = StyleBoxFlat.new()
			s_act.bg_color = c_accent
			s_act.border_color = c_accent
			s_act.set_border_width_all(1)
			s_act.set_corner_radius_all(rad)
			s_act.content_margin_left = 8
			s_act.content_margin_right = 8
			s_act.content_margin_top = 4
			s_act.content_margin_bottom = 4

			btn.add_theme_stylebox_override("normal", s_act)
			btn.add_theme_stylebox_override("hover", s_act)
			btn.add_theme_stylebox_override("pressed", s_act)
			btn.add_theme_stylebox_override("focus", s_act)
			btn.add_theme_color_override("font_color", Color.WHITE)
			btn.add_theme_color_override("icon_normal_color", Color.WHITE)


func _build_profile_tab(row_h: float) -> void:
	var is_mob: bool = _is_mobile()

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = false
	tab_profile_container.add_child(scroll)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	var top_profile_hbox: HBoxContainer = HBoxContainer.new()
	top_profile_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(top_profile_hbox)

	var avatar_vbox: VBoxContainer = VBoxContainer.new()
	avatar_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_profile_hbox.add_child(avatar_vbox)

	avatar_btn = Button.new()
	avatar_btn.custom_minimum_size = Vector2(80.0 if is_mob else 68.0, 80.0 if is_mob else 68.0)
	avatar_btn.focus_mode = Control.FOCUS_NONE
	avatar_btn.pressed.connect(_on_avatar_btn_pressed)
	avatar_vbox.add_child(avatar_btn)

	avatar_texture_rect = TextureRect.new()
	avatar_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	avatar_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_btn.add_child(avatar_texture_rect)

	var avatar_hint: Label = Label.new()
	avatar_hint.text = "Set Custom Icon"
	avatar_hint.theme_type_variation = "HintLabel"
	avatar_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_hint.add_theme_font_size_override("font_size", 10 if is_mob else 9)
	avatar_vbox.add_child(avatar_hint)

	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)
	top_profile_hbox.add_child(info_vbox)

	var lbl_name: Label = Label.new()
	lbl_name.text = "Character Name:"
	lbl_name.theme_type_variation = "HintLabel"
	lbl_name.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	info_vbox.add_child(lbl_name)

	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Name..."
	name_edit.custom_minimum_size = Vector2(0.0, row_h)
	info_vbox.add_child(name_edit)

	var row_grid: GridContainer = GridContainer.new()
	row_grid.columns = 2
	row_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_grid.add_theme_constant_override("h_separation", 8)
	vbox.add_child(row_grid)

	var col_pronouns: VBoxContainer = VBoxContainer.new()
	col_pronouns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_grid.add_child(col_pronouns)

	var lbl_p: Label = Label.new()
	lbl_p.text = "Pronouns:"
	lbl_p.theme_type_variation = "HintLabel"
	lbl_p.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	col_pronouns.add_child(lbl_p)

	pronouns_edit = LineEdit.new()
	pronouns_edit.placeholder_text = "e.g. She/Her, They/Them..."
	pronouns_edit.custom_minimum_size = Vector2(0.0, row_h)
	col_pronouns.add_child(pronouns_edit)

	var col_role: VBoxContainer = VBoxContainer.new()
	col_role.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_grid.add_child(col_role)

	var lbl_r: Label = Label.new()
	lbl_r.text = "Role / Title:"
	lbl_r.theme_type_variation = "HintLabel"
	lbl_r.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	col_role.add_child(lbl_r)

	role_edit = LineEdit.new()
	role_edit.placeholder_text = "e.g. Baker, Knight..."
	role_edit.custom_minimum_size = Vector2(0.0, row_h)
	col_role.add_child(role_edit)

	var col_status: VBoxContainer = VBoxContainer.new()
	col_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(col_status)

	var lbl_status: Label = Label.new()
	lbl_status.text = "Life Status:"
	lbl_status.theme_type_variation = "HintLabel"
	lbl_status.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	col_status.add_child(lbl_status)

	status_opt = OptionButton.new()
	status_opt.custom_minimum_size = Vector2(0.0, row_h)
	_enforce_dropdown_popup_limits(status_opt, 200)
	for i: int in range(LIFE_STATUSES.size()):
		status_opt.add_item(LIFE_STATUSES[i], i)
	col_status.add_child(status_opt)

	vbox.add_child(HSeparator.new())

	var trait_header_row: HBoxContainer = HBoxContainer.new()
	trait_header_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(trait_header_row)

	var lbl_traits: Label = Label.new()
	lbl_traits.text = "Custom Details & Traits:"
	lbl_traits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_traits.theme_type_variation = "HintLabel"
	lbl_traits.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	trait_header_row.add_child(lbl_traits)

	btn_add_trait = Button.new()
	btn_add_trait.text = " + Add Detail"
	btn_add_trait.custom_minimum_size = Vector2(100.0 if is_mob else 85.0, 28.0 if is_mob else 24.0)
	btn_add_trait.focus_mode = Control.FOCUS_NONE
	btn_add_trait.add_theme_font_size_override("font_size", 10)
	btn_add_trait.pressed.connect(func() -> void: _add_trait_row("", "", row_h))
	trait_header_row.add_child(btn_add_trait)

	traits_vbox = VBoxContainer.new()
	traits_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	traits_vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(traits_vbox)


func _add_trait_row(trait_key: String, trait_value: String, row_h: float) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)

	var key_input: LineEdit = LineEdit.new()
	key_input.text = trait_key.strip_edges()
	key_input.placeholder_text = "Detail (e.g. Birthday, Species)"
	key_input.custom_minimum_size = Vector2(140.0, row_h)
	if _is_mobile():
		key_input.focus_entered.connect(_on_input_focus_entered)
		key_input.focus_exited.connect(_on_input_focus_exited)
	row.add_child(key_input)

	var val_input: LineEdit = LineEdit.new()
	val_input.text = trait_value.strip_edges()
	val_input.placeholder_text = "Value (e.g. May 14, Elf)"
	val_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_input.custom_minimum_size = Vector2(0.0, row_h)
	if _is_mobile():
		val_input.focus_entered.connect(_on_input_focus_entered)
		val_input.focus_exited.connect(_on_input_focus_exited)
	row.add_child(val_input)

	var btn_del: Button = Button.new()
	btn_del.text = "✕"
	btn_del.custom_minimum_size = Vector2(28.0, row_h)
	btn_del.theme_type_variation = "DangerButton"
	btn_del.focus_mode = Control.FOCUS_NONE
	btn_del.pressed.connect(func() -> void: row.queue_free())
	row.add_child(btn_del)

	traits_vbox.add_child(row)


func _on_avatar_btn_pressed() -> void:
	if asset_picker != null:
		asset_picker.open_picker("Choose Character Portrait Drawing", "", func(_art_name: String, _tex: Texture2D, file_path: String) -> void:
			_on_avatar_file_selected(file_path)
		)


func _on_avatar_file_selected(file_path: String) -> void:
	avatar_path_stored = file_path.strip_edges()
	_update_avatar_preview()


func _update_avatar_preview() -> void:
	if not avatar_texture_rect:
		return
	avatar_texture_rect.texture = _resolve_character_portrait(
		active_entity.to_dict() if is_instance_valid(active_entity) else fallback_char_dict,
		avatar_path_stored
	)


func _resolve_character_portrait(char_dict: Dictionary, explicit_avatar_path: String = "") -> Texture2D:
	if not explicit_avatar_path.is_empty() and FileAccess.file_exists(explicit_avatar_path):
		return UGCManager.get_thumbnail_async(explicit_avatar_path, 128)

	var custom_f: Dictionary = char_dict.get("custom_fields", {})
	var av_path: String = str(custom_f.get("avatar_path", "")).strip_edges()
	if not av_path.is_empty() and FileAccess.file_exists(av_path):
		return UGCManager.get_thumbnail_async(av_path, 128)

	for k: String in ["ugc_texture_path", "texture_path", "path_to_texture", "ugc_tex"]:
		var path_str: String = str(char_dict.get(k, "")).strip_edges()
		if not path_str.is_empty() and FileAccess.file_exists(path_str):
			return UGCManager.get_thumbnail_async(path_str, 128)

	return null


func _build_bonds_tab(row_h: float) -> void:
	var is_mob: bool = _is_mobile()

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = false
	tab_bonds_container.add_child(scroll)

	var main_content: VBoxContainer = VBoxContainer.new()
	main_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_content.add_theme_constant_override("separation", 8)
	scroll.add_child(main_content)

	var family_header_row: HBoxContainer = HBoxContainer.new()
	family_header_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main_content.add_child(family_header_row)

	var fam_title_vbox: VBoxContainer = VBoxContainer.new()
	fam_title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	family_header_row.add_child(fam_title_vbox)

	var lbl_fam_title: Label = Label.new()
	lbl_fam_title.text = "Family Ties"
	lbl_fam_title.theme_type_variation = "HeaderLabel"
	lbl_fam_title.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	fam_title_vbox.add_child(lbl_fam_title)

	var lbl_fam_hint: Label = Label.new()
	lbl_fam_hint.text = "Parents, children, siblings, and partners (automatically linked both ways)."
	lbl_fam_hint.theme_type_variation = "HintLabel"
	lbl_fam_hint.add_theme_font_size_override("font_size", 10 if is_mob else 9)
	fam_title_vbox.add_child(lbl_fam_hint)

	btn_add_family = Button.new()
	btn_add_family.text = " + Add Family Member"
	btn_add_family.custom_minimum_size = Vector2(160.0 if is_mob else 140.0, row_h)
	btn_add_family.focus_mode = Control.FOCUS_NONE
	btn_add_family.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	btn_add_family.pressed.connect(func() -> void: _add_family_row("", "Sibling", "", row_h))
	family_header_row.add_child(btn_add_family)

	family_vbox = VBoxContainer.new()
	family_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	family_vbox.add_theme_constant_override("separation", 6)
	main_content.add_child(family_vbox)

	main_content.add_child(HSeparator.new())

	var feel_header_row: HBoxContainer = HBoxContainer.new()
	feel_header_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main_content.add_child(feel_header_row)

	var feel_title_vbox: VBoxContainer = VBoxContainer.new()
	feel_title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feel_header_row.add_child(feel_title_vbox)

	var lbl_feel_title: Label = Label.new()
	lbl_feel_title.text = "Feelings & Relationships"
	lbl_feel_title.theme_type_variation = "HeaderLabel"
	lbl_feel_title.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	feel_title_vbox.add_child(lbl_feel_title)

	var lbl_feel_hint: Label = Label.new()
	lbl_feel_hint.text = "How this character feels about others (friendships, rivalries, crushes)."
	lbl_feel_hint.theme_type_variation = "HintLabel"
	lbl_feel_hint.add_theme_font_size_override("font_size", 10 if is_mob else 9)
	feel_title_vbox.add_child(lbl_feel_hint)

	btn_add_feeling = Button.new()
	btn_add_feeling.text = " + Add Relationship"
	btn_add_feeling.custom_minimum_size = Vector2(160.0 if is_mob else 140.0, row_h)
	btn_add_feeling.focus_mode = Control.FOCUS_NONE
	btn_add_feeling.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	btn_add_feeling.pressed.connect(func() -> void: _add_feeling_row("", "Friend / Ally", "", row_h))
	feel_header_row.add_child(btn_add_feeling)

	feelings_vbox = VBoxContainer.new()
	feelings_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feelings_vbox.add_theme_constant_override("separation", 6)
	main_content.add_child(feelings_vbox)


func _add_family_row(target_name: String, relation_type: String, notes: String, row_h: float) -> void:
	var is_mob: bool = _is_mobile()
	var card: PanelContainer = _create_card_container()
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var top_hbox: HBoxContainer = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(top_hbox)

	var target_option: OptionButton = OptionButton.new()
	target_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_option.custom_minimum_size = Vector2(0.0, row_h)
	_enforce_dropdown_popup_limits(target_option, 200)
	top_hbox.add_child(target_option)

	var all_chars: Array[String] = _get_universe_character_names()
	var sel_idx: int = 0
	target_option.add_item("Select Family Member...", 0)
	for i: int in range(all_chars.size()):
		var c_name: String = all_chars[i]
		target_option.add_item(c_name, i + 1)
		if c_name == target_name: sel_idx = i + 1
	target_option.selected = sel_idx

	var rel_option: OptionButton = OptionButton.new()
	rel_option.custom_minimum_size = Vector2(190.0 if is_mob else 160.0, row_h)
	_enforce_dropdown_popup_limits(rel_option, 200)
	top_hbox.add_child(rel_option)

	var rel_sel: int = 0
	for i: int in range(FAMILY_PRESETS.size()):
		var p_rel: String = FAMILY_PRESETS[i]
		rel_option.add_item(p_rel, i)
		if p_rel.to_lower() == relation_type.to_lower(): rel_sel = i
	rel_option.selected = rel_sel

	var btn_del: Button = Button.new()
	btn_del.text = "✕"
	btn_del.custom_minimum_size = Vector2(30.0, row_h)
	btn_del.theme_type_variation = "DangerButton"
	btn_del.focus_mode = Control.FOCUS_NONE
	btn_del.pressed.connect(func() -> void: card.queue_free())
	top_hbox.add_child(btn_del)

	var notes_edit: LineEdit = LineEdit.new()
	notes_edit.text = notes.strip_edges()
	notes_edit.placeholder_text = "Marriage date, adoption details, or family notes..."
	notes_edit.custom_minimum_size = Vector2(0.0, row_h)
	if is_mob:
		notes_edit.focus_entered.connect(_on_input_focus_entered)
		notes_edit.focus_exited.connect(_on_input_focus_exited)
	vbox.add_child(notes_edit)

	family_vbox.add_child(card)


func _add_feeling_row(target_name: String, relation_type: String, notes: String, row_h: float) -> void:
	var is_mob: bool = _is_mobile()
	var card: PanelContainer = _create_card_container()
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var top_hbox: HBoxContainer = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(top_hbox)

	var target_option: OptionButton = OptionButton.new()
	target_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_option.custom_minimum_size = Vector2(0.0, row_h)
	_enforce_dropdown_popup_limits(target_option, 200)
	top_hbox.add_child(target_option)

	var all_chars: Array[String] = _get_universe_character_names()
	var sel_idx: int = 0
	target_option.add_item("Select Character...", 0)
	for i: int in range(all_chars.size()):
		var c_name: String = all_chars[i]
		target_option.add_item(c_name, i + 1)
		if c_name == target_name: sel_idx = i + 1
	target_option.selected = sel_idx

	var rel_option: OptionButton = OptionButton.new()
	rel_option.custom_minimum_size = Vector2(190.0 if is_mob else 160.0, row_h)
	_enforce_dropdown_popup_limits(rel_option, 200)
	top_hbox.add_child(rel_option)

	var rel_sel: int = 0
	for i: int in range(FEELING_PRESETS.size()):
		var p_rel: String = FEELING_PRESETS[i]
		rel_option.add_item(p_rel, i)
		if p_rel.to_lower() == relation_type.to_lower(): rel_sel = i
	rel_option.selected = rel_sel

	var btn_del: Button = Button.new()
	btn_del.text = "✕"
	btn_del.custom_minimum_size = Vector2(30.0, row_h)
	btn_del.theme_type_variation = "DangerButton"
	btn_del.focus_mode = Control.FOCUS_NONE
	btn_del.pressed.connect(func() -> void: card.queue_free())
	top_hbox.add_child(btn_del)

	var notes_edit: LineEdit = LineEdit.new()
	notes_edit.text = notes.strip_edges()
	notes_edit.placeholder_text = "Why they feel this way, history of rivalries, or secret feelings..."
	notes_edit.custom_minimum_size = Vector2(0.0, row_h)
	if is_mob:
		notes_edit.focus_entered.connect(_on_input_focus_entered)
		notes_edit.focus_exited.connect(_on_input_focus_exited)
	vbox.add_child(notes_edit)

	feelings_vbox.add_child(card)


func _create_card_container() -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.theme_type_variation = "SubPanel"
	return card


func _enforce_dropdown_popup_limits(opt_btn: OptionButton, max_height: int = 200) -> void:
	if not is_instance_valid(opt_btn): return
	var pop: PopupMenu = opt_btn.get_popup()
	if pop:
		pop.max_size = Vector2i(4000, max_height)
		pop.about_to_popup.connect(func() -> void: pop.max_size = Vector2i(4000, max_height))


func _build_notes_tab() -> void:
	var lbl_lore: Label = Label.new()
	lbl_lore.text = "Backstory, Personality & Story Notes:"
	lbl_lore.theme_type_variation = "HintLabel"
	lbl_lore.add_theme_font_size_override("font_size", 11 if _is_mobile() else 10)
	tab_notes_container.add_child(lbl_lore)

	lore_text_edit = TextEdit.new()
	lore_text_edit.placeholder_text = "Write your character's backstory, traditions, secrets, or personality quirks here..."
	lore_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	lore_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lore_text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lore_text_edit.custom_minimum_size = Vector2(0.0, 160.0)
	tab_notes_container.add_child(lore_text_edit)


func open_card(entity: OwnEntity) -> void:
	if not is_instance_valid(entity): return
	active_entity = entity
	fallback_char_dict = {}
	_update_responsive_layout()
	_apply_theme_styling()
	_populate_from_data(entity.display_name, entity.custom_fields)


func open_card_for_character_dict(char_dict: Dictionary) -> void:
	active_entity = null
	fallback_char_dict = char_dict.duplicate(true)
	_update_responsive_layout()
	_apply_theme_styling()
	_populate_from_data(str(char_dict.get("display_name", "Character")), char_dict.get("custom_fields", {}))


func _populate_from_data(char_name: String, fields: Dictionary) -> void:
	var row_h: float = 34.0 if _is_mobile() else 28.0

	name_edit.text = char_name.strip_edges()
	pronouns_edit.text = str(fields.get("pronouns", "")).strip_edges()
	role_edit.text = str(fields.get("role", "")).strip_edges()
	lore_text_edit.text = str(fields.get("lore", ""))
	avatar_path_stored = str(fields.get("avatar_path", "")).strip_edges()

	var status_val: String = str(fields.get("life_status", "Living / Active")).strip_edges()
	var st_idx: int = LIFE_STATUSES.find(status_val)
	status_opt.select(maxi(st_idx, 0))

	_update_avatar_preview()

	for c: Node in traits_vbox.get_children(): c.queue_free()
	var traits_dict: Dictionary = fields.get("traits", {})
	for k: Variant in traits_dict.keys():
		_add_trait_row(str(k), str(traits_dict[k]), row_h)

	for c: Node in family_vbox.get_children(): c.queue_free()
	var raw_family: Array = fields.get("family_ties", [])
	initial_family_snapshot.clear()
	for f_var: Variant in raw_family:
		if f_var is Dictionary:
			var f_dict: Dictionary = (f_var as Dictionary).duplicate(true)
			initial_family_snapshot.append(f_dict)
			_add_family_row(str(f_dict.get("target_name", "")), str(f_dict.get("relation_type", "Sibling")), str(f_dict.get("notes", "")), row_h)

	for c: Node in feelings_vbox.get_children(): c.queue_free()
	var raw_feelings: Array = fields.get("relationships", [])
	initial_feelings_snapshot.clear()
	for e_var: Variant in raw_feelings:
		if e_var is Dictionary:
			var e_dict: Dictionary = (e_var as Dictionary).duplicate(true)
			initial_feelings_snapshot.append(e_dict)
			_add_feeling_row(str(e_dict.get("target_name", "")), str(e_dict.get("relation_type", "Friend / Ally")), str(e_dict.get("notes", "")), row_h)

	_switch_tab(CardTab.PROFILE)
	visible = true


func save_and_close() -> void:
	var new_char_name: String = name_edit.text.strip_edges()
	if new_char_name.is_empty():
		new_char_name = active_entity.display_name if is_instance_valid(active_entity) else str(fallback_char_dict.get("display_name", "Character"))

	var updated_traits: Dictionary = {}
	for child: Node in traits_vbox.get_children():
		if child is HBoxContainer:
			var k_node: LineEdit = child.get_child(0) as LineEdit
			var v_node: LineEdit = child.get_child(1) as LineEdit
			if k_node and v_node and not k_node.text.strip_edges().is_empty():
				updated_traits[k_node.text.strip_edges()] = v_node.text.strip_edges()

	var updated_family: Array[Dictionary] = _scrape_bond_cards(family_vbox, "Sibling")
	var updated_feelings: Array[Dictionary] = _scrape_bond_cards(feelings_vbox, "Friend / Ally")
	var status_text: String = LIFE_STATUSES[status_opt.selected] if status_opt.selected >= 0 else "Living / Active"

	if is_instance_valid(active_entity):
		active_entity.display_name = new_char_name
		active_entity.custom_fields["pronouns"] = pronouns_edit.text.strip_edges()
		active_entity.custom_fields["role"] = role_edit.text.strip_edges()
		active_entity.custom_fields["lore"] = lore_text_edit.text
		active_entity.custom_fields["avatar_path"] = avatar_path_stored
		active_entity.custom_fields["life_status"] = status_text
		active_entity.custom_fields["traits"] = updated_traits
		active_entity.custom_fields["family_ties"] = updated_family
		active_entity.custom_fields["relationships"] = updated_feelings

		_enforce_symmetrical_family(new_char_name, updated_family, initial_family_snapshot)
		_sync_directional_feelings(new_char_name, updated_feelings, initial_feelings_snapshot)
		SaveSystem.update_character_data_in_cast(active_entity.to_dict())
		SaveSystem.save_current_room_state()

	elif not fallback_char_dict.is_empty():
		fallback_char_dict["display_name"] = new_char_name
		var c_fields: Dictionary = fallback_char_dict.get("custom_fields", {})
		c_fields["pronouns"] = pronouns_edit.text.strip_edges()
		c_fields["role"] = role_edit.text.strip_edges()
		c_fields["lore"] = lore_text_edit.text
		c_fields["avatar_path"] = avatar_path_stored
		c_fields["life_status"] = status_text
		c_fields["traits"] = updated_traits
		c_fields["family_ties"] = updated_family
		c_fields["relationships"] = updated_feelings
		fallback_char_dict["custom_fields"] = c_fields

		_enforce_symmetrical_family(new_char_name, updated_family, initial_family_snapshot)
		_sync_directional_feelings(new_char_name, updated_feelings, initial_feelings_snapshot)
		SaveSystem.update_character_data_in_cast(fallback_char_dict)

	EventBus.notification_requested.emit("Saved Profile: " + new_char_name, true)
	visible = false
	active_entity = null
	fallback_char_dict = {}


func _scrape_bond_cards(vbox_container: VBoxContainer, fallback_rel: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card: Node in vbox_container.get_children():
		if card is PanelContainer and card.get_child_count() > 0:
			var inner_vbox: VBoxContainer = card.get_child(0) as VBoxContainer
			if inner_vbox and inner_vbox.get_child_count() >= 2:
				var top_row: HBoxContainer = inner_vbox.get_child(0) as HBoxContainer
				var notes_edit_node: LineEdit = inner_vbox.get_child(1) as LineEdit
				var opt_target: OptionButton = top_row.get_child(0) as OptionButton
				var opt_rel: OptionButton = top_row.get_child(1) as OptionButton

				if opt_target and opt_target.selected > 0:
					var tgt_name: String = opt_target.get_item_text(opt_target.selected)
					var rel_name: String = opt_rel.get_item_text(opt_rel.selected) if opt_rel else fallback_rel
					var b_notes: String = notes_edit_node.text.strip_edges() if notes_edit_node else ""
					result.append({"target_name": tgt_name, "relation_type": rel_name, "notes": b_notes})
	return result


func _enforce_symmetrical_family(source_name: String, current_family: Array[Dictionary], old_family: Array[Dictionary]) -> void:
	var all_chars: Array[Dictionary] = _load_universe_character_data()
	if all_chars.is_empty(): return
	var char_map: Dictionary = {}
	for c_var: Variant in all_chars:
		if c_var is Dictionary:
			var d: Dictionary = (c_var as Dictionary).duplicate(true)
			var c_name: String = str(d.get("display_name", "")).strip_edges()
			if not c_name.is_empty(): char_map[c_name] = d

	for old_f: Dictionary in old_family:
		var old_target: String = str(old_f.get("target_name", "")).strip_edges()
		var still_exists: bool = false
		for cur_f: Dictionary in current_family:
			if str(cur_f.get("target_name", "")).strip_edges() == old_target:
				still_exists = true
				break
		if not still_exists and not old_target.is_empty() and char_map.has(old_target):
			var tgt: Dictionary = char_map[old_target]
			var c_fields: Dictionary = tgt.get("custom_fields", {})
			var fam: Array = c_fields.get("family_ties", [])
			for i: int in range(fam.size() - 1, -1, -1):
				if fam[i] is Dictionary and str(fam[i].get("target_name", "")).strip_edges() == source_name:
					fam.remove_at(i)
			c_fields["family_ties"] = fam
			tgt["custom_fields"] = c_fields
			_update_universe_character_data(tgt)

	for cur_f: Dictionary in current_family:
		var target_name: String = str(cur_f.get("target_name", "")).strip_edges()
		var rel_type: String = str(cur_f.get("relation_type", "")).strip_edges()

		if not target_name.is_empty() and target_name != source_name and char_map.has(target_name):
			var tgt: Dictionary = char_map[target_name]
			var c_fields: Dictionary = tgt.get("custom_fields", {})
			var fam: Array = c_fields.get("family_ties", [])
			var reciprocal_rel: String = _get_reciprocal_family_role(rel_type)

			var found_idx: int = -1
			for i: int in range(fam.size()):
				if fam[i] is Dictionary and str(fam[i].get("target_name", "")).strip_edges() == source_name:
					found_idx = i
					break

			if found_idx >= 0:
				fam[found_idx]["relation_type"] = reciprocal_rel
			else:
				fam.append({"target_name": source_name, "relation_type": reciprocal_rel, "notes": ""})

			c_fields["family_ties"] = fam
			tgt["custom_fields"] = c_fields
			_update_universe_character_data(tgt)


func _get_reciprocal_family_role(rel_type: String) -> String:
	match rel_type:
		"Parent (Biological)": return "Child (Biological)"
		"Parent (Adoptive / Guardian)": return "Child (Adopted / Ward)"
		"Child (Biological)": return "Parent (Biological)"
		"Child (Adopted / Ward)": return "Parent (Adoptive / Guardian)"
		"Sibling": return "Sibling"
		"Twin": return "Twin"
		"Spouse / Married": return "Spouse / Married"
		"Partner / Committed": return "Partner / Committed"
		"Ex-Partner / Divorced": return "Ex-Partner / Divorced"
		"Separated": return "Separated"
	return "Sibling"


func _sync_directional_feelings(source_name: String, current_feelings: Array[Dictionary], old_feelings: Array[Dictionary]) -> void:
	var all_chars: Array[Dictionary] = _load_universe_character_data()
	if all_chars.is_empty(): return
	var char_map: Dictionary = {}
	for c_var: Variant in all_chars:
		if c_var is Dictionary:
			var d: Dictionary = (c_var as Dictionary).duplicate(true)
			var c_name: String = str(d.get("display_name", "")).strip_edges()
			if not c_name.is_empty(): char_map[c_name] = d

	for old_b: Dictionary in old_feelings:
		var old_target: String = str(old_b.get("target_name", "")).strip_edges()
		var still_exists: bool = false
		for cur_b: Dictionary in current_feelings:
			if str(cur_b.get("target_name", "")).strip_edges() == old_target:
				still_exists = true
				break
		if not still_exists and not old_target.is_empty() and char_map.has(old_target):
			var tgt: Dictionary = char_map[old_target]
			var c_fields: Dictionary = tgt.get("custom_fields", {})
			var rels: Array = c_fields.get("relationships", [])
			var modified: bool = false
			for i: int in range(rels.size() - 1, -1, -1):
				if rels[i] is Dictionary and str(rels[i].get("target_name", "")).strip_edges() == source_name:
					var existing_rel: String = str(rels[i].get("relation_type", "")).strip_edges()
					var existing_notes: String = str(rels[i].get("notes", "")).strip_edges()
					if existing_rel == "Distant / Acquaintance" and existing_notes.is_empty():
						rels.remove_at(i)
						modified = true
			if modified:
				c_fields["relationships"] = rels
				tgt["custom_fields"] = c_fields
				_update_universe_character_data(tgt)

	for cur_b: Dictionary in current_feelings:
		var target_name: String = str(cur_b.get("target_name", "")).strip_edges()
		if not target_name.is_empty() and target_name != source_name and char_map.has(target_name):
			var tgt: Dictionary = char_map[target_name]
			var c_fields: Dictionary = tgt.get("custom_fields", {})
			var rels: Array = c_fields.get("relationships", [])
			var already_connected: bool = false
			for b_var: Variant in rels:
				if b_var is Dictionary and str(b_var.get("target_name", "")).strip_edges() == source_name:
					already_connected = true
					break
			if not already_connected:
				rels.append({"target_name": source_name, "relation_type": "Distant / Acquaintance", "notes": ""})
				c_fields["relationships"] = rels
				tgt["custom_fields"] = c_fields
				_update_universe_character_data(tgt)


func _on_open_journal_from_card() -> void:
	save_and_close()
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop and main_loop is SceneTree:
		var root: Window = (main_loop as SceneTree).root
		if root:
			var existing: CanvasLayer = root.find_child("UniverseJournalDialog", true, false) as CanvasLayer
			if existing and is_instance_valid(existing) and existing.has_method("open_journal"):
				existing.call("open_journal")


func _get_universe_character_names() -> Array[String]:
	var result: Array[String] = []
	var my_name: String = name_edit.text.strip_edges() if name_edit else ""
	var all_chars: Array[Dictionary] = _load_universe_character_data()
	for c_var: Variant in all_chars:
		if c_var is Dictionary:
			var c_name: String = str((c_var as Dictionary).get("display_name", "")).strip_edges()
			if not c_name.is_empty() and c_name != my_name and not (c_name in result):
				result.append(c_name)

	result.sort()
	return result


func _load_universe_character_data() -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	var seen_names: Dictionary = {}
	var universe_id: String = SaveSystem.get_current_universe_id()
	var cast_path: String = SaveSystem.get_universe_cast_path(universe_id)

	if FileAccess.file_exists(cast_path):
		var cast_file: FileAccess = FileAccess.open(cast_path, FileAccess.READ)
		if cast_file != null:
			var parsed_cast: Variant = JSON.parse_string(cast_file.get_as_text())
			cast_file.close()
			var cast_items: Array = []
			if parsed_cast is Array:
				cast_items = parsed_cast as Array
			elif parsed_cast is Dictionary:
				cast_items = (parsed_cast as Dictionary).get("cast", (parsed_cast as Dictionary).get("templates", []))

			for item: Variant in cast_items:
				if item is Dictionary:
					var c_data: Dictionary = (item as Dictionary).duplicate(true)
					var c_id: String = str(c_data.get("id", ""))
					var c_name: String = str(c_data.get("display_name", "")).strip_edges().to_lower()
					if c_id.is_empty() or seen_ids.has(c_id): continue
					if not c_name.is_empty() and seen_names.has(c_name): continue
					roster.append(c_data)
					seen_ids[c_id] = true
					if not c_name.is_empty(): seen_names[c_name] = true

	return roster


func _update_universe_character_data(character_data: Dictionary) -> void:
	SaveSystem.update_character_data_in_cast(character_data)


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		save_and_close()
