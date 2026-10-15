class_name Replay
extends Node
## Records every car in the run (pose plus what the visual, effects and audio read, see
## `CarBody.capture_replay`) and plays it back by posing the same cars, so the replay looks
## exactly like the run. F opens it; while it plays the race logic is frozen.
## Space pause · ←/→ seek 5 s · ↑/↓ speed · Tab next car · V camera · U clean feed · F back to the race.

signal started
signal stopped

const RATE := 60.0
const MAX_SECONDS := 420.0
const SPEEDS := [0.1, 0.25, 0.5, 1.0, 2.0]
const SEEK_SECONDS := 5.0

var session: DriveSession
## Nodes whose processing stops while the replay plays (race modes, so their clocks hold).
var frozen_nodes: Array[Node] = []
## Display names per car, for the HUD ("YOU", rival names).
var names: Array[String] = []
var cars: Array[CarBody] = []
## Brings the play HUD back after a replay (set by the menu, which knows what each mode shows).
var restore_hud: Callable
var playing := false
var paused := false
var time := 0.0
var speed_index := 3

var _frames: Array[PackedFloat32Array] = []   # per car, REPLAY_STRIDE floats per frame
var _times := PackedFloat32Array()        # run time of each frame
var _count := 0
var _clock := 0.0
var _last_sample := -INF
var _recording := false
var _return_mode := ChaseCamera.Mode.CHASE
var _return_target: CarBody
var _live_time_scale := 1.0
var _hud: CanvasLayer
var _label: Label
var _help: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for pair in [["replay", KEY_F], ["replay_pause", KEY_SPACE], ["replay_back", KEY_LEFT], ["replay_forward", KEY_RIGHT],
			["replay_faster", KEY_UP], ["replay_slower", KEY_DOWN], ["replay_next_car", KEY_TAB]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
			var e := InputEventKey.new()
			e.physical_keycode = pair[1]
			InputMap.action_add_event(pair[0], e)
	_hud = CanvasLayer.new()
	_hud.layer = 11
	_hud.visible = false
	_hud.add_to_group(&"play_hud")
	add_child(_hud)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.position.y = 22
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(box)
	_label = MangaType.label("REPLAY", 34)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_label)
	_help = MangaType.label("SPACE PAUSE   ← → SEEK   ↑ ↓ SPEED   TAB CAR   V CAMERA   U CLEAN   F EXIT", 20, MangaType.caption())
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_help)


## Start a fresh recording of these cars (the player first).
func begin(cars_: Array[CarBody], names_: Array[String]) -> void:
	if playing:
		stop()
	cars = cars_.duplicate()
	names = names_.duplicate()
	_frames.clear()
	for c in cars:
		_frames.append(PackedFloat32Array())
	_times = PackedFloat32Array()
	_count = 0
	_clock = 0.0
	_last_sample = -INF
	_recording = true


func duration() -> float:
	return _times[_count - 1] - _times[0] if _count > 1 else 0.0


func can_play() -> bool:
	return duration() > 1.0 and cars.all(func(c): return is_instance_valid(c))


func _physics_process(delta: float) -> void:
	if playing:
		_play_step(delta)
		return
	if not _recording:
		return
	# Sample by run time, not ticks: time_scale stretches each tick rather than adding ticks.
	_clock += delta
	if _clock - _last_sample < 1.0 / RATE - 1e-4:
		return
	_last_sample = _clock
	if not cars.all(func(c): return is_instance_valid(c)):
		_recording = false
		return
	if _count >= int(MAX_SECONDS * RATE):
		# Keep the latest MAX_SECONDS: drop the oldest second.
		var n := int(RATE)
		for k in _frames.size():
			_frames[k] = _frames[k].slice(n * CarBody.REPLAY_STRIDE)
		_times = _times.slice(n)
		_count -= n
	for k in cars.size():
		cars[k].capture_replay(_frames[k])
	_times.append(_clock)
	_count += 1


func start() -> void:
	if playing or not can_play():
		return
	playing = true
	paused = false
	speed_index = 3
	time = 0.0
	_live_time_scale = Engine.time_scale
	for n in frozen_nodes:
		n.set_physics_process(false)
		n.set_process(false)
	for c in cars:
		c.set_replaying(true)
	var cam := session.camera
	_return_mode = cam.mode
	_return_target = cam.target
	cam.director.set_cars(cars, names)
	cam.director.focus = 0
	cam.director.auto_focus = true
	cam.mode = ChaseCamera.Mode.CINEMATIC
	_hud.visible = not session.clean_feed
	_reset_fx()
	_play_step(0.0)
	started.emit()


