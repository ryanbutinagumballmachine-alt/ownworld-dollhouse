# ==============================================================================
# OWNWORLD — MAIN APPLICATION ORCHESTRATOR
# File: res://Core/Main.gd
# Base Class: Node2D
# ==============================================================================

extends Node2D

const ROOM_WIDTH: float = 1920.0
const ROOM_HEIGHT: float = 1080.0

var TAP_PIXEL_THRESHOLD: float = 24.0 if OS.has_feature("mobile") else 14.0

var room_bounds: Rect2 = Rect2(0.0, 0.0, ROOM_WIDTH, ROOM_HEIGHT)
var current_room_floor_y: float = 600.0
var current_room_title: String = "Main Room"
var current_wallpaper_path: String = ""
var current_wallpaper_fill_mode: String = "cover"

var world_canvas: Node2D = null
var room_default_bg: ColorRect = null
var room_background_sprite: Sprite2D = null
var floor_guide_line: Line2D = null
var main_camera: TouchCameraController = null
var atmosphere: AtmosphereController = null

var main_menu_ui: MainMenuUI = null
var world_map_screen: WorldMapController = null
var universe_hub_ui: UniverseHubUI = null
var universe_journal_ui: CanvasLayer = null
var magic_wheel_ui: MagicWheel = null
var lore_card_ui: CanvasLayer = null

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

# Resilient Index-Based Touch Tracking
var _active_touches: Dictionary = {}
var _ui_touch_indices: Dictionary = {}
var active_touch_index: int = -1
var _next_entity_uid: int = 1


func _ready() -> void:
	set_process(false)

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

	if room_default_bg != null:
		ThemeService.register_background(room_default_bg)

	var win: Window = get_window()
	if win != null and not win.size_changed.is_connected(_on_window_resized):
		win.size_changed.connect(_on_window_resized)

	_apply_hardware_safe_margins()

	if main_menu_ui != null:
		main_menu_ui.open_menu()
	
	FileDialog.set_get_thumbnail_callback(_generate_file_thumbnail)


static func _generate_file_thumbnail(path: String) -> Texture2D:
	var ext: String = path.get_extension().to_lower()
	if ext in ["png", "jpg", "jpeg", "webp"]:
		return UGCManager.get_thumbnail_async(path, 128)
	return null

func _ensure_ugc_directories() -> void:
	var paths: Array[String] = [
		"user://universes/", "user://maps/", "user://saves/"
	]
	for path: String in paths:
		DirAccess.make_dir_recursive_absolute(path)
	UGCManager.ensure_all_directories()


func _enforce_cross_platform_viewport() -> void:
	var win: Window = get_window()
	if win == null:
		return
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	win.content_scale_size = Vector2i(1280, 720)


func _apply_hardware_safe_margins() -> void:
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	if screen_size.x <= 0 or screen_size.y <= 0 or safe_area.size.x <= 0:
		return

	var top_margin: float = float(safe_area.position.y)
	var bottom_margin: float = float(screen_size.y - (safe_area.position.y + safe_area.size.y))

	if top_nav_bar != null and top_nav_bar.root_container != null:
		top_nav_bar.root_container.offset_top = maxf(14.0, top_margin + 6.0)

	if drawer_tray_ui != null and drawer_tray_ui.root_panel != null:
		var bottom_offset: float = -maxf(8.0, bottom_margin + 4.0)
		drawer_tray_ui.root_panel.offset_bottom = bottom_offset
		drawer_tray_ui.root_panel.offset_top = bottom_offset - drawer_tray_ui.DRAWER_HEIGHT


func _on_window_resized() -> void:
	if main_camera != null: main_camera.update_room_bounds(room_bounds)
	_update_room_bg_theme_color()
	if room_default_bg != null: ThemeService.register_background(room_default_bg)
	_apply_hardware_safe_margins()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
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


func _load_dialog_instance(candidate_paths: Array[String]) -> CanvasLayer:
	for path: String in candidate_paths:
		if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
			continue
		var script: Script = load(path) as Script
		if script == null:
			continue
		var instance: Variant = script.new()
		if instance is CanvasLayer:
			return instance as CanvasLayer
	return null


