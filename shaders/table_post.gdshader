shader_type canvas_item;

// Downscaled table image: posterize, film grain, vignette, a little color fringing.
void fragment() {
	vec2 uv = UV;
	vec2 centered = uv - vec2(0.5);
	float rad = length(centered * vec2(1.15, 1.0));
	vec2 shift = centered * 0.0022 * rad;
	float r = texture(TEXTURE, uv + shift).r;
	float g = texture(TEXTURE, uv).g;
	float b = texture(TEXTURE, uv - shift).b;
	vec3 col = vec3(r, g, b);
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	float levels = mix(13.0, 22.0, smoothstep(0.30, 0.78, luma));
	col = floor(col * levels + 0.5) / levels;
	vec2 cell = floor(uv * vec2(960.0, 540.0));
	float frame = floor(TIME * 10.0);
	float n = fract(sin(dot(cell + frame, vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * 0.05;
	float vig = smoothstep(0.42, 1.18, length(centered * vec2(1.22, 1.08)));
	col *= mix(1.0, 0.20, clamp(vig, 0.0, 1.0) * 0.62);
	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
