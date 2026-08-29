# ==============================================================================
# OWNWORLD — MAIN APPLICATION ORCHESTRATOR (HYPER OPTIMIZED)
# File: res://Core/Main.gd
# Base Class: Node2D
#
# Responsibility: Master runtime scene orchestrator. Coordinates multi-slice
# room rendering, smooth room transitions, safe area layout insets, and OS back gestures.
# Input handling is fully delegated to HyperInputRouter.
# ==============================================================================

extends Node2D

const BASE_ROOM_SIZE: Vector2 = Vector2(1280.0, 720.0)

var room_slices: Array[Dictionary] = [{
	"wallpaper_path": "", "fill_mode": "cover", "is_outdoor": false,
	"wall_color": "", "floor_color": "", "baseboard_color": ""
}]
var room_bounds: Rect2 = Rect2(Vector2.ZERO, BASE_ROOM_SIZE)
var current_room_floor_y: float = 580.0
var current_room_title: String = "Main Room"
var current_room_floor_level: String = "1F"
var current_building_id: String = "building_main"
var current_building_name: String = "Main Building"

var world_canvas: Node2D = null
var room_default_bg: ColorRect = null
var room_slices_container: Node2D = null

var floor_guide_line: Line2D = null
var main_camera: TouchCameraController = null
var atmosphere: AtmosphereController = null

# Smooth Cross-Fade Transition Overlay
var transition_layer: CanvasLayer = null
var transition_rect: ColorRect = null
var is_transitioning_room: bool = false

var main_menu_ui: MainMenuUI = null
var world_map_screen: WorldMapController = null
var universe_hub_ui: UniverseHubUI = null
var universe_journal_ui: CanvasLayer = null
var magic_wheel_ui: MagicWheel = null
var lore_card_ui: CanvasLayer = null
var tutorial_dialog: TutorialDialog = null

var pose_anim_studio_ui: PoseAnimationStudioDialog = null
var snap_studio_ui: SnapPointStudioDialog = null
var light_studio_ui: LightStudioDialog = null
var food_studio_ui: FoodStudioDialog = null
var room_studio_ui: RoomStudioDialog = null
var entity_config_dialog: EntityConfigDialog = null
var logic_rule_dialog: LogicRuleEditorDialog = null
var recipe_studio_dialog: RecipeStudioDialog = null
var container_storage_dialog: ContainerStorageDialog = null
var door_editor_dialog: DoorDestinationDialog = null
var elevator_dialog: ElevatorFloorDialog = null
var theme_studio_dialog: ThemeStudioDialog = null
var settings_dialog: SettingsDialog = null
var diagnostic_overlay: DiagnosticOverlay = null

var drawer_tray_ui: DrawerTray = null
var top_nav_bar: TopNavBar = null

var interaction_router: EntityInteractionRouter = null
var interaction_controller: WorldInteractionController = null

var all_entities: Array[OwnEntity] = []
var is_room_loaded: bool = false


func _ready() -> void:
	set_process(false)
	get_tree().quit_on_go_back = false

	if OS.has_feature("android") or OS.has_feature("mobile"):
		OS.request_permissions()

	_ensure_ugc_directories()
	_enforce_cross_platform_viewport()
	_mount_subsystems()
	_connect_system_signals()

	RecipeCrafting.load_recipes_for_universe(AppState.universe_id)
	_load_active_room(AppState.room_id)

	ThemeService.apply_theme_globally()
	_update_room_bg_theme_color()

	var win: Window = get_window()
	if win != null and not win.size_changed.is_connected(_on_window_resized):
		win.size_changed.connect(_on_window_resized)

	_apply_hardware_safe_margins()

	if main_menu_ui != null:
		main_menu_ui.open_menu()


func _ensure_ugc_directories() -> void:
	UGCManager.ensure_all_directories()


func _enforce_cross_platform_viewport() -> void:
	var win: Window = get_window()
	if win == null: return
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	win.content_scale_size = Vector2i(1280, 720)

	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)


func _apply_hardware_safe_margins() -> void:
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	if screen_size.x <= 0 or screen_size.y <= 0 or safe_area.size.x <= 0:
		return

	var top_margin: float = float(safe_area.position.y)
	var bottom_margin: float = float(screen_size.y - (safe_area.position.y + safe_area.size.y))

	if top_nav_bar != null and top_nav_bar.root_container != null:
		top_nav_bar.root_container.offset_top = maxf(10.0, top_margin + 4.0)

	if drawer_tray_ui != null and drawer_tray_ui.root_panel != null:
		var bottom_offset: float = -maxf(8.0, bottom_margin + 6.0)
		drawer_tray_ui.root_panel.offset_bottom = bottom_offset
		drawer_tray_ui.root_panel.offset_top = bottom_offset - drawer_tray_ui.DRAWER_HEIGHT


func _on_window_resized() -> void:
	_apply_room_slices(room_slices)
	_update_room_bg_theme_color()
	_apply_hardware_safe_margins()


func _get_device_screen_slice_size() -> Vector2:
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		vp_size = BASE_ROOM_SIZE
	return vp_size


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_mobile_back_button()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveSystem.save_current_room_state()
		AppState.save_session_to_disk()
		if drawer_tray_ui != null: drawer_tray_ui.save_cast_tray_for_current_universe()
		if world_map_screen != null: world_map_screen.save_map_for_current_universe()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if HyperInputRouter.has_method("_cancel_drag"):
			HyperInputRouter.call("_cancel_drag")
		if is_room_loaded:
			SaveSystem.save_current_room_state()
		AppState.save_session_to_disk()


