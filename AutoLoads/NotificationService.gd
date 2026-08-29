# ==============================================================================
# OWNWORLD — NOTIFICATION TOAST SERVICE (SAFE-AREA & TOP-NAV INTEGRATED)
# File: res://AutoLoads/NotificationService.gd
# Autoload Singleton: NotificationService
# Base Class: Node
#
# Responsibility: Non-intrusive floating toasts with dynamic safe-area aware
# positioning that automatically adjusts below the Top Navigation Bar, display notches,
# and headers. Layer 150 ensures toasts float cleanly on top of all modal dialogs.
# ==============================================================================

extends Node

const NOTIFICATION_LAYER: int = 150
const MIN_WIDTH_MOBILE: float = 240.0
const MIN_WIDTH_DESKTOP: float = 200.0
const MAX_WIDTH: float = 620.0

const DEFAULT_HEIGHT_MOBILE: float = 44.0
const DEFAULT_HEIGHT_DESKTOP: float = 34.0

const FADE_IN_DURATION: float = 0.12
const HOLD_DURATION: float = 1.75
const FADE_OUT_DURATION: float = 0.20

var toast_layer: CanvasLayer = null
var toast_container: CenterContainer = null
var toast_panel: PanelContainer = null
var toast_label: Label = null
var _toast_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_notification_ui()
	if not EventBus.notification_requested.is_connected(_on_notification_requested):
		EventBus.notification_requested.connect(_on_notification_requested)
	if not EventBus.theme_changed.is_connected(_on_theme_changed):
		EventBus.theme_changed.connect(_on_theme_changed)


func _is_mobile() -> bool:
	return ThemeEngine.is_mobile_platform()


func show_notification(message: String, is_success: bool = true) -> void:
	var normalized_message: String = message.strip_edges()
	if normalized_message.is_empty() or not SettingsManager.are_toasts_enabled() or toast_panel == null:
		return

	toast_label.text = normalized_message
	_apply_style(is_success)
	_recalculate_toast_margins()

	toast_panel.visible = true
	toast_panel.modulate.a = 0.0

	_kill_tween()
	_toast_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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
	var is_mob: bool = _is_mobile()
	var default_height: float = DEFAULT_HEIGHT_MOBILE if is_mob else DEFAULT_HEIGHT_DESKTOP
	var min_width: float = MIN_WIDTH_MOBILE if is_mob else MIN_WIDTH_DESKTOP

	toast_layer = CanvasLayer.new()
	toast_layer.name = "NotificationCanvasLayer"
	toast_layer.layer = NOTIFICATION_LAYER
	add_child(toast_layer)

	toast_container = CenterContainer.new()
	toast_container.name = "NotificationContainer"
	toast_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_container.offset_top = 58.0
	toast_container.offset_bottom = 58.0 + default_height
	toast_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_layer.add_child(toast_container)

	toast_panel = PanelContainer.new()
	toast_panel.name = "NotificationPanel"
	toast_panel.theme_type_variation = "ToastPanel"
	toast_panel.visible = false
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.custom_minimum_size = Vector2(min_width, default_height)
	toast_container.add_child(toast_panel)

	toast_label = Label.new()
	toast_label.name = "NotificationLabel"
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.add_theme_font_size_override("font_size", 12 if is_mob else 11)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_child(toast_label)

	_apply_style(true)


## Dynamically queries the exact bottom coordinate of the Top Navigation Bar to position toasts cleanly below it.
func _recalculate_toast_margins() -> void:
	if toast_container == null or toast_panel == null:
		return

	var is_mob: bool = _is_mobile()
	var default_height: float = DEFAULT_HEIGHT_MOBILE if is_mob else DEFAULT_HEIGHT_DESKTOP
	var min_width: float = MIN_WIDTH_MOBILE if is_mob else MIN_WIDTH_DESKTOP

	# 1. Base Hardware Safe Area Offset (Notch Protection)
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	var calculated_top_offset: float = maxf(12.0, float(safe_area.position.y) + 6.0)

	# 2. Inspect Top Navigation Bar via the group registry
	var tree: SceneTree = get_tree()
	if tree != null:
		var nav_nodes: Array[Node] = tree.get_nodes_in_group("top_nav_bar")
		for nav_node: Node in nav_nodes:
			if is_instance_valid(nav_node) and nav_node is CanvasLayer and (nav_node as CanvasLayer).visible:
				if nav_node.has_method("get_nav_bottom_y"):
					var nav_bottom: float = float(nav_node.call("get_nav_bottom_y"))
					calculated_top_offset = maxf(calculated_top_offset, nav_bottom + (10.0 if is_mob else 6.0))
				else:
					calculated_top_offset = maxf(calculated_top_offset, 64.0)

	# 3. Apply Dynamic Offset to Toast Container
	toast_container.offset_top = calculated_top_offset
	toast_container.offset_bottom = calculated_top_offset + default_height

	# 4. Responsive Font Text Width Fitting
	var font: Font = toast_label.get_theme_font("font")
	if font == null: 
		font = ThemeDB.fallback_font
	var font_sz: int = toast_label.get_theme_font_size("font_size")

	var calculated_width: float = font.get_string_size(toast_label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz).x + (44.0 if is_mob else 32.0)
	var clamped_width: float = clampf(calculated_width, min_width, MAX_WIDTH)
	toast_panel.custom_minimum_size = Vector2(clamped_width, default_height)


func _apply_style(is_success: bool) -> void:
	if toast_panel == null:
		return

	var is_mob: bool = _is_mobile()
	var background: Color = ThemeService.get_color("panel_background", "#fff5f7")
	var accent: Color = ThemeService.get_color("accent_primary", "#ec4899")
	var danger: Color = ThemeService.get_color("accent_danger", "#f43f5e")
	var text: Color = ThemeService.get_color("text_primary", "#6c2e3f")
	var corner_radius: int = ThemeService.get_corner_radius()

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(background.r, background.g, background.b, 0.96)
	style.border_color = accent if is_success else danger
	style.set_border_width_all(2 if is_mob else 1)
	style.set_corner_radius_all(corner_radius + 4)
	style.content_margin_left = 16.0 if is_mob else 12.0
	style.content_margin_right = 16.0 if is_mob else 12.0
	style.content_margin_top = 8.0 if is_mob else 5.0
	style.content_margin_bottom = 8.0 if is_mob else 5.0

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
