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
	var sheep_index: int = game.hit_sheep(game.resources.filter(func(r): return r.kind == "food")[0].pos)
	var sheep: Dictionary = game.resources[sheep_index]
	# Keep this functional test near the hall so its assertion covers slaughter,
	# harvesting, and delivery rather than random world travel duration.
	var test_pos: Vector2 = game.player_hall_position + Vector2(260, 80)
	var delta_pos: Vector2 = test_pos - sheep.pos
	sheep.pos = test_pos
	sheep.wander_target = test_pos
	sheep.wander_time = 999.0
	sheep.sheep_walking = false
	sheep.block_center += delta_pos
	sheep.gather_center += delta_pos
	sheep.block_rect.position += delta_pos
	sheep.block_shape.center += delta_pos
	game.resource_nodes[sheep_index].position = test_pos
	var sheep_pos: Vector2 = game.resources[sheep_index].pos
	# Keep player units away so the point-selection check targets the sheep.
	for unit_index in game.units.size():
		game.units[unit_index].pos = game.player_hall_position + Vector2(-220 - unit_index * 50, 180)
		(game.unit_nodes[unit_index] as Node2D).position = game.units[unit_index].pos
	game.selected_units.clear()
	game.selected_units.append(0)
	game.units[0].pos = sheep_pos + Vector2(48, 0)
	(game.unit_nodes[0] as Node2D).position = game.units[0].pos
	var hit_before: int = game.hit_sheep(sheep_pos)
	game.issue_command(sheep_pos)
	var ordered: bool = game.units[0].attack_type == "sheep" and game.units[0].attack_index == sheep_index
	for _frame in 3000: await physics_frame
	var meat: Dictionary = game.resources[sheep_index]
	var label := game.get_node("UIInterface/HUD/ResourcePanel/FoodLabel") as Label
	var harvested: bool = meat.state == "meat" and game.food > game.stats.start.food and label.text == "고기  %d" % game.food
	print("SHEEP_FOOD hit=%s ordered=%s slaughtered=%s food=%s harvested=%s worker=%s carry=%s target=%s flow=%s drop=%s" % [hit_before, ordered, meat.state == "meat", game.food, harvested, game.units[0].pos, game.units[0].carry, game.units[0].target, game.units[0].flow_target, game.buildings[0].drop_point])
	quit(0 if hit_before == sheep_index and ordered and harvested else 1)
