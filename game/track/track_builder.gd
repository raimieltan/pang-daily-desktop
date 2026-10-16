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
const CITY_LIGHTS_SHADER := preload("res://game/art/manga_city_lights.gdshader")


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
	var flags := surface_flags()
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
			var ca := flags[i]
			var cb := flags[i + 1]
			var quad := [
				[pa[k], Vector2(la[k], va), ca], [pb[k], Vector2(lb[k], vb), cb], [pb[k + 1], Vector2(lb[k + 1], vb), cb],
				[pa[k], Vector2(la[k], va), ca], [pb[k + 1], Vector2(lb[k + 1], vb), cb], [pa[k + 1], Vector2(la[k + 1], va), ca],
			]
			for v in quad:
				st.set_color(v[2])
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


## Per-sample road surface flags for the road shader, as vertex color: r = concrete (steep
## stretches and hairpins are poured concrete, as on many PH mountain roads), g = no overtaking
## (double solid center line through corners; dashed on the straights).
func surface_flags() -> PackedColorArray:
	var n := pts.size()
	var steep := PackedFloat64Array()
	var bends := PackedFloat64Array()
	for i in n:
		var grade := 0.0
		if i > 0:
			grade = (pts[i].y - pts[i - 1].y) / SPACING
		steep.append(1.0 if absf(grade) >= 0.075 or absf(curvature[i]) > 1.0 / 25.0 else 0.0)
		bends.append(absf(curvature[i]))
	# Concrete only in runs long enough to have been poured as a section (40 m+), with a margin.
	var concrete := _smooth(steep, 20)
	var corner := _smooth(bends, 50)
	var out := PackedColorArray()
	for i in n:
		var c := 1.0 if concrete[i] > 0.5 else 0.0
		var no_pass := 1.0 if corner[i] > 1.0 / 220.0 else 0.0
		out.append(Color(c, no_pass, 0.0, 1.0))
	return out


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
			if need and _fronts_lot(i, side):
				need = false   # the lot opens onto the road
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


## Metres of concrete barrier at each end of a guardrail run.
const END_BLOCKS := 4


