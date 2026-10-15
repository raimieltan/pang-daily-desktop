shader_type spatial;
// Tire smoke as manga clouds: paper puffs with a lumpy ink contour and a toned shadow side,
// cut out (no soft alpha), shrinking away as the particle ages (COLOR.a from the color ramp).
render_mode unshaded, cull_disabled, shadows_disabled;

#include "res://game/art/manga_tone.gdshaderinc"

global uniform float manga_night;
uniform vec3 paper : source_color = vec3(0.953, 0.937, 0.898);
uniform vec3 ink : source_color = vec3(0.075, 0.072, 0.07);

varying float v_seed;

void vertex() {
	// Billboard, keeping the particle's scale.
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(s, 0, 0, 0), vec4(0, s, 0, 0), vec4(0, 0, s, 0), vec4(0, 0, 0, 1));
	v_seed = float(INSTANCE_ID) * 1.618;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float life = COLOR.a;
	float edge = (0.72 + 0.12 * sin(ang * 5.0 + v_seed * 3.1) + 0.06 * sin(ang * 9.0 + v_seed)) * mix(0.35, 1.0, life);
	if (r > edge) discard;
	float line = 0.06 + 0.05 * life;
	vec3 col = paper;
	// Shadow side (lower right on screen) gets printed tone.
	if (p.x - p.y > 0.35) {
		float pitch = TONE_PITCH * tone_res_scale(VIEWPORT_SIZE);
		col = mix(col, ink, tone_dots(FRAGCOORD.xy, 0.3, pitch) * 0.7);
	}
	if (r > edge - line) col = ink;
	ALBEDO = mix(col, col * 0.4, manga_night);
}
