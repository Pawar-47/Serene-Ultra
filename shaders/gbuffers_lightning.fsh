#version 330 compatibility

uniform sampler2D gtexture;
uniform vec4 entityColor;
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

float calculateLightningFog(float distanceToCamera) {
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
    vec4 beamColor = texture(gtexture, vTexCoord) * vVertexColor;
    if (beamColor.a <= 0.001) discard;

    vec3 beamLinear = pow(max(beamColor.rgb, vec3(0.0)), vec3(2.2));
    vec3 tintLinear = pow(max(entityColor.rgb, vec3(0.0)), vec3(2.2));
    beamLinear = mix(beamLinear, tintLinear, entityColor.a);

    float fogDistance = (fogShape == 1) ? max(length(vViewPosition.xz), abs(vViewPosition.y)) : length(vViewPosition);
    float fogFactor = calculateLightningFog(fogDistance);
    vec3 fogColorLinear = pow(max(fogColor, vec3(0.0)), vec3(2.2));
    beamColor.rgb = pow(max(mix(beamLinear, fogColorLinear, fogFactor), vec3(0.0)), vec3(1.0 / 2.2));

    outColor = beamColor;
    // Iris renders lightning/dragon beams before deferred; the separate
    // gbuffers_basic pass supplies beam depth. Do not shade this overlay with
    // the unrelated entity normal underneath it.
    outDeferredValidity = vec4(0.0);
}
