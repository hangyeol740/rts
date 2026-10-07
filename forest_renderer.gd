class_name ForestRenderer
extends Node2D

const TREE_SCENE = preload("res://scenes/assets/tree.tscn")
const BUCKET_SIZE := 512.0
const VIEW_MARGIN := 160.0
const REFRESH_INTERVAL := 0.20

var buckets: Dictionary = {}
var harvested_positions: Dictionary = {}
var active: Dictionary = {}
var pool: Array[Sprite2D] = []
var game: Node
var tree_texture: Texture2D
var tree_region := Rect2(0, 0, 256, 256)
var tree_position := Vector2.ZERO
var tree_offset := Vector2.ZERO
var tree_scale := Vector2.ONE
var tree_centered := true
var refresh_time := 0.0
var visible_key := Rect2i()

func setup(positions: Array[Vector2], owner: Node) -> void:
	game = owner
	var instance := TREE_SCENE.instantiate() as Node2D
	var sprite := instance.get_node_or_null("Sprite") as Sprite2D
	tree_texture = sprite.texture
	tree_region = sprite.region_rect if sprite.region_enabled else Rect2(Vector2.ZERO, sprite.texture.get_size())
	tree_position = sprite.position
	tree_offset = sprite.offset
	tree_scale = sprite.scale
	tree_centered = sprite.centered
	instance.queue_free()
	buckets.clear()
	harvested_positions.clear()
	for position in positions:
		var key := bucket_key(position)
		if not buckets.has(key): buckets[key] = []
		buckets[key].append(position)
	visible_key = Rect2i()
	refresh_time = 0.0
	refresh_visible_trees()

func hide_tree(position: Vector2) -> void:
	harvested_positions[position] = true
	if active.has(position): release_tree(position)

func _process(delta: float) -> void:
	if game == null: return
	refresh_time -= delta
	if refresh_time > 0.0: return
	refresh_time = REFRESH_INTERVAL
	refresh_visible_trees()

func refresh_visible_trees() -> void:
	if game == null or tree_texture == null: return
	var visible := Rect2(game.camera_pos - Vector2.ONE * VIEW_MARGIN, game.visible_size() + Vector2.ONE * VIEW_MARGIN * 2.0)
	var wanted: Dictionary = {}
	var minimum := bucket_key(visible.position)
	var maximum := bucket_key(visible.end)
	var next_key := Rect2i(minimum, maximum - minimum + Vector2i.ONE)
	if next_key != visible_key:
		visible_key = next_key
		for y in range(minimum.y, maximum.y + 1):
			for x in range(minimum.x, maximum.x + 1):
				for position in buckets.get(Vector2i(x, y), []):
					if visible.has_point(position) and not harvested_positions.has(position): wanted[position] = true
		for position in active.keys():
			if not wanted.has(position): release_tree(position)
		for position in wanted:
			if active.has(position): continue
			var sprite := acquire_tree()
			active[position] = sprite
			apply_tree_visual(sprite, position)
	# Alpha is the only per-tree state that changes while units move.
	for position in active:
		(active[position] as Sprite2D).modulate = Color(1.0, 1.0, 1.0, 0.42) if is_occluding_unit(position) else Color.WHITE

func acquire_tree() -> Sprite2D:
	var sprite: Sprite2D
	if pool.is_empty():
		sprite = Sprite2D.new()
		add_child(sprite)
	else:
		sprite = pool.pop_back()
	sprite.visible = true
	return sprite

func release_tree(position: Vector2) -> void:
	var sprite := active[position] as Sprite2D
	active.erase(position)
	sprite.visible = false
	pool.append(sprite)

func apply_tree_visual(sprite: Sprite2D, position: Vector2) -> void:
	sprite.texture = tree_texture
	sprite.region_enabled = true
	sprite.region_rect = tree_region
	sprite.position = position + tree_position + tree_offset * tree_scale
	sprite.offset = Vector2.ZERO
	sprite.centered = tree_centered
	sprite.scale = tree_scale
	sprite.z_index = clampi(int(position.y / 8.0), -4000, 4000)
	sprite.modulate = Color.WHITE

func is_occluding_unit(tree_root: Vector2) -> bool:
	for unit in game.units:
		if unit.pos.y < tree_root.y and absf(unit.pos.x - tree_root.x) < 114.0 and unit.pos.distance_to(tree_root) < 220.0:
			return true
	return false

func bucket_key(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / BUCKET_SIZE), floori(position.y / BUCKET_SIZE))
