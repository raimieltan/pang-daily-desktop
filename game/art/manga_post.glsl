#[compute]
#version 450
// Manga page pass (docs/ART_DIRECTION.md): runs after the transparent pass on the HDR color buffer,
// one thread per pixel, reading only its own color texel (so it works in place) plus depth/normal
// neighbours for the ink lines.
//   1. Tone ramp: perceptual luminance → 4 bands (ink, dense tone, sparse tone, paper), with
//      screen-space screentone sized to the resolution (no world-space moiré).
//   2. Ink lines: Sobel on linear depth (silhouettes, thick) and on view normals (creases, thin),
//      width falling off with distance, no creases far away, a small hand-inked wobble. Black ink;
//      white where the background is solid ink so silhouettes still read at night.
//   3. Paper grain and a faint ink bleed around lines.
// Saturated pixels (the player car, its lamps, sparks) skip the ramp but still get lines + grain.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D depth_tex;
layout(set = 0, binding = 2) uniform sampler2D normal_tex;
layout(set = 0, binding = 3, std140) uniform Params {
	// Linear depth for a perspective camera needs only d: z = -(a*d + b) / (c*d + e).
	vec4 depth_coef; // a, b, c, e (from the inverse projection, precomputed on the CPU)
	vec4 size;      // w, h, 1/w, 1/h
	vec4 bands;     // t0 (ink|dense), t1 (dense|sparse), t2 (sparse|paper), tone pitch px @1080p
	vec4 tone;      // dense coverage, sparse coverage, dense pattern (0 dots, 1 crosshatch), unused
	vec4 lines;     // silhouette px, crease px, line far (m), crease far (m)
	vec4 lines2;    // depth sensitivity, normal sensitivity, jitter px, jitter scale px
	vec4 paper;     // rgb (linear), grain strength
	vec4 ink;       // rgb (linear), bleed strength
	vec4 misc;      // car saturation threshold, white lines on ink (0/1), enabled (0/1), unused
} p;

