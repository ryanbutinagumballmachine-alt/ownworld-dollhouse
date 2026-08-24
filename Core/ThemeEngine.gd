# ==============================================================================
# Script: res://Core/ThemeEngine.gd
# Base Class: RefCounted (class_name ThemeEngine)
# ==============================================================================

class_name ThemeEngine
extends RefCounted

const DEFAULT_PALETTE: Dictionary = {
	"panel_background": "#fff5f7",
	"panel_border": "#f9a8d4",
	"container_sub_bg": "#fff0f3",
	"button_normal": "#fce7ed",
	"button_hover": "#fbcfe0",
	"button_pressed": "#f9a8d4",
	"button_focus": "#f9a8d4",
	"input_background": "#ffffff",
	"text_primary": "#6c2e3f",
	"text_muted": "#a36374",
	"accent_primary": "#ec4899",
	"accent_danger": "#f43f5e",
	"window_background": "#fff5f7"
}

const DEFAULT_FONT_SIZE: int = 12
const DEFAULT_CORNER_RADIUS: int = 6

const CONTRAST_RATIO_TEXT: float = 4.5
const CONTRAST_RATIO_UI: float = 3.0

static var _cached_procedural_icons: Dictionary = {}

static func calculate_luminance(c: Color) -> float:
	var r: float = (c.r / 12.92) if (c.r <= 0.04045) else pow((c.r + 0.055) / 1.055, 2.4)
	var g: float = (c.g / 12.92) if (c.g <= 0.04045) else pow((c.g + 0.055) / 1.055, 2.4)
	var b: float = (c.b / 12.92) if (c.b <= 0.04045) else pow((c.b + 0.055) / 1.055, 2.4)
	return (0.2126 * r) + (0.7152 * g) + (0.0722 * b)

static func get_contrast_ratio(c1: Color, c2: Color) -> float:
	var lum1: float = calculate_luminance(c1)
	var lum2: float = calculate_luminance(c2)
	var lighter: float = maxf(lum1, lum2)
	var darker: float = minf(lum1, lum2)
	return (lighter + 0.05) / (darker + 0.05)

static func ensure_contrast(fg: Color, bg: Color, min_ratio: float = CONTRAST_RATIO_TEXT) -> Color:
	var current_ratio: float = get_contrast_ratio(fg, bg)
	if current_ratio >= min_ratio:
		return fg

	var bg_lum: float = calculate_luminance(bg)
	var should_lighten: bool = bg_lum < 0.5
	var resolved: Color = fg

	for _step in range(12):
		if should_lighten:
			resolved = resolved.lightened(0.12)
		else:
			resolved = resolved.darkened(0.12)
		if get_contrast_ratio(resolved, bg) >= min_ratio:
			return resolved

	return Color.WHITE if should_lighten else Color(0.08, 0.08, 0.08, 1.0)

