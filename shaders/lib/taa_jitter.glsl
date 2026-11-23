// Shared Halton 2,3 sub-pixel projection jitter for temporal anti-aliasing.
#define TAA_ENABLED 1 // [0 1] Enable jittered temporal anti-aliasing
uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;

float sereneHalton(int index, int base) {
    float result = 0.0;
    float fraction = 1.0;
    int value = index;
    for (int i = 0; i < 8; ++i) {
        if (value <= 0) break;
        fraction /= float(base);
        result += fraction * float(value - (value / base) * base);
        value /= base;
    }
    return result;
}

vec2 sereneTaaJitterNdc(int frameIndex) {
    int sampleIndex = (frameIndex % 8) + 1;
    vec2 jitterPixels = vec2(
        sereneHalton(sampleIndex, 2),
        sereneHalton(sampleIndex, 3)
    ) - 0.5;
    return jitterPixels * 2.0 / max(vec2(viewWidth, viewHeight), vec2(1.0));
}

void applySereneTaaJitter(inout vec4 clipPosition) {
#if TAA_ENABLED > 0
    clipPosition.xy += sereneTaaJitterNdc(frameCounter) * clipPosition.w;
#endif
}
