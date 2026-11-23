#version 330 compatibility

#include "/lib/taa_jitter.glsl"
#include "/lib/animation/water_waves.glsl"

uniform mat4 gbufferModelViewInverse;
uniform ivec3 cameraPositionInt;
uniform vec3 cameraPositionFract;
uniform float frameTimeCounter;

out vec2 vTexCoord;
flat out vec2 vMidTexCoord;
flat out vec2 vTexHalfSize;
out vec2 vLightmapCoord;
out vec4 vVertexColor;
out vec3 vPlayerNormal;
out vec3 vPlayerPosition;
out vec3 vViewPosition;
out vec3 vViewNormal;
out vec3 vPlayerTangent;
flat out float vTangentHandedness;
flat out int vMaterialId;
flat out float vFluidRenderType;

in vec2 mc_Entity;
in vec2 mc_midTexCoord;
in vec4 at_tangent;

#define WATER_WAVE_STRENGTH 100 // [0 25 50 75 100 125 150 175 200] Animated water surface and normal strength
#define WATER_WAVE_SPEED 60 // [15 30 45 60 75 90 120] Water wave cycles per real-time hour

void main() {
    vec4 viewPosition = gl_ModelViewMatrix * gl_Vertex;
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vMidTexCoord = (gl_TextureMatrix[0] * vec4(mc_midTexCoord, 0.0, 1.0)).xy;
    vTexHalfSize = abs(vTexCoord - vMidTexCoord);
    vLightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vVertexColor = gl_Color;

    // Convert current geometry position and normal to player-aligned space.
    // Water runs after deferred, so it must be lit forward in this program.
    vPlayerPosition = (gbufferModelViewInverse * viewPosition).xyz;
    vMaterialId = int(mc_Entity.x + 0.5);
    if (vMaterialId == 10049) vMaterialId = 32001; // Water cauldron
    vFluidRenderType = mc_Entity.y;
#if WATER_WAVE_STRENGTH > 0
    if (vMaterialId == 32000 && vFluidRenderType > 0.5) {
        vec3 stableWorld = sereneStableWaterWavePosition(
            cameraPositionInt, cameraPositionFract, vPlayerPosition
        );
        float waterDisplacement = sereneWaterSurfaceDisplacement(
            stableWorld, frameTimeCounter,
            float(WATER_WAVE_STRENGTH), float(WATER_WAVE_SPEED)
        );
        viewPosition.xyz += mat3(gl_ModelViewMatrix) * vec3(0.0, waterDisplacement, 0.0);
        vPlayerPosition.y += waterDisplacement;
    }
#endif
    gl_Position = gl_ProjectionMatrix * viewPosition;
    vViewPosition = viewPosition.xyz;

    vec3 viewNormal = normalize(gl_NormalMatrix * normalize(gl_Normal));
    vViewNormal = viewNormal;
    vPlayerNormal = normalize(mat3(gbufferModelViewInverse) * viewNormal);
    vec3 viewTangent = normalize(gl_NormalMatrix * normalize(at_tangent.xyz));
    vPlayerTangent = normalize(mat3(gbufferModelViewInverse) * viewTangent);
    vTangentHandedness = at_tangent.w < 0.0 ? -1.0 : 1.0;
    applySereneTaaJitter(gl_Position);
}
