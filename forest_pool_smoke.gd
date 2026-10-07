extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.title_open = false
	game.help_open = false
	game.paused = false
	var forest := game.get_node("ForestRenderer") as ForestRenderer
	forest.refresh_visible_trees()
	var first_active := forest.active.size()
	game.camera_pos = Vector2(0, 0)
	forest.refresh_visible_trees()
	var second_active := forest.active.size()
	var allocated := forest.active.size() + forest.pool.size()
	var reused := allocated <= maxi(first_active, second_active)
	var bounded := first_active < 500 and second_active < 500
	print("FOREST_POOL first=%s second=%s allocated=%s reused=%s bounded=%s" % [first_active, second_active, allocated, reused, bounded])
	quit(0 if bounded and reused else 1)
