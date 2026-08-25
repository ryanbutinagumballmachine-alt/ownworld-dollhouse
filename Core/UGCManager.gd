# ==============================================================================
# OWNWORLD — UGC MANAGER & DOCUMENTS HUB (HYPER-OPTIMIZED)
# File: res://Core/UGCManager.gd
# Base Class: RefCounted (class_name UGCManager)
# ==============================================================================

class_name UGCManager
extends RefCounted

const DEFAULT_MAX_TEXTURE_DIMENSION: int = 1024
const DEFAULT_ALPHA_CUTOFF: float = 0.05
const DEFAULT_ALPHA_EPSILON: float = 4.0
const COLLISION_PROXY_MAX_SIZE: int = 256

const SUPPORTED_ART_EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "webp"]
const SUPPORTED_FONT_EXTENSIONS: Array[String] = ["ttf", "otf", "woff", "woff2"]
const SUPPORTED_AUDIO_EXTENSIONS: Array[String] = ["mp3", "ogg", "wav"]

static var texture_cache: Dictionary = {}
static var polygon_cache: Dictionary = {}
static var all_polygons_cache: Dictionary = {}
static var bitmap_cache: Dictionary = {}

# --- DOCUMENTS HUB PATHS ---

static func get_documents_hub_dir() -> String:
	var docs_dir: String = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if docs_dir.is_empty():
		docs_dir = "user://"
	
	var hub_dir: String = docs_dir.path_join("OwnWorld").replace("\\", "/")
	if not DirAccess.dir_exists_absolute(hub_dir):
		DirAccess.make_dir_recursive_absolute(hub_dir)
	return hub_dir

static func get_dollhouse_dir() -> String:
	var dollhouse_dir: String = get_documents_hub_dir().path_join("Dollhouse").replace("\\", "/")
	if not DirAccess.dir_exists_absolute(dollhouse_dir):
		DirAccess.make_dir_recursive_absolute(dollhouse_dir)
	return dollhouse_dir

static func get_art_root_directory() -> String:
	return _get_or_create_dollhouse_subdir("Art")

static func get_exports_dir() -> String:
	return _get_or_create_dollhouse_subdir("Exports")

static func get_packs_dir() -> String:
	return _get_or_create_dollhouse_subdir("Packs")

static func get_font_root_directory() -> String:
	return _get_or_create_dollhouse_subdir("Font")

static func get_theme_root_directory() -> String:
	return _get_or_create_dollhouse_subdir("Themes")

static func get_theme_icons_directory() -> String:
	var icons_dir: String = get_theme_root_directory().path_join("Icons").replace("\\", "/")
	if not DirAccess.dir_exists_absolute(icons_dir):
		DirAccess.make_dir_recursive_absolute(icons_dir)
	return icons_dir

static func get_theme_file_path() -> String:
	return get_theme_root_directory().path_join("theme.json").replace("\\", "/")

static func get_custom_themes_file_path() -> String:
	return get_theme_root_directory().path_join("custom_themes.json").replace("\\", "/")

static func get_templates_directory() -> String:
	return _get_or_create_dollhouse_subdir("Templates")

static func get_audio_root_directory() -> String:
	return _get_or_create_dollhouse_subdir("Audio")

static func ensure_all_directories() -> void:
	get_art_root_directory()
	get_exports_dir()
	get_packs_dir()
	get_font_root_directory()
	get_theme_root_directory()
	get_theme_icons_directory()
	get_templates_directory()
	get_audio_root_directory()

static func _get_or_create_dollhouse_subdir(subdir_name: String) -> String:
	var target_dir: String = get_dollhouse_dir().path_join(subdir_name).replace("\\", "/")
	if not DirAccess.dir_exists_absolute(target_dir):
		DirAccess.make_dir_recursive_absolute(target_dir)
	return target_dir

