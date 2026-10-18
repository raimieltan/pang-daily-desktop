class_name StoryCourse
extends RefCounted
## Where the story happens on Pass 1 (maps/touge_01/layout.gd), in metres along the road: the
## fatal bend is hairpin 8A; the lower switchback is the 10% leg below it, between 8A and 8B, which
## sits 12–24° off the nose and 6–12 m down from the last 100 m of the approach: a car's lights
## there show through the trees. Track distance equals layout distance (no lead-in).

const FATAL_SEGMENT := 17
const LOWER_FROM_SEGMENT := 18
const LOWER_TO_SEGMENT := 19


static func segment_start(index: int) -> float:
	var d := 0.0
	for i in mini(index, Touge01Layout.SEGMENTS.size()):
		var s: Dictionary = Touge01Layout.SEGMENTS[i]
		d += float(s["s"]) if s.has("s") else float(s["r"]) * deg_to_rad(absf(float(s["a"])))
	return d


static func fatal_entry() -> float:
	return segment_start(FATAL_SEGMENT)


static func fatal_exit() -> float:
	return segment_start(FATAL_SEGMENT + 1)


static func lower_leg() -> Vector2:
	return Vector2(segment_start(LOWER_FROM_SEGMENT), segment_start(LOWER_TO_SEGMENT))


## Composite time at which the ghost reaches `distance` (first frame at or past it).
static func ghost_time_at(ghost: GhostLine, distance: float) -> float:
	for i in ghost.frame_count():
		if ghost.value(i, GhostLine.DISTANCE) >= distance:
			return i / GhostLine.HZ
	return 0.0


## Where the lights on the lower switchback are seen from a recorded run (the night run, or the
## lights test): from 170 m before 8A they come uphill at HeadlightsRig's pace; per frame up to
## just past 8A, (distance along the road, bearing of the lights off the car's nose in degrees,
## + right). Both runs measured the same way, so the test can be laid over the crash.
const LIGHTS_FROM := 170.0
const LIGHTS_SPEED := 8.0


static func lights_distance(seconds: float) -> float:
	var lower := lower_leg()
	return maxf(lower.x + 12.0, lower.y + 10.0 - LIGHTS_SPEED * seconds)


static func lights_bearings(frames: PackedFloat32Array, track: TrackData) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := frames.size() / GhostLine.STRIDE
	var entry := fatal_entry()
	var start := -1
	for i in n:
		var f := i * GhostLine.STRIDE
		var d := frames[f + GhostLine.DISTANCE]
		if start < 0:
			if d < entry - LIGHTS_FROM:
				continue
			start = i
		if d > entry + 20.0:
			break
		var lights: Vector3 = track.pose_at(lights_distance((i - start) / GhostLine.HZ), -1.8)["position"]
		var pos := Vector3(frames[f], frames[f + 1], frames[f + 2])
		var q := Quaternion(frames[f + 3], frames[f + 4], frames[f + 5], frames[f + 6])
		var nose := -(Basis(q).z)
		var to := lights - pos
		var bearing := rad_to_deg(Vector2(nose.x, nose.z).angle_to(Vector2(to.x, to.z)))
		out.append(Vector2(d, bearing))
	return out
