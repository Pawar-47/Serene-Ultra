#version 330 compatibility

uniform sampler2D gtexture;
uniform float alphaTestRef;
uniform int isEyeInWater;
uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform float fogDensity;
uniform int fogMode;
uniform int fogShape;

in vec2 vTexCoord;
in vec4 vVertexColor;
in vec3 vViewPosition;

/* RENDERTARGETS: 0,2 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outDeferredValidity;

float calculateCloudFog(float distanceToCamera) {
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
    if (isEyeInWater != 0) discard;

    // Match the reference path: texture RGB is retained; vertex alpha modulates
    // cloud opacity without tinting the cloud atlas a second time.
    vec4 cloudColor = texture(gtexture, vTexCoord) * vec4(vec3(1.0), vVertexColor.a);
    if (cloudColor.a < alphaTestRef) discard;

    // Keep vanilla cloud texture/vertex lighting intact. Clouds are an overlay,
    // not an opaque surface; do not reuse the terrain normal beneath them.
    vec3 cloudLinear = pow(max(cloudColor.rgb, vec3(0.0)), vec3(2.2));
    float fogDistance = (fogShape == 1) ? length(vViewPosition.xz) : length(vViewPosition);
    float fogFactor = calculateCloudFog(fogDistance);
    vec3 fogColorLinear = pow(max(fogColor, vec3(0.0)), vec3(2.2));
    cloudColor.rgb = pow(max(mix(cloudLinear, fogColorLinear, fogFactor), vec3(0.0)), vec3(1.0 / 2.2));

    outColor = cloudColor;
    outDeferredValidity = vec4(0.0);
}
