// Shared low-cost environment reflection for opaque and translucent materials.
// The celestial lobe uses Iris' view-space shadow-light direction and adds no texture reads.
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