func _handle_mobile_back_button() -> void:
	if magic_wheel_ui != null and magic_wheel_ui.visible:
		magic_wheel_ui.close_wheel()
		return
	if drawer_tray_ui != null and drawer_tray_ui.is_drawer_open:
		drawer_tray_ui._toggle_drawer_state()
		return
	if tutorial_dialog != null and tutorial_dialog.visible:
		tutorial_dialog.close_handbook()
		return
	for ui: Node in get_tree().get_nodes_in_group("modal_ui"):
		if is_instance_valid(ui) and ui != main_menu_ui:
			if ui is CanvasLayer and (ui as CanvasLayer).visible:
				if ui.has_method("close_dialog"): ui.call("close_dialog")
				elif ui.has_method("close_studio"): ui.call("close_studio")
				elif ui.has_method("close_map"): ui.call("close_map")
				elif ui.has_method("close_hub"): ui.call("close_hub")
				else: (ui as CanvasLayer).visible = false
				return
	if main_menu_ui != null and not main_menu_ui.visible:
		main_menu_ui.open_menu()
	else:
		SaveSystem.save_current_room_state()
		get_tree().quit()


func _mount_subsystems() -> void:
	world_canvas = Node2D.new()
	world_canvas.name = "WorldCanvas"
	world_canvas.y_sort_enabled = true
	add_child(world_canvas)

	room_default_bg = ColorRect.new()
	room_default_bg.name = "RoomDefaultColorBg"
	room_default_bg.position = Vector2(-2000.0, -2000.0)
	room_default_bg.size = Vector2(25000.0, 6000.0)
	room_default_bg.z_index = Types.LayerBands.BACKGROUND - 5
	room_default_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_canvas.add_child(room_default_bg)
	ThemeService.register_background(room_default_bg)

	room_slices_container = Node2D.new()
	room_slices_container.name = "RoomSlicesContainer"
	room_slices_container.z_index = Types.LayerBands.BACKGROUND - 2
	world_canvas.add_child(room_slices_container)

	floor_guide_line = Line2D.new()
	floor_guide_line.name = "FloorGuideLine"
	floor_guide_line.width = 3.0
	floor_guide_line.default_color = Color("#38bdf8", 0.85)
	floor_guide_line.z_index = Types.LayerBands.FOREGROUND
	floor_guide_line.visible = false
	world_canvas.add_child(floor_guide_line)

	atmosphere = AtmosphereController.new()
	world_canvas.add_child(atmosphere)

	main_camera = TouchCameraController.new()
	add_child(main_camera)

	interaction_router = EntityInteractionRouter.new()
	add_child(interaction_router)

	interaction_controller = WorldInteractionController.new()
	interaction_controller.setup(world_canvas, interaction_router, all_entities)
	add_child(interaction_controller)

	transition_layer = CanvasLayer.new()
	transition_layer.name = "RoomTransitionCanvas"
	transition_layer.layer = 127
	add_child(transition_layer)

	transition_rect = ColorRect.new()
	transition_rect.name = "TransitionFadeRect"
	transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.add_child(transition_rect)

	main_menu_ui = MainMenuUI.new()
	main_menu_ui.open_universe_hub_requested.connect(func() -> void: if universe_hub_ui: universe_hub_ui.open_hub())
	main_menu_ui.open_world_map_requested.connect(func() -> void: if world_map_screen: world_map_screen.open_map())
	main_menu_ui.open_universe_journal_requested.connect(_on_open_universe_journal)
	main_menu_ui.open_room_studio_requested.connect(_on_open_room_studio)
	main_menu_ui.open_recipe_studio_requested.connect(func() -> void: if recipe_studio_dialog: recipe_studio_dialog.open_studio())
	main_menu_ui.open_theme_studio_requested.connect(func() -> void: if theme_studio_dialog: theme_studio_dialog.open_studio())
	main_menu_ui.open_settings_requested.connect(func() -> void: if settings_dialog: settings_dialog.open_settings())
	add_child(main_menu_ui)

	world_map_screen = WorldMapController.new()
	world_map_screen.reset_all_rooms_requested.connect(_on_reset_all_rooms_requested)
	add_child(world_map_screen)

	universe_hub_ui = UniverseHubUI.new()
	universe_hub_ui.universe_selected.connect(_on_universe_switched)
	add_child(universe_hub_ui)

	universe_journal_ui = UniverseJournalDialog.new()
	add_child(universe_journal_ui)

	magic_wheel_ui = MagicWheel.new()
	magic_wheel_ui.action_triggered.connect(_on_magic_wheel_action)
	add_child(magic_wheel_ui)

	lore_card_ui = CharacterLoreCard.new()
	add_child(lore_card_ui)

	pose_anim_studio_ui = PoseAnimationStudioDialog.new()
	add_child(pose_anim_studio_ui)

	snap_studio_ui = SnapPointStudioDialog.new()
	add_child(snap_studio_ui)

	light_studio_ui = LightStudioDialog.new()
	add_child(light_studio_ui)

	food_studio_ui = FoodStudioDialog.new()
	add_child(food_studio_ui)

	room_studio_ui = RoomStudioDialog.new()
	room_studio_ui.room_configured.connect(_on_room_configured)
	room_studio_ui.floor_preview_changed.connect(_on_floor_preview_changed)
	add_child(room_studio_ui)

	entity_config_dialog = EntityConfigDialog.new()
	add_child(entity_config_dialog)

	logic_rule_dialog = LogicRuleEditorDialog.new()
	add_child(logic_rule_dialog)

	recipe_studio_dialog = RecipeStudioDialog.new()
	add_child(recipe_studio_dialog)

	container_storage_dialog = ContainerStorageDialog.new()
	container_storage_dialog.item_unpacked_requested.connect(_on_item_unpacked_from_container)
	add_child(container_storage_dialog)

	door_editor_dialog = DoorDestinationDialog.new()
	add_child(door_editor_dialog)

	elevator_dialog = ElevatorFloorDialog.new()
	elevator_dialog.floor_travel_requested.connect(_on_elevator_floor_travel_requested)
	add_child(elevator_dialog)

	theme_studio_dialog = ThemeStudioDialog.new()
	add_child(theme_studio_dialog)

	settings_dialog = SettingsDialog.new()
	add_child(settings_dialog)

	diagnostic_overlay = DiagnosticOverlay.new()
	add_child(diagnostic_overlay)
	diagnostic_overlay.setup(self)

	drawer_tray_ui = DrawerTray.new()
	drawer_tray_ui.spawn_ugc_requested.connect(_on_drawer_spawn_ugc)
	drawer_tray_ui.character_spawn_requested.connect(_on_character_spawn_requested)
	drawer_tray_ui.template_spawn_requested.connect(_on_template_spawn_requested)
	add_child(drawer_tray_ui)

	top_nav_bar = TopNavBar.new()
	top_nav_bar.open_main_menu_requested.connect(func() -> void: if main_menu_ui: main_menu_ui.open_menu())
	top_nav_bar.open_world_map_requested.connect(func() -> void: if world_map_screen: world_map_screen.open_map())
	top_nav_bar.open_room_studio_requested.connect(_on_open_room_studio)
	top_nav_bar.toggle_zoom_mode_requested.connect(_toggle_camera_zoom_mode)
	top_nav_bar.undo_requested.connect(_on_undo_requested)
	top_nav_bar.open_floor_switcher_requested.connect(_on_top_nav_floor_switcher_requested)
	add_child(top_nav_bar)

	tutorial_dialog = TutorialDialog.new()
	add_child(tutorial_dialog)

	if main_menu_ui != null:
		main_menu_ui.open_tutorial_requested.connect(func() -> void:
			if tutorial_dialog != null: tutorial_dialog.open_handbook()
		)
	if top_nav_bar != null and top_nav_bar.has_signal("open_tutorial_requested"):
		top_nav_bar.connect("open_tutorial_requested", func() -> void:
			if tutorial_dialog != null: tutorial_dialog.open_handbook()
		)

	if HyperInputRouter.has_method("register_controllers"):
		HyperInputRouter.register_controllers(interaction_controller, main_camera, magic_wheel_ui, drawer_tray_ui, top_nav_bar)


