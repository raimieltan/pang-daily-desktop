class_name TimeAttackRun
extends RefCounted
## Rules of one time-attack run, engine-agnostic so they are unit tested headless.
## Countdown → running → finished. Progress only counts when it advances continuously along the
## road (no shortcuts across switchbacks, no credit for a reset that lands further ahead);
## checkpoints every `spacing` metres are passed in order, and the course splits into sectors.

enum Phase { COUNTDOWN, RUNNING, FINISHED }

## Largest forward jump in one update that still counts as driving (m). At 200 km/h and 120 Hz a
## car moves ~0.5 m per step, so anything near this is a cut across the hillside.
const MAX_JUMP := 25.0
const COUNTDOWN := 3.0

var phase := Phase.COUNTDOWN
var countdown := COUNTDOWN
var time := 0.0
var start_distance := 0.0
var finish_distance := 0.0
var checkpoints := PackedFloat64Array()
var next_checkpoint := 0
var sector_ends := PackedFloat64Array()
var splits := PackedFloat64Array()
## Furthest distance reached legitimately.
var progress := 0.0


func _init(start_distance_: float, finish_distance_: float, spacing := 100.0, sectors := 4) -> void:
	start_distance = start_distance_
	finish_distance = finish_distance_
	progress = start_distance
	var d := start_distance + spacing
	while d < finish_distance:
		checkpoints.append(d)
		d += spacing
	for k in range(1, sectors):
		sector_ends.append(lerpf(start_distance, finish_distance, float(k) / sectors))
	sector_ends.append(finish_distance)


## Advances the run by `dt` with the car at `distance` along the road. Returns event names:
## "go", "checkpoint", "sector", "finish".
func update(dt: float, distance: float) -> PackedStringArray:
	var events := PackedStringArray()
	match phase:
		Phase.COUNTDOWN:
			countdown -= dt
			if countdown <= 0.0:
				phase = Phase.RUNNING
				events.append("go")
		Phase.RUNNING:
			time += dt
			if distance > progress and distance - progress < MAX_JUMP:
				progress = distance
			while next_checkpoint < checkpoints.size() and progress >= checkpoints[next_checkpoint]:
				next_checkpoint += 1
				events.append("checkpoint")
			while splits.size() < sector_ends.size() and progress >= sector_ends[splits.size()]:
				splits.append(time)
				events.append("sector")
			if progress >= finish_distance:
				phase = Phase.FINISHED
				events.append("finish")
	return events


## Where a reset puts the car: the last checkpoint passed, or the start.
func respawn_distance() -> float:
	return checkpoints[next_checkpoint - 1] if next_checkpoint > 0 else start_distance


## The car was put back on the road at `distance`: progress resumes from there.
func respawned(distance: float) -> void:
	progress = distance


static func format_time(seconds: float) -> String:
	if seconds < 0.0 or is_inf(seconds):
		return "--:--.---"
	var ms := int(round(seconds * 1000.0))
	return "%d:%02d.%03d" % [ms / 60000, (ms / 1000) % 60, ms % 1000]
