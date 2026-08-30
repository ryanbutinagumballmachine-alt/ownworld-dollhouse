# ==============================================================================
# OWNWORLD — IN-GAME CREATOR HANDBOOK (HYPER OPTIMIZED & LAYER 120)
# File: res://UI/Dialogs/TutorialDialog.gd
# Base Class: HyperUIDialog
#
# Responsibility: Master interactive creator guide. Provides searchable chapters
# covering controls, drawer storage, UGC art, animation pipelines, sockets,
# physics, logic scripting, and in-app updates.
# ==============================================================================

class_name TutorialDialog
extends HyperUIDialog

var header_title_lbl: Label = null
var search_input: LineEdit = null
var btn_close: Button = null

var topics_list_vbox: VBoxContainer = null
var content_scroll: ScrollContainer = null
var content_vbox: VBoxContainer = null

var active_topic_index: int = 0
var active_filter_query: String = ""

# Master Handbook Chapters Data (14 Comprehensive Systems)
var tutorial_chapters: Array[Dictionary] = [
	{
		"id": "quickstart",
		"title": "1. Quickstart, Controls & Navigation",
		"icon": "icon_play",
		"badge": "Basics",
		"sections": [
			{
				"title": "What is OwnWorld: Dollhouse?",
				"body": "OwnWorld is an interactive digital playset and storytelling sandbox. Just like playing with a physical dollhouse or paper dolls, you can pick up characters, decorate rooms, dress people up, cook meals, and invent your own adventures. Best of all, you can draw your own characters and furniture and bring them into the game anytime!"
			},
			{
				"title": "Looking Around Your Room",
				"body": "• Slide Left and Right: Touch or click any empty background area and drag left or right to glide smoothly across the room.\n• Comfortable View: Rooms fit your screen height naturally, so you only need to slide side-to-side to explore.\n• Dual-Platform Friendly: Everything works with touch controls on phones and tablets, or with a mouse and keyboard on PC."
			},
			{
				"title": "Picking Up & Moving Objects",
				"body": "• Move Anything: Tap and hold any character or object, drag them wherever you want, and let go to drop them.\n• Quick Taps: Tap a lamp to turn the light on or off. Tap a door to open or close it. Tap a backpack or chest to see what is stored inside. Tap stairs to climb up to the next floor.\n• The Action Menu (Magic Wheel): Press and hold down on any character or object for half a second (or right-click with a mouse on PC). A round action menu will appear with tools to flip the item, change outfits, customize interactions, lock it in place, or delete it."
			},
			{
				"title": "Focus & Zoom Mode",
				"body": "• Zoom In: Tap the 'Zoom' button in the top navigation bar to unlock camera zoom.\n• Inspect Details: Pinch with two fingers on a touchscreen (or roll your mouse wheel on PC) to zoom in close on faces, small props, or fine drawings.\n• Return to Normal: Tap 'Focus' in the top bar again to lock the camera smoothly back to normal room view."
			},
			{
				"title": "The Top Navigation Bar",
				"body": "• Menu: Opens the Main Menu to access settings, tutorials, updates, and universe options.\n• Guide: Opens this Creator Handbook anytime.\n• Floors: Quick dropdown to switch between floors in your active building.\n• Zoom: Toggles Focus Mode for close-up camera inspection.\n• Map: Opens the World Map to travel between buildings.\n• Room: Opens the Room Studio to customize wallpapers and floor heights.\n• Undo: Step backward through your recent actions (you can also press Ctrl+Z on PC)."
			}
		]
	},
	{
		"id": "drawer_tray",
		"title": "2. The Drawer Tray, Folders & Tagging",
		"icon": "icon_folder",
		"badge": "Storage",
		"sections": [
			{
				"title": "Opening the Drawer Tray",
				"body": "Tap the small tab button at the bottom of your screen to slide open the master Drawer Tray. This is where all your drawings, saved furniture, props, and story characters live."
			},
			{
				"title": "The 4 Drawer Tabs",
				"body": "1. Assets: Contains all raw drawings and animated GIFs you have imported into the game.\n2. Props: Saved portable items, tools, food dishes, and accessories.\n3. Furniture: Saved chairs, tables, beds, lights, stairs, and decorative furniture pieces.\n4. Cast: Your active character roster where you can summon characters into rooms or call them back home."
			},
			{
				"title": "Creating & Navigating Folders",
				"body": "• Create Folders: Tap '+ Folder' in the drawer toolbar to create custom categories (like 'Animals', 'Food', 'Outfits', or 'Kitchen').\n• Breadcrumbs Navigation: The path bar shows your current location. Tap any folder name in the bar to jump back, or tap 'Up' to step out one level."
			},
			{
				"title": "Searching & Category Tags",
				"body": "• Search Bar: Type any keyword into the search box to find drawings, props, or characters instantly.\n• Tag Filter Pills: Tap tag pills (like #props, #food, #furniture, #characters, or #magic) to filter items quickly. You can create custom hashtags in the item organizer!"
			},
			{
				"title": "Batch Selection & Organizing",
				"body": "• Batch Select: Tap 'Select' in the drawer toolbar to turn on multi-item selection.\n• Organize Multiple Items: Check the boxes on multiple drawings or props, then tap 'Organize' to move them all to a new folder or assign tags together in one step!\n• Batch Delete: Select multiple items and tap 'Delete Batch' to clean up your library quickly."
			}
		]
	},
	{
		"id": "ugc_art",
		"title": "3. Bringing in Your Own Drawings",
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
				"body": "1. Open the bottom drawer by tapping the tab at the bottom of the screen.\n2. Make sure you are on the 'Assets' tab and tap the 'Import' button.\n3. Select your drawing from your device's photo gallery or files.\n4. Tap your drawing card in the drawer to spawn it into your room immediately!"
			},
			{
				"title": "Where Files Live on Your Device",
				"body": "All drawings are kept inside your device's Documents area:\n\nDocuments / OwnWorld / Dollhouse / Art\n\nYou can also create custom subfolders here on your computer or file manager to keep your drawing collection organized."
			}
		]
	},
	{
		"id": "characters_cast",
		"title": "4. Playing with Characters & The Cast Tray",
		"icon": "icon_cast",
		"badge": "Characters",
		"sections": [
			{
				"title": "Finding & Summoning Characters",
				"body": "• The Cast Drawer: Open the bottom drawer and tap the 'Cast' tab to see all your characters.\n• Summon to Room: Tap any character card to place them into your active room.\n• Call Back Home (Universal Hold): Press and hold down on a character card for half a second to call that character back into the drawer and remove them from the world."
			},
			{
				"title": "Automatic Living Reactions",
				"body": "Characters automatically react to what you do with them:\n\n1. Standing (Idle): Their regular standing pose.\n2. Talking (Speaking): Mouth opens when they speak dialogue lines.\n3. Eating: Chewing reactions when enjoying food or drinks.\n4. Sitting: Activated when placed on chairs, couches, or stools.\n5. Sleeping: Activated when placed onto beds.\n\nTip: If you have only made a single drawing for a character, they will naturally use that drawing for all poses!"
			},
			{
				"title": "Duplicating & Managing Characters",
				"body": "• Duplicate: Tap the copy icon on any character card in the Cast drawer to clone them.\n• Return to Drawer: Long-press any character in the room and select 'Return to Cast' on the Magic Wheel to pack them safely back into your tray."
			}
		]
	},
	{
		"id": "states_animations",
		"title": "5. Outfits, Animations & Natural Blinking",
		"icon": "icon_states",
		"badge": "Animation",
		"sections": [
			{
				"title": "Multiple Outfits (Wardrobe Forms)",
				"body": "Want your character to change clothes? Long-press the character, choose 'States & Anims', and tap '+ Form'. Type a form name (like 'Pajamas', 'Armor', or 'Party Outfit') and pick a new drawing. You can switch between outfits anytime!"
			},
			{
				"title": "Setting Up Natural Blinking",
				"body": "Want your character to blink naturally while standing around?\n\n1. Open the States Studio and switch to the 'Frames & GIF Timeline' tab.\n2. Add an eyes-open drawing (Frame 1) and an eyes-closed drawing (Frame 2).\n3. Set Playback Mode to 'Natural Blink'.\n4. Your character will now stay with open eyes and naturally blink every few seconds!"
			},
			{
				"title": "One-Tap Animated GIFs",
				"body": "Have an animated GIF of a dancing pet or a waving character? Open the States Studio (Tab 2) and tap 'Import Animated GIF'. The game will import all frames and play them at their exact original speed!"
			},
			{
				"title": "Sprite Sheet Grid Slicing",
				"body": "If you have a sprite strip or character grid image (like a 4-frame walk cycle on one picture), open Tab 3 in the States Studio. Pick your column and row counts, preview the cutting lines, and tap 'Extract All Slices' to turn them into a playable animation instantly."
			},
			{
				"title": "Testing on the Mannequin",
				"body": "Use the Interactive Test Mannequin station at the top of Tab 1 to preview and test your character's blinking, sitting, sleeping, and talking animations in real time."
			}
		]
	},
	{
		"id": "anchors_sockets",
		"title": "6. Dressing Up & The Anchor Studio",
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
			},
			{
				"title": "Sit Baseline (Hip Alignment)",
				"body": "Place a 'Sit Baseline' (sit_point) anchor near the bottom of a character's body so their hips and legs line up perfectly when sitting on chair cushions."
			}
		]
	},
	{
		"id": "food_liquids_containers",
		"title": "7. Food, Drinks, Sinks & Containers",
		"icon": "icon_food",
		"badge": "Interactive",
		"sections": [
			{
				"title": "Feeding Characters",
				"body": "Drag any food item up to a character's mouth. The character will open their mouth, play chewing sounds, spray yellow crumb particles, and take bites until the snack is finished!"
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
			}
		]
	},
	{
		"id": "crafting_recipes",
		"title": "8. Cooking Recipes & Item Merging",
		"icon": "icon_recipes",
		"badge": "Crafting",
		"sections": [
			{
				"title": "Combining Ingredients in the Room",
				"body": "You can combine items directly in your room! Drop Ingredient A on top of Ingredient B. If there is a matching recipe, a magic merge poof will appear and transform both items into a brand-new crafted object!"
			},
			{
				"title": "The Visual Recipe Creator",
				"body": "Open the Main Menu and select 'Visual Recipe Creator' to build new recipes:\n\n1. Select Ingredient A from your art library.\n2. Select Ingredient B from your art library.\n3. Pick what item will be created as the result.\n4. Type a name for your new creation (like 'Hot Pizza' or 'Magic Elixir') and tap 'Register & Save Recipe'!"
			},
			{
				"title": "Fun Recipe Ideas to Try",
				"body": "• Bakery: Dough + Tomato = Pizza; Flour + Sugar = Birthday Cake.\n• Alchemy: Purple Crystal + Water Bottle = Magic Potion.\n• Crafting: Stick + Iron Ingot = Knight Sword."
			}
		]
	},
	{
		"id": "lighting_glow",
		"title": "9. Lighting & 2D Glow Effects Studio",
		"icon": "icon_lighting",
		"badge": "Visuals",
		"sections": [
			{
				"title": "The Lighting Studio",
				"body": "Long-press any lamp, campfire, magic wand, or glowing crystal and select 'Lighting' to customize its 2D glow effects."
			},
			{
				"title": "Glow Styles",
				"body": "• Silhouette Contour: Draws a glowing outline aura around the exact transparent shape of your drawing.\n• Ambient Room Glow: Fills the surrounding space with soft radial room light.\n• Light Anchors: Emits light points directly from placed light pins."
			},
			{
				"title": "Light Customization Controls",
				"body": "• Brightness: Adjust how strongly the light glows.\n• Glow Radius: Expand or shrink the reach of the light.\n• Breathing Pulse: Make the light gently pulse like a breathing candle or heartbeat.\n• Color Swatches: Pick from warm Candle light, Fairy Pink, Sky Blue, Violet, Emerald, or choose your own custom color!"
			}
		]
	},
	{
		"id": "rooms_atmosphere",
		"title": "10. Room Studio, Multi-Screen Slices & Weather",
		"icon": "icon_room",
		"badge": "Rooms",
		"sections": [
			{
				"title": "The Room Studio",
				"body": "Tap 'Room' in the top bar to customize your active room layout, wallpapers, wall colors, floor lines, and building assignments."
			},
			{
				"title": "Multi-Screen Wide Rooms (Slices)",
				"body": "• Screen Slices: Each room slice matches the exact width of your device screen.\n• Extra Wide Rooms: Tap '+ Add Room Slice' in the Room Studio to expand your room up to 10 screens wide for seamless side-to-side panoramic scrolling."
			},
			{
				"title": "Wallpapers & Procedural Colors",
				"body": "• Custom Wallpaper: Assign custom artwork from your library to any slice, and choose how it scales (Cover, Fit, Stretch, Tile, or Original).\n• Procedural Colors: If no custom art is chosen, use the built-in color pickers to customize the wall, baseboard trim, and floor colors."
			},
			{
				"title": "Floor Baseline Slider",
				"body": "Use the Floor Baseline slider to adjust where characters walk and where furniture sits across the entire room."
			},
			{
				"title": "Outdoor Balcony Weather Masks",
				"body": "Set individual room slices to 'Outdoors'. When rain, snow, autumn leaves, or dust storms are active, the weather will fall only on outdoor slices (like balconies or gardens) while keeping indoor living rooms dry!"
			},
			{
				"title": "Atmosphere & Mood Presets",
				"body": "In the World Map toolbar, pick from 5 lighting moods:\n• Day (Bright and clear)\n• Sunset (Warm golden tones)\n• Night (Deep cozy midnight blue)\n• Cozy (Warm ambient indoor glow)\n• Cyberpunk (Moody violet and neon tones)"
			}
		]
	},
	{
		"id": "world_map_elevators",
		"title": "11. World Map, Doors, Stairs & Elevators",
		"icon": "icon_map",
		"badge": "Worldbuilding",
		"sections": [
			{
				"title": "The World Map",
				"body": "Tap 'Map' in the top bar to view your entire universe map. Tap any building pin to travel straight to that location. Switch the map to 'Edit' mode to move building pins around, add new buildings, or customize building settings."
			},
			{
				"title": "Building Settings & Floor Management",
				"body": "In Map Edit Mode, tap the gear icon on any building pin to open Building Settings. Here you can add new floors (1F, 2F, B1, Rooftop), rename rooms, and assign custom building artwork in one place."
			},
			{
				"title": "Auto-Climbing Stairs",
				"body": "Drop a character onto stairs (or tap the stairs) to climb directly to the floor above in the same building!"
			},
			{
				"title": "Multi-Floor Keypad Elevators",
				"body": "Drop characters inside an elevator. A floor keypad will pop up. Tap any floor button (like 1F, 2F, or Rooftop) and the elevator will close its doors and take everyone to that floor!"
			},
			{
				"title": "Doorway Portals",
				"body": "Long-press any doorway and select 'Destination' to link it to another room or map location. When a character walks through the door, they will travel straight to that room!"
			},
			{
				"title": "Quick Floor Switcher",
				"body": "Tap the floor button in the Top Navigation Bar (e.g. '1F') to open a quick floor dropdown and jump to any floor in your active building."
			}
		]
	},
	{
		"id": "logic_rules",
		"title": "12. Story Magic & Cause-and-Effect Rules",
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
		"id": "lore_journals_factions",
		"title": "13. Character Profiles, Family Trees & Lore",
		"icon": "icon_lore",
		"badge": "Narrative",
		"sections": [
			{
				"title": "Character Lore Cards",
				"body": "Long-press any character and tap 'Profile' to open their 3-tab Lore Card:\n• Tab 1 (Profile): Name, Pronouns, Role/Title (like Baker or Knight), Life Status, custom portrait picture, and custom traits (like Birthday or Favorite Color).\n• Tab 2 (Family & Feelings): Two-way family connections (Parents, Children, Siblings, Partners) and feelings (Best Friends, Rivals, Secret Crushes, Mentors). When you set one character as a sibling to another, the game links them both ways automatically!\n• Tab 3 (Backstory): A notebook where you can write backstories, secrets, and world notes."
			},
			{
				"title": "World Journal & Story Chronicles",
				"body": "Open the World Journal from the Main Menu to chronicle the history of your universe:\n• Story Chronicles: Record dated eras, memorable events, participating characters, and linked rooms.\n• Guilds & Factions: Create kingdoms, clubs, schools, or alliances with custom badge colors, mottos, headquarters, appointed leaders, and ranked member rosters."
			}
		]
	},
	{
		"id": "universes_packs_settings",
		"title": "14. Universes, Sharing, In-App Updates & Settings",
		"icon": "icon_settings",
		"badge": "Settings",
		"sections": [
			{
				"title": "Separate Story Universes",
				"body": "Universes are completely separate creative worlds. Each universe has its own independent rooms, Cast rosters, recipes, World Maps, and Journal chronicles. Switch between stories anytime in the Universe Hub."
			},
			{
				"title": "Exporting & Sharing Story Packs",
				"body": "Want to share your creation? Tap 'Export Active (.ownpack)' in the Universe Hub to bundle your entire world into a single shareable package saved to:\n\nDocuments / OwnWorld / Dollhouse / Exports"
			},
			{
				"title": "Importing Story Packs",
				"body": "Download an .ownpack file created by a friend and tap 'Import (.ownpack)' in the Universe Hub to load and explore their world in one tap!"
			},
			{
				"title": "In-App Updates & Changelogs",
				"body": "Stay up to date with new features effortlessly!\n• Check for Updates: Open the Main Menu and tap 'Check for Updates' to query the latest GitHub release.\n• Review Release Notes: The dialog displays full changelogs and new feature lists.\n• High-Speed Download: Downloads updates with high throughput and live MB/s and ETA metrics.\n• Native Installation: On Android, the APK installer automatically launches when downloading finishes. On Windows, the installer or updated package opens directly."
			},
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


func _init() -> void:
	max_panel_width = 780.0
	max_panel_height = 580.0


func _build_content() -> void:
	name = "TutorialDialog"
	var is_mob: bool = is_mobile()

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
	search_input.placeholder_text = "Search topics (drawings, outfits, food, rules, updates)..."
	search_input.custom_minimum_size = Vector2(260.0 if is_mob else 200.0, 32.0 if is_mob else 26.0)
	search_input.text_changed.connect(_on_search_query_changed)
	register_keyboard_dodge(search_input)
	header_hbox.add_child(search_input)

	btn_close = Button.new()
	btn_close.custom_minimum_size = Vector2(28.0 if is_mob else 22.0, 28.0 if is_mob else 22.0)
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.add_theme_constant_override("icon_max_width", 12)
	apply_close_icon(btn_close)
	btn_close.pressed.connect(_on_close_requested)
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


func _on_theme_updated() -> void:
	if is_instance_valid(header_title_lbl): 
		header_title_lbl.add_theme_color_override("font_color", ThemeService.get_color("accent_primary", "#ec4899"))
	if is_instance_valid(btn_close): 
		apply_close_icon(btn_close)
	if visible:
		_render_topics_sidebar()
		_render_active_topic_content()


func open_handbook(starting_topic_index: int = 0) -> void:
	active_topic_index = clampi(starting_topic_index, 0, tutorial_chapters.size() - 1)
	active_filter_query = ""
	if is_instance_valid(search_input): 
		search_input.text = ""
	_render_topics_sidebar()
	_render_active_topic_content()
	open_dialog()


func _render_topics_sidebar() -> void:
	if not is_instance_valid(topics_list_vbox): 
		return
	for child: Node in topics_list_vbox.get_children(): 
		child.queue_free()

	var is_mob: bool = is_mobile()
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
			if not matches_query: 
				continue

		var is_active: bool = (i == active_topic_index)
		var btn: Button = Button.new()
		btn.text = " " + c_title
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0.0, 36.0 if is_mob else 30.0)
		btn.focus_mode = Control.FOCUS_NONE
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 11 if is_mob else 10)
		btn.add_theme_constant_override("icon_max_width", 14)

		apply_button_icon(btn, str(chapter.get("icon", "icon_room")))

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
	if not is_instance_valid(content_vbox): 
		return
	for child: Node in content_vbox.get_children(): 
		child.queue_free()

	if active_topic_index < 0 or active_topic_index >= tutorial_chapters.size():
		return

	var is_mob: bool = is_mobile()
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
	if icon_tex: 
		icon_rect.texture = icon_tex
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
		if not sec_var is Dictionary: 
			continue
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
			if is_instance_valid(content_scroll):
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
			if is_instance_valid(content_scroll):
				content_scroll.scroll_vertical = 0
		)
		nav_row.add_child(btn_next)


func _on_search_query_changed(new_text: String) -> void:
	active_filter_query = new_text.strip_edges().to_lower()
	_render_topics_sidebar()
