# ============================================================
# File: res://UI/Dialogs/TutorialDialog.gd
# ============================================================

# ==============================================================================
# OWNWORLD - IN-GAME CREATOR HANDBOOK (LANDSCAPE MASTER-DETAIL DUAL-OS)
# File: res://UI/Dialogs/TutorialDialog.gd
# Base Class: CanvasLayer (class_name TutorialDialog)
#
# Responsibility: In-game player guide and creator handbook modal.
# 10 player-friendly chapters covering controls, custom drawings,
# outfits, living animations, sockets, food, story puzzles, rooms, and lore.
# ==============================================================================

class_name TutorialDialog
extends CanvasLayer

signal dialog_closed()

const MAX_PANEL_WIDTH: float = 780.0
const MAX_PANEL_HEIGHT: float = 580.0

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

# Handbook Chapters Data (Player-Friendly Content)
var tutorial_chapters: Array[Dictionary] = [
	{
		"id": "quickstart",
		"title": "1. Quickstart & How to Play",
		"icon": "icon_play",
		"badge": "Basics",
		"sections": [
			{
				"title": "Welcome to OwnWorld: Dollhouse!",
				"body": "OwnWorld: Dollhouse is your personal creative playground. You can tell stories, decorate rooms, dress up characters, cook food, and even make things happen automatically using simple cause-and-effect rules. Best of all, you can bring in your own drawings anytime!"
			},
			{
				"title": "Gliding Around Rooms",
				"body": "• Move Around: Drag anywhere on the empty background with your finger or mouse to glide left and right across the room.\n• Smooth Fit: Rooms fit your screen height comfortably, so you never have to worry about clumsy vertical scrolling.\n• Dual-Platform Friendly: Everything works with touch controls on phones and tablets, or with a mouse and keyboard on PC."
			},
			{
				"title": "Picking Up & Interacting",
				"body": "• Move Anything: Drag and drop any unlocked character or object around the room.\n• Quick Taps: Tap on lights to switch them on, tap doors to open them, tap containers to see inside, or tap stairs to climb to upper floors.\n• The Action Menu: Press and hold on any item (or right-click on PC) to open the round action menu. From there you can flip objects, dress up characters, customize interactions, lock items, or delete them."
			},
			{
				"title": "Focus & Zoom Mode",
				"body": "• Zoom In: Tap the 'Zoom' button in the top navigation bar to zoom in close and inspect fine details, character faces, or small props.\n• Free Camera: While Focus Mode is active, you can pinch-to-zoom on touchscreens or use the mouse wheel on PC.\n• Return to Normal: Tap 'Focus' in the top bar again to smoothly return to regular side-scrolling mode."
			}
		]
	},
	{
		"id": "ugc_art",
		"title": "2. Bringing in Your Own Drawings",
		"icon": "icon_assets",
		"badge": "Custom Art",
		"sections": [
			{
				"title": "Where Your Drawings Live",
				"body": "OwnWorld keeps all your artwork inside a folder in your device's Documents area:\n\nDocuments / OwnWorld / Dollhouse / Art\n\nAny PNG, WebP, JPG, or animated GIF saved here (or inside custom subfolders you create) will show up immediately in your Assets drawer."
			},
			{
				"title": "Importing Drawings in One Tap",
				"body": "1. Open the bottom drawer by tapping the pill at the bottom of the screen.\n2. Tap the 'Import' button in the toolbar.\n3. Pick any drawing or animated GIF from your photo gallery or files. It will be added to your library instantly!"
			},
			{
				"title": "Magic Automatic Cutouts",
				"body": "• Transparent Files: Save your drawings with transparent backgrounds (PNG, WebP, or GIF).\n• Instant Hitboxes: The game automatically detects the shape of your drawing so characters and objects can be picked up and snapped accurately without any manual tracing!\n• Clean Borders: Crop transparent space closely around your drawings for the smoothest dragging and placement."
			}
		]
	},
	{
		"id": "characters_poses",
		"title": "3. Characters, Outfits & Animations",
		"icon": "icon_cast",
		"badge": "Characters",
		"sections": [
			{
				"title": "Living Characters & Outfits",
				"body": "Characters in OwnWorld are fully customizable. They can wear multiple outfits, react to what is happening around them, and have living animated expressions."
			},
			{
				"title": "Automatic Reactions",
				"body": "Your characters automatically react to different actions in the dollhouse:\n\n1. Idle: Normal standing posture.\n2. Speaking: Mouth-open talking state during dialogue.\n3. Eating: Chewing reactions when enjoying food or drinks.\n4. Sitting: Activated when placed on chairs, couches, or stools.\n5. Sleeping: Activated when placed onto beds.\n\nTip: If you do not assign a custom drawing for sitting or sleeping, the character will naturally use their default drawing."
			},
			{
				"title": "Setting Up Natural Blinking",
				"body": "Want your characters to blink naturally on their own? Open the States Studio, go to the Timeline tab, add an eyes-open frame and an eyes-closed frame, then choose 'Natural Blink'. The character will stay resting on Frame 1 and smoothly blink every few seconds!"
			},
			{
				"title": "One-Tap Animated GIFs",
				"body": "Have an animated GIF of a waving character or a flickering campfire? Open the States Studio (Tab 2) and tap 'Import Animated GIF' to load the animation with its exact timing in one step."
			},
			{
				"title": "Sprite Sheet Slicing",
				"body": "If you have a sprite strip or character grid, open Tab 3 in the States Studio. Pick your column and row counts, preview the cutting lines, and tap 'Extract All Slices' to create ready-to-play animation frames instantly."
			},
			{
				"title": "Summoning & Calling Characters Back",
				"body": "• Summon to Room: Tap any character card in the Cast drawer to place them into your current room.\n• Call Back to Tray: Press and hold down on a character's card in the Cast drawer to recall them back to the tray and clear them from the world."
			}
		]
	},
	{
		"id": "anchors_sockets",
		"title": "4. Dressing Up & Snapping Items",
		"icon": "icon_anchors",
		"badge": "Sockets",
		"sections": [
			{
				"title": "How Snapping Works",
				"body": "Items snap together smoothly using Anchor Points. When you drag a hat near a head, a sword near a hand, or a character onto a chair, the item snaps right into place with a chime!"
			},
			{
				"title": "Using the Anchor Studio",
				"body": "Long-press any character or furniture piece and select 'Anchors':\n\n1. Choose an Anchor Category from the dropdown (Hand Sockets, Head / Hats, Seat Sockets, Table Surfaces, etc.).\n2. Tap on the drawing preview where you want the connection point to be.\n3. Drag the pin to adjust its position with pixel accuracy.\n4. Tap 'Save Anchors' to finish."
			},
			{
				"title": "Common Socket Types",
				"body": "• Hand Sockets (hand_1, hand_2): For holding tools, weapons, and food.\n• Head & Face Sockets: For wearing hats, crowns, glasses, and masks.\n• Seat Sockets (seat_1): Tells characters where to sit down on chairs and sofas.\n• Character Sit Baseline (sit_point): Set this on a character's body so their hips line up perfectly with chair cushions.\n• Table Surfaces (surface_1): For placing cups, plates, and decorative props on desks and shelves.\n• Bed Anchors (bed_1): Rotates characters into a sleeping position when dropped onto beds."
			}
		]
	},
	{
		"id": "food_liquids_crafting",
		"title": "5. Food, Cooking & Interactive Props",
		"icon": "icon_food",
		"badge": "Interactive",
		"sections": [
			{
				"title": "Eating Food",
				"body": "Hold any food item near a character's face. The character will open their mouth, play chewing sounds, spray crumbs, and take bites until the snack is finished!"
			},
			{
				"title": "Custom Bite Stages (Food Studio)",
				"body": "Long-press a food item and open 'Food & Drink' to customize it. You can set up multiple progressive bite drawings (such as Whole Apple -> Half Eaten -> Apple Core) or enable 'Infinite' for endless snacking."
			},
			{
				"title": "Pouring Drinks & Faucets",
				"body": "• Realistic Sips: Bringing cups to a character's mouth tilts the cup and plays drinking sounds.\n• Cup-to-Cup Pouring: Hover a full teapot, bottle, or cup over an empty cup to tilt and pour liquid, filling the cup below!\n• Running Faucets: Mark an appliance as a 'Water Stream' to create functional kitchen sinks or garden hoses that spray running water particles."
			},
			{
				"title": "Backpacks, Boxes & Drawers",
				"body": "Objects marked as Containers can hold items inside them. Drop any prop onto a backpack, treasure chest, or drawer to pack it away. Tap the container anytime to view its storage inventory and unpack items back into the room."
			},
			{
				"title": "Combining Ingredients (Recipe Creator)",
				"body": "Open the Main Menu and select 'Visual Recipe Creator' to craft new combinations (like Dough + Tomato = Pizza). In your room, simply drop Ingredient A onto Ingredient B to trigger a magic merge poof!"
			}
		]
	},
	{
		"id": "logic_rules",
		"title": "6. Story Magic & Interactive Puzzles",
		"icon": "icon_logic",
		"badge": "Storytelling",
		"sections": [
			{
				"title": "Make Things Happen Without Coding",
				"body": "The Logic Rule Editor lets you build interactive story moments, secret passages, and fun surprises without writing a single line of code!"
			},
			{
				"title": "The Simple 3-Step Formula",
				"body": "Every rule is built using three clear choices:\n\n1. When This Happens:\n   Choose the trigger (When Tapped, When an Item is Dropped Onto It, When Grabbed, or When Released).\n   Optional: Set an item name filter so it only works with a specific item (like 'Magic Key').\n\n2. Apply Action To:\n   Choose who reacts (This Item, The Dropped Item, All Characters in Room, or the Room Environment).\n\n3. Then Execute Action:\n   • Speech Bubble: Make characters say custom dialogue lines.\n   • Floating Emoji: Spray hearts, stars, musical notes, or question marks.\n   • Play Animation or Change Clothes: Switch outfits or start dance animations.\n   • Shift Atmosphere: Change the room mood to Sunset or start falling rain.\n   • Spawn a Reward: Conjure an item from your art library into the room.\n   • Teleport: Transition to another room in your world."
			}
		]
	},
	{
		"id": "rooms_elevators_map",
		"title": "7. Rooms, Floors & Elevators",
		"icon": "icon_room",
		"badge": "Worldbuilding",
		"sections": [
			{
				"title": "The World Map & Building Settings",
				"body": "Open the World Map from the top bar to view your universe. Switch to Edit Mode and tap the gear on any building pin to open Building Settings. Here you can add new floors, name rooms, assign floor labels (1F, 2F, B1), and pick custom building artwork."
			},
			{
				"title": "Stairs & Elevators",
				"body": "• Auto-Climbing Stairs: Tap stairs (or drop a character on them) to climb directly to the floor above.\n• Keypad Elevators: Step into an elevator to open a floor keypad. Select any registered floor in the building to ride the elevator with all passengers inside!"
			},
			{
				"title": "Multi-Screen Room Expansion",
				"body": "• Screen Slices: Each room slice matches the exact width of your screen.\n• Long Rooms: Tap '+ Add Room Slice' in the Room Studio to expand your room up to 10 screens wide for seamless panoramic side-scrolling.\n• Indoor vs. Outdoor: Set individual slices as Outdoors so weather effects (like rain, snow, or falling leaves) only fall in open areas like balconies or gardens."
			}
		]
	},
	{
		"id": "lore_journals_factions",
		"title": "8. Character Profiles & Story Chronicles",
		"icon": "icon_lore",
		"badge": "Narrative",
		"sections": [
			{
				"title": "Character Profiles",
				"body": "Long-press any character and choose 'Profile' to open their 3-tab Lore Card:\n• Tab 1 (Profile): Name, Pronouns, Role/Title, Life Status, custom portrait drawing, and unlimited customizable traits.\n• Tab 2 (Family & Feelings): Two-way family relationships (Parents, Children, Siblings, Partners) and directional feelings (Best Friends, Rivals, Secret Crushes, Mentors).\n• Tab 3 (Backstory): A notebook for writing backstories, personality quirks, and story notes."
			},
			{
				"title": "World Journal & Guilds",
				"body": "Open the World Journal from the Main Menu to chronicle the history of your universe:\n• Story Chronicles: Record dated eras, memorable events, participating characters, and linked rooms.\n• Guilds & Factions: Create kingdoms, clubs, schools, or alliances with custom badge colors, mottos, headquarters, appointed leaders, and ranked member rosters."
			}
		]
	},
	{
		"id": "universes_packs",
		"title": "9. Story Worlds & Sharing Packs",
		"icon": "icon_universe",
		"badge": "Sharing",
		"sections": [
			{
				"title": "Story Universes",
				"body": "Universes are completely separate creative worlds. Each universe has its own independent rooms, Cast rosters, recipes, World Maps, and Journal chronicles. Switch between stories anytime in the Universe Hub."
			},
			{
				"title": "Exporting Story Packs",
				"body": "Want to share your creation? Tap 'Export Active (.ownpack)' in the Universe Hub to bundle your entire world into a single shareable package saved to:\n\nDocuments / OwnWorld / Dollhouse / Exports"
			},
			{
				"title": "Importing Story Packs",
				"body": "Download an .ownpack file created by a friend and tap 'Import (.ownpack)' in the Universe Hub to load and explore their world in one tap!"
			}
		]
	},
	{
		"id": "theming_settings",
		"title": "10. Themes, Comfort & Motion Controls",
		"icon": "icon_palette",
		"badge": "Customization",
		"sections": [
			{
				"title": "Dynamic Motion & Juice Toggles",
				"body": "Prefer playful bounces, or a calm, classic paper-doll feel? Open Settings -> Motion FX & Dynamic Juice:\n• Master Juice Toggle: Turn all spring bounces, squashes, and spawn physics on or off.\n• Idle Breathing & Levitation: Toggle or adjust the intensity of gentle breathing and floating effects.\n• Tilting Physics: Toggle cup-pouring and sipping rotations.\n• Squash & Stretch: Toggle chewing and landing bounces."
			},
			{
				"title": "Palette & Font Studio",
				"body": "Customize the visual style of your entire game! Choose from curated themes (Strawberry Milk, Matcha Latte, Lavender Mist, Midnight Velvet) or pick your own custom colors. You can also drop any .ttf or .otf font file into Documents/OwnWorld/Dollhouse/Font to restyle all in-game text."
			},
			{
				"title": "Touch & Comfort Settings",
				"body": "• Interface Scale: Adjust UI sizes to fit phones, tablets, or monitors comfortably.\n• Touch Grab Padding: Increases the grab area around small props so they are easy to pick up on mobile screens.\n• Hold Duration: Customize how long you need to hold down before the Magic Wheel opens or characters recall to the Cast drawer."
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


func _is_mobile() -> bool:
	return ThemeEngine.is_mobile_platform()


func _connect_system_signals() -> void:
	if not ThemeService.theme_changed.is_connected(_on_theme_changed):
		ThemeService.theme_changed.connect(_on_theme_changed)
	var tree: SceneTree = get_tree()
	if tree and tree.root and not tree.root.size_changed.is_connected(_update_responsive_layout):
		tree.root.size_changed.connect(_update_responsive_layout)


func _update_responsive_layout() -> void:
	if not is_instance_valid(root_panel): return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280.0, 720.0)
	var is_mob: bool = _is_mobile()

	var target_w: float = clampf(vp_size.x * 0.94, 320.0, MAX_PANEL_WIDTH)
	var target_h: float = clampf(vp_size.y * (0.92 if is_mob else 0.88), 300.0, MAX_PANEL_HEIGHT)
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
	var is_mob: bool = _is_mobile()

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
	main_vbox.add_theme_constant_override("separation", 6)
	root_panel.add_child(main_vbox)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	header_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(header_hbox)

	header_title_lbl = Label.new()
	header_title_lbl.text = "OwnWorld Creator Handbook & Guide"
	header_title_lbl.theme_type_variation = "HeaderLabel"
	header_title_lbl.add_theme_font_size_override("font_size", 14 if is_mob else 12)
	header_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header_title_lbl)

	search_input = LineEdit.new()
	search_input.placeholder_text = "Search topics (drawings, outfits, food, rules)..."
	search_input.custom_minimum_size = Vector2(260.0 if is_mob else 200.0, 32.0 if is_mob else 26.0)
	search_input.text_changed.connect(_on_search_query_changed)
	header_hbox.add_child(search_input)

	btn_close = Button.new()
	btn_close.custom_minimum_size = Vector2(28.0 if is_mob else 22.0, 28.0 if is_mob else 22.0)
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.add_theme_constant_override("icon_max_width", 12)
	var close_icon: Texture2D = ThemeService.get_icon("icon_close")
	if close_icon: btn_close.icon = close_icon
	else: btn_close.text = "X"
	btn_close.pressed.connect(close_handbook)
	header_hbox.add_child(btn_close)

	main_vbox.add_child(HSeparator.new())

	var split_hbox: HBoxContainer = HBoxContainer.new()
	split_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(split_hbox)

	var left_scroll: ScrollContainer = ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(250.0 if is_mob else 210.0, 0.0)
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_scroll.follow_focus = false
	split_hbox.add_child(left_scroll)

	topics_list_vbox = VBoxContainer.new()
	topics_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topics_list_vbox.add_theme_constant_override("separation", 4)
	left_scroll.add_child(topics_list_vbox)

	split_hbox.add_child(VSeparator.new())

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
	content_vbox.add_theme_constant_override("separation", 10)
	content_scroll.add_child(content_vbox)


func _render_topics_sidebar() -> void:
	if not topics_list_vbox: return
	for child: Node in topics_list_vbox.get_children(): child.queue_free()

	var is_mob: bool = _is_mobile()
	var c_accent: Color = ThemeService.get_color("accent_primary", "#ec4899")
	var rad: int = ThemeService.get_corner_radius()

	for i: int in range(tutorial_chapters.size()):
		var chapter: Dictionary = tutorial_chapters[i]
		var c_title: String = str(chapter["title"])

		if not active_filter_query.is_empty():
			var matches_query: bool = active_filter_query in c_title.to_lower()
			if not matches_query:
				for s: Variant in chapter.get("sections", []):
					if s is Dictionary and (active_filter_query in str(s.get("title", "")).to_lower() or active_filter_query in str(s.get("body", "")).to_lower()):
						matches_query = true
						break
			if not matches_query: continue

		var is_active: bool = (i == active_topic_index)
		var btn: Button = Button.new()
		btn.text = " " + c_title
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0.0, 36.0 if is_mob else 30.0)
		btn.focus_mode = Control.FOCUS_NONE
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 11 if is_mob else 10)
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

		var target_idx: int = i
		btn.pressed.connect(func() -> void:
			active_topic_index = target_idx
			_render_topics_sidebar()
			_render_active_topic_content()
		)
		topics_list_vbox.add_child(btn)


