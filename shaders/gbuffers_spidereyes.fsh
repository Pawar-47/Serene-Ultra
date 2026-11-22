#version 330 compatibility

uniform sampler2D gtexture;
uniform float alphaTestRef;

in vec2 vTexCoord;
in vec4 vVertexColor;

/* RENDERTARGETS: 0,2 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outDeferredValidity;

void main() {
    vec4 emissiveColor = texture(gtexture, vTexCoord) * vVertexColor;
    if (emissiveColor.a < alphaTestRef) discard;

    // Spider/enderman/dragon eyes are emissive overlays. Mark the pixel as
    // ineligible for opaque deferred lighting so the body normal behind it
    // cannot darken the emissive eye texture.
    outColor = emissiveColor;
    outDeferredValidity = vec4(0.0);
}