static func create_theme(theme_data: Dictionary, corner_radius: int = DEFAULT_CORNER_RADIUS) -> Theme:
	var raw_colors: Dictionary = theme_data.get("colors", {})

	var c_bg: Color = Color(raw_colors.get("panel_background", DEFAULT_PALETTE["panel_background"]))
	var c_border: Color = Color(raw_colors.get("panel_border", DEFAULT_PALETTE["panel_border"]))
	var c_sub_bg: Color = Color(raw_colors.get("container_sub_bg", DEFAULT_PALETTE["container_sub_bg"]))
	var c_btn_n: Color = Color(raw_colors.get("button_normal", DEFAULT_PALETTE["button_normal"]))
	var c_btn_h: Color = Color(raw_colors.get("button_hover", DEFAULT_PALETTE["button_hover"]))
	var c_btn_p: Color = Color(raw_colors.get("button_pressed", DEFAULT_PALETTE["button_pressed"]))
	var c_input_bg: Color = Color(raw_colors.get("input_background", DEFAULT_PALETTE["input_background"]))
	var c_text: Color = Color(raw_colors.get("text_primary", DEFAULT_PALETTE["text_primary"]))
	var c_muted: Color = Color(raw_colors.get("text_muted", DEFAULT_PALETTE["text_muted"]))
	var c_accent: Color = Color(raw_colors.get("accent_primary", DEFAULT_PALETTE["accent_primary"]))
	var c_danger: Color = Color(raw_colors.get("accent_danger", DEFAULT_PALETTE["accent_danger"]))

	var c_text_on_bg: Color = ensure_contrast(c_text, c_bg, CONTRAST_RATIO_TEXT)
	var c_text_on_btn: Color = ensure_contrast(c_text, c_btn_n, CONTRAST_RATIO_TEXT)
	var c_text_on_sub: Color = ensure_contrast(c_text, c_sub_bg, CONTRAST_RATIO_TEXT)
	var c_text_on_input: Color = ensure_contrast(c_text, c_input_bg, CONTRAST_RATIO_TEXT)
	var c_text_on_accent: Color = ensure_contrast(Color.WHITE, c_accent, CONTRAST_RATIO_TEXT)
	var c_muted_on_bg: Color = ensure_contrast(c_muted, c_bg, CONTRAST_RATIO_UI)
	var c_muted_on_input: Color = ensure_contrast(c_muted, c_input_bg, CONTRAST_RATIO_UI)
	var c_border_safe: Color = ensure_contrast(c_border, c_bg, 1.35)

	var th: Theme = Theme.new()

	var custom_font: Font = null
	var fpath: String = str(theme_data.get("font_path", ""))
	if fpath != "" and FileAccess.file_exists(fpath):
		if fpath.begins_with("res://") and ResourceLoader.exists(fpath):
			custom_font = load(fpath) as Font
		else:
			var font_data: PackedByteArray = FileAccess.get_file_as_bytes(fpath)
			if not font_data.is_empty():
				var font_file: FontFile = FontFile.new()
				font_file.data = font_data
				custom_font = font_file

	if custom_font != null:
		th.default_font = custom_font
	th.default_font_size = DEFAULT_FONT_SIZE

	th.set_type_variation("DangerButton", "Button")
	th.set_type_variation("Breadcrumb", "Button")
	th.set_type_variation("SubPanel", "PanelContainer")
	th.set_type_variation("ToastPanel", "PanelContainer")
	th.set_type_variation("FloatingCapsule", "PanelContainer")
	th.set_type_variation("HeaderLabel", "Label")
	th.set_type_variation("HintLabel", "Label")

	var icons: Dictionary = _build_runtime_procedural_icons(
		c_border_safe, c_input_bg, c_accent, c_btn_n, c_btn_h, c_text_on_bg
	)

	var empty_style: StyleBoxEmpty = StyleBoxEmpty.new()
	var panel_main: StyleBoxFlat = _create_flat_style(c_bg, c_border_safe, corner_radius, 2, 12, 12, 8, 8)
	var panel_sub: StyleBoxFlat = _create_flat_style(c_sub_bg, c_border_safe, corner_radius, 1, 8, 8, 6, 6)
	var btn_normal: StyleBoxFlat = _create_flat_style(c_btn_n, c_border_safe, corner_radius, 1, 8, 8, 5, 5)

	var btn_hover: StyleBoxFlat = btn_normal.duplicate() as StyleBoxFlat
	btn_hover.bg_color = c_btn_h
	btn_hover.border_color = c_accent

	var btn_pressed: StyleBoxFlat = btn_normal.duplicate() as StyleBoxFlat
	btn_pressed.bg_color = c_btn_p
	btn_pressed.border_color = c_accent

	var btn_disabled: StyleBoxFlat = btn_normal.duplicate() as StyleBoxFlat
	btn_disabled.bg_color = Color(c_sub_bg.r, c_sub_bg.g, c_sub_bg.b, 0.6)
	btn_disabled.border_color = Color(c_border_safe.r, c_border_safe.g, c_border_safe.b, 0.3)

	var btn_focus: StyleBoxFlat = btn_hover.duplicate() as StyleBoxFlat
	btn_focus.draw_center = false
	btn_focus.border_color = c_accent
	btn_focus.set_border_width_all(2)

	var btn_danger_n: StyleBoxFlat = btn_normal.duplicate() as StyleBoxFlat
	btn_danger_n.bg_color = c_danger
	btn_danger_n.border_color = c_danger.darkened(0.2)

	var btn_danger_h: StyleBoxFlat = btn_danger_n.duplicate() as StyleBoxFlat
	btn_danger_h.bg_color = c_danger.darkened(0.15)
	btn_danger_h.border_color = Color.WHITE

	var input_box: StyleBoxFlat = _create_flat_style(c_input_bg, c_border_safe, corner_radius, 1, 8, 8, 5, 5)
	var input_focus: StyleBoxFlat = input_box.duplicate() as StyleBoxFlat
	input_focus.border_color = c_accent
	input_focus.set_border_width_all(2)

	var item_selected: StyleBoxFlat = _create_flat_style(c_accent, Color(0,0,0,0), maxi(corner_radius - 2, 0), 0, 6, 6, 4, 4)
	var item_hover: StyleBoxFlat = _create_flat_style(c_btn_h, c_accent, maxi(corner_radius - 2, 0), 1, 6, 6, 4, 4)

	# LABELS
	th.set_color("font_color", "Label", c_text_on_bg)
	th.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	th.set_color("font_color", "HeaderLabel", c_accent)
	th.set_color("font_color", "HintLabel", c_muted_on_bg)
	th.set_color("default_color", "RichTextLabel", c_text_on_bg)
	th.set_color("font_color", "TooltipLabel", c_text_on_bg)

	# BUTTONS
	for btn_type: String in ["Button", "OptionButton", "MenuButton"]:
		th.set_stylebox("normal", btn_type, btn_normal)
		th.set_stylebox("hover", btn_type, btn_hover)
		th.set_stylebox("pressed", btn_type, btn_pressed)
		th.set_stylebox("disabled", btn_type, btn_disabled)
		th.set_stylebox("focus", btn_type, btn_focus)
		th.set_color("font_color", btn_type, c_text_on_btn)
		th.set_color("font_hover_color", btn_type, c_text_on_btn)
		th.set_color("font_pressed_color", btn_type, c_text_on_accent)
		th.set_color("font_focus_color", btn_type, c_text_on_btn)
		th.set_color("font_hover_pressed_color", btn_type, c_text_on_accent)
		th.set_color("font_disabled_color", btn_type, c_muted_on_bg)
		th.set_color("icon_normal_color", btn_type, c_text_on_btn)
		th.set_color("icon_hover_color", btn_type, c_accent)
		th.set_color("icon_pressed_color", btn_type, c_text_on_accent)
		th.set_color("icon_disabled_color", btn_type, c_muted_on_bg)
		th.set_constant("icon_max_width", btn_type, 18)

	th.set_stylebox("normal", "DangerButton", btn_danger_n)
	th.set_stylebox("hover", "DangerButton", btn_danger_h)
	th.set_stylebox("pressed", "DangerButton", btn_danger_h)
	th.set_stylebox("focus", "DangerButton", btn_focus)
	th.set_color("font_color", "DangerButton", Color.WHITE)
	th.set_color("font_hover_color", "DangerButton", Color.WHITE)
	th.set_color("font_pressed_color", "DangerButton", Color.WHITE)
	th.set_color("icon_normal_color", "DangerButton", Color.WHITE)

	th.set_stylebox("normal", "Breadcrumb", btn_normal)
	th.set_stylebox("hover", "Breadcrumb", btn_hover)
	th.set_stylebox("pressed", "Breadcrumb", btn_pressed)
	th.set_stylebox("focus", "Breadcrumb", btn_focus)
	th.set_color("font_color", "Breadcrumb", c_text_on_btn)
	th.set_color("font_pressed_color", "Breadcrumb", c_text_on_accent)

	for chk: String in ["CheckBox", "CheckButton"]:
		th.set_stylebox("normal", chk, empty_style)
		th.set_stylebox("hover", chk, empty_style)
		th.set_stylebox("pressed", chk, empty_style)
		th.set_stylebox("disabled", chk, empty_style)
		th.set_stylebox("focus", chk, empty_style)
		th.set_color("font_color", chk, c_text_on_bg)
		th.set_color("font_pressed_color", chk, c_text_on_bg)
		th.set_color("font_hover_color", chk, c_accent)
		th.set_color("font_hover_pressed_color", chk, c_accent)
		th.set_color("font_disabled_color", chk, c_muted_on_bg)
		th.set_color("icon_normal_color", chk, c_text_on_bg)
		th.set_color("icon_hover_color", chk, c_accent)
		if icons.has(&"chk_unchecked") and icons.has(&"chk_checked"):
			th.set_icon("unchecked", chk, icons[&"chk_unchecked"])
			th.set_icon("checked", chk, icons[&"chk_checked"])
			th.set_icon("unchecked_disabled", chk, icons[&"chk_unchecked"])
			th.set_icon("checked_disabled", chk, icons[&"chk_checked"])
		if icons.has(&"radio_unchecked") and icons.has(&"radio_checked"):
			th.set_icon("radio_unchecked", chk, icons[&"radio_unchecked"])
			th.set_icon("radio_checked", chk, icons[&"radio_checked"])
			th.set_icon("radio_unchecked_disabled", chk, icons[&"radio_unchecked"])
			th.set_icon("radio_checked_disabled", chk, icons[&"radio_checked"])

	th.set_color("font_color", "LinkButton", c_accent)
	th.set_color("font_hover_color", "LinkButton", c_accent.lightened(0.2))
	th.set_color("font_pressed_color", "LinkButton", c_accent.darkened(0.2))

	# TEXT INPUTS
	for txt_type: String in ["LineEdit", "TextEdit", "CodeEdit", "SpinBox"]:
		th.set_stylebox("normal", txt_type, input_box)
		th.set_stylebox("focus", txt_type, input_focus)
		th.set_stylebox("read_only", txt_type, btn_disabled)
		th.set_color("font_color", txt_type, c_text_on_input)
		th.set_color("font_selected_color", txt_type, c_text_on_accent)
		th.set_color("selection_color", txt_type, Color(c_accent.r, c_accent.g, c_accent.b, 0.4))
		th.set_color("font_placeholder_color", txt_type, c_muted_on_input)
		th.set_color("caret_color", txt_type, c_text_on_input)

	if icons.has(&"arrow_down"):
		th.set_icon("arrow", "OptionButton", icons[&"arrow_down"])
	if icons.has(&"updown"):
		th.set_icon("updown", "SpinBox", icons[&"updown"])

	# TREES, LISTS & POPUPS
	for list_type: String in ["Tree", "ItemList"]:
		th.set_stylebox("panel", list_type, panel_sub)
		th.set_stylebox("selected", list_type, item_selected)
		th.set_stylebox("selected_focus", list_type, item_selected)
		th.set_stylebox("hovered", list_type, item_hover)
		th.set_stylebox("cursor", list_type, empty_style)
		th.set_stylebox("cursor_unfocused", list_type, empty_style)
		th.set_color("font_color", list_type, c_text_on_sub)
		th.set_color("font_selected_color", list_type, c_text_on_accent)
		th.set_color("font_hovered_color", list_type, c_text_on_sub)
		th.set_color("font_outline_color", list_type, Color(0, 0, 0, 0))

	if icons.has(&"arrow_down") and icons.has(&"arrow_right"):
		th.set_icon("arrow", "Tree", icons[&"arrow_down"])
		th.set_icon("arrow_collapsed", "Tree", icons[&"arrow_right"])
		th.set_icon("select_arrow", "Tree", icons[&"arrow_down"])
	if icons.has(&"chk_checked") and icons.has(&"chk_unchecked"):
		th.set_icon("checked", "Tree", icons[&"chk_checked"])
		th.set_icon("unchecked", "Tree", icons[&"chk_unchecked"])

	var popup_box: StyleBoxFlat = panel_main.duplicate() as StyleBoxFlat
	popup_box.bg_color = c_bg
	th.set_stylebox("panel", "PopupMenu", popup_box)
	th.set_stylebox("hover", "PopupMenu", item_selected)
	th.set_stylebox("panel", "PopupPanel", popup_box)
	th.set_color("font_color", "PopupMenu", c_text_on_bg)
	th.set_color("font_hover_color", "PopupMenu", c_text_on_accent)
	th.set_color("font_disabled_color", "PopupMenu", c_muted_on_bg)
	th.set_color("font_separator_color", "PopupMenu", c_muted_on_bg)
	th.set_constant("icon_max_width", "PopupMenu", 18)
	th.set_constant("v_separation", "PopupMenu", 6)
	th.set_constant("h_separation", "PopupMenu", 8)

	if icons.has(&"radio_checked") and icons.has(&"radio_unchecked"):
		th.set_icon("radio_checked", "PopupMenu", icons[&"radio_checked"])
		th.set_icon("radio_unchecked", "PopupMenu", icons[&"radio_unchecked"])
	if icons.has(&"chk_checked") and icons.has(&"chk_unchecked"):
		th.set_icon("checked", "PopupMenu", icons[&"chk_checked"])
		th.set_icon("unchecked", "PopupMenu", icons[&"chk_unchecked"])
	if icons.has(&"arrow_right"):
		th.set_icon("submenu", "PopupMenu", icons[&"arrow_right"])

	th.set_stylebox("normal", "MenuBar", empty_style)
	th.set_stylebox("hover", "MenuBar", btn_hover)
	th.set_stylebox("pressed", "MenuBar", btn_pressed)
	th.set_color("font_color", "MenuBar", c_text_on_bg)
	th.set_color("font_hover_color", "MenuBar", c_text_on_btn)
	th.set_color("font_pressed_color", "MenuBar", c_text_on_accent)

	# TABS & CONTAINERS
	var tab_sel: StyleBoxFlat = _create_flat_style(c_accent, c_border_safe, corner_radius, 1, 10, 10, 6, 6)
	var tab_unsel: StyleBoxFlat = tab_sel.duplicate() as StyleBoxFlat
	tab_unsel.bg_color = c_btn_n
	var tab_hov: StyleBoxFlat = tab_unsel.duplicate() as StyleBoxFlat
	tab_hov.bg_color = c_btn_h
	tab_hov.border_color = c_accent

	for tab_type: String in ["TabContainer", "TabBar"]:
		th.set_stylebox("tab_selected", tab_type, tab_sel)
		th.set_stylebox("tab_unselected", tab_type, tab_unsel)
		th.set_stylebox("tab_hovered", tab_type, tab_hov)
		th.set_stylebox("tab_disabled", tab_type, btn_disabled)
		th.set_stylebox("tab_focus", tab_type, empty_style)
		th.set_color("font_selected_color", tab_type, c_text_on_accent)
		th.set_color("font_unselected_color", tab_type, c_text_on_btn)
		th.set_color("font_hovered_color", tab_type, c_accent)

	th.set_stylebox("panel", "TabContainer", panel_sub)
	th.set_stylebox("panel", "PanelContainer", panel_main)
	th.set_stylebox("panel", "Panel", panel_main)
	th.set_stylebox("panel", "SubPanel", panel_sub)
	th.set_stylebox("panel", "ScrollContainer", empty_style)
	th.set_stylebox("panel", "MarginContainer", empty_style)

	var toast_s: StyleBoxFlat = panel_main.duplicate() as StyleBoxFlat
	toast_s.set_corner_radius_all(16)
	toast_s.bg_color = Color(c_bg.r, c_bg.g, c_bg.b, 0.96)
	th.set_stylebox("panel", "ToastPanel", toast_s)

	var cap_s: StyleBoxFlat = panel_main.duplicate() as StyleBoxFlat
	cap_s.set_corner_radius_all(corner_radius + 2)
	cap_s.bg_color = Color(c_bg.r, c_bg.g, c_bg.b, 0.96)
	th.set_stylebox("panel", "FloatingCapsule", cap_s)
	th.set_color("icon_normal_color", "FloatingCapsule", c_text_on_bg)
	th.set_color("icon_hover_color", "FloatingCapsule", c_accent)

	# SLIDERS & PROGRESS BARS
	var s_track: StyleBoxFlat = _create_flat_style(c_sub_bg, c_border_safe, 4, 1, 0, 0, 4, 4)
	var s_fill: StyleBoxFlat = _create_flat_style(c_accent, Color(0,0,0,0), 4, 0, 0, 0, 4, 4)

	for s_type: String in ["HSlider", "VSlider"]:
		th.set_stylebox("slider", s_type, s_track)
		th.set_stylebox("grabber_area", s_type, s_fill)
		th.set_stylebox("grabber_area_highlight", s_type, s_fill)
		th.set_stylebox("focus", s_type, empty_style)
		if icons.has(&"grabber_n") and icons.has(&"grabber_h"):
			th.set_icon("grabber", s_type, icons[&"grabber_n"])
			th.set_icon("grabber_highlight", s_type, icons[&"grabber_h"])
			th.set_icon("grabber_disabled", s_type, icons[&"grabber_n"])

	var p_bar_bg: StyleBoxFlat = s_track.duplicate() as StyleBoxFlat
	p_bar_bg.content_margin_left = 2
	p_bar_bg.content_margin_right = 2
	p_bar_bg.content_margin_top = 2
	p_bar_bg.content_margin_bottom = 2

	var p_bar_fill: StyleBoxFlat = s_fill.duplicate() as StyleBoxFlat
	p_bar_fill.content_margin_left = 2
	p_bar_fill.content_margin_right = 2
	p_bar_fill.content_margin_top = 2
	p_bar_fill.content_margin_bottom = 2

	th.set_stylebox("background", "ProgressBar", p_bar_bg)
	th.set_stylebox("fill", "ProgressBar", p_bar_fill)
	th.set_color("font_color", "ProgressBar", c_text_on_bg)

	var track_bg_color: Color = Color(c_border_safe.r, c_border_safe.g, c_border_safe.b, 0.45)
	var track_border_color: Color = Color(c_border_safe.r, c_border_safe.g, c_border_safe.b, 0.75)

	var v_scroll_track: StyleBoxFlat = _create_flat_style(track_bg_color, track_border_color, 6, 1, 7, 7, 4, 4)
	var v_grabber: StyleBoxFlat = _create_flat_style(c_accent, Color(1, 1, 1, 0.9), 6, 1, 6, 6, 10, 10)
	var v_grabber_hov: StyleBoxFlat = v_grabber.duplicate() as StyleBoxFlat
	v_grabber_hov.bg_color = c_accent.lightened(0.18)
	var v_grabber_press: StyleBoxFlat = v_grabber.duplicate() as StyleBoxFlat
	v_grabber_press.bg_color = c_accent.darkened(0.15)

	th.set_stylebox("scroll", "VScrollBar", v_scroll_track)
	th.set_stylebox("scroll_focus", "VScrollBar", v_scroll_track)
	th.set_stylebox("grabber", "VScrollBar", v_grabber)
	th.set_stylebox("grabber_highlight", "VScrollBar", v_grabber_hov)
	th.set_stylebox("grabber_pressed", "VScrollBar", v_grabber_press)

	var h_scroll_track: StyleBoxFlat = _create_flat_style(track_bg_color, track_border_color, 6, 1, 4, 4, 7, 7)
	var h_grabber: StyleBoxFlat = _create_flat_style(c_accent, Color(1, 1, 1, 0.9), 6, 1, 10, 10, 6, 6)
	var h_grabber_hov: StyleBoxFlat = h_grabber.duplicate() as StyleBoxFlat
	h_grabber_hov.bg_color = c_accent.lightened(0.18)
	var h_grabber_press: StyleBoxFlat = h_grabber.duplicate() as StyleBoxFlat
	h_grabber_press.bg_color = c_accent.darkened(0.15)

	th.set_stylebox("scroll", "HScrollBar", h_scroll_track)
	th.set_stylebox("scroll_focus", "HScrollBar", h_scroll_track)
	th.set_stylebox("grabber", "HScrollBar", h_grabber)
	th.set_stylebox("grabber_highlight", "HScrollBar", h_grabber_hov)
	th.set_stylebox("grabber_pressed", "HScrollBar", h_grabber_press)

	# WINDOWS & DIALOGS
	for win_type: String in ["Window", "AcceptDialog", "ConfirmationDialog", "FileDialog"]:
		th.set_stylebox("panel", win_type, panel_main)
		th.set_stylebox("embedded_border", win_type, panel_main)
		th.set_stylebox("embedded_unfocused_border", win_type, panel_main)
		th.set_color("title_color", win_type, c_accent)
		th.set_color("font_color", win_type, c_text_on_bg)
		if icons.has(&"close"):
			th.set_icon("close", win_type, icons[&"close"])
			th.set_icon("close_pressed", win_type, icons[&"close"])

	th.set_color("folder_icon_color", "FileDialog", c_accent)
	th.set_color("file_icon_color", "FileDialog", c_text_on_bg)
	th.set_color("file_disabled_color", "FileDialog", c_muted_on_bg)

	var tooltip_box: StyleBoxFlat = panel_sub.duplicate() as StyleBoxFlat
	tooltip_box.bg_color = Color(c_bg.r, c_bg.g, c_bg.b, 0.95)
	th.set_stylebox("panel", "TooltipPanel", tooltip_box)

	var h_sep: StyleBoxLine = StyleBoxLine.new()
	h_sep.color = c_border_safe
	h_sep.thickness = 1
	th.set_stylebox("separator", "HSeparator", h_sep)

	var v_sep: StyleBoxLine = StyleBoxLine.new()
	v_sep.color = c_border_safe
	v_sep.thickness = 1
	v_sep.vertical = true
	th.set_stylebox("separator", "VSeparator", v_sep)

	th.set_stylebox("panel", "GraphEdit", panel_sub)
	th.set_color("grid_minor", "GraphEdit", Color(c_border_safe.r, c_border_safe.g, c_border_safe.b, 0.15))
	th.set_color("grid_major", "GraphEdit", Color(c_border_safe.r, c_border_safe.g, c_border_safe.b, 0.35))
	th.set_stylebox("panel", "GraphNode", panel_main)
	th.set_stylebox("panel_selected", "GraphNode", input_focus)
	th.set_stylebox("titlebar", "GraphNode", tab_sel)
	th.set_stylebox("titlebar_selected", "GraphNode", tab_sel)

	return th

