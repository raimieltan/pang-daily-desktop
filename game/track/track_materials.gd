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


## Adds a double-sided quad strip along `spine` (points) with half-widths `widths`, sideways `side`.
static func _strip(st: SurfaceTool, spine: Array[Vector3], widths: Array[float], side: Vector3) -> void:
	for k in range(1, spine.size()):
		var a0: Vector3 = spine[k - 1] - side * widths[k - 1]
		var a1: Vector3 = spine[k - 1] + side * widths[k - 1]
		var b0: Vector3 = spine[k] - side * widths[k]
		var b1: Vector3 = spine[k] + side * widths[k]
		for v in [a0, b0, b1, a0, b1, a1, a0, b1, b0, a0, a1, b1]:
			st.add_vertex(v)


## An arching leaf/frond spine from `root`, heading `yaw`, rising at `lift` and drooping along
## its length: `n` points over `length` metres.
static func _arc(root: Vector3, yaw: float, lift: float, droop: float, length: float, n: int) -> Array[Vector3]:
	var out: Array[Vector3] = [root]
	var dir2 := Vector2(cos(yaw), sin(yaw))
	var p := root
	for k in range(1, n):
		var t := float(k) / (n - 1)
		var pitch := lift - droop * t
		var step := length / (n - 1)
		p += Vector3(dir2.x * cos(pitch), sin(pitch), dir2.y * cos(pitch)) * step
		out.append(p)
	return out


## A banana plant: a few pseudostems, each crowned with broad paddle leaves arching out and
## drooping, their edges torn (the tattered silhouette reads instantly as banana).
static func banana_mesh(seed_ := 0) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4000 + seed_
	var mesh := ArrayMesh.new()
	var stems := SurfaceTool.new()
	stems.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in rng.randi_range(2, 3):
		var base := Vector3(rng.randf_range(-0.6, 0.6), 0.0, rng.randf_range(-0.6, 0.6))
		var h := rng.randf_range(2.2, 3.2)
		var stem := CylinderMesh.new()
		stem.top_radius = 0.1
		stem.bottom_radius = 0.17
		stem.height = h
		stem.radial_segments = 6
		stem.rings = 1
		stems.append_from(stem, 0, Transform3D(Basis(), base + Vector3(0, h * 0.5, 0)))
		var top := base + Vector3(0, h, 0)
		var count := rng.randi_range(6, 9)
		for l in count:
			var yaw := TAU * l / count + rng.randf_range(-0.3, 0.3)
			var spine := _arc(top, yaw, rng.randf_range(0.7, 1.1), rng.randf_range(1.2, 2.0), rng.randf_range(1.8, 2.6), 7)
			var widths: Array[float] = []
			for k in spine.size():
				var t := float(k) / (spine.size() - 1)
				var w := sin(PI * minf(t * 1.15, 1.0)) * 0.32
				# Torn edge: notch every other point toward the tip.
				widths.append(w * (0.55 if k % 2 == 1 and t > 0.3 else 1.0))
			_strip(leaves, spine, widths, Vector3(-sin(yaw), 0, cos(yaw)))
	stems.generate_normals()
	stems.set_material(MangaArt.world_preset("bush"))
	stems.commit(mesh)
	leaves.generate_normals()
	leaves.set_material(MangaArt.world_preset("bush"))
	leaves.commit(mesh)
	return mesh


