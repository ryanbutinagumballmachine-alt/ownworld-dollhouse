@tool
extends EditorScript

# Increments patch version (e.g. 1.0.22 -> 1.0.23) and bumps Android version_code
func _run() -> void:
	# 1. Read and calculate new version string
	var current_version: String = str(ProjectSettings.get_setting("application/config/version", "1.0.0")).strip_edges()
	var parts: PackedStringArray = current_version.split(".")
	
	var major: int = parts[0].to_int() if parts.size() > 0 and parts[0].is_valid_int() else 1
	var minor: int = parts[1].to_int() if parts.size() > 1 and parts[1].is_valid_int() else 0
	var patch: int = parts[2].to_int() if parts.size() > 2 and parts[2].is_valid_int() else 0
	
	patch += 1
	var new_version: String = "%d.%d.%d" % [major, minor, patch]

	# 2. Update and save project.godot
	ProjectSettings.set_setting("application/config/version", new_version)
	ProjectSettings.save()

	# 3. Update export_presets.cfg
	var cfg_path: String = "res://tools/export_presets.cfg"
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load(cfg_path)

	var new_code: int = patch
	if err == OK:
		for section in config.get_sections():
			if section.ends_with(".options"):
				# Android Preset options
				if config.has_section_key(section, "version/code"):
					var code: int = int(config.get_value(section, "version/code", 1)) + 1
					config.set_value(section, "version/code", code)
					config.set_value(section, "version/name", new_version)
					new_code = code
				
				# Windows Desktop options (optional sync)
				if config.has_section_key(section, "application/file_version"):
					config.set_value(section, "application/file_version", new_version)
					config.set_value(section, "application/product_version", new_version)

		config.save(cfg_path)
		print_rich("[color=green][b]✔ [Version Bumper][/b] Updated version to [b]%s[/b] (Android Code: [b]%d[/b]) across project.godot and export_presets.cfg![/color]" % [new_version, new_code])
	else:
		push_warning("Could not load export_presets.cfg, but project.godot was updated to " + new_version)
