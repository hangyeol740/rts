extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.title_open = false
	game.help_open = false
	game.paused = false
	game.selected_units.clear()
	game.selected_units.append(0)
	game.issue_command(game.resources[0].pos)
	for _frame in 2400: await physics_frame
	var label := game.get_node("UIInterface/HUD/ResourcePanel/GoldLabel") as Label
	var worker: Dictionary = game.units[0]
	var hall: Dictionary = game.buildings[0]
	var updated: bool = game.gold > game.stats.start.gold and label.text == "금  %d" % game.gold
	print("RESOURCE_UI gold=%s label=%s updated=%s state=%s worker=%s target=%s flow=%s return=%s carry=%s drop=%s distance=%s" % [game.gold, label.text, updated, worker.worker_state, worker.pos, worker.target, worker.flow_target, worker.return_point, worker.carry, hall.drop_point, worker.pos.distance_to(hall.drop_point)])
	quit(0 if updated else 1)