static func get_default_import_directory() -> String:
	var pictures_dir: String = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if not pictures_dir.is_empty() and DirAccess.dir_exists_absolute(pictures_dir):
		return pictures_dir.replace("\\", "/")

	var dcim_dir: String = OS.get_system_dir(OS.SYSTEM_DIR_DCIM)
	if not dcim_dir.is_empty() and DirAccess.dir_exists_absolute(dcim_dir):
		return dcim_dir.replace("\\", "/")

	var downloads_dir: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if not downloads_dir.is_empty() and DirAccess.dir_exists_absolute(downloads_dir):
		return downloads_dir.replace("\\", "/")

	return get_art_root_directory()

static func resolve_art_directory(relative_folder: String = "") -> String:
	var normalized_folder: String = _normalize_relative_folder(relative_folder)
	var art_root: String = get_art_root_directory()
	var target_directory: String = art_root if (normalized_folder.is_empty() or normalized_folder == "Root") else art_root.path_join(normalized_folder)
	if not DirAccess.dir_exists_absolute(target_directory):
		DirAccess.make_dir_recursive_absolute(target_directory)
	return target_directory

static func import_art_files(source_paths: PackedStringArray, relative_target_folder: String = "") -> Array[Dictionary]:
	var imported_results: Array[Dictionary] = []
	var target_directory: String = resolve_art_directory(relative_target_folder)
	var normalized_folder: String = _normalize_relative_folder(relative_target_folder)
	if normalized_folder == "Root":
		normalized_folder = ""

	for source_path: String in source_paths:
		var clean_source: String = _normalize_file_path(source_path)
		if not FileAccess.file_exists(clean_source):
			continue

		var extension: String = clean_source.get_extension().to_lower()
		if not SUPPORTED_ART_EXTENSIONS.has(extension):
			continue

		var file_name: String = clean_source.get_file()
		var destination_path: String = target_directory.path_join(file_name).replace("\\", "/")

		if clean_source != destination_path:
			if DirAccess.copy_absolute(clean_source, destination_path) != OK:
				continue

		var texture: Texture2D = load_texture_from_file(destination_path)
		imported_results.append({
			"name": file_name.get_basename(),
			"file_path": destination_path,
			"folder": normalized_folder,
			"texture": texture
		})

	return imported_results

static func delete_art_file(file_path: String) -> bool:
	var clean_path: String = _normalize_file_path(file_path)
	if not FileAccess.file_exists(clean_path):
		return false
	clear_cache_for_path(clean_path)
	return DirAccess.remove_absolute(clean_path) == OK

static func load_texture_from_file(file_path: String, max_dimension: int = DEFAULT_MAX_TEXTURE_DIMENSION) -> Texture2D:
	var clean_path: String = _normalize_file_path(file_path)
	if clean_path.is_empty() or not FileAccess.file_exists(clean_path):
		return null

	if texture_cache.has(clean_path):
		var cached_value: Variant = texture_cache[clean_path]
		if is_instance_valid(cached_value) and cached_value is Texture2D:
			return cached_value as Texture2D
		texture_cache.erase(clean_path)

	var image: Image = Image.new()
	if image.load(clean_path) != OK:
		push_error("[UGCManager] Failed to load image from disk: " + clean_path)
		return null

	# --- IMAGE OPTIMIZATION PIPELINE ---
	if image.detect_alpha() == Image.ALPHA_NONE:
		if image.get_format() != Image.FORMAT_RGB8:
			image.convert(Image.FORMAT_RGB8)
	elif image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)

	var original_width: int = image.get_width()
	var original_height: int = image.get_height()
	var safe_dimension: int = maxi(max_dimension, 1)

	if original_width > safe_dimension or original_height > safe_dimension:
		var ratio: float = float(original_width) / float(original_height)
		var target_width: int
		var target_height: int

		if original_width >= original_height:
			target_width = safe_dimension
			target_height = maxi(int(float(safe_dimension) / ratio), 1)
		else:
			target_height = safe_dimension
			target_width = maxi(int(float(safe_dimension) * ratio), 1)

		image.resize(target_width, target_height, Image.INTERPOLATE_LANCZOS)

	if image.get_format() == Image.FORMAT_RGBA8:
		image.fix_alpha_edges()

	image.generate_mipmaps()

	var texture: ImageTexture = ImageTexture.create_from_image(image)
	texture_cache[clean_path] = texture
	return texture

