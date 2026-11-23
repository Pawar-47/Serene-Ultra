// Shared periodic water-surface motion for the visible and shadow passes.
// Integer spatial cycles over 4096 blocks and integer hourly time cycles keep
// the displacement continuous across both large-world and frame-time wraps.
vec3 sereneStableWaterWavePosition(
    ivec3 cameraPositionInt,
    vec3 cameraPositionFract,
    vec3 playerPosition
) {
    ivec3 cameraModulo = cameraPositionInt % ivec3(4096);
    return mod(
        vec3(cameraModulo) + cameraPositionFract + playerPosition,
        vec3(4096.0)
    );
}

float sereneWaterSurfaceDisplacement(
    vec3 stableWorld,
    float frameTimeCounter,
    float strength,
    float waveSpeed
) {
    const float TWO_PI = 6.28318530718;
    const float SPATIAL_PHASE_SCALE = TWO_PI / 4096.0;
    vec2 waterPosition = stableWorld.xz;
    float waterTime = mod(frameTimeCounter, 3600.0) * (TWO_PI * waveSpeed / 3600.0);
    vec2 waveA = vec2(638.0, 1278.0) * SPATIAL_PHASE_SCALE;
    vec2 waveB = vec2(456.0, -913.0) * SPATIAL_PHASE_SCALE;
    float firstWave = sin(waterTime * 0.7 - dot(waterPosition, waveA));
    float secondWave = sin(waterTime * 0.5 - dot(waterPosition, waveB));
    return (firstWave + secondWave) * 0.0125 * strength * 0.01;
}
