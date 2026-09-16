shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D ground_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_arm : filter_linear_mipmap, repeat_enable;
varying vec3 world;
void vertex() {
    world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    TANGENT = vec3(1.0,0.0,0.0);
    BINORMAL = vec3(0.0,0.0,1.0);
}
void fragment() {
    vec2 uv = world.xz * 0.42;
    vec3 tex = texture(ground_color,uv).rgb;
    vec3 large = texture(ground_color,uv*0.17).rgb;
    float variation = sin(world.x*0.38+sin(world.z*0.3))*0.15;
    float track = min(abs(world.x+sin(world.z*0.18)*0.4),abs(world.z));
    float path = 1.0-smoothstep(2.1+variation,3.9+variation,track);
    float plaza = 1.0-smoothstep(7.0,8.5,length(world.xz));
    float sandy = max(path,plaza);
    vec3 meadow = tex * vec3(0.73,1.22,0.42);
    vec3 dirt = tex * vec3(1.32,1.12,0.81);
    ALBEDO = mix(meadow,dirt,sandy)*(0.85+large*0.8);
    NORMAL_MAP = texture(ground_normal,uv).rgb;
    NORMAL_MAP_DEPTH = 0.6;
    ROUGHNESS = texture(ground_arm,uv).g;
    AO = texture(ground_arm,uv).r;
}
