# ==============================================================================
# OWNWORLD — HYPER UI DIALOG BASE CLASS (STANDARDIZED MODAL LAYER)
# File: res://UI/Base/HyperUIDialog.gd
# Base Class: CanvasLayer (class_name HyperUIDialog)
#
# Responsibility: Centralized modal dialog base class. Enforces Layer 120 depth
# so dialogs float cleanly above all game docks, and supports sub-modal depth
# (Layer 125) for nested child pickers with automatic responsive resizing.
# ==============================================================================

class_name HyperUIDialog
extends CanvasLayer

const MODAL_BASE_LAYER: int = 120
const SUB_MODAL_LAYER: int = 125

var max_panel_width: float = 600.0
var max_panel_height: float = 500.0

## Tracks if this dialog is a child sub-modal (Layer 125) or top-level dialog (Layer 120)
var is_sub_modal: bool = false

var root_backdrop: Control = null
var center_container: CenterContainer = null
var root_panel: PanelContainer = null

signal dialog_opened()
signal dialog_closed()


func _init() -> void:
	layer = SUB_MODAL_LAYER if is_sub_modal else MODAL_BASE_LAYER


func _ready() -> void:
	layer = SUB_MODAL_LAYER if is_sub_modal else MODAL_BASE_LAYER
	visible = false
	add_to_group(&"modal_ui")
	_build_base_ui()
	_build_content()
	_connect_system_signals()
	_update_responsive_layout()


# --- VIRTUAL METHODS (To be overridden by children) ---

## Override this to add specific UI elements to `root_panel`.
func _build_content() -> void:
	pass


## Override this to refresh specific theme elements.
func _on_theme_updated() -> void:
	pass


## Override this to handle specific close logic before hiding.
func _on_close_requested() -> void:
	close_dialog()


# --- CORE FUNCTIONALITY ---

func is_mobile() -> bool:
	return ThemeEngine.is_mobile_platform()


func open_dialog() -> void:
	layer = SUB_MODAL_LAYER if is_sub_modal else MODAL_BASE_LAYER
	_update_responsive_layout()
	visible = true
	dialog_opened.emit()
	EventBus.modal_opened.emit(name)


func close_dialog() -> void:
	visible = false
	dialog_closed.emit()
	EventBus.modal_closed.emit(name)


func set_sub_modal_priority(p_is_sub_modal: bool = true) -> void:
	is_sub_modal = p_is_sub_modal
	layer = SUB_MODAL_LAYER if is_sub_modal else MODAL_BASE_LAYER


func _build_base_ui() -> void:
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


func _connect_system_signals() -> void:
	var tree: SceneTree = get_tree()
	if is_instance_valid(tree) and is_instance_valid(tree.root) and not tree.root.size_changed.is_connected(_update_responsive_layout):
		tree.root.size_changed.connect(_update_responsive_layout)
	if not EventBus.theme_changed.is_connected(_internal_theme_changed):
		EventBus.theme_changed.connect(_internal_theme_changed)


func _internal_theme_changed(_theme_data: Dictionary) -> void:
	_update_responsive_layout()
	_on_theme_updated()


func _update_responsive_layout() -> void:
	if not is_instance_valid(root_panel): 
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280.0, 720.0)
	var is_mob: bool = is_mobile()

	var target_width: float = clampf(viewport_size.x * 0.92, 300.0, max_panel_width)
	var target_height: float = clampf(viewport_size.y * (0.92 if is_mob else 0.88), 220.0, max_panel_height)
	root_panel.custom_minimum_size = Vector2(target_width, target_height)
	root_panel.size = Vector2(target_width, target_height)


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		_on_close_requested()


# --- KEYBOARD DODGING ---

func register_keyboard_dodge(control: Control) -> void:
	if not is_mobile() or not is_instance_valid(control): 
		return
	control.focus_entered.connect(_on_input_focus_entered)
	control.focus_exited.connect(_on_input_focus_exited)


func _on_input_focus_entered() -> void:
	if is_mobile() and is_instance_valid(center_container):
		await get_tree().process_frame
		await get_tree().process_frame
		var kb_height: float = DisplayServer.virtual_keyboard_get_height()
		if kb_height > 0:
			var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(center_container, "position:y", -kb_height * 0.45, 0.25)


func _on_input_focus_exited() -> void:
	if is_mobile() and is_instance_valid(center_container):
		var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(center_container, "position:y", 0.0, 0.25)


# --- THEME HELPERS ---

func apply_button_icon(button: Button, icon_key: String) -> void:
	if not is_instance_valid(button): 
		return
	var icon_texture: Texture2D = ThemeService.get_icon(icon_key)
	if icon_texture != null: 
		button.icon = icon_texture


func apply_close_icon(button: Button) -> void:
	if not is_instance_valid(button): 
		return
	var icon_texture: Texture2D = ThemeService.get_icon("icon_close")
	if icon_texture != null: 
		button.icon = icon_texture
	else: 
		button.text = "✕"


func apply_checkbox_icon(checkbox: CheckBox, icon_key: String) -> void:
	if not is_instance_valid(checkbox): 
		return
	var icon_texture: Texture2D = ThemeService.get_icon(icon_key)
	if icon_texture == null and icon_key == "icon_stairs":
		icon_texture = ThemeService.get_icon("icon_up")
	if icon_texture != null: 
		checkbox.icon = icon_texture
