class_name TrackBuilder
extends RefCounted
## Builds a touge map from a segment layout: road ribbon (crown, banking, gutters, shoulders),
## cut walls and fill drops, conforming terrain, guardrails, trees, start/finish gantries and the
## `TrackData` centerline. Run offline by `tools/build_map.gd`; the result is a saved scene.
##
## Layout segments: { "s": length_m } straight, or { "r": radius_m, "a": degrees } arc (a > 0 turns
## right), each with "g": grade (rise/run, negative = downhill). An arc may set "camber": signed
## cross-slope toward the inside (negative = off-camber).

const SPACING := 1.0
const LANE := 3.0
const SHOULDER := 3.3
const MAX_SKIRT := 14.0
const CROWN := 0.02
const MAX_BANK := 0.055
const TERRAIN_STEP := 4.0
const TERRAIN_MARGIN := 260.0

enum Side { CUT, FILL }
enum Mat { ASPHALT, CONCRETE, GRAVEL, ROCK, DIRT }

var layout: Array
var seed_ := 7
## Cross-slope of the mountainside the road is cut into (rise/run).
var sidehill := 0.45

# Per-sample data.
var pts := PackedVector3Array()
var fwd := PackedVector3Array()
var rgt := PackedVector3Array()
var curvature := PackedFloat64Array()
var bank := PackedFloat64Array()
## Per sample: [left side, right side] classification and skirt reach.
var side_type: Array[PackedInt32Array] = []
var skirt: Array[PackedFloat64Array] = []

var _noise := FastNoiseLite.new()
var _plane := Vector3.ZERO   # h = a·x + b·z + c (fitted to the road)
var _uphill := Vector2.ZERO  # horizontal unit vector up the mountain
var _centroid := Vector3.ZERO
var _hash := {}
const HASH_CELL := 24.0


func _init(layout_: Array, seed__ := 7) -> void:
	layout = layout_
	seed_ = seed__
	_noise.seed = seed_
	_noise.frequency = 0.004
	_noise.fractal_octaves = 4


# --- Centerline ---------------------------------------------------------------------------------

func build_centerline() -> void:
	var kappas := PackedFloat64Array()
	var grades := PackedFloat64Array()
	var cambers := PackedFloat64Array()
	for seg in layout:
		var n: int
		var k := 0.0
		if seg.has("s"):
			n = roundi(seg["s"] / SPACING)
		else:
			var angle := deg_to_rad(seg["a"])
			n = roundi(absf(angle) * seg["r"] / SPACING)
			k = signf(angle) / seg["r"]
		for i in n:
			kappas.append(k)
			grades.append(seg["g"])
			cambers.append(seg.get("camber", NAN))
	# Moving averages make clothoid-like curve entries and smooth vertical transitions;
	# both preserve the integral (total turn and total drop).
	kappas = _smooth(kappas, 14)
	grades = _smooth(grades, 30)
	curvature = kappas
	var pos := Vector3.ZERO
	var heading := Vector2(0, -1)   # x, z; start northbound
	pts.clear()
	for i in kappas.size():
		pts.append(pos)
		var a := kappas[i] * SPACING
		heading = Vector2(heading.x * cos(a) - heading.y * sin(a), heading.x * sin(a) + heading.y * cos(a)).normalized()
		pos += Vector3(heading.x, grades[i], heading.y) * SPACING
	pts.append(pos)
	curvature.append(curvature[curvature.size() - 1])
	var n := pts.size()
	fwd.resize(n)
	rgt.resize(n)
	bank.resize(n)
	for i in n:
		var f := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		fwd[i] = f
		rgt[i] = f.cross(Vector3.UP).normalized()
	# Superelevation: inside of the corner lower, ramped in by smoothing, capped for hairpins.
	var raw := PackedFloat64Array()
	for i in n:
		var c: float = cambers[mini(i, cambers.size() - 1)]
		if is_nan(c):
			raw.append(clampf(curvature[i] * 3.2, -MAX_BANK, MAX_BANK))
		else:
			raw.append(c * signf(curvature[i]))
	bank = _smooth(raw, 20)
	_fit_plane()
	_build_hash()