func _mount_subsystems() -> void:
	world_canvas = Node2D.new()
	world_canvas.name = "WorldCanvas"
	world_canvas.y_sort_enabled = true
	add_child(world_canvas)

	room_default_bg = ColorRect.new()
	room_default_bg.name = "RoomDefaultColorBg"
	room_default_bg.position = Vector2(-2000.0, -2000.0)
	room_default_bg.size = Vector2(ROOM_WIDTH + 4000.0, ROOM_HEIGHT + 4000.0)
	room_default_bg.z_index = Types.LayerBands.BACKGROUND - 5
	room_default_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_canvas.add_child(room_default_bg)
	ThemeService.register_background(room_default_bg)

	room_background_sprite = Sprite2D.new()
	room_background_sprite.name = "RoomBackground"
	room_background_sprite.z_index = Types.LayerBands.BACKGROUND
	room_background_sprite.centered = false
	world_canvas.add_child(room_background_sprite)

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

	universe_journal_ui = _load_dialog_instance([
		"res://UI/Dialogs/UniverseJournalDialog.gd",
		"res://UI/UniverseJournalDialog.gd",
		"res://ui/Dialogs/UniverseJournalDialog.gd"
	])
	if universe_journal_ui != null: add_child(universe_journal_ui)

	magic_wheel_ui = MagicWheel.new()
	magic_wheel_ui.action_triggered.connect(_on_magic_wheel_action)
	add_child(magic_wheel_ui)

	lore_card_ui = _load_dialog_instance([
		"res://UI/CharacterLoreCard.gd",
		"res://ui/CharacterLoreCard.gd",
		"res://CharacterLoreCard.gd"
	])
	if lore_card_ui != null: add_child(lore_card_ui)

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
	room_studio_ui.room_cleared.connect(_on_wallpaper_cleared)
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
	top_nav_bar.undo_requested.connect(_on_undo_requested)
	add_child(top_nav_bar)

	var modals: Array[Node] = [
		main_menu_ui, world_map_screen, universe_hub_ui, universe_journal_ui,
		lore_card_ui, pose_anim_studio_ui, snap_studio_ui, light_studio_ui,
		food_studio_ui, room_studio_ui, door_editor_dialog, elevator_dialog,
		theme_studio_dialog, entity_config_dialog, logic_rule_dialog,
		recipe_studio_dialog, container_storage_dialog, settings_dialog,
		magic_wheel_ui
	]

	for ui: Node in modals:
		if ui != null and is_instance_valid(ui):
			ui.add_to_group("modal_ui")


func _connect_system_signals() -> void:
	if not ThemeService.theme_changed.is_connected(_on_theme_changed):
		ThemeService.theme_changed.connect(_on_theme_changed)
	if EventBus.has_signal("room_changed") and not EventBus.room_changed.is_connected(_on_game_room_changed):
		EventBus.room_changed.connect(_on_game_room_changed)
	if EventBus.has_signal("global_atmosphere_changed") and not EventBus.global_atmosphere_changed.is_connected(_on_atmosphere_changed):
		EventBus.global_atmosphere_changed.connect(_on_atmosphere_changed)

	var history_manager: Node = get_node_or_null("/root/HistoryManager")
	if history_manager != null and history_manager.has_signal("state_restored") and not history_manager.is_connected("state_restored", Callable(self, "_on_history_state_restored")):
		history_manager.connect("state_restored", Callable(self, "_on_history_state_restored"))


func _on_theme_changed(_theme_data: Dictionary) -> void:
	_update_room_bg_theme_color()
	if room_default_bg != null:
		ThemeService.register_background(room_default_bg)


func _update_room_bg_theme_color() -> void:
	if room_default_bg != null:
		room_default_bg.color = ThemeService.get_color("window_background", "#fff5f7")


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


