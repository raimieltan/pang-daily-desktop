shader_type spatial;
// The best-run ghost: a pencil sketch of the car (paper fill, ink rim lines), see-through.
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform vec3 paper : source_color = vec3(0.953, 0.937, 0.898);
uniform vec3 ink : source_color = vec3(0.075, 0.072, 0.07);
uniform float opacity = 0.35;

void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float line = smoothstep(0.7, 0.85, rim);
	ALBEDO = mix(paper, ink, line);
	ALPHA = mix(opacity, 0.75, line);
}