static func clear_cache_for_path(file_path: String) -> void:
	var clean_path: String = _normalize_file_path(file_path)
	if not texture_cache.has(clean_path):
		return
	var cached_value: Variant = texture_cache[clean_path]
	if cached_value is Texture2D:
		var rid: RID = (cached_value as Texture2D).get_rid()
		polygon_cache.erase(rid)
		all_polygons_cache.erase(rid)
		bitmap_cache.erase(rid)
	texture_cache.erase(clean_path)

static func clear_texture_cache() -> void:
	texture_cache.clear()
	polygon_cache.clear()
	all_polygons_cache.clear()
	bitmap_cache.clear()

static func get_texture_cache_size() -> int: return texture_cache.size()
static func get_polygon_cache_size() -> int: return polygon_cache.size()

static func generate_alpha_bitmap(tex: Texture2D, alpha_cutoff: float = DEFAULT_ALPHA_CUTOFF) -> BitMap:
	if tex == null:
		return null
	var texture_rid: RID = tex.get_rid()
	if bitmap_cache.has(texture_rid):
		var cached_bitmap: Variant = bitmap_cache[texture_rid]
		if cached_bitmap is BitMap:
			return cached_bitmap as BitMap
		bitmap_cache.erase(texture_rid)

	var image: Image = tex.get_image()
	if image == null or image.is_empty():
		return null

	var proxy_img: Image = image
	if image.get_width() > COLLISION_PROXY_MAX_SIZE or image.get_height() > COLLISION_PROXY_MAX_SIZE:
		proxy_img = image.duplicate()
		var max_side: float = maxf(image.get_width(), image.get_height())
		var scale_down: float = float(COLLISION_PROXY_MAX_SIZE) / max_side
		var pw: int = maxi(int(image.get_width() * scale_down), 1)
		var ph: int = maxi(int(image.get_height() * scale_down), 1)
		proxy_img.resize(pw, ph, Image.INTERPOLATE_NEAREST)

	var bitmap: BitMap = BitMap.new()
	bitmap.create_from_image_alpha(proxy_img, clampf(alpha_cutoff, 0.0, 1.0))
	bitmap_cache[texture_rid] = bitmap
	return bitmap

static func generate_alpha_collision_polygons(tex: Texture2D, alpha_cutoff: float = DEFAULT_ALPHA_CUTOFF, epsilon: float = DEFAULT_ALPHA_EPSILON) -> Array[PackedVector2Array]:
	if tex == null:
		return []

	var texture_rid: RID = tex.get_rid()
	if all_polygons_cache.has(texture_rid):
		var cached_polygons: Variant = all_polygons_cache[texture_rid]
		if cached_polygons is Array:
			return cached_polygons as Array[PackedVector2Array]
		all_polygons_cache.erase(texture_rid)

	var source_img: Image = tex.get_image()
	if source_img == null or source_img.is_empty():
		return []

	var orig_w: float = float(source_img.get_width())
	var orig_h: float = float(source_img.get_height())
	if orig_w <= 0.0 or orig_h <= 0.0:
		return []

	var proxy_img: Image
	var scale_x: float = 1.0
	var scale_y: float = 1.0

	if orig_w > COLLISION_PROXY_MAX_SIZE or orig_h > COLLISION_PROXY_MAX_SIZE:
		proxy_img = source_img.duplicate()
		var max_side: float = maxf(orig_w, orig_h)
		var scale_down: float = float(COLLISION_PROXY_MAX_SIZE) / max_side
		var pw: int = maxi(int(orig_w * scale_down), 1)
		var ph: int = maxi(int(orig_h * scale_down), 1)
		proxy_img.resize(pw, ph, Image.INTERPOLATE_NEAREST)
		scale_x = orig_w / float(pw)
		scale_y = orig_h / float(ph)
	else:
		proxy_img = source_img

	var proxy_bitmap: BitMap = BitMap.new()
	proxy_bitmap.create_from_image_alpha(proxy_img, clampf(alpha_cutoff, 0.0, 1.0))

	var proxy_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(proxy_img.get_size()))
	var raw_polygons: Array[PackedVector2Array] = proxy_bitmap.opaque_to_polygons(proxy_rect, maxf(epsilon, 1.0))
	var center_offset: Vector2 = Vector2(-orig_w * 0.5, -orig_h * 0.5)
	var centered_polygons: Array[PackedVector2Array] = []

	for poly in raw_polygons:
		if poly.size() >= 3:
			var centered_poly: PackedVector2Array = PackedVector2Array()
			for pt in poly:
				var upscaled_pt: Vector2 = Vector2(pt.x * scale_x, pt.y * scale_y)
				centered_poly.append(upscaled_pt + center_offset)
			centered_polygons.append(centered_poly)

	all_polygons_cache[texture_rid] = centered_polygons
	return centered_polygons

