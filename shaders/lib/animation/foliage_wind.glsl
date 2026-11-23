// Shared large-coordinate-stable foliage wind for terrain and shadow vertices.
// Both spatial and hourly temporal phases use integer cycle counts so the
// modulo/timer wrap cannot introduce a visible jump in the wind field.
vec3 sereneStableFoliageWorldPosition(
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

vec2 sereneFoliageWind(
    vec3 stableWorld,
    float frameTimeCounter,
    float strength
) {
    const float TWO_PI = 6.28318530718;
    const float SPATIAL_PHASE_SCALE = TWO_PI / 4096.0;
    vec2 windPosition = stableWorld.xz;
    float broadPhase = frameTimeCounter * (TWO_PI * 487.0 / 3600.0);
    float detailPhase = frameTimeCounter * (TWO_PI * 728.0 / 3600.0);
    vec2 broadFrequency = vec2(46.0, 35.0) * SPATIAL_PHASE_SCALE;
    vec2 detailFrequency = vec2(-74.0, 63.0) * SPATIAL_PHASE_SCALE;
    float broadWave = sin(dot(windPosition, broadFrequency) + broadPhase);
    float detailWave = sin(dot(windPosition, detailFrequency) - detailPhase);
    float windStrength = strength * 0.00045;
    return vec2(
        broadWave + detailWave * 0.28,
        detailWave + broadWave * 0.22
    ) * windStrength;
}