static func _smooth(values: PackedFloat64Array, half: int) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(values.size())
	var prefix := PackedFloat64Array([0.0])
	for v in values:
		prefix.append(prefix[prefix.size() - 1] + v)
	for i in values.size():
		var lo := maxi(0, i - half)
		var hi := mini(values.size(), i + half + 1)
		out[i] = (prefix[hi] - prefix[lo]) / (hi - lo)
	return out


## Smallest horizontal distance between road samples more than `gap` metres apart along the road.
func min_leg_clearance(gap := 80.0) -> Dictionary:
	var best := INF
	var at := Vector2i.ZERO
	var step := 3
	for i in range(0, pts.size(), step):
		for j in range(i + int(gap / SPACING), pts.size(), step):
			var d := Vector2(pts[i].x - pts[j].x, pts[i].z - pts[j].z).length()
			if d < best:
				best = d
				at = Vector2i(i, j)
	return { "distance": best, "a": at.x, "b": at.y }


# --- Terrain model ------------------------------------------------------------------------------

func _fit_plane() -> void:
	# Least squares h = a x + b z + c over the road: the mountain's average fall line.
	var sxx := 0.0; var sxz := 0.0; var szz := 0.0; var sxh := 0.0; var szh := 0.0
	_centroid = Vector3.ZERO
	for p in pts:
		_centroid += p
	_centroid /= pts.size()
	for p in pts:
		var x := p.x - _centroid.x
		var z := p.z - _centroid.z
		var h := p.y - _centroid.y
		sxx += x * x; sxz += x * z; szz += z * z; sxh += x * h; szh += z * h
	var det := sxx * szz - sxz * sxz
	_plane = Vector3((sxh * szz - szh * sxz) / det, (szh * sxx - sxh * sxz) / det, 0.0)
	_uphill = Vector2(_plane.x, _plane.y).normalized()


## Natural mountainside height before the road is cut in. Each road sample predicts a sidehill
## through itself (rising toward the mountain's uphill direction); predictions are blended by
## inverse distance so terrain flows smoothly between switchback legs instead of stepping.
## `_i` is accepted for call-site symmetry; the blend does not depend on it.
func natural_height(x: float, z: float, _i := -1) -> float:
	var sum := 0.0
	var weight := 0.0
	var nearest := INF
	for k in range(0, pts.size(), 6):
		var p := pts[k]
		var rel := Vector2(x - p.x, z - p.z)
		var d2 := rel.length_squared()
		nearest = minf(nearest, d2)
		var w := 1.0 / ((d2 + 100.0) * (d2 + 100.0))
		var d := sqrt(d2)
		var slope := lerpf(sidehill, sidehill * 0.6, smoothstep(40.0, 200.0, d))
		sum += w * (p.y + rel.dot(_uphill) * slope)
		weight += w
	return sum / weight + _noise.get_noise_2d(x, z) * 7.0 * smoothstep(8.0, 40.0, sqrt(nearest))


## Nearest sample by brute force over every 4th sample (for points beyond the hash window).
func nearest_far(x: float, z: float) -> int:
	var best := 0
	var best_d := INF
	for i in range(0, pts.size(), 4):
		var d := Vector2(pts[i].x - x, pts[i].z - z).length_squared()
		if d < best_d:
			best_d = d
			best = i
	return best


func _build_hash() -> void:
	_hash.clear()
	for i in pts.size():
		var key := Vector2i(floori(pts[i].x / HASH_CELL), floori(pts[i].z / HASH_CELL))
		# Packed arrays are values: append to a copy and store it back.
		var bucket: PackedInt32Array = _hash.get(key, PackedInt32Array())
		bucket.append(i)
		_hash[key] = bucket


## Nearest road sample within ~2 hash cells, or -1.
func nearest_sample(x: float, z: float) -> int:
	var cx := floori(x / HASH_CELL)
	var cz := floori(z / HASH_CELL)
	var best := -1
	var best_d := INF
	for ox in range(-2, 3):
		for oz in range(-2, 3):
			var bucket = _hash.get(Vector2i(cx + ox, cz + oz))
			if bucket == null:
				continue
			for i in bucket:
				var d := Vector2(pts[i].x - x, pts[i].z - z).length_squared()
				if d < best_d:
					best_d = d
					best = i
	return best


