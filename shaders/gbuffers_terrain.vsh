#version 330 compatibility

uniform mat4 gbufferModelViewInverse;
in vec2 mc_Entity;
in vec4 at_tangent;

out vec2 vTexCoord;
out vec2 vLightmapCoord;
out vec4 vVertexColor;
out vec3 vPlayerPosition;
out vec3 vPlayerNormal;
out vec3 vPlayerTangent;
flat out float vTangentHandedness;
flat out int vMaterialId;

void main() {
    vec4 viewPosition = gl_ModelViewMatrix * gl_Vertex;
    vPlayerPosition = (gbufferModelViewInverse * viewPosition).xyz;
    gl_Position = ftransform();
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vVertexColor = gl_Color;
    vMaterialId = int(mc_Entity.x + 0.5);

    // Store normals in player/world-aligned space so later deferred passes
    // can compare them consistently with world-space light directions.
    vec3 viewNormal = normalize(gl_NormalMatrix * normalize(gl_Normal));
    vPlayerNormal = normalize(mat3(gbufferModelViewInverse) * viewNormal);
    vec3 viewTangent = normalize(gl_NormalMatrix * normalize(at_tangent.xyz));
    vPlayerTangent = normalize(mat3(gbufferModelViewInverse) * viewTangent);
    vTangentHandedness = at_tangent.w < 0.0 ? -1.0 : 1.0;
}
