extends RefCounted
## Story mode: the script is well formed, and the Ghost Line composite is cut the way the story
## needs (best sectors, three passes in the cut, seams where the source changes, the logger clock
## resetting there, and a target that is the sum of the chosen sectors).

var errors: Array[String] = []

const TYPES := ["chapter", "talk", "goto", "race", "practice", "attack", "sectors", "crash", "daylight", "evidence", "end"]
const STAGES := ["pass", "hub", "panel"]


func _check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)


func test_beats_are_well_formed() -> void:
	var ids := {}
	for b in StoryScript.BEATS:
		var id: String = b.get("id", "")
		_check(id != "" and not ids.has(id), "unique id: %s" % id)
		ids[id] = true
		_check(b.get("type", "") in TYPES, "%s: known type %s" % [id, b.get("type")])
		_check(b.get("stage", "") in STAGES, "%s: known stage %s" % [id, b.get("stage")])
		if b["type"] in ["race", "practice", "attack", "sectors", "crash", "daylight"]:
			_check(b["stage"] == "pass" or (b["type"] == "race" and b.get("course", "") == "loop" and b["stage"] == "hub"),
				"%s: drives on a stage with a road" % id)
		if b["type"] == "goto":
			_check(b["stage"] == "hub" and HubLayout.PLACES.has(b["place"]), "%s: goto a hub place" % id)
		if b.has("spot"):
			_check(b["stage"] == "hub" and HubLayout.PLACES.has(b["spot"]), "%s: spot is a hub place" % id)
		for key in ["lines", "before", "after", "win", "lose", "beaten"]:
			for line in b.get(key, []):
				var wait: bool = line is Array and line.size() == 2 and line[0] == "~wait" and (line[1] is float or line[1] is int)
				_check(wait or (line is Array and line.size() == 2 and line[0] is String and line[1] is String), "%s.%s: [speaker, text]" % [id, key])
				if line is Array and line.size() == 2 and line[0] == "~sfx":
					_check(StoryDialogue.SFX.has(line[1]), "%s: sound %s exists" % [id, line[1]])
		if b.has("question"):
			var n: int = b["options"].size()
			var pick := int(b.get("pick", 1))
			_check(b["answer"].size() >= pick, "%s: enough right answers to pick %d" % [id, pick])
			for a in b["answer"]:
				_check(int(a) >= 0 and int(a) < n, "%s: answer %d is an option" % [id, a])
		for e in b.get("field", []):
			_check(e.size() == 4 and CarRoster.get_car(e[1])["id"] == e[1], "%s: field entry %s" % [id, e])
	_check(StoryScript.BEATS[StoryScript.BEATS.size() - 1]["type"] == "end", "the story ends on an end beat")
	_check(StoryScript.acts().size() == 6, "prologue and five acts (got %d)" % StoryScript.acts().size())


func test_every_storyboard_scene_has_a_beat() -> void:
	var scenes := {}
	for b in StoryScript.BEATS:
		scenes[b["scene"]] = true
	for k in 36:
		_check(scenes.has("S%02d" % k), "S%02d is in the script" % k)


## Three passes, each sampled at GhostLine.HZ, driving a fake 1000 m road at constant per-sector
## speeds: pass `i` is fastest in the sectors listed in `best`.
func _pass(label: String, speeds: Array, lane: float) -> Dictionary:
	var frames := PackedFloat32Array()
	var splits := PackedFloat64Array()
	var d := 0.0
	var t := 0.0
	var k := 0
	var sector_len := 250.0
	while k < 4:
		frames.append_array([d, 0.0, lane, 0.0, 0.0, 0.0, 1.0, speeds[k], 0.1, 1.0, 0.0, d])
		d += speeds[k] / GhostLine.HZ
		t += 1.0 / GhostLine.HZ
		if d >= sector_len * (k + 1):
			splits.append(t)
			k += 1
	return { "label": label, "frames": frames, "splits": splits, "time": t }


func test_composite_takes_best_sectors_from_three_passes() -> void:
	var a := _pass("A", [30.0, 20.0, 20.0, 20.0], -1.0)
	var b := _pass("B", [20.0, 30.0, 25.0, 20.0], 0.0)
	var c := _pass("C", [20.0, 20.0, 20.0, 30.0], 1.0)
	var g := GhostLine.composite([a, b, c])
	_check(g.valid(), "composite has frames")
	_check(Array(g.picks) == [0, 1, 1, 2], "best sectors: A, B, B, C (got %s)" % [g.picks])
	var sum := 0.0
	for k in 4:
		sum += g.source_sectors[g.picks[k]][k]
	_check(absf(g.time - sum) < 1e-6, "target is the sum of the chosen sectors")
	_check(g.time < a["time"] and g.time < b["time"] and g.time < c["time"], "faster than any single pass")
	_check(g.seams.size() == 2, "two joins where the source pass changes (got %d)" % g.seams.size())
	# At a join the picture jumps lanes and the logger clock jumps back or forward.
	var i := int(round(g.seams[0] * GhostLine.HZ))
	_check(absf(g.value(i, 2) - g.value(i - 1, 2)) > 0.5, "the car steps sideways at the seam")
	_check(absf(g.clock[i] - g.clock[i - 1] - 1.0 / GhostLine.HZ) > 0.5, "the logger clock is not continuous at the seam")


func test_composite_never_cuts_from_one_pass() -> void:
	# Pass A is fastest everywhere: a "best of" would be one run. The cut still uses three passes.
	var a := _pass("A", [30.0, 30.0, 30.0, 30.0], 0.0)
	var b := _pass("B", [25.0, 29.0, 20.0, 20.0], 1.0)
	var c := _pass("C", [20.0, 20.0, 20.0, 29.0], -1.0)
	var g := GhostLine.composite([a, b, c])
	var used := {}
	for p in g.picks:
		used[p] = true
	_check(used.size() == 3, "three passes in the cut (got %s)" % [g.picks])
	_check(g.seams.size() >= 2, "and so at least two seams")


func test_ghost_pose_interpolates_and_ends() -> void:
	var a := _pass("A", [20.0, 20.0, 20.0, 20.0], 0.0)
	var g := GhostLine.composite([a])
	var p := g.pose(0.025)
	_check(not p.is_empty() and absf((p["position"] as Vector3).x - 0.5) < 0.01, "half a frame in: half a frame's distance")
	_check(g.pose(g.time + 1.0).is_empty(), "nothing past the end")


func test_fatal_bend_is_hairpin_8a() -> void:
	var s: Dictionary = Touge01Layout.SEGMENTS[StoryCourse.FATAL_SEGMENT]
	_check(s.has("r") and float(s["a"]) == 170.0, "8A is the 170° right hairpin")
	_check(absf(StoryCourse.fatal_entry() - 823.05) < 0.1, "8A starts at ~823 m (got %.2f)" % StoryCourse.fatal_entry())
	var lower := StoryCourse.lower_leg()
	_check(lower.x >= StoryCourse.fatal_exit() and lower.y > lower.x, "the lower switchback is further down the road")
