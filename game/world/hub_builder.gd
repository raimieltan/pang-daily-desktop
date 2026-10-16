class_name HubBuilder
## Builds the barangay hub at runtime (it is small: a road loop, a few dozen houses and two
## Blender buildings, well under the 3 s hub budget): ground and its collider, the main road and
## the loop, houses, poles and sagging wires, sodium street lamps, the perimeter wall, the gas
## station and Suki 24 as simple blocks, Kyo Coffee and the talyer from their GLBs.

const KYO_GLB := "res://assets/world/kyo_coffee.glb"
const TALYER_GLB := "res://assets/world/talyer.glb"

var root: Node3D
## Lamps and shop lights: on at night only (by day a lamp's pool would read as a paper blot).
var lights: Array[Light3D] = []


func build(parent: Node3D) -> Node3D:
	root = Node3D.new()
	root.name = "Barangay"
	parent.add_child(root)
	_ground()
	_roads()
	_walls()
	for h in HubLayout.HOUSES:
		_house(Vector2(h[0], h[1]), Vector2(h[2], h[3]), h[4], h[5], h[6])
	_gas_station()
	_suki()
	_poles()
	_lamps()
	_exit_sign()
	WorldKit.place(root, KYO_GLB, HubLayout.KYO_ORIGIN.x, HubLayout.KYO_ORIGIN.y)
	WorldKit.place(root, TALYER_GLB, HubLayout.TALYER_ORIGIN.x, HubLayout.TALYER_ORIGIN.y)
	_place_lights()
	return root


# --- ground and roads ---------------------------------------------------------------------------

func _ground() -> void:
	var b := HubLayout.BOUNDS.grow(40)
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = b.size
	plane.material = MangaArt.world_preset("grass")
	mi.mesh = plane
	mi.position = HubLayout.pos(b.get_center().x, b.get_center().y)
	root.add_child(mi)
	# One slab under everything, top at y = 0: the roads and lots are paint on it.
	_solid("GroundCollision", [[Vector3(b.size.x, 1.0, b.size.y), HubLayout.pos(b.get_center().x, b.get_center().y, -0.5)]])


func _roads() -> void:
	var main := PackedVector2Array([Vector2(HubLayout.MAIN_FROM, 0), Vector2(HubLayout.MAIN_TO, 0)])
	_ribbon("MainRoad", main, HubLayout.MAIN_WIDTH, 0.03, 5.2)
	# The loop's south leg is the main road itself; draw the rest, cut inside the main road's width.
	var loop := HubLayout.loop_points()
	var legs := PackedVector2Array()
	for p in loop:
		if p.y >= 3.0:
			legs.append(p)
	_ribbon("Loop", legs, HubLayout.LOOP_WIDTH, 0.025, 3.9)
	# Concrete aprons: in front of the talyer and Kyo, the gas station forecourt, Suki 24's lot.
	for r in [Rect2(5, 144.5, 45, 6), Rect2(-6, 6, 62, 38), Rect2(-86, 6, 36, 30), Rect2(-90, 144.5, 24, 12)]:
		_slab(r, 0.015, MangaArt.world_preset("concrete"))


## A road ribbon along `pts` (hub x, z): UV x is lateral metres, y distance, as the road shader wants.
func _ribbon(name: String, pts: PackedVector2Array, width: float, y: float, lane_half: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := width * 0.5
	var dist := 0.0
	var left := []
	var right := []
	var dists := []
	for i in pts.size():
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, pts.size() - 1)]
		var f := (b - a).normalized()
		var r := Vector2(f.y, -f.x)   # right of travel in hub (x east, z north)
		if i > 0:
			dist += pts[i].distance_to(pts[i - 1])
		left.append(pts[i] - r * half)
		right.append(pts[i] + r * half)
		dists.append(dist)
	for i in pts.size() - 1:
		var quad := [[left[i], -half, dists[i]], [right[i], half, dists[i]],
			[right[i + 1], half, dists[i + 1]], [left[i + 1], -half, dists[i + 1]]]
		for k in [0, 2, 1, 0, 3, 2]:
			var v: Array = quad[k]
			st.set_color(Color(0, 0, 0, 1))
			st.set_uv(Vector2(v[1], v[2]))
			st.set_normal(Vector3.UP)
			st.add_vertex(HubLayout.pos(v[0].x, v[0].y, y))
	var mat := MangaArt.road()
	mat.set_shader_parameter("lane_half_width", lane_half)
	st.set_material(mat)
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


