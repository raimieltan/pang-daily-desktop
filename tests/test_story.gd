extends RefCounted
## Story mode: the script is well formed, and the Ghost Line composite is cut the way the story
## needs (best sectors, three passes in the cut, seams where the source changes, the logger clock
## resetting there, and a target that is the sum of the chosen sectors).

var errors: Array[String] = []

const TYPES := ["chapter", "talk", "goto", "race", "practice", "attack", "sectors", "crash", "daylight", "evidence", "end"]
const STAGES := ["pass", "hub", "room", "panel"]


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
		if b["stage"] == "room":
			_check(StoryRoom.SETS.has(b.get("set", "")), "%s: room set %s exists" % [id, b.get("set")])
		if b.has("spot"):
			_check(b["stage"] == "hub" and HubLayout.PLACES.has(b["spot"]), "%s: spot is a hub place" % id)
		for key in ["lines", "before", "after", "win", "lose", "beaten"]:
			for line in b.get(key, []):
				var wait: bool = line is Array and line.size() == 2 and line[0] == "~wait" and (line[1] is float or line[1] is int)
				_check(wait or (line is Array and line.size() == 2 and line[0] is String and line[1] is String), "%s.%s: [speaker, text]" % [id, key])
				if line is Array and line.size() == 2 and line[0] == "~set":
					_check(b["stage"] == "room" and StoryRoom.SETS.has(line[1]), "%s: ~set %s is a room set" % [id, line[1]])
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


const COMIC_ARTS := ["face", "snap", "speed", "rain", "wipers", "lights", "road", "tone", "black", "white"]
const COMIC_KEYS := ["art", "who", "say", "cap", "fx", "side", "sfx"]


## Comic pages: 1–4 panels a page, known art, a face for every "face" panel, real sounds, and
## something to read or see in each.
func test_comic_pages_are_well_formed() -> void:
	var count := 0
	for b in StoryScript.BEATS:
		for key in ["comic", "comic_after"]:
			for page in b.get(key, []):
				_check(page is Array and page.size() >= 1 and page.size() <= 4, "%s.%s: a page of 1-4 panels" % [b["id"], key])
				for p in page:
					count += 1
					var where := "%s.%s" % [b["id"], key]
					_check(p.get("art", "") in COMIC_ARTS, "%s: known art %s" % [where, p.get("art")])
					for k in p:
						_check(k in COMIC_KEYS, "%s: known panel key %s" % [where, k])
					if p.get("art", "") == "face":
						_check(StoryPortrait.LOOKS.has(p.get("who", "")), "%s: %s has a face" % [where, p.get("who")])
					if p.has("sfx"):
						_check(StoryDialogue.SFX.has(p["sfx"]), "%s: sound %s exists" % [where, p["sfx"]])
					if p.has("side"):
						_check(p["side"] in ["left", "right"], "%s: side %s" % [where, p["side"]])
		if b.get("cold_open", false) or b["stage"] == "panel" or b.has("memory"):
			for page in b.get("comic", []):
				for p in page:
					_check(p.get("art", "") != "snap", "%s: no scene to freeze behind the page" % b["id"])
	_check(count > 0, "the story has comic pages")


func test_comic_layouts_fit_the_page() -> void:
	var page := Vector2(1152, 648)
	for n in range(1, 5):
		var rects := StoryComic.layout(n, page)
		_check(rects.size() == n, "%d panels laid out" % n)
		for r in rects:
			_check(Rect2(Vector2.ZERO, page).encloses(r) and r.size.x > 100 and r.size.y > 100, "%d-panel rect %s on the page" % [n, r])
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				_check(not rects[i].intersects(rects[j]), "%d-panel rects %d and %d apart" % [n, i, j])


func test_the_order_keeps_the_twist() -> void:
	var i := StoryScript.index_of
	_check(i.call("s06e") == -1, "the laptop scene is withheld")
	for id in ["s18", "s08", "s09", "s26"]:
		_check(i.call("s06") < i.call(id), "%s needs the passes from s06" % id)
	for id in ["s27", "s28", "s29"]:
		_check(i.call("s13") < i.call(id), "%s needs the crash log from s13" % id)
	_check(i.call("s14") < i.call("s01"), "the clinic comes before the first memory")
	_check(i.call("s20") < i.call("s21") and i.call("s21") < i.call("s30"), "Dante: suspicion, the files, proof")
	for b in StoryScript.BEATS:
		if b["id"] == "s06":
			for p in b["passes"]:
				_check(not ("8A" in p["label"]), "s06 labels do not mention the sign")


