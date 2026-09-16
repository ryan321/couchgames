shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;
void fragment() {
	vec2 p = (UV-0.5)*2.0;
	float r = length(p);
	if (r>1.0) { discard; }
	float a = atan(p.y,p.x);
	float spiral = sin(a*3.0-r*19.0+TIME*2.4)*0.5+0.5;
	float halo = pow(r,5.0);
	vec3 deep = vec3(0.025,0.18,0.20);
	vec3 teal = vec3(0.20,0.75,0.57);
	ALBEDO = mix(deep,teal,spiral*0.55+halo*0.45);
	EMISSION = vec3(0.48,1.0,0.77)*(halo*0.9+spiral*0.12);
	ALPHA = 1.0-smoothstep(0.94,1.0,r);
}
