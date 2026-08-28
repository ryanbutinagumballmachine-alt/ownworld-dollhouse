# ==============================================================================
# OWNWORLD — MAIN APPLICATION ORCHESTRATOR (CROSS-PLATFORM GESTURE & LIFECYCLE)
# File: res://Core/Main.gd
# Base Class: Node2D
#
# Responsibility: Master runtime scene orchestrator. Coordinates multi-slice
# room rendering, touch/mouse gesture isolation, live physics solver ticks,
# smooth room transitions, safe area layout insets, and OS back gestures.
# ==============================================================================

extends Node2D

const BASE_ROOM_SIZE: Vector2 = Vector2(1280.0, 720.0)

var TAP_PIXEL_THRESHOLD: float = 24.0 if (OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")) else 12.0

var room_slices: Array[Dictionary] = [{
	"wallpaper_path": "", "fill_mode": "cover", "is_outdoor": false,
	"wall_color": "", "floor_color": "", "baseboard_color": ""
}]
var room_bounds: Rect2 = Rect2(Vector2.ZERO, BASE_ROOM_SIZE)
var current_building_id: String = "building_main"
var current_building_name: String = "Main Building"
var current_room_floor_level: String = "1F"
var current_room_title: String = "Main Room"
var current_room_floor_y: float = 580.0

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

var all_entities: Array[OwnEntity] = []
var pressed_target_entity: OwnEntity = null
var active_dragged_entity: OwnEntity = null

var drag_offset: Vector2 = Vector2.ZERO
var press_start_world_pos: Vector2 = Vector2.ZERO
var press_start_screen_pos: Vector2 = Vector2.ZERO
var current_pointer_screen_pos: Vector2 = Vector2.ZERO
var current_pointer_world_pos: Vector2 = Vector2.ZERO

var press_start_time: float = 0.0
var is_pointer_down: bool = false
var long_press_triggered: bool = false
var has_drag_moved_past_threshold: bool = false
var is_room_loaded: bool = false

var _active_touches: Dictionary = {}
var _ui_touch_indices: Dictionary = {}
var active_touch_index: int = -1


func _ready() -> void:
	set_process(false)
	get_tree().quit_on_go_back = false

	if OS.has_feature("android") or OS.has_feature("mobile"):
		OS.request_permissions()

	_ensure_ugc_directories()
	_enforce_cross_platform_viewport()
	_mount_subsystems()
	_connect_system_signals()

	RecipeCrafting.load_recipes_for_universe(_get_current_universe_id())
	_load_active_room(_get_current_room_id())

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
	if win == null:
		return
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
		_save_session_from_main_state()
		if drawer_tray_ui != null: drawer_tray_ui.save_cast_tray_for_current_universe()
		if world_map_screen != null: world_map_screen.save_map_for_current_universe()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_active_drag()
		_active_touches.clear()
		_ui_touch_indices.clear()
		active_touch_index = -1
		if main_camera != null and is_instance_valid(main_camera):
			main_camera.reset_touch_state()
		if is_room_loaded:
			SaveSystem.save_current_room_state()
		_save_session_from_main_state()


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

	# Dedicated Cross-Fade Overlay
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

			# 1. Upper Wall
			var wall_rect: ColorRect = ColorRect.new()
			wall_rect.name = "Wall"
			wall_rect.color = slice_wall_color
			wall_rect.position = Vector2.ZERO
			wall_rect.size = Vector2(slice_w, current_room_floor_y)
			wall_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slice_node.add_child(wall_rect)

			# 2. Baseboard Trim
			var baseboard_rect: ColorRect = ColorRect.new()
			baseboard_rect.name = "Baseboard"
			baseboard_rect.color = slice_trim_color
			baseboard_rect.position = Vector2(0.0, current_room_floor_y - baseboard_h)
			baseboard_rect.size = Vector2(slice_w, baseboard_h)
			baseboard_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slice_node.add_child(baseboard_rect)

			# 3. Lower Floor
			var floor_rect: ColorRect = ColorRect.new()
			floor_rect.name = "Floor"
			floor_rect.color = slice_floor_color
			floor_rect.position = Vector2(0.0, current_room_floor_y)
			floor_rect.size = Vector2(slice_w, maxf(0.0, slice_h - current_room_floor_y))
			floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slice_node.add_child(floor_rect)

		# 4. Vertical Divider Seam
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


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	if main_camera != null and is_instance_valid(main_camera):
		var viewport_size: Vector2 = get_viewport_rect().size
		var cam_zoom: float = maxf(main_camera.zoom.x, 0.001)
		return main_camera.position + (screen_pos - (viewport_size * 0.5)) / cam_zoom
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func _is_any_modal_open() -> bool:
	for ui: Node in get_tree().get_nodes_in_group("modal_ui"):
		if not is_instance_valid(ui): continue
		if ui is CanvasLayer and (ui as CanvasLayer).visible: return true
		elif ui is Control and (ui as Control).visible: return true
		elif ui is Window and (ui as Window).visible: return true
	return false


# --- INPUT HANDLING WITH TOUCH/MOUSE ISOLATION ---

func _input(event: InputEvent) -> void:
	if is_transitioning_room:
		return

	if event is InputEventScreenTouch:
		var screen_touch: InputEventScreenTouch = event as InputEventScreenTouch
		var touch_idx: int = screen_touch.index
		var touch_screen_pos: Vector2 = screen_touch.position
		var touch_world_pos: Vector2 = _screen_to_world(touch_screen_pos)

		current_pointer_screen_pos = touch_screen_pos
		current_pointer_world_pos = touch_world_pos

		if screen_touch.pressed:
			_active_touches[touch_idx] = touch_screen_pos
			var is_ui_touch: bool = _is_any_modal_open()
			if not is_ui_touch:
				if drawer_tray_ui != null and drawer_tray_ui.is_point_inside_drawer(touch_screen_pos):
					is_ui_touch = true
				elif top_nav_bar != null and top_nav_bar.is_point_inside_nav(touch_screen_pos):
					is_ui_touch = true

			if is_ui_touch:
				_ui_touch_indices[touch_idx] = true
				if _active_touches.size() >= 2: _cancel_active_drag()
			else:
				_ui_touch_indices.erase(touch_idx)
				if _active_touches.size() == 1:
					active_touch_index = touch_idx
					_handle_press_begin(touch_world_pos, touch_screen_pos)
				elif _active_touches.size() >= 2:
					_cancel_active_drag()

		else:
			_active_touches.erase(touch_idx)
			var was_ui_touch: bool = _ui_touch_indices.has(touch_idx)
			_ui_touch_indices.erase(touch_idx)

			if not was_ui_touch:
				if touch_idx == active_touch_index or _active_touches.is_empty():
					_handle_press_end(touch_world_pos)
					active_touch_index = -1

		if main_camera != null and is_instance_valid(main_camera):
			main_camera.handle_external_touch(screen_touch)

	elif event is InputEventScreenDrag:
		var screen_drag: InputEventScreenDrag = event as InputEventScreenDrag
		var touch_idx: int = screen_drag.index
		_active_touches[touch_idx] = screen_drag.position

		if not _ui_touch_indices.has(touch_idx) and _active_touches.size() == 1 and touch_idx == active_touch_index:
			current_pointer_screen_pos = screen_drag.position
			current_pointer_world_pos = _screen_to_world(screen_drag.position)

			if press_start_screen_pos.distance_to(current_pointer_screen_pos) > TAP_PIXEL_THRESHOLD:
				has_drag_moved_past_threshold = true

			if active_dragged_entity != null:
				_update_active_drag_position(current_pointer_world_pos)
			elif main_camera != null and main_camera.is_panning:
				main_camera.update_drag_pan(screen_drag.position)

		if main_camera != null and is_instance_valid(main_camera) and _active_touches.size() >= 2:
			main_camera.handle_external_drag(screen_drag)

	elif event is InputEventMouseButton:
		if not _active_touches.is_empty():
			return

		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		var mouse_screen_pos: Vector2 = mouse_button.position
		var mouse_world_pos: Vector2 = _screen_to_world(mouse_screen_pos)

		current_pointer_screen_pos = mouse_screen_pos
		current_pointer_world_pos = mouse_world_pos

		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				var is_ui: bool = _is_any_modal_open()
				if not is_ui:
					if drawer_tray_ui != null and drawer_tray_ui.is_point_inside_drawer(mouse_screen_pos): is_ui = true
					elif top_nav_bar != null and top_nav_bar.is_point_inside_nav(mouse_screen_pos): is_ui = true

				if not is_ui and not is_pointer_down:
					_handle_press_begin(mouse_world_pos, mouse_screen_pos)
			else:
				if is_pointer_down:
					_handle_press_end(mouse_world_pos)

		elif mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			if not _is_any_modal_open():
				var clicked: OwnEntity = _get_topmost_at(mouse_world_pos)
				if clicked != null:
					_trigger_haptic(40)
					if magic_wheel_ui != null:
						magic_wheel_ui.open_wheel_for_entity(clicked, mouse_screen_pos)

		elif mouse_button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_MIDDLE]:
			if main_camera != null and is_instance_valid(main_camera):
				main_camera.handle_unhandled_mouse(mouse_button)

	elif event is InputEventMouseMotion:
		if not _active_touches.is_empty():
			return

		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		current_pointer_screen_pos = mouse_motion.position
		current_pointer_world_pos = _screen_to_world(mouse_motion.position)

		if press_start_screen_pos.distance_to(current_pointer_screen_pos) > TAP_PIXEL_THRESHOLD:
			has_drag_moved_past_threshold = true

		if active_dragged_entity != null:
			_update_active_drag_position(current_pointer_world_pos)
		elif is_pointer_down and pressed_target_entity == null and main_camera != null and main_camera.is_panning:
			main_camera.update_drag_pan(mouse_motion.position)

	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z and event.ctrl_pressed:
			_on_undo_requested()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if not _is_any_modal_open() and main_menu_ui != null and not main_menu_ui.visible:
				main_menu_ui.open_menu()
				get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if is_pointer_down and not long_press_triggered and pressed_target_entity != null and is_instance_valid(pressed_target_entity):
		var elapsed: float = (Time.get_ticks_msec() / 1000.0) - press_start_time
		var drag_dist: float = press_start_screen_pos.distance_to(current_pointer_screen_pos)
		var long_press_threshold: float = SettingsManager.get_long_press_duration()

		if not has_drag_moved_past_threshold and elapsed >= long_press_threshold and drag_dist <= TAP_PIXEL_THRESHOLD:
			long_press_triggered = true
			var target_to_open: OwnEntity = pressed_target_entity
			_trigger_haptic(60)
			if magic_wheel_ui != null:
				magic_wheel_ui.open_wheel_for_entity(target_to_open, current_pointer_screen_pos)
			_cancel_active_drag()
			return

	if active_dragged_entity != null and is_instance_valid(active_dragged_entity):
		InteractionSolver.process_live_interactions(delta, active_dragged_entity, all_entities)


