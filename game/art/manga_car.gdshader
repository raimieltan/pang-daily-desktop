shader_type spatial;
// Car paint: flat cel color with one hue-shifted shadow band, ink hatching over the shadow and a
// paper-white glint instead of reflections (docs/ART_DIRECTION.md §3).
render_mode diffuse_lambert, specular_disabled, ambient_light_disabled;

#include "res://game/art/manga_tone.gdshaderinc"

uniform vec3 albedo : source_color = vec3(0.95, 0.75, 0.1);
/// Shadow band = albedo × this tint (cool shift, never grey).
uniform vec3 shadow_tint : source_color = vec3(0.8, 0.62, 0.66);
uniform float hatch_amount : hint_range(0.0, 1.0) = 0.35;
/// Glint size: higher = smaller, sharper.
uniform float glint_power = 0.985;
uniform bool glint = true;
/// Emissive lamps keep their color in shadow.
uniform bool lamp = false;
uniform vec3 paper : source_color = vec3(0.949, 0.937, 0.902);

void fragment() {
	ALBEDO = vec3(1.0);
}

void light() {
	float ndotl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float lit = ndotl * ATTENUATION;
	vec3 color = albedo;
	if (!lamp && lit < 0.32) {
		color = albedo * shadow_tint;
		float hatch = tone_hatch(FRAGCOORD.xy, hatch_amount * (lit < 0.05 ? 0.8 : 0.45), TONE_PITCH * 1.1);
		color = mix(color, vec3(0.06), hatch * 0.85);
	}
	if (glint && lit > 0.3) {
		vec3 h = normalize(LIGHT + VIEW);
		if (dot(NORMAL, h) > glint_power) color = paper;
	}
	DIFFUSE_LIGHT = color;
}