func _render_active_topic_content() -> void:
	if not content_vbox: return
	for child: Node in content_vbox.get_children(): child.queue_free()

	if active_topic_index < 0 or active_topic_index >= tutorial_chapters.size():
		return

	var is_mob: bool = _is_mobile()
	var chapter: Dictionary = tutorial_chapters[active_topic_index]
	var c_title: String = str(chapter["title"])
	var c_badge: String = str(chapter.get("badge", ""))
	var sections: Array = chapter.get("sections", [])

	var title_card: PanelContainer = PanelContainer.new()
	title_card.theme_type_variation = "SubPanel"
	content_vbox.add_child(title_card)

	var title_hbox: HBoxContainer = HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 10)
	title_card.add_child(title_hbox)

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(30.0 if is_mob else 24.0, 30.0 if is_mob else 24.0)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_tex: Texture2D = ThemeService.get_icon(str(chapter.get("icon", "icon_room")))
	if icon_tex: icon_rect.texture = icon_tex
	title_hbox.add_child(icon_rect)

	var title_lbl: Label = Label.new()
	title_lbl.text = c_title
	title_lbl.theme_type_variation = "HeaderLabel"
	title_lbl.add_theme_font_size_override("font_size", 14 if is_mob else 12)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(title_lbl)

	var badge_lbl: Label = Label.new()
	badge_lbl.text = c_badge.to_upper()
	badge_lbl.theme_type_variation = "HintLabel"
	badge_lbl.add_theme_font_size_override("font_size", 10 if is_mob else 9)
	title_hbox.add_child(badge_lbl)

	for sec_var: Variant in sections:
		if not sec_var is Dictionary: continue
		var sec: Dictionary = sec_var as Dictionary
		var s_title: String = str(sec.get("title", ""))
		var s_body: String = str(sec.get("body", ""))

		var card: PanelContainer = PanelContainer.new()
		card.theme_type_variation = "SubPanel"
		content_vbox.add_child(card)

		var card_vbox: VBoxContainer = VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 4)
		card.add_child(card_vbox)

		if not s_title.is_empty():
			var st_lbl: Label = Label.new()
			st_lbl.text = s_title
			st_lbl.theme_type_variation = "HeaderLabel"
			st_lbl.add_theme_font_size_override("font_size", 12 if is_mob else 11)
			card_vbox.add_child(st_lbl)

		var sb_lbl: Label = Label.new()
		sb_lbl.text = s_body
		sb_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sb_lbl.add_theme_font_size_override("font_size", 11 if is_mob else 10)
		sb_lbl.add_theme_color_override("font_color", ThemeService.get_color("text_primary", "#6c2e3f"))
		card_vbox.add_child(sb_lbl)

	var nav_row: HBoxContainer = HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 10)
	content_vbox.add_child(nav_row)

	var btn_h: float = 34.0 if is_mob else 28.0

	if active_topic_index > 0:
		var btn_prev: Button = Button.new()
		btn_prev.text = "< Previous Chapter"
		btn_prev.custom_minimum_size = Vector2(0.0, btn_h)
		btn_prev.focus_mode = Control.FOCUS_NONE
		btn_prev.add_theme_font_size_override("font_size", 11 if is_mob else 10)
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
		btn_next.text = "Next Chapter >"
		btn_next.custom_minimum_size = Vector2(0.0, btn_h)
		btn_next.focus_mode = Control.FOCUS_NONE
		btn_next.add_theme_font_size_override("font_size", 11 if is_mob else 10)
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

	if header_title_lbl: header_title_lbl.add_theme_color_override("font_color", c_accent)
	var close_icon: Texture2D = ThemeService.get_icon("icon_close")
	if close_icon and btn_close: btn_close.icon = close_icon


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		close_handbook()
