class_name Scatter
extends MultiMeshInstance3D
## A MultiMesh whose instance transforms are stored as plain data and applied on load.
## (Offline builds run headless on the dummy renderer, which drops MultiMesh instance buffers.)

@export var transforms: Array[Transform3D] = []


func _ready() -> void:
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])


static func make(name_: String, mesh: Mesh, transforms_: Array[Transform3D]) -> Scatter:
	var s := Scatter.new()
	s.name = name_
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	s.multimesh = mm
	s.transforms = transforms_
	# Instances cover the whole map; give culling the real extent.
	var box := AABB()
	for i in transforms_.size():
		var p := transforms_[i].origin
		box = AABB(p, Vector3.ZERO) if i == 0 else box.expand(p)
	s.custom_aabb = box.grow(15.0)
	return s


## Splits instances into square chunks of `chunk` metres, each its own Scatter with a visibility
## range, so frustum culling and distance culling work per chunk instead of for the whole forest.
static func make_chunked(name_: String, mesh: Mesh, transforms_: Array[Transform3D], chunk := 140.0, visible_to := 480.0) -> Node3D:
	var root := Node3D.new()
	root.name = name_
	var buckets := {}
	for t in transforms_:
		var key := Vector2i(floori(t.origin.x / chunk), floori(t.origin.z / chunk))
		if not buckets.has(key):
			buckets[key] = [] as Array[Transform3D]
		(buckets[key] as Array[Transform3D]).append(t)
	for key in buckets:
		var part := make("%s_%d_%d" % [name_, key.x, key.y], mesh, buckets[key])
		part.visibility_range_end = visible_to
		part.visibility_range_end_margin = 30.0
		root.add_child(part)
	return root
