extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.title_open = false
	game.help_open = false
	game.paused = false
	var hall: Dictionary = game.buildings[0]
	var worker: Dictionary = game.units[0]
	game.selected_units.clear()
	game.selected_units.append(0)
	# User right-clicks the center of the town hall: a valid game must never enter Blocker.
	# Regression: an already embedded unit must be ejected, not merely stopped.
	worker.pos = hall.block_center
	(game.unit_nodes[0] as Node2D).position = hall.block_center
	var escaped := false
	var reentered := false
	for _frame in 900:
		await physics_frame
		var inside: bool = game.flow_field.shape_contains(hall.block_shape, game.units[0].pos, game.units[0].body_radius)
		if not inside: escaped = true
		elif escaped: reentered = true
	worker = game.units[0]
	var distance: float = worker.pos.distance_to(hall.block_center)
	var passed: bool = escaped and not reentered
	print("BUILDING_COLLISION distance=%s escaped=%s reentered=%s passed=%s end=%s" % [distance, escaped, reentered, passed, worker.pos])
	quit(0 if passed else 1)
