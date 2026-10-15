shader_type spatial;
// Restrained lamp glow: an additive camera-facing disc with a hard-banded falloff (no bloom).
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.08, 0.06);
uniform float intensity = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float core = 1.0 - smoothstep(0.25, 0.3, r);
	float halo = (1.0 - smoothstep(0.55, 0.6, r)) * 0.35;
	ALBEDO = color * (core + halo) * intensity;
}
