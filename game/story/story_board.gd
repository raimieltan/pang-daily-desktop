class_name StoryBoard
extends RefCounted
## Kapitan's board and the regulars at Bahandi Fuels during a free-roam beat (docs/story/STORY_MODE.md
## "Free roam"): which events are open, what they cost and pay. In the months before each event
## runs once per roam ("the past has a fixed number of nights"); in the present they repeat.

## The regulars who race for money at the gas station: field entry, where they park on the
## forecourt (hub x, z, heading), the purse for a win (memory, present), and their lines.
const REGULARS := [
	{ "who": ["KAPITAN", "silak_box", "1f4dbf", 0.84], "park": Vector3(52, 36, 270), "purse": [2000, 1500],
		"hello": "My station, my rules. One lap. No phones on the line.",
		"won": "Huh. Again next week.", "lost": "Inside line's mine. Always was." },
	{ "who": ["BUKO", "dalagan_gsr", "1a6b3d", 0.84], "park": Vector3(52, 30, 270), "purse": [2000, 1500],
		"hello": "Camera's rolling. Try not to be boring.",
		"won": "Okay that one's going up.", "lost": "Deleting it. Out of respect." },
	{ "who": ["TISOY", "eg_hatch", "17171a", 0.85], "park": Vector3(52, 18, 270), "purse": [3000, 2500],
		"hello": "Same car as yours. Better everything else.",
		"won": "My tires are new.", "lost": "Told you. Everything else.", "reply_won": "Mine aren't." },
	{ "who": ["ATE LIZA", "civic_fd", "d9191f", 0.88], "park": Vector3(52, 12, 270), "purse": [3000, 2500],
		"hello": "One lap.",
		"won": "You finished slowing that time.", "lost": "You turn in before you've finished slowing. Works till it doesn't." },
]
const SPRINT_ENTRY := 500
## Kapitan's board stands by the shop door (hub x, z).
const BOARD_AT := Vector2(25, 34.5)
## Mountain events (present only): a clock on Pass 1 with three pay bands as fractions over the
## line study's floor (the baked cut), and a three-car downhill.
const CLOCK := { "entry": 1000, "bands": [[1.03, 8000], [1.07, 5000], [1.12, 2500]] }
const DOWNHILL := { "entry": 1000, "purse": [6000, 3000] }


## The once-key for a memory event in this roam.
static func once_key(beat_id: String, event_id: String) -> String:
	return beat_id + ":" + event_id


## Whether a regular will race Pang in the present (after S31 some won't; S33A's split).
static func refuses(name: String, index := -1) -> bool:
	var i := StoryMode.beat if index < 0 else index
	if StoryMode.timeline(i) != "present" or i <= StoryScript.index_of("s31"):
		return false
	return name == "TISOY" and not StoryMode.flag("won:TISOY")


## Every event a roam beat has open: { id, kind ("sprint" | "clock" | "downhill"), title, entry,
## purse, field, regular (REGULARS index), done (memory, already run) }.
static func events(b: Dictionary, index := -1) -> Array:
	var i := StoryMode.beat if index < 0 else index
	var present := StoryMode.timeline(i) == "present"
	var out := []
	var kinds: Array = b.get("events", [])
	if "sprints" in kinds:
		for k in REGULARS.size():
			var r: Dictionary = REGULARS[k]
			var who: Array = r["who"]
			if refuses(who[0], i):
				continue
			var id: String = "sprint_" + who[0].replace(" ", "_").to_lower()
			out.append({ "id": id, "kind": "sprint", "title": "SPRINT  ·  " + who[0], "entry": SPRINT_ENTRY,
				"purse": [int(r["purse"][1 if present else 0])], "field": [scaled(who, i)], "regular": k,
				"done": not present and StoryMode.once.has(once_key(b["id"], id)) })
	if "mountain" in kinds and present:
		out.append({ "id": "clock", "kind": "clock", "title": "MOUNTAIN CLOCK  ·  PASS 1", "entry": CLOCK["entry"],
			"bands": clock_bands(), "done": false })
		out.append({ "id": "downhill", "kind": "downhill", "title": "DOWNHILL  ·  3 CARS  ·  PASS 1",
			"entry": DOWNHILL["entry"], "purse": DOWNHILL["purse"],
			"field": [scaled(REGULARS[3]["who"], i), scaled(REGULARS[0]["who"], i)], "done": false })
	return out


## A field entry with its skill nudged up by Pang's build rating, so a built car still gets a race.
static func scaled(who: Array, index := -1) -> Array:
	var br := CarParts.rating(StoryMode.car(index))
	return [who[0], who[1], who[2], minf(0.96, float(who[3]) + 0.006 * br)]


## [[time, pesos], ...] fastest first: the clock's pay bands over the baked cut.
static func clock_bands() -> Array:
	var floor := StoryMode.baked_passes()
	var base := 75.0
	if floor.size() >= 1:
		var sources: Array = []
		for p in floor:
			sources.append({ "label": p["label"], "frames": StoryMode.unpack(p["frames"]),
				"splits": PackedFloat64Array(p["splits"]), "time": float(p["time"]) })
		var g := GhostLine.composite(sources)
		if g.valid():
			base = g.time
	var out := []
	for band in CLOCK["bands"]:
		out.append([base * float(band[0]), int(band[1])])
	return out


## What a finish pays: the purse by place, ₱1,000 below the places listed, nothing for a sprint
## lost (a sprint is one-on-one money).
static func payout(purse: Array, place: int, kind := "") -> int:
	if place >= 1 and place <= purse.size():
		return int(purse[place - 1])
	return 0 if kind == "sprint" else 1000


## The clock pays the best band the time beats.
static func clock_pay(time: float, bands: Array) -> int:
	for band in bands:
		if time <= float(band[0]):
			return int(band[1])
	return 0
