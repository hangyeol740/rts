extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	var ui := game.get_node("UIInterface") as GameUI
	var grid := ui.get_node("HUD/ConstructionPanel/Buttons") as GridContainer
	var scale_ok: bool = game.VIEW == Vector2(960, 540) and ProjectSettings.get_setting("display/window/size/viewport_width") == 960
	var grid_ok: bool = grid.columns == 2
	var rows_visible := grid.get_child_count() == 4
	var hud_scaled := is_equal_approx((ui.get_node("HUD") as Control).scale.x, 0.75)
	print("UI_LAYOUT scale=%s grid=%s rows=%s hud_scaled=%s" % [scale_ok, grid_ok, rows_visible, hud_scaled])
	quit(0 if scale_ok and grid_ok and rows_visible and hud_scaled else 1)
