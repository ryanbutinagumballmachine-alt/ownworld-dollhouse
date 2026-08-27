# ==============================================================================
# OWNWORLD — MAIN MENU UI
# File: res://UI/MainMenuUI.gd
# Base Class: CanvasLayer (class_name MainMenuUI)
# ==============================================================================

class_name MainMenuUI
extends CanvasLayer

const MAX_PANEL_WIDTH: float = 480.0
const MAX_PANEL_HEIGHT: float = 620.0

var root_backdrop: Control = null
var bg_dim: ColorRect = null
var center_container: CenterContainer = null
var root_panel: PanelContainer = null

var title_lbl: Label = null
var sub_lbl: Label = null
var story_info_box: PanelContainer = null
var universe_info_lbl: Label = null
var menu_buttons_vbox: VBoxContainer = null
var btn_quit: Button = null

var _last_progress_pct: int = -1

signal enter_sandbox_requested()
signal open_universe_hub_requested()
signal open_world_map_requested()
signal open_universe_journal_requested()
signal open_room_studio_requested()
signal open_recipe_studio_requested()
signal open_theme_studio_requested()
signal open_settings_requested()
signal open_tutorial_requested()


func _ready() -> void:
	name = "MainMenuUI"
	layer = 115
	visible = false
	add_to_group("modal_ui")
	_build_ui()
	_connect_system_signals()
	_update_responsive_layout()
	_apply_theme()


func _connect_system_signals() -> void:
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null and not tree.root.size_changed.is_connected(_update_responsive_layout):
		tree.root.size_changed.connect(_update_responsive_layout)
	if not ThemeService.theme_changed.is_connected(_on_theme_changed):
		ThemeService.theme_changed.connect(_on_theme_changed)


func _on_theme_changed(_theme_data: Dictionary) -> void:
	_apply_theme()


func _update_responsive_layout() -> void:
	if not is_instance_valid(root_panel): return
	var viewport: Viewport = get_viewport()
	var viewport_size: Vector2 = viewport.get_visible_rect().size if viewport != null else Vector2(1280.0, 720.0)
	var target_width: float = clampf(viewport_size.x * 0.90, 280.0, MAX_PANEL_WIDTH)
	var target_height: float = clampf(viewport_size.y * 0.92, 320.0, MAX_PANEL_HEIGHT)
	root_panel.custom_minimum_size = Vector2(target_width, target_height)
	root_panel.size = Vector2(target_width, target_height)


