# ==============================================================================
# OWNWORLD - IN-GAME TUTORIAL & CREATOR HANDBOOK
# File: res://UI/Dialogs/TutorialDialog.gd
# Base Class: CanvasLayer (class_name TutorialDialog)
# ==============================================================================

class_name TutorialDialog
extends CanvasLayer

signal dialog_closed()

const MAX_PANEL_WIDTH: float = 960.0
const MAX_PANEL_HEIGHT: float = 620.0

var root_backdrop: Control = null
var center_container: CenterContainer = null
var root_panel: PanelContainer = null

var header_title_lbl: Label = null
var search_input: LineEdit = null
var btn_close: Button = null

var topics_list_vbox: VBoxContainer = null
var content_scroll: ScrollContainer = null
var content_vbox: VBoxContainer = null

var active_topic_index: int = 0
var active_filter_query: String = ""

# Handbook Chapters Data
var tutorial_chapters: Array[Dictionary] = [
	{
		"id": "quickstart",
		"title": "1. Quickstart & Controls",
		"icon": "icon_play",
		"badge": "Basics",
		"sections": [
			{
				"title": "Welcome to OwnWorld: Dollhouse!",
				"body": "OwnWorld: Dollhouse is an open 2D storytelling, dollhouse, and worldbuilding sandbox. Everything you see (characters, furniture, food, rooms, and logic) can be interacted with, customized, or created from scratch using your own drawings."
			},
			{
				"title": "Navigation & Camera Controls",
				"body": "• Pan / Move Camera: Click or drag on empty room space, or drag with two fingers on mobile / trackpads.\n• Zoom In & Out: Use your Mouse Scroll Wheel or pinch with two fingers on mobile screens.\n• Recenter: If you ever lose your place, open the Top Nav Bar and pan back toward the center."
			},
			{
				"title": "Interacting with Objects",
				"body": "• Tap / Click: Tap on lights, doors, containers, or appliances to trigger their default action (turn on/off, open/close, toggle).\n• Drag & Drop: Press and hold any unlocked item or character to pick it up. Drop it onto tables, chairs, characters, or containers to attach or store it.\n• Long-Press / Right-Click: Hold down on any item or character (or right-click with a mouse) to summon the Magic Wheel context menu!"
			},
			{
				"title": "The Bottom Drawer Tray",
				"body": "Tap the floating '▲' button at the bottom of the screen to open your Drawer Tray. This gives you instant access to your imported Art Assets, saved Props, Furniture prefabs, and your Cast Roster."
			}
		]
	},
	{
		"id": "ugc_art",
		"title": "2. Bringing Your Art to Life",
		"icon": "icon_assets",
		"badge": "Custom Art",
		"sections": [
			{
				"title": "Where Your Drawings Live",
				"body": "OwnWorld automatically watches your device's Documents directory. You can place your custom transparent drawings into:\n\n📁 Documents / OwnWorld / Dollhouse / Art\n\nAny PNG, WebP, JPG, or JPEG placed in this folder (or any subfolder inside it) will appear instantly in your Assets Drawer with zero loading lag."
			},
			{
				"title": "Creating Perfect Transparent Cutouts",
				"body": "• Use Transparent PNG or WebP files with transparent backgrounds.\n• The engine automatically generates pixel-perfect collision silhouettes around non-transparent pixels (no manual collision tracing required)!\n• Crop transparent borders closely around your art for the best dragging and snapping experience."
			},
			{
				"title": "In-Game Importing & Folders",
				"body": "• Tap the 'Import' button in the Assets Drawer to select pictures directly from your device storage or camera roll.\n• Tap the '+ Folder' button to create custom organizational categories (e.g. 'Outfits', 'Food', 'Bakery_Items').\n• Tap the Tag icon on any item card to assign hashtags (#food, #props, #magic) or move it between folders."
			}
		]
	},
	{
		"id": "characters_poses",
		"title": "3. Characters & 6-Poses",
		"icon": "icon_cast",
		"badge": "Characters",
		"sections": [
			{
				"title": "The Cast Tray (Persistent Characters)",
				"body": "Characters saved in your Cast Tray are persistent story actors. When you summon a character from the Cast Tray into a room, they will remember their custom outfits, profile notes, family ties, and relationship feelings across every room in your Universe."
			},
			{
				"title": "The 6-Pose Expressive Sprites",
				"body": "Long-press your character and choose 'States & Anims' to open the Pose Studio. You can assign dedicated drawings for expressive reactions:\n\n1. Eyes Open: Default standing sprite.\n2. Eyes Closed: Automatically used when blinking or sleeping in beds.\n3. Mouth Open: Automatically triggered when eating, drinking, or talking.\n4. Sitting: Used when snapped onto chairs, couches, and stools.\n5. Sitting (Eyes Closed): Used when blinking while seated.\n6. Sitting (Mouth Open): Used when eating/drinking while seated.\n\n*Note: Any slot left unassigned will automatically fall back to your main base drawing!*"
			},
			{
				"title": "Multiple Outfits & Forms",
				"body": "In the Pose Studio, tap '+ Add' in the top bar to create alternate wardrobe forms (e.g. 'Pajamas', 'Winter Coat', 'Hero Armor'). Characters can seamlessly switch outfits via the Magic Wheel or automated Logic Rules!"
			},
			{
				"title": "Frame-by-Frame Animation Clips",
				"body": "Switch to the 'Clips & Loops' tab in the Pose Studio to create custom multi-frame animations (such as walking, dancing, spinning, or waving). You can set custom frame rates (FPS) and loop modes (Loop, Natural Blink, or One-Shot)."
			}
		]
	},
	{
		"id": "anchors_sockets",
		"title": "4. Anchors & Dressing Up",
		"icon": "icon_anchors",
		"badge": "Sockets",
		"sections": [
			{
				"title": "How Snapping Works",
				"body": "Items snap together intelligently using Anchor Sockets. Dragging a hat near a character's head or an apple near their hand causes the item to seamlessly lock into position with satisfying haptic feedback and snap chimes."
			},
			{
				"title": "Using the Snap Point Studio",
				"body": "Long-press any character or furniture piece and select 'Anchors'.\n\n1. Select an Anchor Category from the dropdown (e.g. 'Hand Sockets', 'Head / Hats', 'Seat Sockets', 'Table Surfaces', 'Bed Sleep').\n2. Tap directly on the illustration preview where you want the connection point to live.\n3. Tap 'Next Slot' to place additional sockets (e.g. hand_2, seat_2).\n4. Tap 'Save Anchors' to finish."
			},
			{
				"title": "Special Socket Types",
				"body": "• Hand Sockets (hand_1, hand_2): Allows characters to hold props.\n• Seat Sockets (seat_1): Tells characters where to sit down on chairs/benches.\n• Character Sit Baseline (sit_point): Placed on a character's body to define their hip/sitting baseline for perfect seat alignment.\n• Surface Sockets (surface_1): Placed on desks, counters, and shelves for holding props.\n• Bed Sockets (bed_1): Automatically rotates characters into a horizontal sleeping pose."
			}
		]
	},
	{
		"id": "food_liquids_crafting",
		"title": "5. Food, Drinks, Liquids & Merging",
		"icon": "icon_food",
		"badge": "Interactive",
		"sections": [
			{
				"title": "Eating & Proximity Chewing",
				"body": "Hold any food prop near a character's face. The character will automatically open their mouth, play chewing sounds, emit crumb particles, and take bites until the food is finished!"
			},
			{
				"title": "Sequential Bite Stages (Food Studio)",
				"body": "Open the Magic Wheel and choose 'Food & Drink' to configure food props. You can configure multiple sequential bite drawings (e.g. Whole Cake -> Half Cake -> Slice -> Empty Plate) or enable 'Infinite' for endless snacking."
			},
			{
				"title": "Drink Physics & Cup-to-Cup Pouring",
				"body": "• Tilt Sipping: Dragging a beverage cup to a character's mouth tilts the cup realistically and plays sipping audio.\n• Liquid Pouring: Hover a full cup, bottle, or teapot above an empty cup to tilt and pour liquid, filling the recipient cup!\n• Faucets & Sinks: Configure an appliance as a 'Water Stream' to create functional running sinks with flowing particle water."
			},
			{
				"title": "Bags & Physical Containers",
				"body": "Items marked as Containers (backpacks, chests, drawers, gift boxes) can store items. Simply drop any prop onto a container to pack it inside! Tap the container to open its storage inventory and unpack items anytime."
			},
			{
				"title": "Visual Recipe Creator (Item Merging)",
				"body": "Open the Main Menu and tap 'Visual Recipe Creator' to craft item combinations (e.g. Dough + Tomato = Pizza; Potion + Herb = Elixir). In the room, simply drop Ingredient A on top of Ingredient B to trigger a magic merge poof!"
			}
		]
	},
	{
		"id": "logic_rules",
		"title": "6. Cause & Effect Logic Studio",
		"icon": "icon_logic",
		"badge": "Visual Scripting",
		"sections": [
			{
				"title": "No-Code Interactive Story Scripting",
				"body": "The Logic Rule Editor lets you build interactive puzzle mechanics and living story moments without writing a single line of code!"
			},
			{
				"title": "Rule Architecture (When -> Target -> Then)",
				"body": "Every logic rule follows a clean 3-step format:\n\n1. When This Happens: (Tapped, Item Dropped Onto It, Picked Up, Released).\n   • Optional Item Filter: Only trigger if the dropped item is named e.g. 'Gold Key'.\n2. Apply Action To: (Self, Dropped Item, All Characters in Room, Environment).\n3. Then Execute Action:\n   • Say Dialogue: Shows a comic speech bubble over the character.\n   • Spray Symbol: Floating hearts, stars, music notes, or questions.\n   • Play Animation / Swap Outfit: Automatically trigger an outfit change or animation loop.\n   • Change Mood & Weather: Switch to Sunset/Night or start rain/snow.\n   • Spawn Item: Conjure an item from your art library into the room.\n   • Teleport: Transition the scene to a target room."
			},
			{
				"title": "Example Logic Ideas",
				"body": "• Magic Wand: When Tapped -> All Characters -> Spray '✨'.\n• Treasure Chest: When 'Brass Key' Dropped -> Self -> Spawn 'Diamond'.\n• Bedside Lamp: When Tapped -> Environment -> Change Mood to 'Night'.\n• Door Bell: When Tapped -> Self -> Play Sound 'Chime'."
			}
		]
	},
	{
		"id": "rooms_elevators_map",
		"title": "7. Rooms, Elevators & World Map",
		"icon": "icon_room",
		"badge": "Worldbuilding",
		"sections": [
			{
				"title": "Room & Wallpaper Studio",
				"body": "Tap 'Room' in the Top Nav Bar to customize the current scene:\n• Room Background: Select any drawing from your Art library to serve as the wallpaper.\n• Fill Modes: Choose Aspect Cover, Aspect Fit, Stretch, Tile (for seamless patterns), or 1:1 Original.\n• Floor Baseline: Drag the floor slider to set the ground level where characters and furniture naturally walk and rest."
			},
			{
				"title": "Doorways & Portals",
				"body": "Any object or door frame can be marked as a Portal. Configure its Destination Room ID in the Magic Wheel. Dragging a character onto the doorway will smoothly transport them into the target room!"
			},
			{
				"title": "Multi-Floor Elevators",
				"body": "Elevators can hold multiple passengers simultaneously! Open the Elevator Studio to assign floor numbers and room IDs (e.g. '1F Lobby -> room_lobby', '2F Penthouse -> room_penthouse'). Tapping the elevator opens an interactive keypad: passengers inside the cabin travel together upon arrival!"
			},
			{
				"title": "Interactive World Maps",
				"body": "Open 'World Maps' from the Main Menu or Top Nav Bar:\n• Set custom world map artwork.\n• Switch to 'Edit' mode to drop, drag, and configure Location Pins pointing to different rooms in your Universe.\n• In 'Play' mode, tap any pin to immediately travel to that location."
			}
		]
	},
	{
		"id": "lore_journals_factions",
		"title": "8. Lore, Family Trees & Journals",
		"icon": "icon_lore",
		"badge": "Narrative",
		"sections": [
			{
				"title": "Character Lore Cards",
				"body": "Long-press any character and select 'Profile' to open their 3-tab Lore Card:\n• Tab 1 (Profile): Name, Pronouns, Role/Title, Life Status (Living/Spirit/Missing), custom avatar image, and unlimited customizable traits.\n• Tab 2 (Family & Feelings): Two-way symmetrical family trees (Parents, Children, Siblings, Partners) and directional relationship feelings (Best Friends, Rivals, Secret Crushes, Mentors).\n• Tab 3 (Backstory): Full text area for backstories, secrets, and character notes."
			},
			{
				"title": "World Journal & Chronicles",
				"body": "Open the World Journal to record the lore of your Universe:\n• Chronicles & Timeline: Create dated story eras, record historic events, link participating characters, and record what happened in specific rooms.\n• Factions & Guilds: Build kingdoms, guilds, academies, and syndicates with custom badge colors, mottos, headquarters, appointed leaders, and enlisted member rosters with ranks."
			}
		]
	},
	{
		"id": "universes_packs",
		"title": "9. Universes & .ownpack Sharing",
		"icon": "icon_universe",
		"badge": "Sharing",
		"sections": [
			{
				"title": "Story Universes",
				"body": "Universes act as independent save worlds. Each Universe maintains its own separate rooms, Cast rosters, recipes, World Maps, and Journal chronicles. Switch between stories anytime via the Universe Hub."
			},
			{
				"title": "Exporting (.ownpack)",
				"body": "Tap 'Export Active (.ownpack)' in the Universe Hub to bundle your entire story universe (including all rooms, custom drawings, Cast characters, recipes, maps, and lore) into a single `.ownpack` zip package saved to:\n\n📁 Documents / OwnWorld / Dollhouse / Exports"
			},
			{
				"title": "Importing Story Packs",
				"body": "Download an `.ownpack` created by a friend and tap 'Import (.ownpack)' in the Universe Hub to load and play their custom world instantly!"
			}
		]
	},
	{
		"id": "theming_settings",
		"title": "10. Themes, Fonts & Mobile Polish",
		"icon": "icon_palette",
		"badge": "Customization",
		"sections": [
			{
				"title": "Palette & Font Studio",
				"body": "Customize the visual appearance of the entire engine! Choose from curated themes (Strawberry Milk, Matcha Latte, Lavender Mist, Midnight Velvet) or pick custom colors for panels, buttons, accents, and text. Place custom `.ttf` or `.otf` font files in `Documents/OwnWorld/Dollhouse/Font` to restyle all typography."
			},
			{
				"title": "Touch & Display Settings",
				"body": "• UI Scale: Scale up UI menus for phones or tablets.\n• Touch / Grab Padding: Expands invisible hitboxes around tiny drawings so they are effortless to pick up on mobile touchscreens.\n• Hold Duration: Adjust the long-press duration required to summon the Magic Wheel."
			},
			{
				"title": "Developer Diagnostics (F1)",
				"body": "Enable Developer Mode in Settings (or press F1 on keyboards) to display live FPS counters, coordinate data, visual collision outlines, and socket attachment lines."
			}
		]
	}
]


