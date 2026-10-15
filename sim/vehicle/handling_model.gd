class_name HandlingModel
extends RefCounted
## Engine-agnostic, deterministic vehicle handling: state, diagnostics, per-corner tires and forces,
## driven by `FourWheelDynamics`. Port of `ArcadeHandlingModel.ts`, mechanical path only: every car
## already runs through `physicalConfig()`, so the legacy arcade branch is not ported.

var config: Dictionary
var state := VehicleTypes.HandlingState.new()
var diagnostics := VehicleTypes.HandlingDiagnostics.new()
var mechanics: FourWheelDynamics
## Environmental grip; independent of the handling preset and kept across resets.
var surface_grip := 1.0
## Each corner's tire, set by the wheel/tire simulation. Kept across resets.
var tires: Array[VehicleTypes.CornerTire] = []
## Each corner's forces from the last step.
var corners: Array[VehicleTypes.CornerForces] = []


func _init(config_: Dictionary) -> void:
	config = HandlingPresets.physical_config(config_)
	mechanics = FourWheelDynamics.new(self)
	for id in VehicleTypes.CORNERS:
		tires.append(VehicleTypes.CornerTire.new())
		var forces := VehicleTypes.CornerForces.new()
		forces.corner = id
		corners.append(forces)


## Swap tuning live (preset change, part install). Motion state is kept.
func set_config(config_: Dictionary) -> void:
	config = HandlingPresets.physical_config(config_)


func reset() -> void:
	mechanics.reset()
	state = VehicleTypes.HandlingState.new()


## Feed the body's actual motion back in (after collisions, gravity on slopes, ...).
func sync_motion(vx: float, vy: float, yaw_rate: float) -> void:
	state.vx = vx
	state.vy = vy
	state.yaw_rate = yaw_rate


func step(dt: float, input: VehicleTypes.DriverInput, contact: VehicleTypes.AxleContact) -> void:
	mechanics.step(dt, input, contact)
