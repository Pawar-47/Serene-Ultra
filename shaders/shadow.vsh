#version 130

#include "/lib/animation/lava_waves.glsl"
#include "/lib/animation/foliage_wind.glsl"
#include "/lib/animation/water_waves.glsl"

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
#define WATER_WAVE_STRENGTH 50 // [0 25 40 50 55 65 70 75 100 125 150 175 200] Animated water surface and normal strength
#define WATER_WAVE_SPEED 50 // [20 30 40 50 55 60 70 80 90 100 120] Water wave cycles per real-time hour

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
        vec3 stableWorld = sereneStableFoliageWorldPosition(
            cameraPositionInt, cameraPositionFract, vShadowPlayerPosition
        );
        vec2 wind = sereneFoliageWind(
            stableWorld, frameTimeCounter, float(WAVING_FOLIAGE_STRENGTH)
        );
        vShadowPlayerPosition.xz += wind;
        shadowViewPosition = gl_ModelViewMatrix * vec4(vShadowPlayerPosition, 1.0);
    }
#endif
#if LAVA_WAVE_STRENGTH > 0
    if (vShadowMaterialId == 32118 || vShadowMaterialId == 32132) {
        vec3 stableWorld = sereneStableLavaWorldPosition(
            cameraPositionInt, cameraPositionFract, vShadowPlayerPosition
        );
        if (fract(stableWorld.y + 0.005) > 0.06) {
            float lavaDisplacement = sereneLavaSurfaceDisplacement(
                stableWorld, frameTimeCounter, float(LAVA_WAVE_STRENGTH)
            );
            vShadowPlayerPosition.y += lavaDisplacement;
            shadowViewPosition = gl_ModelViewMatrix * vec4(vShadowPlayerPosition, 1.0);
        }
    }
#endif
#if WATER_WAVE_STRENGTH > 0
    if (vShadowMaterialId == 32000 && vShadowFluidRenderType > 0.5) {
        vec3 stableWaterWorld = sereneStableWaterWavePosition(
            cameraPositionInt, cameraPositionFract, vShadowPlayerPosition
        );
        float waterDisplacement = sereneWaterSurfaceDisplacement(
            stableWaterWorld, frameTimeCounter,
            float(WATER_WAVE_STRENGTH), float(WATER_WAVE_SPEED)
        );
        vShadowPlayerPosition.y += waterDisplacement;
        shadowViewPosition = gl_ModelViewMatrix * vec4(vShadowPlayerPosition, 1.0);
    }
#endif
    gl_Position = gl_ProjectionMatrix * shadowViewPosition;
}