func _ready() -> void:
	layer = 125
	visible = false
	add_to_group("modal_ui")
	_build_ui()
	_connect_system_signals()
	_update_responsive_layout()
	_apply_theme_styling()


func _connect_system_signals() -> void:
	if not ThemeService.theme_changed.is_connected(_on_theme_changed):
		ThemeService.theme_changed.connect(_on_theme_changed)
	var tree: SceneTree = get_tree()
	if tree and tree.root and not tree.root.size_changed.is_connected(_update_responsive_layout):
		tree.root.size_changed.connect(_update_responsive_layout)


func _update_responsive_layout() -> void:
	if not is_instance_valid(root_panel): return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280.0, 720.0)
	var target_w: float = clampf(vp_size.x * 0.94, 310.0, MAX_PANEL_WIDTH)
	var target_h: float = clampf(vp_size.y * 0.92, 340.0, MAX_PANEL_HEIGHT)
	root_panel.custom_minimum_size = Vector2(target_w, target_h)
	root_panel.size = Vector2(target_w, target_h)


func _on_theme_changed(_theme_data: Dictionary) -> void:
	_apply_theme_styling()
	if visible:
		_render_topics_sidebar()
		_render_active_topic_content()


func open_handbook(starting_topic_index: int = 0) -> void:
	active_topic_index = clampi(starting_topic_index, 0, tutorial_chapters.size() - 1)
	active_filter_query = ""
	if search_input: search_input.text = ""
	_update_responsive_layout()
	_apply_theme_styling()
	_render_topics_sidebar()
	_render_active_topic_content()
	visible = true