static func apply_theme_globally(tree: SceneTree, theme_data: Dictionary, corner_radius: int = DEFAULT_CORNER_RADIUS) -> Theme:
	if not tree or not tree.root:
		return null
	var global_theme: Theme = create_theme(theme_data, corner_radius)
	tree.root.theme = global_theme
	_propagate_theme_to_tree(tree.root, global_theme)
	return global_theme

static func _propagate_theme_to_tree(node: Node, th: Theme) -> void:
	if node is Window:
		(node as Window).theme = th
	elif node is Control:
		if not (node.get_parent() is Control):
			(node as Control).theme = th
		elif (node as Control).theme != null and (node as Control).theme != th:
			(node as Control).theme = th

	if node is OptionButton:
		var pop: PopupMenu = (node as OptionButton).get_popup()
		if pop != null:
			pop.theme = th
	elif node is MenuButton:
		var pop: PopupMenu = (node as MenuButton).get_popup()
		if pop != null:
			pop.theme = th

	# Use include_internal = true to visit OptionButton popups and embedded dialog windows
	for child: Node in node.get_children(true):
		_propagate_theme_to_tree(child, th)

static func clear_procedural_icon_cache() -> void:
	_cached_procedural_icons.clear()

static func _build_runtime_procedural_icons(
	c_border: Color, 
	c_input_bg: Color, 
	c_accent: Color, 
	c_btn_n: Color, 
	c_btn_h: Color, 
	c_text: Color
) -> Dictionary:
	var cache_key: String = "%s_%s_%s_%s_%s_%s" % [
		c_border.to_html(false), c_input_bg.to_html(false),
		c_accent.to_html(false), c_btn_n.to_html(false),
		c_btn_h.to_html(false), c_text.to_html(false)
	]

	if _cached_procedural_icons.has(cache_key):
		return _cached_procedural_icons[cache_key]

	var out: Dictionary = {}
	out[&"chk_unchecked"] = _gen_checkbox(false, c_input_bg, c_border, c_accent)
	out[&"chk_checked"] = _gen_checkbox(true, c_input_bg, c_border, c_accent)
	out[&"radio_unchecked"] = _gen_radio(false, c_input_bg, c_border, c_accent)
	out[&"radio_checked"] = _gen_radio(true, c_input_bg, c_border, c_accent)
	out[&"grabber_n"] = _gen_slider_grabber(false, c_btn_n, c_border, c_accent)
	out[&"grabber_h"] = _gen_slider_grabber(true, c_btn_h, c_accent, c_accent)
	out[&"arrow_down"] = _gen_arrow(0, c_text)
	out[&"arrow_right"] = _gen_arrow(1, c_text)
	out[&"updown"] = _gen_updown(c_text)
	out[&"close"] = _gen_close(c_text)

	_cached_procedural_icons[cache_key] = out
	return out