func _input(event: InputEvent) -> void:
	# =========================================================================
	# 1. Multi-Touch Screen Events (Mobile & Web Touch)
	# =========================================================================
	if event is InputEventScreenTouch:
		var screen_touch: InputEventScreenTouch = event as InputEventScreenTouch
		var touch_idx: int = screen_touch.index
		var touch_screen_pos: Vector2 = screen_touch.position
		var touch_world_pos: Vector2 = _screen_to_world(touch_screen_pos)

		current_pointer_screen_pos = touch_screen_pos
		current_pointer_world_pos = touch_world_pos

		if screen_touch.pressed:
			_active_touches[touch_idx] = touch_screen_pos

			# Check if touch landed on UI elements or open modal
			var is_ui_touch: bool = _is_any_modal_open()
			if not is_ui_touch:
				if drawer_tray_ui != null and drawer_tray_ui.is_point_inside_drawer(touch_screen_pos):
					is_ui_touch = true
				elif top_nav_bar != null and top_nav_bar.is_point_inside_nav(touch_screen_pos):
					is_ui_touch = true

			if is_ui_touch:
				_ui_touch_indices[touch_idx] = true
				if _active_touches.size() >= 2:
					_cancel_active_drag()
			else:
				_ui_touch_indices.erase(touch_idx)
				if _active_touches.size() == 1:
					active_touch_index = touch_idx
					_handle_press_begin(touch_world_pos, touch_screen_pos)
				elif _active_touches.size() >= 2:
					_cancel_active_drag()

		else: # Release
			_active_touches.erase(touch_idx)
			var was_ui_touch: bool = _ui_touch_indices.has(touch_idx)
			_ui_touch_indices.erase(touch_idx)

			if not was_ui_touch:
				if touch_idx == active_touch_index or _active_touches.is_empty():
					_handle_press_end(touch_world_pos)
					active_touch_index = -1

		# Pass touch state to camera controller for smooth pinch-to-zoom
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

	# =========================================================================
	# 2. Desktop Mouse Events (Filtered so emulated touch clicks don't double-fire)
	# =========================================================================
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
	target_pos.y = clampf(target_pos.y, room_bounds.position.y + top_offset, room_bounds.end.y - bottom_offset)
	active_dragged_entity.global_position = target_pos


func _update_active_process_state() -> void:
	set_process(is_pointer_down or active_dragged_entity != null)


func _handle_press_begin(world_pos: Vector2, screen_pos: Vector2) -> void:
	if is_pointer_down:
		return

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
		_record_history()
		if topmost.parent_socket_entity != null:
			topmost.detach_from_socket(world_canvas)

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
	if not is_pointer_down:
		return

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

	if released_target != null and released_target.is_locked and drag_dist <= TAP_PIXEL_THRESHOLD and elapsed_time <= 0.28:
		_trigger_haptic(35)
		EventBus.notification_requested.emit("Pinned in place (Hold to unlock)", true)
		_update_active_process_state()
		return

	if active_dragged_entity != null and is_instance_valid(active_dragged_entity):
		var released: OwnEntity = active_dragged_entity
		active_dragged_entity = null
		released.on_drop()
		LogicEngine.evaluate_trigger(Types.TriggerEvent.ON_DRAG_ENDED, released)
		AudioManager.play_drop_cushion()

		if drag_dist <= TAP_PIXEL_THRESHOLD and elapsed_time <= 0.28:
			_handle_layer1_tap(released)
		else:
			if released.entity_type == Types.EntityType.CHARACTER:
				for portal_ent: OwnEntity in all_entities:
					if portal_ent != released and portal_ent.is_portal and not portal_ent.is_elevator and portal_ent.contains_point(released.global_position):
						var target_room: String = portal_ent.target_room_id
						if target_room != "" and target_room != _get_current_room_id():
							var bundle: Array[Dictionary] = released.get_full_hierarchy_bundle()
							_remove_hierarchy(released)
							released.queue_free()
							SaveSystem.save_current_room_state()
							_transition_to_room(target_room, {"bundle": bundle})
							_update_active_process_state()
							return

			if released.entity_type == Types.EntityType.PROP:
				for container_ent: OwnEntity in all_entities:
					if container_ent != released and container_ent.is_container and container_ent.contains_point(released.global_position):
						all_entities.erase(released)
						container_ent.pack_item_inside(released)
						_trigger_haptic(45)
						SaveSystem.save_current_room_state()
						EventBus.notification_requested.emit("Packed into: " + container_ent.display_name, true)
						_update_active_process_state()
						return

			if InteractionSolver.check_and_execute_crafting(released, all_entities, world_canvas):
				_trigger_haptic(50)
				SaveSystem.save_current_room_state()
				_update_active_process_state()
				return

			var is_snapped: bool = SocketManager.evaluate_and_snap(released, all_entities)
			if is_snapped and released.parent_socket_entity != null:
				_trigger_haptic(35)
				LogicEngine.evaluate_trigger(Types.TriggerEvent.ON_ITEM_RECEIVED, released.parent_socket_entity, {"item": released})
			else:
				_apply_physical_gravity_settle(released)

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
	_trigger_haptic(20)
	LogicEngine.evaluate_trigger(Types.TriggerEvent.ON_TAPPED, entity)
	if entity.is_elevator: elevator_dialog.open_keypad(entity)
	elif entity.is_container: entity.toggle_container()
	elif entity.has_method("toggle_active_state"): entity.toggle_active_state()
	SaveSystem.save_current_room_state()


