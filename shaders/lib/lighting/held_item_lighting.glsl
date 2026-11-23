uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform int heldItemId;
uniform int heldItemId2;
uniform vec3 relativeEyePosition;

#if HELD_LIGHTING_STRENGTH > 0
float getHeldItemLightBoost(int itemId) {
    // Port the special-alpha boosts from the supplied Complementary reference.
    // Iris' heldBlockLightValue can be zero for several luminous inventory items;
    // the reference adds 15 * sqrt3(alpha), where sqrt3(x) = 1 - (1 - x)^8.
    if (itemId == 44013) return 0.8; // Lava bucket
    if (itemId == 44028 || itemId == 44029 || itemId == 44030) return 0.3; // Soul fire family
    if (itemId == 44034) return 0.1; // Glow lichen
    if (itemId == 44036 || itemId == 44040 || itemId == 44081 || itemId == 44083) return 0.05;
    if (itemId == 44053) return 0.15; // Spawner / end crystal
    if (itemId == 44085) return 0.2; // Trident
    if (itemId == 44086) return 0.175; // Experience bottle
    if (itemId == 44090 || itemId == 44092) return 0.001; // Eye of ender / glow ink
    if (itemId == 44093 || itemId == 44094 || itemId == 44095 || itemId == 44096) return 0.2;
    if (itemId == 44097) return 0.1; // Ice crystal
    return 0.0;
}

float getHeldItemLightEnergy(int itemId, int lightValue) {
    float energy = clamp(float(lightValue) / 15.0, 0.0, 1.0);
    float specialAlpha = getHeldItemLightBoost(itemId);

    if (specialAlpha > 0.0) {
        float referenceBoost = 1.0 - pow(1.0 - max(specialAlpha, 0.1), 8.0);
        energy = min(energy + referenceBoost, 1.0);
    }

    // Complementary's held-light reference explicitly promotes the lava bucket
    // to full light; preserve that special case even when its lightmap is zero.
    if (itemId == 44013) energy = 1.0;

    return energy;
}

vec3 getHeldItemLightColor(int itemId) {
    if (itemId == 44002 || itemId == 44011 || itemId == 44012 || itemId == 44015) {
        return vec3(1.0, 0.62, 0.34); // Torch, jack-o-lantern, lantern and campfire
    } else if (itemId == 44003) {
        return vec3(1.0, 1.0, 1.0); // End rod
    } else if (itemId == 44007) {
        return vec3(1.0, 0.78, 0.32); // Ochre froglight
    } else if (itemId == 44008) {
        return vec3(0.46, 1.0, 0.46); // Verdant froglight
    } else if (itemId == 44009) {
        return vec3(1.0, 0.46, 0.82); // Pearlescent froglight
    } else if (itemId == 44010 || itemId == 44094) {
        return vec3(1.0, 0.54, 0.22); // Glowstone and glowstone dust
    } else if (itemId == 44013) {
        return vec3(1.0, 0.30, 0.08); // Lava bucket
    } else if (itemId == 44018 || itemId == 44095) {
        return vec3(0.68, 0.84, 1.0); // Sea lantern and prismarine crystals
    } else if (itemId == 44019) {
        return vec3(1.0, 0.34, 0.08); // Shroomlight
    } else if (itemId == 44028 || itemId == 44029 || itemId == 44030) {
        return vec3(0.36, 0.66, 1.0); // Soul fire family
    } else if (itemId == 44034) {
        return vec3(0.40, 0.55, 0.55); // Glow lichen
    } else if (itemId == 44035) {
        return vec3(1.0, 0.16, 0.10); // Redstone torch
    } else if (itemId == 44036) {
        return vec3(0.52, 0.24, 0.72); // Amethyst cluster
    } else if (itemId == 44040) {
        return vec3(1.0, 0.48, 0.16); // Brewing stand / spectral arrow / torchflower group
    } else if (itemId == 44053) {
        return vec3(1.0, 0.18, 1.0); // Spawner / end crystal item group
    } else if (itemId == 44081 || itemId == 45112) {
        return vec3(1.0, 0.44, 0.12); // Open eyeblossom / trial key
    } else if (itemId == 44083) {
        return vec3(1.0, 0.82, 0.46); // Firefly bush
    } else if (itemId == 44084) {
        return vec3(0.52, 1.0, 0.62); // Copper torch and lantern
    } else if (itemId == 44085 || itemId == 44092) {
        return vec3(0.48, 1.0, 1.0); // Trident / drowned / glow squid / glow ink
    } else if (itemId == 44086) {
        return vec3(1.0, 1.0, 0.48); // Experience orb / bottle
    } else if (itemId == 44090) {
        return vec3(0.10, 1.0, 1.0); // Eye of ender
    } else if (itemId == 44093) {
        return vec3(1.0, 0.48, 0.18); // Blaze rod and powder
    } else if (itemId == 44096) {
        return vec3(1.0, 1.0, 1.0); // Nether star
    } else if (itemId == 44097) {
        return vec3(0.30, 0.56, 0.85); // Ice crystal
    }

    return vec3(1.0, 0.80, 0.62);
}

vec3 calculateHeldItemLighting(vec3 playerPosition) {
    float mainEnergy = getHeldItemLightEnergy(heldItemId, heldBlockLightValue);
    float offEnergy = getHeldItemLightEnergy(heldItemId2, heldBlockLightValue2);
    if (mainEnergy <= 0.0 && offEnergy <= 0.0) return vec3(0.0);

    // playerPosition is camera-relative player space. Iris' relativeEyePosition
    // moves the light origin back to the player model in third person.
    vec3 playerHeadRelativePosition = playerPosition + relativeEyePosition;
    playerHeadRelativePosition.y += 0.7;
    float lightDistance = length(playerHeadRelativePosition) * 1.33;
    float distanceAttenuation = max(1.0 - lightDistance * 0.0887, 0.0);
    float qualityStrength = float(HELD_LIGHTING_STRENGTH) * 0.01;

    float mainIntensity = mainEnergy * distanceAttenuation * qualityStrength * 0.60;
    float offIntensity = offEnergy * distanceAttenuation * qualityStrength * 0.60;

    vec3 mainLight = getHeldItemLightColor(heldItemId) * mainIntensity;
    vec3 offLight = getHeldItemLightColor(heldItemId2) * offIntensity;

    // Return squared radiance so the caller combines independent sources
    // quadratically with the existing ambient term using one sqrt.
    return mainLight * mainLight + offLight * offLight;
}
#endif