func _toggle_camera_zoom_mode() -> void:
	if main_camera == null: return
	var is_active: bool = main_camera.toggle_zoom_mode()
	if top_nav_bar != null:
		top_nav_bar.set_zoom_button_state(is_active)
	EventBus.notification_requested.emit("Focus Mode: " + ("ENABLED" if is_active else "DISABLED"), true)


func _connect_system_signals() -> void:
	if not ThemeService.theme_changed.is_connected(_on_theme_changed):
		ThemeService.theme_changed.connect(_on_theme_changed)
	if EventBus.has_signal("room_changed") and not EventBus.room_changed.is_connected(_on_game_room_changed):
		EventBus.room_changed.connect(_on_game_room_changed)
	if EventBus.has_signal("global_atmosphere_changed") and not EventBus.global_atmosphere_changed.is_connected(_on_atmosphere_changed):
		EventBus.global_atmosphere_changed.connect(_on_atmosphere_changed)
	if EventBus.has_signal("character_data_changed") and not EventBus.character_data_changed.is_connected(_on_character_data_changed):
		EventBus.character_data_changed.connect(_on_character_data_changed)
	if EventBus.has_signal("entity_spawn_requested") and not EventBus.entity_spawn_requested.is_connected(_on_entity_spawn_requested):
		EventBus.entity_spawn_requested.connect(_on_entity_spawn_requested)
	if EventBus.has_signal("room_change_requested") and not EventBus.room_change_requested.is_connected(_on_room_change_requested):
		EventBus.room_change_requested.connect(_on_room_change_requested)

	var history_manager: Node = get_node_or_null("/root/HistoryManager")
	if history_manager != null and history_manager.has_signal("state_restored") and not history_manager.is_connected("state_restored", Callable(self, "_on_history_state_restored")):
		history_manager.connect("state_restored", Callable(self, "_on_history_state_restored"))


func _on_character_data_changed(character_id: String, character_data: Dictionary) -> void:
	var name_key: String = str(character_data.get("display_name", "")).strip_edges().to_lower()
	for entity: OwnEntity in all_entities:
		if not is_instance_valid(entity) or entity.entity_type != Types.EntityType.CHARACTER:
			continue
		var matches_id: bool = not character_id.is_empty() and entity.entity_id == character_id
		var matches_name: bool = not name_key.is_empty() and entity.display_name.strip_edges().to_lower() == name_key
		if matches_id or matches_name:
			entity.update_character_profile(character_data)


func _on_room_change_requested(target_room_id: String, traveler_data: Dictionary) -> void:
	_transition_to_room(target_room_id, traveler_data)


func _on_theme_changed(_theme_data: Dictionary) -> void:
	_update_room_bg_theme_color()


func _update_room_bg_theme_color() -> void:
	if room_default_bg != null:
		room_default_bg.color = ThemeService.get_color("window_background", "#fff5f7")
	_apply_room_slices(room_slices)


# --- MULTI-SLICE ROOM SPATIAL RENDERING ---

