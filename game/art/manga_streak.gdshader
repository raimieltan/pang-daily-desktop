shader_type spatial;
// Taillight reflection on the road: a flat additive streak stretching back from each lamp,
// fading in hard steps (manga banding) along its length and softly at its edges.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.1, 0.06);
uniform float intensity = 0.0;

void fragment() {
	// PlaneMesh UV.y runs from its −Z edge (far, behind the car) to +Z (the bumper end).
	float t = UV.y;
	float along = pow(t, 0.8);
	// Narrow at the lamp, widening as it fades: a reflection smeared toward the viewer.
	float half_w = mix(0.48, 0.2, t);
	float across = 1.0 - smoothstep(half_w * 0.5, half_w, abs(UV.x - 0.5));
	float v = along * across;
	float stepped = floor(v * 3.0 + 0.2) / 3.0;
	ALBEDO = color * stepped * intensity * 0.55;
}
