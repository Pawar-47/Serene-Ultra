#version 330 compatibility

uniform mat4 gbufferModelViewInverse;

out vec2 vTexCoord;
flat out vec2 vMidTexCoord;
flat out vec2 vTexHalfSize;
out vec2 vLightmapCoord;
out vec4 vVertexColor;
out vec3 vPlayerNormal;
out vec3 vPlayerPosition;
out vec3 vViewPosition;
out vec3 vViewNormal;
flat out int vMaterialId;
flat out float vFluidRenderType;

in vec2 mc_Entity;
in vec2 mc_midTexCoord;

void main() {
    gl_Position = ftransform();
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vMidTexCoord = (gl_TextureMatrix[0] * vec4(mc_midTexCoord, 0.0, 1.0)).xy;
    vTexHalfSize = abs(vTexCoord - vMidTexCoord);
    vLightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vVertexColor = gl_Color;

    // Convert current geometry position and normal to player-aligned space.
    // Water runs after deferred, so it must be lit forward in this program.
    vec4 viewPosition = gl_ModelViewMatrix * gl_Vertex;
    vPlayerPosition = (gbufferModelViewInverse * viewPosition).xyz;
    vViewPosition = viewPosition.xyz;
    vMaterialId = int(mc_Entity.x + 0.5);
    vFluidRenderType = mc_Entity.y;

    vec3 viewNormal = normalize(gl_NormalMatrix * normalize(gl_Normal));
    vViewNormal = viewNormal;
    vPlayerNormal = normalize(mat3(gbufferModelViewInverse) * viewNormal);
}
