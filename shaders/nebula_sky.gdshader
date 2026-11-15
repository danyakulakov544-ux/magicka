shader_type sky;

// Bright, slowly drifting space.
// Sky photos: StumpyStrust, "Space skyboxes", CC0
// https://opengameart.org/content/space-skyboxes-0
// Nebula motion adapted from "Nebula Stars Clouds" by grimbeef, CC0
// https://godotshaders.com/shader/nebula-stars-clouds/

uniform sampler2D sky_cool : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sky_warm : source_color, filter_linear_mipmap, repeat_enable;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

mat2 rot(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat2(vec2(c, -s), vec2(s, c));
}

// Same layered flow as the CC0 nebula shader, with value noise instead of a texture.
float flow(vec2 p, float t) {
	float z = 2.0;
	float rz = 0.02;
	vec2 bp = p;
	for (float i = 1.0; i < 6.0; i += 1.0) {
		p += t * 0.35;
		bp += t * 0.22;
		vec2 gr = vec2(
			noise(p + vec2(0.09, 0.0)) - noise(p - vec2(0.09, 0.0)),
			noise(p + vec2(0.0, 0.09)) - noise(p - vec2(0.0, 0.09))
		);
		gr *= rot(t * 0.15 - (0.05 * p.x + 0.03 * p.y));
		p += gr * 0.85;
		rz += (sin(noise(p) * 6.0) * 0.45 + 0.62) / z;
		p = mix(bp, p, 0.92);
		z *= 1.45;
		p *= 2.0;
		bp *= 1.85;
	}
	return rz;
}

vec3 hue_shift(vec3 col, float h) {
	vec3 k = vec3(0.57735);
	float c = cos(h);
	return col * c + cross(k, col) * sin(h) + k * dot(k, col) * (1.0 - c);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float lon = atan(dir.z, dir.x);
	float lat = asin(clamp(dir.y, -1.0, 1.0));
	vec2 uv = vec2(fract(lon / TAU + 0.5 + TIME * 0.004), lat / PI + 0.5);

	vec3 cool = texture(sky_cool, uv).rgb;
	vec3 warm = texture(sky_warm, uv).rgb;
	float crossfade = 0.35 + 0.45 * sin(TIME * 0.14);
	vec3 photo = mix(cool, warm, crossfade);
	photo = pow(max(photo, vec3(0.02)), vec3(0.78));
	photo = hue_shift(photo, sin(TIME * 0.09) * 0.9);
	photo *= vec3(0.95, 1.05, 1.2);

	float t = TIME * 0.05;
	vec2 p = vec2(lon, lat) * 1.35 + vec2(t * 0.35, t * 0.12);
	float a = flow(p, t);
	float b = flow(p * 1.4 + vec2(2.2, 1.1), t + 1.7);
	vec3 magenta = vec3(1.0, 0.18, 0.55);
	vec3 cyan = vec3(0.1, 0.85, 1.0);
	vec3 gold = vec3(1.0, 0.72, 0.15);
	vec3 violet = vec3(0.55, 0.2, 1.0);
	// Spatially separated hues. Mixing them in one pixel turns the sky gray.
	float band = sin(a * 1.6 + TIME * 0.18);
	float band2 = sin(b * 1.35 - TIME * 0.12);
	vec3 tint = mix(magenta, cyan, smoothstep(-0.2, 0.85, band));
	tint = mix(tint, gold, smoothstep(0.15, 0.95, band2));
	tint = mix(tint, violet, smoothstep(0.45, 1.0, sin(a * 0.7 + b + TIME * 0.08)) * 0.65);

	float star_cell = 180.0;
	vec2 cell = floor(vec2(lon, lat) * star_cell);
	float r = hash21(cell);
	float stars = 0.0;
	if (r > 0.965) {
		float tw = 0.4 + 0.6 * sin(TIME * (1.2 + r * 5.0) + r * 80.0);
		stars = tw * (0.7 + r);
	}

	float up = smoothstep(-0.35, 0.8, dir.y);
	vec3 col = photo * tint * mix(1.35, 1.7, up);
	col += tint * 0.22;
	col += vec3(stars);
	COLOR = col;
}