## A jersey barrier block, 1.9 m long along -Z, sitting on y = 0, centered on x = 0.
static func _jersey_mesh() -> ArrayMesh:
	var profile := [Vector2(-0.3, 0.0), Vector2(-0.3, 0.08), Vector2(-0.15, 0.3), Vector2(-0.1, 0.8),
		Vector2(0.1, 0.8), Vector2(0.15, 0.3), Vector2(0.3, 0.08), Vector2(0.3, 0.0)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := 0.95
	for k in profile.size() - 1:
		var a: Vector2 = profile[k]
		var b: Vector2 = profile[k + 1]
		var a0 := Vector3(a.x, a.y, half); var a1 := Vector3(a.x, a.y, -half)
		var b0 := Vector3(b.x, b.y, half); var b1 := Vector3(b.x, b.y, -half)
		for v in [a0, b0, b1, a0, b1, a1]:
			st.add_vertex(v)
	for z in [half, -half]:
		var c := Vector3(0.0, 0.4, z)
		for k in profile.size() - 1:
			var a: Vector2 = profile[k]
			var b: Vector2 = profile[k + 1]
			var tri := [c, Vector3(a.x, a.y, z), Vector3(b.x, b.y, z)]
			if z < 0.0:
				tri.reverse()
			for v in tri:
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


func build_guardrails(parent: Node3D, owner: Node) -> void:
	var beam_tool := SurfaceTool.new()
	beam_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall_faces := PackedVector3Array()
	var posts: Array[Transform3D] = []
	var blocks := [[] as Array[Transform3D], [] as Array[Transform3D]]
	var block_n := 0
	for run in guardrail_runs():
		var side: int = run["side"]
		var s := 1.0 if side == 1 else -1.0
		var all_concrete: bool = int(run["to"]) - int(run["from"]) < 60
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
			# Concrete end blocks for the first and last few metres; short runs are all concrete.
			var concrete: bool = all_concrete or i - int(run["from"]) < END_BLOCKS or int(run["to"]) - i < END_BLOCKS
			if i > run["from"]:
				if not concrete:
					# W-beam face toward the road (double sided via material).
					for v in [prev_low, low, high, prev_low, high, prev_high, prev_low, high, low, prev_low, prev_high, high]:
						beam_tool.add_vertex(v)
				wall_faces.append_array([prev_wall_low, wall_low, wall_high, prev_wall_low, wall_high, prev_wall_high])
			prev_low = low; prev_high = high; prev_wall_low = wall_low; prev_wall_high = wall_high
			if concrete:
				if (i - int(run["from"])) % 2 == 0 and i + 1 <= int(run["to"]):
					var basis := Basis.looking_at(fwd[i] * Vector3(1, 0, 1), Vector3.UP)
					var at := base + rgt[i] * s * 0.1 + fwd[i] * (SPACING * 0.5)
					blocks[block_n % 2].append(Transform3D(basis, at))
					block_n += 1
				continue
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
	var jersey := _jersey_mesh()
	for k in 2:
		var m := jersey.duplicate() as ArrayMesh
		m.surface_set_material(0, MangaArt.world_preset("board" if k == 0 else "post"))
		var sc := Scatter.make("Barriers%s" % ("White" if k == 0 else "Black"), m, blocks[k])
		parent.add_child(sc)
		sc.owner = owner
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
	# Three cedar (Benguet pine) variants so the forest doesn't repeat one silhouette, then two
	# coconut palm variants that take over below the pine line, on the lower slopes.
	var variants: Array = [[], [], [], [], []]
	var low := INF
	for p in pts:
		low = minf(low, p.y)
	var palm_line := low + 30.0
	var attempts := int(bounds.get_area() / 90.0)
	for n in attempts:
		var x := rng.randf_range(bounds.position.x, bounds.end.x)
		var z := rng.randf_range(bounds.position.y, bounds.end.y)
		var i := nearest_sample(x, z)
		var d := INF if i < 0 else Vector2(pts[i].x - x, pts[i].z - z).length()
		if d < 17.0 or _cleared(x, z):
			continue
		# Forest thins out far from the road to keep the draw count down.
		if d > 70.0 and rng.randf() > 0.35:
			continue
		var h := _grid_height(bounds, grid, x, z)
		var scale := rng.randf_range(0.8, 1.3)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(scale, scale * rng.randf_range(0.9, 1.2), scale))
		var palm_odds := clampf((palm_line - h) / 40.0, 0.0, 0.7)
		var v := 3 + n % 2 if rng.randf() < palm_odds else n % 3
		(variants[v] as Array).append(Transform3D(basis, Vector3(x, h - 0.2, z)))
	var trees := Node3D.new()
	trees.name = "Trees"
	parent.add_child(trees)
	trees.owner = owner
	var total := 0
	for v in 5:
		var xforms: Array[Transform3D] = []
		xforms.assign(variants[v])
		total += xforms.size()
		var mesh := TrackMaterials.cedar_mesh(v) if v < 3 else TrackMaterials.palm_mesh(v - 3)
		var chunked := Scatter.make_chunked(("Cedar%d" % v) if v < 3 else ("Palm%d" % (v - 3)), mesh, xforms)
		trees.add_child(chunked)
		chunked.owner = owner
		for part in chunked.get_children():
			(part as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			part.owner = owner
	print("trees: %d (palms %d)" % [total, variants[3].size() + variants[4].size()])
	_build_undergrowth(parent, owner, bounds, grid, rng)
	_build_tropics(parent, owner, bounds, grid)


## Lowland plants close to the road: banana groves by every house and barrio, bamboo clumps along
## the verges, and patches of tall cogon grass on the drop side.
func _build_tropics(parent: Node3D, owner: Node, bounds: Rect2, grid: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 41 + 9
	var bananas: Array = [[], []]
	var bamboo: Array = [[], []]
	var cogon: Array[Transform3D] = []
	var first_bamboo := -1
	var place := func(list: Array, x: float, z: float, scale: float) -> void:
		var h := _grid_height(bounds, grid, x, z)
		list.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale), Vector3(x, h - 0.1, z)))
	# Bananas: beside and below each roadside lot, and around the barrio clearings.
	for lot in lots:
		if lot["kind"] == "viewpoint":
			continue
		var xf: Transform3D = lot["xform"]
		var half := float(lot["frontage"]) * 0.5
		for k in rng.randi_range(3, 5):
			var local := Vector3(rng.randf_range(-half - 4.0, half + 4.0), 0.0, -float(lot["depth"]) - rng.randf_range(3.0, 7.0))
			if k < 2:
				local = Vector3((half + rng.randf_range(2.5, 4.0)) * (1.0 if k == 0 else -1.0), 0.0, rng.randf_range(-3.0, -1.0))
			var p := xf * local
			if _road_distance(p.x, p.z) > 5.5:
				place.call(bananas[k % 2], p.x, p.z, rng.randf_range(0.9, 1.2))
	for b in barrios:
		for k in int(b.z * 0.4):
			var a := rng.randf() * TAU
			var r := b.z * rng.randf_range(0.6, 1.0)
			place.call(bananas[k % 2], b.x + cos(a) * r, b.y + sin(a) * r, rng.randf_range(0.9, 1.3))
	# Bamboo and cogon along the verges, just past the road's own geometry.
	for i in range(0, pts.size(), 4):
		for side in 2:
			var s := 1.0 if side == 1 else -1.0
			var beyond := skirt[i][side]
			if rng.randf() < 0.1:
				var p := pts[i] + rgt[i] * s * (beyond + rng.randf_range(1.5, 6.0))
				if not _in_lot(p) and _road_distance(p.x, p.z) > beyond:
					place.call(bamboo[rng.randi() % 2], p.x, p.z, rng.randf_range(0.8, 1.15))
					if first_bamboo < 0:
						first_bamboo = i
			if side_type[i][side] == Side.FILL and (i / 40) % 2 == 0:
				for k in 2:
					var p := pts[i] + rgt[i] * s * (beyond + rng.randf_range(0.3, 5.0)) + fwd[i] * rng.randf_range(-2.0, 2.0)
					if not _in_lot(p) and _road_distance(p.x, p.z) > 4.5:
						place.call(cogon, p.x, p.z, rng.randf_range(1.8, 2.6))
	var root := Node3D.new()
	root.name = "Tropics"
	parent.add_child(root)
	root.owner = owner
	var sets := [
		["Banana0", TrackMaterials.banana_mesh(0), bananas[0]], ["Banana1", TrackMaterials.banana_mesh(1), bananas[1]],
		["Bamboo0", TrackMaterials.bamboo_mesh(0), bamboo[0]], ["Bamboo1", TrackMaterials.bamboo_mesh(1), bamboo[1]],
		["Cogon", TrackMaterials.grass_mesh(7), cogon],
	]
	for spec in sets:
		var xforms: Array[Transform3D] = []
		xforms.assign(spec[2])
		var chunked := Scatter.make_chunked(spec[0], spec[1], xforms, 100.0, 300.0)
		root.add_child(chunked)
		chunked.owner = owner
		for part in chunked.get_children():
			(part as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			part.owner = owner
	print("bananas %d, bamboo %d (first at %d m), cogon %d" % [bananas[0].size() + bananas[1].size(),
		bamboo[0].size() + bamboo[1].size(), first_bamboo, cogon.size()])


## Bushes and grass along the verges and the forest edge, close to the road where it is seen.
func _build_undergrowth(parent: Node3D, owner: Node, bounds: Rect2, grid: Dictionary, rng: RandomNumberGenerator) -> void:
	var bushes: Array[Transform3D] = []
	var grass: Array[Transform3D] = []
	for i in range(0, pts.size(), 1):
		for side in 2:
			var s := 1.0 if side == 1 else -1.0
			# Grass: a few tufts per metre on each side, just beyond the road's own geometry.
			for k in 3:
				var lateral := s * (skirt[i][side] + rng.randf_range(0.2, 9.0))
				var p := pts[i] + rgt[i] * lateral + fwd[i] * rng.randf_range(-0.5, 0.5)
				if nearest_sample(p.x, p.z) >= 0 and Vector2(p.x - pts[nearest_sample(p.x, p.z)].x, p.z - pts[nearest_sample(p.x, p.z)].z).length() < 4.5:
					continue
				if _in_lot(p):
					continue
				var h := _grid_height(bounds, grid, p.x, p.z)
				var sc := rng.randf_range(0.8, 1.5)
				grass.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(p.x, h - 0.05, p.z)))
			if i % 6 == 0 and rng.randf() < 0.6:
				var lateral := s * (skirt[i][side] + rng.randf_range(1.0, 12.0))
				var p := pts[i] + rgt[i] * lateral
				if _in_lot(p):
					continue
				var h := _grid_height(bounds, grid, p.x, p.z)
				var sc := rng.randf_range(0.7, 1.4)
				bushes.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(p.x, h - 0.1, p.z)))
	var g := Scatter.make_chunked("Grass", TrackMaterials.grass_mesh(), grass, 60.0, 110.0)
	var b := Scatter.make_chunked("Bushes", TrackMaterials.bush_mesh(), bushes, 100.0, 260.0)
	for node in [g, b]:
		parent.add_child(node)
		node.owner = owner
		for part in node.get_children():
			(part as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			part.owner = owner
	print("grass tufts: %d, bushes: %d" % [grass.size(), bushes.size()])


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


# --- Roadside furniture ----------------------------------------------------------------------------

## Philippine provincial mountain-road props, black-and-white graphics for the manga page with
## sparse spot color: chevron boards on the outside of tight corners, delineator posts, utility
## poles with sagging wires along one stretch, convex traffic mirrors at hairpin apexes, DPWH-style
## white boards with red lettering before tight corners, kilometre posts, and sodium street lamps
## (orange heads and pools) at the start and goal and through the barangay stretch after the start.
func build_props(parent: Node3D, owner: Node, start_distance: float, finish_distance: float) -> void:
	var props := Node3D.new()
	props.name = "Props"
	parent.add_child(props)
	props.owner = owner
	_build_chevrons(props, owner)
	_build_delineators(props, owner)
	_build_poles(props, owner, 180.0, 720.0)
	_build_mirrors(props, owner)
	for d in _lamp_distances(start_distance, finish_distance):
		var store := _lot("store")
		if store.is_empty() or not _in_lot(_roadside(_index(d), -4.7), [store]):
			_build_street_lamp(props, owner, d)
	_build_warning_signs(props, owner, start_distance, finish_distance)
	_build_km_posts(props, owner, start_distance, finish_distance)
	_build_arch(props, owner, start_distance + ARCH_AFTER_START)
	if not _lot("store").is_empty():
		_build_store(props, owner, _lot("store"))
	if not _lot("viewpoint").is_empty():
		_build_viewpoint(props, owner, _lot("viewpoint"))
	if not _lot("shed").is_empty():
		_build_shed(props, owner, _lot("shed"))
	var n := 0
	for lot in lots:
		if lot["kind"] == "house":
			_build_house(props, owner, lot, n)
			n += 1
	_build_painted_rocks(props, owner)


## Street lamps (always on the left): start, goal, and the barangay stretch after the start.
static func _lamp_distances(start_distance: float, finish_distance: float) -> Array[float]:
	var lamps: Array[float] = [start_distance - 6.0, finish_distance - 20.0, finish_distance + 12.0]
	for k in 6:
		lamps.append(start_distance + 40.0 + k * 55.0)
	return lamps


func _index(distance: float) -> int:
	return clampi(roundi(distance / SPACING), 0, pts.size() - 1)


## Ground point beside the road at `lateral` metres (signed, right +) at sample `i`.
func _roadside(i: int, lateral: float) -> Vector3:
	var side := 1 if lateral > 0.0 else 0
	var prof := _side_profile(i, side)
	var offsets: PackedFloat64Array = prof["offsets"]
	var heights: PackedFloat64Array = prof["heights"]
	var x := absf(lateral)
	var h: float = heights[heights.size() - 1]
	for k in range(1, offsets.size()):
		if x <= offsets[k]:
			h = lerpf(heights[k - 1], heights[k], (x - offsets[k - 1]) / maxf(offsets[k] - offsets[k - 1], 1e-3))
			break
	return pts[i] + rgt[i] * lateral + Vector3.UP * h


## Basis facing back down the road (toward oncoming traffic) at sample i.
func _facing_traffic(i: int) -> Basis:
	var z := -Vector3(fwd[i].x, 0.0, fwd[i].z).normalized()
	var x := Vector3.UP.cross(z).normalized()
	return Basis(x, Vector3.UP, z)


func _build_chevrons(parent: Node3D, owner: Node) -> void:
	var boards := { 1: [] as Array[Transform3D], -1: [] as Array[Transform3D] }
	var posts: Array[Transform3D] = []
	var last := -100
	for i in range(0, pts.size(), 2):
		var k := curvature[i]
		if absf(k) < 1.0 / 60.0 or i - last < 13:
			continue
		last = i
		# Outside of the corner: left of a right-hander, right of a left-hander.
		var turn_right := k > 0.0
		var lateral := -4.35 if turn_right else 4.35
		var base := _roadside(i, lateral)
		var basis := _facing_traffic(i)
		boards[1 if turn_right else -1].append(Transform3D(basis, base + Vector3.UP * 1.35))
		posts.append(Transform3D(Basis(), base + Vector3.UP * 0.6))
	var quad := QuadMesh.new()
	quad.size = Vector2(0.62, 0.78)
	for dir in boards:
		var m := MangaArt.world_preset("sign")
		m.set_shader_parameter("pattern_dir", float(dir))
		quad = quad.duplicate()
		quad.material = m
		var s := Scatter.make("Chevrons%s" % ("Right" if dir > 0 else "Left"), quad, boards[dir])
		parent.add_child(s)
		s.owner = owner
	var post := CylinderMesh.new()
	post.top_radius = 0.04
	post.bottom_radius = 0.04
	post.height = 1.2
	post.radial_segments = 6
	post.material = MangaArt.world_preset("post")
	var ps := Scatter.make("ChevronPosts", post, posts)
	parent.add_child(ps)
	ps.owner = owner


func _build_delineators(parent: Node3D, owner: Node) -> void:
	var xforms: Array[Transform3D] = []
	for i in range(10, pts.size(), 25):
		for lateral in [-3.95, 3.95]:
			xforms.append(Transform3D(Basis(), _roadside(i, lateral) + Vector3.UP * 0.5))
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = 0.06
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.material = MangaArt.world_preset("delineator")
	var s := Scatter.make("Delineators", mesh, xforms)
	parent.add_child(s)
	s.owner = owner


func _build_poles(parent: Node3D, owner: Node, from_d: float, to_d: float) -> void:
	var poles: Array[Transform3D] = []
	var arms: Array[Transform3D] = []
	var tops: Array[Vector3] = []
	var i := roundi(from_d / SPACING)
	while i < mini(roundi(to_d / SPACING), pts.size() - 1):
		# On whichever side drops away (the valley), behind the rail.
		var side := 0 if side_type[i][0] == Side.FILL else 1
		var lateral := 6.2 * (1.0 if side == 1 else -1.0)
		var base := _roadside(i, lateral)
		var basis := _facing_traffic(i)
		if not _in_lot(base):
			poles.append(Transform3D(Basis(), base + Vector3.UP * 4.5))
			arms.append(Transform3D(basis, base + Vector3.UP * 8.4))
			tops.append(base + Vector3.UP * 8.45)
		i += 35
	var pole := CylinderMesh.new()
	pole.top_radius = 0.12
	pole.bottom_radius = 0.16
	pole.height = 9.0
	pole.radial_segments = 8
	pole.material = MangaArt.world_preset("pole")
	var arm := BoxMesh.new()
	arm.size = Vector3(1.8, 0.12, 0.12)
	arm.material = MangaArt.world_preset("pole")
	for pair in [["Poles", pole, poles], ["PoleArms", arm, arms]]:
		var s := Scatter.make(pair[0], pair[1], pair[2])
		parent.add_child(s)
		s.owner = owner
	# Three sagging wires between consecutive poles, as thin dark ribbons.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(1, tops.size()):
		var a := tops[k - 1]
		var b := tops[k]
		var across := (b - a).cross(Vector3.UP).normalized()
		for w in [-0.75, 0.0, 0.75]:
			var prev := Vector3.ZERO
			for n in 13:
				var t := n / 12.0
				var p: Vector3 = a.lerp(b, t) + across * w + Vector3.DOWN * (sin(PI * t) * 0.55)
				if n > 0:
					var hw := Vector3.UP * 0.018
					for v in [prev - hw, prev + hw, p + hw, prev - hw, p + hw, p - hw, prev - hw, p + hw, prev + hw, prev - hw, p - hw, p + hw]:
						st.add_vertex(v)
				prev = p
	st.generate_normals()
	st.set_material(MangaArt.world_preset("pole"))
	var wires := MeshInstance3D.new()
	wires.name = "Wires"
	wires.mesh = st.commit()
	wires.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(wires)
	wires.owner = owner


func _build_mirrors(parent: Node3D, owner: Node) -> void:
	var discs: Array[Transform3D] = []
	var posts: Array[Transform3D] = []
	var i := 2
	while i < pts.size() - 2:
		# Hairpin apex: the tightest sample of a run tighter than 22 m radius.
		if absf(curvature[i]) > 1.0 / 22.0:
			var best := i
			while i < pts.size() - 2 and absf(curvature[i]) > 1.0 / 22.0:
				if absf(curvature[i]) > absf(curvature[best]):
					best = i
				i += 1
			var lateral := -4.6 if curvature[best] > 0.0 else 4.6
			var base := _roadside(best, lateral)
			var basis := _facing_traffic(maxi(best - 25, 0))
			discs.append(Transform3D(basis * Basis(Vector3.RIGHT, PI / 2.0), base + Vector3.UP * 2.6))
			posts.append(Transform3D(Basis(), base + Vector3.UP * 1.25))
		i += 1
	var disc := CylinderMesh.new()
	disc.top_radius = 0.42
	disc.bottom_radius = 0.42
	disc.height = 0.06
	disc.radial_segments = 16
	disc.material = MangaArt.world_preset("lamp_head")
	var post := CylinderMesh.new()
	post.top_radius = 0.05
	post.bottom_radius = 0.05
	post.height = 2.5
	post.radial_segments = 6
	post.material = MangaArt.world_preset("post")
	for pair in [["Mirrors", disc, discs], ["MirrorPosts", post, posts]]:
		var s := Scatter.make(pair[0], pair[1], pair[2])
		parent.add_child(s)
		s.owner = owner


func _build_street_lamp(parent: Node3D, owner: Node, distance: float) -> void:
	var i := clampi(roundi(distance / SPACING), 0, pts.size() - 1)
	var base := _roadside(i, -4.7)
	var root := Node3D.new()
	root.name = "StreetLamp%d" % i
	parent.add_child(root)
	root.owner = owner
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.08
	pm.bottom_radius = 0.12
	pm.height = 7.0
	pm.radial_segments = 8
	pm.material = MangaArt.world_preset("pole")
	pole.mesh = pm
	pole.position = base + Vector3.UP * 3.5
	root.add_child(pole)
	pole.owner = owner
	var reach := rgt[i] * 2.4
	var arm := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(0.1, 0.1, 2.6)
	am.material = MangaArt.world_preset("pole")
	arm.mesh = am
	arm.transform = Transform3D(Basis.looking_at(reach.normalized(), Vector3.UP), base + Vector3.UP * 7.0 + reach * 0.5)
	root.add_child(arm)
	arm.owner = owner
	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.5, 0.14, 0.28)
	hm.material = MangaArt.lamp(MangaArt.SODIUM)
	head.mesh = hm
	head.position = base + Vector3.UP * 6.95 + reach
	root.add_child(head)
	head.owner = owner
	var light := SpotLight3D.new()
	light.position = base + Vector3.UP * 6.8 + reach
	light.rotation_degrees = Vector3(-90, 0, 0)
	light.spot_range = 11.0
	light.spot_angle = 38.0
	light.spot_angle_attenuation = 0.05
	light.spot_attenuation = 0.5
	light.light_energy = 2.4
	light.light_color = MangaArt.SODIUM
	light.shadow_enabled = false
	root.add_child(light)
	light.owner = owner


