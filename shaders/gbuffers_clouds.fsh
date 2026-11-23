#version 130

uniform float alphaTestRef;
uniform int isEyeInWater;
uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform float fogDensity;
uniform int fogMode;
uniform int fogShape;
uniform vec3 shadowLightPosition;
uniform sampler2D noisetex;
uniform ivec3 cameraPositionInt;
uniform vec3 cameraPositionFract;
uniform float frameTimeCounter;
uniform float sunAngle;
uniform float rainStrength;
uniform bool hasSkylight;

in vec4 vVertexColor;
in vec3 vViewPosition;
in vec3 vPlayerPosition;

/* RENDERTARGETS: 0,2 */
out vec4 outColor0;
out vec4 outColor1;

#define CLOUD_SCATTERING_STRENGTH 100 // [0 25 50 75 100 125 150] Cloud daylight and silver-lining response
#define CLOUD_DETAIL_STRENGTH 35 // [0 15 25 35 50 65 80 100] World-stable cloud surface detail
#define VOLUMETRIC_CLOUDS 1 // [0 1] Use procedural clouds in the sky pass
#define CLOUD_SPEED 100 // [0 25 50 75 100 125 150] Cloud wind speed

#include "/lib/lighting/stable_world_position.glsl"

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
#if VOLUMETRIC_CLOUDS > 0
    discard; // Volumetric clouds are rendered by gbuffers_skybasic.
#endif

    // Minecraft 26.3's cloud mesh uses Iris ShaderKey.CLOUDS / POSITION_COLOR.
    // The vertex color already contains CloudColor and the generated face shading;
    // there is no cloud atlas UV in this vertex format.
    vec4 cloudColor = vVertexColor;
    if (cloudColor.a < alphaTestRef) discard;

    // Preserve the native CloudColor and per-face vertex shading. Clouds are an
    // overlay, not an opaque surface; do not reuse the terrain normal beneath them.
    vec3 cloudLinear = pow(max(cloudColor.rgb, vec3(0.0)), vec3(2.2));

    // World-stable multi-scale detail adds subtle mottling to Minecraft's native
    // POSITION_COLOR cloud faces without changing the vanilla cloud silhouette.
    // 100000 * 0.0021 = 210 base repeats; 210 * 3.1 = 651 detail repeats.
    const float CLOUD_DETAIL_WORLD_PERIOD = 100000.0;
    const float CLOUD_DETAIL_UV_SCALE = 0.0021;
    const float CLOUD_DETAIL_NOISE_SCALE = 3.1;
    vec2 stableCloudXZ = sereneStableWorldXZ(vPlayerPosition, CLOUD_DETAIL_WORLD_PERIOD);
    float cloudSpeed = float(CLOUD_SPEED) * 0.01;
    vec2 cloudDetailWind = vec2(frameTimeCounter * 0.000035 * cloudSpeed, -frameTimeCounter * 0.000022 * cloudSpeed);
    vec2 cloudDetailUv = stableCloudXZ * CLOUD_DETAIL_UV_SCALE + cloudDetailWind;
    float cloudBroadDetail = texture(noisetex, cloudDetailUv).r;
    float cloudFineDetail = texture(noisetex, cloudDetailUv * CLOUD_DETAIL_NOISE_SCALE + vec2(0.37, 0.19)).g;
    float cloudDetailNoise = cloudBroadDetail * 0.68 + cloudFineDetail * 0.32;
    float cloudDetailStrength = float(CLOUD_DETAIL_STRENGTH) * 0.01;
    float cloudSurfaceVariation = mix(
        1.0,
        mix(0.88, 1.08, smoothstep(0.18, 0.82, cloudDetailNoise)),
        cloudDetailStrength
    );
    cloudLinear *= cloudSurfaceVariation;
    cloudColor.a *= mix(
        1.0,
        mix(0.94, 1.0, smoothstep(0.25, 0.82, cloudDetailNoise)),
        cloudDetailStrength
    );

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
        : vec3(0.0);
    float viewLength = length(vViewPosition);
    vec3 viewDirection = viewLength > 0.0001
        ? -vViewPosition / viewLength
        : vec3(0.0, 1.0, 0.0);

    // Daylight fill changes cloud colour temperature, while forward scattering
    // adds a restrained silver lining toward the active sun/moon direction.
    float towardLight = max(dot(viewDirection, lightDirection), 0.0);
    float silverLining = (hasSkylight && lightLength > 0.0001)
        ? pow(towardLight, 6.0)
        : 0.0;
    float cloudQuality = float(CLOUD_SCATTERING_STRENGTH) * 0.01;
    vec3 dayTint = vec3(1.0, 0.97, 0.90);
    vec3 nightTint = vec3(0.42, 0.50, 0.72);
    vec3 weatherTint = mix(
        vec3(1.0),
        vec3(0.72, 0.78, 0.88),
        rainStrength * 0.65 * cloudQuality
    );
    vec3 lightingTint = hasSkylight
        ? mix(nightTint, dayTint, solarElevation)
        : vec3(1.0);
    cloudLinear *= mix(vec3(1.0), lightingTint, cloudQuality);
    cloudLinear *= weatherTint;
    cloudLinear += cloudLinear * silverLining
        * (0.35 + 0.45 * solarElevation) * cloudQuality * (1.0 - rainStrength * 0.65);

    float fogDistance = (fogShape == 1) ? max(length(vViewPosition.xz), abs(vViewPosition.y)) : length(vViewPosition);
    float fogFactor = calculateCloudFog(fogDistance);
    vec3 fogColorLinear = pow(max(fogColor, vec3(0.0)), vec3(2.2));
    cloudColor.rgb = pow(max(mix(cloudLinear, fogColorLinear, fogFactor), vec3(0.0)), vec3(1.0 / 2.2));

    outColor0 = cloudColor;
    outColor1 = vec4(0.0);
}
