#version 330 compatibility

uniform sampler2D gtexture;
uniform float alphaTestRef;

in vec2 vTexCoord;
in vec4 vVertexColor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
    vec4 albedo = texture(gtexture, vTexCoord) * vVertexColor;
    if (albedo.a < alphaTestRef) discard;
    outColor = albedo;
}