func _update_active_drag_position(world_pointer_pos: Vector2) -> void:
	if active_dragged_entity == null or not is_instance_valid(active_dragged_entity):
		return

	var target_pos: Vector2 = world_pointer_pos + drag_offset
	if SettingsManager.is_grid_snap_enabled():
		var grid_size: float = float(SettingsManager.get_grid_size())
		target_pos = target_pos.snapped(Vector2(grid_size, grid_size))

	var half_width: float = active_dragged_entity.get_visual_half_width()
	var bottom_offset: float = active_dragged_entity.get_visual_bottom_offset()
	var top_offset: float = active_dragged_entity.texture_size.y * 0.5 * active_dragged_entity.entity_scale

	target_pos.x = clampf(target_pos.x, room_bounds.position.x + half_width, room_bounds.end.x - half_width)

	if active_dragged_entity.is_wall_mounted:
		var max_wall_y: float = current_room_floor_y - bottom_offset - 4.0
		target_pos.y = clampf(target_pos.y, room_bounds.position.y + top_offset, maxf(room_bounds.position.y + top_offset, max_wall_y))
	else:
		target_pos.y = clampf(target_pos.y, room_bounds.position.y + top_offset, room_bounds.end.y - bottom_offset)

	active_dragged_entity.global_position = target_pos


