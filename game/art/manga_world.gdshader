shader_type spatial;
// World surfaces: paper + ink only. Light picks a band, material darkness offsets it, and the
// result resolves to screen-space screentone (docs/ART_DIRECTION.md §2).
render_mode diffuse_lambert, specular_disabled, ambient_light_disabled;

#include "res://game/art/manga_tone.gdshaderinc"

uniform vec3 paper : source_color = vec3(0.949, 0.937, 0.902);
uniform vec3 ink : source_color = vec3(0.078);
/// Material darkness in full light (0 = paper-white, 1 = ink).
uniform float darkness : hint_range(0.0, 1.0) = 0.2;
/// How much darker each step away from the light makes it.
uniform float shade : hint_range(0.0, 1.0) = 0.45;
/// 0 dots, 1 hatch, 2 stipple.
uniform float pattern = 0.0;
uniform float pitch_scale = 1.0;
/// Steep faces switch to hatching (rock cuts) when > 0.
uniform float slope_hatch : hint_range(0.0, 1.0) = 0.0;
/// Road shading: x = lateral metres, y = distance; paints lines as paper.
uniform bool road_markings = false;
uniform float lane_half_width = 3.0;
uniform float start_line = -1.0;
uniform float finish_line = -1.0;

varying float v_dark;
varying float v_pattern;
varying vec3 v_world_normal;
varying vec2 v_uv;

float band(float x, float center, float half_w) {
	float aa = fwidth(x) * 0.75;
	return 1.0 - smoothstep(half_w - aa, half_w + aa, abs(x - center));
}

void vertex() {
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_uv = UV;
}

void fragment() {
	float dark = darkness;
	float pat = pattern;
	float steep = smoothstep(0.5, 0.8, 1.0 - v_world_normal.y) * slope_hatch;
	if (steep > 0.5) { pat = 1.0; dark += 0.15; }
	if (road_markings) {
		vec2 p = v_uv;
		float edge = band(p.x, -lane_half_width + 0.15, 0.075) + band(p.x, lane_half_width - 0.15, 0.075);
		float centre = band(p.x, -0.1, 0.06) + band(p.x, 0.1, 0.06);
		float start = start_line > 0.0 ? band(p.y, start_line, 0.25) * step(abs(p.x), lane_half_width) : 0.0;
		// Worn racing line: a slightly darker streak in each lane.
		float wear = exp(-pow((abs(p.x) - 1.4) / 0.6, 2.0));
		dark += wear * 0.08;
		float paint = clamp(edge + centre + start, 0.0, 1.0);
		if (finish_line > 0.0 && abs(p.y - finish_line) < 1.2 && abs(p.x) < lane_half_width) {
			float checker = mod(floor(p.x / 0.6) + floor(p.y / 0.6), 2.0);
			dark = checker > 0.5 ? 1.0 : 0.0;
		} else {
			dark = mix(dark, 0.0, paint);
		}
	}
	v_dark = dark;
	v_pattern = pat;
	ALBEDO = vec3(1.0);
}

void light() {
	float ndotl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float lit = tone_light_band(ndotl, ATTENUATION);
	float coverage = clamp(v_dark + (1.0 - lit) * shade, 0.0, 1.0);
	// Cast shadow: deep tone, solid ink for already-dark materials.
	if (lit == 0.0) coverage = max(coverage, 0.78);
	float ink_amount = tone_ink(FRAGCOORD.xy, coverage, v_pattern, pitch_scale);
	DIFFUSE_LIGHT = mix(paper, ink, ink_amount);
}
