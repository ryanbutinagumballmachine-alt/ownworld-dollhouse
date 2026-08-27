# ============================================================
# File: res://Core/Animation/SpriteSheetSlicer.gd
# ============================================================

# ==============================================================================
# OWNWORLD — PROCEDURAL SPRITE SHEET & STRIP SLICER (BOUNDS PROTECTED)
# File: res://Core/Animation/SpriteSheetSlicer.gd
# Base Class: RefCounted (class_name SpriteSheetSlicer)
#
# Responsibility: In-memory procedural grid and strip slicer. Extracts animation
# frame sequences from multi-character spritesheets without temporary disk I/O.
# Includes pixel boundary clamping to safely handle non-evenly divisible sheets.
# ==============================================================================

class_name SpriteSheetSlicer
extends RefCounted


## Slices a texture by column and row count into an array of ImageTextures.
static func slice_by_grid(
	source_texture: Texture2D,
	columns: int,
	rows: int,
	margin_x: int = 0,
	margin_y: int = 0,
	spacing_x: int = 0,
	spacing_y: int = 0
) -> Array[ImageTexture]:
	var result: Array[ImageTexture] = []
	if source_texture == null or columns <= 0 or rows <= 0:
		return result

	var source_image: Image = source_texture.get_image()
	if source_image == null or source_image.is_empty():
		return result

	var total_w: int = source_image.get_width()
	var total_h: int = source_image.get_height()

	var usable_w: int = total_w - (margin_x * 2) - (spacing_x * (columns - 1))
	var usable_h: int = total_h - (margin_y * 2) - (spacing_y * (rows - 1))

	if usable_w <= 0 or usable_h <= 0:
		return result

	var cell_w: int = maxi(int(float(usable_w) / float(columns)), 1)
	var cell_h: int = maxi(int(float(usable_h) / float(rows)), 1)

	for r: int in range(rows):
		for c: int in range(columns):
			var src_x: int = margin_x + (c * (cell_w + spacing_x))
			var src_y: int = margin_y + (r * (cell_h + spacing_y))

			if src_x >= total_w or src_y >= total_h:
				continue

			var actual_w: int = mini(cell_w, total_w - src_x)
			var actual_h: int = mini(cell_h, total_h - src_y)

			if actual_w <= 0 or actual_h <= 0:
				continue

			var rect: Rect2i = Rect2i(src_x, src_y, actual_w, actual_h)
			var sub_img: Image = source_image.get_region(rect)

			if sub_img != null and not sub_img.is_empty():
				sub_img.generate_mipmaps()
				var tex: ImageTexture = ImageTexture.create_from_image(sub_img)
				result.append(tex)

	return result


## Slices a texture by explicit cell dimensions (e.g. 64x64) into ImageTextures.
static func slice_by_cell_size(
	source_texture: Texture2D,
	cell_width: int,
	cell_height: int,
	margin_x: int = 0,
	margin_y: int = 0,
	spacing_x: int = 0,
	spacing_y: int = 0
) -> Array[ImageTexture]:
	var result: Array[ImageTexture] = []
	if source_texture == null or cell_width <= 0 or cell_height <= 0:
		return result

	var source_image: Image = source_texture.get_image()
	if source_image == null or source_image.is_empty():
		return result

	var total_w: int = source_image.get_width()
	var total_h: int = source_image.get_height()

	var cols: int = maxi(int(float(total_w - margin_x * 2 + spacing_x) / float(cell_width + spacing_x)), 1)
	var rows: int = maxi(int(float(total_h - margin_y * 2 + spacing_y) / float(cell_height + spacing_y)), 1)

	return slice_by_grid(source_texture, cols, rows, margin_x, margin_y, spacing_x, spacing_y)


## Automatically suggests logical column and row counts based on texture dimensions.
static func suggest_grid_layout(tex_width: int, tex_height: int) -> Vector2i:
	if tex_width <= 0 or tex_height <= 0:
		return Vector2i(1, 1)

	if tex_width >= tex_height * 2:
		var ratio: int = int(roundf(float(tex_width) / float(tex_height)))
		return Vector2i(clampi(ratio, 2, 16), 1)

	if tex_height >= tex_width * 2:
		var ratio: int = int(roundf(float(tex_height) / float(tex_width)))
		return Vector2i(1, clampi(ratio, 2, 16))

	var aspect: float = float(tex_width) / float(tex_height)
	if is_equal_approx(aspect, 1.0):
		return Vector2i(2, 2)
	elif is_equal_approx(aspect, 2.0):
		return Vector2i(4, 2)
	elif is_equal_approx(aspect, 1.5):
		return Vector2i(3, 2)

	return Vector2i(2, 1)
