class_name StoryShop
extends RefCounted
## Ruel's bench in story mode (docs/story/STORY_MODE.md "Money, parts and free roam"): story prices
## over CarParts' effects, the kind of each part (a part Ruel would choose, or one for Jolo's
## camera), Ruel's line for every one and Jolo's for some, and the rain set's catch: in the months
## before it can only be ordered, and it cannot arrive before the night run.

## In shop order. ruel: Ruel's line when you look at it; bought: his line once it's on the car;
## jolo: Jolo's (memory only).
const ITEMS := [
	{ "id": "front_tires", "price": 4800, "kind": "ruel", "ruel": "Fronts first.", "bought": "Good. Now the other two.",
		"jolo": "Tires don't show up on the clip, boss." },
	{ "id": "rear_tires", "price": 4800, "kind": "ruel", "ruel": "The back does the steering you don't notice.",
		"bought": "Now it'll stop arguing on the way in." },
	{ "id": "pads", "price": 3500, "kind": "ruel", "ruel": "Stopping is the fast part. Nobody believes me.",
		"bought": "Bed them in. Don't show off on the first night." },
	{ "id": "rotors", "price": 3000, "kind": "ruel", "ruel": "Your fluid is older than your cousin's phone.",
		"bought": "Pedal's honest now." },
	{ "id": "alignment", "price": 1500, "kind": "ruel", "ruel": "Free if you'd come in when I said.",
		"bought": "Straight. For now." },
	{ "id": "coilovers", "price": 22000, "kind": "ruel", "ruel": "Secondhand. I know where they've been.",
		"bought": "Now it'll tell you what the road's doing." },
	{ "id": "rain_set", "price": 16000, "kind": "ruel", "ruel": "One set. Manila. Two weeks.",
		"present": "Yours. Rain set. Came two weeks after.", "bought": "For the weather you don't get to choose." },
	{ "id": "intake", "price": 4500, "kind": "ego", "ruel": "It'll breathe. It won't stop better.",
		"bought": "Louder. Happy?", "jolo": "Sounds like a vacuum. A fast vacuum." },
	{ "id": "exhaust", "price": 5500, "kind": "ego", "ruel": "Your cousin's? I know that exhaust.",
		"bought": "It'll sound like it costs more.", "jolo": "Exhaust. It'll sound like it costs more." },
	{ "id": "header", "price": 9000, "kind": "ego", "ruel": "Nine thousand for a noise and a tenth.",
		"bought": "There's your tenth.", "jolo": "Ten seconds of that and you're famous." },
	{ "id": "remap", "price": 8000, "kind": "ego", "ruel": "The engine's not the part that's tired.",
		"bought": "Don't tell me when it pings.", "jolo": "Nico's got one." },
	{ "id": "wheels", "price": 15000, "kind": "ego", "ruel": "Pretty. Ask me about tires.",
		"bought": "Pretty.", "jolo": "On camera? Those are the car." },
]

## What a part is to the player right now.
enum Status { BUY, FITTED, ORDER, ON_ORDER, HIDDEN }


static func item(id: String) -> Dictionary:
	for it in ITEMS:
		if it["id"] == id:
			return it
	return {}


## The price at this point in the story: the alignment is free with the shakedown (s15b).
static func price(id: String, index := -1) -> int:
	var i := StoryMode.beat if index < 0 else index
	if id == "alignment" and StoryScript.BEATS[clampi(i, 0, StoryScript.BEATS.size() - 1)]["id"] == "s15b":
		return 0
	return int(item(id).get("price", 0))


## The rain set in the months before: not in the shop before the week of the night run (s11);
## from then it is an order, two weeks out; at s12 Ruel orders it. In the present it waits in
## the corner and goes on the bill.
static func status(id: String, index := -1) -> Status:
	var i := StoryMode.beat if index < 0 else index
	var tl := StoryMode.timeline(i)
	var build := StoryMode.car(i)
	if id == "rain_set":
		if tl == "memory":
			if i < StoryScript.index_of("s11"):
				return Status.HIDDEN
			return Status.ON_ORDER if StoryMode.flag("rain_ordered") else Status.ORDER
		return Status.FITTED if CarParts.has(build, id) else Status.BUY
	if CarParts.PARTS[id].has("axle"):
		return Status.BUY
	return Status.FITTED if CarParts.has(build, id) else Status.BUY


## Buy and fit. Pays from the wallet, except the present rain set, which goes on Ruel's bill
## ("fitted at cost"). Returns false when it can't be had (or can't be afforded).
static func buy(id: String, index := -1) -> bool:
	var i := StoryMode.beat if index < 0 else index
	if status(id, i) != Status.BUY:
		return false
	var cost := price(id, i)
	var on_bill := id == "rain_set" and StoryMode.timeline(i) == "present"
	if not on_bill and not StoryMode.spend(cost):
		return false
	if on_bill:
		StoryMode.bill(CarParts.PARTS[id]["name"], cost)
	CarParts.fit(StoryMode.car(i), id)
	StoryMode.set_flag("bought:" + id)
	return true


## Ruel's line for a part (the present rain set has its own).
static func ruel_line(id: String, index := -1) -> String:
	var it := item(id)
	if id == "rain_set" and StoryMode.timeline(index) == "present":
		return it["present"]
	return it["ruel"]


## From the first chase of the clip (s08) to the night run (s13), the memory shop prints each
## power part against GHOST TIME: the posted number minus a projected run on the car with the
## part. Elsewhere, and in the present, nothing (Ruel's notes only).
static func shows_ghost_delta(index := -1) -> bool:
	var i := StoryMode.beat if index < 0 else index
	return StoryMode.timeline(i) == "memory" and i >= StoryScript.index_of("s08") and i <= StoryScript.index_of("s13")


## Seconds a part is worth over a Pass 1 run, roughly (torque and mass only: what sells).
static func gain(id: String) -> float:
	var p: Dictionary = CarParts.PARTS.get(id, {})
	return (float(p.get("torque", 1.0)) - 1.0) * 11.0 - float(p.get("mass", 0.0)) * 0.012


## The projected run with the part, against the posted time: positive = still behind it.
static func ghost_delta(id: String, posted: float) -> float:
	var best := INF
	for key in ["s08", "s09", "s09a2"]:
		var r: Dictionary = StoryMode.results.get(key, {})
		if r.has("time") and float(r["time"]) > 0.0:
			best = minf(best, float(r["time"]))
	if best == INF:
		best = posted * 1.04
	return best - gain(id) - posted
