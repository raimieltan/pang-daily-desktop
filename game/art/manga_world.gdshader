shader_type spatial;
// World surfaces output plain lit GRAYSCALE; the manga compositor (manga_post.glsl) turns it into
// ink / screentone / paper bands. Monochrome by design, the car is the only color on the page.
//  - Moon/sun: albedo gray × (ambient + N·L × shadow).
//  - Lamps (spot/omni): a hard-edged paper-white core, plus a smooth falloff outside it that the
//    tone ramp bands into screentone. No soft colored glow.
render_mode diffuse_lambert, specular_disabled, ambient_light_disabled;

global uniform float manga_night;
global uniform float manga_ambient;

group_uniforms surface;
/// Albedo gray (0 = ink, 1 = paper).
uniform float lit_value : hint_range(0.0, 1.0) = 0.7;
/// Steep faces get this much darker (rock cuts read darker than the hillside).
uniform float slope_darken : hint_range(0.0, 1.0) = 0.0;
/// Daytime haze: far surfaces drift toward this gray (night: ignored, distance stays dark).
uniform float far_value : hint_range(0.0, 1.0) = 0.85;
uniform float near_detail = 40.0;
uniform float far_detail = 400.0;
group_uniforms;

group_uniforms lamps;
/// Lamp intensity above which the pool is hard paper white.
uniform float lamp_core = 0.32;
/// How much light outside the core still reaches the tone ramp.
uniform float lamp_falloff = 0.55;
group_uniforms;

group_uniforms road;
/// Road shading: UV x = lateral metres, y = distance; paints markings as paper.
uniform bool road_markings = false;
uniform float lane_half_width = 3.0;
uniform float start_line = -1.0;
uniform float finish_line = -1.0;
group_uniforms;

group_uniforms pattern;
/// 0 none, 1 chevron sign (UV), 2 delineator band (UV).
uniform int pattern_mode = 0;
/// Chevron direction: +1 points to the board's +U (driver's right), −1 left.
uniform float pattern_dir = 1.0;
group_uniforms;

varying float v_albedo;
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
	float a = lit_value;
	a *= 1.0 - slope_darken * smoothstep(0.5, 0.85, 1.0 - v_world_normal.y);
	if (road_markings) {
		vec2 p = v_uv;
		float edge = band(p.x, -lane_half_width + 0.15, 0.075) + band(p.x, lane_half_width - 0.15, 0.075);
		float centre = band(p.x, -0.1, 0.06) + band(p.x, 0.1, 0.06);
		float start = start_line > 0.0 ? band(p.y, start_line, 0.25) * step(abs(p.x), lane_half_width) : 0.0;
		a *= 1.0 - exp(-pow((abs(p.x) - 1.4) / 0.6, 2.0)) * 0.12;   // worn racing line
		a = mix(a, 0.95, clamp(edge + centre + start, 0.0, 1.0));
		if (finish_line > 0.0 && abs(p.y - finish_line) < 1.2 && abs(p.x) < lane_half_width) {
			a = mod(floor(p.x / 0.6) + floor(p.y / 0.6), 2.0) > 0.5 ? 0.02 : 0.95;
		}
	}
	if (pattern_mode == 1) {
		// Chevron: white board, black arrowheads pointing +U.
		vec2 q = v_uv - 0.5;
		float chev = abs(q.y) * 1.2 - q.x * pattern_dir;
		a = (fract(chev * 2.2) < 0.5 && abs(q.y) < 0.42 && abs(q.x) < 0.46) ? 0.03 : 0.95;
	} else if (pattern_mode == 2) {
		a = abs(v_uv.y - 0.2) < 0.08 ? 0.03 : 0.95;
	}
	v_albedo = a;
	v_dist = length(VERTEX);
	ALBEDO = vec3(1.0);
}

void light() {
	float ndotl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	if (LIGHT_IS_DIRECTIONAL) {
		float energy = dot(LIGHT_COLOR, vec3(0.2126, 0.7152, 0.0722));
		float v = v_albedo * (manga_ambient + ndotl * ATTENUATION * energy);
		// Day: far surfaces haze toward far_value. Night: distance just goes dark.
		float far_t = smoothstep(near_detail, far_detail, v_dist) * (1.0 - manga_night);
		v = mix(v, far_value, far_t * 0.8);
		DIFFUSE_LIGHT = vec3(v);
	} else {
		float peak = max(LIGHT_COLOR.r, max(LIGHT_COLOR.g, LIGHT_COLOR.b));
		float i = ATTENUATION * peak * (0.45 + 0.55 * ndotl);
		float core = step(lamp_core, i);
		// Paper inside the cone whatever the albedo; outside, a falloff for the ramp to band.
		DIFFUSE_LIGHT += vec3(core * 1.1 + (1.0 - core) * i * v_albedo * lamp_falloff * 2.0);
	}
}
