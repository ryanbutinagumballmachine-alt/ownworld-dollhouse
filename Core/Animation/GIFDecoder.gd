# ==============================================================================
# OWNWORLD — PURE GDSCRIPT GIF DECODER (RECURSION PROTECTED)
# File: res://Core/Animation/GifDecoder.gd
# Base Class: RefCounted (class_name GifDecoder)
#
# Responsibility: Decodes standard animated GIF files into Godot Image/Texture2D
# arrays with frame delays, transparency masks, and disposal compositing.
# Includes strict cycle & recursion guards against malformed GIF streams.
# ==============================================================================

class_name GifDecoder
extends RefCounted

const MAX_LZW_BITS: int = 12
const MAX_DICTIONARY_SIZE: int = 4096


## Decodes a GIF file from disk into structured frame textures and timings.
static func decode_file(file_path: String, first_frame_only: bool = false) -> Dictionary:
	var clean_path: String = file_path.strip_edges().replace("\\", "/")
	if not FileAccess.file_exists(clean_path):
		return {"valid": false, "error": "File does not exist: " + clean_path}

	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(clean_path)
	if bytes.is_empty():
		return {"valid": false, "error": "Empty file: " + clean_path}

	return decode_bytes(bytes, first_frame_only)


## Decodes a GIF byte stream into structured frame textures and timings.
static func decode_bytes(bytes: PackedByteArray, first_frame_only: bool = false) -> Dictionary:
	var decoder: GifDecoder = GifDecoder.new()
	return decoder._parse(bytes, first_frame_only)


# --- INTERNAL DECODER ENGINE ---

var _bytes: PackedByteArray = PackedByteArray()
var _pos: int = 0

var _width: int = 0
var _height: int = 0
var _global_color_table: PackedColorArray = PackedColorArray()
var _bg_color_index: int = 0

# Graphic Control Extension state for next frame
var _gce_transparent_flag: bool = false
var _gce_transparent_index: int = 0
var _gce_delay_sec: float = 0.10
var _gce_disposal_method: int = 0


func _parse(bytes: PackedByteArray, first_frame_only: bool) -> Dictionary:
	_bytes = bytes
	_pos = 0

	if _bytes.size() < 13:
		return {"valid": false, "error": "File buffer too small for GIF header."}

	# 1. Header Validation (GIF87a / GIF89a)
	var header_str: String = _read_ascii(6)
	if not (header_str == "GIF87a" or header_str == "GIF89a"):
		return {"valid": false, "error": "Invalid GIF signature: " + header_str}

	# 2. Logical Screen Descriptor
	_width = _read_u16()
	_height = _read_u16()
	if _width <= 0 or _height <= 0:
		return {"valid": false, "error": "Invalid dimensions: %dx%d" % [_width, _height]}

	var packed_fields: int = _read_u8()
	var gct_flag: bool = (packed_fields & 0x80) != 0
	var gct_size_exp: int = (packed_fields & 0x07) + 1
	var gct_color_count: int = 1 << gct_size_exp

	_bg_color_index = _read_u8()
	var _aspect_ratio: int = _read_u8()

	# 3. Global Color Table
	if gct_flag:
		_global_color_table = _read_color_table(gct_color_count)
	else:
		_global_color_table = _create_grayscale_palette()

	var frames: Array[Texture2D] = []
	var delays: Array[float] = []

	var canvas: Image = Image.create(_width, _height, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))

	var prev_canvas_backup: Image = null

	_reset_gce()

	# 4. Data Stream Loop
	while _pos < _bytes.size():
		var block_type: int = _read_u8()

		# Trailer / End of Stream
		if block_type == 0x3B or block_type == -1:
			break

		# Extension Block
		elif block_type == 0x21:
			var ext_label: int = _read_u8()
			if ext_label == 0xF9:
				_parse_graphic_control_extension()
			else:
				_skip_sub_blocks()

		# Image Descriptor
		elif block_type == 0x2C:
			if _gce_disposal_method == 3:
				prev_canvas_backup = canvas.duplicate()

			var frame_img: Image = _parse_image_frame(canvas)
			if frame_img != null:
				var tex: ImageTexture = ImageTexture.create_from_image(frame_img)
				frames.append(tex)
				delays.append(_gce_delay_sec)

				if first_frame_only:
					break

				if _gce_disposal_method == 2:
					canvas.fill(Color(0, 0, 0, 0))
				elif _gce_disposal_method == 3 and prev_canvas_backup != null:
					canvas = prev_canvas_backup.duplicate()

			_reset_gce()

		else:
			continue

	if frames.is_empty():
		return {"valid": false, "error": "No valid frames decoded from GIF."}

	var total_delay: float = 0.0
	for d: float in delays:
		total_delay += d
	var avg_fps: float = float(frames.size()) / maxf(total_delay, 0.01)

	return {
		"valid": true,
		"width": _width,
		"height": _height,
		"frames": frames,
		"delays": delays,
		"fps": clampf(avg_fps, 1.0, 60.0),
		"frame_count": frames.size()
	}