func _update_active_process_state() -> void:
	set_process(is_pointer_down or active_dragged_entity != null)


func _handle_press_begin(world_pos: Vector2, screen_pos: Vector2) -> void:
	if is_pointer_down: return

	is_pointer_down = true
	long_press_triggered = false
	has_drag_moved_past_threshold = false
	press_start_world_pos = world_pos
	press_start_screen_pos = screen_pos
	current_pointer_screen_pos = screen_pos
	current_pointer_world_pos = world_pos
	press_start_time = Time.get_ticks_msec() / 1000.0

	var touch_padding: float = SettingsManager.get_touch_padding(not _active_touches.is_empty())
	var topmost: OwnEntity = _get_topmost_at(world_pos, touch_padding)
	pressed_target_entity = topmost

	if topmost != null and not topmost.is_locked:
		if topmost.parent_socket_entity != null:
			topmost.detach_from_socket(world_canvas)

		var root_ent: OwnEntity = _get_ysort_root_entity(topmost)
		if root_ent.get_parent() == world_canvas:
			world_canvas.move_child(root_ent, -1)

		active_dragged_entity = topmost
		drag_offset = active_dragged_entity.global_position - world_pos
		active_dragged_entity.on_grab()
		_trigger_haptic(25)
		LogicEngine.evaluate_trigger(Types.TriggerEvent.ON_DRAG_STARTED, active_dragged_entity)
		AudioManager.play_pop_grab()

	elif topmost == null and main_camera != null:
		main_camera.start_drag_pan(screen_pos)

	_update_active_process_state()


