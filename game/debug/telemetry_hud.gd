class_name TelemetryHud
extends CanvasLayer
## Driving telemetry: enough to explain bad behaviour (speed, powertrain, per-corner load/slip/grip).

var car: CarBody
var _label: Label
var _speedo: Label


func _ready() -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.72)
	style.set_content_margin_all(10.0)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(12, 12)
	add_child(panel)
	_label = Label.new()
	var font := SystemFont.new()
	font.font_names = ["Menlo", "Consolas", "monospace"]
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", 13)
	panel.add_child(_label)

	_speedo = Label.new()
	_speedo.add_theme_font_size_override("font_size", 44)
	_speedo.add_theme_color_override("font_outline_color", Color.BLACK)
	_speedo.add_theme_constant_override("outline_size", 8)
	_speedo.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_speedo.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_speedo.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_speedo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_speedo.position = Vector2(-24, -24)
	add_child(_speedo)


func _process(_delta: float) -> void:
	if car == null or car.model == null:
		return
	var m := car.model
	var mech := m.mechanics
	var d := m.diagnostics
	var s := m.state
	var a := mech.assistance
	var gear := "R" if s.reversing else str(mech.gear)
	_speedo.text = "%d km/h  %s\n%d rpm" % [absf(car.speed_kmh()), gear, mech.engine_rpm]
	var lines: PackedStringArray = []
	lines.append("PANG DAILY                    [T] tune [Y] tires [N] night [R] reset [H] hud")
	lines.append("tune %-22s tires %s   device %s" % [car.preset, car.tire_product, car.last_input.device])
	lines.append("thr %.2f→%.2f  brk %.2f  hb %.2f  clutch %.2f  axle %5.0f Nm  tcs-cut %.2f" % [
		a.throttle_raw, s.throttle, s.brake, s.handbrake, mech.clutch, mech.axle_torque, d.traction_cut])
	lines.append("steer in %+.2f  rack %+5.1f°  max %4.1f°  drift-factor %.2f" % [
		a.steering_input, rad_to_deg(s.steer_angle), rad_to_deg(d.max_steer_angle), a.drift_factor])
	lines.append("yaw %+6.1f°/s  want %+6.1f°/s  body slip %+5.1f°  US %+.2f  %s%s" % [
		rad_to_deg(s.yaw_rate), rad_to_deg(d.kinematic_yaw_rate), rad_to_deg(d.body_slip), d.understeer,
		"DRIFT " if mech.detector.drifting else "", "HELD" if d.held else ""])
	lines.append("grip use  front %.2f  rear %.2f" % [d.front_grip_use, d.rear_grip_use])
	lines.append("")
	lines.append("      load N  slip°   κ      grip   temp°C  susp mm  status")
	for i in 4:
		var w := mech.wheels[i]
		var c := car.solver.corners[i]
		var flags := ("L" if w.is_locked else "") + ("S" if w.is_spinning else "") + ("~" if w.is_sliding else "")
		lines.append("%s  %6.0f  %+5.1f  %+5.2f  %5.2f  %5.1f   %+5.1f   %s %s" % [
			VehicleTypes.CORNERS[i], w.vertical_load, rad_to_deg(w.slip_angle), w.slip_ratio,
			_grip(w), w.temperature, c.compression * 1000.0, c.status, flags])
	_label.text = "\n".join(lines)


static func _grip(w: FourWheelDynamics.WheelState) -> float:
	if w.max_lateral_grip <= 0.0:
		return 0.0
	return Vector2(w.longitudinal_force, w.lateral_force).length() / w.max_lateral_grip