func close_handbook() -> void:
	visible = false
	dialog_closed.emit()


func _build_ui() -> void:
	root_backdrop = Control.new()
	root_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root_backdrop.gui_input.connect(_on_backdrop_gui_input)
	add_child(root_backdrop)

	var bg_dim: ColorRect = ColorRect.new()
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_dim.color = Color(0.0, 0.0, 0.0, 0.65)
	bg_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_backdrop.add_child(bg_dim)

	center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_PASS
	root_backdrop.add_child(center_container)

	root_panel = PanelContainer.new()
	root_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center_container.add_child(root_panel)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 8)
	root_panel.add_child(main_vbox)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	header_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(header_hbox)

	header_title_lbl = Label.new()
	header_title_lbl.text = "OwnWorld Creator Handbook & Guide"
	header_title_lbl.theme_type_variation = "HeaderLabel"
	header_title_lbl.add_theme_font_size_override("font_size", 14)
	header_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header_title_lbl)

	search_input = LineEdit.new()
	search_input.placeholder_text = "Search topics (e.g. pouring, elevator, anchors)..."
	search_input.custom_minimum_size = Vector2(240.0, 30.0)
	search_input.text_changed.connect(_on_search_query_changed)
	header_hbox.add_child(search_input)

	btn_close = Button.new()
	btn_close.custom_minimum_size = Vector2(28.0, 28.0)
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.add_theme_constant_override("icon_max_width", 12)
	var close_icon: Texture2D = ThemeService.get_icon("icon_close")
	if close_icon: btn_close.icon = close_icon
	else: btn_close.text = "✕"
	btn_close.pressed.connect(close_handbook)
	header_hbox.add_child(btn_close)

	main_vbox.add_child(HSeparator.new())

	var split_hbox: HBoxContainer = HBoxContainer.new()
	split_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(split_hbox)

	# Left Sidebar: Topic List
	var left_scroll: ScrollContainer = ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(240.0, 0.0)
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_scroll.follow_focus = false
	split_hbox.add_child(left_scroll)

	topics_list_vbox = VBoxContainer.new()
	topics_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topics_list_vbox.add_theme_constant_override("separation", 4)
	left_scroll.add_child(topics_list_vbox)

	split_hbox.add_child(VSeparator.new())

	# Right Reader View
	var content_panel: PanelContainer = PanelContainer.new()
	content_panel.theme_type_variation = "SubPanel"
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_hbox.add_child(content_panel)

	content_scroll = ScrollContainer.new()
	content_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.follow_focus = false
	content_panel.add_child(content_scroll)

	content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 12)
	content_scroll.add_child(content_vbox)


