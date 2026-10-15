class_name SuspensionData
## Suspension save shape, parts, geometry curves and impact damage.
## Port of `src/game-core/suspension/{schema,parts,service}.ts` (the parts the solver needs).
## Saves are plain Dictionaries with the same keys as the TS `SavedSuspension` (version 2).

const DEG := PI / 180.0
const COMPONENTS := ["spring", "damper", "upperControlArm", "lowerControlArm", "tieRod", "knuckle", "hub", "topMount", "bushing"]

const _PART_DEFAULTS := { "strength": 1800.0, "mass": 35.0, "springScale": 1.0, "height": 0.0, "travel": 0.09, "droop": 0.06,
	"maxLock": 34.0 * DEG, "ackermann": 0.75, "geometry": "strut", "motionRatio": 1.0 }
const _PART_PATCHES := {
	"stock": {},
	"lowering": { "springScale": 1.4, "height": -0.035 },
	"street": { "springScale": 1.4, "height": -0.025, "strength": 2200.0, "geometry": "strut" },
	"track": { "springScale": 2.0, "height": -0.035, "strength": 2600.0, "geometry": "wishbone" },
	"race": { "springScale": 2.6, "height": -0.04, "strength": 3000.0, "geometry": "multilink" },
	"rally": { "springScale": 0.8, "height": 0.07, "travel": 0.2, "droop": 0.15, "strength": 4200.0, "mass": 40.0, "geometry": "trailing" },
	"drift": { "springScale": 1.9, "height": -0.03, "strength": 2800.0, "maxLock": 62.0 * DEG, "ackermann": 0.35, "geometry": "wishbone" },
}

## Curves of [travel, value] pairs, linearly interpolated (`curveAt`).
const GEOMETRY := {
	"strut": { "camber": [[-0.15, 1.3 * DEG], [0.0, 0.0], [0.2, -2.8 * DEG]], "toe": [[-0.15, -0.25 * DEG], [0.0, 0.0], [0.2, 0.4 * DEG]], "track": [[-0.15, -0.008], [0.0, 0.0], [0.2, -0.008]] },
	"wishbone": { "camber": [[-0.15, 2.0 * DEG], [0.0, 0.0], [0.2, -5.0 * DEG]], "toe": [[-0.15, -0.08 * DEG], [0.0, 0.0], [0.2, 0.1 * DEG]], "track": [[-0.15, -0.006], [0.0, 0.0], [0.2, -0.01]] },
	"multilink": { "camber": [[-0.15, 1.6 * DEG], [0.0, 0.0], [0.2, -3.5 * DEG]], "toe": [[-0.15, -0.15 * DEG], [0.0, 0.0], [0.2, 0.3 * DEG]], "track": [[-0.15, -0.004], [0.0, 0.0], [0.2, -0.006]] },
	"trailing": { "camber": [[-0.2, 0.8 * DEG], [0.0, 0.0], [0.3, -1.2 * DEG]], "toe": [[-0.2, -0.1 * DEG], [0.0, 0.0], [0.3, 0.2 * DEG]], "track": [[-0.2, -0.01], [0.0, 0.0], [0.3, -0.015]] },
}


static func part(id: String) -> Dictionary:
	return SimMath.deep_merge(_PART_DEFAULTS, _PART_PATCHES[id])


static func curve_at(curve: Array, x: float) -> float:
	if x <= curve[0][0]:
		return curve[0][1]
	for i in range(1, curve.size()):
		if x <= curve[i][0]:
			var a: Array = curve[i - 1]
			var b: Array = curve[i]
			return a[1] + (b[1] - a[1]) * (x - a[0]) / (b[0] - a[0])
	return curve[curve.size() - 1][1]


static func healthy_damage() -> Dictionary:
	var health := {}
	for c in COMPONENTS:
		health[c] = 1.0
	return { "health": health, "deformation": { "camber": 0.0, "toe": 0.0, "caster": 0.0, "position": { "x": 0.0, "y": 0.0, "z": 0.0 },
		"rideHeight": 0.0, "travelReduction": 0.0, "steeringCenter": 0.0 }, "fatigue": 0.0 }