## Terrain height shaped around road sample `i`: cut walls rise fast, fills fall away slower.
func shaped_height(i: int, x: float, z: float) -> float:
	var p := pts[i]
	var lateral := Vector2(x - p.x, z - p.z).dot(Vector2(rgt[i].x, rgt[i].z))
	var d := Vector2(x - p.x, z - p.z).length()
	var side := 1 if lateral >= 0.0 else 0
	var natural := natural_height(x, z, i)
	var cut := side_type[i][side] == Side.CUT
	var w := smoothstep(4.5, 14.0, d) if cut else smoothstep(4.5, 26.0, d)
	return lerpf(p.y - 0.35, natural, w)


func terrain_height(x: float, z: float) -> float:
	var i := nearest_sample(x, z)
	if i < 0:
		return natural_height(x, z)
	var h := shaped_height(i, x, z)
	# Keep the terrain under the road's own geometry; the skirts cover the seam.
	var d := Vector2(x - pts[i].x, z - pts[i].z).length()
	var lateral := Vector2(x - pts[i].x, z - pts[i].z).dot(Vector2(rgt[i].x, rgt[i].z))
	var reach := skirt[i][1 if lateral >= 0.0 else 0]
	if d < reach - 1.5:
		h = minf(h, pts[i].y - 0.45)
	return h


func classify_sides() -> void:
	side_type.clear()
	skirt.clear()
	var raw: Array[PackedInt32Array] = []
	for i in pts.size():
		var t := PackedInt32Array([0, 0])
		for side in 2:
			var s := 1.0 if side == 1 else -1.0
			var probe := pts[i] + rgt[i] * s * 12.0
			t[side] = Side.CUT if natural_height(probe.x, probe.z, i) > pts[i].y + 0.5 else Side.FILL
		raw.append(t)
	# Majority filter so walls and drops don't flicker sample to sample.
	for i in pts.size():
		var t := PackedInt32Array([0, 0])
		for side in 2:
			var cuts := 0
			var total := 0
			for j in range(maxi(0, i - 10), mini(pts.size(), i + 11)):
				total += 1
				cuts += 1 if raw[j][side] == Side.CUT else 0
			t[side] = Side.CUT if cuts * 2 > total else Side.FILL
		side_type.append(t)
	# Skirt reach: stop halfway to any other leg of the road (hairpins, switchbacks).
	for i in pts.size():
		var reach := PackedFloat64Array([MAX_SKIRT, MAX_SKIRT])
		for side in 2:
			var s := 1.0 if side == 1 else -1.0
			for j in range(0, pts.size(), 2):
				if absi(j - i) < 40:
					continue
				var rel := pts[j] - pts[i]
				rel.y = 0.0
				if rel.length() > 2.0 * MAX_SKIRT + 8.0 or rel.dot(rgt[i]) * s <= 0.0:
					continue
				reach[side] = minf(reach[side], maxf(5.2, rel.length() / 2.0 - 4.0))
		skirt.append(reach)
	# Smooth reach changes along the road.
	for side in 2:
		var values := PackedFloat64Array()
		for r in skirt:
			values.append(r[side])
		var smoothed := _smooth(values, 6)
		for i in pts.size():
			skirt[i][side] = minf(skirt[i][side], smoothed[i])


# --- Road mesh ----------------------------------------------------------------------------------

