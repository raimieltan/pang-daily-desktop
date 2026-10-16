extends SceneTree
## Offline map build: `godot --headless --path . -s res://tools/build_map.gd`
## Generates maps/touge_01/touge_01.scn (road, terrain, rails, trees, gantries) and track.res.

const OUT_DIR := "res://maps/touge_01/"


func _initialize() -> void:
	var started := Time.get_ticks_msec()
	var b := TrackBuilder.new(Touge01Layout.SEGMENTS, 7)
	b.build_centerline()
	var clearance := b.min_leg_clearance()
	print("road: %.0f m, drop %.1f m, min leg clearance %.1f m (samples %d/%d)" % [
		(b.pts.size() - 1) * TrackBuilder.SPACING, b.pts[0].y - b.pts[b.pts.size() - 1].y,
		clearance["distance"], clearance["a"], clearance["b"]])
	if clearance["distance"] < 22.0:
		push_error("Road legs overlap: adjust the layout.")
		quit(1)
		return
	b.classify_sides()
	print("classified sides  %d ms" % (Time.get_ticks_msec() - started))

	var root := Node3D.new()
	root.name = "Touge01"

	var road := MeshInstance3D.new()
	road.name = "Road"
	road.mesh = b.build_road_mesh()
	var road_mat := road.mesh.surface_get_material(TrackBuilder.Mat.ASPHALT) as ShaderMaterial
	var data := b.track_data(Touge01Layout.START_DISTANCE, Touge01Layout.FINISH_BACK)
	road_mat.set_shader_parameter("lane_half_width", TrackBuilder.LANE)
	road_mat.set_shader_parameter("start_line", data.start_distance)
	road_mat.set_shader_parameter("finish_line", data.finish_distance)
	root.add_child(road)
	road.owner = root
	var road_body := StaticBody3D.new()
	road_body.name = "RoadCollision"
	road_body.collision_layer = CarBody.STATIC_LAYER
	road_body.collision_mask = 0
	var road_shape := CollisionShape3D.new()
	road_shape.shape = road.mesh.create_trimesh_shape()
	road_body.add_child(road_shape)
	root.add_child(road_body)
	road_body.owner = root
	road_shape.owner = root
	print("road mesh  %d ms" % (Time.get_ticks_msec() - started))

	var bounds := b.terrain_bounds()
	var grid := b.terrain_heights(bounds)
	print("terrain %dx%d  %d ms" % [grid["width"], grid["depth"], Time.get_ticks_msec() - started])
	var terrain := MeshInstance3D.new()
	terrain.name = "Terrain"
	terrain.mesh = b.build_terrain_mesh(bounds, grid)
	root.add_child(terrain)
	terrain.owner = root
	var terrain_body := StaticBody3D.new()
	terrain_body.name = "TerrainCollision"
	terrain_body.collision_layer = CarBody.STATIC_LAYER
	terrain_body.collision_mask = 0
	# A trimesh of the visual terrain. (A scaled HeightMapShape3D does not line up under Jolt: it
	# poked up to 2 m through the road.)
	var terrain_shape := CollisionShape3D.new()
	terrain_shape.shape = terrain.mesh.create_trimesh_shape()
	terrain_body.add_child(terrain_shape)
	root.add_child(terrain_body)
	terrain_body.owner = root
	terrain_shape.owner = root

	b.plan_village(data.start_distance, data.finish_distance)
	b.build_guardrails(root, root)
	b.build_trees(root, root, bounds, grid)
	b.build_backdrop(root, root, bounds)
	b.build_props(root, root, data.start_distance, data.finish_distance)
	b.build_gantry(root, root, data.start_distance, "START", Color(0.75, 0.12, 0.1))
	b.build_gantry(root, root, data.finish_distance, "GOAL", Color(0.1, 0.25, 0.7))
	print("dressing  %d ms" % (Time.get_ticks_msec() - started))

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT_DIR + "touge_01.scn", ResourceSaver.FLAG_COMPRESS)
	var err2 := ResourceSaver.save(data, OUT_DIR + "track.res", ResourceSaver.FLAG_COMPRESS)
	print("saved (%s, %s) in %d ms" % [error_string(err), error_string(err2), Time.get_ticks_msec() - started])
	root.free()
	quit(0 if err == OK and err2 == OK else 1)
