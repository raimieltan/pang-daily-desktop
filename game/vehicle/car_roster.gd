class_name CarRoster
extends RefCounted
## The cars the player can drive: body, tune, and the lines printed on the garage page.
## `id` keys time-attack records (with the tune), so keep ids stable once shipped.

const CARS := [
	{ "id": "dalagan_gsr", "name": "DALAGAN GSR", "drive": "AWD",
		"model": "res://assets/vehicles/dalagan_evo/dalagan_evo_modular.glb", "preset": "awd_gsr",
		"spec": "TURBO FOUR  ·  1,260 KG", "blurb": "RALLY-BRED GRIP. PUTS IT DOWN OUT OF EVERY HAIRPIN." },
	{ "id": "silak_box", "name": "SILAK BOX", "drive": "RWD",
		"model": "res://assets/vehicles/lancer/lancer_box_1983_modular.glb", "preset": "rwd_box_turbo",
		"spec": "TURBO FOUR  ·  1,090 KG", "blurb": "LIGHT '83 BOX SEDAN. THE TAIL STEPS OUT IF YOU ASK." },
	{ "id": "eg_hatch", "name": "EG HATCH", "drive": "FWD",
		"model": "res://assets/vehicles/civic_eg/civic_eg_modular.glb", "preset": "fwd_sport_hatch",
		"spec": "HIGH-REV FOUR  ·  1,060 KG", "blurb": "FEATHERWEIGHT HATCH. CARRY SPEED, NEVER LIFT." },
	{ "id": "civic_fd", "name": "CIVIC FD", "drive": "FWD",
		"model": "res://assets/vehicles/civic-fd/civic_fd_2007_modular.glb", "preset": "fwd_sport_hatch",
		"spec": "HIGH-REV FOUR  ·  1,060 KG", "blurb": "SHARP SEDAN WITH A PLANTED NOSE." },
]


static func get_car(id: String) -> Dictionary:
	for c in CARS:
		if c["id"] == id:
			return c
	return CARS[0]
