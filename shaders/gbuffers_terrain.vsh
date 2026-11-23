#version 330 compatibility

#include "/lib/taa_jitter.glsl"
#include "/lib/animation/lava_waves.glsl"

uniform mat4 gbufferModelViewInverse;
uniform ivec3 cameraPositionInt;
uniform vec3 cameraPositionFract;
uniform float frameTimeCounter;
in vec2 mc_Entity;
in vec4 at_tangent;
in vec2 mc_midTexCoord;

out vec2 vTexCoord;
out vec2 vLightmapCoord;
out vec4 vVertexColor;
out vec3 vPlayerPosition;
out vec3 vPlayerNormal;
out vec3 vPlayerTangent;
out vec3 vTangentView;
flat out vec4 vTexCoordAM;
flat out float vTangentHandedness;
flat out int vMaterialId;

#define WAVING_FOLIAGE_STRENGTH 50 // [0 10 20 35 50 65 80 100] Wind-driven foliage motion
#define LAVA_WAVE_STRENGTH 50 // [0 10 20 35 50 65 80 100] Animated lava surface vertex motion

void main() {
    vec4 viewPosition = gl_ModelViewMatrix * gl_Vertex;
    vPlayerPosition = (gbufferModelViewInverse * viewPosition).xyz;
    gl_Position = ftransform();
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vVertexColor = gl_Color;
    vMaterialId = int(mc_Entity.x + 0.5);

#if WAVING_FOLIAGE_STRENGTH > 0
    // Use camera-relative player coordinates plus Iris' split camera origin
    // for stable wind phase at large world coordinates. Existing leaf IDs are
    // reused; the additional ID covers vanilla ground and aquatic vegetation.
    if (vMaterialId == 10009 || vMaterialId == 10011 || vMaterialId == 32130) {
        vec3 stableWorld = vec3(cameraPositionInt) + cameraPositionFract + vPlayerPosition;
        vec2 windPosition = mod(stableWorld.xz, vec2(4096.0));
        float windStrength = float(WAVING_FOLIAGE_STRENGTH) * 0.00045;
        float broadWave = sin(dot(windPosition, vec2(0.071, 0.053)) + frameTimeCounter * 0.85);
        float detailWave = sin(dot(windPosition, vec2(-0.113, 0.097)) - frameTimeCounter * 1.27);
        vec2 wind = vec2(broadWave + detailWave * 0.28, detailWave + broadWave * 0.22)
            * windStrength;
        vec4 displacedViewPosition = viewPosition;
        displacedViewPosition.xyz += mat3(gl_ModelViewMatrix)
            * vec3(wind.x, 0.0, wind.y);
        gl_Position = gl_ProjectionMatrix * displacedViewPosition;
        vPlayerPosition.xz += wind;
    }
#endif

#if LAVA_WAVE_STRENGTH > 0
    // Apply a low-amplitude, world-stable fluid-surface wave to lava and lava
    // cauldron geometry. The same displacement is mirrored in shadow.vsh.
    if (vMaterialId == 32118 || vMaterialId == 32132) {
        vec3 stableWorld = sereneStableLavaWorldPosition(
            cameraPositionInt, cameraPositionFract, vPlayerPosition
        );
        if (fract(stableWorld.y + 0.005) > 0.06) {
            float lavaDisplacement = sereneLavaSurfaceDisplacement(
                stableWorld, frameTimeCounter, float(LAVA_WAVE_STRENGTH)
            );
            vec4 displacedViewPosition = viewPosition;
            displacedViewPosition.xyz += mat3(gl_ModelViewMatrix)
                * vec3(0.0, lavaDisplacement, 0.0);
            gl_Position = gl_ProjectionMatrix * displacedViewPosition;
            viewPosition = displacedViewPosition;
            vPlayerPosition.y += lavaDisplacement;
        }
    }
#endif

    // Store normals in player/world-aligned space so later deferred passes
    // can compare them consistently with world-space light directions.
    vec3 viewNormal = normalize(gl_NormalMatrix * normalize(gl_Normal));
    vPlayerNormal = normalize(mat3(gbufferModelViewInverse) * viewNormal);
    vec3 viewTangent = normalize(gl_NormalMatrix * normalize(at_tangent.xyz));
    vPlayerTangent = normalize(mat3(gbufferModelViewInverse) * viewTangent);
    vec3 viewBitangent = normalize(cross(viewTangent, viewNormal))
        * (at_tangent.w < 0.0 ? -1.0 : 1.0);
    vTangentView = vec3(
        dot(viewTangent, viewPosition.xyz),
        dot(viewBitangent, viewPosition.xyz),
        dot(viewNormal, viewPosition.xyz)
    );

    // Iris mc_midTexCoord is the per-quad sprite centre. Preserve the atlas
    // rectangle so displaced samples cannot leak into adjacent texture tiles.
    vec2 midTexCoord = (gl_TextureMatrix[0] * vec4(mc_midTexCoord, 0.0, 1.0)).st;
    vec2 texMinMidCoord = vTexCoord - midTexCoord;
    vTexCoordAM = vec4(
        min(vTexCoord, midTexCoord - texMinMidCoord),
        abs(texMinMidCoord) * 2.0
    );
    vTangentHandedness = at_tangent.w < 0.0 ? -1.0 : 1.0;
    applySereneTaaJitter(gl_Position);
}
