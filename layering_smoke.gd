extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	var forest := game.get_node("ForestRenderer") as ForestRenderer
	var tree_pos: Vector2 = game.units[0].pos + Vector2(0, 80)
	forest.setup([tree_pos], game)
	forest.refresh_visible_trees()
	var tree := forest.active[tree_pos] as Sprite2D
	var unit: Dictionary = game.units[0]
	var unit_node := game.unit_nodes[0] as Node2D
	var gold_index: int = game.resources.find_custom(func(resource): return resource.kind == "gold")
	var gold: Dictionary = game.resources[gold_index]
	gold.block_center = tree_pos + Vector2(0, 80)
	gold.pos = gold.block_center
	game.resource_nodes[gold_index].position = gold.block_center
	game.update_visual_nodes(0.0)
	forest.refresh_visible_trees()
	var tree_depth: bool = tree.z_index == int(tree_pos.y / 8.0)
	var unit_depth: bool = unit_node.z_index == int(unit.pos.y / 8.0)
	var gold_depth: bool = game.resource_nodes[gold_index].z_index == int(gold.block_center.y / 8.0)
	var unit_transparent: bool = tree.modulate.a < 1.0
	print("LAYERING tree_depth=%s unit_depth=%s gold_depth=%s unit_transparent=%s" % [tree_depth, unit_depth, gold_depth, unit_transparent])
	quit(0 if tree_depth and unit_depth and gold_depth and unit_transparent else 1)
