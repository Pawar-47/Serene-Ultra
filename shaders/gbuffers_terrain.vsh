#version 330 compatibility

uniform mat4 gbufferModelViewInverse;

out vec2 vTexCoord;
out vec2 vLightmapCoord;
out vec4 vVertexColor;
out vec3 vPlayerNormal;
out vec3 vViewPosition;

void main() {
    gl_Position = ftransform();
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vVertexColor = gl_Color;

    // Store normals in player/world-aligned space so later deferred passes
    // can compare them consistently with world-space light directions.
    vec3 viewNormal = normalize(gl_NormalMatrix * gl_Normal);
    vPlayerNormal = normalize(mat3(gbufferModelViewInverse) * viewNormal);
    vViewPosition = (gl_ModelViewMatrix * gl_Vertex).xyz;
}
