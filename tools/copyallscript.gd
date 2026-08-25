@tool
extends EditorScript

const EXTENSIONS: Array[String] = [".gd", ".cs"]
const IGNORED_DIRS: Array[String] = [".godot", ".git", ".import"]
const IGNORE_ADDONS: bool = true

func _run() -> void:
	var script_paths: Array[String] = []
	_scan_dir("res://", script_paths)
	
	if script_paths.is_empty():
		print("No scripts found.")
		return
	
	var combined_text: String = ""
	var count: int = 0
	
	for path in script_paths:
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			var content := file.get_as_text()
			file.close()
			
			combined_text += "# " + "=".repeat(60) + "\n"
			combined_text += "# File: " + path + "\n"
			combined_text += "# " + "=".repeat(60) + "\n\n"
			combined_text += content + "\n\n"
			count += 1
		else:
			push_warning("Could not read file: " + path)
	
	DisplayServer.clipboard_set(combined_text)
	print("Copied %d scripts to clipboard! (Total characters: %d)" % [count, combined_text.length()])

func _scan_dir(dir_path: String, out_files: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var item_name := dir.get_next()
	
	while item_name != "":
		if item_name.begins_with(".") and item_name in IGNORED_DIRS:
			item_name = dir.get_next()
			continue
		
		if IGNORE_ADDONS and item_name == "addons" and dir_path == "res://":
			item_name = dir.get_next()
			continue

		var full_path := dir_path.path_join(item_name)
		if dir.current_is_dir():
			if not item_name.begins_with("."):
				_scan_dir(full_path, out_files)
		else:
			for ext in EXTENSIONS:
				if item_name.ends_with(ext):
					out_files.append(full_path)
					break
					
		item_name = dir.get_next()
	
	dir.list_dir_end()
