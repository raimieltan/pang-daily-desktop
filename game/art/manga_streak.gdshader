shader_type spatial;
// Taillight trail: a red light streak that starts AT the lamp and stretches backwards, longer
// with speed (the manga motion trail). Axially billboarded: the strip runs along the node's +Z
// (set to point behind the car) and turns about that axis to face the camera.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

uniform vec3 color : source_color = vec3(1.0, 0.1, 0.06);
uniform float intensity = 0.0;
/// Trail length (m) and width at the lamp (m).
uniform float trail_length = 0.4;
uniform float width = 0.16;

varying float v_t;

void vertex() {
	// QuadMesh 1×1: VERTEX.x across, VERTEX.y along (−0.5 at the lamp .. +0.5 at the tail end).
	vec3 start = MODEL_MATRIX[3].xyz;
	vec3 axis = normalize(MODEL_MATRIX[2].xyz);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - start);
	vec3 side = normalize(cross(axis, to_cam));
	float t = VERTEX.y + 0.5;
	// Narrows toward the tail.
	vec3 world = start + axis * t * trail_length + side * VERTEX.x * width * mix(1.0, 0.45, t);
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	v_t = t;
}

void fragment() {
	float along = pow(1.0 - v_t, 1.3);
	float across = 1.0 - smoothstep(0.25, 0.5, abs(UV.x - 0.5));
	// Hard manga steps: a bright core at the lamp fading to the tail in three bands.
	float stepped = floor(along * across * 3.0 + 0.25) / 3.0;
	ALBEDO = color * stepped * intensity;
}
