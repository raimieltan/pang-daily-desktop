shader_type spatial;
// Car materials: the color on the page. Hard toon bands (lit color → darker color → solid ink in
// shadow), crisp white specular streaks along the body lines and a glint; no hatching. The
// compositor leaves these saturated pixels in color and only adds ink lines. The car does not
// receive shadows on itself (self-shadow acne speckled the body); it still casts them on the road.
render_mode diffuse_lambert, specular_disabled, ambient_light_disabled, shadows_disabled;

/// 0 paint, 1 glass, 2 lamp, 3 rubber/trim, 4 metal.
uniform int kind = 0;
uniform vec3 albedo : source_color = vec3(0.95, 0.75, 0.1);
group_uniforms toon;
/// Wrapped N·L thresholds: above `lit_cut` full color, above `shade_cut` the shade band, else ink.
uniform float lit_cut : hint_range(0.0, 1.0) = 0.42;
uniform float shade_cut : hint_range(0.0, 1.0) = 0.03;
/// Shade band = albedo × this (keeps saturation, so it stays out of the compositor's gray ramp).
uniform float shade_mul : hint_range(0.0, 1.0) = 0.55;
uniform vec3 ink_color : source_color = vec3(0.067);
group_uniforms;
group_uniforms highlights;
uniform bool glint = true;
uniform float glint_power = 0.985;
/// Body-line streaks: values of the surface's "up" factor that catch a white shine line.
uniform float streak_a = 0.86;
uniform float streak_b = 0.66;
uniform float streak_width = 0.022;
uniform vec3 paper : source_color = vec3(0.953, 0.929, 0.882);
group_uniforms;
/// Lamps: 0 off .. 1+ lit (brake, night). Driven from the car state.
uniform float glow : hint_range(0.0, 2.0) = 0.0;

varying float v_up;
varying vec3 v_view_pos;

void vertex() {
	v_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}

void fragment() {
	v_view_pos = VERTEX;
	ALBEDO = vec3(1.0);
	if (kind == 2) {
		EMISSION = albedo * glow;
	}
}

vec3 paint(float lit, float up, vec3 n, vec3 l, vec3 v) {
	vec3 col = lit > lit_cut ? albedo : (lit > shade_cut ? albedo * shade_mul : ink_color);
	if (lit > lit_cut) {
		// Shine lines that follow the body's curvature (shoulder line, roof edge).
		if (abs(up - streak_a) < streak_width || abs(up - streak_b) < streak_width * 0.7) col = paper;
		if (glint && dot(n, normalize(l + v)) > glint_power) col = paper;
	}
	return col;
}

void light() {
	float ndotl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	if (!LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * ndotl * 0.3;
	} else {
		// Wrapped so panels facing away from the light keep the shade band, not instant ink.
		float lit = clamp(dot(NORMAL, LIGHT) * 0.6 + 0.4, 0.0, 1.0) * ATTENUATION;
		vec3 col;
		if (kind == 1) {
			// Glass: ink with crisp diagonal white reflection streaks.
			col = ink_color * 1.4;
			float s = fract((v_view_pos.x * 0.9 + v_view_pos.y * 1.4) * 0.55);
			if ((s > 0.08 && s < 0.2) || (s > 0.3 && s < 0.34)) col = paper;
		} else if (kind == 2) {
			col = albedo * (lit > shade_cut ? 1.0 : shade_mul);
		} else if (kind == 3) {
			col = ink_color;
		} else if (kind == 4) {
			col = (v_up > -0.15 && v_up < 0.25) ? ink_color : paper * 0.9;
		} else {
			col = paint(lit, v_up, NORMAL, LIGHT, VIEW);
		}
		DIFFUSE_LIGHT = col;
	}
}