func _handle_press_end(_world_pos: Vector2) -> void:
	if not is_pointer_down: return

	is_pointer_down = false
	if main_camera != null:
		main_camera.end_drag_pan()

	var released_target: OwnEntity = pressed_target_entity
	pressed_target_entity = null

	if long_press_triggered:
		_update_active_process_state()
		return

	var elapsed_time: float = (Time.get_ticks_msec() / 1000.0) - press_start_time
	var drag_dist: float = press_start_screen_pos.distance_to(current_pointer_screen_pos)
	var hold_duration: float = SettingsManager.get_long_press_duration()
	var is_quick_tap: bool = (drag_dist <= TAP_PIXEL_THRESHOLD) and (elapsed_time < hold_duration)

	if active_dragged_entity == null:
		if released_target != null and is_instance_valid(released_target) and is_quick_tap:
			_handle_layer1_tap(released_target)
		_update_active_process_state()
		return

	if is_instance_valid(active_dragged_entity):
		var released: OwnEntity = active_dragged_entity
		active_dragged_entity = null
		released.on_drop()
		LogicEngine.evaluate_trigger(Types.TriggerEvent.ON_DRAG_ENDED, released)
		AudioManager.play_drop_cushion()

		if is_quick_tap:
			_handle_layer1_tap(released)
		else:
			# Portal / Stairs / Elevator Routing
			if released.entity_type == Types.EntityType.CHARACTER:
				for portal_ent: OwnEntity in all_entities:
					if not is_instance_valid(portal_ent): continue
					if portal_ent != released and portal_ent.is_portal and portal_ent.contains_point(released.global_position):
						if portal_ent.is_stairs:
							_handle_stairs_travel(portal_ent, released)
							_update_active_process_state()
							return
						elif portal_ent.is_elevator:
							_handle_elevator_interaction(portal_ent, released)
							_update_active_process_state()
							return
						else:
							var target_room: String = portal_ent.target_room_id
							if not target_room.is_empty() and target_room != _get_current_room_id():
								var bundle: Array[Dictionary] = released.get_full_hierarchy_bundle()
								_remove_hierarchy(released)
								released.queue_free()
								SaveSystem.save_current_room_state()
								_transition_to_room(target_room, {"bundle": bundle, "source": "portal"})
								_update_active_process_state()
								return

			if released.entity_type == Types.EntityType.PROP:
				for container_ent: OwnEntity in all_entities:
					if not is_instance_valid(container_ent): continue
					if container_ent != released and container_ent.is_container and container_ent.contains_point(released.global_position):
						all_entities.erase(released)
						container_ent.pack_item_inside(released)
						_trigger_haptic(45)
						_record_history()
						SaveSystem.save_current_room_state()
						EventBus.notification_requested.emit("Packed into: " + container_ent.display_name, true)
						_update_active_process_state()
						return

			if InteractionSolver.check_and_execute_crafting(released, all_entities, world_canvas):
				_trigger_haptic(50)
				_record_history()
				SaveSystem.save_current_room_state()
				_update_active_process_state()
				return

			var is_snapped: bool = SocketManager.evaluate_and_snap(released, all_entities)
			if is_snapped and released.parent_socket_entity != null:
				_trigger_haptic(35)
				LogicEngine.evaluate_trigger(Types.TriggerEvent.ON_ITEM_RECEIVED, released.parent_socket_entity, {"item": released})
			else:
				_apply_physical_gravity_settle(released)

			_record_history()
			SaveSystem.save_current_room_state()

	_update_active_process_state()


