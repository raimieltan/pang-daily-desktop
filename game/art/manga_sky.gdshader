shader_type sky;
// Sky as luminance for the manga compositor.
//  Night: solid black with sparse 1–2 px star dots (sized from the camera's angle per pixel).
//  Day: paper with a darker horizon (banded into tone by the compositor) and cumulus outlined in ink.
// No TIME, so radiance never re-bakes per frame.

global uniform float manga_night;
/// Radians per screen pixel, set by the camera (sky shaders have no viewport size).
global uniform float manga_px_angle;

uniform float star_density : hint_range(0.0, 0.02) = 0.0035;
/// Star dot radius in pixels.
uniform float star_px = 0.9;
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.46;
uniform float cloud_scale = 1.6;
uniform vec2 cloud_offset = vec2(3.7, 1.2);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 hash2(vec2 p) { return vec2(hash(p), hash(p + 19.19)); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float clouds(vec2 p) { return vnoise(p) * 0.55 + vnoise(p * 2.1 + 7.0) * 0.3 + vnoise(p * 4.3 + 3.0) * 0.15; }

void sky() {
	vec3 d = EYEDIR;
	float h = clamp(d.y, 0.0, 1.0);

	// Day: a horizon band that the ramp turns into sparse tone, paper above.
	float day = mix(0.5, 0.97, smoothstep(0.0, 0.25, h));
	// Cloud noise is the expensive part of this shader: skip it on a fully night sky.
	if (d.y > 0.02 && manga_night < 0.999) {
		vec2 uv = d.xz / (d.y + 0.12) * cloud_scale + cloud_offset;
		float thr = 1.0 - cloud_cover;
		float n = clouds(uv);
		float fade = smoothstep(0.02, 0.12, d.y);
		if (n > thr) {
			vec2 to_sun = normalize(LIGHT0_DIRECTION.xz + vec2(1e-4)) * 0.08;
			day = mix(day, clouds(uv + to_sun) < n + 0.015 ? 0.97 : 0.45, fade);
		}
		float contour = 1.0 - smoothstep(0.0, fwidth(n) * 1.4, abs(n - thr));
		day = mix(day, 0.0, contour * fade);
	}

	// Night: black, with point stars on a direction grid; each star is a disc star_px wide.
	float cell_size = 0.035;
	vec2 sph = vec2(atan(d.z, d.x), asin(clamp(d.y, -1.0, 1.0))) / cell_size;
	vec2 cell = floor(sph);
	float night = 0.0;
	if (manga_night > 0.001 && d.y > 0.08 && hash(cell + 3.1) < star_density * 30.0) {
		vec2 center = (cell + 0.2 + 0.6 * hash2(cell)) * cell_size;
		vec2 here = sph * cell_size;
		float ang = length(vec2((here.x - center.x) * cos(here.y), here.y - center.y));
		night = 1.0 - smoothstep(star_px * manga_px_angle, (star_px + 0.8) * manga_px_angle, ang);
	}
	COLOR = vec3(mix(day, night, manga_night));
}
