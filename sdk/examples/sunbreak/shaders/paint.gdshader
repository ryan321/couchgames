shader_type spatial;
render_mode diffuse_burley;
uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D detail_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world;
varying vec3 weights;
void vertex() {
    world = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    weights = pow(abs((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz),vec3(4.0));
    weights /= max(dot(weights,vec3(1.0)),0.001);
}
void fragment() {
    vec3 p = world*3.0;
    float grain = dot(texture(detail_map,p.yz).rgb,vec3(0.333))*weights.x+dot(texture(detail_map,p.xz).rgb,vec3(0.333))*weights.y+dot(texture(detail_map,p.xy).rgb,vec3(0.333))*weights.z;
    float wear = 0.9+grain*0.35;
    float damp = mix(0.78,1.0,smoothstep(0.3,1.1,world.y));
    ALBEDO = tint.rgb*wear*damp;
    ROUGHNESS = 0.82;
    vec3 bump = texture(normal_map,p.yz).rgb*weights.x+texture(normal_map,p.xz).rgb*weights.y+texture(normal_map,p.xy).rgb*weights.z;
    NORMAL = normalize(NORMAL+(bump-vec3(0.5,0.5,1.0))*0.07);
}
