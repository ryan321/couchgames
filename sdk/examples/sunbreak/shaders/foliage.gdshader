shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(0.32,0.48,0.13,1.0);
uniform float wind_strength = 0.15;
varying vec3 world;
varying float shade;
void vertex() {
    world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    float phase = world.x*0.8 + world.z*0.6 + TIME*1.3;
    VERTEX.x += sin(phase)*wind_strength*max(0.0,VERTEX.y);
    VERTEX.z += cos(phase*0.8)*wind_strength*0.5*max(0.0,VERTEX.y);
    shade = INSTANCE_CUSTOM.r;
}
void fragment() {
    ALBEDO = base_color.rgb * mix(0.7,1.3,shade);
    ROUGHNESS = 0.86;
    BACKLIGHT = base_color.rgb*0.25;
    NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
}
