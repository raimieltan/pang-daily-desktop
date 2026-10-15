shader_type spatial;
// Inverted-hull ink outline for the car: a back-face shell pushed out along the normals, so the
// silhouette always has a solid line even where the compositor's depth edge is thin.
render_mode unshaded, cull_front, shadows_disabled;

global uniform float manga_outline_scale;

uniform float width = 0.014;
uniform vec3 ink : source_color = vec3(0.067);

void vertex() {
	VERTEX += NORMAL * width * manga_outline_scale;
}

void fragment() {
	ALBEDO = ink;
}
