extends RefCounted
## SP battle rules: rolling run-up, gap drain, wall-hit penalties and both end conditions.

var errors: Array[String] = []

const DT := 1.0 / 120.0


func _check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)


## Both cars at `speed` with B `lead` metres ahead of A, from `from` until either reaches `to`
## or the battle ends.
func _drive(rules: SpBattleRules, from: float, to: float, lead: float, speed := 30.0) -> PackedStringArray:
	var events := PackedStringArray()
	var a := from
	while a + maxf(lead, 0.0) < to and rules.phase != SpBattleRules.Phase.OVER:
		a += speed * DT
		events.append_array(rules.update(DT, a, a + lead))
	return events


func test_no_drain_before_the_gauge_arms() -> void:
	var rules := SpBattleRules.new(150.0, 1400.0)
	var events := _drive(rules, 20.0, 200.0, 40.0)
	_check(rules.phase == SpBattleRules.Phase.BATTLE and events.has("armed"), "arms when the leader reaches the SP line")
	var r := SpBattleRules.new(150.0, 1400.0)
	_drive(r, 20.0, 100.0, 20.0)
	_check(r.sp[0] == 100.0 and r.sp[1] == 100.0, "full gauges through the run-up (%s)" % r.sp)


func test_side_by_side_does_not_drain() -> void:
	var rules := SpBattleRules.new(30.0, 1400.0)
	_drive(rules, 20.0, 600.0, 2.0)
	_check(rules.sp[0] == 100.0 and rules.sp[1] == 100.0, "no drain inside the deadband (%s)" % rules.sp)


func test_trailing_car_drains_by_gap() -> void:
	var near := SpBattleRules.new(30.0, 5000.0)
	var far := SpBattleRules.new(30.0, 5000.0)
	_drive(near, 30.0, 340.0, 10.0)
	_drive(far, 30.0, 370.0, 40.0)
	_check(near.sp[1] == 100.0 and far.sp[1] == 100.0, "the leader keeps a full gauge")
	_check(near.sp[0] < 100.0, "trailing by 10 m drains (%.1f)" % near.sp[0])
	_check(far.sp[0] < near.sp[0], "a bigger gap drains faster (%.1f vs %.1f)" % [far.sp[0], near.sp[0]])
	# 10 s at 10 m: (0.5 + 0.2 × 7) × 10 = 19 SP.
	_check(absf(near.sp[0] - 81.0) < 0.5, "10 m for 10 s costs ~19 SP (left %.1f)" % near.sp[0])


func test_empty_gauge_ends_the_battle() -> void:
	var rules := SpBattleRules.new(30.0, 5000.0)
	var events := _drive(rules, 30.0, 4000.0, 60.0)
	_check(events.has("over") and rules.phase == SpBattleRules.Phase.OVER, "ends when a gauge empties")
	_check(rules.winner == 1 and rules.reason == "sp", "the leader wins on SP (winner %d, %s)" % [rules.winner, rules.reason])
	_check(rules.sp[0] == 0.0, "the gauge stops at 0")


func test_road_end_higher_gauge_wins() -> void:
	var rules := SpBattleRules.new(30.0, 600.0)
	# A trails for a while, then B scrapes walls hard: A has more SP at the end but finishes second.
	_drive(rules, 30.0, 200.0, 8.0)
	for k in 6:
		rules.update(SpBattleRules.HIT_WINDOW + 0.01, 200.0, 208.0)
		rules.hit(1, 6.0)
	var events := _drive(rules, 200.0, 610.0, 8.0)
	_check(events.has("over") and rules.reason == "road", "ends at the road end (%s)" % rules.reason)
	_check(rules.sp[0] > rules.sp[1], "A kept more SP (%s)" % rules.sp)
	_check(rules.winner == 0, "the higher gauge wins even from behind")


func test_road_end_tie_goes_to_the_leader() -> void:
	var rules := SpBattleRules.new(30.0, 600.0)
	var events := _drive(rules, 30.0, 610.0, 1.0)
	_check(events.has("over") and rules.winner == 1, "level gauges: the car ahead wins (winner %d)" % rules.winner)


func test_wall_hits_cost_sp_once_per_window() -> void:
	var rules := SpBattleRules.new(30.0, 5000.0)
	_check(rules.hit(0, 8.0) == 0.0, "no penalty during the run-up")
	_drive(rules, 20.0, 40.0, 0.0)
	_check(rules.hit(0, 1.0) == 0.0, "a scrape under the threshold is free")
	var cost := rules.hit(0, 4.0)
	_check(absf(cost - 10.0) < 1e-6, "(4 − 1.5) × 4 = 10 SP (got %.2f)" % cost)
	_check(rules.hit(0, 4.0) == 0.0, "the same contact next step is not charged again")
	_check(rules.hit(1, 50.0) == SpBattleRules.HIT_MAX, "one hit costs at most HIT_MAX")
	rules.update(SpBattleRules.HIT_WINDOW, 40.0, 40.0)
	_check(rules.hit(0, 4.0) > 0.0, "a new hit after the window is charged")
