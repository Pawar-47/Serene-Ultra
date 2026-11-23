#version 330 compatibility

uniform sampler2D colortex5;

in vec2 vTexCoord;

/* RENDERTARGETS: 7 */
layout(location = 0) out vec4 outColor;

// Declared identically in every bloom stage; Iris treats it as one option.
#define BLOOM_STRENGTH 50 // [0 10 20 30 40 50 60 70 80 90 100] Two-scale emissive bloom strength

void main() {
#if BLOOM_STRENGTH <= 0
    outColor = vec4(0.0);
#else
    // Second bloom scale: resolve the already-blurred half-resolution level down
    // to quarter resolution. The wider footprint is what produces the soft halo
    // around large bright regions, which a single-scale five-tap blur cannot do.
    vec2 sourceTexel = 1.0 / vec2(textureSize(colortex5, 0));
    vec3 accumulated = texture(colortex5, vTexCoord + vec2(-0.5, -0.5) * sourceTexel).rgb;
    accumulated += texture(colortex5, vTexCoord + vec2(0.5, -0.5) * sourceTexel).rgb;
    accumulated += texture(colortex5, vTexCoord + vec2(-0.5, 0.5) * sourceTexel).rgb;
    accumulated += texture(colortex5, vTexCoord + vec2(0.5, 0.5) * sourceTexel).rgb;
    outColor = vec4(accumulated * 0.25, 1.0);
#endif
}