func _render_topics_sidebar() -> void:
	if not topics_list_vbox: return
	for child: Node in topics_list_vbox.get_children():
		child.queue_free()

	var c_accent: Color = ThemeService.get_color("accent_primary", "#ec4899")
	var rad: int = ThemeService.get_corner_radius()

	for i: int in range(tutorial_chapters.size()):
		var chapter: Dictionary = tutorial_chapters[i]
		var c_title: String = str(chapter["title"])

		# Filter matches
		if not active_filter_query.is_empty():
			var matches_query: bool = active_filter_query in c_title.to_lower()
			if not matches_query:
				for s in chapter.get("sections", []):
					if active_filter_query in str(s.get("title", "")).to_lower() or active_filter_query in str(s.get("body", "")).to_lower():
						matches_query = true
						break
			if not matches_query: continue

		var is_active: bool = (i == active_topic_index)
		var btn: Button = Button.new()
		btn.text = " " + c_title
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0.0, 34.0)
		btn.focus_mode = Control.FOCUS_NONE
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 10)
		btn.add_theme_constant_override("icon_max_width", 14)

		var icon_tex: Texture2D = ThemeService.get_icon(str(chapter.get("icon", "icon_room")))
		if icon_tex: btn.icon = icon_tex

		if is_active:
			var s_act: StyleBoxFlat = StyleBoxFlat.new()
			s_act.bg_color = c_accent
			s_act.border_color = c_accent
			s_act.set_border_width_all(1)
			s_act.set_corner_radius_all(rad)
			s_act.content_margin_left = 8
			s_act.content_margin_right = 8
			s_act.content_margin_top = 4
			s_act.content_margin_bottom = 4
			btn.add_theme_stylebox_override("normal", s_act)
			btn.add_theme_stylebox_override("hover", s_act)
			btn.add_theme_stylebox_override("pressed", s_act)
			btn.add_theme_color_override("font_color", Color.WHITE)
			btn.add_theme_color_override("icon_normal_color", Color.WHITE)

		var target_idx: int = i
		btn.pressed.connect(func() -> void:
			active_topic_index = target_idx
			_render_topics_sidebar()
			_render_active_topic_content()
		)
		topics_list_vbox.add_child(btn)