static func generate_alpha_collision_polygon(tex: Texture2D, alpha_cutoff: float = DEFAULT_ALPHA_CUTOFF, epsilon: float = DEFAULT_ALPHA_EPSILON) -> PackedVector2Array:
	if tex == null:
		return PackedVector2Array()

	var texture_rid: RID = tex.get_rid()
	if polygon_cache.has(texture_rid):
		var cached_polygon: Variant = polygon_cache[texture_rid]
		if cached_polygon is PackedVector2Array:
			return cached_polygon as PackedVector2Array
		polygon_cache.erase(texture_rid)

	var polygons: Array[PackedVector2Array] = generate_alpha_collision_polygons(tex, alpha_cutoff, epsilon)

	if not polygons.is_empty():
		var best_polygon: PackedVector2Array = polygons[0]
		for index: int in range(1, polygons.size()):
			if polygons[index].size() > best_polygon.size():
				best_polygon = polygons[index]

		polygon_cache[texture_rid] = best_polygon
		return best_polygon

	var empty_polygon: PackedVector2Array = PackedVector2Array()
	polygon_cache[texture_rid] = empty_polygon
	return empty_polygon

static func scan_user_art_library() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	_scan_dir_recursive(get_art_root_directory(), "", results)
	return results

static func _scan_dir_recursive(disk_path: String, relative_folder: String, results: Array[Dictionary]) -> void:
	if not DirAccess.dir_exists_absolute(disk_path):
		return

	var files: PackedStringArray = DirAccess.get_files_at(disk_path)
	for file_name: String in files:
		var extension: String = file_name.get_extension().to_lower()
		if not SUPPORTED_ART_EXTENSIONS.has(extension):
			continue
		var full_path: String = disk_path.path_join(file_name).replace("\\", "/")
		results.append({
			"name": file_name.get_basename(),
			"file_path": full_path,
			"folder": relative_folder,
			"texture": load_texture_from_file(full_path)
		})

	var directories: PackedStringArray = DirAccess.get_directories_at(disk_path)
	for directory_name: String in directories:
		if directory_name.begins_with("."):
			continue
		var sub_directory: String = disk_path.path_join(directory_name)
		var sub_relative_path: String = directory_name if relative_folder.is_empty() else relative_folder + "/" + directory_name
		_scan_dir_recursive(sub_directory, sub_relative_path, results)

static func get_subfolders_in_art_folder(relative_folder_path: String) -> Array[String]:
	var subfolders: Array[String] = []
	var normalized_relative: String = _normalize_relative_folder(relative_folder_path)
	var art_root: String = get_art_root_directory()
	var target_directory: String = art_root if (normalized_relative.is_empty() or normalized_relative == "Root") else art_root.path_join(normalized_relative)

	if not DirAccess.dir_exists_absolute(target_directory):
		return subfolders

	var directories: PackedStringArray = DirAccess.get_directories_at(target_directory)
	for directory_name: String in directories:
		if not directory_name.begins_with("."):
			subfolders.append(directory_name)

	return subfolders

static func get_all_art_folders() -> Array[String]:
	var folders: Array[String] = ["Root"]
	_gather_all_folders_recursive(get_art_root_directory(), "", folders)
	return folders