func _trigger_haptic(duration_ms: int = 30) -> void:
	if SettingsManager.are_haptics_enabled() and (OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")):
		if Input.has_method("vibrate_handheld"):
			Input.vibrate_handheld(duration_ms)


func _on_elevator_floor_travel_requested(elevator: OwnEntity, target_room_id: String, floor_name: String) -> void:
	if not is_instance_valid(elevator):
		return

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
		EventBus.notification_requested.emit("Arriving at " + floor_name + "...", true)
		_transition_to_room(target_room_id, {"bundle": bundle, "arrival_elevator": true})
	)


func _on_item_unpacked_from_container(item_data: Dictionary, container_ent: OwnEntity) -> void:
	var spawn_pos: Vector2 = container_ent.global_position + Vector2(randf_range(-40.0, 40.0), 20.0)
	RoomManager.reconstruct_traveler_bundle([item_data], spawn_pos, world_canvas, all_entities)
	_trigger_haptic(30)
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
		var tween: Tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween.tween_property(entity, "global_position:y", floor_baseline, fall_duration)


func _remove_hierarchy(root_ent: OwnEntity) -> void:
	all_entities.erase(root_ent)
	for child: OwnEntity in root_ent.attached_children:
		if is_instance_valid(child):
			_remove_hierarchy(child)


func _get_topmost_at(world_pos: Vector2, touch_padding: float = 0.0) -> OwnEntity:
	var best: OwnEntity = null
	for entity: OwnEntity in all_entities:
		if is_instance_valid(entity) and entity.is_visible_in_tree() and entity.contains_point(world_pos, touch_padding):
			if best == null or _is_entity_in_front_of(entity, best):
				best = entity
	return best


func _is_entity_in_front_of(a: OwnEntity, b: OwnEntity) -> bool:
	if a.parent_socket_entity == b: return true
	if b.parent_socket_entity == a: return false

	var z_a: int = _calculate_global_z(a)
	var z_b: int = _calculate_global_z(b)
	if z_a != z_b: return z_a > z_b

	var foot_a: float = a.global_position.y + a.get_visual_bottom_offset()
	var foot_b: float = b.global_position.y + b.get_visual_bottom_offset()
	if absf(foot_a - foot_b) > 2.0: return foot_a > foot_b

	var area_a: float = a.texture_size.x * a.texture_size.y * a.entity_scale * a.entity_scale
	var area_b: float = b.texture_size.x * b.texture_size.y * b.entity_scale * b.entity_scale
	return area_a < area_b


func _calculate_global_z(entity: OwnEntity) -> int:
	if not is_instance_valid(entity): return 0
	if entity.parent_socket_entity != null and is_instance_valid(entity.parent_socket_entity):
		return _calculate_global_z(entity.parent_socket_entity) + entity.z_index + 10
	return entity.z_index