## Cross-section for one side: lateral offsets and heights relative to the centerline, plus the
## material of each span (from the previous point).
func _side_profile(i: int, side: int) -> Dictionary:
	var s := 1.0 if side == 1 else -1.0
	var e := bank[i]
	# Road surface height at lateral x (right +): crown on straights, a plane when banked.
	var surface := func(x: float) -> float:
		var crowned := -CROWN * absf(x)
		var banked := -e * x
		return lerpf(crowned, banked, smoothstep(0.0, 0.025, absf(e)))
	var reach := skirt[i][side]
	var end_point := pts[i] + rgt[i] * s * reach
	var end_h := shaped_height(i, end_point.x, end_point.z) - pts[i].y
	var edge: float = surface.call(s * SHOULDER)
	var offsets: PackedFloat64Array
	var heights: PackedFloat64Array
	var mats: PackedInt32Array
	if side_type[i][side] == Side.CUT:
		# Gutter (mizo) along the mountain side, then the cut wall.
		var rise := maxf(end_h - edge, 0.8)
		var wall_x := minf(4.5, reach - 0.2)
		offsets = [LANE, SHOULDER, 3.36, 3.66, 3.78, wall_x, reach]
		heights = [surface.call(s * LANE), edge, edge - 0.25, edge - 0.25, edge + 0.05, edge + rise * 0.65, edge + rise]
		mats = [Mat.ASPHALT, Mat.ASPHALT, Mat.CONCRETE, Mat.CONCRETE, Mat.CONCRETE, Mat.ROCK, Mat.ROCK]
	else:
		var drop := minf(end_h - edge, -0.3)
		var lip_x := minf(4.8, reach - 0.2)
		offsets = [LANE, SHOULDER, 3.6, 3.9, 4.25, lip_x, reach]
		heights = [surface.call(s * LANE), edge, edge - 0.02, edge - 0.04, edge - 0.08, edge - 0.15 + drop * 0.25, edge + drop]
		mats = [Mat.ASPHALT, Mat.ASPHALT, Mat.GRAVEL, Mat.GRAVEL, Mat.GRAVEL, Mat.DIRT, Mat.DIRT]
	return { "offsets": offsets, "heights": heights, "mats": mats }


## Full ring, left edge to right edge: world positions, lateral offsets (signed) and span materials.
func _ring(i: int) -> Dictionary:
	var left := _side_profile(i, 0)
	var right := _side_profile(i, 1)
	var positions := PackedVector3Array()
	var lats := PackedFloat64Array()
	var mats := PackedInt32Array()
	var n: int = left["offsets"].size()
	for k in range(n - 1, -1, -1):
		var x: float = -left["offsets"][k]
		positions.append(pts[i] + rgt[i] * x + Vector3.UP * left["heights"][k])
		lats.append(x)
		mats.append(left["mats"][k])  # material of the span toward the centre
	positions.append(pts[i])
	lats.append(0.0)
	mats.append(Mat.ASPHALT)
	for k in n:
		var x: float = right["offsets"][k]
		positions.append(pts[i] + rgt[i] * x + Vector3.UP * right["heights"][k])
		lats.append(x)
		mats.append(right["mats"][k])  # material of the span from the previous point
	return { "positions": positions, "lats": lats, "mats": mats }


func build_road_mesh() -> ArrayMesh:
	var tools: Array[SurfaceTool] = []
	for m in Mat.size():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools.append(st)
	var rings: Array[Dictionary] = []
	for i in pts.size():
		rings.append(_ring(i))
	var center: int = (rings[0]["positions"] as PackedVector3Array).size() / 2
	for i in pts.size() - 1:
		var a: Dictionary = rings[i]
		var b: Dictionary = rings[i + 1]
		var pa: PackedVector3Array = a["positions"]
		var pb: PackedVector3Array = b["positions"]
		var la: PackedFloat64Array = a["lats"]
		var lb: PackedFloat64Array = b["lats"]
		var ma: PackedInt32Array = a["mats"]
		var va := i * SPACING
		var vb := (i + 1) * SPACING
		for k in pa.size() - 1:
			# Span k joins point k and k+1; its material is stored on the outer point.
			var mat: int = ma[k] if k < center else ma[k + 1]
			var st := tools[mat]
			var uv_scale := 1.0 if mat == Mat.ASPHALT else 0.5
			var quad := [
				[pa[k], Vector2(la[k], va)], [pb[k], Vector2(lb[k], vb)], [pb[k + 1], Vector2(lb[k + 1], vb)],
				[pa[k], Vector2(la[k], va)], [pb[k + 1], Vector2(lb[k + 1], vb)], [pa[k + 1], Vector2(la[k + 1], va)],
			]
			for v in quad:
				st.set_uv((v[1] as Vector2) * uv_scale)
				st.add_vertex(v[0])
	var mesh := ArrayMesh.new()
	var materials := TrackMaterials.road_set()
	for m in Mat.size():
		var st := tools[m]
		st.generate_normals()
		st.generate_tangents()
		st.set_material(materials[m])
		st.commit(mesh)
	return mesh