static func _gather_all_folders_recursive(disk_path: String, relative_path: String, folders: Array[String]) -> void:
	if not DirAccess.dir_exists_absolute(disk_path):
		return

	var directories: PackedStringArray = DirAccess.get_directories_at(disk_path)
	for directory_name: String in directories:
		if directory_name.begins_with("."):
			continue
		var sub_relative_path: String = directory_name if relative_path.is_empty() else relative_path + "/" + directory_name
		folders.append(sub_relative_path)
		_gather_all_folders_recursive(disk_path.path_join(directory_name), sub_relative_path, folders)

static func create_art_folder(nested_folder_path: String) -> bool:
	var normalized_path: String = _normalize_relative_folder(nested_folder_path)
	if normalized_path.is_empty() or normalized_path == "Root":
		return false
	var target_directory: String = get_art_root_directory().path_join(normalized_path)
	if DirAccess.dir_exists_absolute(target_directory):
		return true
	return DirAccess.make_dir_recursive_absolute(target_directory) == OK

static func delete_art_folder(relative_folder_path: String) -> bool:
	var normalized_relative: String = _normalize_relative_folder(relative_folder_path)
	if normalized_relative.is_empty() or normalized_relative == "Root":
		return false
	var target_directory: String = get_art_root_directory().path_join(normalized_relative)
	if not DirAccess.dir_exists_absolute(target_directory):
		return false
	return _wipe_dir_recursive(target_directory)

static func _wipe_dir_recursive(disk_path: String) -> bool:
	if not DirAccess.dir_exists_absolute(disk_path):
		return true

	var files: PackedStringArray = DirAccess.get_files_at(disk_path)
	for file_name: String in files:
		var file_path: String = disk_path.path_join(file_name).replace("\\", "/")
		clear_cache_for_path(file_path)
		DirAccess.remove_absolute(file_path)

	var directories: PackedStringArray = DirAccess.get_directories_at(disk_path)
	for directory_name: String in directories:
		_wipe_dir_recursive(disk_path.path_join(directory_name))

	return DirAccess.remove_absolute(disk_path) == OK

static func move_art_file(source_path: String, target_folder: String) -> String:
	var clean_source: String = _normalize_file_path(source_path)
	if not FileAccess.file_exists(clean_source):
		return ""

	var file_name: String = clean_source.get_file()
	var target_directory: String = resolve_art_directory(target_folder)
	var new_path: String = target_directory.path_join(file_name).replace("\\", "/")

	if clean_source == new_path:
		return new_path

	clear_cache_for_path(new_path)
	if DirAccess.rename_absolute(clean_source, new_path) != OK:
		if DirAccess.copy_absolute(clean_source, new_path) != OK:
			return ""
		DirAccess.remove_absolute(clean_source)

	clear_cache_for_path(clean_source)
	return new_path

static func create_blank_starter_graphic(dimensions: Vector2, tint: Color) -> ImageTexture:
	var width: int = maxi(int(dimensions.x), 1)
	var height: int = maxi(int(dimensions.y), 1)
	var image: Image = Image.create(width, height, true, Image.FORMAT_RGBA8)
	image.fill(tint)
	return ImageTexture.create_from_image(image)

static func create_door_frame_texture(dimensions: Vector2 = Vector2(96.0, 160.0)) -> ImageTexture:
	var width: int = maxi(int(dimensions.x), 1)
	var height: int = maxi(int(dimensions.y), 1)
	var image: Image = Image.create(width, height, true, Image.FORMAT_RGBA8)
	image.fill(Color("#1e1b18"))
	var frame_color: Color = Color("#5c3d2e")

	for x: int in range(width):
		for y: int in range(height):
			if x < 8 or x >= width - 8 or y < 8:
				image.set_pixel(x, y, frame_color)

	return ImageTexture.create_from_image(image)

static func _normalize_file_path(file_path: String) -> String:
	return file_path.replace("\\", "/").strip_edges()

static func _normalize_relative_folder(relative_folder: String) -> String:
	var normalized: String = relative_folder.replace("\\", "/").strip_edges().trim_prefix("/").trim_suffix("/")
	var parts: PackedStringArray = normalized.split("/", false)
	var safe_parts: Array[String] = []
	for part: String in parts:
		if part.is_empty() or part == "." or part == "..":
			continue
		safe_parts.append(part)
	return "/".join(safe_parts)