func _load_session() -> Dictionary:
	const DEFAULT_SESSION: Dictionary = {
		"universe_id": "default_universe", "universe_name": "Default Universe",
		"room_id": "room_main", "time_preset": "day", "weather_preset": "none"
	}
	if not FileAccess.file_exists("user://session.json"):
		return DEFAULT_SESSION.duplicate(true)

	var content: String = FileAccess.get_file_as_string("user://session.json")
	var parsed: Variant = JSON.parse_string(content)
	return (parsed as Dictionary) if parsed is Dictionary else DEFAULT_SESSION.duplicate(true)


func _get_current_universe_id() -> String: return SaveSystem.get_current_universe_id()
func _get_current_room_id() -> String: return SaveSystem.get_current_room_id()


func _save_session_from_main_state() -> void:
	var session: Dictionary = _load_session()
	session["room_id"] = _get_current_room_id()
	var file: FileAccess = FileAccess.open("user://session.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(session, "\t"))
		file.close()


func _on_atmosphere_changed(time_preset: String, weather_preset: String) -> void:
	if atmosphere != null:
		atmosphere.set_preset(time_preset)
		atmosphere.set_weather(weather_preset)


func _transition_to_room(target_room_id: String, traveler_data: Dictionary = {}) -> void:
	var current_room_id_str: String = _get_current_room_id()
	if target_room_id.is_empty() or (target_room_id == current_room_id_str and traveler_data.is_empty()):
		return

	var session: Dictionary = _load_session()
	session["room_id"] = target_room_id
	var file: FileAccess = FileAccess.open("user://session.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(session, "\t"))
		file.close()

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

	var file: FileAccess = FileAccess.open("user://session.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(session, "\t"))
		file.close()

	if EventBus.has_signal("universe_changed"):
		EventBus.universe_changed.emit(new_u_id, new_u_name)


func _clear_current_universe_rooms() -> void:
	var save_dir: String = SaveSystem.get_universe_save_dir()
	if not DirAccess.dir_exists_absolute(save_dir):
		return
	var dir: DirAccess = DirAccess.open(save_dir)
	if dir == null: return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			DirAccess.remove_absolute(save_dir.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()


func _generate_entity_uuid(base_name: String) -> String:
	var sanitized: String = base_name.validate_node_name()
	if sanitized.is_empty(): sanitized = "entity"
	var uid: String = "%s_%d" % [sanitized, _next_entity_uid]
	_next_entity_uid += 1
	return uid


func _on_open_universe_journal() -> void:
	if universe_journal_ui == null or not is_instance_valid(universe_journal_ui):
		universe_journal_ui = _load_dialog_instance([
			"res://UI/Dialogs/UniverseJournalDialog.gd", "res://UI/UniverseJournalDialog.gd", "res://ui/Dialogs/UniverseJournalDialog.gd"
		])
		if universe_journal_ui != null:
			add_child(universe_journal_ui)
			universe_journal_ui.add_to_group("modal_ui")

	if universe_journal_ui != null and universe_journal_ui.has_method("open_journal"):
		universe_journal_ui.call("open_journal")


func _on_open_room_studio() -> void:
	_update_floor_guide_visuals(current_room_floor_y, true)
	if room_studio_ui != null:
		room_studio_ui.open_studio(current_room_title, current_room_floor_y, current_wallpaper_path, current_wallpaper_fill_mode)


func _on_floor_preview_changed(preview_y: float, preview_visible: bool) -> void:
	current_room_floor_y = preview_y
	_update_floor_guide_visuals(preview_y, preview_visible)


func _on_room_configured(wall_path: String, wall_texture: Texture2D, floor_y: float, room_name: String, fill_mode: String) -> void:
	current_wallpaper_path = wall_path
	current_wallpaper_fill_mode = fill_mode
	current_room_floor_y = floor_y
	current_room_title = room_name if not room_name.is_empty() else _get_current_room_id()
	_apply_room_wallpaper(wall_texture, fill_mode)
	_update_floor_guide_visuals(floor_y, false)
	SaveSystem.save_current_room_state()


func _apply_room_wallpaper(wall_texture: Texture2D, fill_mode: String) -> void:
	if room_background_sprite == null: return
	if wall_texture == null:
		room_background_sprite.texture = null
		return

	room_background_sprite.texture = wall_texture
	var texture_width: float = float(wall_texture.get_width())
	var texture_height: float = float(wall_texture.get_height())
	if texture_width <= 0.0 or texture_height <= 0.0: return

	match fill_mode:
		"cover":
			room_background_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
			room_background_sprite.region_enabled = false
			room_background_sprite.centered = true
			room_background_sprite.position = room_bounds.get_center()
			var scale_cover: float = maxf(ROOM_WIDTH / texture_width, ROOM_HEIGHT / texture_height)
			room_background_sprite.scale = Vector2(scale_cover, scale_cover)
		"fit":
			room_background_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
			room_background_sprite.region_enabled = false
			room_background_sprite.centered = true
			room_background_sprite.position = room_bounds.get_center()
			var scale_fit: float = minf(ROOM_WIDTH / texture_width, ROOM_HEIGHT / texture_height)
			room_background_sprite.scale = Vector2(scale_fit, scale_fit)
		"stretch":
			room_background_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
			room_background_sprite.region_enabled = false
			room_background_sprite.centered = false
			room_background_sprite.position = Vector2.ZERO
			room_background_sprite.scale = Vector2(ROOM_WIDTH / texture_width, ROOM_HEIGHT / texture_height)
		"tile":
			room_background_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			room_background_sprite.region_enabled = true
			room_background_sprite.region_rect = Rect2(0.0, 0.0, ROOM_WIDTH, ROOM_HEIGHT)
			room_background_sprite.centered = false
			room_background_sprite.position = Vector2.ZERO
			room_background_sprite.scale = Vector2.ONE
		"original":
			room_background_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
			room_background_sprite.region_enabled = false
			room_background_sprite.centered = true
			room_background_sprite.position = room_bounds.get_center()
			room_background_sprite.scale = Vector2.ONE


func _on_wallpaper_cleared() -> void:
	current_wallpaper_path = ""
	current_wallpaper_fill_mode = "cover"
	if room_background_sprite != null: room_background_sprite.texture = null
	_update_room_bg_theme_color()


func _update_floor_guide_visuals(floor_y: float, preview_visible: bool) -> void:
	if floor_guide_line == null: return
	if preview_visible:
		floor_guide_line.clear_points()
		floor_guide_line.add_point(Vector2(0.0, floor_y))
		floor_guide_line.add_point(Vector2(ROOM_WIDTH, floor_y))
		floor_guide_line.visible = true
	else:
		floor_guide_line.visible = false


func _load_active_room(room_id: String, traveler_data: Dictionary = {}) -> void:
	is_room_loaded = false
	RoomManager.stream_room(room_id, traveler_data, world_canvas, all_entities)

	if atmosphere != null:
		var session: Dictionary = _load_session()
		atmosphere.set_preset(str(session.get("time_preset", "day")))
		atmosphere.set_weather(str(session.get("weather_preset", "none")))

	var saved_state: Dictionary = SaveSystem.load_room_state(room_id)
	current_room_floor_y = float(saved_state.get("floor_y", 620.0))
	current_room_title = str(saved_state.get("room_title", room_id))
	current_wallpaper_fill_mode = str(saved_state.get("wallpaper_fill_mode", "cover"))

	var wall_path: String = str(saved_state.get("wallpaper_path", ""))
	if not wall_path.is_empty() and FileAccess.file_exists(wall_path):
		current_wallpaper_path = wall_path
		_apply_room_wallpaper(UGCManager.load_texture_from_file(wall_path), current_wallpaper_fill_mode)
	else:
		_on_wallpaper_cleared()

	_update_floor_guide_visuals(current_room_floor_y, false)
	if main_camera != null: main_camera.update_room_bounds(room_bounds)
	if drawer_tray_ui != null: drawer_tray_ui.refresh_tray()
	is_room_loaded = true


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


func _serialize_state() -> Dictionary:
	var entities: Array[Dictionary] = []
	for entity: OwnEntity in all_entities:
		if is_instance_valid(entity):
			entities.append(entity.to_dict())

	var camera_position: Vector2 = main_camera.position if main_camera != null else Vector2(960.0, 540.0)
	var camera_zoom: float = main_camera.zoom.x if main_camera != null else 1.0

	return {
		"version": "1.0",
		"room_title": current_room_title,
		"floor_y": current_room_floor_y,
		"wallpaper_path": current_wallpaper_path,
		"wallpaper_fill_mode": current_wallpaper_fill_mode,
		"camera_pos": {"x": camera_position.x, "y": camera_position.y},
		"camera_zoom": camera_zoom,
		"entities": entities
	}


func _on_history_state_restored(snapshot: Dictionary) -> void:
	RoomManager.deserialize_room_into_canvas(snapshot, world_canvas, all_entities)


func _on_drawer_spawn_ugc(item_name: String, texture: Texture2D, file_path: String) -> void:
	var texture_height: float = float(texture.get_height()) if texture != null else 64.0
	var scale_factor: float = clampf(180.0 / texture_height, 0.08, 1.0) if texture_height > 240.0 else 1.0
	var uid: String = _generate_entity_uuid(item_name)
	var entity: OwnEntity = OwnEntity.new()
	var camera_x: float = main_camera.position.x if main_camera != null else 960.0
	var spawn_x: float = clampf(camera_x + randf_range(-40.0, 40.0), 100.0, ROOM_WIDTH - 100.0)

	entity.setup(uid, item_name, texture, Vector2(spawn_x, current_room_floor_y), Types.EntityType.PROP, file_path)
	entity.set_entity_scale(scale_factor)

	var bottom_offset: float = entity.get_visual_bottom_offset()
	entity.position.y = clampf(current_room_floor_y - bottom_offset, 100.0, ROOM_HEIGHT - 100.0)

	world_canvas.add_child(entity)
	all_entities.append(entity)
	entity.trigger_spawn_juice()
	_trigger_haptic(30)
	SaveSystem.save_current_room_state()


func _on_character_spawn_requested(char_data: Dictionary) -> void:
	var camera_x: float = main_camera.position.x if main_camera != null else 960.0
	var spawn_pos: Vector2 = Vector2(camera_x, current_room_floor_y - 80.0)
	RoomManager.reconstruct_traveler_bundle([char_data], spawn_pos, world_canvas, all_entities)
	_trigger_haptic(35)
	SaveSystem.save_current_room_state()


func _on_template_spawn_requested(template_data: Dictionary) -> void:
	var camera_x: float = main_camera.position.x if main_camera != null else 960.0
	var spawn_x: float = clampf(camera_x + randf_range(-40.0, 40.0), 100.0, ROOM_WIDTH - 100.0)
	var spawn_y: float = current_room_floor_y - 80.0
	RoomManager.reconstruct_traveler_bundle([template_data], Vector2(spawn_x, spawn_y), world_canvas, all_entities)
	_trigger_haptic(30)
	SaveSystem.save_current_room_state()


func _on_magic_wheel_action(action_name: String, target: OwnEntity) -> void:
	if not is_instance_valid(target):
		return

	match action_name:
		"flip": target.flip_horizontal()
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
		"elevator":
			if elevator_dialog != null: elevator_dialog.open_keypad(target)
		"edit_floors":
			if elevator_dialog != null: elevator_dialog.open_floor_studio(target)
		"save_template":
			if drawer_tray_ui != null: drawer_tray_ui.store_entity_as_template(target)
		"lock":
			target.is_locked = not target.is_locked
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
			SaveSystem.save_current_room_state()
		"store":
			all_entities.erase(target)
			if drawer_tray_ui != null: drawer_tray_ui.store_character_in_tray(target)
			_trigger_haptic(45)
			SaveSystem.save_current_room_state()
		"delete":
			all_entities.erase(target)
			target.queue_free()
			_trigger_haptic(50)
			SaveSystem.save_current_room_state()


func _on_undo_requested() -> void:
	var history: Node = get_node_or_null("/root/HistoryManager")
	if history != null and history.has_method("undo"):
		history.call("undo")
