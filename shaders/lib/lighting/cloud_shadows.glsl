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
    float receiverWorldY = float(cameraPositionInt.y) + cameraPositionFract.y + playerPosition.y;
    float cloudHeightAboveReceiver = max(float(CLOUD_ALTITUDE) - receiverWorldY, 16.0);
    vec2 cloudOffset = worldLightDirection.xz * (cloudHeightAboveReceiver / sunHeight);
    float offsetLength = length(cloudOffset);
    if (offsetLength > 512.0) cloudOffset *= 512.0 / offsetLength;

    float cloudSpeed = float(CLOUD_SPEED) * 0.01;
    vec2 wind = vec2(frameTimeCounter * 0.00004 * cloudSpeed, -frameTimeCounter * 0.000025 * cloudSpeed);
    vec2 cloudWorldXZ = mod(stableWorldXZ + cloudOffset, vec2(CLOUD_SHADOW_WORLD_PERIOD));
    vec2 cloudUv = cloudWorldXZ * CLOUD_SHADOW_UV_SCALE + wind + vec2(0.0, 0.11);
    float broadNoise = texture(noisetex, cloudUv).r;
    float detailNoise = texture(noisetex, cloudUv * CLOUD_SHADOW_DETAIL_SCALE + vec2(0.37, 0.19)).g;
    float detailStrength = float(CLOUD_DETAIL_STRENGTH) * 0.01;
    float cloudNoise = mix(
        broadNoise,
        broadNoise * 0.72 + detailNoise * 0.28,
        detailStrength
    );

    float coverage = mix(
        float(CLOUD_COVERAGE) * 0.01,
        float(CLOUD_COVERAGE) * 0.01 - 0.08,
        clamp(rainStrength, 0.0, 1.0)
    );
    float cloudDensity = smoothstep(
        coverage, min(coverage + 0.22, 0.999), cloudNoise
    ) * (1.0 + rainStrength * 0.25);
    float cloudOpacity = cloudDensity * float(CLOUD_DENSITY) * 0.01 * 0.55;
    float strength = float(CLOUD_SHADOW_STRENGTH) * 0.01;
    return clamp(
        1.0 - cloudOpacity * strength * clamp(dayFactor, 0.0, 1.0),
        0.35, 1.0
    );
#else
    return 1.0;
#endif
}
