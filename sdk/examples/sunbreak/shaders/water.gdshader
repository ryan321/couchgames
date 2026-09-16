shader_type spatial;
render_mode diffuse_burley;
varying vec3 world;
void vertex() {
    world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float a = world.x*0.23+TIME*0.9;
    float b = world.z*0.3+TIME*0.7;
    VERTEX.y += sin(a)*0.15+cos(b)*0.11;
    NORMAL = normalize(vec3(-0.0345*cos(a),1.0,0.033*sin(b)));
}
void fragment() {
    float wave = sin(world.x*0.6+world.z*0.4+TIME)*sin(world.z*0.7-TIME*0.6);
    float shore = 1.0-smoothstep(63.0,82.0,length(world.xz));
    float foam = smoothstep(0.76,0.98,wave)*0.22;
    float tide = sin(length(world.xz)*1.7-TIME*0.75+sin(world.x*0.25));
    foam += pow(max(tide,0.0),16.0)*shore*0.4;
    ALBEDO = mix(vec3(0.015,0.19,0.25),vec3(0.055,0.44,0.4),shore);
    ALBEDO = mix(ALBEDO,vec3(0.68,0.84,0.72),foam);
    METALLIC = 0.55;
    ROUGHNESS = 0.18+foam*0.4;
}
