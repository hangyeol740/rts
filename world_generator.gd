class_name WorldGenerator
extends RefCounted

static func generate_resource_layout(map_size: Vector2, rng: RandomNumberGenerator, _noise: FastNoiseLite) -> Dictionary:
	var center := map_size * 0.5
	var gold: Array[Vector2] = []
	for index in 10:
		var angle := TAU * float(index) / 10.0 + rng.randf_range(-0.22, 0.22)
		gold.append(center + Vector2.RIGHT.rotated(angle) * rng.randf_range(1100.0, 5200.0))
	var sheep: Array[Vector2] = []
	for index in 18:
		var angle := TAU * float(index) / 18.0 + rng.randf_range(-0.16, 0.16)
		sheep.append(center + Vector2.RIGHT.rotated(angle) * rng.randf_range(750.0, 3600.0))
	# Perlin "height" is interpreted as forest density. High values create dense
	# forest cores, slopes create sparse edges, and low values create clearings.
	var height := FastNoiseLite.new()
	height.seed = rng.randi()
	height.noise_type = FastNoiseLite.TYPE_PERLIN
	height.frequency = 0.00025
	height.fractal_type = FastNoiseLite.FRACTAL_FBM
	height.fractal_octaves = 4
	var detail := FastNoiseLite.new()
	detail.seed = rng.randi()
	detail.noise_type = FastNoiseLite.TYPE_PERLIN
	detail.frequency = 0.0011
	detail.fractal_type = FastNoiseLite.FRACTAL_FBM
	detail.fractal_octaves = 2
	var wood: Array[Vector2] = []
	var spacing := 150.0
	var columns := ceili(map_size.x / spacing)
	var rows := ceili(map_size.y / spacing)
	for gy in rows:
		for gx in columns:
			var base := Vector2((gx + 0.5) * spacing, (gy + 0.5) * spacing)
			var start_distance := base.distance_to(center)
			# Keep only the exact base clearing. Do not use a radial density fade:
			# it creates an artificial circular forest ring around the base.
			if start_distance < 620.0: continue
			var forest_height := height.get_noise_2d(base.x, base.y)
			var local_detail := detail.get_noise_2d(base.x, base.y)
			# Height drives the forest shape. Detail only roughens its border.
			# This gives distinct broad woodland masses instead of scattered dots.
			var height_density := smoothstep(-0.22, 0.20, forest_height)
			# High "altitude" is a nearly solid forest canopy; low altitude stays open.
			var chance := clampf(height_density * 1.05 + local_detail * 0.025, 0.01, 0.995)
			if rng.randf() > chance: continue
			var jitter := Vector2(rng.randf_range(-55.0, 55.0), rng.randf_range(-55.0, 55.0))
			wood.append(base + jitter)
			# Peak areas receive a second offset tree, producing visibly dense cores.
			if height_density > 0.78 and rng.randf() < (height_density - 0.78) * 1.9:
				wood.append(base + Vector2(rng.randf_range(-72.0, 72.0), rng.randf_range(-72.0, 72.0)))
	return {"center":center, "gold":gold, "sheep":sheep, "wood":wood}
