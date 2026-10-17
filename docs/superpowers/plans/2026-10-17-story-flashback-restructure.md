# Story Flashback Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tell "The Ghost Line" from after the crash, with the months before as marked flashbacks, the edit withheld until Act III, Dante confronted twice, and the speedometer back in story races.

**Architecture:** The story is data (`StoryScript.BEATS`, played in order by `StoryDirector`), so the restructure is mostly a reordered, rewritten beat list plus two new beat keys: `memory` (first beat of a flashback, its period label) and `now` (first beat back, the present-day sound). `StoryScript.memory_of(index)` derives "inside a memory" by walking the list, and one flag feeds the portrait (scar, Jolo's face), the tint, the stamp and the present-day weather default. The warm flashback look is a single multiply-blend overlay on a top CanvasLayer owned by the director, so the 3D page and every UI panel warm together without touching the compositor or the 71 `MangaType.PAPER` uses.

**Tech Stack:** Godot 4.7, GDScript; headless test runner `tests/run_tests.gd`; `tests/probe_story.gd` (whole story headless); `tools/story_shot.gd` (screenshots, needs a window).

**Spec:** `docs/superpowers/specs/2026-10-17-story-flashback-restructure-design.md`

## Global Constraints

- English dialogue only.
- Storyboard scenes S00–S35 all present in `BEATS`; six `chapter` beats (prologue + five acts); the last beat is `end` (`tests/test_story.gd` enforces all three).
- Godot binary: `/Users/sean/Downloads/Godot.app/Contents/MacOS/Godot`. macOS has no `timeout`: run headless commands in the background with a manual kill loop (a script error hangs headless Godot).
- A new `class_name` needs `Godot --headless --path . --import` once before other scripts see it.
- Commit with explicit pathspecs: `git add <paths>` then `git commit -- <paths>`; never a bare `git commit`.
- Memory beats with `comic` pages must not use `"art": "snap"` panels when the beat opens a new scene (there is no frame to freeze; the unit test for comic pages checks `cold_open`/`panel` beats, extend it to `memory` beats).

## Review Focus

1. A save from the old script order resumes at a beat index that now means a different scene → the player lands mid-memory with no stamp. Pinned in Task 2 (`test_old_save_restarts_the_story`).
2. The player quits during a memory and resumes: the tint, stamp and Jolo's face must come back from the beat index alone, not from director state. Pinned in Task 1 (`test_memory_of_walks_the_script`) and Task 3 (director reads `StoryScript.memory_of(StoryMode.beat)` at every beat).
3. A present-day talk beat with no conditions must get rain; a drive beat with none must not (Nico's trials are dry evidence). Pinned in Task 3 (`test_present_day_default_only_touches_talk_beats`).
4. The cold open (`s00`) is before Act I: Pang's portrait there must have no scar even though it is "not in a memory". Pinned in Task 3 (`test_scar_only_in_the_present_after_the_prologue`).
5. The speedometer must show in every story drive beat but stay hidden in the cold open and the daylight drive, which set the clean feed on purpose. Checked by screenshots in Task 4 (no unit test: HUD visibility needs a scene).

---

### Task 1: The script in the new order

**Files:**
- Modify: `game/story/story_script.gd` (the whole `BEATS` array; `acts()`, `index_of()` stay)
- Test: `tests/test_story.gd`

**Interfaces:**
- Produces: beat keys `"memory": String` (period label, e.g. `"MONTHS BEFORE"`) on the first beat of a flashback and `"now": String` (a `StoryDialogue.SFX` name, e.g. `"phone_buzz"`) on the first beat after it; `static func memory_of(index: int) -> String` returning the period label of the memory containing beat `index`, or `""`.

- [ ] **Step 1: Write the failing tests** in `tests/test_story.gd`

```gdscript
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
```

Also extend `test_comic_pages_are_well_formed`: the "no snap panels" check applies to beats with `memory` too.

- [ ] **Step 2: Run the suite to see them fail**

Run (background, kill after 120 s): `Godot --headless --path . -s res://tests/run_tests.gd`
Expected: the three new tests FAIL (`s06e` present, no `memory` keys, `memory_of` undefined).

- [ ] **Step 3: Rewrite `BEATS` in the spec's order**

Move the existing beat dictionaries into the order in the spec § The order, with act cards `a1_card` THE RETURN, `a2_card` THE GHOST, `a3_card` THE GHOST IS YOU, `a4_card` WHAT HAPPENED ON THE MOUNTAIN, `a5_card` THE ROAD IS NOT A RECORDING (subtitles: builder's, one line each). Delete `s06e`; drop `s04` (the drive to Kyo inside Memory 1 is not needed: `s04t` sits at the Kyo spot). Add the keys:

| beat | key |
| --- | --- |
| `s01` | `"memory": "MONTHS BEFORE"`, `comic`: 3 panels from the manuscript's "The Sound of a Wrench" (the wrench on concrete in the present, black; Ruel's hands; the stamp caption) |
| `s16` | `"now": "wrench"` |
| `s06` | `"memory": "THE LINE STUDY"`, `comic`: 2–3 panels (the clip playing on Buko's phone at Kyo, frozen `snap` is NOT allowed: use `tone`; Jolo's camera on the dash; stamp) |
| `s20` | `"now": "phone_buzz"` |
| `s07` | `"memory": "GHOST GOES PUBLIC"`, `comic`: 2–3 panels from "Ghost Goes Public" (Jolo's camera bag in the present, Dante's post) |
| `s21` | `"now": "phone_buzz"` |
| `s11` | `"memory": "THE WEEK OF THE NIGHT RUN"`, `comic`: 2–3 panels (the bent sign at 8A, rain, stamp) |
| `s27` | `"now": "wiper"` |

Text changes (spec § What is hidden, § Dante, § Calls made):
- `s06` pass labels: `"PASS A  ·  TUESDAY 3:40 PM  ·  DRY"`, `"PASS B  ·  THURSDAY 4:15 PM  ·  DAMP PATCHES AFTER A SHOWER"`, `"PASS C  ·  SATURDAY 5:30 PM  ·  DRY  ·  LOW SUN"`; keep the `sign` fields; its first comic caption "It began with a joke."
- `s05` after: cut `["JOLO", "I'll make a clip that shows what you can do."]`.
- `s08`: replace both `after` and `beaten` lines where Jolo explains the composite with Jolo starting to ("Pang, about the clip—") and Pang cutting him off ("I'm close."); keep Ruel's before line.
- `s07`: cut `["JOLO", "It's not one run."]` and Jolo's "They're putting a time on it"; keep Dante's lines.
- `s20`: new lines per spec § Dante (suspicion; Dante does not know who Ghost is: "It came to me the way everything does. Somebody sends it, I post it."; ends on Ruel's backup line, moved from the old `s20`).
- `s30`: remove the opening exchange up to and including `["DANTE", "Because the event needed a target."]`; open on `["PANG", "A target no one could complete."]`.
- `s25` cards: add `{ "kind": "text", "title": "THE SIGN AT 8A", "body": "intact in /raw_tuesday\nbent in /raw_thursday\n\nOne road. Two different weeks." }`.

Add `static func memory_of(index: int) -> String` (walk `BEATS[0..index]`, track the open label, `now` closes it).

- [ ] **Step 4: Run the suite**

Expected: all tests PASS, including `test_every_storyboard_scene_has_a_beat` (S04 is still covered by `s04t`, S06 by `s06`).

- [ ] **Step 5: Commit**

```bash
git add game/story/story_script.gd tests/test_story.gd
git commit -m "feat(story): the story told from after the crash, the months before as memories" -- game/story/story_script.gd tests/test_story.gd
```

### Task 2: Saves know which script they belong to

**Files:**
- Modify: `game/story/story_mode.gd:12-62`
- Test: `tests/test_story.gd`

**Interfaces:**
- Produces: `const SCRIPT_VERSION := 2` in `StoryMode`; `save()` writes `"script": SCRIPT_VERSION`; `load_save()` treats a file whose `script` differs (or is missing) as no save: beat 0, empty record and results, `reached` 0, `completed` false.

- [ ] **Step 1: Write the failing test**

```gdscript
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
```

- [ ] **Step 2: Run it to see it fail** (beat is 12).

- [ ] **Step 3: Implement** `SCRIPT_VERSION`, write it in `save()`, check it in `load_save()`.

- [ ] **Step 4: Run the suite: PASS.**

- [ ] **Step 5: Commit** `-- game/story/story_mode.gd tests/test_story.gd`, message `fix(story): saves restart when the script order changes`.

### Task 3: Memories look like memories

**Files:**
- Create: `game/story/story_tint.gd` (`class_name StoryTint extends CanvasLayer`)
- Modify: `game/story/story_director.gd:112-170` (`_play`, `_reveal`), `:189-200` (`_conditions`)
- Modify: `game/story/story_dialogue.gd:239-243` (caption) and `_ready`
- Modify: `game/story/story_portrait.gd:38-45`
- Test: `tests/test_story.gd`

**Interfaces:**
- Consumes: `StoryScript.memory_of(index)` (Task 1).
- Produces:
  - `StoryTint`: `func set_warm(on: bool) -> void` (a full-rect `ColorRect` on `layer = 20`, `CanvasItemMaterial` with `blend_mode = BLEND_MODE_MUL`, color `Color(1.0, 0.94, 0.82)` when on, hidden when off; `mouse_filter = IGNORE`).
  - `StoryDialogue.set_stamp(period: String) -> void`: a red two-line stamp (same style as `_caption`) anchored top-right under the day/night chip (`PRESET_TOP_RIGHT`, `offset_top = 84`, `offset_right = -40`, `grow_horizontal = BEGIN`), text `period`, hidden when `""`. It is not cleared by `play()`.
  - `StoryPortrait.show_speaker(who)`: Pang's scar when `StoryScript.memory_of(StoryMode.beat) == "" and StoryMode.beat >= StoryScript.index_of("a1_card")`; JOLO shows no face when `memory_of(...) == ""`.
  - `StoryDirector`: `const PRESENT := { "rain": 0.4, "wet": 0.7, "night_value": 0.3 }` applied in `_conditions` when `memory_of == ""`, `b["type"] in ["talk", "evidence", "goto"]` and `b` has none of `rain`, `wet`, `night`, `night_value`.

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_present_day_default_only_touches_talk_beats() -> void:
	# StoryDirector.conditions_for(b, in_memory) -> Dictionary { night, rain, wet }
	var talk := { "id": "x", "type": "talk" }
	var drive := { "id": "y", "type": "sectors" }
	var dry_talk := { "id": "z", "type": "talk", "wet": 0.0 }
	_check(StoryDirector.conditions_for(talk, false)["rain"] > 0.0, "present-day talk gets rain")
	_check(StoryDirector.conditions_for(talk, true)["rain"] == 0.0, "a memory stays dry")
	_check(StoryDirector.conditions_for(drive, false)["rain"] == 0.0, "drive beats keep their own conditions")
	_check(StoryDirector.conditions_for(dry_talk, false)["wet"] == 0.0, "explicit conditions win")

func test_scar_only_in_the_present_after_the_prologue() -> void:
	_check(not StoryPortrait.scarred_at(StoryScript.index_of("s00")), "no scar in the cold open")
	_check(StoryPortrait.scarred_at(StoryScript.index_of("s14")), "scar at the clinic")
	_check(not StoryPortrait.scarred_at(StoryScript.index_of("s03")), "no scar inside a memory")
	_check(not StoryPortrait.has_face("JOLO", StoryScript.index_of("s22")), "Jolo has no face in the present")
	_check(StoryPortrait.has_face("JOLO", StoryScript.index_of("s03")), "Jolo has a face in a memory")
```

This fixes two static helpers: `static func conditions_for(b: Dictionary, in_memory: bool) -> Dictionary` on `StoryDirector` (pure; `_conditions` calls it) and `static func scarred_at(index: int) -> bool`, `static func has_face(who: String, index: int) -> bool` on `StoryPortrait` (`show_speaker` calls them with `StoryMode.beat`).

- [ ] **Step 2: Run to see them fail** (functions undefined).

- [ ] **Step 3: Implement** the helpers, `StoryTint`, `set_stamp`, and the director's memory flow in `_reveal(b)`:
  - compute `label := StoryScript.memory_of(StoryMode.beat)`; `tint.set_warm(label != "")`; `dialogue.set_stamp(label if label != "" else ("NOW" if b.has("now") else ""))`.
  - `b.has("memory")`: pages play with `out = "black"`, then `_settle`, then `fade(false, 0.5)`.
  - `b.has("now")`: `dialogue.black(true)`, `dialogue.sfx(b["now"])`, wait 0.5 s, `_settle`, `fade(false, 0.5)`.
  - the `NOW` stamp clears on the next beat (the per-beat computation above does that).
  Run `Godot --headless --path . --import` once for the new class.

- [ ] **Step 4: Run the suite: PASS.**

- [ ] **Step 5: Look at it.** With a window: `tools/story_shot.gd -- <out> s01 20 2` (memory entry page, warm tint, stamp), `-- s03 12 3` (a race inside a memory: stamp still up over the HUD), `-- s16 12 2` (NOW, rain, scar, no tint). Fix what is wrong before committing.

- [ ] **Step 6: Commit** `-- game/story/story_tint.gd game/story/story_tint.gd.uid game/story/story_director.gd game/story/story_dialogue.gd game/story/story_portrait.gd tests/test_story.gd`, message `feat(story): memories are warm, stamped and cut back to NOW`.

### Task 4: The speedometer in story races

**Files:**
- Modify: `game/story/story_director.gd:256-272` (`_hold`)

**Interfaces:**
- Consumes: `DriveSession.gauges: CanvasLayer`, `DriveSession.day_night`.

- [ ] **Step 1: Reproduce**: `tools/story_shot.gd -- <out> s16 14 2`: the race runs with no speedometer.

- [ ] **Step 2: Fix**: in `_hold(false)`, after `session.set_clean_feed(false)`, set `session.gauges.visible = true` and `session.day_night.visible = true`. The cold open and the daylight drive call `set_clean_feed(true)` themselves after `_hold(false)`, so they stay clean.

- [ ] **Step 3: Verify** the same shot shows the speedometer and minimap; `-- s00 20 2` still shows none during the fragments; `-- s34 14 3` none on the daylight drive.

- [ ] **Step 4: Commit** `-- game/story/story_director.gd`, message `fix(story): the speedometer shows in story races`.

### Task 5: The whole story, headless, and the docs

**Files:**
- Modify: `docs/story/STORY_MODE.md` (§ Structure, the Acts table, § Comic pages, § Not built / open)
- Modify: `docs/GAME_DESIGN.md` (the story-mode row: "told from after the crash with flashbacks")

- [ ] **Step 1: Run the whole story**: `Godot --headless --fixed-fps 120 --path . -s res://tests/probe_story.gd` in the background (about 25 min; kill at 40). Expected: `STORY COMPLETE` with `passes=3`, a valid ghost time, `crash_frames > 0`, results for `s03 s05 s08 s09 s16 s18 s26`, and 0 `SCRIPT ERROR` lines. If a beat hangs, the log's last `beat` line names it.

- [ ] **Step 2: Update the docs** to the new order and the memory keys (the spec's order block can be pasted into `STORY_MODE.md`; the Not-built list gains "Comic pages for the non-memory transitions in Acts II–V" and "Full-colour / watercolour memories (art pipeline)").

- [ ] **Step 3: Commit** `-- docs/story/STORY_MODE.md docs/GAME_DESIGN.md`, message `docs(story): the flashback order`.