# --- Terrain ------------------------------------------------------------------------------------

func terrain_bounds() -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	lo -= Vector2.ONE * TERRAIN_MARGIN
	hi += Vector2.ONE * TERRAIN_MARGIN
	return Rect2(lo, hi - lo)


## Heights on a regular grid (row-major, x fastest), shared by the mesh and HeightMapShape3D.
func terrain_heights(bounds: Rect2) -> Dictionary:
	var w := int(ceil(bounds.size.x / TERRAIN_STEP)) + 1
	var d := int(ceil(bounds.size.y / TERRAIN_STEP)) + 1
	var heights := PackedFloat32Array()
	heights.resize(w * d)
	for zi in d:
		for xi in w:
			heights[zi * w + xi] = terrain_height(bounds.position.x + xi * TERRAIN_STEP, bounds.position.y + zi * TERRAIN_STEP)
	return { "width": w, "depth": d, "heights": heights }


func build_terrain_mesh(bounds: Rect2, grid: Dictionary) -> ArrayMesh:
	var w: int = grid["width"]
	var d: int = grid["depth"]
	var heights: PackedFloat32Array = grid["heights"]
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.resize(w * d)
	uvs.resize(w * d)
	for zi in d:
		for xi in w:
			var x := bounds.position.x + xi * TERRAIN_STEP
			var z := bounds.position.y + zi * TERRAIN_STEP
			verts[zi * w + xi] = Vector3(x, heights[zi * w + xi], z)
			uvs[zi * w + xi] = Vector2(x, z) / 8.0
	var indices := PackedInt32Array()
	for zi in d - 1:
		for xi in w - 1:
			var a := zi * w + xi
			indices.append_array([a, a + 1, a + w, a + 1, a + w + 1, a + w])
	var normals := PackedVector3Array()
	normals.resize(w * d)
	for zi in d:
		for xi in w:
			var hl := heights[zi * w + maxi(xi - 1, 0)]
			var hr := heights[zi * w + mini(xi + 1, w - 1)]
			var hd := heights[maxi(zi - 1, 0) * w + xi]
			var hu := heights[mini(zi + 1, d - 1) * w + xi]
			normals[zi * w + xi] = Vector3(hl - hr, 2.0 * TERRAIN_STEP, hd - hu).normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, TrackMaterials.terrain())
	return mesh


# --- Guardrails ---------------------------------------------------------------------------------

## Runs of samples on the drop side that need a rail: real drops and the outside of tight corners.
func guardrail_runs() -> Array[Dictionary]:
	var runs: Array[Dictionary] = []
	for side in 2:
		var s := 1.0 if side == 1 else -1.0
		var start := -1
		for i in pts.size():
			var outside_tight := curvature[i] * s < -1.0 / 40.0
			var need := side_type[i][side] == Side.FILL or outside_tight
			if need and side_type[i][side] == Side.CUT:
				need = false   # a wall is its own barrier
			if need and start < 0:
				start = i
			elif not need and start >= 0:
				if i - start > 12:
					runs.append({ "side": side, "from": start, "to": i - 1 })
				start = -1
		if start >= 0 and pts.size() - start > 12:
			runs.append({ "side": side, "from": start, "to": pts.size() - 1 })
	return runs


func rail_base(i: int, side: int) -> Vector3:
	var prof := _side_profile(i, side)
	var s := 1.0 if side == 1 else -1.0
	return pts[i] + rgt[i] * s * 3.9 + Vector3.UP * prof["heights"][3]


