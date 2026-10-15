shader_type spatial;
// The single full-screen page pass (docs/ART_DIRECTION.md §8): depth-edge ink, grayscale
// atmospheric fade, sky gradient, paper grain, speed lines, impact bursts, night and the panel
// border. Drawn on a quad parked on the camera. One depth read per tap, ALU otherwise.
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

global uniform float manga_night;
global uniform float manga_fx_intensity;
global uniform float manga_outline_scale;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 paper : source_color = vec3(0.953, 0.937, 0.898);
uniform vec3 ink : source_color = vec3(0.075, 0.072, 0.07);
/// Inverse-depth curvature that counts as an ink line.
uniform float edge_threshold = 0.02;
/// Atmospheric fade toward `haze` (never all the way: far shapes stay light-gray silhouettes).
uniform float fade_start = 160.0;
uniform float fade_end = 900.0;
uniform float fade_max = 0.72;
uniform vec3 haze : source_color = vec3(0.88, 0.865, 0.83);
/// 0..1 from the car's speed.
uniform float speed_lines = 0.0;
/// 0..1, decays after a hard hit.
uniform float impact = 0.0;
uniform float border_px = 3.0;
uniform float gutter = 0.012;

float linear_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 view = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -view.z / view.w;
}

float hash1(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float res = max(VIEWPORT_SIZE.y / 1080.0, 0.5);
	vec2 px = res * manga_outline_scale / VIEWPORT_SIZE;
	vec3 col = texture(screen_tex, uv).rgb;
	float z = linear_depth(uv, INV_PROJECTION_MATRIX);
	bool sky = z > 2700.0;

	// The sky is drawn by manga_sky.gdshader; this pass leaves it alone.

	// Ink lines: inverse depth is linear across planes, so its Laplacian only fires at silhouettes
	// and creases, never on grazing ground.
	float zl = linear_depth(uv - vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float zr = linear_depth(uv + vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float zu = linear_depth(uv - vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	float zd = linear_depth(uv + vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	float w = 1.0 / max(z, 0.05);
	float lap = abs(1.0 / max(zl, 0.05) + 1.0 / max(zr, 0.05) + 1.0 / max(zu, 0.05) + 1.0 / max(zd, 0.05) - 4.0 * w) / w;
	// Silhouettes against the sky always ink (the mountain skyline stroke).
	bool sky_edge = !sky && max(max(zl, zr), max(zu, zd)) > 2700.0;
	float edge = sky ? 0.0 : max(smoothstep(edge_threshold, edge_threshold * 2.5, lap), sky_edge ? 1.0 : 0.0);

	if (!sky) {
		float fade = smoothstep(fade_start, fade_end, z) * fade_max;
		vec3 haze_col = mix(haze, ink * 1.6, manga_night);
		col = mix(col, haze_col, fade);
		// Lines outlast tone, but thin out in the distance.
		vec3 line_col = mix(ink, vec3(0.5, 0.49, 0.47), manga_night * 0.7);
		col = mix(col, line_col, edge * (1.0 - fade * 0.6));
	}

	// Paper grain.
	col *= 0.975 + hash2(floor(FRAGCOORD.xy / (2.0 * res))) * 0.025;

	vec2 c = (uv - vec2(0.5, 0.45)) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
	float r = length(c);
	float a = atan(c.y, c.x) / 6.2831853 + 0.5;

	// Speed lines: radial streaks from the edges; mostly ink, a few pale blue-white at top speed.
	float fx = manga_fx_intensity;
	if (speed_lines > 0.0) {
		float slots = 220.0;
		float id = floor(a * slots);
		float local = fract(a * slots);
		float on = step(1.0 - speed_lines * 0.5 * fx, hash1(id + floor(TIME * 14.0) * 7.31));
		float reach = mix(0.98, 0.5, hash1(id * 3.7)) * mix(1.15, 0.78, speed_lines);
		float thin = 1.0 - smoothstep(0.0, 0.16 + 0.22 * hash1(id * 1.3), abs(local - 0.5));
		float streak = on * thin * smoothstep(reach, reach + 0.25, r);
		vec3 streak_col = mix(ink, paper, manga_night);
		if (speed_lines > 0.6 && hash1(id * 9.1) > 0.82) streak_col = vec3(0.72, 0.84, 1.0);
		col = mix(col, streak_col, streak * 0.8);
	}

	// Impact: burst lines from the screen edge inward and a brief inverted rim; the centre
	// (the road ahead) stays clear.
	if (impact > 0.01) {
		float slots = 90.0;
		float id = floor(a * slots);
		float local = fract(a * slots);
		float burst = step(0.45, hash1(id + 3.3)) * (1.0 - smoothstep(0.0, 0.3, abs(local - 0.5)));
		float reach = mix(0.75, 0.42, impact) + hash1(id * 5.1) * 0.12;
		float rim = smoothstep(reach, reach + 0.05, r);
		col = mix(col, ink, burst * rim * impact * fx);
		float edge_band = smoothstep(0.62, 0.8, r) * impact * 0.6 * fx;
		col = mix(col, vec3(1.0) - col, edge_band);
	}

	// Panel: a paper gutter and a thin ink frame.
	vec2 edge_uv = min(uv, 1.0 - uv);
	float m = min(edge_uv.x * VIEWPORT_SIZE.x, edge_uv.y * VIEWPORT_SIZE.y);
	float g = gutter * VIEWPORT_SIZE.y;
	if (m < g) col = paper;
	else if (m < g + border_px * res) col = ink;

	ALBEDO = col;
}
