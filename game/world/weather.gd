class_name Weather
extends Node3D
## Rain on the page: ink streaks falling round the camera (paper streaks at night), a darker, sheened
## road (`manga_wet` in the world shader), mist, a rain loop, and less grip for every car on the road.
## `wet` 0..1 is the road (grip and sheen); `rain` 0..1 is what is falling. Damp road, no rain: wet
## only. From the driver's seat the rain is on the glass too (Windscreen). Grip on a soaked road
## is WET_GRIP of dry, the step change the story's last night run hinges on.

const WET_GRIP := 0.62
const RAIN_LOOP := preload("res://assets/audio/ambience/rain_loop.wav")

var camera: Camera3D
var wet := 0.0:
	set(v):
		wet = clampf(v, 0.0, 1.0)
		RenderingServer.global_shader_parameter_set("manga_wet", maxf(wet, sheen))
## A road that only looks damp (dark patches, sheen in the ruts) without losing grip.
var sheen := 0.0:
	set(v):
		sheen = clampf(v, 0.0, 1.0)
		RenderingServer.global_shader_parameter_set("manga_wet", maxf(wet, sheen))
var rain := 0.0:
	set(v):
		rain = clampf(v, 0.0, 1.0)
		_apply_rain()
## Extra grip scale on top of the wet road (1 = none); the story's damp middle sector uses it.
var grip_scale := 1.0
## The view is from inside a car that is not the chase camera's (a parked-car scene): show the glass.
var cabin := false
var windscreen: Windscreen
var _particles: GPUParticles3D
var _material: StandardMaterial3D
var _audio: AudioStreamPlayer
var _env: Environment


func _ready() -> void:
	_particles = GPUParticles3D.new()
	_particles.amount = 2400
	_particles.lifetime = 0.9
	_particles.visibility_aabb = AABB(Vector3(-24, -16, -24), Vector3(48, 32, 48))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(18, 1, 18)
	process.direction = Vector3(0.08, -1, 0.02)
	process.spread = 2.0
	process.initial_velocity_min = 22.0
	process.initial_velocity_max = 26.0
	process.gravity = Vector3.ZERO
	_particles.process_material = process
	# A thin vertical quad stretched along its fall: an ink stroke.
	var quad := QuadMesh.new()
	quad.size = Vector2(0.018, 0.9)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = _material
	_particles.draw_pass_1 = quad
	_particles.layers = 1
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_particles)
	_audio = AudioStreamPlayer.new()
	_audio.stream = CarAudio._looped(RAIN_LOOP)
	_audio.bus = "Ambience" if AudioServer.get_bus_index("Ambience") >= 0 else "Master"
	add_child(_audio)
	windscreen = Windscreen.new()
	add_child(windscreen)
	var env_node := get_viewport().find_child("WorldEnvironment", true, false) as WorldEnvironment
	if env_node == null:
		for n in get_tree().root.find_children("*", "WorldEnvironment", true, false):
			env_node = n
	if env_node:
		_env = env_node.environment
	wet = wet
	_apply_rain()


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("manga_wet", 0.0)
	for car in get_tree().get_nodes_in_group(&"cars"):
		var body := car as CarBody
		if body and body.model:
			body.model.surface_grip = 1.0
	if _env:
		_env.fog_enabled = false


func _apply_rain() -> void:
	if _particles == null:
		return
	_particles.emitting = rain > 0.01
	_particles.amount_ratio = maxf(rain, 0.05)
	if _audio:
		if rain > 0.01 and not _audio.playing:
			_audio.play()
		elif rain <= 0.01:
			_audio.stop()
		_audio.volume_db = linear_to_db(maxf(rain, 0.001)) - 6.0
	if _env:
		_env.fog_enabled = rain > 0.01
		_env.fog_light_color = Color(0.55, 0.55, 0.55).lerp(Color(0.05, 0.05, 0.06), MangaArt.night)
		_env.fog_density = 0.012 * rain
		_env.fog_sky_affect = 0.4


## Every car on the road loses grip on a wet surface.
func surface_grip() -> float:
	return lerpf(1.0, WET_GRIP, wet) * grip_scale


## A car on the rain set keeps more of its grip on a wet road; a damp patch under one car
## (CarBody.surface_scale) is that car's alone.
func grip_for(body: CarBody) -> float:
	var wet_grip := CarParts.RAIN_WET_GRIP if body.on_rain_set() else WET_GRIP
	return lerpf(1.0, wet_grip, wet) * grip_scale * body.surface_scale


func _physics_process(_delta: float) -> void:
	for car in get_tree().get_nodes_in_group(&"cars"):
		var body := car as CarBody
		if body and body.model:
			body.model.surface_grip = grip_for(body)


func _process(_delta: float) -> void:
	if camera == null:
		camera = get_viewport().get_camera_3d()
	if camera:
		_particles.global_position = camera.global_position + Vector3(0, 9, 0) - camera.global_basis.z * 6.0
	# Rain on the glass whenever the view is from the driver's seat.
	var chase := camera as ChaseCamera
	var hood := chase != null and chase.current and chase.mode == ChaseCamera.Mode.HOOD
	windscreen.shown = cabin or hood
	windscreen.rain = rain
	windscreen.speed = chase.target.linear_velocity.length() if hood and chase.target else 0.0
	# Ink by day, paper streaks in the headlights at night.
	_material.albedo_color = Color(MangaType.INK, 0.55).lerp(Color(MangaType.PAPER, 0.5), MangaArt.night)