func _apply_room_slices(slices_data: Array[Dictionary]) -> void:
	room_slices = slices_data.duplicate(true)
	if room_slices.is_empty():
		room_slices.append({
			"wallpaper_path": "", "fill_mode": "cover", "is_outdoor": false,
			"wall_color": "", "floor_color": "", "baseboard_color": ""
		})

	var slice_size: Vector2 = _get_device_screen_slice_size()
	var slice_w: float = slice_size.x
	var slice_h: float = slice_size.y
	var total_width: float = float(room_slices.size()) * slice_w

	room_bounds = Rect2(0.0, 0.0, total_width, slice_h)

	if room_slices_container == null: return
	for child: Node in room_slices_container.get_children():
		child.queue_free()

	var default_wall: Color = ThemeService.get_color("window_background", "#fff5f7")
	var default_sub: Color = ThemeService.get_color("container_sub_bg", "#fff0f3")
	var default_border: Color = ThemeService.get_color("panel_border", "#f9a8d4")
	var baseboard_h: float = 8.0

	for i: int in range(room_slices.size()):
		var sec_data: Dictionary = room_slices[i]
		var wall_path: String = str(sec_data.get("wallpaper_path", "")).strip_edges()
		var fill_mode: String = str(sec_data.get("fill_mode", "cover"))
		var slice_offset_x: float = float(i) * slice_w
		var is_odd_slice: bool = (i % 2 == 1)

		var slice_node: Node2D = Node2D.new()
		slice_node.name = "Slice_%d" % i
		slice_node.position = Vector2(slice_offset_x, 0.0)

		var has_custom_art: bool = not wall_path.is_empty() and FileAccess.file_exists(wall_path)

		if has_custom_art:
			var wall_texture: Texture2D = UGCManager.load_texture_from_file(wall_path)
			if wall_texture != null:
				var sprite: Sprite2D = Sprite2D.new()
				sprite.texture = wall_texture
				_apply_slice_sprite_scaling(sprite, wall_texture, fill_mode, slice_w, slice_h)
				slice_node.add_child(sprite)
		else:
			var custom_wall_str: String = str(sec_data.get("wall_color", "")).strip_edges()
			var custom_floor_str: String = str(sec_data.get("floor_color", ""))
			var custom_trim_str: String = str(sec_data.get("baseboard_color", "")).strip_edges()

			var slice_wall_color: Color = Color(custom_wall_str) if not custom_wall_str.is_empty() else (default_wall.darkened(0.055) if is_odd_slice else default_wall)
			var slice_floor_color: Color = Color(custom_floor_str) if not custom_floor_str.is_empty() else (default_sub.darkened(0.20) if is_odd_slice else default_sub.darkened(0.12))
			var slice_trim_color: Color = Color(custom_trim_str) if not custom_trim_str.is_empty() else (default_border.darkened(0.15) if is_odd_slice else default_border.darkened(0.08))

			var wall_rect: ColorRect = ColorRect.new()
			wall_rect.name = "Wall"
			wall_rect.color = slice_wall_color
			wall_rect.position = Vector2.ZERO
			wall_rect.size = Vector2(slice_w, current_room_floor_y)
			wall_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slice_node.add_child(wall_rect)

			var baseboard_rect: ColorRect = ColorRect.new()
			baseboard_rect.name = "Baseboard"
			baseboard_rect.color = slice_trim_color
			baseboard_rect.position = Vector2(0.0, current_room_floor_y - baseboard_h)
			baseboard_rect.size = Vector2(slice_w, baseboard_h)
			baseboard_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slice_node.add_child(baseboard_rect)

			var floor_rect: ColorRect = ColorRect.new()
			floor_rect.name = "Floor"
			floor_rect.color = slice_floor_color
			floor_rect.position = Vector2(0.0, current_room_floor_y)
			floor_rect.size = Vector2(slice_w, maxf(0.0, slice_h - current_room_floor_y))
			floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slice_node.add_child(floor_rect)

		if i > 0:
			var seam_line: ColorRect = ColorRect.new()
			seam_line.name = "SliceDividerSeam"
			seam_line.position = Vector2.ZERO
			seam_line.size = Vector2(2.5, slice_h)
			seam_line.color = Color(default_border.r * 0.4, default_border.g * 0.4, default_border.b * 0.4, 0.45)
			seam_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slice_node.add_child(seam_line)

		room_slices_container.add_child(slice_node)

	if main_camera != null:
		main_camera.update_room_bounds(room_bounds)
	if interaction_controller != null:
		interaction_controller.room_bounds = room_bounds

	if atmosphere != null:
		atmosphere.configure_weather_slices(room_slices, slice_w)


func _apply_slice_sprite_scaling(sprite: Sprite2D, texture: Texture2D, fill_mode: String, slice_w: float, slice_h: float) -> void:
	var tw: float = float(texture.get_width())
	var th: float = float(texture.get_height())
	if tw <= 0.0 or th <= 0.0: return

	match fill_mode:
		"cover":
			sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
			sprite.region_enabled = false
			sprite.centered = true
			sprite.position = Vector2(slice_w * 0.5, slice_h * 0.5)
			var scale_cover: float = maxf(slice_w / tw, slice_h / th)
			sprite.scale = Vector2(scale_cover, scale_cover)
		"fit":
			sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
			sprite.region_enabled = false
			sprite.centered = true
			sprite.position = Vector2(slice_w * 0.5, slice_h * 0.5)
			var scale_fit: float = minf(slice_w / tw, slice_h / th)
			sprite.scale = Vector2(scale_fit, scale_fit)
		"stretch":
			sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
			sprite.region_enabled = false
			sprite.centered = false
			sprite.position = Vector2.ZERO
			sprite.scale = Vector2(slice_w / tw, slice_h / th)
		"tile":
			sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			sprite.region_enabled = true
			sprite.region_rect = Rect2(0.0, 0.0, slice_w, slice_h)
			sprite.centered = false
			sprite.position = Vector2.ZERO
			sprite.scale = Vector2.ONE
		"original":
			sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
			sprite.region_enabled = false
			sprite.centered = true
			sprite.position = Vector2(slice_w * 0.5, slice_h * 0.5)
			sprite.scale = Vector2.ONE


