# ==============================================================================
# OWNWORLD — IN-APP UPDATE & CHANGELOG DIALOG (LAYER 120)
# File: res://UI/Dialogs/UpdateDialog.gd
# Base Class: HyperUIDialog
#
# Responsibility: Modal interface for checking GitHub releases, viewing release
# notes / changelogs, live high-throughput download progress tracking (MB/s & ETA),
# and triggering native OS installation.
# ==============================================================================

class_name UpdateDialog
extends HyperUIDialog

# ------------------------------------------------------------------------------
# UI REFERENCES
# ------------------------------------------------------------------------------
var header_title_lbl: Label = null
var btn_close: Button = null

var status_badge_card: PanelContainer = null
var current_version_lbl: Label = null
var remote_version_lbl: Label = null
var status_desc_lbl: Label = null

var release_notes_title_lbl: Label = null
var release_notes_scroll: ScrollContainer = null
var release_notes_text: RichTextLabel = null

var progress_card: PanelContainer = null
var progress_bar: ProgressBar = null
var progress_metrics_lbl: Label = null
var progress_speed_lbl: Label = null

var action_hbox: HBoxContainer = null
var btn_check_again: Button = null
var btn_download_update: Button = null
var btn_install_now: Button = null
var btn_view_github: Button = null

# ------------------------------------------------------------------------------
# INTERNAL STATE
# ------------------------------------------------------------------------------
var update_manager: UpdateManager = null
var cached_release_info: Dictionary = {}
var is_downloading: bool = false


# ------------------------------------------------------------------------------
# INITIALIZATION & SETUP
# ------------------------------------------------------------------------------
func _init() -> void:
	max_panel_width = 640.0
	max_panel_height = 540.0


