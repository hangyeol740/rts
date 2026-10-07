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
	var sheep_index: int = game.resources.find_custom(func(resource): return resource.kind == "food")
	var sheep: Dictionary = game.resources[sheep_index]
	game.units[0].pos = sheep.pos + Vector2(420, 0)
	(game.unit_nodes[0] as Node2D).position = game.units[0].pos
	game.issue_command(sheep.pos)
	var start: Vector2 = sheep.pos
	var walked_while_targeted := false
	var saw_walk_art := false
	var saw_knife_art := false
	for _frame in 360:
		await physics_frame
		var unit: Dictionary = game.units[0]
		walked_while_targeted = walked_while_targeted or (game.resources[sheep_index].pos.distance_to(start) > 24.0 and unit.attack_type == "sheep")
		var sprite := game.unit_nodes[0].get_node("Animation") as AnimatedSprite2D
		saw_walk_art = saw_walk_art or (unit.attack_type == "sheep" and unit.moving and sprite.animation == &"walk")
		saw_knife_art = saw_knife_art or (unit.attack_type == "sheep" and unit.cooldown > 0.45 and sprite.animation == &"gather_food")
	# Continue the same order at close range to verify the actual hit animation
	# independently from random sheep wandering distance.
	sheep = game.resources[sheep_index]
	var close_pos: Vector2 = game.units[0].pos + Vector2(32, 0)
	var delta_pos: Vector2 = close_pos - sheep.pos
	sheep.pos = close_pos
	sheep.wander_target = close_pos
	sheep.wander_time = 999.0
	sheep.sheep_walking = false
	sheep.block_center += delta_pos
	sheep.gather_center += delta_pos
	sheep.block_rect.position += delta_pos
	sheep.block_shape.center += delta_pos
	for _frame in 120:
		await physics_frame
		var sprite := game.unit_nodes[0].get_node("Animation") as AnimatedSprite2D
		if game.units[0].attack_type == "sheep" and game.units[0].cooldown > 0.45:
			saw_knife_art = saw_knife_art or sprite.animation == &"gather_food"
	print("SHEEP_PURSUIT sheep_moves=%s walk_art=%s knife_art=%s" % [walked_while_targeted, saw_walk_art, saw_knife_art])
	quit(0 if walked_while_targeted and saw_walk_art and saw_knife_art else 1)