func _on_atmosphere_changed(time_preset: String, weather_preset: String) -> void:
	if atmosphere != null:
		atmosphere.set_preset(time_preset)
		atmosphere.set_weather(weather_preset)


# --- TRANSITIONS ---

func _transition_to_room(target_room_id: String, traveler_data: Dictionary = {}) -> void:
	var current_room_id_str: String = AppState.room_id
	if target_room_id.is_empty() or is_transitioning_room:
		return
	if target_room_id == current_room_id_str and traveler_data.is_empty():
		return

	is_transitioning_room = true
	SaveSystem.save_current_room_state()

	if transition_rect != null:
		transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		var tw_out: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw_out.tween_property(transition_rect, "color:a", 1.0, 0.18)
		await tw_out.finished

	AppState.set_active_room(target_room_id)
	_load_active_room(target_room_id, traveler_data)

	if transition_rect != null:
		var tw_in: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw_in.tween_property(transition_rect, "color:a", 0.0, 0.22)
		await tw_in.finished
		transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	is_transitioning_room = false

	if EventBus.has_signal("room_changed"):
		EventBus.room_changed.emit(target_room_id, current_room_id_str, traveler_data)
	else:
		_on_game_room_changed(target_room_id, current_room_id_str, traveler_data)


func _on_open_universe_journal() -> void:
	if universe_journal_ui != null and universe_journal_ui.has_method("open_journal"):
		universe_journal_ui.call("open_journal")


func _on_open_room_studio() -> void:
	_update_floor_guide_visuals(current_room_floor_y, true)
	if room_studio_ui != null:
		room_studio_ui.open_studio(
			current_room_title,
			current_room_floor_y,
			room_slices,
			current_room_floor_level,
			current_building_name,
			current_building_id,
			AppState.room_id
		)


func _on_floor_preview_changed(preview_y: float, preview_visible: bool) -> void:
	current_room_floor_y = preview_y
	if interaction_controller: interaction_controller.current_floor_y = preview_y
	_apply_room_slices(room_slices)
	_update_floor_guide_visuals(preview_y, preview_visible)


func _on_room_configured(slices_data: Array[Dictionary], floor_y: float, room_name: String, floor_level: String, bldg_name: String = "", bldg_id: String = "") -> void:
	current_room_floor_y = floor_y
	current_room_title = room_name if not room_name.is_empty() else AppState.room_id
	if interaction_controller: 
		interaction_controller.current_floor_y = floor_y
	
	var b_id: String = bldg_id if not bldg_id.is_empty() else AppState.building_id
	var b_name: String = bldg_name if not bldg_name.is_empty() else AppState.building_name
	var f_lvl: String = floor_level if not floor_level.is_empty() else "1F"

	current_building_id = b_id
	current_building_name = b_name
	current_room_floor_level = f_lvl

	AppState.set_active_room(AppState.room_id, f_lvl, b_id, b_name)

	_apply_room_slices(slices_data)
	_update_floor_guide_visuals(floor_y, false)
	_record_history()
	SaveSystem.save_current_room_state()


func _update_floor_guide_visuals(floor_y: float, preview_visible: bool) -> void:
	if floor_guide_line == null: return
	if preview_visible:
		floor_guide_line.clear_points()
		floor_guide_line.add_point(Vector2(0.0, floor_y))
		floor_guide_line.add_point(Vector2(room_bounds.size.x, floor_y))
		floor_guide_line.visible = true
	else:
		floor_guide_line.visible = false


static func parse_floor_info(raw_label: String) -> Dictionary:
	var text: String = raw_label.strip_edges()
	if text.is_empty(): return {"floor_level": "1F", "title": "Main Room"}

	var words: PackedStringArray = text.split(" ", false)
	if words.is_empty(): return {"floor_level": "1F", "title": text}

	var first_word: String = words[0].strip_edges()
	var upper_first: String = first_word.to_upper()

	if (upper_first.ends_with("F") and upper_first.trim_suffix("F").is_valid_int()) or (upper_first.begins_with("B") and upper_first.trim_prefix("B").is_valid_int()):
		var fl: String = upper_first
		var title: String = text.trim_prefix(first_word).strip_edges().trim_prefix("-").strip_edges()
		return {"floor_level": fl, "title": title if not title.is_empty() else text}

	if (upper_first == "FLOOR" or upper_first == "LEVEL" or upper_first == "FL") and words.size() >= 2:
		var num: String = words[1].strip_edges()
		if num.is_valid_int():
			var fl: String = num + "F"
			var prefix_len: int = words[0].length() + 1 + words[1].length()
			var title: String = text.substr(prefix_len).strip_edges().trim_prefix("-").strip_edges()
			return {"floor_level": fl, "title": title if not title.is_empty() else text}

	if upper_first in ["ATTIC", "ROOF", "ROOFTOP", "BASEMENT", "CELLAR", "LOBBY", "MEZZANINE"]:
		var fl: String = first_word.capitalize()
		var title: String = text.trim_prefix(first_word).strip_edges().trim_prefix("-").strip_edges()
		return {"floor_level": fl, "title": title if not title.is_empty() else text}

	if text.length() <= 4:
		return {"floor_level": text.to_upper(), "title": text}

	return {"floor_level": "1F", "title": text}


