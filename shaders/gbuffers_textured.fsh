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

float calculateTexturedFog(float distanceToCamera) {
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
    vec4 texturedColor = texture(gtexture, vTexCoord) * vVertexColor;
    if (texturedColor.a < alphaTestRef) discard;

    // This program is Iris' unlit-texture fallback (world border and particles
    // without a lighting path). Preserve the supplied texture/vertex color and
    // prevent deferred from borrowing the opaque surface normal behind it.
    vec3 colorLinear = pow(max(texturedColor.rgb, vec3(0.0)), vec3(2.2));
    float fogDistance = (fogShape == 1) ? max(length(vViewPosition.xz), abs(vViewPosition.y)) : length(vViewPosition);
    float fogFactor = calculateTexturedFog(fogDistance);
    vec3 fogColorLinear = pow(max(fogColor, vec3(0.0)), vec3(2.2));
    texturedColor.rgb = pow(max(mix(colorLinear, fogColorLinear, fogFactor), vec3(0.0)), vec3(1.0 / 2.2));

    outColor = texturedColor;
    outDeferredValidity = vec4(0.0);
}
