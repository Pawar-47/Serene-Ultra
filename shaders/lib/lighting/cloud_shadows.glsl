// Stable procedural cloud-shadow approximation shared by opaque and forward passes.
// It projects a moving, multi-scale noise field onto the ground along the sun ray.
float sampleSereneCloudShadow(
    vec3 playerPosition,
    vec3 worldLightDirection,
    float dayFactor
) {
#if CLOUD_SHADOW_STRENGTH > 0
    if (dayFactor <= 0.001 || worldLightDirection.y <= 0.02) return 1.0;

    vec3 worldPosition = vec3(cameraPositionInt) + cameraPositionFract + playerPosition;
    float sunHeight = max(worldLightDirection.y, 0.20);
    vec2 cloudOffset = worldLightDirection.xz * (128.0 / sunHeight);
    float offsetLength = length(cloudOffset);
    if (offsetLength > 512.0) cloudOffset *= 512.0 / offsetLength;

    vec2 wind = vec2(frameTimeCounter * 0.00004, -frameTimeCounter * 0.000025);
    vec2 cloudUv = (worldPosition.xz + cloudOffset) * 0.0016 + wind;
    float broadNoise = texture(noisetex, cloudUv).r;
    float detailNoise = texture(noisetex, cloudUv * 2.73 + vec2(0.37, 0.19)).g;
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
