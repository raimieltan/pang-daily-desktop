class_name CarParts
extends RefCounted
## Parts (docs/GAME_DESIGN.md "Speed costs money"; story prices in StoryShop): what each one does to
## a car's physical config, and tire wear. A build is { "parts": [ids], "wear": { "front", "rear" } }
## (wear 1.0 = new); `apply` lays it over HandlingPresets.physical_config(...) before the setup.
## The catalogue is shared: story mode prices it (StoryShop), the grind will too.

## Per km of driving (nominal distance, so a run costs the same however it went).
const WEAR_FRONT_PER_KM := 0.05
const WEAR_REAR_PER_KM := 0.03
## Worn tires keep this much of their grip, dry (new = 1.0).
const WORN_GRIP := 0.95
## The rain set's grip on a wet road (Weather.WET_GRIP is street tires'), and its cost in the dry.
const RAIN_WET_GRIP := 0.8
const RAIN_DRY_GRIP := 0.97

## id: name, BR (build rating), and what it changes. `axle` parts are tires: buying them resets
## that axle's wear. Effects: torque / brake / spring / damping / grip scales, mass delta (kg).
const PARTS := {
	"front_tires": { "name": "FRONT TIRES (PAIR)", "br": 0, "axle": "front" },
	"rear_tires": { "name": "REAR TIRES (PAIR)", "br": 0, "axle": "rear" },
	"pads": { "name": "BRAKE PADS", "br": 1, "brake": 1.05 },
	"rotors": { "name": "ROTORS + FLUID", "br": 1, "brake": 1.04 },
	"alignment": { "name": "ALIGNMENT", "br": 0, "grip": 1.01 },
	"coilovers": { "name": "USED COILOVERS", "br": 3, "spring": 1.25, "damping": 1.2, "grip": 1.02 },
	"rain_set": { "name": "RAIN SET (FOUR)", "br": 1, "rain": true },
	"intake": { "name": "INTAKE", "br": 1, "torque": 1.03 },
	"exhaust": { "name": "USED EXHAUST", "br": 1, "torque": 1.04 },
	"header": { "name": "HEADER", "br": 2, "torque": 1.06 },
	"remap": { "name": "ECU REMAP", "br": 2, "torque": 1.07 },
	"wheels": { "name": "LIGHTWEIGHT WHEELS", "br": 2, "mass": -14.0, "grip": 1.01 },
}


static func new_build() -> Dictionary:
	return { "parts": [], "wear": { "front": 1.0, "rear": 1.0 } }


static func has(build: Dictionary, id: String) -> bool:
	return id in build.get("parts", [])


## Build rating: the sum of the fitted parts' ratings.
static func rating(build: Dictionary) -> int:
	var br := 0
	for id in build.get("parts", []):
		br += int(PARTS.get(id, {}).get("br", 0))
	return br


static func wear(build: Dictionary, axle: String) -> float:
	return clampf(float(build.get("wear", {}).get(axle, 1.0)), 0.0, 1.0)


## Dry grip left in an axle's tires.
static func wear_grip(w: float) -> float:
	return lerpf(WORN_GRIP, 1.0, clampf(w, 0.0, 1.0))


## Drive `km` on the build's tires.
static func charge(build: Dictionary, km: float) -> void:
	var w: Dictionary = build.get("wear", { "front": 1.0, "rear": 1.0 })
	w["front"] = maxf(0.0, float(w.get("front", 1.0)) - WEAR_FRONT_PER_KM * km)
	w["rear"] = maxf(0.0, float(w.get("rear", 1.0)) - WEAR_REAR_PER_KM * km)
	build["wear"] = w


## Fit a part: tires reset their axle's wear; anything else goes on once.
static func fit(build: Dictionary, id: String) -> void:
	var spec: Dictionary = PARTS[id]
	if spec.has("axle"):
		build["wear"][spec["axle"]] = 1.0
		return
	var parts: Array = build["parts"]
	if not id in parts:
		parts.append(id)


## The config with the build on it (a deep copy; the input is untouched).
static func apply(physical: Dictionary, build: Dictionary) -> Dictionary:
	if build.is_empty():
		return physical
	var c := physical.duplicate(true)
	var m: Dictionary = c["mechanical"]
	var torque := 1.0
	var brake := 1.0
	var spring := 1.0
	var damping := 1.0
	var grip := 1.0
	var mass := 0.0
	for id in build.get("parts", []):
		var p: Dictionary = PARTS.get(id, {})
		torque *= float(p.get("torque", 1.0))
		brake *= float(p.get("brake", 1.0))
		spring *= float(p.get("spring", 1.0))
		damping *= float(p.get("damping", 1.0))
		grip *= float(p.get("grip", 1.0))
		mass += float(p.get("mass", 0.0))
		if p.get("rain", false):
			grip *= RAIN_DRY_GRIP
	var e: Dictionary = m["engine"]
	e["torqueNm"] = float(e["torqueNm"]) * torque
	e["clutchTorqueNm"] = maxf(float(e["clutchTorqueNm"]), float(e["torqueNm"]) * 1.5)
	c["brakes"]["decelerationMps2"] = float(c["brakes"]["decelerationMps2"]) * brake
	var sus: Dictionary = m["suspension"]
	sus["frontSpring"] = float(sus["frontSpring"]) * spring
	sus["rearSpring"] = float(sus["rearSpring"]) * spring
	sus["damping"] = float(sus["damping"]) * damping
	c["chassis"]["massKg"] = float(c["chassis"]["massKg"]) + mass
	var tires: Dictionary = c["tires"]
	tires["frontGrip"] = float(tires["frontGrip"]) * grip * wear_grip(wear(build, "front"))
	tires["rearGrip"] = float(tires["rearGrip"]) * grip * wear_grip(wear(build, "rear"))
	return c