func _cancel_active_drag() -> void:
	if active_dragged_entity != null and is_instance_valid(active_dragged_entity):
		active_dragged_entity.on_drop()
		active_dragged_entity = null
	if main_camera != null and is_instance_valid(main_camera):
		main_camera.end_drag_pan()
	pressed_target_entity = null
	is_pointer_down = false
	has_drag_moved_past_threshold = false
	_update_active_process_state()


func _handle_layer1_tap(entity: OwnEntity) -> void:
	if not is_instance_valid(entity):
		return

	_trigger_haptic(20)
	LogicEngine.evaluate_trigger(Types.TriggerEvent.ON_TAPPED, entity)

	if entity.is_stairs:
		_handle_stairs_tap(entity)
	elif entity.is_elevator:
		_handle_elevator_tap(entity)
	elif entity.is_container:
		entity.toggle_container()
	elif entity.has_method("toggle_active_state"):
		entity.toggle_active_state()

	_record_history()
	SaveSystem.save_current_room_state()


# --- STAIRS ROUTING LOGIC ---

func _handle_stairs_travel(_stairs: OwnEntity, traveler: OwnEntity) -> void:
	var current_room: String = _get_current_room_id()
	var bldg_floors: Array[Dictionary] = SaveSystem.get_building_floors(current_building_id)

	if bldg_floors.size() <= 1:
		_trigger_haptic(40)
		EventBus.notification_requested.emit("There are no other floors in this building.", true)
		_apply_physical_gravity_settle(traveler)
		return

	var next_floor: Dictionary = SaveSystem.get_next_floor_above(current_building_id, current_room)
	if next_floor.is_empty():
		_trigger_haptic(40)
		EventBus.notification_requested.emit("There are no other floors above in this building.", true)
		_apply_physical_gravity_settle(traveler)
		return

	var target_room_id: String = str(next_floor.get("room_id", "")).strip_edges()
	var target_floor_label: String = str(next_floor.get("label", next_floor.get("floor_level", "Floor Above")))

	var bundle: Array[Dictionary] = traveler.get_full_hierarchy_bundle()
	_remove_hierarchy(traveler)
	traveler.queue_free()

	for item: Dictionary in bundle:
		var c_id: String = str(item.get("id", ""))
		var c_name: String = str(item.get("display_name", ""))
		if not c_id.is_empty():
			DrawerMetadataService.scrub_character_from_universe_rooms(c_id, c_name)

	AudioManager.play_snap_chime()
	EventBus.notification_requested.emit("Climbing to: " + target_floor_label, true)
	_transition_to_room(target_room_id, {
		"bundle": bundle,
		"arrival_stairs": true,
		"floor_name": target_floor_label,
		"building_id": current_building_id,
		"building_name": current_building_name,
		"source": "stairs"
	})


