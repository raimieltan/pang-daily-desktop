class_name TrackMaterials
## Materials and small meshes for generated tracks, in the manga style (docs/ART_DIRECTION.md).


static func road() -> ShaderMaterial:
	return MangaArt.road()


## Indexed by `TrackBuilder.Mat`: asphalt, concrete, gravel, rock, dirt.
static func road_set() -> Array[Material]:
	return [MangaArt.road(), MangaArt.world_preset("concrete"), MangaArt.world_preset("gravel"),
		MangaArt.world_preset("rock"), MangaArt.world_preset("dirt")]


static func terrain() -> ShaderMaterial:
	return MangaArt.world_preset("terrain")


static func guardrail() -> ShaderMaterial:
	return MangaArt.world_preset("guardrail")


## Japanese cedar (sugi) drawn for ink: stacked drooping tiers whose rims are jagged spikes, so
## the silhouette reads as a hand-drawn tree rather than a cone. `seed_` varies tier count/shape.
static func cedar_mesh(seed_ := 0) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + seed_
	var mesh := ArrayMesh.new()
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.14
	trunk.bottom_radius = 0.24
	trunk.height = 4.0
	trunk.radial_segments = 6
	trunk.rings = 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(trunk, 0, Transform3D(Basis(), Vector3(0, 2.0, 0)))
	st.set_material(MangaArt.world_preset("trunk"))
	st.commit(mesh)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tiers := rng.randi_range(5, 7)
	var height := rng.randf_range(11.0, 14.0)
	var base := 2.6
	for k in tiers:
		var t := float(k) / tiers
		var bottom := base + (height - base) * t * 0.92
		var top := bottom + (height - base) / tiers * 1.9
		var radius := lerpf(2.6, 0.5, t) * rng.randf_range(0.85, 1.1)
		var spikes := 11 - k
		var apex := Vector3(rng.randf_range(-0.1, 0.1), top, rng.randf_range(-0.1, 0.1))
		var rim: Array[Vector3] = []
		var turn := rng.randf() * TAU
		for n in spikes * 2:
			var a := turn + TAU * n / (spikes * 2)
			var out := n % 2 == 0
			var r := radius * (1.0 if out else 0.62) * rng.randf_range(0.88, 1.08)
			# Spike tips droop below the tier line; notches sit higher.
			var y := bottom - (0.45 if out else -0.15) * rng.randf_range(0.7, 1.2)
			rim.append(Vector3(cos(a) * r, y, sin(a) * r))
		for n in rim.size():
			var a := rim[n]
			var b := rim[(n + 1) % rim.size()]
			leaves.add_vertex(apex); leaves.add_vertex(b); leaves.add_vertex(a)
			# Underside so the skirt is closed from below (the camera sees under tiers on slopes).
			leaves.add_vertex(Vector3(0, bottom + 0.3, 0)); leaves.add_vertex(a); leaves.add_vertex(b)
	leaves.generate_normals()
	leaves.set_material(MangaArt.world_preset("leaves"))
	leaves.commit(mesh)
	return mesh


## A roadside bush: a clump of a few small jagged cones.
static func bush_mesh(seed_ := 0) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2000 + seed_
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in rng.randi_range(3, 5):
		var center := Vector3(rng.randf_range(-0.7, 0.7), 0.0, rng.randf_range(-0.7, 0.7))
		var h := rng.randf_range(0.9, 1.6)
		var r := rng.randf_range(0.5, 0.9)
		var apex := center + Vector3(0, h, 0)
		var rim: Array[Vector3] = []
		for n in 14:
			var a := TAU * n / 14.0
			var rr := r * (1.0 if n % 2 == 0 else 0.65)
			rim.append(center + Vector3(cos(a) * rr, rng.randf_range(0.0, 0.25), sin(a) * rr))
		for n in rim.size():
			st.add_vertex(apex); st.add_vertex(rim[(n + 1) % rim.size()]); st.add_vertex(rim[n])
	st.generate_normals()
	st.set_material(MangaArt.world_preset("bush"))
	return st.commit()


## A grass tuft: a fan of thin tapered blades leaning outward, double-sided.
static func grass_mesh(seed_ := 0) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3000 + seed_
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in 9:
		var a := rng.randf() * TAU
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x) * rng.randf_range(0.025, 0.045)
		var root := dir * rng.randf_range(0.0, 0.15)
		var h := rng.randf_range(0.35, 0.75)
		var tip := root + dir * rng.randf_range(0.12, 0.35) + Vector3(0, h, 0)
		for v in [root - side, root + side, tip, root + side, root - side, tip]:
			st.add_vertex(v)
	st.generate_normals()
	st.set_material(MangaArt.world_preset("grass"))
	return st.commit()