func _build_content() -> void:
	name = "UpdateDialog"
	var is_mob: bool = is_mobile()
	var row_h: float = 36.0 if is_mob else 30.0

	# 1. Mount Internal Update Engine
	update_manager = UpdateManager.new()
	update_manager.name = "InternalUpdateManager"
	add_child(update_manager)
	_connect_update_manager_signals()

	# 2. Main Dialog Layout
	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 8)
	root_panel.add_child(main_vbox)

	# 3. Header Row
	var header_hbox: HBoxContainer = HBoxContainer.new()
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	header_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(header_hbox)

	header_title_lbl = Label.new()
	header_title_lbl.text = "Application Updates"
	header_title_lbl.theme_type_variation = "HeaderLabel"
	header_title_lbl.add_theme_font_size_override("font_size", 15 if is_mob else 13)
	header_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header_title_lbl)

	btn_close = Button.new()
	btn_close.custom_minimum_size = Vector2(28.0 if is_mob else 22.0, 28.0 if is_mob else 22.0)
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.add_theme_constant_override("icon_max_width", 12)
	apply_close_icon(btn_close)
	btn_close.pressed.connect(_on_close_requested)
	header_hbox.add_child(btn_close)

	main_vbox.add_child(HSeparator.new())

	# 4. Version & Status Card
	status_badge_card = PanelContainer.new()
	status_badge_card.theme_type_variation = "SubPanel"
	main_vbox.add_child(status_badge_card)

	var status_vbox: VBoxContainer = VBoxContainer.new()
	status_vbox.add_theme_constant_override("separation", 4)
	status_badge_card.add_child(status_vbox)

	var versions_hbox: HBoxContainer = HBoxContainer.new()
	versions_hbox.add_theme_constant_override("separation", 12)
	status_vbox.add_child(versions_hbox)

	current_version_lbl = Label.new()
	current_version_lbl.text = "Installed: v%s" % UpdateManager.get_current_app_version()
	current_version_lbl.theme_type_variation = "HintLabel"
	current_version_lbl.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	versions_hbox.add_child(current_version_lbl)

	remote_version_lbl = Label.new()
	remote_version_lbl.text = "Latest: Checking..."
	remote_version_lbl.theme_type_variation = "HeaderLabel"
	remote_version_lbl.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	remote_version_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	versions_hbox.add_child(remote_version_lbl)

	status_desc_lbl = Label.new()
	status_desc_lbl.text = "Connecting to release server..."
	status_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_desc_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	status_vbox.add_child(status_desc_lbl)

	# 5. Release Notes Scroll Area
	release_notes_title_lbl = Label.new()
	release_notes_title_lbl.text = "Changelog & Release Notes:"
	release_notes_title_lbl.theme_type_variation = "HintLabel"
	release_notes_title_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	main_vbox.add_child(release_notes_title_lbl)

	var notes_panel: PanelContainer = PanelContainer.new()
	notes_panel.theme_type_variation = "SubPanel"
	notes_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notes_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes_panel.custom_minimum_size = Vector2(0.0, 140.0 if is_mob else 120.0)
	main_vbox.add_child(notes_panel)

	release_notes_scroll = ScrollContainer.new()
	release_notes_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	release_notes_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	release_notes_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	release_notes_scroll.follow_focus = false
	notes_panel.add_child(release_notes_scroll)

	release_notes_text = RichTextLabel.new()
	release_notes_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	release_notes_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	release_notes_text.bbcode_enabled = true
	release_notes_text.fit_content = true
	release_notes_text.scroll_active = false
	release_notes_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	release_notes_text.text = "No release notes loaded."
	release_notes_text.add_theme_font_size_override("normal_font_size", 11 if is_mob else 10)
	release_notes_scroll.add_child(release_notes_text)

	# 6. Live Download Progress Card
	progress_card = PanelContainer.new()
	progress_card.theme_type_variation = "SubPanel"
	progress_card.visible = false
	main_vbox.add_child(progress_card)

	var progress_vbox: VBoxContainer = VBoxContainer.new()
	progress_vbox.add_theme_constant_override("separation", 4)
	progress_card.add_child(progress_vbox)

	var prog_metrics_hbox: HBoxContainer = HBoxContainer.new()
	progress_vbox.add_child(prog_metrics_hbox)

	progress_metrics_lbl = Label.new()
	progress_metrics_lbl.text = "Downloading: 0.0 MB / 0.0 MB (0%)"
	progress_metrics_lbl.theme_type_variation = "HeaderLabel"
	progress_metrics_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_metrics_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	prog_metrics_hbox.add_child(progress_metrics_lbl)

	progress_speed_lbl = Label.new()
	progress_speed_lbl.text = "0.0 MB/s • ETA: --"
	progress_speed_lbl.theme_type_variation = "HintLabel"
	progress_speed_lbl.add_theme_font_size_override("font_size", 10 if is_mob else 9)
	prog_metrics_hbox.add_child(progress_speed_lbl)

	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0.0
	progress_bar.max_value = 1.0
	progress_bar.value = 0.0
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(0.0, 16.0 if is_mob else 12.0)
	progress_vbox.add_child(progress_bar)

	main_vbox.add_child(HSeparator.new())

	# 7. Action Button Toolbar
	action_hbox = HBoxContainer.new()
	action_hbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(action_hbox)

	btn_check_again = Button.new()
	btn_check_again.text = " Check Again"
	btn_check_again.custom_minimum_size = Vector2(110.0 if is_mob else 95.0, row_h)
	btn_check_again.focus_mode = Control.FOCUS_NONE
	btn_check_again.add_theme_constant_override("icon_max_width", 14)
	btn_check_again.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	apply_button_icon(btn_check_again, "icon_refresh")
	btn_check_again.pressed.connect(check_updates)
	action_hbox.add_child(btn_check_again)

	btn_view_github = Button.new()
	btn_view_github.text = " View on Web"
	btn_view_github.custom_minimum_size = Vector2(110.0 if is_mob else 95.0, row_h)
	btn_view_github.focus_mode = Control.FOCUS_NONE
	btn_view_github.add_theme_constant_override("icon_max_width", 14)
	btn_view_github.add_theme_font_size_override("font_size", 11 if is_mob else 10)
	apply_button_icon(btn_view_github, "icon_tag")
	btn_view_github.pressed.connect(_on_view_github_pressed)
	action_hbox.add_child(btn_view_github)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_hbox.add_child(spacer)

	btn_download_update = Button.new()
	btn_download_update.text = " Download & Update"
	btn_download_update.custom_minimum_size = Vector2(160.0 if is_mob else 140.0, row_h)
	btn_download_update.focus_mode = Control.FOCUS_NONE
	btn_download_update.add_theme_constant_override("icon_max_width", 16)
	btn_download_update.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	apply_button_icon(btn_download_update, "icon_import")
	btn_download_update.pressed.connect(_on_download_button_pressed)
	btn_download_update.disabled = true
	action_hbox.add_child(btn_download_update)

	btn_install_now = Button.new()
	btn_install_now.text = " Install Now"
	btn_install_now.custom_minimum_size = Vector2(140.0 if is_mob else 120.0, row_h)
	btn_install_now.focus_mode = Control.FOCUS_NONE
	btn_install_now.add_theme_constant_override("icon_max_width", 16)
	btn_install_now.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	apply_button_icon(btn_install_now, "icon_play")
	btn_install_now.pressed.connect(_on_install_button_pressed)
	btn_install_now.visible = false
	action_hbox.add_child(btn_install_now)


