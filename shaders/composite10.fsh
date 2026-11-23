#version 330 compatibility

uniform sampler2D colortex10;

in vec2 vTexCoord;

/* RENDERTARGETS: 11 */
layout(location = 0) out vec4 outColor;

#define BLOOM_STRENGTH 50 // [0 10 20 30 40 50 60 70 80 90 100] Emissive bloom strength
#define BLOOM_QUALITY 2 // [0 1 2] Number of additional wide bloom scales

void main() {
#if BLOOM_STRENGTH <= 0 || BLOOM_QUALITY < 2
    outColor = vec4(0.0);
#else
    vec2 texel = 1.0 / vec2(textureSize(colortex10, 0));
    float tapSpacing = 1.5 * texel.x;
    vec3 accumulation = texture(colortex10, vTexCoord).rgb * 0.2270270270;
    accumulation += texture(colortex10, vTexCoord + vec2(tapSpacing, 0.0)).rgb * 0.1945945946;
    accumulation += texture(colortex10, vTexCoord - vec2(tapSpacing, 0.0)).rgb * 0.1945945946;
    accumulation += texture(colortex10, vTexCoord + vec2(tapSpacing * 2.0, 0.0)).rgb * 0.1216216216;
    accumulation += texture(colortex10, vTexCoord - vec2(tapSpacing * 2.0, 0.0)).rgb * 0.1216216216;
    accumulation += texture(colortex10, vTexCoord + vec2(tapSpacing * 3.0, 0.0)).rgb * 0.0540540541;
    accumulation += texture(colortex10, vTexCoord - vec2(tapSpacing * 3.0, 0.0)).rgb * 0.0540540541;
    accumulation += texture(colortex10, vTexCoord + vec2(tapSpacing * 4.0, 0.0)).rgb * 0.0162162162;
    accumulation += texture(colortex10, vTexCoord - vec2(tapSpacing * 4.0, 0.0)).rgb * 0.0162162162;
    outColor = vec4(accumulation, 1.0);
#endif
}
