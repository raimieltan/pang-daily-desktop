class_name TimeAttack
extends Node
## A time-attack run on a track for the session's car: countdown with the car held on the brakes
## (throttle still revs), live timer and sector splits against the local best, a ghost of the best
## run, reset to the last checkpoint (R), restart (Enter), and records saved on a new best.

signal started
signal finished(time: float, record: bool)

const GHOST_SHADER := preload("res://game/art/manga_ghost.gdshader")

var track: TrackData
var track_id := "touge_01"
var session: DriveSession
var run: TimeAttackRun
var best := {}
var hud: RaceHud
var intro: RaceIntro
var music: MusicPlayer
var _in_intro := false
var _ghost_data := PackedFloat32Array()
var _ghost_visual: Node3D
var _ghost_model := ""
var _record := PackedFloat32Array()
var _sample_clock := 0.0
var _index_hint := 0
## False in free drive: no timer, ghost or countdown.
var active := true


func _ready() -> void:
	PlayerInput.register_actions()
	if not InputMap.has_action("restart_run"):
		InputMap.add_action("restart_run")
		for key in [KEY_ENTER, KEY_KP_ENTER]:
			var e := InputEventKey.new()
			e.physical_keycode = key
			InputMap.action_add_event("restart_run", e)
	hud = RaceHud.new()
	add_child(hud)
	_ghost_visual = _make_ghost()
	add_child(_ghost_visual)
	session.input_filter = _filter_input
	session.reset_pose = _reset_pose
	restart()


func _car_id() -> String:
	return session.car_spec["id"] + "_" + session.car.preset


## With an intro, the car waits on the line (brakes on) while it plays; the countdown follows.
func restart(with_intro := false) -> void:
	active = true
	session.input_filter = _filter_input
	session.reset_pose = _reset_pose
	run = null
	best = TimeAttackRecords.load_best(track_id, _car_id())
	_ghost_data = TimeAttackRecords.load_ghost(track_id, _car_id())
	_record = PackedFloat32Array()
	_sample_clock = 0.0
	_index_hint = track.index_at(track.start_distance)
	var pose := track.pose_at(track.start_distance - 8.0)
	session.car.place(pose["position"], pose["heading"])
	session.camera.snap.call_deferred()
	if _ghost_model != session.car_spec["model"]:
		_ghost_visual.queue_free()
		_ghost_visual = _make_ghost()
		add_child(_ghost_visual)
	_ghost_visual.visible = false
	if with_intro and intro:
		if music:
			music.play_track(&"intro")
		hud.visible = false
		_in_intro = true
		await get_tree().physics_frame
		await get_tree().physics_frame
		intro.play(track, [{ "node": session.car, "name": "YOU", "car": session.car_spec["name"] }], "TIME ATTACK", "PASS 1  ·  DOWNHILL")
		await intro.finished
		_in_intro = false
		if not active:
			return
		session.camera.snap.call_deferred()
	if music and active:
		music.play_track(&"race_alt")
	hud.visible = true
	run = TimeAttackRun.new(track.start_distance, track.finish_distance)
	hud.show_run(best)


## Free drive: drop the run and its HUD; the car keeps going where it is.
func free_drive() -> void:
	active = false
	if intro:
		intro.skip()
	run = null
	hud.visible = false
	_ghost_visual.visible = false


func _filter_input(input: VehicleTypes.DriverInput) -> VehicleTypes.DriverInput:
	if active and (run == null or run.phase == TimeAttackRun.Phase.COUNTDOWN):
		input.brake = 1.0
		input.handbrake = 0.0
	return input


func _reset_pose(_car: CarBody) -> Dictionary:
	if run == null or run.phase == TimeAttackRun.Phase.FINISHED:
		return track.pose_at(track.distance_at(session.car.global_position, _index_hint))
	var d := run.respawn_distance()
	run.respawned(d)
	_index_hint = track.index_at(d)
	return track.pose_at(d)


func _unhandled_input(event: InputEvent) -> void:
	if active and not _in_intro and event.is_action_pressed("restart_run"):
		restart()


func _physics_process(delta: float) -> void:
	if run == null:
		return
	var car := session.car
	_index_hint = track.nearest_index(car.global_position, _index_hint)
	var events := run.update(delta, _index_hint * track.spacing)
	for e in events:
		match e:
			"go":
				hud.go()
				started.emit()
			"sector":
				var k := run.splits.size() - 1
				var ref: Array = best.get("splits", [])
				hud.split(k, run.splits[k], float(ref[k]) if k < ref.size() else -1.0)
			"finish":
				var record := TimeAttackRecords.submit(track_id, _car_id(), run.time, run.splits, _record)
				hud.finish(run.time, float(best.get("time", -1.0)), record)
				finished.emit(run.time, record)
	if run.phase == TimeAttackRun.Phase.RUNNING:
		_sample_clock += delta
		while _sample_clock >= 1.0 / TimeAttackRecords.GHOST_HZ:
			_sample_clock -= 1.0 / TimeAttackRecords.GHOST_HZ
			var p := car.global_position
			var q := car.global_basis.get_rotation_quaternion()
			_record.append_array([p.x, p.y, p.z, q.x, q.y, q.z, q.w])


func _process(_delta: float) -> void:
	if run == null:
		return
	hud.update_run(run)
	var pose := TimeAttackRecords.ghost_pose(_ghost_data, run.time) if run.phase == TimeAttackRun.Phase.RUNNING else {}
	_ghost_visual.visible = not pose.is_empty()
	if not pose.is_empty():
		_ghost_visual.global_transform = Transform3D(Basis(pose["rotation"]), pose["position"])


## The best run's car (the player's current body): a translucent paper sketch with ink edges, no collisions.
func _make_ghost() -> Node3D:
	var root := Node3D.new()
	root.name = "Ghost"
	_ghost_model = session.car_spec["model"]
	var model: Node3D = (load(_ghost_model) as PackedScene).instantiate()
	model.rotation.y = PI
	root.add_child(model)
	var m := ShaderMaterial.new()
	m.shader = GHOST_SHADER
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.layers = CarVisual.CAR_RENDER_LAYER
	return root
