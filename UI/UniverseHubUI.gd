# ==============================================================================
# OWNWORLD — UNIVERSE HUB / STORY LIBRARY
# File: res://UI/UniverseHubUI.gd
# Base Class: CanvasLayer (class_name UniverseHubUI)
# ==============================================================================

class_name UniverseHubUI
extends CanvasLayer

const UNIVERSES_DIR: String = "user://universes/"
const DEFAULT_UNIVERSE_ID: String = "default_universe"
const DEFAULT_UNIVERSE_NAME: String = "Default Universe"

var root_panel: PanelContainer = null
var main_vbox: VBoxContainer = null
var header_title_lbl: Label = null
var name_input: LineEdit = null
var universe_list_vbox: VBoxContainer = null
var file_dialog: FileDialog = null

var btn_import: Button = null
var btn_export: Button = null
var btn_close: Button = null
var btn_create: Button = null

var universe_registry: Array[Dictionary] = []

signal universe_selected(universe_id: String, universe_name: String)


func _ready() -> void:
	name = "UniverseHubUI"
	layer = 112
	visible = false
	add_to_group("modal_ui")
	_load_universe_manifests()
	_build_hub_ui()
	_build_import_file_dialog()
	_connect_system_signals()


func _connect_system_signals() -> void:
	if not ThemeService.theme_changed.is_connected(_on_theme_changed):
		ThemeService.theme_changed.connect(_on_theme_changed)


func _on_theme_changed(_theme_data: Dictionary) -> void:
	_refresh_theme_icons()
	_render_universe_cards()


func _build_hub_ui() -> void:
	root_panel = PanelContainer.new()
	root_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	root_panel.add_child(margin)

	main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(main_vbox)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	header_title_lbl = Label.new()
	header_title_lbl.text = "Universe Hub & Story Library"
	header_title_lbl.theme_type_variation = "HeaderLabel"
	header_hbox.add_child(header_title_lbl)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)

	btn_import = Button.new()
	btn_import.text = " Import (.ownpack)"
	btn_import.custom_minimum_size = Vector2(0.0, 32.0)
	btn_import.focus_mode = Control.FOCUS_NONE
	btn_import.add_theme_constant_override("icon_max_width", 14)
	_apply_button_icon(btn_import, "icon_import")
	btn_import.pressed.connect(_on_open_import_dialog)
	header_hbox.add_child(btn_import)

	btn_export = Button.new()
	btn_export.text = " Export Active (.ownpack)"
	btn_export.custom_minimum_size = Vector2(0.0, 32.0)
	btn_export.focus_mode = Control.FOCUS_NONE
	btn_export.add_theme_constant_override("icon_max_width", 14)
	_apply_export_icon(btn_export)
	btn_export.pressed.connect(_on_export_pack_pressed)
	header_hbox.add_child(btn_export)

	btn_close = Button.new()
	btn_close.text = " Close"
	btn_close.custom_minimum_size = Vector2(0.0, 32.0)
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.add_theme_constant_override("icon_max_width", 12)
	_apply_button_icon(btn_close, "icon_close")
	btn_close.pressed.connect(close_hub)
	header_hbox.add_child(btn_close)

	main_vbox.add_child(HSeparator.new())

	var create_hbox: HBoxContainer = HBoxContainer.new()
	create_hbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(create_hbox)

	name_input = LineEdit.new()
	name_input.placeholder_text = "Enter new Story Universe name..."
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_input.custom_minimum_size = Vector2(0.0, 34.0)
	create_hbox.add_child(name_input)

	btn_create = Button.new()
	btn_create.text = " Create Universe"
	btn_create.custom_minimum_size = Vector2(160.0, 34.0)
	btn_create.focus_mode = Control.FOCUS_NONE
	btn_create.add_theme_constant_override("icon_max_width", 14)
	_apply_create_icon(btn_create)
	btn_create.pressed.connect(_on_create_universe_pressed)
	create_hbox.add_child(btn_create)

	main_vbox.add_child(HSeparator.new())

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	universe_list_vbox = VBoxContainer.new()
	universe_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	universe_list_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(universe_list_vbox)


func _build_import_file_dialog() -> void:
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.ownpack ; OwnPack Story Bundles", "*.zip ; ZIP Bundles"]
	file_dialog.file_selected.connect(_on_pack_file_selected)
	add_child(file_dialog)


func open_hub() -> void:
	_load_universe_manifests()
	_render_universe_cards()
	visible = true


func close_hub() -> void:
	visible = false


