# ==============================================================================
# OWNWORLD — SCRIPT CONCATENATION & CLIPBOARD EXPORTER
# File: res://tools/copyallscript.gd
# Base Class: EditorScript
#
# Responsibility: Scans res:// for GDScript and C# source files, combines them
# into formatted markdown blocks, and copies the entire codebase to the clipboard.
# ==============================================================================

@tool
extends EditorScript

const EXTENSIONS: Array[String] = [".gd", ".cs"]
const IGNORED_DIRS: Array[String] = [".godot", ".git", ".import"]
const IGNORE_ADDONS: bool = true


func _run() -> void:
	var script_paths: Array[String] = []
	_scan_dir_iterative("res://", script_paths)
	
	if script_paths.is_empty():
		print("No scripts found.")
		return
	
	var output_chunks: PackedStringArray = []
	var count: int = 0
	
	for path: String in script_paths:
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file != null:
			var content: String = file.get_as_text()
			file.close()
			
			output_chunks.append("# " + "=".repeat(60))
			output_chunks.append("# File: " + path)
			output_chunks.append("# " + "=".repeat(60) + "\n")
			output_chunks.append(content + "\n")
			count += 1
		else:
			push_warning("Could not read file: " + path)
	
	var combined_text: String = "\n".join(output_chunks)
	DisplayServer.clipboard_set(combined_text)
	print("Copied %d scripts to clipboard! (Total characters: %d)" % [count, combined_text.length()])


## Iterative directory scanner to prevent stack overflows on massive projects.
func _scan_dir_iterative(start_path: String, out_files: Array[String]) -> void:
	var dirs_to_scan: Array[String] = [start_path]
	
	while not dirs_to_scan.is_empty():
		var current_dir: String = dirs_to_scan.pop_back()
		var dir: DirAccess = DirAccess.open(current_dir)
		if dir == null:
			continue
		
		dir.list_dir_begin()
		var item_name: String = dir.get_next()
		
		while not item_name.is_empty():
			if item_name.begins_with(".") and item_name in IGNORED_DIRS:
				item_name = dir.get_next()
				continue
			
			if IGNORE_ADDONS and item_name == "addons" and current_dir == "res://":
				item_name = dir.get_next()
				continue

			var full_path: String = current_dir.path_join(item_name)
			if dir.current_is_dir():
				if not item_name.begins_with("."):
					dirs_to_scan.append(full_path)
			else:
				for ext: String in EXTENSIONS:
					if item_name.ends_with(ext):
						out_files.append(full_path)
						break
						
			item_name = dir.get_next()
		
		dir.list_dir_end()
