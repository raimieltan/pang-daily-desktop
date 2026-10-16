shader_type spatial;
// Distant valley lights: camera-facing dots, night only. Each dot keeps a minimum on-screen size
// (scaled with distance) so a town 800 m off still reads as a spray of points, and twinkles a
// little through the haze. Colored dots survive the manga compositor as spot color, like lamps.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

global uniform float manga_night;

uniform vec3 color : source_color = vec3(1.0, 0.6, 0.2);
uniform float intensity = 3.0;
// World size per metre of view distance (~2.5 px at 1080p), with a floor up close.
uniform float size_per_metre = 0.0035;
uniform float min_size = 0.9;

varying float v_seed;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float d = length((MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
	float s = max(min_size, d * size_per_metre);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(s, 0, 0, 0), vec4(0, s, 0, 0), vec4(0, 0, s, 0), vec4(0, 0, 0, 1));
	v_seed = fract(float(INSTANCE_ID) * 0.61803);
}

void fragment() {
	if (manga_night < 0.02) discard;
	float r = length(UV * 2.0 - 1.0);
	if (r > 1.0) discard;
	float core = 1.0 - smoothstep(0.25, 1.0, r);
	float twinkle = 0.75 + 0.25 * sin(TIME * (1.3 + v_seed * 2.7) + v_seed * 40.0);
	ALBEDO = color * core * twinkle * intensity * manga_night;
}