func _load_active_room(room_id: String, traveler_data: Dictionary = {}) -> void:
	is_room_loaded = false
	RoomManager.stream_room(room_id, traveler_data, world_canvas, all_entities)

	var saved_state: Dictionary = SaveSystem.load_room_state(room_id)
	current_room_floor_y = float(saved_state.get("floor_y", 580.0))
	if interaction_controller: interaction_controller.current_floor_y = current_room_floor_y

	var target_bldg_id: String = str(saved_state.get("building_id", "")).strip_edges()
	var target_bldg_name: String = str(saved_state.get("building_name", "")).strip_edges()

	if traveler_data.has("building_id") and not str(traveler_data["building_id"]).is_empty():
		target_bldg_id = str(traveler_data["building_id"]).strip_edges()
	if traveler_data.has("building_name") and not str(traveler_data["building_name"]).is_empty():
		target_bldg_name = str(traveler_data["building_name"]).strip_edges()

	if target_bldg_id.is_empty(): target_bldg_id = "building_main"
	if target_bldg_name.is_empty(): target_bldg_name = "Main Building"

	current_building_id = target_bldg_id
	current_building_name = target_bldg_name

	var target_floor_level: String = str(saved_state.get("floor_level", "")).strip_edges()
	var target_title: String = str(saved_state.get("room_title", "")).strip_edges()

	var floor_name_from_travel: String = str(traveler_data.get("floor_name", "")).strip_edges()
	if not floor_name_from_travel.is_empty():
		var parsed_info: Dictionary = parse_floor_info(floor_name_from_travel)
		if target_floor_level.is_empty() or saved_state.is_empty() or target_floor_level == "1F":
			target_floor_level = str(parsed_info.get("floor_level", "1F"))
		if target_title.is_empty() or target_title == room_id:
			target_title = str(parsed_info.get("title", room_id))

	if traveler_data.has("floor_level") and not str(traveler_data["floor_level"]).is_empty():
		target_floor_level = str(traveler_data["floor_level"])

	if target_floor_level.is_empty(): target_floor_level = "1F"
	if target_title.is_empty(): target_title = current_building_name + " (" + target_floor_level + ")"

	current_room_floor_level = target_floor_level
	current_room_title = target_title

	AppState.set_active_room(room_id, current_room_floor_level, current_building_id, current_building_name)

	if top_nav_bar != null:
		top_nav_bar.update_current_floor_display(current_room_floor_level, current_room_title)

	var raw_slices: Variant = saved_state.get("slices", null)
	var loaded_slices: Array[Dictionary] = []
	if raw_slices is Array and not (raw_slices as Array).is_empty():
		for item: Variant in (raw_slices as Array):
			if item is Dictionary: loaded_slices.append((item as Dictionary).duplicate(true))
	elif saved_state.has("sections") and saved_state["sections"] is Array:
		for item: Variant in (saved_state["sections"] as Array):
			if item is Dictionary: loaded_slices.append((item as Dictionary).duplicate(true))
	else:
		var wall_path: String = str(saved_state.get("wallpaper_path", ""))
		var fill_mode: String = str(saved_state.get("fill_mode", "cover"))
		var is_outdoor: bool = bool(saved_state.get("is_outdoor", false))
		loaded_slices.append({
			"wallpaper_path": wall_path, "fill_mode": fill_mode, "is_outdoor": is_outdoor,
			"wall_color": "", "floor_color": "", "baseboard_color": ""
		})

	_apply_room_slices(loaded_slices)

	if atmosphere != null:
		atmosphere.set_preset(AppState.time_preset)
		atmosphere.set_weather(AppState.weather_preset)

	_update_floor_guide_visuals(current_room_floor_y, false)

	if main_camera != null:
		main_camera.update_room_bounds(room_bounds)
		var spawn_pos: Vector2 = RoomManager.resolve_traveler_spawn_position(traveler_data, all_entities)
		main_camera.reset_to_default_view(spawn_pos.x if not traveler_data.is_empty() else -1.0)
		if top_nav_bar != null:
			top_nav_bar.set_zoom_button_state(false)

	if drawer_tray_ui != null: drawer_tray_ui.refresh_tray()
	is_room_loaded = true

	SaveSystem.save_current_room_state()

	var history_manager: Node = get_node_or_null("/root/HistoryManager")
	if history_manager != null:
		history_manager.call("clear_history")
		history_manager.call("record_snapshot", _serialize_state())


func _on_game_room_changed(new_room: String, _departing_room: String, traveler_data: Dictionary) -> void:
	_load_active_room(new_room, traveler_data)


func _on_universe_switched(new_u_id: String, new_u_name: String) -> void:
	SaveSystem.save_current_room_state()
	AppState.switch_universe(new_u_id, new_u_name, "room_main")
	RecipeCrafting.load_recipes_for_universe(new_u_id)

	if world_map_screen != null: world_map_screen.load_map_for_current_universe()
	if drawer_tray_ui != null: drawer_tray_ui.load_cast_tray_for_current_universe()
	_load_active_room("room_main")


func _on_reset_all_rooms_requested() -> void:
	var rescued_count: int = 0
	var characters_to_rescue: Array[OwnEntity] = []

	for entity: OwnEntity in all_entities:
		if is_instance_valid(entity) and entity.entity_type == Types.EntityType.CHARACTER:
			characters_to_rescue.append(entity)

	for character: OwnEntity in characters_to_rescue:
		if not is_instance_valid(character): continue
		all_entities.erase(character)
		if drawer_tray_ui != null: drawer_tray_ui.store_character_in_tray(character)
		rescued_count += 1

	RoomRepository.clear_universe(AppState.universe_id)
	_load_active_room("room_main")
	EventBus.notification_requested.emit("Rooms Reset. %d Character(s) returned to Cast Tray!" % rescued_count, true)


func _record_history() -> void:
	var history: Node = get_node_or_null("/root/HistoryManager")
	if history != null and history.has_method("record_snapshot"):
		history.call("record_snapshot", _serialize_state())