func _handle_stairs_tap(stairs: OwnEntity) -> void:
	var current_room: String = _get_current_room_id()
	var bldg_floors: Array[Dictionary] = SaveSystem.get_building_floors(current_building_id)

	if bldg_floors.size() <= 1:
		_trigger_haptic(40)
		EventBus.notification_requested.emit("There are no other floors in this building.", true)
		return

	var next_floor: Dictionary = SaveSystem.get_next_floor_above(current_building_id, current_room)
	if next_floor.is_empty():
		_trigger_haptic(40)
		EventBus.notification_requested.emit("There are no other floors above in this building.", true)
		return

	var target_room_id: String = str(next_floor.get("room_id", "")).strip_edges()
	var target_floor_label: String = str(next_floor.get("label", next_floor.get("floor_level", "Floor Above")))

	var passengers: Array[OwnEntity] = stairs.get_passengers_in_cab(all_entities)
	var bundle: Array[Dictionary] = []
	for p: OwnEntity in passengers:
		if is_instance_valid(p):
			bundle.append_array(p.get_full_hierarchy_bundle())
			_remove_hierarchy(p)
			p.queue_free()

	AudioManager.play_snap_chime()
	EventBus.notification_requested.emit("Climbing to: " + target_floor_label, true)
	_transition_to_room(target_room_id, {
		"bundle": bundle,
		"arrival_stairs": true,
		"floor_name": target_floor_label,
		"building_id": current_building_id,
		"building_name": current_building_name,
		"source": "stairs"
	})


# --- ELEVATOR ROUTING LOGIC ---

func _handle_elevator_tap(elevator: OwnEntity) -> void:
	var bldg_floors: Array[Dictionary] = SaveSystem.get_building_floors(current_building_id)
	if bldg_floors.size() <= 1:
		_trigger_haptic(40)
		EventBus.notification_requested.emit("There are no other floors in this building.", true)
		return
	elevator_dialog.open_keypad(elevator)


func _handle_elevator_interaction(elevator: OwnEntity, traveler: OwnEntity) -> void:
	var bldg_floors: Array[Dictionary] = SaveSystem.get_building_floors(current_building_id)
	if bldg_floors.size() <= 1:
		_trigger_haptic(40)
		EventBus.notification_requested.emit("There are no other floors in this building.", true)
		_apply_physical_gravity_settle(traveler)
		return
	elevator_dialog.open_keypad(elevator)
	_apply_physical_gravity_settle(traveler)


