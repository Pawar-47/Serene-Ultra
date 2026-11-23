#version 330 compatibility

uniform float alphaTestRef;
uniform int isEyeInWater;
uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform float fogDensity;
uniform int fogMode;
uniform int fogShape;
uniform vec3 shadowLightPosition;
uniform float sunAngle;
uniform float rainStrength;
uniform bool hasSkylight;

in vec4 vVertexColor;
in vec3 vViewPosition;

/* RENDERTARGETS: 0,2 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outDeferredValidity;

#define CLOUD_SCATTERING_STRENGTH 100 // [0 25 50 75 100 125 150] Cloud daylight and silver-lining response

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

    // Minecraft 26.3's cloud mesh uses Iris ShaderKey.CLOUDS / POSITION_COLOR.
    // The vertex color already contains CloudColor and the generated face shading;
    // there is no cloud atlas UV in this vertex format.
    vec4 cloudColor = vVertexColor;
    if (cloudColor.a < alphaTestRef) discard;

    // Preserve the native CloudColor and per-face vertex shading. Clouds are an
    // overlay, not an opaque surface; do not reuse the terrain normal beneath them.
    vec3 cloudLinear = pow(max(cloudColor.rgb, vec3(0.0)), vec3(2.2));

    // The POSITION_COLOR cloud mesh has no per-pixel normal; its vertex color already
    // carries engine face shading and CloudColor. Add only bounded exposure and
    // forward-scattering terms using uniforms this pass already has.
    // shadowLightPosition is the view-space direction of the active celestial body
    // (sun by day, moon by night), normalised here with a guard so dimensions
    // without a celestial body cannot produce a NaN.
    float solarElevation = hasSkylight
        ? smoothstep(-0.15, 0.35, sin(sunAngle * 6.28318530718))
        : 0.0;
    float lightLength = length(shadowLightPosition);
    vec3 lightDirection = lightLength > 0.0001
        ? shadowLightPosition / lightLength
        : vec3(0.0, 1.0, 0.0);
    float viewLength = length(vViewPosition);
    vec3 viewDirection = viewLength > 0.0001
        ? -vViewPosition / viewLength
        : vec3(0.0, 1.0, 0.0);

    // Daylight fill changes cloud colour temperature, while forward scattering
    // adds a restrained silver lining toward the active sun/moon direction.
    float towardLight = max(dot(viewDirection, lightDirection), 0.0);
    float silverLining = pow(towardLight, 6.0);
    float cloudQuality = float(CLOUD_SCATTERING_STRENGTH) * 0.01;
    vec3 dayTint = vec3(1.0, 0.97, 0.90);
    vec3 nightTint = vec3(0.42, 0.50, 0.72);
    vec3 weatherTint = mix(
        vec3(1.0),
        vec3(0.72, 0.78, 0.88),
        rainStrength * 0.65 * cloudQuality
    );
    vec3 lightingTint = mix(nightTint, dayTint, solarElevation);
    cloudLinear *= mix(vec3(1.0), lightingTint, cloudQuality);
    cloudLinear *= weatherTint;
    cloudLinear += cloudLinear * silverLining
        * (0.35 + 0.45 * solarElevation) * cloudQuality * (1.0 - rainStrength * 0.65);

    float fogDistance = (fogShape == 1) ? max(length(vViewPosition.xz), abs(vViewPosition.y)) : length(vViewPosition);
    float fogFactor = calculateCloudFog(fogDistance);
    vec3 fogColorLinear = pow(max(fogColor, vec3(0.0)), vec3(2.2));
    cloudColor.rgb = pow(max(mix(cloudLinear, fogColorLinear, fogFactor), vec3(0.0)), vec3(1.0 / 2.2));

    outColor = cloudColor;
    outDeferredValidity = vec4(0.0);
}