func _parse_graphic_control_extension() -> void:
	var block_size: int = _read_u8()
	if block_size < 4:
		_skip_sub_blocks()
		return

	var packed: int = _read_u8()
	_gce_disposal_method = (packed >> 2) & 0x07
	_gce_transparent_flag = (packed & 0x01) != 0

	var delay_hundredths: int = _read_u16()
	_gce_delay_sec = maxf(float(delay_hundredths) / 100.0, 0.04)

	_gce_transparent_index = _read_u8()

	var terminator: int = _read_u8()
	if terminator != 0:
		_pos += terminator
		_skip_sub_blocks()


func _parse_image_frame(canvas: Image) -> Image:
	var img_left: int = _read_u16()
	var img_top: int = _read_u16()
	var img_width: int = _read_u16()
	var img_height: int = _read_u16()

	if img_width <= 0 or img_height <= 0:
		_skip_sub_blocks()
		return null

	var packed: int = _read_u8()
	var lct_flag: bool = (packed & 0x80) != 0
	var interlace_flag: bool = (packed & 0x40) != 0
	var lct_size_exp: int = (packed & 0x07) + 1

	var active_palette: PackedColorArray = _global_color_table
	if lct_flag:
		active_palette = _read_color_table(1 << lct_size_exp)

	var min_code_size: int = _read_u8()
	var compressed_data: PackedByteArray = _read_sub_blocks_to_buffer()
	if compressed_data.is_empty():
		return null

	var pixel_indices: PackedByteArray = _decompress_lzw(compressed_data, min_code_size, img_width * img_height)

	var palette_size: int = active_palette.size()
	var dest_w: int = canvas.get_width()
	var dest_h: int = canvas.get_height()

	var interlaced_rows: PackedInt32Array = PackedInt32Array()
	if interlace_flag:
		interlaced_rows = _generate_interlace_row_indices(img_height)

	for src_idx: int in range(pixel_indices.size()):
		var local_x: int = src_idx % img_width
		var local_y: int = int(float(src_idx) / float(img_width))

		var final_y: int = interlaced_rows[local_y] if interlace_flag else local_y
		var canvas_x: int = img_left + local_x
		var canvas_y: int = img_top + final_y

		if canvas_x >= 0 and canvas_x < dest_w and canvas_y >= 0 and canvas_y < dest_h:
			var color_index: int = pixel_indices[src_idx]

			if _gce_transparent_flag and color_index == _gce_transparent_index:
				continue

			if color_index < palette_size:
				var pixel_color: Color = active_palette[color_index]
				canvas.set_pixel(canvas_x, canvas_y, pixel_color)

	return canvas.duplicate()