func _build_ui() -> void:
	root_backdrop = Control.new()
	root_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root_backdrop.gui_input.connect(_on_backdrop_gui_input)
	add_child(root_backdrop)

	bg_dim = ColorRect.new()
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

	title_lbl = Label.new()
	title_lbl.text = "OWNWORLD: DOLLHOUSE"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.theme_type_variation = "HeaderLabel"
	title_lbl.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(title_lbl)

	sub_lbl = Label.new()
	sub_lbl.text = "2D Storytelling & Worldbuilding Sandbox"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.theme_type_variation = "HintLabel"
	sub_lbl.add_theme_font_size_override("font_size", 10)
	main_vbox.add_child(sub_lbl)

	story_info_box = PanelContainer.new()
	story_info_box.theme_type_variation = "SubPanel"
	main_vbox.add_child(story_info_box)

	universe_info_lbl = Label.new()
	universe_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	universe_info_lbl.add_theme_font_size_override("font_size", 10)
	story_info_box.add_child(universe_info_lbl)

	main_vbox.add_child(HSeparator.new())

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = false
	main_vbox.add_child(scroll)

	menu_buttons_vbox = VBoxContainer.new()
	menu_buttons_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_buttons_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(menu_buttons_vbox)

	_add_menu_btn(menu_buttons_vbox, "Play / Resume", "icon_play", func() -> void:
		close_menu()
		enter_sandbox_requested.emit()
	)
	_add_menu_btn(menu_buttons_vbox, "World Maps", "icon_map", func() -> void:
		close_menu()
		open_world_map_requested.emit()
	)
	_add_menu_btn(menu_buttons_vbox, "World Journal & Story Chronicles", "icon_tag", func() -> void:
		close_menu()
		open_universe_journal_requested.emit()
	)
	_add_menu_btn(menu_buttons_vbox, "Room & Wallpaper Studio", "icon_room", func() -> void:
		close_menu()
		open_room_studio_requested.emit()
	)
	_add_menu_btn(menu_buttons_vbox, "Visual Recipe Creator", "icon_recipes", func() -> void:
		close_menu()
		open_recipe_studio_requested.emit()
	)
	_add_menu_btn(menu_buttons_vbox, "Story Universes & Worlds", "icon_universe", func() -> void:
		close_menu()
		open_universe_hub_requested.emit()
	)
	_add_menu_btn(menu_buttons_vbox, "Palette & Font Studio", "icon_palette", func() -> void:
		close_menu()
		open_theme_studio_requested.emit()
	)
	_add_menu_btn(menu_buttons_vbox, "Check for Updates", "icon_refresh", func() -> void:
		EventBus.notification_requested.emit("Checking for updates...", true)
		_last_progress_pct = -1

		UpdateManager.check_for_updates(self, func(status: int, tag: String, download_url: String, message: String) -> void:
			match status:
				UpdateManager.CheckResult.UPDATE_AVAILABLE:
					EventBus.notification_requested.emit("Downloading update %s..." % tag, true)
					
					UpdateManager.download_and_install_update(
						self,
						download_url,
						func(progress: float, downloaded: int, total: int) -> void:
							if total > 0:
								var pct: int = int(progress * 100.0)
								if pct % 20 == 0 and pct != _last_progress_pct:
									_last_progress_pct = pct
									EventBus.notification_requested.emit("Downloading: %d%%" % pct, true)
							else:
								var mb: float = float(downloaded) / 1048576.0
								EventBus.notification_requested.emit("Downloaded: %.1f MB" % mb, true),
						func() -> void:
							EventBus.notification_requested.emit("Download complete! Launching installer...", true),
						func(err: String) -> void:
							EventBus.notification_requested.emit("Update error: " + err, false)
					)

				UpdateManager.CheckResult.UP_TO_DATE:
					EventBus.notification_requested.emit(message, true)

				UpdateManager.CheckResult.NO_APK_FOUND:
					EventBus.notification_requested.emit(message, false)

				UpdateManager.CheckResult.ERROR:
					EventBus.notification_requested.emit(message, false)
		)
	)
	_add_menu_btn(menu_buttons_vbox, "Tutorial & Guide Handbook", "icon_lore", func() -> void:
		close_menu()
		open_tutorial_requested.emit()
	)
	_add_menu_btn(menu_buttons_vbox, "Settings", "icon_settings", func() -> void:
		close_menu()
		open_settings_requested.emit()
	)

	main_vbox.add_child(HSeparator.new())

	btn_quit = Button.new()
	btn_quit.text = " Quit Game"
	btn_quit.theme_type_variation = "DangerButton"
	btn_quit.custom_minimum_size = Vector2(0.0, 34.0)
	btn_quit.focus_mode = Control.FOCUS_NONE
	btn_quit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_quit.add_theme_constant_override("icon_max_width", 16)
	var quit_icon: Texture2D = ThemeService.get_icon("icon_quit")
	if quit_icon != null: btn_quit.icon = quit_icon
	btn_quit.pressed.connect(_on_quit_pressed)
	main_vbox.add_child(btn_quit)


func open_menu() -> void:
	_apply_theme()
	_update_story_info_display()
	_update_responsive_layout()
	visible = true


func close_menu() -> void:
	visible = false


func _update_story_info_display() -> void:
	if universe_info_lbl == null: return
	universe_info_lbl.text = "Active Story: %s\nRoom: %s" % [
		SaveSystem.get_current_universe_name(),
		SaveSystem.get_current_room_id()
	]


func _add_menu_btn(parent: VBoxContainer, btn_text: String, icon_key: String, on_pressed: Callable) -> void:
	var btn: Button = Button.new()
	btn.text = " " + btn_text
	btn.custom_minimum_size = Vector2(0.0, 34.0)
	btn.focus_mode = Control.FOCUS_NONE
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_constant_override("icon_max_width", 16)
	btn.add_theme_font_size_override("font_size", 10)

	var icon_texture: Texture2D = ThemeService.get_icon(icon_key)
	if icon_texture != null:
		btn.icon = icon_texture
		btn.expand_icon = false

	btn.pressed.connect(on_pressed)
	parent.add_child(btn)


func _apply_theme() -> void:
	if root_backdrop:
		root_backdrop.theme = ThemeService.create_theme()

	if btn_quit != null:
		btn_quit.icon = ThemeService.get_icon("icon_quit")

	if menu_buttons_vbox == null: return
	var buttons: Array[Button] = []
	for child: Node in menu_buttons_vbox.get_children():
		if child is Button: buttons.append(child as Button)

	var icon_keys: Array[String] = [
		"icon_play", "icon_map", "icon_tag", "icon_room",
		"icon_recipes", "icon_universe", "icon_palette", "icon_refresh", "icon_lore", "icon_settings"
	]
	var count: int = mini(buttons.size(), icon_keys.size())
	for index: int in range(count):
		buttons[index].icon = ThemeService.get_icon(icon_keys[index])


func _on_quit_pressed() -> void:
	var tree: SceneTree = get_tree()
	if tree == null: return
	tree.root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	tree.quit()


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		close_menu()