// Integer hash (PCG-style): much cheaper than sin() hashes on Apple GPUs.
float hash(vec2 q) {
	uvec2 v = uvec2(ivec2(q) + 32768);
	uint h = v.x * 747796405u + v.y * 2891336453u;
	h = ((h >> ((h >> 28u) + 4u)) ^ h) * 277803737u;
	return float((h >> 22u) ^ h) * (1.0 / 4294967295.0);
}
float vnoise(vec2 q) {
	vec2 i = floor(q); vec2 f = fract(q); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

ivec2 g_max;

float linear_depth_at(ivec2 q) {
	float d = texelFetch(depth_tex, clamp(q, ivec2(0), g_max), 0).r;
	return -(p.depth_coef.x * d + p.depth_coef.y) / (p.depth_coef.z * d + p.depth_coef.w);
}

vec3 view_normal_at(ivec2 q) {
	return normalize(texelFetch(normal_tex, clamp(q, ivec2(0), g_max), 0).xyz * 2.0 - 1.0);
}

// Screen-space 45° dots: 1 = ink.
float tone_dots(vec2 frag, float coverage, float pitch) {
	vec2 q = vec2(frag.x + frag.y, frag.y - frag.x) * 0.70710678 / pitch;
	float d = length(fract(q) - 0.5) * pitch;
	float r = pitch * sqrt(coverage / 3.14159);
	return 1.0 - smoothstep(r - 0.6, r + 0.6, d);
}

// Screen-space crosshatch: two diagonal line sets.
float tone_hatch(vec2 frag, float coverage, float pitch) {
	float w = coverage * pitch * 0.32;
	float a = abs(fract((frag.x + frag.y) * 0.70710678 / pitch) - 0.5) * pitch;
	float b = abs(fract((frag.x - frag.y) * 0.70710678 / pitch) - 0.5) * pitch;
	return max(1.0 - smoothstep(w - 0.6, w + 0.6, a), 1.0 - smoothstep(w - 0.6, w + 0.6, b));
}

void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy);
	if (px.x >= int(p.size.x) || px.y >= int(p.size.y)) return;
	if (p.misc.z < 0.5) return;
	vec2 frag = vec2(px) + 0.5;
	float res = max(p.size.y / 1080.0, 0.5);
	vec4 src = imageLoad(color_image, px);

	// --- Tone ramp ---------------------------------------------------------------------------
	float lum = dot(max(src.rgb, vec3(0.0)), vec3(0.2126, 0.7152, 0.0722));
	float L = pow(clamp(lum, 0.0, 1.0), 1.0 / 2.2);
	float hi = max(src.r, max(src.g, src.b));
	float lo = min(src.r, min(src.g, src.b));
	float sat = hi > 1e-4 ? (hi - lo) / hi : 0.0;
	bool colored = sat > p.misc.x && hi > 0.03;

	int band = L < p.bands.x ? 0 : (L < p.bands.y ? 1 : (L < p.bands.z ? 2 : 3));
	float pitch = p.bands.w * res;
	float tone_ink = 0.0;
	if (band == 0) tone_ink = 1.0;
	else if (band == 1) tone_ink = p.tone.z > 0.5 ? tone_hatch(frag, p.tone.x, pitch) : tone_dots(frag, p.tone.x, pitch);
	else if (band == 2) tone_ink = tone_dots(frag, p.tone.y, pitch);
	vec3 col = colored ? src.rgb : mix(p.paper.rgb, p.ink.rgb, tone_ink);

	// --- Ink lines ---------------------------------------------------------------------------
	g_max = ivec2(p.size.xy) - 1;
	float z = linear_depth_at(px);
	bool sky = z > 4000.0;
	float near_t = 1.0 - smoothstep(4.0, p.lines.z, z);   // 1 near → 0 at line_far
	// Hand-inked wobble: one slowly varying noise shifts the kernel by a pixel or so.
	float wn = vnoise(frag / (p.lines2.w * res)) - 0.5;
	ivec2 k = px + ivec2(round(vec2(wn, -wn * 0.7) * p.lines2.z * res));

	float sil = 0.0;
	if (!sky) {
		int o = max(1, int(round(mix(p.lines.x * 0.35, p.lines.x, near_t) * res)));
		// Cross-shaped gradient + Laplacian on inverse depth (linear across planes, so flat ground
		// never lights up): 4 taps instead of a 3×3 Sobel's 8, same silhouettes.
		float tc = 1.0 / max(linear_depth_at(k + ivec2(0, -o)), 0.05);
		float bc = 1.0 / max(linear_depth_at(k + ivec2(0, o)), 0.05);
		float ml = 1.0 / max(linear_depth_at(k + ivec2(-o, 0)), 0.05);
		float mr = 1.0 / max(linear_depth_at(k + ivec2(o, 0)), 0.05);
		float mc = 1.0 / max(z, 0.05);
		float grad = length(vec2(mr - ml, bc - tc)) * 0.5;
		float lap = abs(tc + bc + ml + mr - 4.0 * mc);
		// Second difference rejects the smooth gradient of planes; first difference finds the jump.
		float g = min(grad, lap * 2.0) / mc;
		sil = smoothstep(p.lines2.x, p.lines2.x * 2.2, g);
	}
	float crease = 0.0;
	if (!sky && z < p.lines.w) {
		int o = max(1, int(round(p.lines.y * res)));
		// Forward differences right and down: 3 normal taps.
		vec3 n = view_normal_at(k);
		float e = max(1.0 - dot(n, view_normal_at(k + ivec2(o, 0))), 1.0 - dot(n, view_normal_at(k + ivec2(0, o))));
		crease = smoothstep(p.lines2.y, p.lines2.y * 1.8, e) * (1.0 - smoothstep(p.lines.w * 0.5, p.lines.w, z));
	}
	float line = max(sil, crease * 0.85);
	// White ink is for silhouettes over solid black (night skylines), never interior creases.
	bool white_ok = sil > crease * 0.85;
	// Far geometry: silhouettes thin, then stop: distant trees are plain black shapes.
	line *= mix(0.55, 1.0, near_t) * (1.0 - smoothstep(p.lines.z * 0.7, p.lines.z, z));

	// Ink on paper; white ink only where the page under the line is already solid black.
	vec3 line_col = (p.misc.y > 0.5 && band == 0 && !colored && white_ok) ? p.paper.rgb : p.ink.rgb;
	// Ink bleed: a faint darker halo hugging every black line.
	float bleed = smoothstep(0.0, 0.35, line) * (1.0 - line) * p.ink.w;
	if (line_col == p.ink.rgb) col = mix(col, p.ink.rgb, bleed);
	col = mix(col, line_col, line);

	// --- Paper grain ---------------------------------------------------------------------------
	float grain = hash(floor(frag / (1.5 * res)));
	col *= 1.0 - p.paper.w * (1.0 - grain);

	imageStore(color_image, px, vec4(col, src.a));
}
