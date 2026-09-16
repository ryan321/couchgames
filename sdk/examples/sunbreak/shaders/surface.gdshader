shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D arm_map : filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float scale = 0.6;
varying vec3 world;
varying vec3 weights;
void vertex() {
    world = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    weights = abs((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz);
    weights = pow(weights,vec3(4.0));
    weights /= max(dot(weights,vec3(1.0)),0.001);
}
void fragment() {
    vec3 p = world * scale;
    vec3 tex = texture(albedo_map,p.yz).rgb*weights.x + texture(albedo_map,p.xz).rgb*weights.y + texture(albedo_map,p.xy).rgb*weights.z;
    ALBEDO = tex*tint.rgb;
    vec3 orm = texture(arm_map,p.yz).rgb*weights.x + texture(arm_map,p.xz).rgb*weights.y + texture(arm_map,p.xy).rgb*weights.z;
    ROUGHNESS = orm.g;
    AO = orm.r;
    // Fine rock detail without tangent seams at triplanar transitions.
    vec3 bump = texture(normal_map,p.yz).rgb*weights.x + texture(normal_map,p.xz).rgb*weights.y + texture(normal_map,p.xy).rgb*weights.z;
    NORMAL = normalize(NORMAL+(bump-vec3(0.5,0.5,1.0))*0.22);
}
