# ==============================================================================
# OWNWORLD — DRAWER FOLDER CREATION MODAL
# File: res://UI/Drawer/DrawerFolderModal.gd
# Base Class: Control (class_name DrawerFolderModal)
#
# Responsibility: Compact dialog for creating nested folders across Assets,
# Props, Furniture, and Cast drawer tabs.
# ==============================================================================

class_name DrawerFolderModal
extends Control

signal folder_create_confirmed(folder_name: String)

var panel: PanelContainer = null
var input_field: LineEdit = null
var btn_cancel: Button = null
var btn_ok: Button = null


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()


func _build_ui() -> void:
	gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			close_modal()
	)

	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(340.0, 150.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var lbl: Label = Label.new()
	lbl.text = "Create New Folder"
	lbl.theme_type_variation = "HeaderLabel"
	vbox.add_child(lbl)

	input_field = LineEdit.new()
	input_field.placeholder_text = "Folder Name..."
	input_field.custom_minimum_size = Vector2(0.0, 32.0)
	input_field.text_submitted.connect(func(_t: String) -> void: _on_confirm())
	vbox.add_child(input_field)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	btn_cancel = Button.new()
	btn_cancel.text = " Cancel"
	btn_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_cancel.custom_minimum_size = Vector2(0.0, 32.0)
	btn_cancel.focus_mode = Control.FOCUS_NONE
	btn_cancel.add_theme_constant_override("icon_max_width", 14)
	var c_icon: Texture2D = ThemeService.get_icon("icon_close")
	if c_icon: btn_cancel.icon = c_icon
	btn_cancel.pressed.connect(close_modal)
	btn_row.add_child(btn_cancel)

	btn_ok = Button.new()
	btn_ok.text = " Create"
	btn_ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_ok.custom_minimum_size = Vector2(0.0, 32.0)
	btn_ok.focus_mode = Control.FOCUS_NONE
	btn_ok.add_theme_constant_override("icon_max_width", 14)
	var plus_icon: Texture2D = ThemeService.get_icon("icon_plus")
	if not plus_icon: plus_icon = ThemeService.get_icon("icon_folder")
	if plus_icon: btn_ok.icon = plus_icon
	btn_ok.pressed.connect(_on_confirm)
	btn_row.add_child(btn_ok)


func open_modal() -> void:
	input_field.text = ""
	visible = true
	input_field.grab_focus()


func close_modal() -> void:
	input_field.text = ""
	visible = false


func _on_confirm() -> void:
	var n: String = input_field.text.strip_edges()
	if not n.is_empty():
		folder_create_confirmed.emit(n)
	close_modal()
