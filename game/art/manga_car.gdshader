shader_type spatial;
// Car materials: the color on the page (docs/ART_DIRECTION.md §3). Hard-banded illustration
// shading: warm highlight on top panels, body color, a darker warmer shadow, and a deep-shadow band
// with fine hatching. Glass gets diagonal reflection streaks, metal a hard dark band, lamps a glow.
render_mode diffuse_lambert, specular_disabled, ambient_light_disabled;

#include "res://game/art/manga_tone.gdshaderinc"

global uniform float manga_night;

/// 0 paint, 1 glass, 2 lamp, 3 rubber/trim, 4 metal.
uniform int kind = 0;
uniform vec3 albedo : source_color = vec3(0.95, 0.75, 0.1);
/// Shadow = albedo × shadow_mul, pushed warm: darker and warmer, never grey.
uniform vec3 shadow_mul : source_color = vec3(0.84, 0.64, 0.5);
uniform vec3 warm_shift : source_color = vec3(0.03, 0.0, 0.0);
/// How far the top-facing highlight band moves toward warm paper.
uniform float highlight : hint_range(0.0, 1.0) = 0.38;
uniform float hatch_amount : hint_range(0.0, 1.0) = 0.3;
uniform float glint_power = 0.985;
uniform bool glint = true;
/// Lamps: 0 off .. 1 fully lit (brake). Driven from the car state.
uniform float glow : hint_range(0.0, 2.0) = 0.0;
uniform vec3 paper : source_color = vec3(0.953, 0.937, 0.898);
uniform vec3 ink_color : source_color = vec3(0.06, 0.058, 0.056);

varying float v_up;
varying vec3 v_view_pos;

void vertex() {
	v_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}

void fragment() {
	v_view_pos = VERTEX;
	ALBEDO = vec3(1.0);
	if (kind == 2) {
		// Lamps glow by state, so the color reads even in shadow and at night.
		EMISSION = albedo * glow * 0.9;
	}
}

vec3 paint_shade(float lit, float up, vec3 n, vec3 l, vec3 v, vec2 frag, vec2 viewport) {
	vec3 shadow = albedo * shadow_mul + warm_shift;
	vec3 col;
	if (lit > 0.6 && up > 0.55) col = mix(albedo, paper * vec3(1.0, 0.97, 0.9), highlight);   // top panels catch the sky
	else if (lit > 0.12) col = albedo;
	else if (lit > 0.02) col = shadow;
	else {
		col = shadow * 0.8;
		float h = tone_hatch(frag, hatch_amount, TONE_PITCH * 0.9 * tone_res_scale(viewport));
		col = mix(col, ink_color, h * 0.8);
	}
	if (glint && lit > 0.3 && dot(n, normalize(l + v)) > glint_power) col = paper;
	// Illustrated edge highlight: a thin light line where lit panels turn away from the viewer.
	float rim = 1.0 - clamp(dot(n, v), 0.0, 1.0);
	if (lit > 0.3 && rim > 0.8 && up > 0.1) col = mix(col, paper, 0.45);
	return col;
}

void light() {
	float ndotl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	if (!LIGHT_IS_DIRECTIONAL) {
		// Lamps of other cars (or our own) light the body a little.
		DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * ndotl * 0.35;
	} else {
		// Wrap the light a little so panels facing away from the sun keep the body color.
		float lit = clamp(dot(NORMAL, LIGHT) * 0.6 + 0.4, 0.0, 1.0) * ATTENUATION;
		vec3 col;
		if (kind == 1) {
			// Glass: dark cool tone, lighter toward the roofline, two diagonal reflection streaks.
			col = mix(vec3(0.1, 0.11, 0.14), vec3(0.32, 0.35, 0.42), clamp(v_up, 0.0, 1.0));
			float s = fract((v_view_pos.x * 0.9 + v_view_pos.y * 1.4) * 0.55);
			float streak = step(0.08, s) * step(s, 0.2) + step(0.3, s) * step(s, 0.34);
			col = mix(col, paper, streak * 0.85);
		} else if (kind == 2) {
			col = mix(albedo * 0.55, albedo, step(0.3, lit));
		} else if (kind == 3) {
			col = mix(vec3(0.07), vec3(0.17), step(0.35, lit));
		} else if (kind == 4) {
			// Manga chrome: bright with a hard dark horizon band.
			col = mix(albedo, paper, 0.3);
			if (v_up > -0.15 && v_up < 0.25) col = vec3(0.18);
			if (lit < 0.2) col *= 0.6;
		} else {
			col = paint_shade(lit, v_up, NORMAL, LIGHT, VIEW, FRAGCOORD.xy, VIEWPORT_SIZE);
		}
		// Night: the car keeps its color, but darker; lamps and headlight bounce carry it.
		col = mix(col, col * 0.35, manga_night * (kind == 2 ? 0.0 : 1.0));
		DIFFUSE_LIGHT = col;
	}
}
