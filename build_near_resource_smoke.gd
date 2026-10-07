extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	var resource: Dictionary = game.resources[0]
	var blocked: bool = not game.can_place_building("house", resource.block_center)
	print("BUILD_NEAR_RESOURCE blocked=%s" % blocked)
	quit(0 if blocked else 1)