func _render_universe_cards() -> void:
	if universe_list_vbox == null: return
	for child: Node in universe_list_vbox.get_children():
		child.queue_free()

	var c_sub_bg: Color = ThemeService.get_color("container_sub_bg", "#fdf2f4")
	var c_border: Color = ThemeService.get_color("panel_border", "#f472b6")
	var c_accent: Color = ThemeService.get_color("accent_primary", "#db2777")
	var current_universe_id: String = SaveSystem.get_current_universe_id()
	var corner_radius: int = ThemeService.get_corner_radius()

	for u_data: Dictionary in universe_registry:
		var universe_id: String = str(u_data.get("id", ""))
		var universe_name: String = str(u_data.get("name", "Unnamed Universe"))

		var card: PanelContainer = PanelContainer.new()
		card.theme_type_variation = "SubPanel"
		var is_active: bool = (universe_id == current_universe_id)

		var card_style: StyleBoxFlat = StyleBoxFlat.new()
		card_style.bg_color = c_sub_bg
		card_style.border_color = c_accent if is_active else c_border
		card_style.set_border_width_all(2 if is_active else 1)
		card_style.set_corner_radius_all(corner_radius)
		card_style.content_margin_left = 14
		card_style.content_margin_right = 14
		card_style.content_margin_top = 10
		card_style.content_margin_bottom = 10
		card.add_theme_stylebox_override("panel", card_style)

		var card_hbox: HBoxContainer = HBoxContainer.new()
		card_hbox.add_theme_constant_override("separation", 12)
		card.add_child(card_hbox)

		var info_vbox: VBoxContainer = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_theme_constant_override("separation", 2)
		card_hbox.add_child(info_vbox)

		var u_title: Label = Label.new()
		u_title.text = universe_name
		if is_active: u_title.theme_type_variation = "HeaderLabel"
		info_vbox.add_child(u_title)

		var u_desc: Label = Label.new()
		u_desc.text = "ID: " + universe_id + (" • Active Now" if is_active else "")
		u_desc.theme_type_variation = "HintLabel"
		u_desc.add_theme_font_size_override("font_size", 11)
		info_vbox.add_child(u_desc)

		var btn_play: Button = Button.new()
		btn_play.text = " Active" if is_active else " Enter"
		btn_play.focus_mode = Control.FOCUS_NONE
		btn_play.custom_minimum_size = Vector2(95.0, 32.0)
		btn_play.add_theme_constant_override("icon_max_width", 14)
		_apply_button_icon(btn_play, "icon_star" if is_active else "icon_play")

		if is_active:
			var s_active_btn: StyleBoxFlat = StyleBoxFlat.new()
			s_active_btn.bg_color = c_accent
			s_active_btn.border_color = c_accent
			s_active_btn.set_border_width_all(1)
			s_active_btn.set_corner_radius_all(corner_radius)
			s_active_btn.content_margin_left = 10
			s_active_btn.content_margin_right = 10
			btn_play.add_theme_stylebox_override("normal", s_active_btn)
			btn_play.add_theme_stylebox_override("hover", s_active_btn)
			btn_play.add_theme_stylebox_override("pressed", s_active_btn)
			btn_play.add_theme_color_override("font_color", Color.WHITE)
			btn_play.add_theme_color_override("icon_normal_color", Color.WHITE)
		else:
			var captured_id: String = universe_id
			var captured_name: String = universe_name
			btn_play.pressed.connect(func() -> void: _on_switch_universe_pressed(captured_id, captured_name))

		card_hbox.add_child(btn_play)

		if universe_id != DEFAULT_UNIVERSE_ID:
			var captured_delete_id: String = universe_id
			var captured_delete_name: String = universe_name
			var btn_del: Button = Button.new()
			btn_del.custom_minimum_size = Vector2(28.0, 32.0)
			btn_del.theme_type_variation = "DangerButton"
			btn_del.focus_mode = Control.FOCUS_NONE
			btn_del.add_theme_constant_override("icon_max_width", 12)
			_apply_button_icon(btn_del, "icon_close")
			btn_del.pressed.connect(func() -> void: _delete_universe(captured_delete_id, captured_delete_name))
			card_hbox.add_child(btn_del)

		universe_list_vbox.add_child(card)


func _on_open_import_dialog() -> void:
	if file_dialog == null: return
	file_dialog.theme = ThemeService.create_theme()
	file_dialog.popup_centered_ratio(0.7)


func _on_pack_file_selected(file_path: String) -> void:
	var success: bool = OwnPackManager.import_pack_file(file_path)
	if success:
		_load_universe_manifests()
		_render_universe_cards()
		EventBus.notification_requested.emit("Imported .ownpack Successfully!", true)
	else:
		EventBus.notification_requested.emit("Pack Import Failed", false)


