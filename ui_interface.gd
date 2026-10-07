class_name GameUI
extends CanvasLayer

signal action_requested(kind: String)
signal start_requested
signal help_closed
signal pause_closed

@onready var gold_label: Label = $HUD/ResourcePanel/GoldLabel
@onready var wood_label: Label = $HUD/ResourcePanel/WoodLabel
@onready var food_label: Label = $HUD/ResourcePanel/FoodLabel
@onready var population_label: Label = $HUD/ResourcePanel/PopulationLabel
@onready var message_label: Label = $HUD/MessageLabel
@onready var selection_name: Label = $HUD/SelectionPanel/NameLabel
@onready var selection_detail: Label = $HUD/SelectionPanel/DetailLabel
@onready var command_buttons: VBoxContainer = $HUD/CommandPanel/Buttons
@onready var construction_panel: Control = $HUD/ConstructionPanel
@onready var construction_buttons: GridContainer = $HUD/ConstructionPanel/Buttons
@onready var title_dialog: Control = $TitleDialog
@onready var help_dialog: Control = $HelpDialog
@onready var pause_dialog: Control = $PauseDialog
var last_state := ""
var game: Node

func _ready() -> void:
	$TitleDialog/StartButton.pressed.connect(func(): start_requested.emit())
	$HelpDialog/CloseButton.pressed.connect(func(): help_closed.emit())
	$PauseDialog/ContinueButton.pressed.connect(func(): pause_closed.emit())

func refresh(game: Node) -> void:
	self.game = game
	$HUD/Minimap.game = game
	var state := "%d:%d:%d:%d:%d:%s:%d:%d:%s" % [game.gold, game.wood, game.food, game.units.size(), game.population_cap, game.selected_units, game.selected_building, game.selected_resource, game.message]
	if state == last_state:
		title_dialog.visible = game.title_open
		help_dialog.visible = game.help_open
		pause_dialog.visible = game.paused
		return
	last_state = state
	gold_label.text = "금  %d" % game.gold
	wood_label.text = "나무  %d" % game.wood
	food_label.text = "고기  %d" % game.food
	population_label.text = "인구  %d / %d" % [game.units.filter(func(u): return u.team == 0).size(), game.population_cap]
	message_label.text = game.message
	var name := "선택한 대상이 없습니다"
	var detail := "유닛이나 건물을 클릭하세요."
	if game.selected_units.size() == 1:
		var unit: Dictionary = game.units[game.selected_units[0]]
		name = game.korean_name(unit.kind) + "  %d / %d" % [unit.hp, unit.max_hp]
		detail = "공격 %d   사거리 %d   이동 %d" % [game.stats[unit.kind].attack, game.stats[unit.kind].range, game.stats[unit.kind].speed]
	elif game.selected_units.size() > 1:
		name = "%d명 선택" % game.selected_units.size()
		detail = "오른쪽 클릭으로 함께 이동합니다."
	elif game.selected_building >= 0:
		var building: Dictionary = game.buildings[game.selected_building]
		name = game.korean_name(building.kind) + "  %d / %d" % [building.hp, building.max_hp]
		detail = "생산 버튼을 누르면 유닛이 바로 나옵니다."
	elif game.selected_resource >= 0:
		var resource: Dictionary = game.resources[game.selected_resource]
		name = "양  %d / %d" % [resource.hp, resource.max_hp] if resource.state == "sheep" else "고기  %d" % resource.amount
		detail = "오른쪽 클릭해서 도축하세요." if resource.state == "sheep" else "일꾼으로 채집할 수 있습니다."
	selection_name.text = name
	selection_detail.text = detail
	for child in command_buttons.get_children(): child.queue_free()
	for kind in game.action_buttons():
		if kind in ["barracks", "house", "archery", "tower"]: continue
		command_buttons.add_child(make_command_row(game, kind, false))
	for child in construction_buttons.get_children(): child.queue_free()
	# Production and construction occupy the same right-side area. When a
	# production building is selected, hide construction so it cannot cover
	# the worker/sword/archer production controls.
	construction_panel.visible = true
	for kind in ["barracks", "house", "archery", "tower"]:
		construction_buttons.add_child(make_command_row(game, kind, true))
	title_dialog.visible = game.title_open
	help_dialog.visible = game.help_open
	pause_dialog.visible = game.paused

func make_command_row(game: Node, kind: String, construction: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 42)
	row.add_theme_constant_override("separation", 7)
	var button := TextureButton.new()
	# Blue means the action is available. Red communicates a blocked action.
	button.texture_normal = load("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Buttons/SmallBlueSquareButton_Regular.png") as Texture2D
	button.texture_disabled = load("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Buttons/SmallRedSquareButton_Regular.png") as Texture2D
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.custom_minimum_size = Vector2(38, 38)
	button.disabled = game.gold < game.stats[kind].gold or game.wood < game.stats[kind].wood or game.food < game.stats[kind].get("food", 0)
	button.pressed.connect(func(): action_requested.emit(kind))
	row.add_child(button)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var enough: bool = game.gold >= game.stats[kind].gold and game.wood >= game.stats[kind].wood
	var title := Label.new()
	title.text = game.korean_name(kind) + (" 건설" if construction else " 생산")
	title.add_theme_color_override("font_color", Color("e5e1d8"))
	title.add_theme_color_override("font_outline_color", Color("3d2c22"))
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_font_size_override("font_size", 11)
	text_box.add_child(title)
	var cost := RichTextLabel.new()
	cost.bbcode_enabled = true
	cost.fit_content = true
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost.add_theme_color_override("default_color", Color("e5e1d8"))
	cost.add_theme_color_override("font_outline_color", Color("3d2c22"))
	cost.add_theme_constant_override("outline_size", 2)
	cost.add_theme_font_size_override("normal_font_size", 10)
	var gold_color := "#ff8a80" if game.gold < game.stats[kind].gold else "#e5e1d8"
	var wood_color := "#ff8a80" if game.wood < game.stats[kind].wood else "#e5e1d8"
	var food_cost: int = game.stats[kind].get("food", 0)
	var food_color := "#ff8a80" if game.food < food_cost else "#e5e1d8"
	cost.text = "[color=%s]금 %d[/color]   [color=%s]나무 %d[/color]   [color=%s]고기 %d[/color]" % [gold_color, game.stats[kind].gold, wood_color, game.stats[kind].wood, food_color, food_cost]
	text_box.add_child(cost)
	row.add_child(text_box)
	return row