func _slab(r: Rect2, y: float, mat: Material) -> void:
	var c := r.get_center()
	_box(Vector3(r.size.x, 0.02, r.size.y), Transform3D(Basis(), HubLayout.pos(c.x, c.y, y)), mat, false)


# --- buildings ----------------------------------------------------------------------------------

## A bungalow: hollow-block walls, a GI roof (pitched, ridge along the front), a door and windows
## on the facing side, and a low wall with a gate gap toward the street.
func _house(c: Vector2, size: Vector2, wall: float, roof: float, facing: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, HubLayout.yaw(facing)), HubLayout.pos(c.x, c.y))
	var h := 2.8
	var node := Node3D.new()
	node.transform = xf
	root.add_child(node)
	# Local frame: −Z is the facing side (front), size.x across it, size.y deep.
	_box(Vector3(size.x, h, size.y), Transform3D(Basis(), Vector3(0, h * 0.5, 0)), WorldKit.tone(wall), true, node)
	var prism := PrismMesh.new()
	prism.size = Vector3(size.y + 1.2, 1.6, size.x + 1.0)
	prism.material = WorldKit.tone(roof)
	var r := MeshInstance3D.new()
	r.mesh = prism
	r.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, h + 0.8, 0))
	node.add_child(r)
	var dark := WorldKit.tone(0.12)
	var front := -size.y * 0.5 - 0.03
	_box(Vector3(1.0, 2.1, 0.06), Transform3D(Basis(), Vector3(-size.x * 0.2, 1.05, front)), dark, false, node)
	for x in [size.x * 0.12, size.x * 0.32]:
		_box(Vector3(1.3, 1.0, 0.06), Transform3D(Basis(), Vector3(x, 1.6, front)), dark, false, node)
	# Front yard wall, a gate gap in front of the door.
	var yard := -size.y * 0.5 - 3.0
	var wall_mat := WorldKit.tone(wall + 0.08)
	var gap := -size.x * 0.2
	var left_w := gap - 1.4 - (-size.x * 0.5)
	var right_w := size.x * 0.5 - (gap + 1.4)
	_box(Vector3(left_w, 1.3, 0.2), Transform3D(Basis(), Vector3(-size.x * 0.5 + left_w * 0.5, 0.65, yard)), wall_mat, true, node)
	_box(Vector3(right_w, 1.3, 0.2), Transform3D(Basis(), Vector3(size.x * 0.5 - right_w * 0.5, 0.65, yard)), wall_mat, true, node)


func _gas_station() -> void:
	var white := WorldKit.tone(0.92)
	_box(Vector3(40, 0.6, 20), Transform3D(Basis(), HubLayout.pos(25, 24, 5.8)), white, false)
	for z in [13.95, 34.05]:
		_box(Vector3(40.2, 0.5, 0.12), Transform3D(Basis(), HubLayout.pos(25, z, 5.8)), MangaArt.accent(Color("#19b58a")), false)
	for p in [Vector2(9, 17), Vector2(41, 17), Vector2(9, 31), Vector2(41, 31)]:
		_box(Vector3(0.6, 5.5, 0.6), Transform3D(Basis(), HubLayout.pos(p.x, p.y, 2.75)), white, true)
	for x in [17.0, 33.0]:
		_box(Vector3(1.2, 1.8, 2.4), Transform3D(Basis(), HubLayout.pos(x, 24, 0.9)), WorldKit.tone(0.8), true)
		_box(Vector3(1.6, 0.25, 6.0), Transform3D(Basis(), HubLayout.pos(x, 24, 0.12)), white, false)
	_box(Vector3(10, 3.2, 6), Transform3D(Basis(), HubLayout.pos(25, 40.5, 1.6)), WorldKit.tone(0.85), true)
	_paint("BAHANDI FUELS", Vector3(8, 0.9, 0), Transform3D(Basis(), HubLayout.pos(25, 37.45, 2.6)), Color("#19b58a"))


func _suki() -> void:
	_box(Vector3(16, 3.4, 10), Transform3D(Basis(), HubLayout.pos(-68, 31, 1.7)), WorldKit.tone(0.88), true)
	_box(Vector3(16.2, 0.9, 0.2), Transform3D(Basis(), HubLayout.pos(-68, 25.9, 3.0)), MangaArt.accent(Color("#2f6bff")), false)
	_paint("SUKI 24", Vector3(6, 0.7, 0), Transform3D(Basis(), HubLayout.pos(-68, 25.78, 3.0)), Color("#ffd23a"))
	_box(Vector3(9, 2.2, 0.05), Transform3D(Basis(), HubLayout.pos(-68, 25.97, 1.25)), MangaArt.lamp(Color("#f4ecd0"), 0.5), false)


