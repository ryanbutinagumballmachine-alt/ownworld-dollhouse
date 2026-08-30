# ==============================================================================
# OWNWORLD — THEME SERVICE AUTOLOAD (CROSS-PLATFORM ORCHESTRATION)
# File: res://AutoLoads/ThemeService.gd
# Autoload Singleton: ThemeService
# Base Class: Node
#
# Responsibility: Global UI theme orchestration, platform-adapted StyleBox creation,
# cached icon resolution with multi-directory fallback, and safe background registries.
# ==============================================================================

extends Node

const RES_ICONS_DIRECTORY: String = "res://Assets/Icons/"
const FALLBACK_RES_ICONS_DIRECTORY: String = "res://assets/icons/"

const DEFAULT_CORNER_RADIUS: int = 6

var active_theme_cache: Dictionary = {
	"colors": ThemeEngine.DEFAULT_PALETTE.duplicate(true),
	"font_path": ""
}

var _theme_cache: Theme = null
var _theme_icon_cache: Dictionary = {}
var _popup_icon_cache: Dictionary = {}
var _registered_backgrounds: Array[WeakRef] = []

signal theme_changed(theme_data: Dictionary)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_initialize_theme_directories()
	_load_persisted_theme()

	var tree: SceneTree = get_tree()
	if is_instance_valid(tree):
		tree.node_added.connect(_on_node_added)

	call_deferred("apply_theme_globally")


func is_mobile() -> bool:
	return ThemeEngine.is_mobile_platform()


func get_touch_target_min_height() -> float:
	return 44.0 if is_mobile() else 32.0


func get_touch_target_min_width() -> float:
	return 44.0 if is_mobile() else 32.0


func _on_node_added(node: Node) -> void:
	if _theme_cache == null or not is_instance_valid(node):
		return
	if node is Window:
		(node as Window).theme = _theme_cache
	elif node is Control:
		if not (node.get_parent() is Control):
			(node as Control).theme = _theme_cache
	elif node is CanvasLayer:
		for child: Node in node.get_children():
			if child is Control:
				(child as Control).theme = _theme_cache

	if node is OptionButton:
		var pop: PopupMenu = (node as OptionButton).get_popup()
		if is_instance_valid(pop): 
			pop.theme = _theme_cache
	elif node is MenuButton:
		var pop: PopupMenu = (node as MenuButton).get_popup()
		if is_instance_valid(pop): 
			pop.theme = _theme_cache


func _initialize_theme_directories() -> void:
	UGCManager.get_theme_root_directory()
	UGCManager.get_theme_icons_directory()
	UGCManager.get_font_root_directory()


func _load_persisted_theme() -> void:
	active_theme_cache = {
		"colors": ThemeEngine.DEFAULT_PALETTE.duplicate(true),
		"font_path": ""
	}

	var theme_file_path: String = UGCManager.get_theme_file_path()
	if not FileAccess.file_exists(theme_file_path):
		_save_theme_to_disk()
		return

	var persisted: Dictionary = JsonFileStore.read_dictionary(theme_file_path)
	if persisted.is_empty():
		return

	var persisted_colors: Variant = persisted.get("colors", {})
	if persisted_colors is Dictionary:
		for key: Variant in (persisted_colors as Dictionary).keys():
			active_theme_cache["colors"][str(key)] = (persisted_colors as Dictionary)[key]

	active_theme_cache["font_path"] = str(persisted.get("font_path", ""))


func _save_theme_to_disk() -> void:
	_initialize_theme_directories()
	JsonFileStore.write_dictionary(UGCManager.get_theme_file_path(), active_theme_cache)


func save_theme_to_disk() -> void:
	_save_theme_to_disk()


func get_color(color_key: String, fallback_hex: String = "#ffffff") -> Color:
	var colors: Dictionary = active_theme_cache.get("colors", {})
	var raw_value: Variant = colors.get(color_key, null)

	if raw_value != null:
		var parsed_color: Color = Color(str(raw_value))
		if parsed_color != Color.TRANSPARENT or str(raw_value).to_lower() == "#00000000":
			return parsed_color

	return Color(fallback_hex)


func get_corner_radius() -> int:
	return DEFAULT_CORNER_RADIUS


func get_theme_data() -> Dictionary:
	return active_theme_cache.duplicate(true)


func create_theme() -> Theme:
	_rebuild_theme_cache()
	return _theme_cache


func _rebuild_theme_cache() -> void:
	_theme_cache = ThemeEngine.create_theme(active_theme_cache, DEFAULT_CORNER_RADIUS)


func apply_theme(theme_data: Dictionary) -> void:
	if theme_data.is_empty():
		return

	var incoming_colors: Variant = theme_data.get("colors", null)
	if incoming_colors is Dictionary:
		for key: Variant in (incoming_colors as Dictionary).keys():
			active_theme_cache["colors"][str(key)] = (incoming_colors as Dictionary)[key]

	if theme_data.has("font_path"):
		active_theme_cache["font_path"] = str(theme_data["font_path"])

	_rebuild_theme_cache()
	_save_theme_to_disk()
	apply_theme_globally()

	var payload: Dictionary = get_theme_data()
	theme_changed.emit(payload)
	EventBus.theme_changed.emit(payload)


