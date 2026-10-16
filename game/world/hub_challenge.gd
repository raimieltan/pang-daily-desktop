class_name HubChallenge
## A challenge made in the barangay, handed across the scene change to Pass 1 and back.

const HUB_SCENE := "res://scenes/hub.tscn"
const PASS_SCENE := "res://scenes/touge.tscn"

## VsBattle.RIVALS index to battle on arrival at the pass; -1: none pending.
static var rival := -1
## Arrive at the pass in free drive (the main road's east exit).
static var free_drive := false
## The car the player drove up in (CarRoster id).
static var car_id := ""
## Where the hub puts you when you come back (HubLayout.PLACES key).
static var return_to := "kyo"


static func start(tree: SceneTree, rival_index: int, car: String) -> void:
	rival = rival_index
	car_id = car
	return_to = "kyo"
	tree.change_scene_to_file(PASS_SCENE)


static func back_to_hub(tree: SceneTree) -> void:
	rival = -1
	free_drive = false
	tree.paused = false
	tree.change_scene_to_file(HUB_SCENE)
