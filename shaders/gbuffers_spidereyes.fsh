#version 330 compatibility

uniform sampler2D gtexture;
uniform float alphaTestRef;
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

float calculateEyeFog(float distanceToCamera) {
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
    vec4 emissiveColor = texture(gtexture, vTexCoord) * vVertexColor;
    if (emissiveColor.a < alphaTestRef) discard;

    // Spider/enderman/dragon eyes are emissive overlays. Mark the pixel as
    // ineligible for opaque deferred lighting so the body normal behind it
    // cannot darken the emissive eye texture.
    float fogDistance = (fogShape == 1) ? length(vViewPosition.xz) : length(vViewPosition);
    float fogFactor = calculateEyeFog(fogDistance);
    vec3 eyeLinear = pow(max(emissiveColor.rgb, vec3(0.0)), vec3(2.2));
    vec3 fogColorLinear = pow(max(fogColor, vec3(0.0)), vec3(2.2));
    emissiveColor.rgb = pow(max(mix(eyeLinear, fogColorLinear, fogFactor), vec3(0.0)), vec3(1.0 / 2.2));

    outColor = emissiveColor;
    outDeferredValidity = vec4(0.0);
}
