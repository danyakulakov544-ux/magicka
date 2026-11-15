shader_type canvas_item;

// Light CRT: scanlines, a warm grade, vignette. The pixel world stays nearest-filtered.
void fragment() {
	vec3 col = texture(TEXTURE, UV).rgb;
	float scan = step(0.62, fract(UV.y * 220.0));
	col *= mix(0.84, 1.0, scan);
	vec2 d = UV - vec2(0.5);
	float vig = smoothstep(0.35, 1.2, length(d * vec2(1.05, 1.2)));
	col *= mix(1.0, 0.4, clamp(vig, 0.0, 1.0));
	col *= vec3(1.05, 0.96, 0.88);
	COLOR = vec4(col, 1.0);
}
