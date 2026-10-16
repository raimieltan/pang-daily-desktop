class_name SpBattleRules
extends RefCounted
## Rules of a 1v1 SP battle, engine-agnostic so they are unit tested headless (Tokyo Xtreme Racer
## style, docs/GAME_DESIGN.md "SP battle rules"). Both cars start with 100 SP. After a rolling
## run-up the gauge arms; from then the trailing car drains by its gap to the leader, and wall hits
## cost either car extra. The battle ends when a gauge empties or a car reaches the end of the
## road, where the higher gauge wins (the leader on a tie).

enum Phase { ROLLING, BATTLE, OVER }

const FULL := 100.0
## Side by side: no drain inside this gap (m).
const DEADBAND := 3.0
## Drain on the trailing car: a base rate once outside the deadband, plus a rate per metre of gap.
const DRAIN_BASE := 0.5
const DRAIN_PER_M := 0.2
## Fastest drain (SP/s), so a reset far behind empties the gauge in a few seconds, not one frame.
const DRAIN_MAX := 25.0
## Wall hits: impacts below this (m/s of impulse) are scrapes and free; above it each m/s costs SP.
const HIT_FREE_DV := 1.5
const HIT_SP_PER_DV := 4.0
const HIT_MAX := 15.0
## One contact is reported every step it lasts: a hit is charged once per this window (s).
const HIT_WINDOW := 0.5

var phase := Phase.ROLLING
## Gauges, [0] = car A (the player), [1] = car B (the rival).
var sp := PackedFloat64Array([FULL, FULL])
## Road distance where the gauge arms, and where the road ends.
var arm_distance := 0.0
var finish_distance := 0.0
## Index of the winner once OVER, and why: "sp" (a gauge emptied) or "road" (the road ended).
var winner := -1
var reason := ""
## Race time when it was decided (set by the race; the rules have no clock of their own).
var time := -1.0
## The latest gap (m, ≥ 0) and which car trails (-1 when level).
var gap := 0.0
var trailing := -1
var _hit_cooldown := PackedFloat64Array([0.0, 0.0])


func _init(arm_distance_: float, finish_distance_: float) -> void:
	arm_distance = arm_distance_
	finish_distance = finish_distance_


## Advances by `dt` with the cars at `a` and `b` metres along the road. Returns event names:
## "armed", "over".
func update(dt: float, a: float, b: float) -> PackedStringArray:
	var events := PackedStringArray()
	for i in 2:
		_hit_cooldown[i] = maxf(0.0, _hit_cooldown[i] - dt)
	gap = absf(a - b)
	trailing = -1 if gap <= DEADBAND else (0 if a < b else 1)
	match phase:
		Phase.ROLLING:
			if maxf(a, b) >= arm_distance:
				phase = Phase.BATTLE
				events.append("armed")
		Phase.BATTLE:
			if trailing >= 0:
				var rate := minf(DRAIN_MAX, DRAIN_BASE + DRAIN_PER_M * (gap - DEADBAND))
				sp[trailing] = maxf(0.0, sp[trailing] - rate * dt)
			if _decide(a, b):
				events.append("over")
	return events


## Car `i` hit a wall or the other car with `dv` m/s of impulse. Returns the SP it cost.
func hit(i: int, dv: float) -> float:
	if phase != Phase.BATTLE or dv <= HIT_FREE_DV or _hit_cooldown[i] > 0.0:
		return 0.0
	_hit_cooldown[i] = HIT_WINDOW
	var cost := minf(HIT_MAX, (dv - HIT_FREE_DV) * HIT_SP_PER_DV)
	sp[i] = maxf(0.0, sp[i] - cost)
	return cost


func _decide(a: float, b: float) -> bool:
	if sp[0] <= 0.0 or sp[1] <= 0.0:
		reason = "sp"
		winner = 1 if sp[0] <= 0.0 else 0
	elif maxf(a, b) >= finish_distance:
		reason = "road"
		var leader := 0 if a >= b else 1
		winner = leader if sp[leader] >= sp[1 - leader] else 1 - leader
	else:
		return false
	phase = Phase.OVER
	return true
