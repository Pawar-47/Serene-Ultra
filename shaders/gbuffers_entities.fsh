#version 330 compatibility

uniform sampler2D texture;

in vec2 vTexCoord;
in vec4 vVertexColor;
in vec3 vViewNormal;

layout(location = 0) out vec4 outColor;

void main() {
    vec4 albedo = texture2D(texture, vTexCoord) * vVertexColor;
    if (albedo.a < 0.1) discard;
    outColor = albedo;
}
