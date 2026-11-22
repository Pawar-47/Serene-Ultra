#version 330 compatibility

in vec4 at_tangent;

uniform mat4 gbufferModelViewInverse;

out vec2 vTexCoord;
out vec2 vLightmapCoord;
flat out vec4 vVertexColor;
out vec3 vPlayerNormal;
out vec3 vPlayerTangent;
flat out float vTangentHandedness;
out vec3 vViewPosition;

void main() {
    gl_Position = ftransform();
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vVertexColor = gl_Color;

    vec4 viewPosition = gl_ModelViewMatrix * gl_Vertex;
    vViewPosition = viewPosition.xyz;
    vec3 viewNormal = normalize(gl_NormalMatrix * normalize(gl_Normal));
    vPlayerNormal = normalize(mat3(gbufferModelViewInverse) * viewNormal);
    vec3 viewTangent = normalize(gl_NormalMatrix * normalize(at_tangent.xyz));
    vPlayerTangent = normalize(mat3(gbufferModelViewInverse) * viewTangent);
    vTangentHandedness = at_tangent.w < 0.0 ? -1.0 : 1.0;
}
