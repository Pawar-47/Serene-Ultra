#version 330 compatibility

uniform sampler2D colortex0;

in vec2 vTexCoord;
layout(location = 0) out vec4 outColor;

vec3 srgbEncode(vec3 linearColor) {
    vec3 low = linearColor * 12.92;
    vec3 high = 1.055 * pow(max(linearColor, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055;
    return mix(high, low, lessThanEqual(linearColor, vec3(0.0031308)));
}

void main() {
    vec4 scene = texture2D(colortex0, vTexCoord);
    // Neutral, non-destructive output transform. A calibrated filmic pipeline
    // will be introduced only after reference captures are available.
    outColor = vec4(scene.rgb, scene.a);
}
