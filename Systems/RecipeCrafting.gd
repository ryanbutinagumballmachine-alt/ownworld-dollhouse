# ==============================================================================
# OWNWORLD — RECIPE CRAFTING
# File: res://Systems/RecipeCrafting.gd
# Base Class: RefCounted (class_name RecipeCrafting)
# ==============================================================================

class_name RecipeCrafting
extends RefCounted

static var active_recipes: Dictionary = {}
const RECIPES_FILE_NAME: String = "recipes.json"


static func get_recipes_path(universe_id: String) -> String:
	return SaveSystem.get_universe_save_dir(universe_id) + RECIPES_FILE_NAME


static func load_recipes_for_universe(universe_id: String) -> void:
	active_recipes.clear()
	var clean_universe_id: String = universe_id.strip_edges()
	if clean_universe_id.is_empty():
		return

	var path: String = get_recipes_path(clean_universe_id)
	if not FileAccess.file_exists(path):
		return

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Dictionary:
			active_recipes = (parsed as Dictionary).duplicate(true)


static func save_recipes_for_universe(universe_id: String) -> void:
	var clean_universe_id: String = universe_id.strip_edges()
	if clean_universe_id.is_empty():
		return

	var universe_dir: String = SaveSystem.get_universe_save_dir(clean_universe_id)
	if not DirAccess.dir_exists_absolute(universe_dir):
		DirAccess.make_dir_recursive_absolute(universe_dir)

	var path: String = universe_dir + RECIPES_FILE_NAME
	var temp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return

	file.store_string(JSON.stringify(active_recipes, "\t"))
	file.flush()
	file.close()

	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	DirAccess.rename_absolute(temp_path, path)


static func register_recipe(item_a_name: String, item_b_name: String, result_name: String, result_type: Types.EntityType, result_texture_path: String = "") -> void:
	var normalized_a: String = item_a_name.to_lower().strip_edges()
	var normalized_b: String = item_b_name.to_lower().strip_edges()
	if normalized_a.is_empty() or normalized_b.is_empty() or result_name.strip_edges().is_empty():
		return

	var recipe_entry: Dictionary = {
		"name": result_name,
		"type": int(result_type),
		"tex_path": result_texture_path
	}

	active_recipes["%s+%s" % [normalized_a, normalized_b]] = recipe_entry
	active_recipes["%s+%s" % [normalized_b, normalized_a]] = recipe_entry
	save_recipes_for_universe(SaveSystem.get_current_universe_id())


static func check_and_craft(source_item: OwnEntity, target_item: OwnEntity) -> Dictionary:
	if not is_instance_valid(source_item) or not is_instance_valid(target_item):
		return {}

	var source_name: String = source_item.display_name.to_lower().strip_edges()
	var target_name: String = target_item.display_name.to_lower().strip_edges()
	var key: String = "%s+%s" % [source_name, target_name]

	var recipe: Variant = active_recipes.get(key, {})
	return (recipe as Dictionary).duplicate(true) if recipe is Dictionary else {}


static func spawn_merge_poof(parent_canvas: Node2D, world_pos: Vector2) -> void:
	if parent_canvas == null:
		return

	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.position = world_pos
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.amount = 16
	particles.lifetime = 0.5
	particles.spread = 180.0
	particles.gravity = Vector2(0.0, -20.0)
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 120.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.5
	parent_canvas.add_child(particles)
	particles.finished.connect(particles.queue_free)
