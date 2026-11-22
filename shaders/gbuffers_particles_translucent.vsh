#version 330 compatibility

out vec2 vTexCoord;
out vec2 vLightmapCoord;
out vec4 vVertexColor;
out vec3 vViewPosition;
out vec3 vPlayerPosition;
out vec3 vPlayerNormal;

uniform mat4 gbufferModelViewInverse;

void main() {
    gl_Position = ftransform();
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vVertexColor = gl_Color;
    vec4 viewPosition = gl_ModelViewMatrix * gl_Vertex;
    vViewPosition = viewPosition.xyz;
    vPlayerPosition = (gbufferModelViewInverse * viewPosition).xyz;
    vec3 viewNormal = normalize(gl_NormalMatrix * normalize(gl_Normal));
    vPlayerNormal = normalize(mat3(gbufferModelViewInverse) * viewNormal);
}
