#version 330 compatibility

uniform sampler2D gtexture;
uniform float alphaTestRef;

in vec2 vTexCoord;
flat in vec4 vVertexColor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
    vec4 crackColor = texture(gtexture, vTexCoord);
    if (crackColor.a < alphaTestRef) discard;

    // The crack overlay is intentionally color-only: deferred lighting uses
    // the opaque block's existing normal/lightmap beneath the overlay.
    crackColor.rgb *= vVertexColor.rgb;
    outColor = crackColor;
}