const WARNINGS := [
	["SLOW DOWN", "SHARP CURVE AHEAD"],
	["MENOR", "DELIKADONG KURBADA"],
	["ACCIDENT", "PRONE AREA"],
	["DANGER", "SHARP CURVE"],
	["BAWAL", "MAG-OVERTAKE"],
	["DRIVE SAFELY", "KEEP RIGHT"],
]


## White boards with red lettering on the driver's side, ~45 m before every other tight corner.
func _build_warning_signs(parent: Node3D, owner: Node, start_distance: float, finish_distance: float) -> void:
	var lead := roundi(45.0 / SPACING)
	var last := -1000
	var n := 0
	for i in range(lead, pts.size(), 2):
		if absf(curvature[i]) < 1.0 / 35.0 or i - last < roundi(160.0 / SPACING):
			continue
		last = i
		var at := i - lead
		if at * SPACING < start_distance + 20.0 or at * SPACING > finish_distance - 20.0:
			continue
		var lines: Array = WARNINGS[n % WARNINGS.size()]
		_build_board(parent, owner, at, 4.3, Vector2(2.2, 1.1), 1.4, lines[0], lines[1], MangaArt.SIGN_RED)
		n += 1


## White concrete kilometre posts every kilometre on the driver's side.
func _build_km_posts(parent: Node3D, owner: Node, start_distance: float, finish_distance: float) -> void:
	var km := 247
	var d := start_distance + 150.0
	while d < finish_distance:
		var i := clampi(roundi(d / SPACING), 0, pts.size() - 1)
		_build_board(parent, owner, i, 4.3, Vector2(0.42, 0.75), 0.0, "KM", str(km), MangaArt.INK)
		km += 1
		d += 1000.0


