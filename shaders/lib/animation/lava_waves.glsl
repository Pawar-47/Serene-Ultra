// Shared, large-coordinate-stable lava surface motion for the visible and shadow passes.
// The 4096-block spatial period and one-hour timer wrap use integer wave cycles,
// preventing phase seams at either wrap boundary.
vec3 sereneStableLavaWorldPosition(
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

float sereneLavaSurfaceDisplacement(
    vec3 stableWorld,
    float frameTimeCounter,
    float strength
) {
    const float TWO_PI = 6.28318530718;
    const float SPATIAL_PHASE_SCALE = TWO_PI / 4096.0;
    vec2 lavaPosition = stableWorld.xz;
    float lavaTime = mod(frameTimeCounter, 3600.0) * (TWO_PI * 60.0 / 3600.0);
    vec2 waveA = vec2(638.0, 1278.0) * SPATIAL_PHASE_SCALE;
    vec2 waveB = vec2(913.0, -456.0) * SPATIAL_PHASE_SCALE;
    float firstWave = sin(lavaTime * 0.7 - dot(lavaPosition, waveA));
    float secondWave = sin(lavaTime * 0.5 - dot(lavaPosition, waveB));
    return (firstWave + secondWave) * 0.0125 * strength * 0.01;
}