## Factory setup for a car (`createSuspension`).
static func create_suspension(b: Dictionary, height := 0.0) -> Dictionary:
	var corners := []
	for i in 4:
		var front := i < 2
		var mass: float = b["mass"] * (b["frontWeight"] if front else 1.0 - b["frontWeight"]) / 2.0
		var rate: float = b["frontSpring"] if front else b["rearSpring"]
		var damping: float = 2.0 * sqrt(rate * maxf(100.0, mass - 35.0)) * b.get("damping", 0.6)
		corners.append({ "rideHeight": height, "springRate": rate, "preload": 0.0, "bump": damping * 0.65, "rebound": damping,
			"highSpeedBump": damping * 0.4, "highSpeedRebound": damping * 0.65,
			"camber": b.get("camber", (-1.0 if front else -0.8) * DEG), "toe": b.get("toe", (0.03 if front else 0.12) * DEG),
			"caster": b.get("caster", 6.0 * DEG) if front else 0.0,
			"compressionTravel": 0.09, "droopTravel": 0.06, "bumpStop": 0.02, "unsprungMass": 35.0, "trackOffset": 0.0 })
	var damage := []
	var alignment := []
	for i in 4:
		damage.append(healthy_damage())
		alignment.append({ "camber": 0.0, "toe": 0.0, "caster": 0.0 })
	return { "version": 2, "part": "stock", "setup": { "corners": corners, "frontARB": b.get("frontARB", 10000.0), "rearARB": b.get("rearARB", 7000.0),
		"maxLock": b.get("maxLock", 34.0 * DEG), "ackermann": 0.75, "steeringRatio": 16.0 }, "damage": damage, "alignment": alignment, "presets": {} }


## Impact damage to one corner (`damageCorner`).
static func damage_corner(saved: Dictionary, index: int, energy: float, direction: float) -> void:
	var d: Dictionary = saved["damage"][index]
	if not is_finite(energy) or energy <= 0.0:
		return
	var strength: float = part(saved["part"])["strength"]
	var stress := maxf(0.0, energy / strength - 0.35)
	if stress == 0.0:
		return
	var loss := minf(0.7, stress * 0.15)
	var sgn := -1.0 if direction < 0.0 else 1.0
	d["fatigue"] = SimMath.clamp_(d["fatigue"] + loss * 0.05, 0.0, 1.0)
	var health: Dictionary = d["health"]
	for key in COMPONENTS:
		health[key] = SimMath.clamp_(health[key] - loss * (1.5 if key == "tieRod" else (0.4 if key == "spring" else 1.0)), 0.0, 1.0)
	var f: Dictionary = d["deformation"]
	# Toe is semantic (positive = inward on either side): impacts bend it outward on both sides.
	f["toe"] = SimMath.clamp_(f["toe"] - loss * 0.12, -0.3, 0.3)
	f["camber"] = SimMath.clamp_(f["camber"] - loss * 0.08, -0.4, 0.4)
	f["caster"] = SimMath.clamp_(f["caster"] - loss * 0.03, -0.3, 0.3)
	f["position"]["z"] = SimMath.clamp_(f["position"]["z"] - loss * 0.04, -0.3, 0.3)
	f["position"]["x"] = SimMath.clamp_(f["position"]["x"] + sgn * loss * 0.012, -0.2, 0.2)
	f["rideHeight"] = SimMath.clamp_(f["rideHeight"] - loss * 0.015, -0.15, 0.0)
	f["travelReduction"] = SimMath.clamp_(f["travelReduction"] + loss * 0.015, 0.0, 0.15)
	f["steeringCenter"] = SimMath.clamp_(f["steeringCenter"] + sgn * loss * 0.025, -0.2, 0.2)
	saved["alignment"][index]["toe"] = SimMath.clamp_(saved["alignment"][index]["toe"] - loss * 0.003, -0.2, 0.2)
