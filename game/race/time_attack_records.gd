class_name TimeAttackRecords
extends RefCounted
## Local best times and ghosts (user://), per track and car. A ghost is the car's pose sampled at
## `GHOST_HZ`: position (3) + rotation quaternion (4) floats per frame.

const DIR := "user://time_attack/"
const GHOST_HZ := 20.0


static func _key(track_id: String, car_id: String) -> String:
	return "%s__%s" % [track_id, car_id]


static func load_best(track_id: String, car_id: String) -> Dictionary:
	var path := DIR + _key(track_id, car_id) + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


static func load_ghost(track_id: String, car_id: String) -> PackedFloat32Array:
	var path := DIR + _key(track_id, car_id) + ".ghost"
	if not FileAccess.file_exists(path):
		return PackedFloat32Array()
	return FileAccess.get_file_as_bytes(path).to_float32_array()


## Saves the run if it beats the stored best. Returns true when it is a new record.
static func submit(track_id: String, car_id: String, time: float, splits: PackedFloat64Array, ghost: PackedFloat32Array) -> bool:
	var best := load_best(track_id, car_id)
	if best.has("time") and float(best["time"]) <= time:
		return false
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(DIR + _key(track_id, car_id) + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify({ "time": time, "splits": Array(splits), "date": Time.get_datetime_string_from_system() }))
	f.close()
	var g := FileAccess.open(DIR + _key(track_id, car_id) + ".ghost", FileAccess.WRITE)
	g.store_buffer(ghost.to_byte_array())
	g.close()
	return true


## Ghost pose at `t` seconds into the run, interpolated; empty when past the end.
static func ghost_pose(ghost: PackedFloat32Array, t: float) -> Dictionary:
	var frames := ghost.size() / 7
	if frames < 2:
		return {}
	var f := t * GHOST_HZ
	var i := int(f)
	if i >= frames - 1:
		return {}
	var a := i * 7
	var b := a + 7
	var w := f - i
	var p := Vector3(ghost[a], ghost[a + 1], ghost[a + 2]).lerp(Vector3(ghost[b], ghost[b + 1], ghost[b + 2]), w)
	var q := Quaternion(ghost[a + 3], ghost[a + 4], ghost[a + 5], ghost[a + 6]).slerp(Quaternion(ghost[b + 3], ghost[b + 4], ghost[b + 5], ghost[b + 6]), w)
	return { "position": p, "rotation": q }
