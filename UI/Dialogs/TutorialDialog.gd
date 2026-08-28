# ============================================================
# File: res://UI/Dialogs/TutorialDialog.gd
# ============================================================

# ==============================================================================
# OWNWORLD - IN-GAME CREATOR HANDBOOK (LANDSCAPE MASTER-DETAIL DUAL-OS)
# File: res://UI/Dialogs/TutorialDialog.gd
# Base Class: CanvasLayer (class_name TutorialDialog)
#
# Responsibility: Comprehensive beginner-proof player guide and creator handbook.
# 10 clear, easy-to-read chapters covering controls, custom drawings,
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

# Handbook Chapters Data (Beginner-Friendly Content)
var tutorial_chapters: Array[Dictionary] = [
	{
		"id": "quickstart",
		"title": "1. The Basics: How to Move & Play",
		"icon": "icon_play",
		"badge": "Basics",
		"sections": [
			{
				"title": "What is OwnWorld: Dollhouse?",
				"body": "OwnWorld is an interactive digital toy and story sandbox. Just like playing with a physical dollhouse or paper dolls, you can pick up characters, decorate rooms, dress people up, cook meals, and invent your own stories. Best of all, you can draw your own characters and furniture and bring them into the game anytime!"
			},
			{
				"title": "Looking Around Your Room",
				"body": "• Slide Left and Right: Touch or click any empty background area and drag left or right to glide across the room.\n• Comfortable View: Rooms fit your screen height naturally, so you only need to slide side-to-side to explore.\n• Works on Any Device: You can play comfortably using touch on phones and tablets, or using a mouse and keyboard on PC."
			},
			{
				"title": "Picking Up & Interacting with Items",
				"body": "• Move Anything: Tap and hold any character or object, drag them wherever you want, and let go to drop them.\n• Quick Taps: Tap a lamp to turn the light on or off. Tap a door to open or close it. Tap a backpack or chest to see what is stored inside. Tap stairs to climb up to the next floor.\n• The Action Menu (Magic Wheel): Press and hold down on any character or object for half a second (or right-click with a mouse on PC). A round action menu will appear with tools to flip the item, change outfits, customize interactions, lock it in place, or delete it."
			},
			{
				"title": "Zooming In Close (Focus Mode)",
				"body": "• Zoom In: Tap the 'Zoom' button in the top navigation bar to unlock camera zoom.\n• Inspect Details: Pinch with two fingers on a touchscreen (or roll your mouse wheel on PC) to zoom in close on faces, small props, or fine drawings.\n• Return to Normal: Tap 'Focus' in the top bar again to lock the camera smoothly back to normal room view."
			}
		]
	},
	{
		"id": "ugc_art",
		"title": "2. Adding Your Own Drawings",
		"icon": "icon_assets",
		"badge": "Custom Art",
		"sections": [
			{
				"title": "You Can Draw Anything!",
				"body": "You do not need to be a professional artist to add things into the game! You can draw characters, pets, hats, food, chairs, or castles using your favorite drawing app on your phone, tablet, or computer (like Procreate, IbisPaint, Krita, Photoshop, or MS Paint)."
			},
			{
				"title": "Saving with a Transparent Background",
				"body": "• Use PNG or WebP: When saving or exporting your drawing, choose PNG or WebP format with a transparent background.\n• Magic Automatic Cutouts: You never need to trace manual collision outlines! The game automatically detects the shape of your drawing and turns it into a solid physical object you can pick up and hold.\n• Crop Closely: For the smoothest snapping and dragging, crop empty transparent space closely around your drawing."
			},
			{
				"title": "How to Import Drawings into the Game",
				"body": "1. Open the bottom drawer by tapping the small tab at the bottom of the screen.\n2. Make sure you are on the 'Assets' tab and tap the 'Import' button.\n3. Select your drawing from your device's photo gallery or files.\n4. Tap your drawing card in the drawer to spawn it into your room immediately!"
			},
			{
				"title": "Where Files Live on Your Device",
				"body": "All drawings are kept inside your device's Documents area:\n\nDocuments / OwnWorld / Dollhouse / Art\n\nYou can also create custom subfolders here (like 'Animals', 'Food', or 'Hats') to keep your drawing collection organized."
			}
		]
	},
	{
		"id": "characters_poses",
		"title": "3. Playing with Characters",
		"icon": "icon_cast",
		"badge": "Characters",
		"sections": [
			{
				"title": "Finding & Summoning Characters",
				"body": "• The Cast Drawer: Open the bottom drawer and tap the 'Cast' tab to see all your characters.\n• Summon to Room: Tap any character card to place them into your active room.\n• Call Back Home: Press and hold down on a character card for half a second to call that character back into the drawer and remove them from the world."
			},
			{
				"title": "Automatic Living Reactions",
				"body": "Characters automatically react to what you do with them:\n\n1. Standing (Idle): Their regular standing pose.\n2. Talking (Speaking): Mouth opens when they speak dialogue lines.\n3. Eating: Chewing reactions when enjoying food or drinks.\n4. Sitting: Activated when placed on chairs, couches, or stools.\n5. Sleeping: Activated when placed onto beds.\n\nTip: If you have only made a single drawing for a character, they will naturally use that drawing for all poses!"
			},
			{
				"title": "Setting Up Natural Blinking",
				"body": "Want your character to blink naturally while standing around? Open the States Studio, switch to the 'Frames & GIF Timeline' tab, add an eyes-open drawing (Frame 1) and an eyes-closed drawing (Frame 2), then set Playback Mode to 'Natural Blink'. Your character will now stay with open eyes and naturally blink every few seconds!"
			},
			{
				"title": "One-Tap Animated GIFs",
				"body": "Have an animated GIF of a dancing pet or a waving character? Open the States Studio (Tab 2) and tap 'Import Animated GIF'. The game will import all frames and play them at their exact original speed!"
			},
			{
				"title": "Sprite Sheet Slicing",
				"body": "If you have a sprite strip or character grid image (like a 4-frame walk cycle on one picture), open Tab 3 in the States Studio. Pick your column and row counts, preview the cutting lines, and tap 'Extract All Slices' to turn them into an animation instantly."
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
				"body": "Items connect together smoothly using Anchor Points. When you drag a hat near a head, a sword near a hand, or a character onto a chair, the item snaps into place with a chime sound!"
			},
			{
				"title": "Holding Items in Hands",
				"body": "Drag any small prop (like an apple, a wand, or a cup) over a character's hand. The character will automatically grab the item and hold onto it as you move them around."
			},
			{
				"title": "Hats, Glasses & Accessories",
				"body": "• Hats & Crowns: Drop onto a character's head to wear them.\n• Glasses & Masks: Drop over a character's face.\n• Scarves & Necklaces: Drop near the neck.\n• Wings & Backpacks: Drop over a character's back."
			},
			{
				"title": "Sitting on Chairs & Sleeping in Beds",
				"body": "• To Sit: Drag a character and drop them onto a chair or sofa. They will automatically sit down.\n• To Sleep: Drag a character onto a bed. They will automatically lie down in a horizontal sleeping position."
			},
			{
				"title": "Using the Anchor Studio",
				"body": "Want to fine-tune where a hat sits or where a hand grips? Long-press any character or furniture piece and tap 'Anchors':\n\n1. Pick a category from the dropdown (Hand, Head, Seat, Table Surface, Bed, etc.).\n2. Tap directly on the drawing preview where you want the connection point to be.\n3. Drag the pin with your finger or mouse to adjust its exact location.\n4. Tap 'Save Anchors' when done!"
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
				"title": "Feeding Characters",
				"body": "Drag any food item up to a character's mouth. The character will open their mouth, play chewing sounds, spray crumbs, and take bites until the snack is finished!"
			},
			{
				"title": "Custom Bite Stages (Food Studio)",
				"body": "Long-press a food item and open 'Food & Drink' to customize it. You can set up multiple progressive bite drawings (such as Whole Pizza -> Slice Taken -> Crust -> Empty Plate) or enable 'Infinite' for endless snacking."
			},
			{
				"title": "Pouring Drinks & Using Faucets",
				"body": "• Realistic Sips: Bringing a cup to a character's mouth tilts the cup realistically and plays sipping sounds.\n• Cup-to-Cup Pouring: Pick up a full teapot, bottle, or cup and hover it directly above an empty cup. It will tilt and pour liquid, filling the cup below!\n• Sinks & Faucets: Tap any running faucet to turn on flowing water particles. Hold an empty cup under the water stream to fill it up!"
			},
			{
				"title": "Backpacks, Boxes & Drawers",
				"body": "Items marked as Containers can store props inside them. Drop any item onto a backpack, treasure chest, or drawer to pack it away. Tap the container anytime to view its storage inventory and unpack items back into the room."
			},
			{
				"title": "Combining Ingredients (Recipe Creator)",
				"body": "Open the Main Menu and tap 'Visual Recipe Creator' to make cooking recipes (like Dough + Tomato = Pizza). In your room, simply drop Ingredient A onto Ingredient B to trigger a magic merge poof!"
			}
		]
	},
	{
		"id": "logic_rules",
		"title": "6. Story Magic: Make Things Happen",
		"icon": "icon_logic",
		"badge": "Story Magic",
		"sections": [
			{
				"title": "What is Story Magic?",
				"body": "The Logic Rule Editor lets you make objects and characters interact automatically without writing a single line of code! You can create working light switches, talking characters, secret doors, and puzzle rewards."
			},
			{
				"title": "The Simple 3-Step Rule Maker",
				"body": "Every rule is built using three clear choices:\n\n1. When This Happens (Trigger):\n   Pick what starts the action (When Tapped, When an Item is Dropped Onto It, When Picked Up, or When Released).\n   Optional: Set an item name filter so it only works with a specific item (like 'Gold Key').\n\n2. Apply Action To (Target):\n   Choose who reacts (This Item, The Dropped Item, All Characters in the Room, or the Room Environment).\n\n3. Then Execute Action (Effect):\n   • Speech Bubble: Make a character say custom dialogue lines.\n   • Floating Emoji: Spray hearts, stars, music notes, or questions.\n   • Play Animation / Change Clothes: Switch outfits or start dance moves.\n   • Shift Atmosphere: Change the room mood to Sunset or start falling rain.\n   • Spawn a Reward: Conjure an item from your art library into the room.\n   • Teleport: Travel to another room in your world."
			},
			{
				"title": "3 Fun Story Examples to Try",
				"body": "• Example 1 (Light Switch): Set a lamp to turn its light on or off when tapped.\n• Example 2 (Polite Character): Set a character to say 'Thank you!' and spray hearts whenever they are handed a cookie.\n• Example 3 (Treasure Chest): Set a treasure chest to spawn gold coins when a key is dropped onto it."
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
				"title": "The World Map",
				"body": "Tap 'Map' in the top bar to view your universe map. Tap any building pin to travel straight to that location. Switch the map to 'Edit' mode to move building pins around, add new buildings, or customize building settings."
			},
			{
				"title": "Stairs & Elevators",
				"body": "• Auto-Climbing Stairs: Tap stairs (or drop a character on them) to climb directly to the floor above!\n• Keypad Elevators: Drop characters inside an elevator. A floor keypad will pop up. Tap any floor button (like 1F, 2F, or Rooftop) and the elevator will close its doors and take everyone to that floor!"
			},
			{
				"title": "Multi-Screen Wide Rooms",
				"body": "• Screen Slices: Each room slice matches the exact width of your device screen.\n• Extra Wide Rooms: In the Room Studio, tap '+ Add Room Slice' to expand your room up to 10 screens wide for seamless side-to-side panoramic scrolling.\n• Outdoor Balconies: Set individual room slices to 'Outdoors' so weather effects (like rain, snow, or falling leaves) fall only on outdoor balconies while keeping indoor rooms dry!"
			}
		]
	},
	{
		"id": "lore_journals_factions",
		"title": "8. Profiles, Family Trees & Lore",
		"icon": "icon_lore",
		"badge": "Narrative",
		"sections": [
			{
				"title": "Character Lore Cards",
				"body": "Long-press any character and tap 'Profile' to open their 3-tab Lore Card:\n• Tab 1 (Profile): Name, Pronouns, Role/Title (like Baker or Knight), Life Status, custom portrait picture, and custom traits (like Birthday or Favorite Color).\n• Tab 2 (Family & Feelings): Two-way family connections (Parents, Children, Siblings, Partners) and feelings (Best Friends, Rivals, Secret Crushes, Mentors). When you set one character as a sibling to another, the game links them both ways automatically!\n• Tab 3 (Backstory): A notebook where you can write backstories, secrets, and world notes."
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
				"title": "Dynamic Motion & Juice Controls",
				"body": "• Love Bouncy Animations? The game includes lively squashes, bounces, and breathing effects when picking up and dropping items.\n• Prefer a Calm Paper-Doll Look? Open Settings -> Motion FX & Dynamic Juice and switch the Master Juice toggle off to disable all bouncy animations."
			},
			{
				"title": "Palette & Font Studio",
				"body": "Customize the visual style of your entire game! Choose from curated themes (Strawberry Milk, Matcha Latte, Lavender Mist, Peach Sorbet, Midnight Velvet) or pick your own custom colors. You can also drop your own .ttf or .otf font files into Documents/OwnWorld/Dollhouse/Font to change in-game text fonts."
			},
			{
				"title": "Touch & Comfort Settings",
				"body": "• Interface Scale: Adjust UI sizes to fit phones, tablets, or monitors comfortably.\n• Touch Grab Padding: Increases the grab area around small props so they are easy to pick up on mobile touchscreens.\n• Hold Duration: Customize how long you need to hold down before the Magic Wheel opens or characters recall to the Cast drawer."
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