func apply_global_theme(theme_data: Dictionary) -> void:
	apply_theme(theme_data)


func apply_theme_globally() -> void:
	var tree: SceneTree = get_tree()
	if not is_instance_valid(tree) or not is_instance_valid(tree.root):
		return

	ThemeEngine.clear_procedural_icon_cache()
	_theme_cache = ThemeEngine.apply_theme_globally(tree, active_theme_cache, DEFAULT_CORNER_RADIUS)
	_refresh_registered_backgrounds()


func create_stylebox(background_key: String, border_key: String, radius: int = DEFAULT_CORNER_RADIUS) -> StyleBoxFlat:
	var m_h: int = 12 if is_mobile() else 8
	var m_v: int = 8 if is_mobile() else 5
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = get_color(background_key, "#ffffff")
	s.border_color = get_color(border_key, "#f9a8d4")
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = m_h
	s.content_margin_right = m_h
	s.content_margin_top = m_v
	s.content_margin_bottom = m_v
	return s


func get_icon(icon_name: String) -> Texture2D:
	if icon_name.is_empty():
		return null
	
	var cache_key: StringName = StringName(icon_name)
	if _theme_icon_cache.has(cache_key):
		return _theme_icon_cache[cache_key]

	var clean_name: String = icon_name.strip_edges().to_lower()
	var names: Array[String] = [clean_name]
	if clean_name.begins_with("icon_"):
		names.append(clean_name.trim_prefix("icon_"))
	else:
		names.append("icon_" + clean_name)

	var directories: Array[String] = [
		RES_ICONS_DIRECTORY,
		FALLBACK_RES_ICONS_DIRECTORY,
		UGCManager.get_theme_icons_directory()
	]
	var extensions: Array[String] = [".png", ".svg", ".webp"]

	for directory: String in directories:
		for name_variant: String in names:
			for extension: String in extensions:
				var path: String = directory.path_join(name_variant + extension).replace("\\", "/")
				if path.begins_with("res://") and ResourceLoader.exists(path):
					var resource_texture: Texture2D = load(path) as Texture2D
					if resource_texture != null:
						_theme_icon_cache[cache_key] = resource_texture
						return resource_texture
				if (path.begins_with("user://") or not path.begins_with("res://")) and FileAccess.file_exists(path):
					var image: Image = Image.load_from_file(path)
					if image != null and not image.is_empty():
						image.generate_mipmaps()
						var user_texture: ImageTexture = ImageTexture.create_from_image(image)
						_theme_icon_cache[cache_key] = user_texture
						return user_texture

	return null


func get_popup_icon(icon_name: String) -> Texture2D:
	var tint_color: Color = get_color("text_primary", "#6c2e3f")
	var cache_key: StringName = StringName(icon_name + "_" + tint_color.to_html(false))

	if _popup_icon_cache.has(cache_key):
		return _popup_icon_cache[cache_key]

	var raw_texture: Texture2D = get_icon(icon_name)
	if raw_texture == null:
		return null

	var source_image: Image = raw_texture.get_image()
	if source_image == null:
		return raw_texture

	var icon_dim: int = 22 if is_mobile() else 18
	var image: Image = source_image.duplicate()
	image.resize(icon_dim, icon_dim, Image.INTERPOLATE_LANCZOS)

	for x: int in range(image.get_width()):
		for y: int in range(image.get_height()):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a <= 0.01:
				continue
			image.set_pixel(x, y, Color(tint_color.r, tint_color.g, tint_color.b, pixel.a * tint_color.a))

	var result: ImageTexture = ImageTexture.create_from_image(image)
	_popup_icon_cache[cache_key] = result
	return result


func clear_icon_cache() -> void:
	_theme_icon_cache.clear()
	_popup_icon_cache.clear()


func register_background(control: Control) -> void:
	if not is_instance_valid(control):
		return
	for weak_reference: WeakRef in _registered_backgrounds:
		if weak_reference.get_ref() == control:
			_update_background_control(control)
			return

	_registered_backgrounds.append(weakref(control))
	_update_background_control(control)


func unregister_background(control: Control) -> void:
	if not is_instance_valid(control):
		return
	for index: int in range(_registered_backgrounds.size() - 1, -1, -1):
		var target: Control = _registered_backgrounds[index].get_ref() as Control
		if not is_instance_valid(target) or target == control:
			_registered_backgrounds.remove_at(index)


func _refresh_registered_backgrounds() -> void:
	for index: int in range(_registered_backgrounds.size() - 1, -1, -1):
		var bg: Control = _registered_backgrounds[index].get_ref() as Control
		if not is_instance_valid(bg):
			_registered_backgrounds.remove_at(index)
			continue
		_update_background_control(bg)


func _update_background_control(control: Control) -> void:
	if control is ColorRect:
		(control as ColorRect).color = get_color("window_background", "#fff5f7")


func reset_to_default_theme() -> void:
	active_theme_cache = {
		"colors": ThemeEngine.DEFAULT_PALETTE.duplicate(true),
		"font_path": ""
	}
	clear_icon_cache()
	_save_theme_to_disk()
	apply_theme_globally()

	var payload: Dictionary = get_theme_data()
	theme_changed.emit(payload)
	EventBus.theme_changed.emit(payload)
