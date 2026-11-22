#version 330 compatibility

#define WAVING_RAIN // Animate rain and snow geometry

out vec2 vTexCoord;
out vec2 vLightmapCoord;
out vec4 vVertexColor;
out vec3 vViewPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform ivec2 eyeBrightnessSmooth;

void main() {
    vec4 playerPosition = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;

    #ifdef WAVING_RAIN
        float rainWavingFactor = clamp(float(eyeBrightnessSmooth.y) / 240.0, 0.0, 1.0) * rainStrength;
        playerPosition.xz += rainWavingFactor * (0.4 * playerPosition.y + 0.2)
            * vec2(sin(frameTimeCounter * 0.3) + 0.5, sin(frameTimeCounter * 0.5) * 0.5);
        playerPosition.xz *= 1.0 - 0.08 * playerPosition.y * rainWavingFactor;
    #endif

    vec4 viewPosition = gbufferModelView * playerPosition;
    gl_Position = gl_ProjectionMatrix * viewPosition;
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vVertexColor = gl_Color;
    vViewPosition = viewPosition.xyz;
}
