shader_type spatial;
// Inverted-hull ink outline for cars and props: a back-face shell pushed out along the normals.
// World-space width, so the line thins naturally with distance.
render_mode unshaded, cull_front, shadows_disabled;

uniform float width = 0.025;
uniform vec3 ink : source_color = vec3(0.06);

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = ink;
}
