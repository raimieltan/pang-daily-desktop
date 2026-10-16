class_name GhostLine
extends RefCounted
## Jolo's "COMPOSITE LINE STUDY — BEST SECTORS / NOT ONE RUN": the best sector of each practice
## pass, cut together into one clip that looks like a single drive. Every frame is real; the run
## never happened. Its target ("GHOST TIME") is the sum of the chosen sectors.
##
## Frames are StoryRecorder samples (STRIDE floats at HZ). At each join the clip jumps from one
## pass to another: the car's position steps sideways, the speed trace steps, and the logger clock
## (`clock`, time into the source pass) resets. Those are the seams the investigation finds.

const HZ := 20.0
## x y z, rotation quaternion (4), speed m/s, steer, throttle, brake, distance along the road.
const STRIDE := 12
const SPEED := 7
const STEER := 8
const THROTTLE := 9
const BRAKE := 10
const DISTANCE := 11

var frames := PackedFloat32Array()
## Cumulative sector times of the composite (the HUD's split reference).
var splits := PackedFloat64Array()
var time := 0.0
## Which source pass each sector came from, and each source's label.
var picks := PackedInt32Array()
var labels := PackedStringArray()
## Every source's own sector times: [[s1, s2, s3, s4], ...].
var source_sectors: Array = []
## Per frame: the source pass, and the time into that pass (the logger clock).
var source := PackedInt32Array()
var clock := PackedFloat32Array()
## Composite times where the clip cuts to another pass.
var seams := PackedFloat64Array()


func valid() -> bool:
	return frames.size() >= STRIDE * 2


func frame_count() -> int:
	return frames.size() / STRIDE


func value(i: int, field: int) -> float:
	return frames[clampi(i, 0, frame_count() - 1) * STRIDE + field]


## Pose at `t` seconds into the clip; empty past its end.
func pose(t: float) -> Dictionary:
	return pose_in(frames, t)


static func pose_in(data: PackedFloat32Array, t: float) -> Dictionary:
	var n := data.size() / STRIDE
	var f := t * HZ
	var i := int(f)
	if n < 2 or t < 0.0 or i >= n - 1:
		return {}
	var a := i * STRIDE
	var b := a + STRIDE
	var w := f - i
	var p := Vector3(data[a], data[a + 1], data[a + 2]).lerp(Vector3(data[b], data[b + 1], data[b + 2]), w)
	var q := Quaternion(data[a + 3], data[a + 4], data[a + 5], data[a + 6]).normalized().slerp(
		Quaternion(data[b + 3], data[b + 4], data[b + 5], data[b + 6]).normalized(), w)
	return { "position": p, "rotation": q }


func sector_time(k: int) -> float:
	return splits[k] - (splits[k - 1] if k > 0 else 0.0)


## Best sectors of `sources` ({ label, frames, splits, time }), at least three passes in the cut
## when there are three to choose from (a "best of" that is one pass is not a composite).
static func composite(sources: Array) -> GhostLine:
	var g := GhostLine.new()
	var usable: Array = []
	for s in sources:
		if (s["splits"] as PackedFloat64Array).size() >= 4 and (s["frames"] as PackedFloat32Array).size() >= STRIDE * 2:
			usable.append(s)
	if usable.is_empty():
		return g
	var sectors := 4
	for s in usable:
		g.labels.append(s["label"])
		var own := []
		var sp: PackedFloat64Array = s["splits"]
		for k in sectors:
			own.append(sp[k] - (sp[k - 1] if k > 0 else 0.0))
		g.source_sectors.append(own)
	# Fastest source per sector, then make sure the cut uses enough passes.
	for k in sectors:
		var best := 0
		for i in usable.size():
			if g.source_sectors[i][k] < g.source_sectors[best][k]:
				best = i
		g.picks.append(best)
	var want := mini(3, usable.size())
	while _distinct(g.picks) < want:
		var swap_k := -1
		var swap_to := -1
		var cost := INF
		for k in sectors:
			if _count(g.picks, g.picks[k]) < 2:
				continue
			for i in usable.size():
				if i in g.picks:
					continue
				var c: float = g.source_sectors[i][k] - g.source_sectors[g.picks[k]][k]
				if c < cost:
					cost = c
					swap_k = k
					swap_to = i
		if swap_k < 0:
			break
		g.picks[swap_k] = swap_to
	# Cut the frames together.
	var total := 0.0
	for k in sectors:
		var s: Dictionary = usable[g.picks[k]]
		var sp: PackedFloat64Array = s["splits"]
		var from := (sp[k - 1] if k > 0 else 0.0)
		var to := sp[k]
		var data: PackedFloat32Array = s["frames"]
		var i0 := int(round(from * HZ))
		var i1 := mini(int(round(to * HZ)), data.size() / STRIDE - 1)
		if k > 0 and g.picks[k] != g.picks[k - 1]:
			g.seams.append(total)
		for i in range(i0, i1):
			g.frames.append_array(data.slice(i * STRIDE, (i + 1) * STRIDE))
			g.source.append(g.picks[k])
			g.clock.append(i / HZ)
		total += to - from
		g.splits.append(total)
	g.time = total
	return g


static func _distinct(a: PackedInt32Array) -> int:
	var seen := {}
	for v in a:
		seen[v] = true
	return seen.size()


static func _count(a: PackedInt32Array, v: int) -> int:
	var n := 0
	for x in a:
		if x == v:
			n += 1
	return n
