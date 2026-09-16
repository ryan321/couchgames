shader_type spatial;
render_mode cull_disabled;
uniform vec4 cloth_color : source_color = vec4(0.12,0.15,0.22,1.0);
uniform float sway = 0.0;
void vertex() {
	float hem = pow(1.0-UV.y,2.0);
	VERTEX.x += sin(TIME*2.8+UV.x*12.0)*0.024*hem*sway;
	VERTEX.z += sin(TIME*3.1+UV.x*9.0)*0.018*hem*sway;
}
void fragment() {
	float weave = sin(UV.x*950.0)*sin(UV.y*650.0);
	ALBEDO = cloth_color.rgb*(0.96+weave*0.035);
	ROUGHNESS = 0.94;
}
