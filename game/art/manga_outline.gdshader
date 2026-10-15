shader_type spatial;
// Inverted-hull ink outline for cars and props: a back-face shell pushed out along the normals.
// World-space width (per material), scaled globally; thins naturally with distance.
render_mode unshaded, cull_front, shadows_disabled;

global uniform float manga_outline_scale;
global uniform float manga_night;

uniform float width = 0.02;
uniform vec3 ink : source_color = vec3(0.06);

void vertex() {
	VERTEX += NORMAL * width * manga_outline_scale;
}

void fragment() {
	// At night the page inverts: outlines read as pale ink on the dark world.
	ALBEDO = mix(ink, vec3(0.55, 0.54, 0.52), manga_night * 0.6);
}
