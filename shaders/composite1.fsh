#version 330 compatibility

uniform sampler2D colortex0;

in vec2 vTexCoord;

/* RENDERTARGETS: 5 */
layout(location = 0) out vec4 outColor;

// Shared with the other bloom stages, which declare the strength line identically
// the way the POM and weather options already are.
#define BLOOM_STRENGTH 50 // [0 10 20 30 40 50 60 70 80 90 100] Two-scale emissive bloom strength
#define BLOOM_THRESHOLD 0.90 // [0.50 0.65 0.80 0.90 1.00 1.20 1.50 2.00] Highlight threshold for bloom

// Soft-knee highlight extraction. A hard threshold makes bloom pop in and out as
// brightness crosses the limit; the knee lets it ramp in over a small range.
vec3 extractHighlight(vec3 color) {
    float brightness = max(max(color.r, color.g), color.b);
    float knee = max(BLOOM_THRESHOLD * 0.5, 0.001);
    float soft = clamp(brightness - BLOOM_THRESHOLD + knee, 0.0, 2.0 * knee);
    soft = soft * soft / (4.0 * knee + 0.0001);
    float contribution = max(brightness - BLOOM_THRESHOLD, soft) / max(brightness, 0.0001);
    return color * contribution;
}

void main() {
#if BLOOM_STRENGTH <= 0
    // The chain still runs so its buffers hold a defined value, but it samples
    // nothing and final.fsh never adds the result.
    outColor = vec4(0.0);
#else
    // Entry point of the bloom chain: threshold the lit scene and resolve it at
    // half resolution. One destination texel covers two source texels per axis.
    vec2 sourceTexel = 1.0 / vec2(textureSize(colortex0, 0));
    vec3 accumulated = texture(colortex0, vTexCoord + vec2(-0.5, -0.5) * sourceTexel).rgb;
    accumulated += texture(colortex0, vTexCoord + vec2(0.5, -0.5) * sourceTexel).rgb;
    accumulated += texture(colortex0, vTexCoord + vec2(-0.5, 0.5) * sourceTexel).rgb;
    accumulated += texture(colortex0, vTexCoord + vec2(0.5, 0.5) * sourceTexel).rgb;
    accumulated *= 0.25;
    // The scene buffer is display-encoded; bloom extraction and all blur levels
    // operate in linear light so threshold and halo energy are physically useful.
    vec3 accumulatedLinear = pow(max(accumulated, vec3(0.0)), vec3(2.2));
    outColor = vec4(extractHighlight(accumulatedLinear), 1.0);
#endif
}
