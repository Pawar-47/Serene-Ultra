#version 330 compatibility

uniform sampler2D gtexture;
uniform float alphaTestRef;

in vec2 vShadowTexCoord;
in vec4 vShadowVertexColor;

// Keep the cutoff conservative: it removes transparent texels while
// retaining thin foliage and partially transparent cutout edges.
#define SHADOW_ALPHA_CUTOFF 0.10 // [0.05 0.10 0.15 0.20 0.25 0.30 0.40 0.50] Alpha threshold for shadow casters

void main() {
    float materialAlpha = texture(gtexture, vShadowTexCoord).a * vShadowVertexColor.a;
    // Iris may raise alphaTestRef for a particular cutout render layer.
    // Retain the pack's user cutoff without bypassing Iris' per-layer threshold.
    float effectiveAlphaCutoff = max(alphaTestRef, SHADOW_ALPHA_CUTOFF);
    if (materialAlpha < effectiveAlphaCutoff) {
        discard;
    }

    // No color output: the shadow framebuffer records depth only.
}