func _delete_universe(u_id: String, u_name: String) -> void:
	var current_universe_id: String = SaveSystem.get_current_universe_id()
	if u_id == current_universe_id:
		_on_switch_universe_pressed(DEFAULT_UNIVERSE_ID, DEFAULT_UNIVERSE_NAME)

	var manifest_path: String = UNIVERSES_DIR + u_id + ".json"
	if FileAccess.file_exists(manifest_path): DirAccess.remove_absolute(manifest_path)

	var cast_path: String = SaveSystem.get_universe_cast_path(u_id)
	if FileAccess.file_exists(cast_path): DirAccess.remove_absolute(cast_path)

	var journal_path: String = SaveSystem.get_universe_journal_path(u_id)
	if FileAccess.file_exists(journal_path): DirAccess.remove_absolute(journal_path)

	var map_path: String = _get_universe_map_path(u_id)
	if FileAccess.file_exists(map_path): DirAccess.remove_absolute(map_path)

	var save_dir: String = SaveSystem.get_universe_save_dir(u_id)
	if DirAccess.dir_exists_absolute(save_dir):
		_delete_directory_contents(save_dir)
		DirAccess.remove_absolute(save_dir)

	_load_universe_manifests()
	_render_universe_cards()
	EventBus.notification_requested.emit("Deleted Universe: " + u_name, true)


func _delete_directory_contents(directory_path: String) -> void:
	var dir: DirAccess = DirAccess.open(directory_path)
	if dir == null: return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		var full_path: String = directory_path.path_join(file_name)
		if dir.current_is_dir():
			_delete_directory_contents(full_path)
			DirAccess.remove_absolute(full_path)
		else:
			DirAccess.remove_absolute(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()


func _on_create_universe_pressed() -> void:
	var u_name: String = name_input.text.strip_edges()
	if u_name.is_empty(): return
	var u_id: String = u_name.to_lower().replace(" ", "_")

	var new_universe: Dictionary = {
		"id": u_id, "name": u_name,
		"created_at": Time.get_unix_time_from_system()
	}

	universe_registry.append(new_universe)
	name_input.text = ""
	_save_universe_manifest(new_universe)
	_render_universe_cards()
	EventBus.notification_requested.emit("Created Universe: " + u_name, true)


func _on_switch_universe_pressed(new_u_id: String, new_u_name: String) -> void:
	close_hub()
	universe_selected.emit(new_u_id, new_u_name)


func _on_export_pack_pressed() -> void:
	var current_universe_id: String = SaveSystem.get_current_universe_id()
	var current_universe_name: String = SaveSystem.get_current_universe_name()
	var success: bool = OwnPackManager.export_universe_pack(current_universe_name, "@Creator", current_universe_id, current_universe_id + "_export")

	if success: EventBus.notification_requested.emit("Exported .ownpack to Documents/OwnWorld/Dollhouse/Exports/", true)
	else: EventBus.notification_requested.emit("Export Failed", false)


func _save_universe_manifest(u_data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(UNIVERSES_DIR)
	var universe_id: String = str(u_data.get("id", ""))
	if universe_id.is_empty(): return

	var file: FileAccess = FileAccess.open(UNIVERSES_DIR + universe_id + ".json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(u_data, "\t"))
		file.flush()
		file.close()


func _load_universe_manifests() -> void:
	universe_registry.clear()
	DirAccess.make_dir_recursive_absolute(UNIVERSES_DIR)
	var dir: DirAccess = DirAccess.open(UNIVERSES_DIR)

	if dir != null:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while not file_name.is_empty():
			if not dir.current_is_dir() and file_name.ends_with(".json") and not file_name.ends_with("_cast.json") and not file_name.ends_with("_journal.json"):
				var file: FileAccess = FileAccess.open(UNIVERSES_DIR + file_name, FileAccess.READ)
				if file != null:
					var parsed: Variant = JSON.parse_string(file.get_as_text())
					file.close()
					if parsed is Dictionary: universe_registry.append(parsed as Dictionary)
			file_name = dir.get_next()
		dir.list_dir_end()

	if universe_registry.is_empty():
		var default_universe: Dictionary = {
			"id": DEFAULT_UNIVERSE_ID, "name": DEFAULT_UNIVERSE_NAME,
			"created_at": Time.get_unix_time_from_system()
		}
		universe_registry.append(default_universe)
		_save_universe_manifest(default_universe)


func _get_universe_map_path(universe_id: String) -> String:
	return "user://maps/" + universe_id + "_map.json"


func _refresh_theme_icons() -> void:
	_apply_button_icon(btn_import, "icon_import")
	_apply_export_icon(btn_export)
	_apply_button_icon(btn_close, "icon_close")
	_apply_create_icon(btn_create)
	_render_universe_cards()


func _apply_button_icon(button: Button, icon_key: String) -> void:
	if button == null: return
	var icon_texture: Texture2D = ThemeService.get_icon(icon_key)
	if icon_texture != null: button.icon = icon_texture


func _apply_export_icon(button: Button) -> void:
	if button == null: return
	var icon_texture: Texture2D = ThemeService.get_icon("icon_prefab")
	if icon_texture == null: icon_texture = ThemeService.get_icon("icon_save")
	if icon_texture != null: button.icon = icon_texture


func _apply_create_icon(button: Button) -> void:
	if button == null: return
	var icon_texture: Texture2D = ThemeService.get_icon("icon_universe")
	if icon_texture == null: icon_texture = ThemeService.get_icon("icon_plus")
	if icon_texture != null: button.icon = icon_texture


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		close_hub()
