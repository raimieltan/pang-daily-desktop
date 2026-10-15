extends SceneTree
## Probe: what do downward rays along the touge road hit, and how far from the road surface?
var _scene
var _frames := 0
func _initialize() -> void:
	_scene = load("res://scenes/touge.tscn").instantiate()
	root.add_child(_scene)
func _physics_process(_d: float) -> bool:
	_frames += 1
	if _frames < 3: return false
	var space: PhysicsDirectSpaceState3D = _scene.get_world_3d().direct_space_state
	var track: TrackData = _scene.track
	var counts := {}
	var worst := 0.0
	for i in range(0, track.points.size(), 25):
		for lat in [-2.5, -0.7, 0.0, 0.7, 2.5]:
			var p: Vector3 = track.points[i] + track.rights[i] * lat
			var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3, p + Vector3.DOWN * 3, CarBody.STATIC_LAYER)
			var hit: Dictionary = space.intersect_ray(q)
			var name: String = hit["collider"].name if hit else "none"
			counts[name] = counts.get(name, 0) + 1
			if hit and name != "RoadCollision":
				worst = maxf(worst, hit["position"].y - p.y)
				if counts[name] < 4: print("i=%d lat=%.1f hit %s at dy=%.2f" % [i, lat, name, hit["position"].y - p.y])
	print(counts, " worst non-road dy=", worst)
	return true
