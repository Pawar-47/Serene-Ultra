#version 330 compatibility

uniform int renderStage;
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

float calculateLineFog(float distanceToCamera) {
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
    if (vVertexColor.a <= 0.001) discard;

    vec3 colorLinear = pow(max(vVertexColor.rgb, vec3(0.0)), vec3(2.2));
    bool skipFog = false;
    #ifdef MC_RENDER_STAGE_OUTLINE
        skipFog = skipFog || (renderStage == MC_RENDER_STAGE_OUTLINE);
    #endif
    #ifdef MC_RENDER_STAGE_DEBUG
        skipFog = skipFog || (renderStage == MC_RENDER_STAGE_DEBUG);
    #endif

    if (!skipFog) {
        float fogDistance = (fogShape == 1) ? length(vViewPosition.xz) : length(vViewPosition);
        float fogFactor = calculateLineFog(fogDistance);
        vec3 fogColorLinear = pow(max(fogColor, vec3(0.0)), vec3(2.2));
        colorLinear = mix(colorLinear, fogColorLinear, fogFactor);
    }

    outColor = vec4(pow(max(colorLinear, vec3(0.0)), vec3(1.0 / 2.2)), vVertexColor.a);
    // Lines and outlines are overlays; never reuse the terrain normal beneath.
    outDeferredValidity = vec4(0.0);
}