func build_guardrails(parent: Node3D, owner: Node) -> void:
	var beam_tool := SurfaceTool.new()
	beam_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall_faces := PackedVector3Array()
	var posts: Array[Transform3D] = []
	for run in guardrail_runs():
		var side: int = run["side"]
		var s := 1.0 if side == 1 else -1.0
		var prev_low := Vector3.ZERO
		var prev_high := Vector3.ZERO
		var prev_wall_low := Vector3.ZERO
		var prev_wall_high := Vector3.ZERO
		for i in range(run["from"], run["to"] + 1):
			var base := rail_base(i, side)
			var low := base + Vector3.UP * 0.5
			var high := base + Vector3.UP * 0.8
			var wall_low := base - Vector3.UP * 0.3
			var wall_high := base + Vector3.UP * 1.0
			if i > run["from"]:
				# W-beam face toward the road (double sided via material).
				for v in [prev_low, low, high, prev_low, high, prev_high, prev_low, high, low, prev_low, prev_high, high]:
					beam_tool.add_vertex(v)
				wall_faces.append_array([prev_wall_low, wall_low, wall_high, prev_wall_low, wall_high, prev_wall_high])
			prev_low = low; prev_high = high; prev_wall_low = wall_low; prev_wall_high = wall_high
			if (i - run["from"]) % 2 == 0:
				var basis := Basis.looking_at(fwd[i] * Vector3(1, 0, 1), Vector3.UP)
				posts.append(Transform3D(basis, base + rgt[i] * s * 0.12 + Vector3.UP * 0.4))
	beam_tool.generate_normals()
	beam_tool.set_material(TrackMaterials.guardrail())
	var beam := MeshInstance3D.new()
	beam.name = "GuardrailBeams"
	beam.mesh = beam_tool.commit()
	parent.add_child(beam)
	beam.owner = owner
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.1, 0.9, 0.1)
	post_mesh.material = MangaArt.world_preset("post")
	var post_instance := Scatter.make("GuardrailPosts", post_mesh, posts)
	parent.add_child(post_instance)
	post_instance.owner = owner
	var body := StaticBody3D.new()
	body.name = "GuardrailCollision"
	body.collision_layer = CarBody.STATIC_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var concave := ConcavePolygonShape3D.new()
	concave.backface_collision = true
	concave.set_faces(wall_faces)
	shape.shape = concave
	body.add_child(shape)
	parent.add_child(body)
	body.owner = owner
	shape.owner = owner


# --- Trees --------------------------------------------------------------------------------------

