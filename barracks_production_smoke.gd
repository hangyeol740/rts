extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.title_open = false
	game.help_open = false
	game.paused = false
	game.gold = 500
	game.wood = 500
	game.add_building("barracks", Vector2(9700, 9200), 0, true)
	game.selected_building = game.buildings.size() - 1
	var before: int = game.units.size()
	game.perform_action("sword")
	var produced: bool = game.units.size() == before + 1 and game.units.back().kind == "sword"
	print("BARRACKS_PRODUCTION produced=%s units=%s" % [produced, game.units.size()])
	quit(0 if produced else 1)
