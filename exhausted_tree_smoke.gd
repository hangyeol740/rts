extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	var tree_pos: Vector2 = game.forest_positions[0]
	var index: int = game.hit_resource(tree_pos)
	game.resources[index].amount = 0
	game.resources[index].stump = true
	game.harvested_forest_positions[tree_pos] = true
	var retry: int = game.hit_resource(tree_pos)
	var excluded: bool = retry == -1 and game.nearest_forest_tree(tree_pos, 1.0) == Vector2.INF
	print("EXHAUSTED_TREE excluded=%s retry=%s" % [excluded, retry])
	quit(0 if excluded else 1)
