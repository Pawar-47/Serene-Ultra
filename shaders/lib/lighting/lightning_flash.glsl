// Localized lightning illumination shared by deferred and forward receivers.
// lightningBoltPosition is Iris player-space; w is 1 only while a bolt is present.
vec3 sampleSereneLightningFlash(vec3 playerPosition, vec3 surfaceNormal) {
    if (lightningBoltPosition.w < 0.5 || thunderStrength <= 0.001) {
        return vec3(0.0);
    }
    vec3 toBolt = lightningBoltPosition.xyz - playerPosition;
    float boltDistance = length(toBolt);
    if (boltDistance > 112.0) return vec3(0.0);

    vec3 boltDirection = boltDistance > 0.001
        ? toBolt / boltDistance
        : normalize(surfaceNormal);
    float distanceFalloff = exp(-boltDistance * 0.032);
    float orientation = 0.22 + 0.78 * max(dot(normalize(surfaceNormal), boltDirection), 0.0);
    float flashEnergy = clamp(thunderStrength, 0.0, 1.0)
        * distanceFalloff * orientation * 1.65;
    // Lightning is near-white with a very slight cool atmospheric bias.
    return vec3(0.88, 0.94, 1.0) * flashEnergy;
}
