# ==============================================================================
# OWNWORLD — MAIN MENU UI (HYPER OPTIMIZED)
# File: res://UI/MainMenuUI.gd
# Base Class: HyperUIDialog
# ==============================================================================

class_name MainMenuUI
extends HyperUIDialog

var title_lbl: Label = null
var sub_lbl: Label = null
var story_info_box: PanelContainer = null
var universe_info_lbl: Label = null
var menu_grid: GridContainer = null
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

func _init() -> void:
	max_panel_width = 620.0
	max_panel_height = 560.0

func _build_content() -> void:
	name = "MainMenuUI"
	var is_mob: bool = is_mobile()
	var btn_h: float = 42.0 if is_mob else 34.0

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 6)
	root_panel.add_child(main_vbox)

	title_lbl = Label.new()
	title_lbl.text = "OWNWORLD: DOLLHOUSE"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.theme_type_variation = "HeaderLabel"
	title_lbl.add_theme_font_size_override("font_size", 16 if is_mob else 14)
	main_vbox.add_child(title_lbl)

	sub_lbl = Label.new()
	sub_lbl.text = "2D Storytelling & Worldbuilding Sandbox"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.theme_type_variation = "HintLabel"
	sub_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	main_vbox.add_child(sub_lbl)

	story_info_box = PanelContainer.new()
	story_info_box.theme_type_variation = "SubPanel"
	main_vbox.add_child(story_info_box)

	universe_info_lbl = Label.new()
	universe_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	universe_info_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	story_info_box.add_child(universe_info_lbl)

	main_vbox.add_child(HSeparator.new())

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = false
	main_vbox.add_child(scroll)

	menu_grid = GridContainer.new()
	menu_grid.columns = 2
	menu_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_grid.add_theme_constant_override("h_separation", 8)
	menu_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(menu_grid)

	_add_menu_btn(menu_grid, "Play / Resume", "icon_play", btn_h, func() -> void:
		close_menu()
		enter_sandbox_requested.emit()
	)
	_add_menu_btn(menu_grid, "World Maps", "icon_map", btn_h, func() -> void:
		close_menu()
		open_world_map_requested.emit()
	)
	_add_menu_btn(menu_grid, "World Journal & Lore", "icon_tag", btn_h, func() -> void:
		close_menu()
		open_universe_journal_requested.emit()
	)
	_add_menu_btn(menu_grid, "Room & Slices Studio", "icon_room", btn_h, func() -> void:
		close_menu()
		open_room_studio_requested.emit()
	)
	_add_menu_btn(menu_grid, "Visual Recipe Creator", "icon_recipes", btn_h, func() -> void:
		close_menu()
		open_recipe_studio_requested.emit()
	)
	_add_menu_btn(menu_grid, "Story Universes", "icon_universe", btn_h, func() -> void:
		close_menu()
		open_universe_hub_requested.emit()
	)
	_add_menu_btn(menu_grid, "Palette & Font Studio", "icon_palette", btn_h, func() -> void:
		close_menu()
		open_theme_studio_requested.emit()
	)
	_add_menu_btn(menu_grid, "Check for Updates", "icon_refresh", btn_h, func() -> void:
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
	_add_menu_btn(menu_grid, "Creator Handbook", "icon_lore", btn_h, func() -> void:
		close_menu()
		open_tutorial_requested.emit()
	)
	_add_menu_btn(menu_grid, "Settings", "icon_settings", btn_h, func() -> void:
		close_menu()
		open_settings_requested.emit()
	)

	main_vbox.add_child(HSeparator.new())

	btn_quit = Button.new()
	btn_quit.text = " Quit Game"
	btn_quit.theme_type_variation = "DangerButton"
	btn_quit.custom_minimum_size = Vector2(0.0, btn_h)
	btn_quit.focus_mode = Control.FOCUS_NONE
	btn_quit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_quit.add_theme_constant_override("icon_max_width", 18 if is_mob else 16)
	apply_button_icon(btn_quit, "icon_quit")
	btn_quit.pressed.connect(_on_quit_pressed)
	main_vbox.add_child(btn_quit)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close_menu()
			get_viewport().set_input_as_handled()

func _update_responsive_layout() -> void:
	super._update_responsive_layout()
	if menu_grid != null and root_panel != null:
		menu_grid.columns = 2 if root_panel.size.x >= 420.0 else 1

func open_menu() -> void:
	_update_story_info_display()
	open_dialog()

func close_menu() -> void:
	close_dialog()

func _update_story_info_display() -> void:
	if universe_info_lbl == null: 
		return
	universe_info_lbl.text = "Active Story: %s  |  Room: %s" % [
		AppState.universe_name,
		AppState.room_id
	]

func _add_menu_btn(parent: GridContainer, btn_text: String, icon_key: String, btn_h: float, on_pressed: Callable) -> void:
	var is_mob: bool = is_mobile()
	var btn: Button = Button.new()
	btn.text = " " + btn_text
	btn.custom_minimum_size = Vector2(0.0, btn_h)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_constant_override("icon_max_width", 18 if is_mob else 14)
	btn.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	apply_button_icon(btn, icon_key)
	btn.pressed.connect(on_pressed)
	parent.add_child(btn)

func _on_theme_updated() -> void:
	apply_button_icon(btn_quit, "icon_quit")
	if menu_grid == null: 
		return
	var buttons: Array[Button] = []
	for child: Node in menu_grid.get_children():
		if child is Button: 
			buttons.append(child as Button)

	var icon_keys: Array[String] = [
		"icon_play", "icon_map", "icon_tag", "icon_room",
		"icon_recipes", "icon_universe", "icon_palette", "icon_refresh", "icon_lore", "icon_settings"
	]
	var count: int = mini(buttons.size(), icon_keys.size())
	for index: int in range(count):
		apply_button_icon(buttons[index], icon_keys[index])

func _on_quit_pressed() -> void:
	var tree: SceneTree = get_tree()
	if tree == null: 
		return
	tree.root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	tree.quit()
