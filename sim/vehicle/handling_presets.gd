class_name HandlingPresets
## Handling configs as plain Dictionaries with the same shape and units as the TS
## `HandlingConfig` (`src/game/vehicles/handling/HandlingConfig.ts`), so they round-trip to JSON/saves.
## Only the Dalagan's tunes are ported so far.

const STOCK_MECHANICAL := {
	"engine": { "torqueNm": 215.0, "idleRpm": 850.0, "redlineRpm": 6500.0, "peakTorqueRpm": 3800.0, "inertia": 0.24,
		"gearRatios": [3.3, 2.05, 1.4, 1.03, 0.82], "reverseRatio": 3.2, "finalDrive": 3.9, "efficiency": 0.87,
		"clutchTorqueNm": 320.0, "shiftSeconds": 0.18 },
	"differential": { "type": "open", "lock": 0.0, "preloadNm": 0.0 },
	"wheel": { "radiusM": 0.3, "inertia": 1.3 },
	"tire": { "peakSlipRatio": 0.12, "loadExponent": 0.88, "relaxationSeconds": 0.035, "recoverySeconds": 0.22,
		"ambientC": 25.0, "optimalC": 75.0, "overheatC": 115.0, "heatCapacity": 18000.0, "coolingRate": 0.018, "wearPerJoule": 1.5e-9 },
	"suspension": { "frontSpring": 28000.0, "rearSpring": 24000.0, "damping": 0.75, "frontAntiRoll": 10000.0, "rearAntiRoll": 7000.0,
		"rideHeightOffsetM": 0.0, "camberDeg": -1.0, "toeDeg": 0.05, "casterDeg": 6.0 },
	"steering": { "roadAngleDeg": 34.0, "driftAngleDeg": 34.0, "rackRate": 7.0, "rackAcceleration": 22.0, "returnRate": 5.5,
		"gripLimitedLock": true, "gripLockSlip": 0.7, "gripLockSlipHighSpeed": 0.3, "gripLockMu": 0.85, "yawLimitGain": 4.0, "keyboardHighSpeedRate": 2.5 },
	"assistance": "standard", "tcs": "off", "esc": false, "abs": true,
}

const FWD_WORN_SEDAN := {
	"chassis": { "massKg": 1080.0, "wheelbaseM": 2.5, "frontWeight": 0.62, "cgHeightM": 0.52, "trackWidthM": 1.456, "yawInertiaScale": 1.1 },
	"steering": { "maxAngleDeg": 32.0, "minAngleDeg": 2.0, "fullLockLateralG": 1.25, "turnInSeconds": 0.2, "unwindSeconds": 0.12 },
	"drive": { "drivetrain": "FWD", "accelerationMps2": 3.8, "topSpeedKmh": 180.0, "reverseAccelerationMps2": 2.5, "reverseTopSpeedKmh": 25.0,
		"engineBrakingMps2": 1.2, "rollingResistanceMps2": 0.15, "aeroDrag": 0.00035 },
	"brakes": { "decelerationMps2": 8.0, "frontBias": 0.68 },
	"tires": { "frontGrip": 0.95, "rearGrip": 1.0, "frontPeakSlipDeg": 7.0, "rearPeakSlipDeg": 6.0, "frontLoadSensitivity": 0.3, "rearLoadSensitivity": 0.25 },
	"balance": { "understeer": 0.45, "rearSlideFalloff": 0.1, "weightTransfer": 0.6, "weightTransferRate": 5.0, "liftOffRotation": 0.08,
		"liftOffMinSpeedKmh": 35.0, "liftOffBuildRate": 3.0, "liftOffReleaseRate": 6.0 },
	"assists": { "traction": 0.35, "stability": 0.5, "stabilityThresholdDeg": 5.0 },
	"handbrake": { "enabled": true, "minEffectiveSpeedKmh": 18.0, "fullEffectSpeedKmh": 45.0, "rearGripMultiplier": 0.55,
		"frontGripMultiplier": 0.95, "rearBrakeMps2": 5.0, "engageSmoothing": 12.0, "releaseSmoothing": 8.0 },
	"lowSpeed": { "kinematicBelowKmh": 5.0, "dynamicAboveKmh": 12.0, "holdBelowKmh": 1.5, "reverseEngageBelowKmh": 3.0, "reverseDelaySeconds": 0.35 },
	"pedals": { "throttleRise": 6.0, "throttleFall": 8.0, "brakeRise": 7.0, "brakeFall": 10.0 },
}

