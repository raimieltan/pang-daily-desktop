class_name TrackData
extends Resource
## A road's centerline, sampled every `spacing` metres along its length at the road surface.
## Used for spawning, resets, checkpoints, timing and (later) AI racing lines.

@export var points := PackedVector3Array()
## Unit travel direction at each sample (3D, follows the grade).
@export var forwards := PackedVector3Array()
## Horizontal unit vector to the driver's right at each sample.
@export var rights := PackedVector3Array()
@export var spacing := 1.0
@export var half_width := 3.6
@export var start_distance := 20.0
@export var finish_distance := 0.0


func length() -> float:
	return (points.size() - 1) * spacing


func index_at(distance: float) -> int:
	return clampi(roundi(distance / spacing), 0, points.size() - 1)


## Nearest sample to a world position (horizontal distance; heights only break ties near overpasses).
func nearest_index(p: Vector3, hint := -1, window := 80) -> int:
	var lo := 0
	var hi := points.size()
	if hint >= 0:
		lo = maxi(0, hint - window)
		hi = mini(points.size(), hint + window)
	var best := lo
	var best_d := INF
	for i in range(lo, hi):
		var q := points[i]
		var d := Vector2(q.x - p.x, q.z - p.z).length_squared() + 0.25 * (q.y - p.y) * (q.y - p.y)
		if d < best_d:
			best_d = d
			best = i
	return best


func distance_at(p: Vector3, hint := -1) -> float:
	return nearest_index(p, hint) * spacing


## Lateral offset from the centerline (right +) at the nearest sample.
func lateral_offset(p: Vector3, index: int) -> float:
	return (p - points[index]).dot(rights[index])


## Spawn pose for `CarBody.place`: heading turns the car's -Z forward onto the road direction.
func pose_at(distance: float, lateral := 0.0) -> Dictionary:
	var i := index_at(distance)
	var f := forwards[i]
	return { "position": points[i] + rights[i] * lateral + Vector3.UP * 0.3, "heading": atan2(-f.x, -f.z) }
