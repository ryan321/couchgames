shader_type spatial;
uniform vec4 stone_color : source_color = vec4(0.3,0.35,0.4,1.0);
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void vertex() { world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec2 p = world_position.xz + world_position.yy*0.37;
	float grain = hash(floor(p*130.0));
	float cloud = hash(floor(p*7.0));
	float fleck = step(0.985,hash(floor(p*44.0)));
	vec2 tile = fract(world_position.xz);
	float rim = min(min(tile.x,1.0-tile.x),min(tile.y,1.0-tile.y));
	float bevel = smoothstep(0.0,0.045,rim);
	ALBEDO = stone_color.rgb*(0.82+0.15*grain+0.10*cloud-fleck*0.13)*(0.75+0.25*bevel);
	ROUGHNESS = 0.92;
}
