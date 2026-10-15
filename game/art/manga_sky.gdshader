shader_type sky;
// Manga sky (docs/ART_DIRECTION.md §6): paper with a printed horizon band, cumulus clouds drawn
// with ink contours and toned undersides, a sun with drawn rays; at night an ink sky with stars
// and a crescent moon. No TIME, so the sky never re-bakes radiance per frame.

#include "res://game/art/manga_tone.gdshaderinc"

global uniform float manga_night;
/// viewport height / 1080, set by the camera (sky shaders have no viewport size built-in).
global uniform float manga_res_scale;

uniform vec3 paper : source_color = vec3(0.953, 0.937, 0.898);
uniform vec3 horizon : source_color = vec3(0.83, 0.815, 0.78);
uniform vec3 ink : source_color = vec3(0.075, 0.072, 0.07);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.46;
uniform float cloud_scale = 1.6;
uniform vec2 cloud_offset = vec2(3.7, 1.2);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float clouds(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.1 + 7.0) * 0.3 + vnoise(p * 4.3 + 3.0) * 0.15;
}

void sky() {
	vec3 d = EYEDIR;
	float pitch = TONE_PITCH * max(manga_res_scale, 0.5);
	float h = clamp(d.y, 0.0, 1.0);
	vec3 col = mix(horizon, paper, smoothstep(0.0, 0.3, h));
	// Printed horizon band.
	col = mix(col, ink, tone_dots(FRAGCOORD.xy, 0.22, pitch) * (1.0 - smoothstep(0.0, 0.1, h)) * 0.4);

	// Clouds on a flat layer: density, an ink contour at the threshold, toned shadow side.
	if (d.y > 0.02) {
		vec2 uv = d.xz / (d.y + 0.12) * cloud_scale + cloud_offset;
		float thr = 1.0 - cloud_cover;
		float n = clouds(uv);
		float fade = smoothstep(0.02, 0.12, d.y);
		if (n > thr) {
			vec2 to_sun = normalize(LIGHT0_DIRECTION.xz + vec2(1e-4)) * 0.08;
			float lit = clouds(uv + to_sun) < n + 0.015 ? 1.0 : 0.0;
			vec3 c = paper;
			if (lit < 0.5) c = mix(paper, ink, tone_dots(FRAGCOORD.xy, 0.35, pitch) * 0.75);
			col = mix(col, c, fade);
		}
		float contour = 1.0 - smoothstep(0.0, fwidth(n) * 1.6, abs(n - thr));
		col = mix(col, ink, contour * fade * 0.9);
	}

	// Sun: paper disc, ink ring, drawn rays.
	vec3 sun = LIGHT0_DIRECTION;
	float sd = dot(d, sun);
	if (sd > 0.9985) col = paper;
	float ring = 1.0 - smoothstep(0.0, 0.00025, abs(sd - 0.9985));
	col = mix(col, ink, ring);
	if (sd > 0.985 && sd < 0.9975) {
		vec3 t = normalize(cross(sun, vec3(0.0, 1.0, 0.0)));
		vec3 b = cross(sun, t);
		float a = atan(dot(d, b), dot(d, t));
		float ray = step(0.75, fract(a * 6.0)) * smoothstep(0.985, 0.992, sd);
		col = mix(col, ink, ray * 0.55);
	}

	// Night: ink sky, paper stars, a crescent moon opposite the sun's azimuth.
	vec3 night = ink * 1.35;
	vec2 cell = floor(vec2(atan(d.z, d.x) * 160.0, d.y * 240.0));
	night = mix(night, paper, step(0.9965, hash(cell)) * step(0.06, d.y));
	vec3 moon = normalize(vec3(-sun.x, 0.45, -sun.z));
	float md = dot(d, moon);
	if (md > 0.9993) {
		vec3 bite = normalize(moon + normalize(cross(moon, vec3(0.0, 1.0, 0.0))) * 0.02);
		night = dot(d, bite) > 0.9993 ? night : paper;
	}
	COLOR = mix(col, night, manga_night);
}
