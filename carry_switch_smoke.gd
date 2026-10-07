extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.title_open = false
	game.help_open = false
	game.paused = false
	var worker: Dictionary = game.units[0]
	worker.task = "gather"
	worker.resource = 0
	worker.carry = 6
	worker.carry_kind = "gold"
	game.selected_units.clear()
	game.selected_units.append(0)
	var target_resource := 0
	for i in game.resources.size():
		if game.resources[i].kind == "gold" and i != worker.resource:
			target_resource = i
			break
	game.issue_command(game.resources[target_resource].pos)
	var queued: bool = game.units[0].pending_resource == target_resource and game.units[0].carry == 6
	print("CARRY_SWITCH queued=%s pending=%s carry=%s" % [queued, game.units[0].pending_resource, game.units[0].carry])
	quit(0 if queued else 1)
