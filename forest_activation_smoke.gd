extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	var forest: Vector2 = game.forest_positions[0]
	var before: int = game.resources.filter(func(r): return r.kind == "wood").size()
	var index: int = game.hit_resource(forest)
	var after: int = game.resources.filter(func(r): return r.kind == "wood").size()
	var activated: bool = index >= 0 and after == before + 1 and game.resources[index].forest_visual
	print("FOREST_ACTIVATION visual_forest=%s before=%s after=%s activated=%s" % [game.forest_positions.size(), before, after, activated])
	quit(0 if activated else 1)
