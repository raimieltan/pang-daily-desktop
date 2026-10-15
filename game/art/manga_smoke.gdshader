shader_type spatial;
// Tire smoke as manga clouds: a paper puff with a lumpy ink contour and a gray shadow side (the
// compositor bands it into tone), cut out, shrinking away as the particle ages (COLOR.a).
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec3 paper : source_color = vec3(0.953, 0.929, 0.882);
uniform vec3 ink : source_color = vec3(0.067);

varying float v_seed;

void vertex() {
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
	vec3 col = p.x - p.y > 0.35 ? paper * 0.55 : paper;
	if (r > edge - (0.06 + 0.05 * life)) col = ink;
	ALBEDO = col;
}
