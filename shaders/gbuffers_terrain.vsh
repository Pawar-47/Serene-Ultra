#version 330 compatibility

uniform mat4 gbufferModelViewInverse;
in vec2 mc_Entity;

out vec2 vTexCoord;
out vec2 vLightmapCoord;
out vec4 vVertexColor;
out vec3 vPlayerNormal;
flat out int vMaterialId;

void main() {
    gl_Position = ftransform();
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vVertexColor = gl_Color;
    vMaterialId = int(mc_Entity.x + 0.5);

    // Store normals in player/world-aligned space so later deferred passes
    // can compare them consistently with world-space light directions.
    vec3 viewNormal = normalize(gl_NormalMatrix * normalize(gl_Normal));
    vPlayerNormal = normalize(mat3(gbufferModelViewInverse) * viewNormal);
}
