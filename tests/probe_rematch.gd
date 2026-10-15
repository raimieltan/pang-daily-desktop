extends SceneTree
## Starts a VS battle, rematches three times mid-race, and checks nothing errors (headless).

var _scene
var _t := 0.0
var _n := 0


func _initialize() -> void:
	GameMenu.skip_title = true
	_scene = load("res://scenes/touge.tscn").instantiate()
	root.add_child(_scene)


func _physics_process(delta: float) -> bool:
	_t += delta
	if _n == 0 and _t > 0.2:
		_scene.time_attack.free_drive()
		_scene.vs_battle.start()
		_scene.intro.skip()
		_n = 1
	elif _n > 0 and _t > 0.2 + _n * 2.0:
		if _n == 4:
			print("REMATCH_OK rivals=%d" % _scene.vs_battle.rivals.size())
			quit(0)
			return true
		_scene.vs_battle.start()
		_scene.intro.skip()
		_n += 1
	return false