## A coconut palm: a slender trunk leaning on a gentle curve, a crown of long drooping fronds with
## serrated (leaflet) edges, and a cluster of nuts under the crown.
static func palm_mesh(seed_ := 0) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5000 + seed_
	var mesh := ArrayMesh.new()
	var trunk := SurfaceTool.new()
	trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
	var height := rng.randf_range(9.0, 13.0)
	var lean := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.8, 2.2)
	var segments := 6
	var prev := Vector3.ZERO
	for k in range(1, segments + 1):
		var t := float(k) / segments
		var p := Vector3(lean.x * t * t, height * t, lean.y * t * t)
		var seg := CylinderMesh.new()
		seg.top_radius = lerpf(0.2, 0.14, t)
		seg.bottom_radius = lerpf(0.2, 0.14, t - 1.0 / segments) + 0.01
		seg.height = (p - prev).length()
		seg.radial_segments = 6
		seg.rings = 1
		var up := (p - prev).normalized()
		var axis := Vector3.UP.cross(up)
		var basis := Basis() if axis.length() < 1e-4 else Basis(axis.normalized(), Vector3.UP.angle_to(up))
		trunk.append_from(seg, 0, Transform3D(basis, (p + prev) * 0.5))
		prev = p
	trunk.generate_normals()
	trunk.set_material(MangaArt.world_preset("trunk"))
	trunk.commit(mesh)
	var fronds := SurfaceTool.new()
	fronds.begin(Mesh.PRIMITIVE_TRIANGLES)
	var crown := prev
	var count := rng.randi_range(10, 14)
	for f in count:
		var yaw := TAU * f / count + rng.randf_range(-0.2, 0.2)
		var spine := _arc(crown, yaw, rng.randf_range(0.4, 0.9), rng.randf_range(1.6, 2.4), rng.randf_range(3.6, 4.8), 11)
		var widths: Array[float] = []
		for k in spine.size():
			var t := float(k) / (spine.size() - 1)
			# Leaflets: alternate wide/narrow along the frond for a feathery serrated edge.
			widths.append(sin(PI * minf(t * 1.1, 1.0)) * (0.55 if k % 2 == 0 else 0.22))
		_strip(fronds, spine, widths, Vector3(-sin(yaw), 0, cos(yaw)))
	fronds.generate_normals()
	fronds.set_material(MangaArt.world_preset("leaves"))
	fronds.commit(mesh)
	var nuts := SurfaceTool.new()
	nuts.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nut := SphereMesh.new()
	nut.radius = 0.16
	nut.height = 0.32
	nut.radial_segments = 6
	nut.rings = 3
	for k in rng.randi_range(3, 6):
		var a := TAU * k / 6.0
		nuts.append_from(nut, 0, Transform3D(Basis(), crown + Vector3(cos(a) * 0.25, -0.3 - (k % 2) * 0.15, sin(a) * 0.25)))
	nuts.generate_normals()
	nuts.set_material(MangaArt.world_preset("trunk"))
	nuts.commit(mesh)
	return mesh


## A bamboo clump: thin culms fanning out from one root and arching over, with sprays of narrow
## leaves along their upper half.
static func bamboo_mesh(seed_ := 0) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6000 + seed_
	var mesh := ArrayMesh.new()
	var culms := SurfaceTool.new()
	culms.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := rng.randi_range(12, 20)
	for c in count:
		var yaw := rng.randf() * TAU
		var root := Vector3(cos(yaw), 0, sin(yaw)) * rng.randf_range(0.0, 0.7)
		var length := rng.randf_range(6.0, 10.0)
		var spine := _arc(root, yaw, deg_to_rad(rng.randf_range(72.0, 86.0)), deg_to_rad(rng.randf_range(25.0, 55.0)), length, 6)
		for k in range(1, spine.size()):
			var a: Vector3 = spine[k - 1]
			var b: Vector3 = spine[k]
			var seg := CylinderMesh.new()
			seg.top_radius = 0.045
			seg.bottom_radius = 0.06
			seg.height = a.distance_to(b)
			seg.radial_segments = 5
			seg.rings = 1
			var up := (b - a).normalized()
			var axis := Vector3.UP.cross(up)
			var basis := Basis() if axis.length() < 1e-4 else Basis(axis.normalized(), Vector3.UP.angle_to(up))
			culms.append_from(seg, 0, Transform3D(basis, (a + b) * 0.5))
			# Leaf sprays on the upper culm: small fans of narrow blades.
			if k >= 3:
				for n in 3:
					var ly := yaw + rng.randf_range(-1.4, 1.4)
					var blade := _arc(b, ly, rng.randf_range(-0.2, 0.3), 0.6, rng.randf_range(0.7, 1.1), 3)
					var w: Array[float] = [0.02, 0.07, 0.0]
					_strip(leaves, blade, w, Vector3(-sin(ly), 0, cos(ly)))
	culms.generate_normals()
	culms.set_material(MangaArt.world_preset("pole"))
	culms.commit(mesh)
	leaves.generate_normals()
	leaves.set_material(MangaArt.world_preset("leaves"))
	leaves.commit(mesh)
	return mesh