# ------------------------------------------------------------------------------
# SIGNAL CONNECTIONS & THEME INTEGRATION
# ------------------------------------------------------------------------------
func _connect_update_manager_signals() -> void:
	if update_manager == null:
		return
	update_manager.check_started.connect(_on_update_check_started)
	update_manager.check_completed.connect(_on_update_check_completed)
	update_manager.download_started.connect(_on_update_download_started)
	update_manager.download_progress.connect(_on_update_download_progress)
	update_manager.download_completed.connect(_on_update_download_completed)
	update_manager.installation_triggered.connect(_on_installation_triggered)
	update_manager.error_occurred.connect(_on_update_error_occurred)


func _on_theme_updated() -> void:
	var c_accent: Color = ThemeService.get_color("accent_primary", "#ec4899")
	if header_title_lbl != null:
		header_title_lbl.add_theme_color_override("font_color", c_accent)
	apply_button_icon(btn_check_again, "icon_refresh")
	apply_button_icon(btn_view_github, "icon_tag")
	apply_button_icon(btn_download_update, "icon_import")
	apply_button_icon(btn_install_now, "icon_play")
	apply_close_icon(btn_close)


# ------------------------------------------------------------------------------
# PUBLIC API
# ------------------------------------------------------------------------------
## Opens the update dialog and immediately checks GitHub for the latest release.
func open_and_check() -> void:
	open_dialog()
	current_version_lbl.text = "Installed: v%s" % UpdateManager.get_current_app_version()
	check_updates()


func check_updates() -> void:
	if is_downloading:
		return
	btn_download_update.visible = true
	btn_download_update.disabled = true
	btn_install_now.visible = false
	progress_card.visible = false
	remote_version_lbl.text = "Latest: Checking..."
	status_desc_lbl.text = "Connecting to GitHub release feed..."
	release_notes_text.text = "Fetching changelog..."
	update_manager.check_for_updates()


# ------------------------------------------------------------------------------
# UPDATE MANAGER EVENT HANDLERS
# ------------------------------------------------------------------------------
func _on_update_check_started() -> void:
	btn_check_again.disabled = true