## Back to the race exactly where it was: every car posed on the last recorded frame.
func stop() -> void:
	if not playing:
		return
	playing = false
	Engine.time_scale = _live_time_scale
	time = duration()
	_pose_all()
	for c in cars:
		if is_instance_valid(c):
			c.set_replaying(false)
	for n in frozen_nodes:
		n.set_physics_process(true)
		n.set_process(true)
	var cam := session.camera
	cam.target = _return_target if is_instance_valid(_return_target) else session.car
	cam.director.set_cars([session.car], ["YOU"])
	cam.mode = _return_mode
	_hud.visible = false
	_reset_fx()
	if restore_hud.is_valid() and not session.clean_feed:
		restore_hud.call()
	stopped.emit()


func _play_step(delta: float) -> void:
	if not cars.all(func(c): return is_instance_valid(c)):
		stop()
		return
	if not paused:
		time = minf(time + delta, duration())
		if time >= duration():
			paused = true
	_pose_all()


func _pose_all() -> void:
	var t := _times[0] + clampf(time, 0.0, duration())
	var b := clampi(_times.bsearch(t), 1, _count - 1)
	var a := b - 1
	var u := clampf((t - _times[a]) / maxf(_times[b] - _times[a], 1e-5), 0.0, 1.0)
	var stride := CarBody.REPLAY_STRIDE
	for k in cars.size():
		var src := _frames[k]
		var f := src.slice(a * stride, (a + 1) * stride)
		if b != a and u > 0.0:
			var g := src.slice(b * stride, (b + 1) * stride)
			for i in 3:
				f[i] = lerpf(f[i], g[i], u)
			var q := Quaternion(f[3], f[4], f[5], f[6]).slerp(Quaternion(g[3], g[4], g[5], g[6]), u)
			f[3] = q.x
			f[4] = q.y
			f[5] = q.z
			f[6] = q.w
			for i in range(7, 13):
				f[i] = lerpf(f[i], g[i], u)
		if paused:
			# Hold still: no velocity to integrate on top of the pose.
			for i in range(7, 13):
				f[i] = 0.0
		cars[k].replay_frame = f


func _process(_delta: float) -> void:
	if not playing:
		return
	# The race HUD would show a frozen clock: only the replay strip is on screen.
	for n in get_tree().get_nodes_in_group(&"play_hud"):
		if n != _hud and n != session.camera_picker:
			n.visible = false
	_hud.visible = not session.clean_feed
	var who: String = names[session.camera.director.focus] if session.camera.director.focus < names.size() else ""
	_label.text = "REPLAY  %s  ×%s   %s / %s   ·   %s" % ["II" if paused else "▶", _speed_text(),
		TimeAttackRun.format_time(time), TimeAttackRun.format_time(duration()), who]


func _speed_text() -> String:
	var s: float = SPEEDS[speed_index]
	return ("%.2f" % s).trim_suffix("0").trim_suffix("0").trim_suffix(".")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("replay"):
		if playing:
			stop()
		else:
			start()
		get_viewport().set_input_as_handled()
		return
	if not playing:
		return
	if event.is_action_pressed("replay_pause"):
		paused = not paused
		if not paused and time >= duration():
			time = 0.0
			_reset_fx()
	elif event.is_action_pressed("replay_back"):
		time = maxf(0.0, time - SEEK_SECONDS)
		_reset_fx()
	elif event.is_action_pressed("replay_forward"):
		time = minf(duration(), time + SEEK_SECONDS)
		_reset_fx()
	elif event.is_action_pressed("replay_faster"):
		speed_index = mini(speed_index + 1, SPEEDS.size() - 1)
	elif event.is_action_pressed("replay_slower"):
		speed_index = maxi(speed_index - 1, 0)
	elif event.is_action_pressed("replay_next_car"):
		var d := session.camera.director
		d.auto_focus = false
		d.focus = (d.focus + 1) % cars.size()
		d.cut()
	else:
		return
	Engine.time_scale = _live_time_scale * SPEEDS[speed_index]
	get_viewport().set_input_as_handled()


## Skid trails would join across a jump in time.
func _reset_fx() -> void:
	if session.fx:
		session.fx.reset_trails()
