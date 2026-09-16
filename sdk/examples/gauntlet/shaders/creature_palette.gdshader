shader_type spatial;
render_mode cull_back;
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.74;
	METALLIC = 0.12;
	// Only the authored bright eye/gem colors emit; cloth, hide and armor stay opaque.
	float light = smoothstep(0.68,0.85,max(COLOR.r,max(COLOR.g,COLOR.b)));
	EMISSION = COLOR.rgb*light*0.8;
}
