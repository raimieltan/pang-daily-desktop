class_name TrackMaterials
## Materials and small meshes for generated tracks. Procedural (shaders and noise textures), so
## maps stay small on disk and need no texture assets yet.

const ROAD_SHADER := """
shader_type spatial;
render_mode diffuse_burley;
// UV: x = lateral offset (m, right +), y = distance along the road (m).
uniform float lane_half_width = 3.0;
uniform float start_line = 20.0;
uniform float finish_line = -1.0;
varying vec2 road_uv;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float band(float x, float center, float half_w) {
	float aa = fwidth(x) * 0.75;
	return 1.0 - smoothstep(half_w - aa, half_w + aa, abs(x - center));
}
void vertex() { road_uv = UV; }
void fragment() {
	vec2 p = road_uv;
	float grain = noise(p * 6.0) * 0.5 + noise(p * 23.0) * 0.5;
	float patches = smoothstep(0.55, 0.8, noise(p * vec2(0.35, 0.08)));
	// Worn racing line: darker, polished rubber in each lane.
	float wear = exp(-pow((abs(p.x) - 1.4) / 0.6, 2.0)) * 0.6;
	vec3 asphalt = vec3(0.13, 0.135, 0.14) * (0.85 + grain * 0.3) * (1.0 - patches * 0.18) * (1.0 - wear * 0.25);
	// Edge lines and a dashed centre line (Japanese pass roads: white edges, yellow no-overtake centre).
	float edge = band(p.x, -lane_half_width + 0.15, 0.075) + band(p.x, lane_half_width - 0.15, 0.075);
	float dash = step(0.5, fract(p.y / 8.0));
	float centre = band(p.x, -0.1, 0.06) + band(p.x, 0.1, 0.06);
	float start = band(p.y, start_line, 0.25) * step(abs(p.x), lane_half_width);
	float finish = finish_line > 0.0 ? band(p.y, finish_line, 1.2) * step(abs(p.x), lane_half_width) : 0.0;
	float checker = mod(floor(p.x / 0.6) + floor(p.y / 0.6), 2.0);
	vec3 paint = vec3(0.86) * (0.8 + grain * 0.2);
	vec3 col = mix(asphalt, paint, clamp(edge, 0.0, 1.0));
	col = mix(col, vec3(0.85, 0.65, 0.1), clamp(centre, 0.0, 1.0) * 0.9);
	col = mix(col, paint, start);
	col = mix(col, mix(vec3(0.05), paint, checker), finish);
	ALBEDO = col;
	ROUGHNESS = mix(0.88, 0.7, wear);
}
"""

const TRIPLANAR_SHADER := """
shader_type spatial;
render_mode diffuse_burley;
uniform vec3 base_color : source_color = vec3(0.4);
uniform vec3 alt_color : source_color = vec3(0.3);
uniform float scale = 0.25;
uniform float slope_rock = 0.0;
uniform vec3 rock_color : source_color = vec3(0.35, 0.33, 0.3);
varying vec3 world_pos;
varying vec3 world_normal;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), u.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), u.x), u.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), u.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), u.x), u.y), u.z);
}
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	float n = noise(world_pos * scale) * 0.6 + noise(world_pos * scale * 4.0) * 0.4;
	vec3 col = mix(base_color, alt_color, n);
	// Steep faces read as bare rock.
	float steep = smoothstep(0.55, 0.85, 1.0 - world_normal.y) * slope_rock;
	col = mix(col, rock_color * (0.8 + n * 0.4), steep);
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
"""


static func road() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = ROAD_SHADER
	m.shader = shader
	return m


static func _triplanar(base: Color, alt: Color, scale: float, slope_rock: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = TRIPLANAR_SHADER
	m.shader = shader
	m.set_shader_parameter("base_color", base)
	m.set_shader_parameter("alt_color", alt)
	m.set_shader_parameter("scale", scale)
	m.set_shader_parameter("slope_rock", slope_rock)
	return m


## Indexed by `TrackBuilder.Mat`: asphalt, concrete, gravel, rock, dirt.
static func road_set() -> Array[Material]:
	return [
		road(),
		_triplanar(Color(0.55, 0.55, 0.52), Color(0.47, 0.47, 0.45), 1.5, 0.0),
		_triplanar(Color(0.42, 0.4, 0.36), Color(0.3, 0.29, 0.27), 3.0, 0.0),
		_triplanar(Color(0.36, 0.35, 0.32), Color(0.24, 0.27, 0.2), 0.6, 1.0),
		_triplanar(Color(0.27, 0.3, 0.16), Color(0.33, 0.28, 0.2), 0.4, 0.6),
	]


static func terrain() -> ShaderMaterial:
	return _triplanar(Color(0.18, 0.27, 0.12), Color(0.26, 0.3, 0.15), 0.05, 1.0)


static func guardrail() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.78, 0.8, 0.82)
	m.metallic = 0.6
	m.roughness = 0.45
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Low-poly Japanese cedar (sugi): trunk plus two stacked cones, one mesh with two surfaces.
static func cedar_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.25
	trunk.height = 3.0
	trunk.radial_segments = 6
	trunk.rings = 1
	var leaves := CylinderMesh.new()
	leaves.top_radius = 0.0
	leaves.bottom_radius = 2.3
	leaves.height = 11.0
	leaves.radial_segments = 7
	leaves.rings = 2
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(trunk, 0, Transform3D(Basis(), Vector3(0, 1.5, 0)))
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.25, 0.17, 0.12)
	st.set_material(trunk_mat)
	st.commit(mesh)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	st2.append_from(leaves, 0, Transform3D(Basis(), Vector3(0, 8.0, 0)))
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.09, 0.2, 0.1)
	leaf_mat.roughness = 1.0
	st2.set_material(leaf_mat)
	st2.commit(mesh)
	return mesh