func build_trees(parent: Node3D, owner: Node, bounds: Rect2, grid: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 31 + 5
	var transforms: Array[Transform3D] = []
	var attempts := int(bounds.get_area() / 90.0)
	for n in attempts:
		var x := rng.randf_range(bounds.position.x, bounds.end.x)
		var z := rng.randf_range(bounds.position.y, bounds.end.y)
		var i := nearest_sample(x, z)
		var d := INF if i < 0 else Vector2(pts[i].x - x, pts[i].z - z).length()
		if d < 17.0:
			continue
		# Forest thins out far from the road to keep the draw count down.
		if d > 70.0 and rng.randf() > 0.35:
			continue
		var h := _grid_height(bounds, grid, x, z)
		var scale := rng.randf_range(0.8, 1.35)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(scale, scale * rng.randf_range(0.9, 1.2), scale))
		transforms.append(Transform3D(basis, Vector3(x, h - 0.2, z)))
	print("trees: %d" % transforms.size())
	var trees := Scatter.make_chunked("Trees", TrackMaterials.cedar_mesh(), transforms)
	parent.add_child(trees)
	trees.owner = owner
	for part in trees.get_children():
		(part as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.owner = owner


static func _grid_height(bounds: Rect2, grid: Dictionary, x: float, z: float) -> float:
	var w: int = grid["width"]
	var d: int = grid["depth"]
	var heights: PackedFloat32Array = grid["heights"]
	var fx := (x - bounds.position.x) / TERRAIN_STEP
	var fz := (z - bounds.position.y) / TERRAIN_STEP
	var xi := clampi(int(fx), 0, w - 2)
	var zi := clampi(int(fz), 0, d - 2)
	var tx := fx - xi
	var tz := fz - zi
	var h00 := heights[zi * w + xi]
	var h10 := heights[zi * w + xi + 1]
	var h01 := heights[(zi + 1) * w + xi]
	var h11 := heights[(zi + 1) * w + xi + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


# --- Gantries -----------------------------------------------------------------------------------

func build_gantry(parent: Node3D, owner: Node, distance: float, label: String, color: Color) -> void:
	var i := clampi(roundi(distance / SPACING), 0, pts.size() - 1)
	var root := Node3D.new()
	root.name = label.capitalize().replace(" ", "") + "Gantry"
	root.transform = Transform3D(Basis.looking_at(fwd[i] * Vector3(1, 0, 1), Vector3.UP), pts[i])
	parent.add_child(root)
	root.owner = owner
	var mat := MangaArt.accent(color)
	var post_mat := MangaArt.world_preset("post")
	for x in [-4.6, 4.6]:
		var post := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.25, 5.2, 0.25)
		box.material = post_mat
		post.mesh = box
		post.position = Vector3(x, 2.6, 0)
		root.add_child(post)
		post.owner = owner
	var banner := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(9.4, 0.9, 0.15)
	bm.material = mat
	banner.mesh = bm
	banner.position = Vector3(0, 4.9, 0)
	root.add_child(banner)
	banner.owner = owner
	var text := Label3D.new()
	text.text = label
	text.font_size = 96
	text.pixel_size = 0.006
	text.modulate = MangaArt.PAPER
	text.outline_modulate = MangaArt.INK
	text.outline_size = 24
	text.position = Vector3(0, 4.9, 0.1)
	text.rotation.y = PI   # face oncoming cars
	root.add_child(text)
	text.owner = owner


# --- Track data ---------------------------------------------------------------------------------

func track_data(start_distance: float, finish_back: float) -> TrackData:
	var data := TrackData.new()
	data.points = pts
	data.forwards = fwd
	data.rights = rgt
	data.spacing = SPACING
	data.half_width = SHOULDER
	data.start_distance = start_distance
	data.finish_distance = (pts.size() - 1) * SPACING - finish_back
	return data


# --- Backdrop ----------------------------------------------------------------------------------

## Two rings of distant ridges around the map: light-gray silhouettes that give the page depth
## (near ridge a little darker than the far one) and an ink skyline from the page pass.
func build_backdrop(parent: Node3D, owner: Node, bounds: Rect2) -> void:
	var center := bounds.get_center()
	var low := INF
	for p in pts:
		low = minf(low, p.y)
	var noise := FastNoiseLite.new()
	noise.seed = seed_ + 99
	noise.frequency = 1.6
	noise.fractal_octaves = 3
	var rings := [
		{ "name": "RidgeNear", "radius": bounds.size.length() * 0.5 + 180.0, "base": low - 40.0, "height": 140.0, "vary": 170.0, "far_value": 0.78 },
		{ "name": "RidgeFar", "radius": bounds.size.length() * 0.5 + 700.0, "base": low - 60.0, "height": 300.0, "vary": 260.0, "far_value": 0.88 },
	]
	for ring in rings:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var segments := 240
		var prev_base := Vector3.ZERO
		var prev_peak := Vector3.ZERO
		for k in segments + 1:
			var a := TAU * k / segments
			var dir := Vector3(cos(a), 0.0, sin(a))
			var r: float = ring["radius"]
			var h: float = ring["height"] + (noise.get_noise_1d(float(k) / segments * 6.0 + ring["radius"]) * 0.5 + 0.5) * ring["vary"]
			var base := Vector3(center.x, ring["base"], center.y) + dir * r
			var peak := Vector3(center.x, ring["base"] + h, center.y) + dir * (r + h * 0.9)
			if k > 0:
				# Both windings: the ridge is seen from inside the ring.
				for v in [prev_base, prev_peak, peak, prev_base, peak, base, prev_base, peak, prev_peak, prev_base, base, peak]:
					st.add_vertex(v)
			prev_base = base
			prev_peak = peak
		st.generate_normals()
		var m := MangaArt.world_preset("backdrop")
		m.set_shader_parameter("far_value", ring["far_value"])
		st.set_material(m)
		var mi := MeshInstance3D.new()
		mi.name = ring["name"]
		mi.mesh = st.commit()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		mi.owner = owner
