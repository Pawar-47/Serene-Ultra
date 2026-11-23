// Stable procedural cloud-shadow approximation shared by opaque and forward passes.
// It projects a moving, multi-scale noise field onto the ground along the sun ray.
#include "/lib/lighting/stable_world_position.glsl"
float sampleSereneCloudShadow(
    vec3 playerPosition,
    vec3 worldLightDirection,
    float dayFactor
) {
#if CLOUD_SHADOW_STRENGTH > 0
    if (dayFactor <= 0.001 || worldLightDirection.y <= 0.02) return 1.0;

    // 62500 * 0.0016 = 100 base repeats; 100 * 2.73 = 273 detail repeats.
    const float CLOUD_SHADOW_WORLD_PERIOD = 62500.0;
    const float CLOUD_SHADOW_UV_SCALE = 0.0016;
    const float CLOUD_SHADOW_DETAIL_SCALE = 2.73;
    vec2 stableWorldXZ = sereneStableWorldXZ(playerPosition, CLOUD_SHADOW_WORLD_PERIOD);
    float sunHeight = max(worldLightDirection.y, 0.20);
    float cloudHeightAboveReceiver = max(float(CLOUD_ALTITUDE) - worldPosition.y, 16.0);
    vec2 cloudOffset = worldLightDirection.xz * (cloudHeightAboveReceiver / sunHeight);
    float offsetLength = length(cloudOffset);
    if (offsetLength > 512.0) cloudOffset *= 512.0 / offsetLength;

    float cloudSpeed = float(CLOUD_SPEED) * 0.01;
    vec2 wind = vec2(frameTimeCounter * 0.00004 * cloudSpeed, -frameTimeCounter * 0.000025 * cloudSpeed);
    vec2 cloudWorldXZ = mod(stableWorldXZ + cloudOffset, vec2(CLOUD_SHADOW_WORLD_PERIOD));
    vec2 cloudUv = cloudWorldXZ * CLOUD_SHADOW_UV_SCALE + wind;
    float broadNoise = texture(noisetex, cloudUv).r;
    float detailNoise = texture(noisetex, cloudUv * CLOUD_SHADOW_DETAIL_SCALE + vec2(0.37, 0.19)).g;
    float cloudNoise = broadNoise * 0.72 + detailNoise * 0.28;

    float coverage = mix(0.58, 0.46, clamp(rainStrength, 0.0, 1.0));
    float cloudDensity = smoothstep(coverage - 0.16, coverage + 0.16, cloudNoise);
    float cloudOpacity = mix(0.32, 0.62, clamp(rainStrength, 0.0, 1.0));
    float strength = float(CLOUD_SHADOW_STRENGTH) * 0.01;
    return clamp(
        1.0 - cloudDensity * cloudOpacity * strength * clamp(dayFactor, 0.0, 1.0),
        0.35, 1.0
    );
#else
    return 1.0;
#endif
}
