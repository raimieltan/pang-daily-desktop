shader_type canvas_item;
// Screen overlay above the 3D frame, below the HUD: speed lines (radial focus lines from the
// vanishing point, clear in the centre), horizontal background streaks at high speed, impact
// bursts and the panel border. Pure 2D: no scene reads, cheap at any resolution.

group_uniforms speed_lines;
/// 0..1: off below ~60 km/h, full at ~160 km/h (set from the car each frame).
uniform float speed = 0.0;
/// Vanishing point in screen UV.
uniform vec2 focus = vec2(0.5, 0.44);
/// Radius (in screen heights) kept clear around the focus at full speed / at the threshold.
uniform float clear_radius_full = 0.36;
uniform float clear_radius_min = 0.62;
uniform float line_count = 260.0;
/// Fraction of slots that carry a line at full speed.
uniform float density = 0.55;
uniform float flicker_hz = 16.0;
uniform float ink_alpha = 0.9;
group_uniforms;

group_uniforms streaks;
/// Horizontal streaks on the background at high speed (starts at this speed value).
uniform float streak_from = 0.55;
uniform float streak_rows = 120.0;
group_uniforms;

group_uniforms impact;
uniform float impact = 0.0;
group_uniforms;

group_uniforms page;
uniform vec4 paper : source_color = vec4(0.953, 0.929, 0.882, 1.0);
uniform vec4 ink : source_color = vec4(0.067, 0.067, 0.067, 1.0);
/// Paper gutter (share of screen height) and ink frame (px at 1080p).
uniform float gutter = 0.012;
uniform float border_px = 3.0;
group_uniforms;

float hash1(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float res_scale = max(res.y / 1080.0, 0.5);
	vec2 c = (uv - focus) * vec2(res.x / res.y, 1.0);
	float r = length(c);
	float a = atan(c.y, c.x) / 6.2831853 + 0.5;
	float ink_amount = 0.0;
	vec3 color = ink.rgb;

	if (speed > 0.0) {
		// Thin tapered wedges: each slot gets a random length and on/off state, re-rolled at flicker_hz.
		float id = floor(a * line_count);
		float local = fract(a * line_count);
		float frame = floor(TIME * flicker_hz);
		float on = step(1.0 - speed * density, hash1(id * 1.7 + frame * 7.31));
		float clear = mix(clear_radius_min, clear_radius_full, speed) + hash1(id * 3.7 + frame) * 0.18;
		float along = smoothstep(clear, clear + 0.22, r);
		// Taper: thin at the inner tip, wider toward the frame edge.
		float half_w = mix(0.04, 0.32, clamp((r - clear) / 0.6, 0.0, 1.0));
		float wedge = 1.0 - smoothstep(half_w * 0.6, half_w, abs(local - 0.5));
		ink_amount = max(ink_amount, on * along * wedge * ink_alpha);

		// Background streaks: short horizontal ink dashes at the screen sides.
		if (speed > streak_from) {
			float row = floor(uv.y * streak_rows);
			float s = (speed - streak_from) / (1.0 - streak_from);
			float lane = hash1(row + frame * 3.1);
			float x0 = hash1(row * 7.7 + frame);
			float dash = step(lane, s * 0.35) * step(abs(fract(uv.x * 2.0 + x0) - 0.5), 0.12 * s)
				* step(0.32, abs(uv.x - 0.5)) * (1.0 - smoothstep(0.3, 0.5, abs(fract(uv.y * streak_rows) - 0.5)));
			ink_amount = max(ink_amount, dash * 0.75);
		}
	}

	// Impact: burst lines driving in from the frame edge, centre kept clear.
	if (impact > 0.01) {
		float id = floor(a * 90.0);
		float local = fract(a * 90.0);
		float burst = step(0.45, hash1(id + 3.3)) * (1.0 - smoothstep(0.0, 0.3, abs(local - 0.5)));
		float reach = mix(0.78, 0.45, impact) + hash1(id * 5.1) * 0.12;
		ink_amount = max(ink_amount, burst * smoothstep(reach, reach + 0.05, r) * impact);
	}

	// Panel: paper gutter and a thin ink frame.
	vec2 edge_uv = min(uv, 1.0 - uv);
	float m = min(edge_uv.x * res.x, edge_uv.y * res.y);
	float g = gutter * res.y;
	if (m < g) { color = paper.rgb; ink_amount = 1.0; }
	else if (m < g + border_px * res_scale) { color = ink.rgb; ink_amount = 1.0; }

	COLOR = vec4(color, ink_amount);
}
