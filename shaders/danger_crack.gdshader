shader_type canvas_item;

void fragment() {
	vec2 uv = UV;

	// Two crack lines at different angles
	float d1 = abs(fract((uv.x * 0.9 + uv.y * 1.2) * 1.7 + 0.08) - 0.5);
	float d2 = abs(fract((uv.x * 1.8 - uv.y * 0.65) * 1.45 + 0.38) - 0.5);

	float crack = clamp(
		(1.0 - smoothstep(0.0, 0.055, d1)) +
		(1.0 - smoothstep(0.0, 0.038, d2)) * 0.65,
		0.0, 1.0
	);

	// Cracks glow red-orange and pulse
	float pulse = 0.3 + 0.7 * abs(sin(TIME * 3.2));
	vec3 crack_col = vec3(1.0, 0.05, 0.0) * pulse;

	// Slightly darken the base tile so cracks pop against it
	COLOR.rgb *= 0.82;
	COLOR.rgb = mix(COLOR.rgb, crack_col, crack * 0.9);
}
