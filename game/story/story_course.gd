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