func test_memories_open_and_close() -> void:
	var open := ""
	var count := 0
	for b in StoryScript.BEATS:
		if b.has("memory"):
			_check(open == "", "%s: memory opens while %s is open" % [b["id"], open])
			_check(b.has("comic"), "%s: a memory opens on a comic page" % b["id"])
			open = b["id"]
			count += 1
		if b.has("now"):
			_check(open != "", "%s: now with no memory open" % b["id"])
			_check(StoryDialogue.SFX.has(b["now"]), "%s: now sound exists" % b["id"])
			open = ""
	_check(open == "", "the last memory closes")
	_check(count == 4, "four memories (got %d)" % count)


func test_memory_of_walks_the_script() -> void:
	_check(StoryScript.memory_of(StoryScript.index_of("s03")) == "MONTHS BEFORE", "s03 is in the first memory")
	_check(StoryScript.memory_of(StoryScript.index_of("s16")) == "", "s16 is the present")
	_check(StoryScript.memory_of(StoryScript.index_of("s13")) != "", "the night run is a memory")
	_check(StoryScript.memory_of(0) == "", "the prologue is not a memory")


func test_old_save_restarts_the_story() -> void:
	var path := "user://test_story_old.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({ "beat": 12, "record": { "passes": [1] }, "results": { "s03": 1 }, "reached": 20 }))
	f.close()
	var before := StoryMode.save_path
	StoryMode.save_path = path
	StoryMode.load_save()
	StoryMode.save_path = before
	_check(StoryMode.beat == 0 and StoryMode.record.is_empty() and StoryMode.results.is_empty() and StoryMode.reached == 0,
		"a save from another script order starts over")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_present_day_default_only_touches_talk_beats() -> void:
	var talk := { "id": "x", "type": "talk" }
	var drive := { "id": "y", "type": "sectors" }
	var dry_talk := { "id": "z", "type": "talk", "wet": 0.0 }
	_check(StoryDirector.conditions_for(talk, false)["rain"] > 0.0, "present-day talk gets rain")
	_check(StoryDirector.conditions_for(talk, true)["rain"] == 0.0, "a memory stays dry")
	_check(StoryDirector.conditions_for(drive, false)["rain"] == 0.0, "drive beats keep their own conditions")
	_check(StoryDirector.conditions_for(dry_talk, false)["wet"] == 0.0, "explicit conditions win")
	var drive_to := { "id": "g", "type": "goto" }
	_check(StoryDirector.conditions_for(drive_to, false)["rain"] == 0.0, "a drive-to is a drive: no default rain")
	_check(StoryDirector.conditions_for(talk, false, true)["rain"] == 0.0, "the ending (Act V) is past the rain")
	for id in ["s27", "s30"]:
		var beat: Dictionary = StoryScript.BEATS[StoryScript.index_of(id)]
		_check(StoryDirector.conditions_for(beat, false)["rain"] == 0.0, "%s is dry by its own data" % id)


func test_the_entry_pages_keep_the_twist() -> void:
	# Before the backup folder (s21) no caption or line may tie the clip to Pang's own car.
	var stop := StoryScript.index_of("s21")
	for i in stop:
		var b: Dictionary = StoryScript.BEATS[i]
		for page in b.get("comic", []):
			for panel in page:
				for key in ["cap", "say"]:
					var t: String = str(panel.get(key, "")).to_lower()
					_check(not ("knew that angle" in t) and not ("different name" in t), "%s: page gives the clip away: %s" % [b["id"], t])


func test_scar_only_in_the_present_after_the_prologue() -> void:
	_check(not StoryPortrait.scarred_at(StoryScript.index_of("s00")), "no scar in the cold open")
	_check(StoryPortrait.scarred_at(StoryScript.index_of("s14")), "scar at the clinic")
	_check(not StoryPortrait.scarred_at(StoryScript.index_of("s03")), "no scar inside a memory")
	_check(not StoryPortrait.has_face("JOLO", StoryScript.index_of("s22")), "Jolo has no face in the present")
	_check(StoryPortrait.has_face("JOLO", StoryScript.index_of("s03")), "Jolo has a face in a memory")
	_check(StoryPortrait.has_face("JOLO", StoryScript.index_of("s00")), "Jolo has a face in the cold open (he is alive)")


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
