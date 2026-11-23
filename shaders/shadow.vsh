#version 130

uniform mat4 shadowModelViewInverse;
uniform ivec3 cameraPositionInt;
uniform vec3 cameraPositionFract;
uniform float frameTimeCounter;

// Iris shader options for the initial shadow-map implementation.
const int shadowMapResolution = 1024; // [512 768 1024 1536 2048] Shadow-map resolution
const float shadowDistance = 96.0; // [64.0 96.0 128.0 160.0 192.0 224.0] Shadow draw distance in blocks
const float shadowDistanceRenderMul = 1.0; // Cull shadow geometry outside shadowDistance

out vec2 vShadowTexCoord;
out vec4 vShadowVertexColor;
out vec3 vShadowPlayerPosition;
flat out int vShadowMaterialId;
flat out float vShadowFluidRenderType;

in vec2 mc_Entity;

#define WAVING_FOLIAGE_STRENGTH 50 // [0 10 20 35 50 65 80 100] Wind-driven foliage motion
#define LAVA_WAVE_STRENGTH 50 // [0 10 20 35 50 65 80 100] Animated lava surface vertex motion

void main() {
    // Preserve the original block/entity texture coordinates so cutout
    // geometry (leaves, grass, fences and similar materials) casts shaped
    // shadows instead of opaque rectangular silhouettes.
    vShadowTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vShadowVertexColor = gl_Color;
    vec4 shadowViewPosition = gl_ModelViewMatrix * gl_Vertex;
    vShadowPlayerPosition = (shadowModelViewInverse * shadowViewPosition).xyz;
    vShadowMaterialId = int(mc_Entity.x + 0.5);
    if (vShadowMaterialId == 10049) vShadowMaterialId = 32001; // Water cauldron
    vShadowFluidRenderType = mc_Entity.y;

#if WAVING_FOLIAGE_STRENGTH > 0
    // Apply the identical world-space wind field used by gbuffers_terrain so
    // animated foliage does not detach from its shadow silhouette.
    if (vShadowMaterialId == 10009 || vShadowMaterialId == 10011 || vShadowMaterialId == 32130) {
        vec3 stableWorld = vec3(cameraPositionInt) + cameraPositionFract + vShadowPlayerPosition;
        vec2 windPosition = mod(stableWorld.xz, vec2(4096.0));
        float windStrength = float(WAVING_FOLIAGE_STRENGTH) * 0.00045;
        float broadWave = sin(dot(windPosition, vec2(0.071, 0.053)) + frameTimeCounter * 0.85);
        float detailWave = sin(dot(windPosition, vec2(-0.113, 0.097)) - frameTimeCounter * 1.27);
        vec2 wind = vec2(broadWave + detailWave * 0.28, detailWave + broadWave * 0.22)
            * windStrength;
        vShadowPlayerPosition.xz += wind;
        shadowViewPosition = gl_ModelViewMatrix * vec4(vShadowPlayerPosition, 1.0);
    }
#endif
#if LAVA_WAVE_STRENGTH > 0
    if (vShadowMaterialId == 32118 || vShadowMaterialId == 32132) {
        vec3 stableWorld = vec3(cameraPositionInt) + cameraPositionFract + vShadowPlayerPosition;
        if (fract(stableWorld.y + 0.005) > 0.06) {
            vec2 lavaPosition = mod(stableWorld.xz, vec2(4096.0));
            float lavaTime = mod(frameTimeCounter, 3600.0) * 0.10471975512;
            float waveA = sin(lavaTime * 0.7 - dot(lavaPosition, vec2(0.9790, 1.9602)));
            float waveB = sin(lavaTime * 0.5 - dot(lavaPosition, vec2(1.4008, -0.6995)));
            float lavaDisplacement = (waveA + waveB)
                * 0.0125 * float(LAVA_WAVE_STRENGTH) * 0.01;
            vShadowPlayerPosition.y += lavaDisplacement;
            shadowViewPosition = gl_ModelViewMatrix * vec4(vShadowPlayerPosition, 1.0);
        }
    }
#endif
    gl_Position = gl_ProjectionMatrix * shadowViewPosition;
}
