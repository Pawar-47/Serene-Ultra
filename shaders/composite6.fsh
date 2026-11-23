#version 330 compatibility

uniform sampler2D colortex7;

in vec2 vTexCoord;

/* RENDERTARGETS: 8 */
layout(location = 0) out vec4 outColor;

#define BLOOM_STRENGTH 50 // [0 10 20 30 40 50 60 70 80 90 100] Emissive bloom strength
#define BLOOM_QUALITY 2 // [0 1 2] Number of additional wide bloom scales

void main() {
#if BLOOM_STRENGTH <= 0 || BLOOM_QUALITY < 1
    outColor = vec4(0.0);
#else
    vec2 sourceTexel = 1.0 / vec2(textureSize(colortex7, 0));
    vec3 accumulated = texture(colortex7, vTexCoord + vec2(-0.5, -0.5) * sourceTexel).rgb;
    accumulated += texture(colortex7, vTexCoord + vec2(0.5, -0.5) * sourceTexel).rgb;
    accumulated += texture(colortex7, vTexCoord + vec2(-0.5, 0.5) * sourceTexel).rgb;
    accumulated += texture(colortex7, vTexCoord + vec2(0.5, 0.5) * sourceTexel).rgb;
    outColor = vec4(accumulated * 0.25, 1.0);
#endif
}