const PRESETS := {
	"fwd_worn_sedan": { "config": FWD_WORN_SEDAN },
	"fwd_worn_sedan_drift": { "extends": "fwd_worn_sedan", "overrides": {
		"tires": { "rearGrip": 0.94 },
		"balance": { "understeer": 0.36, "rearSlideFalloff": 0.2, "liftOffRotation": 0.2 },
		"assists": { "stability": 0.15 },
		"handbrake": { "rearGripMultiplier": 0.38, "rearBrakeMps2": 6.5 },
	} },
}


static func resolve(id: String) -> Dictionary:
	var preset: Dictionary = PRESETS[id]
	if preset.has("config"):
		return (preset["config"] as Dictionary).duplicate(true)
	return SimMath.deep_merge(resolve(preset["extends"]), preset["overrides"])


## Port of `physicalConfig()` (suspensionConfig.ts): legacy presets migrate to the common
## drivetrain/tire model at the runtime boundary.
static func physical_config(config: Dictionary) -> Dictionary:
	if config.has("mechanical"):
		return config
	var p: Dictionary = STOCK_MECHANICAL.duplicate(true)
	var chassis: Dictionary = config["chassis"]
	var e: Dictionary = p["engine"]
	e["torqueNm"] = chassis["massKg"] * config["drive"]["accelerationMps2"] * p["wheel"]["radiusM"] \
		/ (e["gearRatios"][0] * e["finalDrive"] * e["efficiency"]) * 1.3
	e["clutchTorqueNm"] = e["torqueNm"] * 1.5
	p["steering"]["roadAngleDeg"] = config["steering"]["maxAngleDeg"]
	p["steering"]["driftAngleDeg"] = config["steering"]["maxAngleDeg"]
	p["suspension"]["frontSpring"] = chassis["massKg"] * 25.0
	p["suspension"]["rearSpring"] = chassis["massKg"] * 20.0
	p["suspension"]["frontAntiRoll"] = 8500.0
	p["suspension"]["rearAntiRoll"] = 4500.0
	# The preset's stability assist becomes ESC on the mechanical car (see the TS comment).
	p["esc"] = config["assists"]["stability"] > 0.0
	var out := config.duplicate(true)
	out["mechanical"] = p
	return out


## Port of `suspensionBaseline()`.
static func suspension_baseline(config: Dictionary) -> Dictionary:
	var c := physical_config(config)
	var p: Dictionary = c["mechanical"]
	var s: Dictionary = p["suspension"]
	return { "mass": c["chassis"]["massKg"], "frontWeight": c["chassis"]["frontWeight"], "wheelbase": c["chassis"]["wheelbaseM"],
		"track": c["chassis"]["trackWidthM"], "cgHeight": c["chassis"]["cgHeightM"], "frontSpring": s["frontSpring"], "rearSpring": s["rearSpring"],
		"radius": p["wheel"]["radiusM"], "frontARB": s["frontAntiRoll"], "rearARB": s["rearAntiRoll"], "damping": s["damping"],
		"camber": s["camberDeg"] * SimMath.DEG, "toe": s["toeDeg"] * SimMath.DEG, "caster": s["casterDeg"] * SimMath.DEG,
		"maxLock": p["steering"]["roadAngleDeg"] * SimMath.DEG }