static func _create_flat_style(
	bg: Color, border: Color, radius: int, border_w: int,
	m_left: int, m_right: int, m_top: int, m_bottom: int
) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = m_left
	s.content_margin_right = m_right
	s.content_margin_top = m_top
	s.content_margin_bottom = m_bottom
	return s

static func _gen_checkbox(is_checked: bool, bg: Color, border: Color, check: Color) -> ImageTexture:
	var img: Image = Image.create(18, 18, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var fill_color: Color = check if is_checked else bg
	for x in range(1, 17):
		for y in range(1, 17):
			if x == 1 or x == 16 or y == 1 or y == 16:
				img.set_pixel(x, y, border)
			else:
				img.set_pixel(x, y, fill_color)
	if is_checked:
		for x in range(5, 13):
			for y in range(5, 13):
				img.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)

static func _gen_radio(is_checked: bool, bg: Color, border: Color, dot: Color) -> ImageTexture:
	var size: int = 16
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center: Vector2 = Vector2(float(size) * 0.5, float(size) * 0.5)
	var radius: float = 6.5
	for x in range(size):
		for y in range(size):
			var dist: float = Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center)
			if dist <= radius:
				if dist >= radius - 1.2:
					img.set_pixel(x, y, border)
				else:
					img.set_pixel(x, y, bg)
			if is_checked and dist <= 3.5:
				img.set_pixel(x, y, dot)
	return ImageTexture.create_from_image(img)

