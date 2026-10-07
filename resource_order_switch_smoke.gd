extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.title_open = false
	game.help_open = false
	game.paused = false
	await physics_frame
	game.selected_units.clear()
	game.selected_units.append(0)
	var sheep_pos: Vector2 = game.resources.filter(func(r): return r.kind == "food")[0].pos
	var sheep_index: int = game.hit_sheep(sheep_pos)
	game.issue_command(sheep_pos)
	var sheep_ordered: bool = game.units[0].slaughter_resource == sheep_index and game.units[0].attack_type == "sheep"
	var wood_index: int = game.hit_resource(game.forest_positions[0])
	game.issue_command(game.resources[wood_index].pos)
	var switched: bool = game.units[0].task == "gather" and game.units[0].resource == wood_index and game.units[0].slaughter_resource == -1 and game.units[0].attack_type == ""
	print("RESOURCE_ORDER_SWITCH sheep_hit=%s sheep_ordered=%s slaughter=%s attack=%s switched_to_wood=%s" % [sheep_index, sheep_ordered, game.units[0].slaughter_resource, game.units[0].attack_type, switched])
	quit(0 if sheep_ordered and switched else 1)
