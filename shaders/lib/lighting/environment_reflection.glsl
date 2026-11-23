// Shared low-cost environment reflection for opaque and translucent materials.
// The celestial lobe uses Iris' view-space shadow-light direction and adds no texture reads.

vec4 sampleSereneCloudReflection(vec3 playerDirection, float sunAngleValue) {
#if CLOUD_REFLECTION_STRENGTH > 0
    float verticalMask = smoothstep(-0.10, 0.12, playerDirection.y)
        * (1.0 - smoothstep(0.78, 0.96, playerDirection.y));
    if (verticalMask <= 0.001) return vec4(0.0);
    float longitude = atan(playerDirection.z, playerDirection.x) * 0.15915494309 + 0.5;
    float latitude = asin(clamp(playerDirection.y, -1.0, 1.0)) * 0.31830988618 + 0.5;
    vec2 sphericalUv = vec2(longitude, latitude);
    float windSpeed = float(CLOUD_SPEED) * 0.01;
    vec2 wind = vec2(frameTimeCounter * 0.000018 * windSpeed,
                     -frameTimeCounter * 0.000009 * windSpeed);
    float broadNoise = texture(noisetex, sphericalUv * vec2(4.0, 3.0) + wind).r;
    float fineNoise = texture(
        noisetex,
        sphericalUv * vec2(10.92, 8.19) + wind * 1.7 + vec2(0.37, 0.19)
    ).g;
    float cloudNoise = mix(broadNoise, broadNoise * 0.72 + fineNoise * 0.28,
                           float(CLOUD_DETAIL_STRENGTH) * 0.01);
    float coverage = float(CLOUD_COVERAGE) * 0.01;
    float cloudMask = smoothstep(coverage - 0.12, min(coverage + 0.12, 0.999), cloudNoise);
    float cloudOpacity = cloudMask * verticalMask * float(CLOUD_DENSITY) * 0.01
        * 0.55 * float(CLOUD_REFLECTION_STRENGTH) * 0.01;
    float dayFactor = smoothstep(0.0, 0.30, sin(sunAngleValue * 6.28318530718));
    vec3 cloudColor = mix(vec3(0.20, 0.27, 0.43), vec3(0.94, 0.96, 1.0), dayFactor);
    return vec4(cloudColor, clamp(cloudOpacity, 0.0, 0.75));
#else
    return vec4(0.0);
#endif
}

vec3 calculateEnvironmentReflection(
    vec3 viewReflectionDirection,
    vec3 shadowLightDirection,
    float sunAngleValue,
    bool skylightAvailable
) {
    vec3 playerReflectionDirection = normalize(
        mat3(gbufferModelViewInverse) * viewReflectionDirection
    );
    float skyBlend = smoothstep(-0.12, 0.28, playerReflectionDirection.y);
    vec3 environmentSrgb = mix(fogColor, skyColor, skyBlend);
    vec3 environmentLinear = pow(max(environmentSrgb, vec3(0.0)), vec3(2.2));

    if (skylightAvailable) {
        vec4 cloudReflection = sampleSereneCloudReflection(playerReflectionDirection, sunAngleValue);
        environmentLinear = mix(environmentLinear, cloudReflection.rgb, cloudReflection.a);
        float solarElevation = sin(sunAngleValue * 6.28318530718);
        float dayFactor = smoothstep(0.0, 0.30, solarElevation);
        float celestialAlignment = max(
            dot(normalize(viewReflectionDirection), normalize(shadowLightDirection)),
            0.0
        );

        // A narrow 256th-power lobe approximates the sun/moon disk without a sky texture fetch.
        float celestialDisk = celestialAlignment;
        celestialDisk *= celestialDisk;
        celestialDisk *= celestialDisk;
        celestialDisk *= celestialDisk;
        celestialDisk *= celestialDisk;
        celestialDisk *= celestialDisk;
        celestialDisk *= celestialDisk;
        celestialDisk *= celestialDisk;

        vec3 celestialColor = mix(
            vec3(0.48, 0.60, 0.90),
            vec3(1.0, 0.86, 0.70),
            dayFactor
        );
        environmentLinear += celestialColor * celestialDisk * mix(0.32, 0.78, dayFactor);
    }

    return environmentLinear;
}
