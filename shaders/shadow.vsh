#version 330 compatibility

uniform mat4 shadowModelViewInverse;

// Iris shader options for the initial shadow-map implementation.
const int shadowMapResolution = 1024; // [512 768 1024 1536 2048] Shadow-map resolution
const float shadowDistance = 96.0; // [64.0 96.0 128.0 160.0 192.0 224.0] Shadow draw distance in blocks
const float shadowDistanceRenderMul = 1.0; // Cull shadow geometry outside shadowDistance

out vec2 vShadowTexCoord;
out vec4 vShadowVertexColor;
out vec3 vShadowPlayerPosition;
flat out int vShadowMaterialId;
flat out float vShadowFluidRenderType;

in vec2 mc_Entity;

void main() {
    // Preserve the original block/entity texture coordinates so cutout
    // geometry (leaves, grass, fences and similar materials) casts shaped
    // shadows instead of opaque rectangular silhouettes.
    vShadowTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vShadowVertexColor = gl_Color;
    vec4 shadowViewPosition = gl_ModelViewMatrix * gl_Vertex;
    vShadowPlayerPosition = (shadowModelViewInverse * shadowViewPosition).xyz;
    vShadowMaterialId = int(mc_Entity.x + 0.5);
    if (vShadowMaterialId == 10049) vShadowMaterialId = 32001; // Water cauldron
    vShadowFluidRenderType = mc_Entity.y;
    gl_Position = ftransform();
}
