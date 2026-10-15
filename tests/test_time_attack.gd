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