## A board facing traffic at sample `i`, `lateral` m to the right, with two lines of lettering.
## `height` 0 = a squat post standing on the ground (km post); otherwise a board on two posts.
func _build_board(parent: Node3D, owner: Node, i: int, lateral: float, size: Vector2, height: float,
		line1: String, line2: String, ink: Color) -> void:
	var base := _roadside(i, lateral)
	var root := Node3D.new()
	root.name = "Sign%d" % i
	root.transform = Transform3D(_facing_traffic(i), base)
	parent.add_child(root)
	root.owner = owner
	var center_y := height + size.y * 0.5
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x, size.y, 0.18 if height == 0.0 else 0.05)
	bm.material = MangaArt.world_preset("board")
	board.mesh = bm
	board.position = Vector3(0, center_y, 0)
	root.add_child(board)
	board.owner = owner
	if height > 0.0:
		var pm := CylinderMesh.new()
		pm.top_radius = 0.04
		pm.bottom_radius = 0.04
		pm.height = height + size.y * 0.8
		pm.radial_segments = 6
		pm.material = MangaArt.world_preset("post")
		for x in [-size.x * 0.35, size.x * 0.35]:
			var post := MeshInstance3D.new()
			post.mesh = pm
			post.position = Vector3(x, pm.height * 0.5, -0.04)
			root.add_child(post)
			post.owner = owner
	var font_px := 64
	var big := minf(size.y * 0.36, size.x * 0.9 / maxf(line1.length(), 1) * 1.6)
	var small := minf(size.y * 0.26, size.x * 0.9 / maxf(line2.length(), 1) * 1.6)
	for spec in [[line1, big, center_y + size.y * 0.2], [line2, small, center_y - size.y * 0.2]]:
		var text := Label3D.new()
		text.text = spec[0]
		text.font_size = font_px
		text.pixel_size = float(spec[1]) / font_px
		text.modulate = ink
		text.outline_size = 0
		# Unshaded: retroreflective paint stays a flat spot color (shaded, it fell into ink).
		text.shaded = false
		text.double_sided = false
		text.position = Vector3(0, spec[2], bm.size.z * 0.5 + 0.01)
		root.add_child(text)
		text.owner = owner


# --- Barangay ------------------------------------------------------------------------------------

## The welcome arch spans the road this far after the start line, where the village lamps begin.
const ARCH_AFTER_START := 30.0
## Sari-sari store footprint: frontage along the road, wall height, depth back from the road.
const STORE_SIZE := Vector3(5.2, 2.6, 3.8)
## Lateral offset of the store's front wall (just past the gravel shoulder).
const STORE_FRONT := 4.4
## Waiting shed and roadside house footprints: frontage, wall height, depth.
const SHED_SIZE := Vector3(4.2, 2.5, 2.4)
const HOUSE_SIZE := Vector3(7.0, 2.8, 5.5)
## Viewpoint pull-off: frontage along the road and depth out over the valley.
const VIEW_SIZE := Vector2(30.0, 8.0)
const TRIM := Color(0.95, 0.72, 0.1)
const BULB := Color(1.0, 0.78, 0.45)

## Reserved roadside lots (buildings, the viewpoint pad): { kind, i: sample, side: 0 left / 1 right,
## frontage, depth, xform: front frame (+Z toward the road, +X along it, origin at road-edge level) }.
## Guardrails, poles, lamps and undergrowth leave them open.
var lots: Array[Dictionary] = []


## Plans every lot before the dressing is built. Call it before the guardrails and trees.
func plan_lots(start_distance: float, finish_distance: float) -> void:
	lots.clear()
	var lamps := _lamp_distances(start_distance, finish_distance)
	# The sari-sari store on stilts over the drop, front at road level, in the barangay stretch.
	_find_lot("store", start_distance + ARCH_AFTER_START + 25.0, start_distance + 300.0,
		STORE_SIZE.x, STORE_SIZE.z, STORE_FRONT, lamps)
	# The waiting shed and a few houses along the road, each on stilts over the drop.
	_find_lot("shed", start_distance + ARCH_AFTER_START + 20.0, start_distance + 420.0,
		SHED_SIZE.x, SHED_SIZE.z, 4.3, lamps)
	for span in [[start_distance + 100.0, start_distance + 380.0], [520.0, 900.0], [960.0, finish_distance - 90.0]]:
		_find_lot("house", span[0], span[1], HOUSE_SIZE.x, HOUSE_SIZE.z, 5.6, lamps)
	# The viewpoint pull-off by the goal, on the valley side.
	# Its street lamps stay: they light the deck.
	_find_lot("viewpoint", finish_distance - 70.0, finish_distance + 10.0, VIEW_SIZE.x, VIEW_SIZE.y,
		3.3, [] as Array[float], 1.0 / 90.0)
	for lot in lots:
		print("%s at %.0f m, %s side" % [lot["kind"], lot["i"] * SPACING, "right" if lot["side"] == 1 else "left"])


## First lot between `from_d` and `to_d` on a drop (fill) side that is straight enough, has room
## behind it, avoids other lots and (on the left) the street lamps. Returns it, or {} if none.
func _find_lot(kind: String, from_d: float, to_d: float, frontage: float, depth: float, front: float,
		lamps: Array[float], max_curvature := 1.0 / 150.0) -> Dictionary:
	var half := roundi((frontage * 0.5 + 6.0) / SPACING)
	for d in range(int(from_d), int(to_d)):
		var i := _index(d)
		if i - half < 0 or i + half >= pts.size():
			continue
		for side in [1, 0]:
			if side == 0 and lamps.any(func(l: float) -> bool: return absf(l - d) < frontage * 0.5 + 6.0):
				continue
			var ok := true
			for j in range(i - half, i + half + 1):
				if side_type[j][side] != Side.FILL or absf(curvature[j]) > max_curvature or skirt[j][side] < minf(depth + front, MAX_SKIRT - 1.0):
					ok = false
					break
			if not ok:
				continue
			var s := 1.0 if side == 1 else -1.0
			var origin := _roadside(i, s * 3.6) + rgt[i] * s * (front - 3.6)
			var taken := false
			for other in lots:
				if other["side"] == side and absi(int(other["i"]) - i) * SPACING < (frontage + float(other["frontage"])) * 0.5 + 8.0:
					taken = true
			if taken:
				continue
			var z := -rgt[i] * s
			var x := Vector3.UP.cross(z).normalized()
			var lot := { "kind": kind, "i": i, "side": side, "frontage": frontage, "depth": depth,
				"xform": Transform3D(Basis(x, Vector3.UP, z), origin) }
			lots.append(lot)
			return lot
	push_warning("No lot for %s between %.0f and %.0f m." % [kind, from_d, to_d])
	return {}


func _lot(kind: String) -> Dictionary:
	for lot in lots:
		if lot["kind"] == kind:
			return lot
	return {}


## True when `p` falls on a lot (its footprint plus a margin), so nothing grows or stands there.
func _in_lot(p: Vector3, among: Array[Dictionary] = lots) -> bool:
	for lot in among:
		var local: Vector3 = (lot["xform"] as Transform3D).affine_inverse() * p
		if absf(local.x) < float(lot["frontage"]) * 0.5 + 2.0 and local.z < 1.5 and local.z > -float(lot["depth"]) - 2.5:
			return true
	return false


## True when sample `i` on `side` fronts a lot (no guardrail there: the lot opens onto the road).
func _fronts_lot(i: int, side: int) -> bool:
	for lot in lots:
		if lot["side"] == side and absi(i - int(lot["i"])) <= roundi((float(lot["frontage"]) * 0.5 + 1.5) / SPACING):
			return true
	return false