func _on_update_check_completed(result: UpdateManager.CheckResult, release_data: Dictionary) -> void:
	btn_check_again.disabled = false
	cached_release_info = release_data

	var tag_name: String = str(release_data.get("tag_name", "")).strip_edges()
	var raw_notes: String = str(release_data.get("release_notes", "")).strip_edges()

	if not tag_name.is_empty():
		remote_version_lbl.text = "Latest: %s" % tag_name

	if not raw_notes.is_empty():
		release_notes_text.text = raw_notes
	else:
		release_notes_text.text = "No detailed release notes provided."

	match result:
		UpdateManager.CheckResult.UPDATE_AVAILABLE:
			status_desc_lbl.text = "✨ A new update (%s) is ready for download!" % tag_name
			status_desc_lbl.add_theme_color_override("font_color", ThemeService.get_color("accent_primary", "#ec4899"))
			btn_download_update.disabled = false
			btn_download_update.text = " Download & Update"

		UpdateManager.CheckResult.UP_TO_DATE:
			status_desc_lbl.text = "✔ You are running the latest version (%s)." % UpdateManager.get_current_app_version()
			status_desc_lbl.add_theme_color_override("font_color", ThemeService.get_color("text_primary", "#6c2e3f"))
			btn_download_update.disabled = true

		UpdateManager.CheckResult.NO_COMPATIBLE_ASSET:
			status_desc_lbl.text = "New release %s found, but no direct package was attached for this platform." % tag_name
			status_desc_lbl.add_theme_color_override("font_color", ThemeService.get_color("text_muted", "#a36374"))
			btn_download_update.disabled = true

		UpdateManager.CheckResult.RATE_LIMITED:
			status_desc_lbl.text = "GitHub API rate limit reached. Please try again later or check via web."
			status_desc_lbl.add_theme_color_override("font_color", ThemeService.get_color("accent_danger", "#f43f5e"))
			btn_download_update.disabled = true

		UpdateManager.CheckResult.NETWORK_ERROR, UpdateManager.CheckResult.ERROR:
			var err_str: String = str(release_data.get("error", "Failed to connect to update feed."))
			status_desc_lbl.text = err_str
			status_desc_lbl.add_theme_color_override("font_color", ThemeService.get_color("accent_danger", "#f43f5e"))
			btn_download_update.disabled = true


func _on_download_button_pressed() -> void:
	if is_downloading:
		return
	is_downloading = true
	btn_download_update.disabled = true
	btn_check_again.disabled = true
	progress_card.visible = true
	progress_bar.value = 0.0
	status_desc_lbl.text = "Downloading package..."
	update_manager.start_download()


func _on_update_download_started(total_bytes: int, _target_path: String) -> void:
	var total_mb: float = float(total_bytes) / 1048576.0
	progress_metrics_lbl.text = "Starting download (%.1f MB)..." % total_mb if total_bytes > 0 else "Starting download stream..."


func _on_update_download_progress(percent: float, downloaded_bytes: int, total_bytes: int, speed_bytes_per_sec: float, eta_seconds: float) -> void:
	progress_bar.value = percent

	var downloaded_mb: float = float(downloaded_bytes) / 1048576.0
	var total_mb: float = float(total_bytes) / 1048576.0
	var speed_mb: float = speed_bytes_per_sec / 1048576.0

	if total_bytes > 0:
		progress_metrics_lbl.text = "Downloading: %.1f MB / %.1f MB (%d%%)" % [downloaded_mb, total_mb, int(percent * 100.0)]
	else:
		progress_metrics_lbl.text = "Downloaded: %.1f MB" % downloaded_mb

	var eta_str: String = "%ds" % int(eta_seconds) if eta_seconds > 0.0 else "--"
	progress_speed_lbl.text = "%.2f MB/s • ETA: %s" % [speed_mb, eta_str]


func _on_update_download_completed(target_file_path: String) -> void:
	is_downloading = false
	btn_check_again.disabled = false
	progress_bar.value = 1.0
	progress_metrics_lbl.text = "Download Complete!"
	progress_speed_lbl.text = "Ready to install"
	status_desc_lbl.text = "Package ready: %s" % target_file_path.get_file()

	btn_download_update.visible = false
	btn_install_now.visible = true
	btn_install_now.disabled = false

	# Automatically trigger installation prompt on mobile
	if OS.has_feature("android"):
		update_manager.install_update(target_file_path)


func _on_install_button_pressed() -> void:
	update_manager.install_update()


func _on_installation_triggered(success: bool) -> void:
	if success:
		status_desc_lbl.text = "OS Installer launched. Follow on-screen prompts."
	else:
		status_desc_lbl.text = "Could not launch package installer automatically."


func _on_update_error_occurred(message: String) -> void:
	is_downloading = false
	btn_check_again.disabled = false
	btn_download_update.disabled = false
	status_desc_lbl.text = "Error: %s" % message
	status_desc_lbl.add_theme_color_override("font_color", ThemeService.get_color("accent_danger", "#f43f5e"))
	EventBus.notification_requested.emit(message, false)


func _on_view_github_pressed() -> void:
	var release_url: String = str(cached_release_info.get("release_url", ""))
	if release_url.is_empty():
		release_url = "https://github.com/%s/releases" % UpdateManager.GITHUB_REPO
	OS.shell_open(release_url)
