#version 330 compatibility

uniform sampler2D colortex6;

in vec2 vTexCoord;

/* RENDERTARGETS: 5 */
layout(location = 0) out vec4 outColor;

// Declared identically in every bloom stage; Iris treats it as one option.
#define BLOOM_STRENGTH 50 // [0 10 20 30 40 50 60 70 80 90 100] Two-scale emissive bloom strength

void main() {
#if BLOOM_STRENGTH <= 0
    outColor = vec4(0.0);
#else
    // Vertical half of the separable blur. It reads the horizontal result and
    // writes the half-resolution level that final.fsh samples.
    vec2 texel = 1.0 / vec2(textureSize(colortex6, 0));
    float tapSpacing = 1.5 * texel.y;

    vec3 accumulation = texture(colortex6, vTexCoord).rgb * 0.2270270270;
    accumulation += texture(colortex6, vTexCoord + vec2(0.0, tapSpacing)).rgb * 0.1945945946;
    accumulation += texture(colortex6, vTexCoord - vec2(0.0, tapSpacing)).rgb * 0.1945945946;
    accumulation += texture(colortex6, vTexCoord + vec2(0.0, tapSpacing * 2.0)).rgb * 0.1216216216;
    accumulation += texture(colortex6, vTexCoord - vec2(0.0, tapSpacing * 2.0)).rgb * 0.1216216216;
    accumulation += texture(colortex6, vTexCoord + vec2(0.0, tapSpacing * 3.0)).rgb * 0.0540540541;
    accumulation += texture(colortex6, vTexCoord - vec2(0.0, tapSpacing * 3.0)).rgb * 0.0540540541;
    accumulation += texture(colortex6, vTexCoord + vec2(0.0, tapSpacing * 4.0)).rgb * 0.0162162162;
    accumulation += texture(colortex6, vTexCoord - vec2(0.0, tapSpacing * 4.0)).rgb * 0.0162162162;
    outColor = vec4(accumulation, 1.0);
#endif
}
