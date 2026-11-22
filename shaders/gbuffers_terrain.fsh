#version 330 compatibility

uniform sampler2D texture;

in vec2 vTexCoord;
in vec4 vVertexColor;
in vec3 vViewNormal;
in vec3 vViewPosition;

layout(location = 0) out vec4 outColor;

void main() {
    vec4 albedo = texture2D(texture, vTexCoord) * vVertexColor;
    if (albedo.a < 0.1) discard;

    // Preserve texture-authored color and alpha in the geometry pass.
    // Lighting is composed in the deferred stage; do not bake a destructive
    // low-quality approximation into terrain materials.
    outColor = albedo;
}
