#version 330 compatibility

uniform sampler2D gtexture;
uniform sampler2D lightmap;

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

float calculateWeatherFog(float distanceToCamera) {
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
    vec4 weatherColor = texture(gtexture, vTexCoord) * vVertexColor;
    if (weatherColor.a <= 0.001) discard;

    // Weather is post-deferred. Preserve the vanilla lightmap and fog response
    // in a color-only forward pass without reading colortex0-3.
    vec3 lightmapLinear = pow(max(texture(lightmap, vLightmapCoord).rgb, vec3(0.0)), vec3(2.2));
    vec3 weatherLinear = pow(max(weatherColor.rgb, vec3(0.0)), vec3(2.2)) * lightmapLinear;

    float fogDistance = (fogShape == 1)
        ? length(vViewPosition.xz)
        : length(vViewPosition);
    float fogFactor = calculateWeatherFog(fogDistance);
    vec3 fogColorLinear = pow(max(fogColor, vec3(0.0)), vec3(2.2));
    weatherColor.rgb = pow(max(mix(weatherLinear, fogColorLinear, fogFactor), vec3(0.0)), vec3(1.0 / 2.2));

    outColor = weatherColor;
}