func _walls() -> void:
	var b := HubLayout.BOUNDS
	var mat := WorldKit.tone(0.82)
	var h := 2.4
	var x0 := b.position.x
	var x1 := b.end.x
	var z0 := b.position.y
	var z1 := b.end.y
	var runs := [
		[Vector2(x0, z0), Vector2(x1, z0)], [Vector2(x0, z1), Vector2(x1, z1)],
		[Vector2(x0, z0), Vector2(x0, -8)], [Vector2(x0, 8), Vector2(x0, z1)],
		[Vector2(x1, z0), Vector2(x1, -8)], [Vector2(x1, 8), Vector2(x1, z1)],
	]
	for r in runs:
		var a: Vector2 = r[0]
		var c: Vector2 = r[1]
		var mid := (a + c) * 0.5
		var length := a.distance_to(c)
		var along_x := absf(c.x - a.x) > absf(c.y - a.y)
		var size := Vector3(length, h, 0.25) if along_x else Vector3(0.25, h, length)
		_box(size, Transform3D(Basis(), HubLayout.pos(mid.x, mid.y, h * 0.5)), mat, true)
	# Road closures where the main road meets the wall: striped barriers.
	for x in [x0 + 1.5, x1 - 1.5]:
		_box(Vector3(0.4, 1.1, 14), Transform3D(Basis(), HubLayout.pos(x, 0, 0.55)), MangaArt.world_preset("delineator"), true)


func _exit_sign() -> void:
	var post := MangaArt.world_preset("post")
	for z in [-7.5, -11.5]:
		_box(Vector3(0.12, 3.2, 0.12), Transform3D(Basis(), HubLayout.pos(226, z, 1.6)), post, false)
	_box(Vector3(0.08, 1.4, 4.6), Transform3D(Basis(), HubLayout.pos(226, -9.5, 2.6)), MangaArt.accent(Color("#1f6b3a")), false)
	_paint("PASS 1  →", Vector3(4.2, 0.8, 0), Transform3D(Basis(Vector3.UP, -PI * 0.5), HubLayout.pos(225.95, -9.5, 2.6)), MangaArt.PAPER)


# --- street furniture ---------------------------------------------------------------------------

func _poles() -> void:
	var lines := [
		_line(Vector2(-148, -12.5), Vector2(244, -12.5), 36.0),
		_line(Vector2(-80, 134), Vector2(95, 134), 30.0),
		_line(Vector2(113.5, 40), Vector2(113.5, 100), 30.0),
		# Kyo's frontage, poles clear of the apron's parking spots and the arrival spot.
		[Vector2(125.4, 85), Vector2(125.4, 99), Vector2(125.4, 115)] as Array[Vector2],
	]
	var pole := CylinderMesh.new()
	pole.top_radius = 0.12
	pole.bottom_radius = 0.16
	pole.height = 9.0
	pole.radial_segments = 8
	pole.material = MangaArt.world_preset("pole")
	var xforms: Array[Transform3D] = []
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for line in lines:
		var tops: Array[Vector3] = []
		for p in line:
			xforms.append(Transform3D(Basis(), HubLayout.pos(p.x, p.y, 4.5)))
			tops.append(HubLayout.pos(p.x, p.y, 8.45))
			_solid("Pole", [[Vector3(0.3, 9, 0.3), HubLayout.pos(p.x, p.y, 4.5)]])
		for k in range(1, tops.size()):
			_wires(st, tops[k - 1], tops[k])
	var s := Scatter.make("Poles", pole, xforms)
	root.add_child(s)
	st.generate_normals()
	st.set_material(MangaArt.world_preset("pole"))
	var wires := MeshInstance3D.new()
	wires.name = "Wires"
	wires.mesh = st.commit()
	wires.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(wires)


