// Shared screentone helpers (docs/ART_DIRECTION.md §2). Screen-space, so tone keeps a constant
// printed size at any distance. `coverage` is the share of ink (0 = paper, 1 = solid ink).

const float TONE_PITCH = 5.0;      // px between dots / hatch lines at 1080p (scale with tone_res_scale)
const float SQRT_HALF = 0.70710678;

vec2 tone_rotate(vec2 p) {
	return vec2(p.x + p.y, p.y - p.x) * SQRT_HALF;
}

float tone_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// 1 = ink, 0 = paper. Dot screen at 45°; past half coverage it inverts to paper dots on ink.
float tone_dots(vec2 frag, float coverage, float pitch) {
	vec2 q = tone_rotate(frag) / pitch;
	vec2 cell = fract(q) - 0.5;
	float d = length(cell) * pitch;
	float aa = 0.7;
	if (coverage <= 0.5) {
		float r = pitch * sqrt(coverage / 3.14159);
		return 1.0 - smoothstep(r - aa, r + aa, d);
	}
	float r = pitch * sqrt((1.0 - coverage) / 3.14159);
	return smoothstep(r - aa, r + aa, d);
}

// Parallel 45° lines whose thickness tracks coverage; cross-hatch joins in past 55%.
float tone_hatch(vec2 frag, float coverage, float pitch) {
	vec2 q = tone_rotate(frag) / pitch;
	float a = abs(fract(q.x) - 0.5) * pitch;
	float w = coverage * pitch * 0.5;
	// Locals must not share names with shader uniforms (e.g. `ink`): Godot rewrites them to uniforms.
	float lines = 1.0 - smoothstep(w - 0.6, w + 0.6, a);
	if (coverage > 0.55) {
		float b = abs(fract(q.y) - 0.5) * pitch;
		float w2 = (coverage - 0.55) * pitch * 0.9;
		lines = max(lines, 1.0 - smoothstep(w2 - 0.6, w2 + 0.6, b));
	}
	return lines;
}

// Random stipple (gravel, dirt).
float tone_stipple(vec2 frag, float coverage) {
	return step(tone_hash(floor(frag / 1.5)), coverage);
}

// Keeps printed tone the same size relative to the frame at any resolution.
float tone_res_scale(vec2 viewport) {
	return max(viewport.y / 1080.0, 0.5);
}

// pattern: 0 dots, 1 hatch, 2 stipple.
float tone_ink(vec2 frag, float coverage, float pattern, float pitch_scale) {
	float pitch = TONE_PITCH * pitch_scale;
	if (coverage < 0.06) return 0.0;
	if (coverage > 0.93) return 1.0;
	if (pattern < 0.5) return tone_dots(frag, coverage, pitch);
	if (pattern < 1.5) return tone_hatch(frag, coverage, pitch);
	return tone_stipple(frag, coverage);
}

// Hard light bands from N·L × shadow: 1 lit, 0.55 half, 0.2 turned away, 0 cast shadow.
float tone_light_band(float ndotl, float attenuation) {
	float lit = ndotl * attenuation;
	if (attenuation < 0.35) return 0.0;
	if (lit > 0.45) return 1.0;
	if (lit > 0.18) return 0.55;
	return 0.2;
}