func _decompress_lzw(data: PackedByteArray, min_code_size: int, expected_pixels: int) -> PackedByteArray:
	var clear_code: int = 1 << min_code_size
	var end_code: int = clear_code + 1

	var code_size: int = min_code_size + 1
	var code_mask: int = (1 << code_size) - 1
	var next_code: int = end_code + 1

	var dict_prefix: PackedInt32Array = PackedInt32Array()
	dict_prefix.resize(MAX_DICTIONARY_SIZE)
	var dict_suffix: PackedByteArray = PackedByteArray()
	dict_suffix.resize(MAX_DICTIONARY_SIZE)

	var pixel_stack: PackedByteArray = PackedByteArray()
	pixel_stack.resize(MAX_DICTIONARY_SIZE + 2)
	var stack_ptr: int = 0

	var out_pixels: PackedByteArray = PackedByteArray()
	out_pixels.resize(expected_pixels)
	var out_idx: int = 0

	var bit_acc: int = 0
	var bit_count: int = 0
	var data_pos: int = 0
	var data_size: int = data.size()

	var old_code: int = -1
	var first_char: int = 0

	for i: int in range(clear_code):
		dict_prefix[i] = -1
		dict_suffix[i] = i

	while data_pos < data_size and out_idx < expected_pixels:
		while bit_count < code_size and data_pos < data_size:
			bit_acc |= (int(data[data_pos]) << bit_count)
			bit_count += 8
			data_pos += 1

		if bit_count < code_size:
			break

		var code: int = bit_acc & code_mask
		bit_acc >>= code_size
		bit_count -= code_size

		if code == clear_code:
			code_size = min_code_size + 1
			code_mask = (1 << code_size) - 1
			next_code = end_code + 1
			old_code = -1
			continue

		if code == end_code:
			break

		if old_code == -1:
			if code < next_code:
				out_pixels[out_idx] = dict_suffix[code]
				out_idx += 1
				old_code = code
				first_char = code
			continue

		var in_code: int = code
		if code >= next_code:
			pixel_stack[stack_ptr] = first_char
			stack_ptr += 1
			code = old_code

		var loop_guard: int = 0
		while code >= clear_code and code < MAX_DICTIONARY_SIZE:
			if stack_ptr >= MAX_DICTIONARY_SIZE:
				break
			pixel_stack[stack_ptr] = dict_suffix[code]
			stack_ptr += 1
			var next_prefix: int = dict_prefix[code]
			if next_prefix == code or loop_guard > MAX_DICTIONARY_SIZE:
				break
			code = next_prefix
			loop_guard += 1

		first_char = int(dict_suffix[code])
		if stack_ptr < MAX_DICTIONARY_SIZE:
			pixel_stack[stack_ptr] = first_char
			stack_ptr += 1

		while stack_ptr > 0:
			stack_ptr -= 1
			if out_idx < expected_pixels:
				out_pixels[out_idx] = pixel_stack[stack_ptr]
				out_idx += 1

		if next_code < MAX_DICTIONARY_SIZE:
			dict_prefix[next_code] = old_code
			dict_suffix[next_code] = first_char
			next_code += 1

			if next_code > code_mask and code_size < MAX_LZW_BITS:
				code_size += 1
				code_mask = (1 << code_size) - 1

		old_code = in_code

	return out_pixels


func _generate_interlace_row_indices(height: int) -> PackedInt32Array:
	var rows: PackedInt32Array = PackedInt32Array()
	rows.resize(height)
	var cursor: int = 0

	var y: int = 0
	while y < height:
		rows[cursor] = y
		cursor += 1
		y += 8

	y = 4
	while y < height:
		rows[cursor] = y
		cursor += 1
		y += 8

	y = 2
	while y < height:
		rows[cursor] = y
		cursor += 1
		y += 4

	y = 1
	while y < height:
		rows[cursor] = y
		cursor += 1
		y += 2

	return rows


func _read_sub_blocks_to_buffer() -> PackedByteArray:
	var buffer: PackedByteArray = PackedByteArray()
	while _pos < _bytes.size():
		var block_len: int = _read_u8()
		if block_len <= 0:
			break
		var end_idx: int = mini(_pos + block_len, _bytes.size())
		buffer.append_array(_bytes.slice(_pos, end_idx))
		_pos = end_idx
	return buffer


func _skip_sub_blocks() -> void:
	while _pos < _bytes.size():
		var block_len: int = _read_u8()
		if block_len <= 0:
			break
		_pos += block_len


func _read_color_table(num_entries: int) -> PackedColorArray:
	var colors: PackedColorArray = PackedColorArray()
	colors.resize(num_entries)

	for i: int in range(num_entries):
		if _pos + 3 <= _bytes.size():
			var r: float = float(_bytes[_pos]) / 255.0
			var g: float = float(_bytes[_pos + 1]) / 255.0
			var b: float = float(_bytes[_pos + 2]) / 255.0
			colors[i] = Color(r, g, b, 1.0)
			_pos += 3
		else:
			colors[i] = Color.BLACK
	return colors


func _create_grayscale_palette() -> PackedColorArray:
	var colors: PackedColorArray = PackedColorArray()
	colors.resize(256)
	for i: int in range(256):
		var v: float = float(i) / 255.0
		colors[i] = Color(v, v, v, 1.0)
	return colors


func _reset_gce() -> void:
	_gce_transparent_flag = false
	_gce_transparent_index = 0
	_gce_delay_sec = 0.10
	_gce_disposal_method = 0


func _read_u8() -> int:
	if _pos < _bytes.size():
		var val: int = int(_bytes[_pos])
		_pos += 1
		return val
	return -1


func _read_u16() -> int:
	if _pos + 1 < _bytes.size():
		var val: int = int(_bytes[_pos]) | (int(_bytes[_pos + 1]) << 8)
		_pos += 2
		return val
	return 0


func _read_ascii(length: int) -> String:
	var end_idx: int = mini(_pos + length, _bytes.size())
	var sub: PackedByteArray = _bytes.slice(_pos, end_idx)
	_pos = end_idx
	return sub.get_string_from_ascii()