func _line(a: Vector2, b: Vector2, step: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var n := maxi(1, roundi(a.distance_to(b) / step))
	for i in n + 1:
		out.append(a.lerp(b, float(i) / n))
	return out


## Three sagging wires between two pole tops, as thin dark ribbons.
func _wires(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var across := (b - a).cross(Vector3.UP).normalized()
	for w: float in [-0.75, 0.0, 0.75]:
		var prev := Vector3.ZERO
		for k in 13:
			var t := k / 12.0
			var p := a.lerp(b, t) + across * w + Vector3.DOWN * sin(PI * t) * 0.55
			if k > 0:
				var up := Vector3.UP * 0.018
				for v in [prev - up, p - up, p + up, prev - up, p + up, prev + up]:
					st.add_vertex(v)
			prev = p


func _lamps() -> void:
	for x in range(-140, 241, 28):
		_street_lamp(Vector2(x, -7.5), 0.0)
	# Inside the loop, every ~40 m, off the main road.
	var loop := HubLayout.loop_points()
	for i in range(20, loop.size() - 20, 42):
		var p := loop[i]
		if p.y < 10.0:
			continue
		var f := (loop[i + 1] - loop[i - 1]).normalized()
		var r := Vector2(f.y, -f.x)
		var at := p + r * (HubLayout.LOOP_WIDTH * 0.5 + 1.0)
		_street_lamp(at, rad_to_deg(atan2(-r.x, -r.y)))


## Sodium street lamp: post, arm reaching over the road toward `facing` (deg, 0 north), head, spot.
func _street_lamp(at: Vector2, facing: float) -> void:
	var node := Node3D.new()
	node.transform = Transform3D(Basis(Vector3.UP, HubLayout.yaw(facing)), HubLayout.pos(at.x, at.y))
	root.add_child(node)
	var pole := MangaArt.world_preset("pole")
	_box(Vector3(0.16, 7.0, 0.16), Transform3D(Basis(), Vector3(0, 3.5, 0)), pole, false, node)
	_box(Vector3(0.1, 0.1, 2.4), Transform3D(Basis(), Vector3(0, 7.0, -1.2)), pole, false, node)
	_box(Vector3(0.3, 0.14, 0.5), Transform3D(Basis(), Vector3(0, 6.95, -2.3)), MangaArt.lamp(MangaArt.SODIUM), false, node)
	_solid("LampPost", [[Vector3(0.25, 7, 0.25), node.transform.origin + Vector3.UP * 3.5]])
	var light := SpotLight3D.new()
	light.position = Vector3(0, 6.8, -2.3)
	light.rotation_degrees = Vector3(-90, 0, 0)
	light.spot_range = 11.0
	light.spot_angle = 38.0
	light.spot_angle_attenuation = 0.05
	light.spot_attenuation = 0.5
	light.light_energy = 2.4
	light.light_color = MangaArt.SODIUM
	light.shadow_enabled = false
	node.add_child(light)
	lights.append(light)


## The talyer's fluorescents.
func _place_lights() -> void:
	var tube := Color(0.92, 0.96, 0.9)
	# Kyo has none: its lit glass and downlights glow on their own, and any pool near the white
	# storefront paints it solid paper.
	for spec in [[Vector3(16, 3.9, 158), tube, 1.0, 6.0],
			[Vector3(32, 3.9, 158), tube, 1.0, 6.0], [Vector3(24, 3.9, 151), tube, 0.8, 5.0],
			[Vector3(44, 2.7, 153), tube, 0.7, 4.0]]:
		var light := OmniLight3D.new()
		var p: Vector3 = spec[0]
		light.position = HubLayout.pos(p.x, p.z, p.y)
		light.light_color = spec[1]
		light.light_energy = spec[2]
		light.omni_range = spec[3]
		light.omni_attenuation = 0.8
		light.shadow_enabled = false
		root.add_child(light)
		lights.append(light)


# --- helpers ------------------------------------------------------------------------------------

func _box(size: Vector3, xform: Transform3D, mat: Material, collide: bool, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.transform = xform
	(parent if parent else root).add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = CarBody.STATIC_LAYER
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		shape.shape = bs
		body.add_child(shape)
		mi.add_child(body)
	return mi


func _solid(name: String, shapes: Array) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.collision_layer = CarBody.STATIC_LAYER
	body.collision_mask = 0
	root.add_child(body)
	for spec in shapes:
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = spec[0]
		shape.shape = bs
		shape.position = spec[1]
		body.add_child(shape)


## Painted lettering facing +Z of `xform` (hub south for an unrotated sign), fitted to size.x × size.y.
func _paint(text: String, size: Vector3, xform: Transform3D, ink: Color) -> void:
	var font_px := 64
	var label := Label3D.new()
	label.text = text
	label.font_size = font_px
	label.pixel_size = minf(size.y, size.x * 0.9 / maxf(text.length(), 1) * 1.6) / font_px
	label.modulate = ink
	label.outline_size = 0
	label.shaded = false
	label.double_sided = false
	label.transform = xform
	root.add_child(label)
