class_name StoryRoom
extends Node3D
## Story mode's room stage: the small rooms of the story (the clinic, Pang's rented room, Jolo's
## family home), built in Blender by tools/world_builders/build-story-rooms.py, lit by their own
## lamps and framed from the open side like a panel. A beat names its set ("set"); a "~set" line
## cuts to another mid-scene. Esc pauses (StoryPause).

## glb, the camera's eye and aim (layout units: x east, y up, z north), fov, and the room's lamps
## [position, colour, energy, range].
const SETS := {
	"clinic": { "glb": "res://assets/world/story_clinic.glb", "eye": Vector3(1.4, 1.75, -1.4),
		"at": Vector3(-0.6, 0.15, 2.4), "fov": 62.0,
		"lamps": [[Vector3(-0.6, 2.5, 2.4), Color(0.95, 1.0, 0.95), 1.4, 6.0], [Vector3(1.0, 1.6, -0.8), Color(0.8, 0.85, 1.0), 0.5, 5.0]] },
	"rented_room": { "glb": "res://assets/world/story_rented_room.glb", "eye": Vector3(0.8, 1.7, -1.2),
		"at": Vector3(-0.3, 0.0, 2.0), "fov": 64.0,
		"lamps": [[Vector3(0.0, 2.15, 1.6), Color(1.0, 0.86, 0.6), 0.55, 5.0], [Vector3(1.0, 0.95, 2.5), Color(0.8, 0.88, 1.0), 0.25, 1.2]] },
	"jolo_home": { "glb": "res://assets/world/story_jolo_home.glb", "eye": Vector3(1.2, 1.75, -1.4),
		"at": Vector3(-0.8, 0.1, 2.2), "fov": 62.0,
		"lamps": [[Vector3(0.0, 2.5, 2.0), Color(1.0, 0.97, 0.9), 0.7, 7.0], [Vector3(1.2, 1.6, -0.8), Color(1.0, 0.97, 0.9), 0.3, 5.0]] },
}

var camera: ChaseCamera
var _set := ""
var _model: Node3D
var _lamps: Array[OmniLight3D] = []


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	env.environment = MangaArt.environment()
	add_child(env)
	add_child(MangaArt.sun())
	# The chase camera with no car is a fixed camera that carries the manga page.
	camera = ChaseCamera.new()
	add_child(camera)
	camera.current = true
	if not InputMap.has_action("hub_menu"):
		InputMap.add_action("hub_menu")
		var e := InputEventKey.new()
		e.physical_keycode = KEY_ESCAPE
		InputMap.action_add_event("hub_menu", e)
	if not StoryMode.active:
		StoryMode.resume(get_tree())
		return
	show_set(str(StoryMode.current().get("set", "rented_room")))
	var director := StoryDirector.new()
	director.name = "StoryDirector"
	director.stage = "room"
	director.room = self
	add_child(director)



## Build set `name` (no-op if it is already up).
func show_set(name: String) -> void:
	if name == _set or not SETS.has(name):
		return
	_set = name
	if _model:
		_model.queue_free()
	for l in _lamps:
		l.queue_free()
	_lamps.clear()
	var spec: Dictionary = SETS[name]
	_model = (load(spec["glb"]) as PackedScene).instantiate() as Node3D
	add_child(_model)
	WorldKit.restyle(_model)
	for lamp in spec["lamps"]:
		var l := OmniLight3D.new()
		l.position = _godot(lamp[0])
		l.light_color = lamp[1]
		l.light_energy = lamp[2]
		l.omni_range = lamp[3]
		l.shadow_enabled = true
		add_child(l)
		_lamps.append(l)
	camera.fov = spec["fov"]
	camera.position = _godot(spec["eye"])
	camera.look_at(_godot(spec["at"]))


## Layout units (z north) to Godot (z south).
static func _godot(v: Vector3) -> Vector3:
	return Vector3(v.x, v.y, -v.z)
