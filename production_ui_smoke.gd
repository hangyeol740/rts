extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.title_open = false
	game.help_open = false
	game.paused = false
	game.add_building("archery", Vector2(9700, 9200), 0, true)
	game.selected_building = game.buildings.size() - 1
	game.get_node("UIInterface").refresh(game)
	var ui = game.get_node("UIInterface")
	var construction_visible: bool = ui.get_node("HUD/ConstructionPanel").visible
	var production_count: int = ui.get_node("HUD/CommandPanel/Buttons").get_child_count()
	var archery_produces_archer: bool = game.action_buttons() == ["archer"]
	print("PRODUCTION_UI construction_visible=%s production_buttons=%s archery_produces_archer=%s" % [construction_visible, production_count, archery_produces_archer])
	quit(0 if construction_visible and production_count == 1 and archery_produces_archer else 1)
