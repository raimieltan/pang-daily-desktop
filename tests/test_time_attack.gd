extends RefCounted
## Time-attack rules: countdown, ordered checkpoints, shortcut rejection, sectors and finish.

var errors: Array[String] = []


func _check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)


func _drive(run: TimeAttackRun, from: float, to: float, speed := 20.0, dt := 1.0 / 120.0) -> PackedStringArray:
	var events := PackedStringArray()
	var d := from
	while d < to:
		d = minf(to, d + speed * dt)
		events.append_array(run.update(dt, d))
	return events


## The results: best sector times kept across runs (not only record runs), their sum as the
## theoretical best, and the GOAL panel's lines (docs/GAME_DESIGN.md "Results").
func test_best_sectors_merge_and_sum() -> void:
	var first := TimeAttackRecords.merge_sectors([], PackedFloat64Array([20.0, 42.0, 66.0, 90.0]))
	_check(first == [20.0, 22.0, 24.0, 24.0], "cumulative splits become sector times (got %s)" % [first])
	var merged := TimeAttackRecords.merge_sectors(first, PackedFloat64Array([21.0, 41.0, 67.0, 89.0]))
	_check(merged == [20.0, 20.0, 24.0, 22.0], "each sector keeps its quickest (got %s)" % [merged])
	_check(absf(TimeAttackRecords.theoretical(merged) - 86.0) < 1e-9, "theoretical best is their sum")
	_check(TimeAttackRecords.theoretical([]) < 0.0, "no sectors, no theoretical best")
	_check(TimeAttackRecords.merge_sectors(first, PackedFloat64Array([21.0, 41.0])) == first, "a short run (not finished) changes nothing")


func test_goal_panel_lines() -> void:
	var splits := PackedFloat64Array([20.0, 42.0, 66.0, 90.0])
	var lines := RaceHud.result_lines(90.0, splits, [21.0, 41.5, 65.5, 91.0], [20.0, 20.0, 24.0, 22.0], 91.0, true, "BEST")
	var text := "\n".join(lines)
	_check(lines[0] == "G O A L" and "1:30.000" in text, "the time under GOAL")
	_check("S1  20.000  −1.000" in text, "a sector with its delta to the best run's sector")
	_check("S2  22.000  +1.500" in text, "...slower shows plus")
	_check("S3  24.000  ±0.000" in text, "...equal shows ±")
	_check("THEORETICAL  1:26.000" in text, "the theoretical best from the best sectors")
	_check("NEW RECORD!" in text and "−1.000" in text, "a record says so with the gain")
	var plain := "\n".join(RaceHud.result_lines(92.0, splits, [], [], 91.0, false, "BEST"))
	_check("S1  20.000" in plain and not ("S1  20.000  " in plain), "no reference: sector times alone")
	_check("BEST  1:31.000" in plain and "+1.000" in plain, "not a record: the best and the gap to it")
	_check(not ("THEORETICAL" in plain), "no sectors kept yet: no theoretical line")
	var first_run := "\n".join(RaceHud.result_lines(92.0, splits, [], [], -1.0, true, "BEST"))
	_check("FIRST RECORD" in first_run, "the first run is the first record")


func test_countdown_then_go() -> void:
	var run := TimeAttackRun.new(20.0, 1000.0)
	var events := PackedStringArray()
	for i in 359:
		events.append_array(run.update(1.0 / 120.0, 20.0))
	_check(run.phase == TimeAttackRun.Phase.COUNTDOWN, "still counting down just before 3 s")
	events.append_array(run.update(2.0 / 120.0, 20.0))
	_check("go" in events and run.phase == TimeAttackRun.Phase.RUNNING, "goes after 3 s")
	_check(run.time == 0.0, "the timer starts at go, not during the countdown")


func test_full_run_finishes_with_all_checkpoints_and_sectors() -> void:
	var run := TimeAttackRun.new(20.0, 1000.0)
	run.update(3.1, 20.0)
	var events := _drive(run, 20.0, 1001.0)
	_check(run.phase == TimeAttackRun.Phase.FINISHED, "finishes at the finish distance")
	_check(events.count("checkpoint") == run.checkpoints.size(), "every checkpoint passed in order")
	_check(run.splits.size() == 4 and events.count("sector") == 4, "four sector splits")
	_check(absf(run.time - 49.0) < 0.1, "time ≈ distance / speed (got %.2f)" % run.time)


func test_shortcut_jump_is_ignored() -> void:
	var run := TimeAttackRun.new(20.0, 1000.0)
	run.update(3.1, 20.0)
	_drive(run, 20.0, 300.0)
	# Cutting across a switchback lands 200 m further along the road in one step.
	run.update(1.0 / 120.0, 500.0)
	_check(run.progress < 310.0, "a 200 m jump does not count (progress %.0f)" % run.progress)
	_check(run.next_checkpoint == 2, "no checkpoints credited by the cut")


func test_reset_returns_to_last_checkpoint() -> void:
	var run := TimeAttackRun.new(20.0, 1000.0)
	run.update(3.1, 20.0)
	_drive(run, 20.0, 450.0)
	var back := run.respawn_distance()
	_check(back == 420.0, "respawns at the last checkpoint passed (got %.0f)" % back)
	run.respawned(back)
	var events := _drive(run, back, 1001.0)
	_check(run.phase == TimeAttackRun.Phase.FINISHED and events.has("finish"), "finishes after a reset")


func test_format_time() -> void:
	_check(TimeAttackRun.format_time(83.4567) == "1:23.457", "formats m:ss.mmm (got %s)" % TimeAttackRun.format_time(83.4567))