func get_current_room_state() -> Dictionary:
	return _serialize_state()


func _serialize_state() -> Dictionary:
	var entities: Array[Dictionary] = []
	for entity: OwnEntity in all_entities:
		if is_instance_valid(entity):
			if entity.parent_socket_entity == null:
				entities.append_array(entity.get_full_hierarchy_bundle())
			if entity.entity_type == Types.EntityType.CHARACTER:
				SaveSystem.update_character_in_cast(entity)

	var camera_position: Vector2 = main_camera.position if main_camera != null else room_bounds.get_center()
	var camera_zoom: float = main_camera.zoom.x if main_camera != null else 1.0

	return SaveSchema.create_room(
		AppState.room_id,
		current_room_title,
		current_room_floor_y,
		room_slices,
		camera_position,
		camera_zoom,
		entities,
		current_room_floor_level,
		current_building_id,
		current_building_name
	)


func _on_history_state_restored(snapshot: Dictionary) -> void:
	if snapshot.has("floor_y"): 
		current_room_floor_y = float(snapshot["floor_y"])
		if interaction_controller: interaction_controller.current_floor_y = current_room_floor_y
	if snapshot.has("room_title"):
		current_room_title = str(snapshot["room_title"])
	if snapshot.has("floor_level"):
		current_room_floor_level = str(snapshot["floor_level"])
	if snapshot.has("slices") and snapshot["slices"] is Array:
		var restored_slices: Array[Dictionary] = []
		for s: Variant in (snapshot["slices"] as Array):
			if s is Dictionary: restored_slices.append((s as Dictionary).duplicate(true))
		_apply_room_slices(restored_slices)
	RoomManager.deserialize_room_into_canvas(snapshot, world_canvas, all_entities)
	_update_floor_guide_visuals(current_room_floor_y, false)
	SaveSystem.save_current_room_state()


func _on_drawer_spawn_ugc(item_name: String, texture: Texture2D, file_path: String) -> void:
	var texture_height: float = float(texture.get_height()) if texture != null else 64.0
	var scale_factor: float = clampf(180.0 / texture_height, 0.08, 1.0) if texture_height > 240.0 else 1.0
	var uid: String = AppState.generate_entity_uuid(item_name)
	var entity: OwnEntity = OwnEntity.new()
	var center_x: float = main_camera.position.x if main_camera != null else room_bounds.get_center().x
	var spawn_x: float = clampf(center_x + randf_range(-40.0, 40.0), 100.0, room_bounds.end.x - 100.0)

	entity.setup(uid, item_name, texture, Vector2(spawn_x, current_room_floor_y), Types.EntityType.PROP, file_path)
	entity.set_entity_scale(scale_factor)

	var bottom_offset: float = entity.get_visual_bottom_offset()
	entity.position.y = clampf(current_room_floor_y - bottom_offset, 100.0, room_bounds.end.y - 100.0)

	world_canvas.add_child(entity)
	all_entities.append(entity)
	entity.trigger_spawn_juice()
	_trigger_haptic(30)
	_record_history()
	SaveSystem.save_current_room_state()


func _on_character_spawn_requested(char_data: Dictionary) -> void:
	var center_x: float = main_camera.position.x if main_camera != null else room_bounds.get_center().x
	var spawn_pos: Vector2 = Vector2(center_x, current_room_floor_y - 80.0)
	RoomManager.reconstruct_traveler_bundle([char_data], spawn_pos, world_canvas, all_entities)
	_trigger_haptic(35)
	_record_history()
	SaveSystem.save_current_room_state()


func _on_template_spawn_requested(template_data: Dictionary) -> void:
	var center_x: float = main_camera.position.x if main_camera != null else room_bounds.get_center().x
	var spawn_x: float = clampf(center_x + randf_range(-40.0, 40.0), 100.0, room_bounds.end.x - 100.0)
	var spawn_y: float = current_room_floor_y - 80.0
	RoomManager.reconstruct_traveler_bundle([template_data], Vector2(spawn_x, spawn_y), world_canvas, all_entities)
	_trigger_haptic(30)
	_record_history()
	SaveSystem.save_current_room_state()


func _on_entity_spawn_requested(request: Dictionary) -> void:
	var item_name: String = str(request.get("item_name", "Spawned Item"))
	var tex: Texture2D = request.get("texture", null) as Texture2D
	var fpath: String = str(request.get("file_path", ""))
	var pos_dict: Dictionary = request.get("position", {})
	var spawn_pos: Vector2 = Vector2(float(pos_dict.get("x", 640.0)), float(pos_dict.get("y", current_room_floor_y)))

	var uid: String = AppState.generate_entity_uuid(item_name)
	var entity: OwnEntity = OwnEntity.new()
	entity.setup(uid, item_name, tex, spawn_pos, Types.EntityType.PROP, fpath)

	world_canvas.add_child(entity)
	all_entities.append(entity)
	entity.trigger_spawn_juice()
	_record_history()
	SaveSystem.save_current_room_state()


