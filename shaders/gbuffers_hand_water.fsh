#version 330 compatibility

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform float thunderStrength;
uniform vec4 lightningBoltPosition;

uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform float fogDensity;
uniform int fogMode;
uniform int fogShape;

in vec2 vTexCoord;
in vec2 vLightmapCoord;
in vec4 vVertexColor;
in vec3 vViewPosition;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

#include "/lib/lighting/lightning_flash.glsl"

float calculateHandWaterFog(float distanceToCamera) {
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
    vec4 handWaterColor = texture(gtexture, vTexCoord) * vVertexColor;
    if (handWaterColor.a <= 0.001) discard;

    vec3 lightmapLinear = pow(max(texture(lightmap, vLightmapCoord).rgb, vec3(0.0)), vec3(2.2));
    vec3 handWaterLinear = pow(max(handWaterColor.rgb, vec3(0.0)), vec3(2.2)) * lightmapLinear;
    handWaterLinear += sampleSereneLightningFlash(
        vec3(0.0), normalize(lightningBoltPosition.xyz + vec3(0.0, 0.0, 0.0001))
    );

    float fogDistance = (fogShape == 1)
        ? max(length(vViewPosition.xz), abs(vViewPosition.y))
        : length(vViewPosition);
    float fogFactor = calculateHandWaterFog(fogDistance);
    vec3 fogColorLinear = pow(max(fogColor, vec3(0.0)), vec3(2.2));
    handWaterColor.rgb = pow(max(mix(handWaterLinear, fogColorLinear, fogFactor), vec3(0.0)), vec3(1.0 / 2.2));

    outColor = handWaterColor;
}