static func _gen_slider_grabber(is_highlight: bool, bg: Color, border: Color, accent: Color) -> ImageTexture:
	var size: int = 16
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center: Vector2 = Vector2(float(size) * 0.5, float(size) * 0.5)
	var radius: float = 6.5 if is_highlight else 5.5
	for x in range(size):
		for y in range(size):
			var dist: float = Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center)
			if dist <= radius:
				if dist >= radius - 1.2:
					img.set_pixel(x, y, border if not is_highlight else Color.WHITE)
				else:
					img.set_pixel(x, y, accent if is_highlight else bg)
	return ImageTexture.create_from_image(img)

static func _gen_arrow(dir: int, color: Color) -> ImageTexture:
	var size: int = 14
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if dir == 0:
		for t in range(5):
			img.set_pixel(3 + t, 4 + t, color)
			img.set_pixel(3 + t, 5 + t, color)
			img.set_pixel(11 - t, 4 + t, color)
			img.set_pixel(11 - t, 5 + t, color)
	elif dir == 1:
		for t in range(5):
			img.set_pixel(4 + t, 3 + t, color)
			img.set_pixel(5 + t, 3 + t, color)
			img.set_pixel(4 + t, 11 - t, color)
			img.set_pixel(5 + t, 11 - t, color)
	return ImageTexture.create_from_image(img)

static func _gen_updown(color: Color) -> ImageTexture:
	var size: int = 14
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for t in range(3):
		img.set_pixel(7 - t, 2 + t, color)
		img.set_pixel(7 + t, 2 + t, color)
		img.set_pixel(7 - t, 11 - t, color)
		img.set_pixel(7 + t, 11 - t, color)
	return ImageTexture.create_from_image(img)

static func _gen_close(color: Color) -> ImageTexture:
	var size: int = 14
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in range(3, 11):
		img.set_pixel(i, i, color)
		img.set_pixel(i, 13 - i, color)
	return ImageTexture.create_from_image(img)
