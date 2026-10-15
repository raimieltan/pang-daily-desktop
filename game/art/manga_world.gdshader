shader_type spatial;
// World surfaces: a grayscale value layer with screentone printed over it (docs/ART_DIRECTION.md §2).
// Light picks a hard band, material sets the gray and tone, distance lightens both (grayscale
// atmospheric perspective) so the foreground reads strongest. Monochrome by design: the only
// color that reaches the world is from positional lights (car lamps), added on top.
render_mode diffuse_lambert, specular_disabled, ambient_light_disabled;

#include "res://game/art/manga_tone.gdshaderinc"

global uniform float manga_night;
global uniform float manga_tone_contrast;
global uniform float manga_tone_density;

uniform vec3 paper : source_color = vec3(0.953, 0.937, 0.898);
uniform vec3 ink : source_color = vec3(0.075, 0.072, 0.07);
/// Neutral multiplier on the gray (road: slightly cool; most of the world: 1).
uniform vec3 tint : source_color = vec3(1.0);
/// Gray value in full light / in shadow (0 = ink, 1 = paper).
uniform float lit_value : hint_range(0.0, 1.0) = 0.85;
uniform float shadow_value : hint_range(0.0, 1.0) = 0.5;
/// Screentone coverage in full light, and how much more it gets per step away from the light.
uniform float darkness : hint_range(0.0, 1.0) = 0.2;
uniform float shade : hint_range(0.0, 1.0) = 0.35;
/// 0 dots, 1 hatch, 2 stipple. `shadow_pattern` < 0 keeps `pattern` in shadow.
uniform float pattern = 0.0;
uniform float shadow_pattern = -1.0;
/// How dark the printed tone is (1 = ink dots; lower = gray dots).
uniform float tone_contrast : hint_range(0.0, 1.0) = 0.8;
uniform float pitch_scale = 1.0;
/// Steep faces switch to hatching (rock cuts) when > 0.
uniform float slope_hatch : hint_range(0.0, 1.0) = 0.0;
/// Distance range over which tone thins and value drifts to `far_value`.
uniform float near_detail = 30.0;
uniform float far_detail = 260.0;
uniform float far_value : hint_range(0.0, 1.0) = 0.86;
/// Road shading: UV x = lateral metres, y = distance; paints markings as paper.
uniform bool road_markings = false;
uniform float lane_half_width = 3.0;
uniform float start_line = -1.0;
uniform float finish_line = -1.0;

varying float v_dark;
varying float v_pattern;
varying float v_paint;
varying float v_dist;
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
	float paint = 0.0;
	float steep = smoothstep(0.5, 0.8, 1.0 - v_world_normal.y) * slope_hatch;
	if (steep > 0.5) { pat = 1.0; dark += 0.12; }
	if (road_markings) {
		vec2 p = v_uv;
		float edge = band(p.x, -lane_half_width + 0.15, 0.075) + band(p.x, lane_half_width - 0.15, 0.075);
		float centre = band(p.x, -0.1, 0.06) + band(p.x, 0.1, 0.06);
		float start = start_line > 0.0 ? band(p.y, start_line, 0.25) * step(abs(p.x), lane_half_width) : 0.0;
		// Worn racing line: slightly denser tone in each lane.
		dark += exp(-pow((abs(p.x) - 1.4) / 0.6, 2.0)) * 0.08;
		paint = clamp(edge + centre + start, 0.0, 1.0);
		if (finish_line > 0.0 && abs(p.y - finish_line) < 1.2 && abs(p.x) < lane_half_width) {
			paint = mod(floor(p.x / 0.6) + floor(p.y / 0.6), 2.0) > 0.5 ? -1.0 : 1.0;
		}
	}
	v_dark = dark;
	v_pattern = pat;
	v_paint = paint;
	v_dist = length(VERTEX);
	ALBEDO = vec3(1.0);
}

void light() {
	float ndotl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	if (LIGHT_IS_DIRECTIONAL) {
		float lit = tone_light_band(ndotl, ATTENUATION);
		float far_t = smoothstep(near_detail, far_detail, v_dist);
		float value = mix(shadow_value, lit_value, lit);
		float coverage = v_dark + (1.0 - lit) * shade;
		float pat = v_pattern;
		// Cast shadows: denser tone, directional hatching where the material asks for it.
		if (lit == 0.0) {
			coverage = max(coverage, 0.5);
			if (shadow_pattern >= 0.0) pat = shadow_pattern;
		}
		// Distance: thinner tone, paler value (foreground strongest, background lightest).
		coverage *= mix(1.0, 0.25, far_t);
		value = mix(value, far_value, far_t * 0.85);
		float contrast = tone_contrast * manga_tone_contrast * mix(1.0, 0.45, far_t);
		float pitch = pitch_scale * manga_tone_density * tone_res_scale(VIEWPORT_SIZE);
		float dots = tone_ink(FRAGCOORD.xy, clamp(coverage, 0.0, 1.0), pat, pitch);
		vec3 gray = mix(ink, paper, value) * tint;
		vec3 col = mix(gray, ink, dots * contrast);
		// Road paint stays paper (checkers: ink squares).
		if (v_paint > 0.0) col = mix(col, paper * mix(1.0, 0.72, 1.0 - lit), v_paint);
		if (v_paint < 0.0) col = ink;
		// Night: the page goes dark; lamps (positional lights) draw on top.
		col = mix(col, col * 0.13 + ink * 0.25, manga_night);
		DIFFUSE_LIGHT = col;
	} else {
		// Car lamps: hard-banded colored pools on the monochrome world.
		// Band on energy × falloff (LIGHT_COLOR carries the energy); mostly ignore N·L because
		// headlight beams hit the road at grazing angles.
		float peak = max(LIGHT_COLOR.r, max(LIGHT_COLOR.g, LIGHT_COLOR.b));
		float i = ATTENUATION * peak * (0.45 + 0.55 * ndotl);
		float banded = floor(min(i, 1.0) * 3.0 + 0.35) / 3.0;
		DIFFUSE_LIGHT += LIGHT_COLOR / max(peak, 0.001) * banded * 0.6;
	}
}