func _render_active_topic_content() -> void:
	if not content_vbox: return
	for child: Node in content_vbox.get_children():
		child.queue_free()

	if active_topic_index < 0 or active_topic_index >= tutorial_chapters.size():
		return

	var chapter: Dictionary = tutorial_chapters[active_topic_index]
	var c_title: String = str(chapter["title"])
	var c_badge: String = str(chapter.get("badge", ""))
	var sections: Array = chapter.get("sections", [])

	# Chapter Header
	var title_card: PanelContainer = PanelContainer.new()
	title_card.theme_type_variation = "SubPanel"
	content_vbox.add_child(title_card)

	var title_hbox: HBoxContainer = HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 10)
	title_card.add_child(title_hbox)

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(28.0, 28.0)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_tex: Texture2D = ThemeService.get_icon(str(chapter.get("icon", "icon_room")))
	if icon_tex: icon_rect.texture = icon_tex
	title_hbox.add_child(icon_rect)

	var title_lbl: Label = Label.new()
	title_lbl.text = c_title
	title_lbl.theme_type_variation = "HeaderLabel"
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(title_lbl)

	var badge_lbl: Label = Label.new()
	badge_lbl.text = c_badge.to_upper()
	badge_lbl.theme_type_variation = "HintLabel"
	badge_lbl.add_theme_font_size_override("font_size", 9)
	title_hbox.add_child(badge_lbl)

	# Content Cards
	for sec_var in sections:
		if not sec_var is Dictionary: continue
		var sec: Dictionary = sec_var as Dictionary
		var s_title: String = str(sec.get("title", ""))
		var s_body: String = str(sec.get("body", ""))

		var card: PanelContainer = PanelContainer.new()
		card.theme_type_variation = "SubPanel"
		content_vbox.add_child(card)

		var card_vbox: VBoxContainer = VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 6)
		card.add_child(card_vbox)

		if not s_title.is_empty():
			var st_lbl: Label = Label.new()
			st_lbl.text = s_title
			st_lbl.theme_type_variation = "HeaderLabel"
			st_lbl.add_theme_font_size_override("font_size", 11)
			card_vbox.add_child(st_lbl)

		var sb_lbl: Label = Label.new()
		sb_lbl.text = s_body
		sb_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sb_lbl.add_theme_font_size_override("font_size", 10)
		sb_lbl.add_theme_color_override("font_color", ThemeService.get_color("text_primary", "#6c2e3f"))
		card_vbox.add_child(sb_lbl)

	# Bottom Navigation Row (Prev / Next Chapter)
	var nav_row: HBoxContainer = HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 10)
	content_vbox.add_child(nav_row)

	if active_topic_index > 0:
		var btn_prev: Button = Button.new()
		btn_prev.text = "◄ Previous Chapter"
		btn_prev.focus_mode = Control.FOCUS_NONE
		btn_prev.pressed.connect(func() -> void:
			active_topic_index -= 1
			_render_topics_sidebar()
			_render_active_topic_content()
			content_scroll.scroll_vertical = 0
		)
		nav_row.add_child(btn_prev)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_row.add_child(spacer)

	if active_topic_index < tutorial_chapters.size() - 1:
		var btn_next: Button = Button.new()
		btn_next.text = "Next Chapter: " + str(tutorial_chapters[active_topic_index + 1]["title"]).split(". ")[-1] + " ►"
		btn_next.focus_mode = Control.FOCUS_NONE
		btn_next.pressed.connect(func() -> void:
			active_topic_index += 1
			_render_topics_sidebar()
			_render_active_topic_content()
			content_scroll.scroll_vertical = 0
		)
		nav_row.add_child(btn_next)


func _on_search_query_changed(new_text: String) -> void:
	active_filter_query = new_text.strip_edges().to_lower()
	_render_topics_sidebar()


func _apply_theme_styling() -> void:
	var c_bg: Color = ThemeService.get_color("panel_background", "#fff5f7")
	var c_border: Color = ThemeService.get_color("panel_border", "#f9a8d4")
	var c_accent: Color = ThemeService.get_color("accent_primary", "#ec4899")
	var radius: int = ThemeService.get_corner_radius()

	if root_panel:
		var p_style: StyleBoxFlat = StyleBoxFlat.new()
		p_style.bg_color = c_bg
		p_style.border_color = c_border
		p_style.set_border_width_all(2)
		p_style.set_corner_radius_all(radius + 2)
		p_style.content_margin_left = 14
		p_style.content_margin_right = 14
		p_style.content_margin_top = 10
		p_style.content_margin_bottom = 10
		root_panel.add_theme_stylebox_override("panel", p_style)

	if header_title_lbl:
		header_title_lbl.add_theme_color_override("font_color", c_accent)

	var close_icon: Texture2D = ThemeService.get_icon("icon_close")
	if close_icon and btn_close:
		btn_close.icon = close_icon


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		close_handbook()