func _box(parent: Node3D, owner: Node, size: Vector3, xform: Transform3D, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.transform = xform
	parent.add_child(mi)
	mi.owner = owner
	return mi


## Painted lettering facing +Z (or -Z when `back`), fitted to `width` and at most `height` tall.
func _paint(parent: Node3D, owner: Node, text: String, width: float, height: float, pos: Vector3,
		ink: Color, back := false) -> void:
	var font_px := 64
	var label := Label3D.new()
	label.text = text
	label.font_size = font_px
	label.pixel_size = minf(height, width * 0.9 / maxf(text.length(), 1) * 1.6) / font_px
	label.modulate = ink
	label.outline_size = 0
	label.shaded = false
	label.double_sided = false
	label.position = pos
	if back:
		label.rotation.y = PI
	parent.add_child(label)
	label.owner = owner


func _solid(parent: Node3D, owner: Node, name: String, shapes: Array) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.collision_layer = CarBody.STATIC_LAYER
	body.collision_mask = 0
	parent.add_child(body)
	body.owner = owner
	for spec in shapes:
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = spec[0]
		shape.shape = bs
		shape.transform = spec[1]
		body.add_child(shape)
		shape.owner = owner


## Concrete barangay welcome arch over the road: two pillars, a lintel and a raised name panel,
## red lettering on whitewash with a yellow trim stripe, sodium globes on the pillar caps.
## Welcome on the face toward oncoming cars, farewell on the back.
func _build_arch(parent: Node3D, owner: Node, distance: float) -> void:
	var i := _index(distance)
	var root := Node3D.new()
	root.name = "BarangayArch"
	root.transform = Transform3D(_facing_traffic(i), pts[i])
	parent.add_child(root)
	root.owner = owner
	var concrete := MangaArt.world_preset("concrete")
	var paint := MangaArt.world_preset("board")
	var top := 6.0
	var shapes := []
	for lateral in [-4.4, 4.4]:
		var ground := _roadside(i, lateral).y - pts[i].y - 0.4
		var h := top - ground
		var at := Vector3(lateral, ground + h * 0.5, 0)
		_box(root, owner, Vector3(0.7, h, 0.7), Transform3D(Basis(), at), concrete)
		shapes.append([Vector3(0.7, h, 0.7), Transform3D(Basis(), at)])
		_box(root, owner, Vector3(0.95, 1.1, 0.95), Transform3D(Basis(), Vector3(lateral, ground + 0.95, 0)), concrete)
		_box(root, owner, Vector3(0.9, 0.2, 0.9), Transform3D(Basis(), Vector3(lateral, top + 0.85, 0)), concrete)
		var globe := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.22
		sm.height = 0.44
		sm.radial_segments = 12
		sm.rings = 6
		sm.material = MangaArt.lamp(MangaArt.SODIUM)
		globe.mesh = sm
		globe.position = Vector3(lateral, top + 1.17, 0)
		root.add_child(globe)
		globe.owner = owner
	_solid(root, owner, "ArchCollision", shapes)
	# Lintel and raised name panel.
	_box(root, owner, Vector3(9.5, 0.9, 0.5), Transform3D(Basis(), Vector3(0, top - 0.2, 0)), paint)
	_box(root, owner, Vector3(9.5, 0.12, 0.54), Transform3D(Basis(), Vector3(0, top - 0.62, 0)), MangaArt.accent(TRIM))
	_box(root, owner, Vector3(5.4, 1.2, 0.4), Transform3D(Basis(), Vector3(0, top + 0.85, 0)), paint)
	_box(root, owner, Vector3(5.4, 0.1, 0.44), Transform3D(Basis(), Vector3(0, top + 1.5, 0)), MangaArt.accent(TRIM))
	_box(root, owner, Vector3(2.2, 0.4, 0.36), Transform3D(Basis(), Vector3(0, top + 1.75, 0)), paint)
	var faces := [
		[false, 1.0, "MALIGAYANG PAGDATING SA", "BRGY. SAN ISIDRO", "MAG-INGAT SA PAGMAMANEHO"],
		[true, -1.0, "SALAMAT SA PAGBISITA", "BRGY. SAN ISIDRO", "BALIK PO KAYO"],
	]
	for f in faces:
		var z: float = f[1]
		_paint(root, owner, f[2], 5.0, 0.3, Vector3(0, top + 1.18, z * 0.21), MangaArt.INK, f[0])
		_paint(root, owner, f[3], 5.0, 0.62, Vector3(0, top + 0.72, z * 0.21), MangaArt.SIGN_RED, f[0])
		_paint(root, owner, f[4], 8.6, 0.42, Vector3(0, top - 0.18, z * 0.26), MangaArt.SIGN_RED, f[0])


## Sari-sari store on the valley side: plywood box on stilts, its front at road level with the
## barred tindahan window and counter, a rusty GI roof over the shoulder, snack strips hanging in
## the window (spot color), a bare bulb under the eave, and a bench out front.
func _build_store(parent: Node3D, owner: Node, lot: Dictionary) -> void:
	var xf: Transform3D = lot["xform"]
	var root := Node3D.new()
	root.name = "SariSariStore"
	root.transform = xf
	parent.add_child(root)
	root.owner = owner
	var w := STORE_SIZE.x
	var h := STORE_SIZE.y
	var d := STORE_SIZE.z
	var wall := MangaArt.world_preset("concrete")
	var wood := MangaArt.world_preset("pole")
	var paint := MangaArt.world_preset("board")
	var dark := MangaArt.world_preset("post")
	var hw := w * 0.5
	# Floor deck (reaches over the shoulder lip) and walls: back, sides, front around the window.
	_box(root, owner, Vector3(w + 0.2, 0.18, d + 0.5), Transform3D(Basis(), Vector3(0, -0.09, -d * 0.5 + 0.25)), wall)
	_box(root, owner, Vector3(w, h, 0.1), Transform3D(Basis(), Vector3(0, h * 0.5, -d + 0.05)), wall)
	for x in [-hw + 0.05, hw - 0.05]:
		_box(root, owner, Vector3(0.1, h, d), Transform3D(Basis(), Vector3(x, h * 0.5, -d * 0.5)), wall)
	var win := Vector2(-1.7, 1.2)   # window span along the front
	_box(root, owner, Vector3(w, 1.0, 0.1), Transform3D(Basis(), Vector3(0, 0.5, -0.05)), wall)
	_box(root, owner, Vector3(w, h - 2.1, 0.1), Transform3D(Basis(), Vector3(0, (h + 2.1) * 0.5, -0.05)), wall)
	_box(root, owner, Vector3(win.x + hw, 1.1, 0.1), Transform3D(Basis(), Vector3((-hw + win.x) * 0.5, 1.55, -0.05)), wall)
	_box(root, owner, Vector3(hw - win.y, 1.1, 0.1), Transform3D(Basis(), Vector3((win.y + hw) * 0.5, 1.55, -0.05)), wall)
	# Dark interior behind the window so the opening reads as shade.
	_box(root, owner, Vector3(win.y - win.x, 1.1, 0.04), Transform3D(Basis(), Vector3((win.x + win.y) * 0.5, 1.55, -1.2)), dark)
	# Counter ledge and the wooden grille.
	_box(root, owner, Vector3(win.y - win.x + 0.3, 0.06, 0.4), Transform3D(Basis(), Vector3((win.x + win.y) * 0.5, 1.02, 0.12)), wood)
	var x := win.x + 0.2
	while x < win.y - 0.1:
		_box(root, owner, Vector3(0.035, 1.08, 0.035), Transform3D(Basis(), Vector3(x, 1.55, 0.0)), wood)
		x += 0.24
	_box(root, owner, Vector3(win.y - win.x, 0.05, 0.05), Transform3D(Basis(), Vector3((win.x + win.y) * 0.5, 1.6, 0.0)), wood)
	# Snack strips hanging inside the window: the store's color.
	var snacks := [MangaArt.SIGN_RED, TRIM, Color(0.1, 0.35, 0.8), Color(0.15, 0.6, 0.25)]
	var k := 0
	x = win.x + 0.15
	while x < win.y - 0.1:
		_box(root, owner, Vector3(0.13, 0.55, 0.01), Transform3D(Basis(), Vector3(x, 1.78, -0.2)), MangaArt.accent(snacks[k % snacks.size()]))
		x += 0.19
		k += 1
	# Store sign over the window, a hand-lettered no-credit card and the e-load card.
	_box(root, owner, Vector3(3.6, 0.55, 0.06), Transform3D(Basis(), Vector3(-0.2, 2.33, 0.04)), paint)
	_paint(root, owner, "ALING NENA'S", 3.4, 0.2, Vector3(-0.2, 2.47, 0.08), MangaArt.INK)
	_paint(root, owner, "SARI-SARI STORE", 3.4, 0.28, Vector3(-0.2, 2.24, 0.08), MangaArt.SIGN_RED)
	_box(root, owner, Vector3(0.75, 0.3, 0.01), Transform3D(Basis(), Vector3(-0.5, 1.3, 0.04)), paint)
	_paint(root, owner, "BAWAL ANG", 0.7, 0.1, Vector3(-0.5, 1.36, 0.05), MangaArt.INK)
	_paint(root, owner, "UTANG", 0.7, 0.13, Vector3(-0.5, 1.24, 0.05), MangaArt.SIGN_RED)
	_box(root, owner, Vector3(0.7, 0.45, 0.04), Transform3D(Basis(), Vector3(1.85, 1.45, 0.03)), MangaArt.accent(TRIM))
	_paint(root, owner, "LOAD", 0.65, 0.18, Vector3(1.85, 1.52, 0.06), MangaArt.INK)
	_paint(root, owner, "NA DITO", 0.65, 0.12, Vector3(1.85, 1.36, 0.06), MangaArt.INK)
	# Single-pitch GI roof, low over the shoulder.
	var roof_len := d + 1.2
	var front_h := h + 0.15
	var back_h := h + 0.65
	var tilt := atan2(back_h - front_h, roof_len)
	var roof_mid := Vector3(0, (front_h + back_h) * 0.5, -d * 0.5 + 0.6)
	_box(root, owner, Vector3(w + 0.6, 0.05, roof_len / cos(tilt)), Transform3D(Basis(Vector3.RIGHT, tilt), roof_mid), wood)
	# Bare bulb under the eave.
	var bulb := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.07
	bm.height = 0.14
	bm.radial_segments = 8
	bm.rings = 4
	bm.material = MangaArt.lamp(BULB, 1.0)
	bulb.mesh = bm
	bulb.position = Vector3(-0.2, h + 0.05, 0.45)
	root.add_child(bulb)
	bulb.owner = owner
	var light := OmniLight3D.new()
	light.position = Vector3(-0.2, h - 0.05, 0.6)
	light.omni_range = 3.5
	light.omni_attenuation = 0.8
	light.light_energy = 0.9
	light.light_color = BULB
	light.shadow_enabled = false
	root.add_child(light)
	light.owner = owner
	# Bench on the shoulder.
	var bench_z := 0.55
	_box(root, owner, Vector3(2.0, 0.06, 0.34), Transform3D(Basis(), Vector3(-1.1, 0.45, bench_z)), wood)
	for bx in [-1.95, -0.25]:
		_box(root, owner, Vector3(0.06, 0.45, 0.3), Transform3D(Basis(), Vector3(bx, 0.22, bench_z)), wood)
	_stilts(root, owner, xf, [-hw + 0.1, 0.0, hw - 0.1], [-1.4, -d + 0.15], wood)
	_solid(root, owner, "StoreCollision", [
		[Vector3(w, h, d), Transform3D(Basis(), Vector3(0, h * 0.5, -d * 0.5))],
	])


# --- Viewpoint ------------------------------------------------------------------------------------

## The pull-off by the goal: a concrete pad flush with the road edge (tapered at both ends) out over
## the valley, a parapet along its lip, benches facing the view, the deck's sign and a litter sign.
func _build_viewpoint(parent: Node3D, owner: Node, lot: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Viewpoint"
	parent.add_child(root)
	root.owner = owner
	var i0: int = lot["i"]
	var side: int = lot["side"]
	var s := 1.0 if side == 1 else -1.0
	var half := roundi(VIEW_SIZE.x * 0.5 / SPACING)
	var taper := 6.0
	var inner := 3.25
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall := SurfaceTool.new()
	wall.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rail := SurfaceTool.new()
	rail.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rail_posts: Array[Transform3D] = []
	var faces := PackedVector3Array()
	var prev := {}
	for j in range(i0 - half, i0 + half + 1):
		var along := absf(j - i0) * SPACING
		var depth := VIEW_SIZE.y * clampf((VIEW_SIZE.x * 0.5 - along) / taper, 0.0, 1.0)
		var edge_h: float = _roadside(j, s * 3.6).y - pts[j].y
		var a := pts[j] + rgt[j] * s * inner + Vector3.UP * edge_h
		var b := pts[j] + rgt[j] * s * (inner + depth) + Vector3.UP * (edge_h - 0.02)
		var c := pts[j] + rgt[j] * s * (inner + depth + 0.3) + Vector3.UP * (edge_h - 0.02)
		var ground := minf(_roadside(j, s * minf(inner + depth + 0.3, skirt[j][side])).y, c.y - 0.5) - 1.0
		var foot := Vector3(c.x, ground, c.z)
		var cur := { "a": a, "b": b, "c": c, "foot": foot, "depth": depth }
		if not prev.is_empty():
			var quad := func(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, collide: bool) -> void:
				for v in [p0, p1, p2, p0, p2, p3, p0, p2, p1, p0, p3, p2]:
					st.add_vertex(v)
				if collide:
					faces.append_array([p0, p1, p2, p0, p2, p3])
			quad.call(top, prev["a"], cur["a"], cur["c"], prev["c"], true)
			# Retaining face down to the slope.
			quad.call(wall, prev["c"], cur["c"], cur["foot"], prev["foot"], false)
			# Parapet along the lip: a 0.5 m wall, 0.25 m thick, with a pipe railing over it so the
			# valley stays in view. Collision goes up to the top rail.
			if cur["depth"] > 0.5 and prev["depth"] > 0.5:
				var up := Vector3.UP * 0.5
				var pb: Vector3 = prev["b"]
				var cb: Vector3 = cur["b"]
				var pc: Vector3 = prev["c"]
				var cc: Vector3 = cur["c"]
				quad.call(wall, pb, cb, cb + up, pb + up, false)
				quad.call(wall, pc, cc, cc + up, pc + up, false)
				quad.call(wall, pb + up, cb + up, cc + up, pc + up, false)
				faces.append_array([pb, cb, cb + Vector3.UP * 1.1, pb, cb + Vector3.UP * 1.1, pb + Vector3.UP * 1.1])
				var pm: Vector3 = (pb + pc) * 0.5
				var cm: Vector3 = (cb + cc) * 0.5
				for h: float in [0.78, 1.05]:
					var t := Vector3.UP * 0.025
					var y := Vector3.UP * h
					quad.call(rail, pm + y - t, cm + y - t, cm + y + t, pm + y + t, false)
				if j % 2 == 0:
					rail_posts.append(Transform3D(Basis(), cm + Vector3.UP * 0.78))
		prev = cur
	top.generate_normals()
	top.set_material(MangaArt.world_preset("concrete"))
	wall.generate_normals()
	wall.set_material(MangaArt.world_preset("concrete"))
	rail.generate_normals()
	rail.set_material(MangaArt.world_preset("pole"))
	for pair in [["Pad", top], ["Parapet", wall], ["Railing", rail]]:
		var mi := MeshInstance3D.new()
		mi.name = pair[0]
		mi.mesh = (pair[1] as SurfaceTool).commit()
		root.add_child(mi)
		mi.owner = owner
	var post := BoxMesh.new()
	post.size = Vector3(0.05, 0.6, 0.05)
	post.material = MangaArt.world_preset("pole")
	var posts := Scatter.make("RailPosts", post, rail_posts)
	root.add_child(posts)
	posts.owner = owner
	var body := StaticBody3D.new()
	body.name = "ViewpointCollision"
	body.collision_layer = CarBody.STATIC_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var concave := ConcavePolygonShape3D.new()
	concave.backface_collision = true
	concave.set_faces(faces)
	shape.shape = concave
	body.add_child(shape)
	root.add_child(body)
	body.owner = owner
	shape.owner = owner
	# Furniture in a frame at the pad's middle: +Z toward the road, origin on the deck at the lip.
	var z := -rgt[i0] * s
	var x := Vector3.UP.cross(z).normalized()
	var lip := pts[i0] + rgt[i0] * s * (inner + VIEW_SIZE.y) + Vector3.UP * (_roadside(i0, s * 3.6).y - pts[i0].y)
	var deck := Node3D.new()
	deck.name = "Deck"
	deck.transform = Transform3D(Basis(x, Vector3.UP, z), lip)
	root.add_child(deck)
	deck.owner = owner
	var wood := MangaArt.world_preset("pole")
	for bx in [-6.0, 3.0]:
		_box(deck, owner, Vector3(2.2, 0.07, 0.4), Transform3D(Basis(), Vector3(bx, 0.45, 1.3)), wood)
		_box(deck, owner, Vector3(2.2, 0.35, 0.06), Transform3D(Basis(), Vector3(bx, 0.75, 1.48)), wood)
		for lx in [-0.95, 0.95]:
			_box(deck, owner, Vector3(0.08, 0.45, 0.36), Transform3D(Basis(), Vector3(bx + lx, 0.22, 1.3)), wood)
	# The deck's sign at the road end, facing traffic; the litter sign by the bench.
	var sign_root := Node3D.new()
	sign_root.name = "ViewDeckSign"
	var si := clampi(i0 - half + 4, 0, pts.size() - 1)
	sign_root.transform = Transform3D(_facing_traffic(si), _roadside(si, s * 4.6))
	root.add_child(sign_root)
	sign_root.owner = owner
	_box(sign_root, owner, Vector3(2.6, 1.0, 0.12), Transform3D(Basis(), Vector3(0, 2.0, 0)), MangaArt.world_preset("board"))
	_box(sign_root, owner, Vector3(2.6, 0.1, 0.14), Transform3D(Basis(), Vector3(0, 1.45, 0)), MangaArt.accent(TRIM))
	for px in [-1.0, 1.0]:
		_box(sign_root, owner, Vector3(0.1, 2.5, 0.1), Transform3D(Basis(), Vector3(px, 1.25, -0.08)), MangaArt.world_preset("post"))
	_paint(sign_root, owner, "VIEW DECK", 2.4, 0.42, Vector3(0, 2.18, 0.07), MangaArt.SIGN_RED)
	_paint(sign_root, owner, "SCENIC VIEWPOINT · 50 M", 2.4, 0.2, Vector3(0, 1.8, 0.07), MangaArt.INK)
	_box(deck, owner, Vector3(0.9, 0.5, 0.05), Transform3D(Basis(), Vector3(0.0, 1.35, 0.2)), MangaArt.world_preset("board"))
	_box(deck, owner, Vector3(0.06, 1.1, 0.06), Transform3D(Basis(), Vector3(0.0, 0.55, 0.16)), MangaArt.world_preset("post"))
	_paint(deck, owner, "BAWAL MAGTAPON", 0.85, 0.12, Vector3(0, 1.45, 0.23), MangaArt.SIGN_RED)
	_paint(deck, owner, "NG BASURA DITO", 0.85, 0.12, Vector3(0, 1.27, 0.23), MangaArt.INK)


# --- Valley lights --------------------------------------------------------------------------------

## Barrio clearings on the slopes below the road, planned before the trees: (x, z, radius).
var barrios: Array[Vector3] = []


## Picks the barrios' spots (clearings in the forest below the road, well away from it).
func plan_valley(bounds: Rect2) -> void:
	barrios.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 53 + 11
	var center := bounds.get_center()
	var low := INF
	for p in pts:
		low = minf(low, p.y)
	var ridge := bounds.size.length() * 0.5 + 180.0
	var view := _lot("viewpoint")
	if not view.is_empty():
		# The view from the deck: a poblacion on the slope below and a sitio nearer in.
		var xf: Transform3D = view["xform"]
		for spec in [Vector3(0.0, -270.0, 70.0), Vector3(70.0, -150.0, 30.0)]:
			var c := xf * Vector3(spec.x, 0.0, spec.y)
			barrios.append(Vector3(c.x, c.z, spec.z))
	var tries := 0
	while barrios.size() < 18 and tries < 400:
		tries += 1
		var c := center + (-_uphill).rotated(rng.randf_range(-1.1, 1.1)) * rng.randf_range(150.0, ridge - 120.0)
		if not bounds.has_point(c) or _road_distance(c.x, c.y) < 110.0 or terrain_height(c.x, c.y) > low - 8.0:
			continue
		barrios.append(Vector3(c.x, c.y, rng.randf_range(18.0, 45.0)))


func _road_distance(x: float, z: float) -> float:
	var i := nearest_sample(x, z)
	return INF if i < 0 else Vector2(pts[i].x - x, pts[i].z - z).length()


## True where trees give way: barrio clearings and the view corridor below the viewpoint deck.
func _cleared(x: float, z: float) -> bool:
	for b in barrios:
		if Vector2(b.x - x, b.y - z).length() < b.z * 0.8 + 8.0:
			return true
	var view := _lot("viewpoint")
	if not view.is_empty():
		var local: Vector3 = (view["xform"] as Transform3D).affine_inverse() * Vector3(x, 0.0, z)
		var out := -local.z
		if out > 0.0 and out < 220.0 and absf(local.x) < VIEW_SIZE.x * 0.5 + out * 0.7:
			return true
	return false


## Night lights in the valley below the pass: barrios scattered on the lower slopes (warm bulbs,
## the odd white tube light) and a lowland town spread across the valley floor out to the near
## ridge, joined by strings of sodium road lamps. Billboard dots, hidden by day (see the shader).
func build_valley_lights(parent: Node3D, owner: Node, bounds: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 59 + 3
	var center := bounds.get_center()
	var down := -_uphill
	var ridge := bounds.size.length() * 0.5 + 180.0
	var warm: Array[Transform3D] = []
	var white: Array[Transform3D] = []
	var sodium: Array[Transform3D] = []
	# Past the terrain the lowland plain lies at the foot of the far ridge (no geometry there: at
	# night it is just dark, and from the road the lights read as a town across the valley).
	var low := INF
	for q in pts:
		low = minf(low, q.y)
	var plain := low - 50.0
	var ground := func(x: float, z: float) -> float:
		var p := Vector2(x, z)
		if bounds.has_point(p):
			return terrain_height(x, z)
		return plain + _noise.get_noise_2d(x * 0.3, z * 0.3) * 8.0
	var dot := func(list: Array[Transform3D], x: float, z: float, lift: float) -> void:
		list.append(Transform3D(Basis(), Vector3(x, ground.call(x, z) + lift, z)))
	# Barrios: small houses in each clearing, one window light apiece.
	var houses: Array[Transform3D] = []
	var roofs: Array[Transform3D] = []
	for b in barrios:
		var n := int(PI * b.z * b.z / rng.randf_range(80.0, 120.0))
		for k in n:
			var p := Vector2(b.x, b.y) + Vector2(rng.randfn(0.0, b.z * 0.4), rng.randfn(0.0, b.z * 0.4))
			if _road_distance(p.x, p.y) < 60.0:
				continue
			var yaw := Basis(Vector3.UP, rng.randf() * TAU)
			var sc := rng.randf_range(0.8, 1.3)
			var h: float = ground.call(p.x, p.y)
			houses.append(Transform3D(yaw.scaled(Vector3(sc, 1.0, sc)), Vector3(p.x, h + 1.2, p.y)))
			roofs.append(Transform3D(yaw.scaled(Vector3(sc, 1.0, sc)), Vector3(p.x, h + 3.3, p.y)))
			var window := Vector3(p.x, 0.0, p.y) + yaw.z * 2.9 * sc
			dot.call(white if rng.randf() < 0.2 else warm, window.x, window.z, 1.8)
	var house := BoxMesh.new()
	house.size = Vector3(6.0, 3.0, 5.0)
	house.material = MangaArt.world_preset("concrete")
	var roof := PrismMesh.new()
	roof.size = Vector3(6.8, 1.4, 5.6)
	roof.material = MangaArt.world_preset("pole")
	for spec in [["BarrioHouses", house, houses], ["BarrioRoofs", roof, roofs]]:
		var chunked := Scatter.make_chunked(spec[0], spec[1], spec[2])
		parent.add_child(chunked)
		chunked.owner = owner
		for part in chunked.get_children():
			part.owner = owner
	# The lowland town past the terrain: dense clusters joined by lamp-lit roads.
	var towns: Array[Vector2] = []
	var view := _lot("viewpoint")
	for t in 7:
		var dir := down.rotated(rng.randf_range(-0.8, 0.8))
		var c := center + dir * rng.randf_range(ridge * 0.72, ridge - 60.0)
		if t == 0 and not view.is_empty():
			# The biggest town lies straight out across the valley from the viewpoint deck.
			var out := (view["xform"] as Transform3D) * Vector3(0.0, 0.0, -620.0)
			c = Vector2(out.x, out.z)
			if c.distance_to(center) > ridge - 60.0:
				c = center + (c - center).normalized() * (ridge - 60.0)
		towns.append(c)
		var n := rng.randi_range(80, 220)
		var spread := rng.randf_range(50.0, 130.0)
		for k in n:
			var p := c + Vector2(rng.randfn(0.0, spread * 0.45), rng.randfn(0.0, spread * 0.45))
			var roll := rng.randf()
			dot.call(white if roll < 0.3 else (sodium if roll < 0.45 else warm), p.x, p.y, 3.0)
	towns.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.angle_to_point(center) < b.angle_to_point(center))
	for t in range(1, towns.size()):
		var a := towns[t - 1]
		var b := towns[t]
		var steps := int(a.distance_to(b) / 28.0)
		for k in steps:
			var p := a.lerp(b, float(k) / steps) + Vector2(sin(k * 0.4), cos(k * 0.3)) * 6.0
			dot.call(sodium, p.x, p.y, 6.0)
	var root := Node3D.new()
	root.name = "ValleyLights"
	parent.add_child(root)
	root.owner = owner
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var colors := [["Warm", warm, Color(1.0, 0.72, 0.38)], ["White", white, Color(0.85, 0.92, 1.0)], ["Sodium", sodium, MangaArt.SODIUM]]
	for spec in colors:
		var m := ShaderMaterial.new()
		m.shader = CITY_LIGHTS_SHADER
		m.set_shader_parameter("color", spec[2])
		var q := quad.duplicate() as QuadMesh
		q.material = m
		var sc := Scatter.make(spec[0], q, spec[1])
		sc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(sc)
		sc.owner = owner
	print("valley lights: %d warm, %d white, %d sodium" % [warm.size(), white.size(), sodium.size()])



## Posts from a lot's floor (y = 0 in `xf`) down to the slope (the road's fill skirt) under it.
func _stilts(root: Node3D, owner: Node, xf: Transform3D, xs: Array, zs: Array, mat: Material) -> void:
	for sx in xs:
		for sz in zs:
			var foot := xf * Vector3(sx, 0.0, sz)
			var j := nearest_sample(foot.x, foot.z)
			var ground := _roadside(j, (foot - pts[j]).dot(rgt[j])).y - foot.y - 0.3
			if ground > -0.3:
				continue
			_box(root, owner, Vector3(0.14, -ground, 0.14), Transform3D(Basis(), Vector3(sx, ground * 0.5, sz)), mat)


## Floor deck from the road edge back over the lot, in lot space.
func _deck(root: Node3D, owner: Node, w: float, d: float, front: float, mat: Material) -> void:
	_box(root, owner, Vector3(w + 0.2, 0.18, d + front), Transform3D(Basis(), Vector3(0, -0.09, (front - d) * 0.5)), mat)


## Waiting shed: a concrete bench shelter under a GI roof, its open side to the road, with the
## barangay project lettering every PH shed carries.
func _build_shed(parent: Node3D, owner: Node, lot: Dictionary) -> void:
	var xf: Transform3D = lot["xform"]
	var root := Node3D.new()
	root.name = "WaitingShed"
	root.transform = xf
	parent.add_child(root)
	root.owner = owner
	var w := SHED_SIZE.x
	var h := SHED_SIZE.y
	var d := SHED_SIZE.z
	var concrete := MangaArt.world_preset("concrete")
	var paint := MangaArt.world_preset("board")
	var dark := MangaArt.world_preset("pole")
	_deck(root, owner, w, d, 0.6, concrete)
	_box(root, owner, Vector3(w, h, 0.15), Transform3D(Basis(), Vector3(0, h * 0.5, -d + 0.075)), concrete)
	for x in [-w * 0.5 + 0.075, w * 0.5 - 0.075]:
		_box(root, owner, Vector3(0.15, h, d), Transform3D(Basis(), Vector3(x, h * 0.5, -d * 0.5)), concrete)
	# Bench along the back wall.
	_box(root, owner, Vector3(w - 0.4, 0.08, 0.45), Transform3D(Basis(), Vector3(0, 0.45, -d + 0.4)), paint)
	_box(root, owner, Vector3(w - 0.4, 0.45, 0.3), Transform3D(Basis(), Vector3(0, 0.22, -d + 0.4)), concrete)
	# Roof sloping to the back, fascia board with the lettering facing the road.
	var tilt := atan2(0.4, d + 0.8)
	_box(root, owner, Vector3(w + 0.5, 0.05, (d + 0.8) / cos(tilt)), Transform3D(Basis(Vector3.RIGHT, tilt), Vector3(0, h + 0.2, -d * 0.5 + 0.3)), dark)
	_box(root, owner, Vector3(w, 0.5, 0.08), Transform3D(Basis(), Vector3(0, h + 0.1, 0.62)), paint)
	_box(root, owner, Vector3(w, 0.08, 0.1), Transform3D(Basis(), Vector3(0, h - 0.13, 0.63)), MangaArt.accent(TRIM))
	_paint(root, owner, "WAITING SHED", w * 0.9, 0.22, Vector3(0, h + 0.2, 0.67), MangaArt.SIGN_RED)
	_paint(root, owner, "PROJECT NG BRGY. SAN ISIDRO", w * 0.9, 0.1, Vector3(0, h + 0.0, 0.67), MangaArt.INK)
	_stilts(root, owner, xf, [-w * 0.5 + 0.1, w * 0.5 - 0.1], [-d + 0.15], dark)
	_solid(root, owner, "ShedCollision", [
		[Vector3(w, h, 0.15), Transform3D(Basis(), Vector3(0, h * 0.5, -d + 0.075))],
		[Vector3(0.15, h, d), Transform3D(Basis(), Vector3(-w * 0.5 + 0.075, h * 0.5, -d * 0.5))],
		[Vector3(0.15, h, d), Transform3D(Basis(), Vector3(w * 0.5 - 0.075, h * 0.5, -d * 0.5))],
	])


const LAUNDRY := [Color(0.8, 0.07, 0.05), Color(0.95, 0.72, 0.1), Color(0.1, 0.35, 0.8), Color(0.95, 0.93, 0.88), Color(0.15, 0.6, 0.25)]


## Roadside house on stilts over the drop: hollow-block lower wall and plywood upper, a GI roof,
## a door and two windows (one lit warm from inside), and a clothesline (sampayan) in front.
func _build_house(parent: Node3D, owner: Node, lot: Dictionary, n: int) -> void:
	var xf: Transform3D = lot["xform"]
	var root := Node3D.new()
	root.name = "House%d" % n
	root.transform = xf
	parent.add_child(root)
	root.owner = owner
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 7 + n * 131
	var w := HOUSE_SIZE.x
	var h := HOUSE_SIZE.y
	var d := HOUSE_SIZE.z
	var block := MangaArt.world_preset("concrete")
	var ply := MangaArt.world_preset("board")
	var dark := MangaArt.world_preset("pole")
	var ink := MangaArt.world_preset("post")
	# Yard deck from the road edge, then the house set back a metre.
	var front := 1.5
	_deck(root, owner, w, d + 1.0, front, block)
	var z0 := -1.0
	_box(root, owner, Vector3(w, 1.1, d), Transform3D(Basis(), Vector3(0, 0.55, z0 - d * 0.5)), block)
	_box(root, owner, Vector3(w, h - 1.1, d), Transform3D(Basis(), Vector3(0, 1.1 + (h - 1.1) * 0.5, z0 - d * 0.5)), ply)
	# Door, a dark window and a lit window on the road face.
	var face := z0 + 0.02
	_box(root, owner, Vector3(0.9, 2.0, 0.04), Transform3D(Basis(), Vector3(-w * 0.5 + 1.3, 1.0, face)), dark)
	_box(root, owner, Vector3(1.2, 0.9, 0.04), Transform3D(Basis(), Vector3(0.4, 1.6, face)), ink)
	var lit_x := w * 0.5 - 1.4
	var lit := MeshInstance3D.new()
	var lm := QuadMesh.new()
	lm.size = Vector2(1.2, 0.9)
	lm.material = MangaArt.lamp(BULB, 1.2)
	lit.mesh = lm
	lit.position = Vector3(lit_x, 1.6, face + 0.01)
	root.add_child(lit)
	lit.owner = owner
	for wx in [0.4, lit_x]:
		_box(root, owner, Vector3(0.05, 0.9, 0.06), Transform3D(Basis(), Vector3(wx, 1.6, face + 0.02)), dark)
		_box(root, owner, Vector3(1.3, 0.06, 0.12), Transform3D(Basis(), Vector3(wx, 1.12, face + 0.05)), dark)
	var light := OmniLight3D.new()
	light.position = Vector3(lit_x, 1.6, face + 0.8)
	light.omni_range = 3.5
	light.omni_attenuation = 0.8
	light.light_energy = 0.9
	light.light_color = BULB
	light.shadow_enabled = false
	root.add_child(light)
	light.owner = owner
	# GI roof sloping back, overhanging the front.
	var roof_len := d + 1.0
	var tilt := atan2(0.6, roof_len)
	_box(root, owner, Vector3(w + 0.5, 0.05, roof_len / cos(tilt)), Transform3D(Basis(Vector3.RIGHT, tilt), Vector3(0, h + 0.3, z0 - d * 0.5 + 0.5)), dark)
	# Sampayan: a line between two posts in the yard, a few clothes pegged on it (spot color).
	var line_z := 0.0
	for px in [-w * 0.5 + 0.5, 0.6]:
		_box(root, owner, Vector3(0.06, 1.9, 0.06), Transform3D(Basis(), Vector3(px, 0.95, line_z)), dark)
	_box(root, owner, Vector3(w * 0.5 + 0.1, 0.015, 0.015), Transform3D(Basis(), Vector3((-w * 0.5 + 0.5 + 0.6) * 0.5, 1.85, line_z)), ink)
	var x := -w * 0.5 + 0.8
	while x < 0.4:
		var size := Vector2(rng.randf_range(0.3, 0.6), rng.randf_range(0.4, 0.7))
		var col: Color = LAUNDRY[rng.randi() % LAUNDRY.size()]
		_box(root, owner, Vector3(size.x, size.y, 0.01), Transform3D(Basis(), Vector3(x + size.x * 0.5, 1.85 - size.y * 0.5, line_z)), MangaArt.accent(col))
		x += size.x + rng.randf_range(0.08, 0.25)
	_stilts(root, owner, xf, [-w * 0.5 + 0.1, 0.0, w * 0.5 - 0.1], [z0 - 1.5, z0 - d + 0.15], dark)
	_solid(root, owner, "HouseCollision", [
		[Vector3(w, h, d), Transform3D(Basis(), Vector3(0, h * 0.5, z0 - d * 0.5))],
	])


## White-painted rocks along the toe of the cut wall, in stretches (the provincial road edge).
func _build_painted_rocks(parent: Node3D, owner: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 17 + 4
	var xforms: Array[Transform3D] = []
	for i in range(0, pts.size(), 3):
		if (i / 70) % 3 != 1:
			continue
		for side in 2:
			if side_type[i][side] != Side.CUT or absf(curvature[i]) > 1.0 / 60.0:
				continue
			var s := 1.0 if side == 1 else -1.0
			var at := _roadside(i, s * 3.95)
			var sc := Vector3(rng.randf_range(0.5, 0.8), rng.randf_range(0.35, 0.55), rng.randf_range(0.45, 0.7))
			xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(sc), at + Vector3.UP * sc.y * 0.15))
	var rock := SphereMesh.new()
	rock.radius = 0.5
	rock.height = 0.8
	rock.radial_segments = 7
	rock.rings = 3
	rock.material = MangaArt.world_preset("board")
	var sc := Scatter.make("PaintedRocks", rock, xforms)
	parent.add_child(sc)
	sc.owner = owner
