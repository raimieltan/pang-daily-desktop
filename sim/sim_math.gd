class_name SimMath
## Helpers with the exact semantics of the TS sim (`DriverAssistance.ts`), so ported formulas match
## the original bit for bit. Godot's built-ins differ at the edges (e.g. clampf with min > max).

const G := 9.81
const DEG := PI / 180.0


static func clamp_(x: float, a: float, b: float) -> float:
	return maxf(a, minf(b, x))


static func move_toward_(x: float, target: float, amount: float) -> float:
	return x + clamp_(target - x, -amount, amount)


static func smoothstep_(a: float, b: float, x: float) -> float:
	var t := clamp_((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func lerp_(a: float, b: float, t: float) -> float:
	return a + (b - a) * t


## JS Math.sign: 0 for 0.
static func sign_(x: float) -> float:
	return 1.0 if x > 0.0 else (-1.0 if x < 0.0 else 0.0)


## Recursive merge of plain Dictionaries; arrays and scalars in `overrides` replace.
static func deep_merge(base: Dictionary, overrides: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for key in overrides:
		var value = overrides[key]
		if value is Dictionary and out.get(key) is Dictionary:
			out[key] = deep_merge(out[key], value)
		else:
			out[key] = value.duplicate(true) if (value is Dictionary or value is Array) else value
	return out
