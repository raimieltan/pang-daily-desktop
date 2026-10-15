class_name VehicleTypes
## Small typed records shared by the handling model, its adapter and tests.
## Mirrors the TS types in `ArcadeHandlingModel.ts`. Corner order is always FL, FR, RL, RR.

const CORNERS := ["FL", "FR", "RL", "RR"]


## Normalized driver intent. Device mapping and stick smoothing happen upstream.
class DriverInput:
	var throttle := 0.0
	var brake := 0.0
	## -1 (left) .. 1 (right)
	var steer := 0.0
	var handbrake := 0.0
	var clutch := 0.0
	## False disables propulsion in either gear while preserving braking.
	var engine_available := true
	## "keyboard" | "controller" | "wheel" | "ai"
	var device := "ai"

	static func make(throttle_: float, brake_: float, steer_: float, handbrake_ := 0.0, device_ := "ai") -> DriverInput:
		var i := DriverInput.new()
		i.throttle = throttle_
		i.brake = brake_
		i.steer = steer_
		i.handbrake = handbrake_
		i.device = device_
		return i


## What one corner's tire can do right now. Neutral values reproduce the plain model.
class CornerTire:
	var surface_grip := 1.0
	var pressure_psi := 32.0
	var grip := 1.0
	var longitudinal_grip := 1.0
	var slip_scale := 1.0
	var rolling_resistance := 0.0
	var installed := true
	var raised := false


## Per-corner result of the last step (N, wheel frame), for wear, telemetry and tests.
class CornerForces:
	var corner := ""
	var grounded := false
	var normal_load_n := 0.0
	var fx := 0.0
	var fy := 0.0
	var drive_n := 0.0
	var brake_n := 0.0
	var rolling_n := 0.0
	var cap_n := 0.0
	var slip_angle := 0.0
	var slip_ratio := 0.0
	var wheel_speed := 0.0
	var steer_angle := 0.0


## Ground contact handed to the model by the physics layer. `wheels`, when non-empty, is each
## corner's own contact and overrides the axle shares. `suspension` holds the solver's corners.
class AxleContact:
	var front := 0.0
	var rear := 0.0
	var wheels: Array[bool] = []
	var suspension: Array = []

	static func grounded() -> AxleContact:
		var c := AxleContact.new()
		c.front = 1.0
		c.rear = 1.0
		return c


class HandlingState:
	## Body frame: +x forward, +y right, yaw rate positive = turning right.
	var vx := 0.0
	var vy := 0.0
	var yaw_rate := 0.0
	var steer_angle := 0.0
	var throttle := 0.0
	var brake := 0.0
	var reversing := false
	var load_shift := 0.0
	var lateral_load_shift := 0.0
	var lift_off := 0.0
	var handbrake := 0.0
	var long_accel := 0.0
	var lat_accel := 0.0


class HandlingDiagnostics:
	var max_steer_angle := 0.0
	var kinematic_yaw_rate := 0.0
	var understeer := 0.0
	var body_slip := 0.0
	var front_slip := 0.0
	var rear_slip := 0.0
	var front_grip_use := 0.0
	var rear_grip_use := 0.0
	var traction_cut := 0.0
	var stability_yaw := 0.0
	var handbrake_effect := 0.0
	var held := false
