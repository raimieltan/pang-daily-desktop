shader_type spatial;
// Full-screen manga page pass (docs/ART_DIRECTION.md §8): depth-edge ink lines, distance fade to
// paper, paper grain, speed lines and the panel border. Drawn on a quad parked on the camera.
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 paper : source_color = vec3(0.949, 0.937, 0.902);
uniform vec3 ink : source_color = vec3(0.078);
/// Relative depth jump that counts as a silhouette.
uniform float edge_threshold = 0.02;
uniform float fade_start = 140.0;
uniform float fade_end = 520.0;
/// 0..1 from the car's speed; drives speed lines.
uniform float speed_lines = 0.0;
uniform float border_px = 3.0;
uniform float gutter = 0.012;

float linear_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 view = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -view.z / view.w;
}

float hash1(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = 1.0 / VIEWPORT_SIZE;
	vec3 col = texture(screen_tex, uv).rgb;
	float z = linear_depth(uv, INV_PROJECTION_MATRIX);
	float far_plane = 3000.0;
	bool sky = z > far_plane * 0.9;

	// Ink silhouettes: depth discontinuities, one pixel kernel, heavier near the camera.
	float zl = linear_depth(uv - vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float zr = linear_depth(uv + vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float zu = linear_depth(uv - vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	float zd = linear_depth(uv + vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	// Inverse depth is linear across any plane, so its Laplacian is ~0 on flat ground at any angle
	// and spikes at silhouettes and creases.
	float w = 1.0 / max(z, 0.05);
	float lap = abs(1.0 / max(zl, 0.05) + 1.0 / max(zr, 0.05) + 1.0 / max(zu, 0.05) + 1.0 / max(zd, 0.05) - 4.0 * w) / w;
	float edge = sky ? 0.0 : smoothstep(edge_threshold, edge_threshold * 2.5, lap);

	// Distance fades to paper; lines outlast tone.
	float fade = sky ? 1.0 : smoothstep(fade_start, fade_end, z);
	col = mix(col, paper, fade);
	col = mix(col, ink, edge * (1.0 - fade * 0.75));

	// Paper grain.
	float grain = fract(sin(dot(floor(FRAGCOORD.xy / 2.0), vec2(12.9898, 78.233))) * 43758.5453);
	col *= 0.97 + grain * 0.03;

	// Speed lines: radial ink streaks from the screen edges toward the vanishing point.
	if (speed_lines > 0.0) {
		vec2 c = (uv - vec2(0.5, 0.46)) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
		float r = length(c);
		float a = atan(c.y, c.x);
		float slots = 220.0;
		float id = floor((a / 6.2831853 + 0.5) * slots);
		float local = fract((a / 6.2831853 + 0.5) * slots);
		float on = step(1.0 - speed_lines * 0.55, hash1(id + floor(TIME * 14.0) * 7.31));
		float reach = mix(0.95, 0.45, hash1(id * 3.7)) * mix(1.2, 0.75, speed_lines);
		float thin = 1.0 - smoothstep(0.0, 0.18 + 0.25 * hash1(id * 1.3), abs(local - 0.5));
		float streak = on * thin * smoothstep(reach, reach + 0.25, r);
		col = mix(col, ink, streak * 0.85);
	}

	// Panel: a paper gutter and a thin ink frame.
	vec2 edge_uv = min(uv, 1.0 - uv);
	float m = min(edge_uv.x * VIEWPORT_SIZE.x, edge_uv.y * VIEWPORT_SIZE.y);
	float g = gutter * VIEWPORT_SIZE.y;
	if (m < g) col = paper;
	else if (m < g + border_px) col = ink;

	ALBEDO = col;
}
