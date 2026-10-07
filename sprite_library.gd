class_name SpriteLibrary
extends RefCounted

const ROOT := "res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/"
const UNIT_FRAME := Vector2i(192, 192)
static var cache: Dictionary = {}

static func path_for_unit(kind: String, team: int, action: String = "idle", carrying: String = "") -> String:
	var color := "Blue" if team == 0 else "Red"
	var folder: String = {"worker":"Pawn", "sword":"Warrior", "archer":"Archer"}[kind]
	var file: String = ""
	if kind == "worker":
		var tool := "Knife" if carrying == "food" else ("Axe" if carrying == "wood" else "Pickaxe")
		file = "Pawn_Interact %s.png" % tool if action == "gather" else ("Pawn_Run %s.png" % tool if action == "walk" else "Pawn_Idle %s.png" % tool)
		# Harvesting always has priority; carrying art is for travelling only.
		if action != "gather" and carrying == "gold": file = "Pawn_Run Gold.png"
		if action != "gather" and carrying == "wood": file = "Pawn_Run Wood.png"
		if action != "gather" and carrying == "food": file = "Pawn_Run Meat.png"
	elif kind == "sword":
		file = "Warrior_Attack1.png" if action == "attack" else ("Warrior_Run.png" if action == "walk" else "Warrior_Idle.png")
	else:
		file = "Archer_Shoot.png" if action == "attack" else ("Archer_Run.png" if action == "walk" else "Archer_Idle.png")
	return ROOT + "Units/%s Units/%s/%s" % [color, folder, file]

static func path_for_building(kind: String, team: int) -> String:
	var color := "Blue" if team == 0 else "Red"
	var file: String = {"hall":"Castle.png", "barracks":"Barracks.png", "house":"House1.png", "archery":"Archery.png", "tower":"Tower.png"}[kind]
	return ROOT + "Buildings/%s Buildings/%s" % [color, file]

# Tree1..4 are 6-frame horizontal sprite sheets, 256px per frame
static func tree_path(variant: int) -> String:
	return ROOT + "Terrain/Resources/Wood/Trees/Tree%d.png" % clamp(variant, 1, 4)

static func stump_path(variant: int) -> String:
	return ROOT + "Terrain/Resources/Wood/Trees/Stump %d.png" % clamp(variant, 1, 4)

static func gold_path() -> String:
	return ROOT + "Terrain/Resources/Gold/Gold Stones/Gold Stone 5.png"

static func resource_path(kind: String) -> String:
	if kind == "gold": return gold_path()
	return tree_path(1)

# UI Banners
static func banner_path() -> String:
	return ROOT + "UI Elements/UI Elements/Banners/Banner.png"

static func banner_slots_path() -> String:
	return ROOT + "UI Elements/UI Elements/Banners/Banner_Slots.png"

# Bars
static func big_bar_base_path() -> String:
	return ROOT + "UI Elements/UI Elements/Bars/BigBar_Base.png"

static func big_bar_fill_path() -> String:
	return ROOT + "UI Elements/UI Elements/Bars/BigBar_Fill.png"

static func small_bar_base_path() -> String:
	return ROOT + "UI Elements/UI Elements/Bars/SmallBar_Base.png"

static func small_bar_fill_path() -> String:
	return ROOT + "UI Elements/UI Elements/Bars/SmallBar_Fill.png"

# Buttons
static func big_button_path(color: String, pressed: bool = false) -> String:
	var suffix := "_Pressed.png" if pressed else "_Regular.png"
	return ROOT + "UI Elements/UI Elements/Buttons/Big%sButton%s" % [color, suffix]

static func small_square_button_path(color: String, pressed: bool = false) -> String:
	var suffix := "_Pressed.png" if pressed else "_Regular.png"
	return ROOT + "UI Elements/UI Elements/Buttons/Small%sSquareButton%s" % [color, suffix]

# Wood Table panel
static func wood_table_path() -> String:
	return ROOT + "UI Elements/UI Elements/Wood Table/WoodTable.png"

static func wood_table_slots_path() -> String:
	return ROOT + "UI Elements/UI Elements/Wood Table/WoodTable_Slots.png"

# Papers
static func regular_paper_path() -> String:
	return ROOT + "UI Elements/UI Elements/Papers/RegularPaper.png"

static func special_paper_path() -> String:
	return ROOT + "UI Elements/UI Elements/Papers/SpecialPaper.png"

# Ribbons
static func big_ribbons_path() -> String:
	return ROOT + "UI Elements/UI Elements/Ribbons/BigRibbons.png"

static func small_ribbons_path() -> String:
	return ROOT + "UI Elements/UI Elements/Ribbons/SmallRibbons.png"

# Icons (64x64 each)
static func icon_path(n: int) -> String:
	return ROOT + "UI Elements/UI Elements/Icons/Icon_%02d.png" % clamp(n, 1, 12)

# Human avatars (256x256 each)
static func avatar_path(n: int) -> String:
	return ROOT + "UI Elements/UI Elements/Human Avatars/Avatars_%02d.png" % clamp(n, 1, 25)

# Store-page banner
static func store_banner_path() -> String:
	return ROOT + "UI Elements/UI Banners from the store page/Banner/Banner.png"

static func ui_path(relative: String) -> String:
	return ROOT + "UI Elements/UI Elements/" + relative

static func terrain_path(relative: String) -> String:
	return ROOT + "Terrain/Tileset/" + relative

static func texture(path: String) -> Texture2D:
	# The pack is git-ignored, so load source PNG files directly instead of using imports.
	if cache.has(path): return cache[path]
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	var result := ImageTexture.create_from_image(image)
	cache[path] = result
	return result
