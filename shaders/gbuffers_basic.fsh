#version 330 compatibility

uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform float fogDensity;
uniform int fogMode;
uniform int fogShape;

in vec4 vVertexColor;
in vec3 vViewPosition;

/* RENDERTARGETS: 0,2 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outDeferredValidity;

float calculateBasicFog(float distanceToCamera) {
    if (fogMode == 9729) {
        return clamp((distanceToCamera - fogStart) / max(fogEnd - fogStart, 0.0001), 0.0, 1.0);
    }
    if (fogMode == 2048) {
        return clamp(1.0 - exp(-fogDensity * distanceToCamera), 0.0, 1.0);
    }
    if (fogMode == 2049) {
        float densityDistance = fogDensity * distanceToCamera;
        return clamp(1.0 - exp(-densityDistance * densityDistance), 0.0, 1.0);
    }
    return 0.0;
}

void main() {
    float fogDistance = (fogShape == 1) ? max(length(vViewPosition.xz), abs(vViewPosition.y)) : length(vViewPosition);
    float fogFactor = calculateBasicFog(fogDistance);
    vec3 colorLinear = pow(max(vVertexColor.rgb, vec3(0.0)), vec3(2.2));
    vec3 fogLinear = pow(max(fogColor, vec3(0.0)), vec3(2.2));
    colorLinear = mix(colorLinear, fogLinear, fogFactor);

    outColor = vec4(pow(max(colorLinear, vec3(0.0)), vec3(1.0 / 2.2)), vVertexColor.a);
    outDeferredValidity = vec4(0.0);
}
