#version 330 compatibility

// Iris shader options for the initial shadow-map implementation.
const int shadowMapResolution = 1024; // [512 768 1024 1536 2048] Shadow-map resolution
const float shadowDistance = 96.0; // [64.0 96.0 128.0 160.0 192.0 224.0] Shadow draw distance in blocks

out vec2 vShadowTexCoord;
out vec4 vShadowVertexColor;

void main() {
    // Preserve the original block/entity texture coordinates so cutout
    // geometry (leaves, grass, fences and similar materials) casts shaped
    // shadows instead of opaque rectangular silhouettes.
    vShadowTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vShadowVertexColor = gl_Color;
    gl_Position = ftransform();
}
