#version 330 compatibility

#include "/lib/taa_jitter.glsl"

uniform mat4 gbufferModelViewInverse;

out vec2 vTexCoord;
out vec2 vLightmapCoord;
out vec4 vVertexColor;
out vec3 vPlayerNormal;
out vec3 vPlayerPosition;
out vec3 vViewPosition;

void main() {
    gl_Position = ftransform();
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vVertexColor = gl_Color;

    vec4 viewPosition = gl_ModelViewMatrix * gl_Vertex;
    vPlayerPosition = (gbufferModelViewInverse * viewPosition).xyz;
    vViewPosition = viewPosition.xyz;

    vec3 viewNormal = normalize(gl_NormalMatrix * normalize(gl_Normal));
    vPlayerNormal = normalize(mat3(gbufferModelViewInverse) * viewNormal);
    applySereneTaaJitter(gl_Position);
}
