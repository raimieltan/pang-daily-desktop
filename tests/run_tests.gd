extends SceneTree
## Headless test runner: `godot --headless --path . -s res://tests/run_tests.gd`
## Runs every `test_*` method of the suites below and exits non-zero on any failure.

const SUITES := [
	preload("res://tests/test_sim_parity.gd"),
	preload("res://tests/test_time_attack.gd"),
	preload("res://tests/test_sp_battle.gd"),
	preload("res://tests/test_story.gd"),
	preload("res://tests/test_gearbox.gd"),
	preload("res://tests/test_tuning.gd"),
	preload("res://tests/test_rival_audio.gd"),
]

var failures := 0
var passes := 0


func _initialize() -> void:
	for suite_script in SUITES:
		var suite = suite_script.new()
		for method in suite.get_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			suite.errors.clear()
			var started := Time.get_ticks_msec()
			suite.call(name)
			var ms := Time.get_ticks_msec() - started
			if suite.errors.is_empty():
				passes += 1
				print("  ok   %s (%d ms)" % [name, ms])
			else:
				failures += 1
				print("  FAIL %s (%d ms)" % [name, ms])
				for e in suite.errors:
					print("       ", e)
	print("\n%d passed, %d failed" % [passes, failures])
	quit(1 if failures > 0 else 0)
