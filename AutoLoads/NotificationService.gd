# ==============================================================================
# OWNWORLD — NOTIFICATION SERVICE
# File: res://AutoLoads/NotificationService.gd
# Autoload: NotificationService
# ==============================================================================

extends Node

const NOTIFICATION_LAYER: int = 128
const DEFAULT_WIDTH: float = 240.0
const DEFAULT_HEIGHT: float = 36.0

const FADE_IN_DURATION: float = 0.12
const HOLD_DURATION: float = 1.60
const FADE_OUT_DURATION: float = 0.20

var toast_layer: CanvasLayer = null
var toast_container: Control = null
var toast_panel: PanelContainer = null
var toast_label: Label = null
var _toast_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_notification_ui()
	EventBus.notification_requested.connect(_on_notification_requested)
	EventBus.theme_changed.connect(_on_theme_changed)


func show_notification(message: String, is_success: bool = true) -> void:
	var normalized_message: String = message.strip_edges()
	if normalized_message.is_empty() or not SettingsManager.are_toasts_enabled() or toast_panel == null:
		return

	toast_label.text = normalized_message
	_apply_style(is_success)
	toast_panel.visible = true
	toast_panel.modulate.a = 0.0

	_kill_tween()
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_panel, "modulate:a", 1.0, FADE_IN_DURATION)
	_toast_tween.tween_interval(HOLD_DURATION)
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, FADE_OUT_DURATION)
	_toast_tween.tween_callback(_hide_panel)


func show_toast(message: String, is_success: bool = true) -> void:
	show_notification(message, is_success)


func _on_notification_requested(message: String, is_success: bool) -> void:
	show_notification(message, is_success)


func _on_theme_changed(_theme_data: Dictionary) -> void:
	if toast_panel != null:
		_apply_style(true)


func _build_notification_ui() -> void:
	toast_layer = CanvasLayer.new()
	toast_layer.name = "NotificationCanvasLayer"
	toast_layer.layer = NOTIFICATION_LAYER
	add_child(toast_layer)

	toast_container = Control.new()
	toast_container.name = "NotificationContainer"
	toast_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toast_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_layer.add_child(toast_container)

	toast_panel = PanelContainer.new()
	toast_panel.name = "NotificationPanel"
	toast_panel.theme_type_variation = "ToastPanel"
	toast_panel.visible = false
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.custom_minimum_size = Vector2(DEFAULT_WIDTH, DEFAULT_HEIGHT)

	toast_panel.anchor_left = 1.0
	toast_panel.anchor_right = 1.0
	toast_panel.anchor_top = 0.0
	toast_panel.anchor_bottom = 0.0
	toast_panel.offset_left = -DEFAULT_WIDTH - 30.0
	toast_panel.offset_top = 18.0
	toast_panel.offset_right = -18.0
	toast_panel.offset_bottom = 18.0 + DEFAULT_HEIGHT
	toast_container.add_child(toast_panel)

	toast_label = Label.new()
	toast_label.name = "NotificationLabel"
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toast_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	toast_label.add_theme_font_size_override("font_size", 11)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_child(toast_label)

	_apply_style(true)


func _apply_style(is_success: bool) -> void:
	if toast_panel == null:
		return

	var background: Color = ThemeService.get_color("panel_background", "#fff5f7")
	var accent: Color = ThemeService.get_color("accent_primary", "#ec4899")
	var danger: Color = ThemeService.get_color("accent_danger", "#f43f5e")
	var text: Color = ThemeService.get_color("text_primary", "#6c2e3f")

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = accent if is_success else danger
	style.set_border_width_all(1)
	style.set_corner_radius_all(ThemeService.get_corner_radius())
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0

	toast_panel.add_theme_stylebox_override("panel", style)
	toast_label.add_theme_color_override("font_color", text)


func _kill_tween() -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = null


func _hide_panel() -> void:
	if toast_panel != null:
		toast_panel.visible = false
	_toast_tween = null