func _on_magic_wheel_action(action_name: String, target: OwnEntity) -> void:
	if not is_instance_valid(target): return

	match action_name:
		"flip":
			target.flip_horizontal()
			_record_history()
			SaveSystem.save_current_room_state()
		"character_studio", "wardrobe", "frames", "states":
			if pose_anim_studio_ui != null: pose_anim_studio_ui.open_for_entity(target)
		"anchors":
			if snap_studio_ui != null: snap_studio_ui.open_for_entity(target)
		"lighting":
			if light_studio_ui != null: light_studio_ui.open_for_entity(target)
		"food_studio":
			if food_studio_ui != null: food_studio_ui.open_for_entity(target)
		"lore", "profile":
			if lore_card_ui != null and lore_card_ui.has_method("open_card"): lore_card_ui.call("open_card", target)
		"config":
			if entity_config_dialog != null: entity_config_dialog.open_for_entity(target)
		"logic":
			if logic_rule_dialog != null: logic_rule_dialog.open_for_entity(target)
		"edit_door":
			if door_editor_dialog != null: door_editor_dialog.open_for_door(target)
		"climb_stairs":
			if interaction_router: interaction_router._handle_stairs_tap(target, all_entities)
		"elevator":
			if elevator_dialog: elevator_dialog.open_keypad(target)
		"save_template":
			if drawer_tray_ui != null: drawer_tray_ui.store_entity_as_template(target)
		"lock":
			target.is_locked = not target.is_locked
			_record_history()
			SaveSystem.save_current_room_state()
			_trigger_haptic(40)
			EventBus.notification_requested.emit("Locked" if target.is_locked else "Unlocked", true)
		"clone":
			var uid: String = AppState.generate_entity_uuid(target.display_name)
			var clone_entity: OwnEntity = OwnEntity.new()
			clone_entity.setup(uid, target.display_name, target.main_texture, target.global_position + Vector2(40.0, 40.0), target.entity_type, target.texture_path)
			clone_entity.from_dict(target.to_dict())
			world_canvas.add_child(clone_entity)
			all_entities.append(clone_entity)
			clone_entity.trigger_spawn_juice()
			_trigger_haptic(35)
			_record_history()
			SaveSystem.save_current_room_state()
		"store":
			_remove_hierarchy(target)
			if drawer_tray_ui != null: drawer_tray_ui.store_character_in_tray(target)
			_trigger_haptic(45)
			_record_history()
			SaveSystem.save_current_room_state()
		"delete":
			_remove_hierarchy(target)
			target.queue_free()
			_trigger_haptic(50)
			_record_history()
			SaveSystem.save_current_room_state()


func _on_undo_requested() -> void:
	var history: Node = get_node_or_null("/root/HistoryManager")
	if history != null and history.has_method("undo"):
		history.call("undo")


func _on_top_nav_floor_switcher_requested() -> void:
	var floors: Array[Dictionary] = SaveSystem.get_building_floors(current_building_id)

	if floors.size() <= 1:
		_trigger_haptic(30)
		EventBus.notification_requested.emit("There are no other floors in this building.", true)
		return

	var popup: PopupMenu = PopupMenu.new()
	popup.theme = ThemeService.create_theme()
	add_child(popup)

	for i: int in range(floors.size()):
		var fl: Dictionary = floors[i]
		var r_id: String = str(fl.get("room_id", ""))
		var fl_label: String = str(fl.get("label", r_id))
		var is_current: bool = (r_id == AppState.room_id)
		popup.add_item(fl_label + (" (Current)" if is_current else ""), i)
		popup.set_item_disabled(i, is_current)

	popup.id_pressed.connect(func(id: int) -> void:
		if id >= 0 and id < floors.size():
			var target_fl: Dictionary = floors[id]
			var target_room_id: String = str(target_fl.get("room_id", ""))
			var target_label: String = str(target_fl.get("label", target_room_id))
			popup.queue_free()
			_transition_to_room(target_room_id, {
				"source": "nav_bar_switcher",
				"floor_name": target_label,
				"building_id": current_building_id,
				"building_name": current_building_name
			})
	)

	popup.popup_hide.connect(popup.queue_free)
	var btn_rect: Rect2 = top_nav_bar.btn_floors.get_global_rect() if top_nav_bar.btn_floors else Rect2(Vector2(640, 50), Vector2.ZERO)
	popup.position = Vector2i(int(btn_rect.position.x - 20.0), int(btn_rect.end.y + 6.0))
	popup.popup()


func _on_elevator_floor_travel_requested(elevator: OwnEntity, target_room_id: String, floor_name: String) -> void:
	if not is_instance_valid(elevator): return
	var passengers: Array[OwnEntity] = elevator.get_passengers_in_cab(all_entities)
	var bundle: Array[Dictionary] = []
	for p: OwnEntity in passengers:
		if is_instance_valid(p):
			bundle.append_array(p.get_full_hierarchy_bundle())
			_remove_hierarchy(p)
			p.queue_free()

	SaveSystem.save_current_room_state()
	elevator.close_door_animated(func() -> void:
		AudioManager.play_snap_chime()
		EventBus.notification_requested.emit("Floor Arrival: " + floor_name, true)
		_transition_to_room(target_room_id, {
			"bundle": bundle,
			"arrival_elevator": true,
			"floor_name": floor_name,
			"building_id": current_building_id,
			"building_name": current_building_name,
			"source": "elevator"
		})
	)


func _remove_hierarchy(root_ent: OwnEntity) -> void:
	all_entities.erase(root_ent)
	for child: OwnEntity in root_ent.attached_children:
		if is_instance_valid(child): _remove_hierarchy(child)


func _on_item_unpacked_from_container(item_data: Dictionary, container_ent: OwnEntity) -> void:
	var spawn_pos: Vector2 = container_ent.global_position + Vector2(randf_range(-40.0, 40.0), 20.0)
	RoomManager.reconstruct_traveler_bundle([item_data], spawn_pos, world_canvas, all_entities)
	_trigger_haptic(30)
	_record_history()
	SaveSystem.save_current_room_state()
	EventBus.notification_requested.emit("Unpacked: " + str(item_data.get("display_name", "Item")), true)


func _trigger_haptic(duration_ms: int = 30) -> void:
	if SettingsManager.are_haptics_enabled() and (OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")):
		if Input.has_method("vibrate_handheld"):
			Input.vibrate_handheld(duration_ms)