func _trigger_haptic(duration_ms: int = 30) -> void:
	if SettingsManager.are_haptics_enabled() and (OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")):
		if Input.has_method("vibrate_handheld"):
			Input.vibrate_handheld(duration_ms)


func _on_elevator_floor_travel_requested(elevator: OwnEntity, target_room_id: String, floor_name: String) -> void:
	if not is_instance_valid(elevator): return

	var passengers: Array[OwnEntity] = elevator.get_passengers_in_cab(all_entities)
	var bundle: Array[Dictionary] = []
	for passenger: OwnEntity in passengers:
		if is_instance_valid(passenger):
			bundle.append_array(passenger.get_full_hierarchy_bundle())
			_remove_hierarchy(passenger)
			passenger.queue_free()

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


func _on_item_unpacked_from_container(item_data: Dictionary, container_ent: OwnEntity) -> void:
	var spawn_pos: Vector2 = container_ent.global_position + Vector2(randf_range(-40.0, 40.0), 20.0)
	RoomManager.reconstruct_traveler_bundle([item_data], spawn_pos, world_canvas, all_entities)
	_trigger_haptic(30)
	_record_history()
	SaveSystem.save_current_room_state()
	EventBus.notification_requested.emit("Unpacked: " + str(item_data.get("display_name", "Item")), true)


func _apply_physical_gravity_settle(entity: OwnEntity) -> void:
	if entity.is_wall_mounted or entity.can_float or entity.is_floor_decor or entity.parent_socket_entity != null:
		return

	var bottom_offset: float = entity.get_visual_bottom_offset()
	var floor_baseline: float = current_room_floor_y - bottom_offset
	if entity.global_position.y < floor_baseline - 15.0:
		var drop_dist: float = floor_baseline - entity.global_position.y
		var fall_duration: float = clampf(drop_dist * 0.0008, 0.2, 0.4)

		if SettingsManager.is_juice_squash_stretch_enabled():
			var tween: Tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tween.tween_property(entity, "global_position:y", floor_baseline, fall_duration)
		else:
			entity.global_position.y = floor_baseline


func _remove_hierarchy(root_ent: OwnEntity) -> void:
	all_entities.erase(root_ent)
	for child: OwnEntity in root_ent.attached_children:
		if is_instance_valid(child): _remove_hierarchy(child)


func _get_topmost_at(world_pos: Vector2, touch_padding: float = 0.0) -> OwnEntity:
	var exact_hits: Array[OwnEntity] = []
	var padded_hits: Array[OwnEntity] = []

	for entity: OwnEntity in all_entities:
		if is_instance_valid(entity) and entity.is_visible_in_tree():
			if entity.has_point_exact(world_pos):
				exact_hits.append(entity)
			elif entity.contains_point(world_pos, touch_padding):
				padded_hits.append(entity)

	var candidates: Array[OwnEntity] = exact_hits if not exact_hits.is_empty() else padded_hits

	var best: OwnEntity = null
	for entity: OwnEntity in candidates:
		if best == null or _is_entity_in_front_of(entity, best):
			best = entity
	return best


func _is_entity_in_front_of(a: OwnEntity, b: OwnEntity) -> bool:
	if a == b: return false
	if not is_instance_valid(a): return false
	if not is_instance_valid(b): return true

	if a.parent_socket_entity == b:
		return a.z_index >= 0
	if b.parent_socket_entity == a:
		return b.z_index < 0

	var z_a: int = _calculate_effective_z(a)
	var z_b: int = _calculate_effective_z(b)
	if z_a != z_b:
		return z_a > z_b

	var root_a: OwnEntity = _get_ysort_root_entity(a)
	var root_b: OwnEntity = _get_ysort_root_entity(b)

	if root_a != root_b:
		var y_a: float = root_a.global_position.y
		var y_b: float = root_b.global_position.y
		if not is_equal_approx(y_a, y_b) and absf(y_a - y_b) > 0.5:
			return y_a > y_b
		return root_a.get_index() > root_b.get_index()

	return a.get_index() > b.get_index()


func _get_ysort_root_entity(entity: OwnEntity) -> OwnEntity:
	var current: OwnEntity = entity
	while current.parent_socket_entity != null and is_instance_valid(current.parent_socket_entity):
		current = current.parent_socket_entity
	return current


func _calculate_effective_z(entity: OwnEntity) -> int:
	if not is_instance_valid(entity): return 0
	if entity.z_as_relative and entity.get_parent() is Node2D:
		var parent_node: Node2D = entity.get_parent() as Node2D
		if parent_node is OwnEntity:
			return _calculate_effective_z(parent_node as OwnEntity) + entity.z_index
		return parent_node.z_index + entity.z_index
	return entity.z_index


func _load_session() -> Dictionary:
	return JsonFileStore.read_dictionary("user://session.json")


func _get_current_universe_id() -> String: return SaveSystem.get_current_universe_id()
func _get_current_room_id() -> String: return SaveSystem.get_current_room_id()


func _save_session_from_main_state() -> void:
	var session: Dictionary = _load_session()
	session["room_id"] = _get_current_room_id()
	JsonFileStore.write_dictionary("user://session.json", session)


func _on_atmosphere_changed(time_preset: String, weather_preset: String) -> void:
	if atmosphere != null:
		atmosphere.set_preset(time_preset)
		atmosphere.set_weather(weather_preset)


# --- TRANSITIONS ---

func _transition_to_room(target_room_id: String, traveler_data: Dictionary = {}) -> void:
	var current_room_id_str: String = _get_current_room_id()
	if target_room_id.is_empty() or is_transitioning_room:
		return
	if target_room_id == current_room_id_str and traveler_data.is_empty():
		return

	is_transitioning_room = true
	SaveSystem.save_current_room_state()

	# 1. Smooth Fade-Out
	if transition_rect != null:
		transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		var tw_out: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw_out.tween_property(transition_rect, "color:a", 1.0, 0.18)
		await tw_out.finished

	# 2. Write session & stream target room
	var session: Dictionary = _load_session()
	session["room_id"] = target_room_id
	JsonFileStore.write_dictionary("user://session.json", session)

	_load_active_room(target_room_id, traveler_data)

	# 3. Smooth Fade-In
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


func _switch_universe(new_u_id: String, new_u_name: String, starting_room: String = "room_main") -> void:
	if new_u_id.is_empty(): return
	var session: Dictionary = _load_session()
	session["universe_id"] = new_u_id
	session["universe_name"] = new_u_name
	session["room_id"] = starting_room
	JsonFileStore.write_dictionary("user://session.json", session)

	if EventBus.has_signal("universe_changed"):
		EventBus.universe_changed.emit(new_u_id, new_u_name)


func _clear_current_universe_rooms() -> void:
	RoomRepository.clear_universe(SaveSystem.get_current_universe_id())


func _generate_entity_uuid(base_name: String) -> String:
	return AppState.generate_entity_uuid(base_name)


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
			_get_current_room_id()
		)


