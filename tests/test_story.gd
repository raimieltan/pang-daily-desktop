extends RefCounted
## Story mode: the script is well formed, and the Ghost Line composite is cut the way the story
## needs (best sectors, three passes in the cut, seams where the source changes, the logger clock
## resetting there, and a target that is the sum of the chosen sectors).

var errors: Array[String] = []

const TYPES := ["chapter", "talk", "goto", "race", "practice", "attack", "sectors", "crash", "daylight", "evidence", "end",
	"roam", "test", "trial", "final"]
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
		if b["type"] in ["race", "practice", "attack", "sectors", "crash", "daylight", "trial", "final"]:
			_check(b["stage"] == "pass" or (b["type"] == "race" and b.get("course", "") == "loop" and b["stage"] == "hub"),
				"%s: drives on a stage with a road" % id)
		if b["type"] == "test":
			_check((b.get("kind") == "shakedown" and b["stage"] == "hub") or (b.get("kind") == "lights" and b["stage"] == "pass"),
				"%s: a shakedown in the barangay or the lights test on the pass" % id)
		if b["type"] == "roam":
			_check(b["stage"] == "hub" and HubLayout.PLACES.has(b.get("next", "")), "%s: roam to a hub place" % id)
			for e in b.get("events", []):
				_check(e in ["sprints", "mountain"], "%s: known roam event %s" % [id, e])
		if b["type"] == "goto":
			_check(b["stage"] == "hub" and HubLayout.PLACES.has(b["place"]), "%s: goto a hub place" % id)
		if b["stage"] == "room":
			_check(StoryRoom.SETS.has(b.get("set", "")), "%s: room set %s exists" % [id, b.get("set")])
		if b.has("spot"):
			_check(b["stage"] == "hub" and HubLayout.PLACES.has(b["spot"]), "%s: spot is a hub place" % id)
		for key in ["lines", "before", "after", "win", "lose", "beaten", "ahead", "heat_lines", "between", "after_lap", "lifted", "chased"]:
			for line in b.get(key, []):
				var wait: bool = line is Array and line.size() == 2 and line[0] == "~wait" and (line[1] is float or line[1] is int)
				var cond: bool = line is Array and line.size() == 3 and line[2] is String
				_check(wait or (line is Array and (line.size() == 2 or cond) and line[0] is String and line[1] is String), "%s.%s: [speaker, text(, condition)]" % [id, key])
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
		var entries: Array = b.get("field", []) + (b.get("heat", []) if b["type"] == "race" else [])
		for cond in b.get("field_if", {}):
			entries.append_array(b["field_if"][cond])
		for e in entries:
			_check(e is Array and e.size() == 4 and CarRoster.get_car(e[1])["id"] == e[1], "%s: field entry %s" % [id, e])
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
	_check(StoryMode.stale, "...and says so (the menu shows a notice)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	StoryMode.save_path = path
	StoryMode.load_save()
	StoryMode.save_path = before
	_check(not StoryMode.stale, "no save, nothing stale")


func test_present_day_default_only_touches_talk_beats() -> void:
	var talk := { "id": "x", "type": "talk" }
	var drive := { "id": "y", "type": "sectors" }
	var dry_talk := { "id": "z", "type": "talk", "wet": 0.0 }
	_check(StoryDirector.conditions_for(talk, false)["rain"] > 0.0, "present-day talk gets rain")
	_check(StoryDirector.conditions_for(talk, true)["rain"] == 0.0, "a memory stays dry")
	_check(StoryDirector.conditions_for(drive, false)["rain"] == 0.0, "drive beats keep their own conditions")
	_check(StoryDirector.conditions_for(dry_talk, false)["wet"] == 0.0, "explicit conditions win")
	var night_talk := { "id": "n", "type": "talk", "night": true }
	var c := StoryDirector.conditions_for(night_talk, false)
	_check(c["rain"] > 0.0 and c["night"] == 1.0, "a present-day scene at night still rains (night only sets the light)")
	var drive_to := { "id": "g", "type": "goto" }
	_check(StoryDirector.conditions_for(drive_to, false)["rain"] == 0.0, "a drive-to is a drive: no default rain")
	_check(StoryDirector.conditions_for(talk, false, true)["rain"] == 0.0, "the ending (Act V) is past the rain")
	for id in ["s27", "s30"]:
		var beat: Dictionary = StoryScript.BEATS[StoryScript.index_of(id)]
		_check(StoryDirector.conditions_for(beat, false)["rain"] == 0.0, "%s is dry by its own data" % id)


## No hard jumps: a beat that starts somewhere new (after an act card, on another stage, or at
## another place in the barangay) opens on comic pages, unless the beat before it left on pages,
## or the beat is a memory's entry or the NOW cut back (which bridge themselves). Act cards, gotos,
## the end and paper-panel beats are pages of their own.
func test_scene_changes_are_bridged_by_pages() -> void:
	var prev := {}
	for b in StoryScript.BEATS:
		var skip: bool = b["type"] in ["chapter", "end", "goto"] or b["stage"] == "panel" or b.has("memory") or b.has("now")
		if not skip and not prev.is_empty():
			var spot_prev: String = str(prev.get("spot", prev.get("place", ""))) if prev["type"] != "chapter" else ""
			var spot: String = str(b.get("spot", ""))
			var changes: bool = prev["type"] == "chapter" or prev["stage"] != b["stage"] \
				or (spot != "" and spot_prev != "" and spot != spot_prev)
			var bridged: bool = b.has("comic") or prev.has("comic_after")
			_check(not changes or bridged, "%s starts somewhere new without pages (after %s)" % [b["id"], prev["id"]])
		prev = b


## Transitions: every bridge names a sound there is, tails and heads stay short (the crash
## runs its own), and a looped sound really loops.
func test_transitions_are_well_formed() -> void:
	var sounds := StoryBridge.sounds()
	var keys := ["sound", "db", "loop", "lead", "carry", "until", "cut", "tail", "head", "fade"]
	var count := 0
	for b in StoryScript.BEATS:
		for side in ["enter", "exit"]:
			if not b.has(side):
				continue
			count += 1
			var t: Dictionary = b[side]
			var where := "%s.%s" % [b["id"], side]
			for k in t.keys():
				_check(k in keys, "%s: known key %s" % [where, k])
			if t.has("sound"):
				_check(t["sound"] in sounds, "%s: sound %s exists" % [where, t["sound"]])
			for k in ["tail", "head"]:
				if t.has(k):
					_check(float(t[k]) >= 1.0 and float(t[k]) <= 3.0, "%s: %s is 1-3 s" % [where, k])
			if t.has("lead"):
				_check(float(t["lead"]) <= 2.0, "%s: lead is at most 2 s" % where)
			if t.has("until"):
				_check(t["until"] == "reveal" and side == "enter", "%s: until reveal, on an enter" % where)
	_check(count >= 15, "the transitions are authored (got %d)" % count)
	var rain := StoryBridge.stream_for("rain", true) as AudioStreamWAV
	_check(rain != null and rain.loop_mode == AudioStreamWAV.LOOP_FORWARD, "a looped bridge loops")


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


## The line study's floor: a recorded pass slower than the baked pass in its slot takes the baked
## driving (under its own label), a quicker one is kept, and a slot with nothing baked keeps what
## was driven. Driving the study badly cannot make the Ghost Line beatable.
func test_baked_passes_floor_the_line_study() -> void:
	var fast := _pass("BAKED", [30.0, 30.0, 30.0, 30.0], 0.0)
	var baked := { "label": "BAKED", "frames": StoryMode.pack(fast["frames"]), "splits": Array(fast["splits"]), "time": fast["time"] }
	var baked_before := StoryMode.baked
	var record_before := StoryMode.record
	StoryMode.baked = [baked, baked]
	StoryMode.record = {}
	var slow := _pass("A", [20.0, 20.0, 20.0, 20.0], 1.0)
	var quick := _pass("B", [32.0, 32.0, 32.0, 32.0], 1.0)
	StoryMode.add_pass("PASS A", slow["frames"], slow["splits"], slow["time"])
	StoryMode.add_pass("PASS B", quick["frames"], quick["splits"], quick["time"])
	StoryMode.add_pass("PASS C", slow["frames"], slow["splits"], slow["time"])
	var passes: Array = StoryMode.record["passes"]
	_check(passes.size() == 3, "three passes recorded")
	_check(absf(float(passes[0]["time"]) - fast["time"]) < 1e-6 and passes[0]["label"] == "PASS A",
		"a slow pass takes the baked time under its own label")
	_check(StoryMode.unpack(passes[0]["frames"]) == fast["frames"], "...and the baked frames")
	_check(absf(float(passes[1]["time"]) - quick["time"]) < 1e-6, "a pass quicker than the floor is kept")
	_check(absf(float(passes[2]["time"]) - slow["time"]) < 1e-6, "a slot with nothing baked keeps what was driven")
	StoryMode.use_floor = false
	StoryMode.record = {}
	StoryMode.add_pass("PASS A", slow["frames"], slow["splits"], slow["time"])
	_check(absf(float(StoryMode.record["passes"][0]["time"]) - slow["time"]) < 1e-6, "with the floor off (baking) a slow pass is kept")
	StoryMode.use_floor = true
	StoryMode.baked = baked_before
	StoryMode.record = record_before


## The floor ships: three baked passes, each a whole run of Pass 1 (4 splits, frames to match), quick
## enough that the cut over them is a target and not a lap.
func test_the_baked_floor_is_shipped() -> void:
	var baked_before := StoryMode.baked
	StoryMode.baked = []
	StoryMode._baked_loaded = false
	var floor := StoryMode.baked_passes()
	_check(floor.size() == 3, "three baked passes (got %d)" % floor.size())
	var sources: Array = []
	for p in floor:
		var frames := StoryMode.unpack(p["frames"])
		var splits := PackedFloat64Array(p["splits"])
		_check(splits.size() == 4 and float(p["time"]) > 60.0 and float(p["time"]) < 95.0,
			"a whole pass with 4 splits in 60..95 s (got %.1f)" % float(p["time"]))
		_check(absf(frames.size() / GhostLine.STRIDE - float(p["time"]) * GhostLine.HZ) < GhostLine.HZ,
			"frames cover the pass at %d Hz" % int(GhostLine.HZ))
		sources.append({ "label": p["label"], "frames": frames, "splits": splits, "time": float(p["time"]) })
	if floor.size() == 3:
		var g := GhostLine.composite(sources)
		_check(g.valid() and g.time < 90.0, "the cut over the floor is under 1:30 (got %.1f)" % g.time)
	StoryMode.baked = baked_before
	StoryMode._baked_loaded = false


## Dante's number: the posted GHOST TIME is the cut's time with something taken off, and beating
## it in public moves it under the run that beat it ("Ghost responded").
func test_posted_ghost_time_is_shorter_than_the_cut() -> void:
	var record_before := StoryMode.record
	StoryMode.record = {}
	var posted := StoryMode.posted_time(90.0)
	_check(posted < 90.0 * 0.99 and posted > 90.0 * 0.9, "posted is a little under the cut (got %.2f)" % posted)
	StoryMode.repost(85.0)
	_check(StoryMode.posted_time(90.0) < 85.0, "after a public beating the posted time drops under the run that beat it")
	_check(StoryMode.record.has("posted"), "and the record remembers it")
	StoryMode.record = record_before


## What a drive chases: the cut itself, or (`posted`) Dante's shorter number with the splits scaled
## to it. And the lines that follow: "beaten" under the target; "ahead" of the car in the clip but
## not of the posted clock; else "after".
func test_posted_target_and_the_lines_that_follow() -> void:
	var record_before := StoryMode.record
	StoryMode.record = {}
	var g := GhostLine.composite([_pass("A", [30.0, 20.0, 20.0, 20.0], -1.0),
		_pass("B", [20.0, 30.0, 25.0, 20.0], 0.0), _pass("C", [20.0, 20.0, 20.0, 30.0], 1.0)])
	var cut := StoryDirector.target_for(g, false)
	_check(absf(float(cut["time"]) - g.time) < 1e-6 and cut["splits"] == g.splits, "the cut is its own target")
	var posted := StoryDirector.target_for(g, true)
	_check(absf(float(posted["time"]) - StoryMode.posted_time(g.time)) < 1e-6, "the posted target is Dante's number")
	var sp: PackedFloat64Array = posted["splits"]
	_check(sp.size() == 4 and absf(sp[3] - float(posted["time"])) < 1e-6
		and absf(sp[0] / g.splits[0] - sp[3] / g.splits[3]) < 1e-6, "its splits scale to it")
	var b := { "beaten": [], "ahead": [], "after": [] }
	_check(StoryDirector.after_key(b, float(posted["time"]) - 0.1, posted, g.time) == "beaten", "under the posted clock: beaten")
	_check(StoryDirector.after_key(b, g.time - 0.1, posted, g.time) == "ahead", "ahead of the car in the clip, behind the clock: ahead")
	_check(StoryDirector.after_key(b, g.time + 0.1, posted, g.time) == "after", "behind both: after")
	_check(StoryDirector.after_key({ "beaten": [] }, g.time - 0.1, posted, g.time) == "after", "no ahead lines: after")
	_check(StoryDirector.after_key(b, g.time - 0.1, cut, g.time) == "beaten", "against the cut itself, under it is beaten")
	StoryMode.record = record_before


## The event and the night run chase Dante's posted number; the private chase and Nico's trials
## chase the cut. The event answers all three outcomes.
func test_public_drives_chase_the_posted_number() -> void:
	for id in ["s09", "s13"]:
		_check(StoryScript.BEATS[StoryScript.index_of(id)].get("posted", false), "%s chases the posted number" % id)
	for id in ["s08", "s26"]:
		_check(not StoryScript.BEATS[StoryScript.index_of(id)].get("posted", false), "%s chases the cut" % id)
	var s09: Dictionary = StoryScript.BEATS[StoryScript.index_of("s09")]
	_check(s09.has("beaten") and s09.has("ahead") and s09.has("after"), "the event has beaten, ahead and after lines")


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


# --- Money, parts and free roam (docs/story/STORY_MODE.md) --------------------------------------


func test_every_progression_card_has_a_beat() -> void:
	var scenes := {}
	for b in StoryScript.BEATS:
		scenes[b["scene"]] = true
	for card in ["S04A", "S04B", "S05A", "S09A", "S11A", "S15A", "S20A", "S23A", "S27A", "S33A", "S33B", "S34A"]:
		_check(scenes.has(card), "%s is in the script" % card)
	_check(StoryScript.BEATS.size() == 65, "65 beats (got %d)" % StoryScript.BEATS.size())


func test_progression_order() -> void:
	var i := StoryScript.index_of
	_check(i.call("s34") < i.call("s34a"), "the recce before the final")
	for b in StoryScript.BEATS:
		var at := StoryScript.index_of(b["id"])
		if StoryMode.timeline(at) == "memory" and (b["type"] == "roam" or b.get("garage", false)):
			_check(at < i.call("s12"), "%s: every memory purchase stop comes before s12" % b["id"])
	_check(StoryMode.timeline(i.call("s05a")) == "memory" and StoryMode.timeline(i.call("s15a")) == "present", "timelines follow the memories")
	_check(StoryMode.timeline(i.call("s00")) == "memory", "the cold open drives the memory car")
	for id in ["s26", "s27a"]:
		_check(StoryScript.BEATS[i.call(id)].get("snapshot", "") == "s06", "%s runs on the line-study snapshot" % id)


func _with_fresh_progress(f: Callable) -> void:
	var saved := [StoryMode.beat, StoryMode.cars, StoryMode.wallets, StoryMode.ledgers, StoryMode.commitments, StoryMode.rep, StoryMode.once, StoryMode.snapshot, StoryMode.results]
	StoryMode.reset_progress()
	StoryMode.results = {}
	f.call()
	StoryMode.beat = saved[0]
	StoryMode.cars = saved[1]
	StoryMode.wallets = saved[2]
	StoryMode.ledgers = saved[3]
	StoryMode.commitments = saved[4]
	StoryMode.rep = saved[5]
	StoryMode.once = saved[6]
	StoryMode.snapshot = saved[7]
	StoryMode.results = saved[8]


## The critical path is affordable with no optional races at last place: every required entry in
## the months before is covered by the required purses at the worst finish.
func test_critical_path_is_affordable() -> void:
	var earned := int(StoryMode.START_WALLET["memory"])
	var due := 0
	for i in StoryScript.BEATS.size():
		var b: Dictionary = StoryScript.BEATS[i]
		if StoryMode.timeline(i) != "memory":
			continue
		due += int(b.get("entry", 0)) + int(b.get("off_list", 0))
		if b.has("purse"):
			var places: int = 1 + b.get("field", []).size()
			var last: int = places if b["type"] == "race" else 99
			# R1 must be won (require_win).
			earned += StoryBoard.payout(b["purse"], 1 if b.get("require_win", false) else last, b.get("kind", ""))
	_check(earned >= due, "memory: purses at last place (%d) cover the required entries (%d)" % [earned, due])


func test_required_entries_never_block() -> void:
	_with_fresh_progress(func():
		StoryMode.beat = StoryScript.index_of("s05a")
		StoryMode.wallets["memory"] = 100
		_check(StoryMode.pay_entry(1500, true, "THE MOUNTAIN"), "a required entry goes through when broke")
		_check(StoryMode.wallet() == 100 and StoryMode.commitments_total() == 1500, "...and Jolo covers it")
		_check(not StoryMode.pay_entry(500, false), "an optional entry needs the cash")
		StoryMode.beat = StoryScript.index_of("s16")
		_check(StoryMode.pay_entry(500, true) and StoryMode.owed("present") == 38500, "in the present it goes on Ruel's bill"))


## The rain set can't be fitted in the months before, for any purchase sequence; in the present it
## goes on the bill.
func test_rain_set_never_arrives_in_time() -> void:
	_with_fresh_progress(func():
		StoryMode.wallets["memory"] = 1000000
		for i in StoryScript.index_of("s13") + 1:
			StoryMode.beat = i
			if StoryMode.timeline(i) != "memory":
				continue
			for it in StoryShop.ITEMS:
				StoryShop.buy(it["id"], i)
			_check(not CarParts.has(StoryMode.cars["memory"], "rain_set"), "no rain set on the memory car at %s" % StoryScript.BEATS[i]["id"])
		StoryMode.beat = StoryScript.index_of("s15b")
		_check(StoryShop.status("rain_set") == StoryShop.Status.BUY, "the present rain set is in the corner")
		_check(StoryShop.buy("rain_set") and StoryMode.owed() == 38000 + 16000, "fitted at cost, on the bill"))


## Fronts fitted at s04a are under 0.3 by s12 on the critical path: the night run is on worn fronts.
func test_fronts_from_s04a_are_worn_by_s12() -> void:
	var km := 0.0
	for i in range(StoryScript.index_of("s04a"), StoryScript.index_of("s12")):
		var b: Dictionary = StoryScript.BEATS[i]
		if StoryMode.timeline(i) != "memory":
			continue
		match b["type"]:
			"race":
				var laps := float(b.get("laps", 1))
				var runs := 2.0 if b.has("heat") else 1.0
				km += runs * laps * (StoryMode.LOOP_KM if b.get("course", "") == "loop" else StoryMode.PASS_KM)
			"practice":
				km += b["passes"].size() * StoryMode.PASS_KM
			"attack":
				km += StoryMode.PASS_KM
			"sectors":
				km += b["trials"].size() * StoryMode.PASS_KM * 0.35 + (StoryMode.PASS_KM if b.get("connect", false) else 0.0)
	var build := CarParts.new_build()
	CarParts.charge(build, km)
	_check(CarParts.wear(build, "front") < 0.3, "fronts at %.2f after %.1f km (want < 0.3)" % [CarParts.wear(build, "front"), km])


func test_parts_change_the_car() -> void:
	var physical := HandlingPresets.physical_config(HandlingPresets.resolve("fwd_sport_hatch"))
	var build := CarParts.new_build()
	var stock := CarParts.apply(physical, build)
	_check(is_equal_approx(float(stock["tires"]["frontGrip"]), float(physical["tires"]["frontGrip"])), "new tires: stock grip")
	CarParts.fit(build, "header")
	CarParts.fit(build, "wheels")
	var built := CarParts.apply(physical, build)
	_check(float(built["mechanical"]["engine"]["torqueNm"]) > float(physical["mechanical"]["engine"]["torqueNm"]), "the header adds torque")
	_check(float(built["chassis"]["massKg"]) < float(physical["chassis"]["massKg"]), "light wheels take mass off")
	CarParts.charge(build, 100.0)
	var worn := CarParts.apply(physical, build)
	_check(absf(float(worn["tires"]["frontGrip"]) / float(built["tires"]["frontGrip"]) - CarParts.WORN_GRIP) < 1e-4, "dead fronts keep 0.95 of the grip")
	CarParts.fit(build, "front_tires")
	_check(CarParts.wear(build, "front") == 1.0 and CarParts.wear(build, "rear") < 1.0, "new fronts reset the fronts only")
	_check(CarParts.rating(build) == 4, "BR adds up (got %d)" % CarParts.rating(build))


func test_memory_events_run_once_per_roam() -> void:
	_with_fresh_progress(func():
		var i := StoryScript.index_of("s04b")
		StoryMode.beat = i
		var b: Dictionary = StoryScript.BEATS[i]
		var events := StoryBoard.events(b)
		_check(events.size() == 4, "four regulars race at the gas station (got %d)" % events.size())
		StoryMode.once[StoryBoard.once_key("s04b", events[0]["id"])] = true
		_check(StoryBoard.events(b)[0]["done"], "a sprint run in the past stays run")
		var j := StoryScript.index_of("s17")
		StoryMode.beat = j
		var present := StoryBoard.events(StoryScript.BEATS[j])
		_check(present.size() == 6, "present roams add the mountain events (got %d)" % present.size())
		StoryMode.beat = StoryScript.index_of("s33r")
		_check(StoryBoard.events(StoryScript.BEATS[StoryMode.beat]).filter(func(e): return e["id"] == "sprint_tisoy").is_empty(),
			"after S31 Tisoy won't race unless Pang beat him for the clip")
		StoryMode.set_flag("won:TISOY")
		_check(not StoryBoard.events(StoryScript.BEATS[StoryMode.beat]).filter(func(e): return e["id"] == "sprint_tisoy").is_empty(),
			"...and will if he did"))


func test_conditional_lines() -> void:
	_with_fresh_progress(func():
		StoryMode.beat = StoryScript.index_of("s12")
		StoryMode.wallets["memory"] = 20000
		var lines := StoryDirector.spoken([["A", "always"], ["B", "rich", "cash:16000"], ["C", "broke", "!cash:16000"]])
		_check(lines.size() == 2 and lines[1][1] == "rich", "conditions pick the line (got %s)" % [lines]))


func test_payouts() -> void:
	_check(StoryBoard.payout([5000, 3000, 1500], 2) == 3000, "second pays the second purse")
	_check(StoryBoard.payout([5000, 3000, 1500], 4) == 1000, "below the places listed: ₱1,000")
	_check(StoryBoard.payout([2000], 2, "sprint") == 0, "a lost sprint pays nothing")
	_check(StoryBoard.clock_pay(70.0, [[71.0, 8000], [74.0, 5000]]) == 8000 and StoryBoard.clock_pay(73.0, [[71.0, 8000], [74.0, 5000]]) == 5000,
		"the clock pays the best band beaten")
