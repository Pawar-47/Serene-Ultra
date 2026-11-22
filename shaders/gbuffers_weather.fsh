#version 330 compatibility

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform float alphaTestRef;
uniform int isEyeInWater;

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

#define WEATHER_TEX_OPACITY 100 // [25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100 110 120 130 140 150 160 170 180 190 200 220 240 260 280 300 325 350 375 400 425 450 475 500 550 600 650 700 750 800 850 900] Weather particle opacity
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
    if (weatherColor.a < max(0.1, alphaTestRef) || isEyeInWater == 3) discard;
    float rainTexOpacity = 0.25;
    float snowTexOpacity = 0.5;
    #if WEATHER_TEX_OPACITY != 100
        float opacityExponent = 100.0 / WEATHER_TEX_OPACITY;
        rainTexOpacity = pow(0.25, opacityExponent);
        snowTexOpacity = pow(0.5, opacityExponent);
    #endif
    if (weatherColor.r + weatherColor.g < 1.5) weatherColor.a *= rainTexOpacity;
    else weatherColor.a *= snowTexOpacity;

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