func _on_floor_preview_changed(preview_y: float, preview_visible: bool) -> void:
	current_room_floor_y = preview_y
	_apply_room_slices(room_slices)
	_update_floor_guide_visuals(preview_y, preview_visible)


func _on_room_configured(slices_data: Array[Dictionary], floor_y: float, room_name: String, floor_level: String, bldg_name: String = "", bldg_id: String = "") -> void:
	current_room_floor_y = floor_y
	current_room_title = room_name if not room_name.is_empty() else _get_current_room_id()
	current_room_floor_level = floor_level if not floor_level.is_empty() else "1F"
	if not bldg_name.is_empty(): current_building_name = bldg_name
	if not bldg_id.is_empty(): current_building_id = bldg_id

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
		var session: Dictionary = _load_session()
		atmosphere.set_preset(str(session.get("time_preset", "day")))
		atmosphere.set_weather(str(session.get("weather_preset", "none")))

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
	_switch_universe(new_u_id, new_u_name, "room_main")
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

	_clear_current_universe_rooms()
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
		_get_current_room_id(),
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
	if snapshot.has("floor_y"): current_room_floor_y = float(snapshot["floor_y"])
	if snapshot.has("room_title"): current_room_title = str(snapshot["room_title"])
	if snapshot.has("floor_level"): current_room_floor_level = str(snapshot["floor_level"])
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
	var uid: String = _generate_entity_uuid(item_name)
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

	var uid: String = _generate_entity_uuid(item_name)
	var entity: OwnEntity = OwnEntity.new()
	entity.setup(uid, item_name, tex, spawn_pos, Types.EntityType.PROP, fpath)

	world_canvas.add_child(entity)
	all_entities.append(entity)
	entity.trigger_spawn_juice()
	_record_history()
	SaveSystem.save_current_room_state()


func _on_magic_wheel_action(action_name: String, target: OwnEntity) -> void:
	if not is_instance_valid(target):
		return

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
			_handle_stairs_tap(target)
		"elevator":
			_handle_elevator_tap(target)
		"save_template":
			if drawer_tray_ui != null: drawer_tray_ui.store_entity_as_template(target)
		"lock":
			target.is_locked = not target.is_locked
			_record_history()
			SaveSystem.save_current_room_state()
			_trigger_haptic(40)
			EventBus.notification_requested.emit("Locked" if target.is_locked else "Unlocked", true)
		"clone":
			var uid: String = _generate_entity_uuid(target.display_name)
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
		var is_current: bool = (r_id == _get_current_room_id())
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
