extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.title_open = false
	game.help_open = false
	game.paused = false
	var sheep_index: int = game.resources.find_custom(func(resource): return resource.kind == "food")
	var sheep_node := game.resource_nodes[sheep_index] as Node2D
	var idle := sheep_node.get_node("Sprite") as Sprite2D
	var moving := sheep_node.get_node("MoveSprite") as AnimatedSprite2D
	var meat := sheep_node.get_node("MeatSprite") as Sprite2D
	game.camera_pos = game.resources[sheep_index].pos - game.visible_size() * 0.5
	game.clamp_camera()
	var frames_visible := true
	var saw_idle := false
	var saw_walk := false
	var frames: Dictionary = {}
	for _frame in 360:
		await physics_frame
		saw_idle = saw_idle or idle.visible
		saw_walk = saw_walk or moving.visible
		if moving.visible: frames[moving.frame] = true
		if not sheep_node.visible or (not idle.visible and not moving.visible) or meat.visible:
			frames_visible = false
	var animated: bool = frames.size() > 1
	print("SHEEP_VISIBILITY stable=%s saw_idle=%s saw_walk=%s animated=%s frames=%s" % [frames_visible, saw_idle, saw_walk, animated, frames.size()])
	quit(0 if frames_visible and saw_idle and saw_walk and animated else 1)
