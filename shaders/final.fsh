#version 330 compatibility

uniform sampler2D colortex0;
// Bloom chain levels produced by composite1-composite4.
uniform sampler2D colortex5;
uniform sampler2D colortex7;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjectionInverse;

in vec2 vTexCoord;
layout(location = 0) out vec4 outColor;

// User-facing color controls. These are defined only in this program so Iris
// discovers one authoritative definition for each option. BLOOM_STRENGTH is the
// exception: the bloom stages declare it identically, as the POM options do.
#define RED_GAIN 1.00 // [0.50 0.60 0.70 0.80 0.90 1.00 1.10 1.20 1.30 1.40 1.50] Red channel gain
#define GREEN_GAIN 1.00 // [0.50 0.60 0.70 0.80 0.90 1.00 1.10 1.20 1.30 1.40 1.50] Green channel gain
#define BLUE_GAIN 1.00 // [0.50 0.60 0.70 0.80 0.90 1.00 1.10 1.20 1.30 1.40 1.50] Blue channel gain
#define GAMMA 1.00 // [0.70 0.80 0.90 1.00 1.10 1.20 1.30 1.40 1.50] Display gamma correction
#define EXPOSURE 0.00 // [-2.00 -1.50 -1.00 -0.50 0.00 0.50 1.00 1.50 2.00] Exposure in stops
#define CONTRAST 1.00 // [0.60 0.70 0.80 0.90 1.00 1.10 1.20 1.30 1.40] Contrast
#define SATURATION 1.00 // [0.00 0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00] Color saturation
#define HDR_LOOK 0 // [0 1 2] 0=Neutral, 1=HDR, 2=Ultra HDR tone mapping
#define BLOOM_STRENGTH 50 // [0 10 20 30 40 50 60 70 80 90 100] Two-scale emissive bloom strength
#define FXAA_ENABLED 1 // [0 1] Edge-adaptive fast approximate anti-aliasing
#define DOF_STRENGTH 0 // [0 10 20 30 40 50 60 70 80 90 100] Depth-of-field blur strength
#define DOF_FOCUS_DISTANCE 8.0 // [2.0 4.0 6.0 8.0 10.0 12.0 16.0 24.0 32.0 48.0 64.0] Focus distance in blocks
#define DOF_FOCUS_RANGE 8.0 // [2.0 4.0 6.0 8.0 12.0 16.0 24.0 32.0] In-focus depth range in blocks

// Edge-adaptive FXAA using the final scene buffer. It avoids temporal history
// and extra render targets, so it remains usable on older integrated GPUs.
vec3 sampleFxaa(vec2 uv, vec2 texelSize) {
    vec3 center = texture(colortex0, uv).rgb;
    vec3 northWest = texture(colortex0, uv + texelSize * vec2(-1.0, -1.0)).rgb;
    vec3 northEast = texture(colortex0, uv + texelSize * vec2( 1.0, -1.0)).rgb;
    vec3 southWest = texture(colortex0, uv + texelSize * vec2(-1.0,  1.0)).rgb;
    vec3 southEast = texture(colortex0, uv + texelSize * vec2( 1.0,  1.0)).rgb;

    const vec3 lumaWeights = vec3(0.299, 0.587, 0.114);
    float lumaCenter = dot(center, lumaWeights);
    float lumaNW = dot(northWest, lumaWeights);
    float lumaNE = dot(northEast, lumaWeights);
    float lumaSW = dot(southWest, lumaWeights);
    float lumaSE = dot(southEast, lumaWeights);
    float lumaMin = min(lumaCenter, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
    float lumaMax = max(lumaCenter, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));

    vec2 direction;
    direction.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));
    direction.y =  ((lumaNW + lumaSW) - (lumaNE + lumaSE));
    float directionReduce = max(
        (lumaNW + lumaNE + lumaSW + lumaSE) * (0.25 * 0.125),
        1.0 / 128.0
    );
    float reciprocalMin = 1.0 / (min(abs(direction.x), abs(direction.y)) + directionReduce);
    direction = clamp(direction * reciprocalMin, vec2(-8.0), vec2(8.0)) * texelSize;

    vec3 sampleA = 0.5 * (
        texture(colortex0, uv + direction * (1.0 / 3.0 - 0.5)).rgb +
        texture(colortex0, uv + direction * (2.0 / 3.0 - 0.5)).rgb
    );
    vec3 sampleB = sampleA * 0.5 + 0.25 * (
        texture(colortex0, uv + direction * -0.5).rgb +
        texture(colortex0, uv + direction * 0.5).rgb
    );
    float lumaB = dot(sampleB, lumaWeights);
    return (lumaB < lumaMin || lumaB > lumaMax) ? sampleA : sampleB;
}


float getLinearViewDepth(vec2 uv) {
    float depth = texture(depthtex0, uv).r;
    if (depth >= 0.999999) return 10000.0;
    vec4 viewPosition = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    return abs(viewPosition.z / max(abs(viewPosition.w), 0.000001));
}

// Eight-tap bounded gather blur with bilateral depth rejection to reduce
// foreground/background colour bleeding at silhouettes.
vec3 sampleDepthOfField(vec2 uv, vec2 texelSize, float centerDepth) {
#if DOF_STRENGTH > 0
    float normalizedDefocus = clamp(abs(centerDepth - DOF_FOCUS_DISTANCE) / max(DOF_FOCUS_RANGE, 0.5), 0.0, 1.0);
    float radiusPixels = normalizedDefocus * float(DOF_STRENGTH) * 0.06;
    if (radiusPixels < 0.35) return texture(colortex0, uv).rgb;

    const vec2 disk[8] = vec2[8](
        vec2(0.000, -1.000), vec2(0.707, -0.707),
        vec2(1.000, 0.000), vec2(0.707, 0.707),
        vec2(0.000, 1.000), vec2(-0.707, 0.707),
        vec2(-1.000, 0.000), vec2(-0.707, -0.707)
    );
    vec3 accumulated = texture(colortex0, uv).rgb * 2.0;
    float totalWeight = 2.0;
    float depthTolerance = max(0.06, centerDepth * 0.0125);
    for (int i = 0; i < 8; ++i) {
        vec2 sampleUv = clamp(uv + disk[i] * texelSize * radiusPixels, texelSize, vec2(1.0) - texelSize);
        float sampleDepth = getLinearViewDepth(sampleUv);
        float depthWeight = exp(-abs(sampleDepth - centerDepth) / depthTolerance);
        float weight = depthWeight * (1.0 - float(i) * 0.025);
        accumulated += texture(colortex0, sampleUv).rgb * weight;
        totalWeight += weight;
    }
    return accumulated / max(totalWeight, 0.0001);
#else
    return texture(colortex0, uv).rgb;
#endif
}

// The bloom chain is built by composite1-composite4: a thresholded half-resolution
// bright pass, a separable Gaussian blur, and a quarter-resolution wide level.
// This pass only combines the finished levels, so it adds no bright-pass work.
// Four-tap tent upsampling keeps the result smooth independently of the sampler
// filter mode Iris selects for the bloom buffers.
vec3 sampleBloomLevel(sampler2D level, vec2 uv, float spread) {
    vec2 texel = spread / vec2(textureSize(level, 0));
    vec3 accumulated = texture(level, uv + vec2(-0.5, -0.5) * texel).rgb;
    accumulated += texture(level, uv + vec2(0.5, -0.5) * texel).rgb;
    accumulated += texture(level, uv + vec2(-0.5, 0.5) * texel).rgb;
    accumulated += texture(level, uv + vec2(0.5, 0.5) * texel).rgb;
    return accumulated * 0.25;
}

vec3 sampleBloomChain(vec2 uv) {
    // Tight halo from the blurred half-resolution level, wide falloff from the
    // quarter-resolution level. The wide level is dimmed by its own downsample,
    // so it is weighted higher to stay visible next to the narrow one.
    vec3 narrowScale = sampleBloomLevel(colortex5, uv, 1.0);
    vec3 wideScale = sampleBloomLevel(colortex7, uv, 2.0);
    return narrowScale * 0.60 + wideScale * 0.55;
}

vec3 applyHdrLook(vec3 color) {
#if HDR_LOOK == 1
    // Filmic shoulder: retain highlight detail while keeping output display-safe.
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((color * (a * color + b)) / (color * (c * color + d) + e), 0.0, 1.0);
#elif HDR_LOOK == 2
    // Stronger highlight compression and a slightly lifted midtone response.
    vec3 x = max(color, vec3(0.0));
    vec3 mapped = x / (1.0 + x);
    mapped = pow(mapped, vec3(0.92));
    return clamp(mapped, 0.0, 1.0);
#else
    return color;
#endif
}

void main() {
    vec4 scene = texture(colortex0, vTexCoord);
    vec2 texelSize = 1.0 / vec2(textureSize(colortex0, 0));
#if DOF_STRENGTH > 0
    float focusDepth = getLinearViewDepth(vTexCoord);
    vec3 dofColor = sampleDepthOfField(vTexCoord, texelSize, focusDepth);
#else
    vec3 dofColor = scene.rgb;
#endif
#if FXAA_ENABLED > 0
    vec3 fxaaColor = max(sampleFxaa(vTexCoord, texelSize), vec3(0.0));
    vec3 color = mix(fxaaColor, max(dofColor, vec3(0.0)), float(DOF_STRENGTH) * 0.01);
#else
    vec3 color = max(dofColor, vec3(0.0));
#endif

#if BLOOM_STRENGTH > 0
    vec3 bloom = sampleBloomChain(vTexCoord);
    color += bloom * (float(BLOOM_STRENGTH) * 0.01);
#endif

    // Exposure is expressed in photographic stops.
    color *= exp2(EXPOSURE);

    // Independent channel gains provide white-balance and creative RGB tuning.
    color *= vec3(RED_GAIN, GREEN_GAIN, BLUE_GAIN);

    // Contrast is applied around a perceptual mid-gray pivot.
    color = (color - vec3(0.18)) * CONTRAST + vec3(0.18);

    // Luminance-preserving saturation adjustment.
    float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = mix(vec3(luminance), color, SATURATION);
    color = max(color, vec3(0.0));

    color = applyHdrLook(color);

    // Gamma is an explicit user control. 1.0 leaves the tone-mapped result unchanged.
    color = pow(max(color, vec3(0.0)), vec3(1.0 / GAMMA));

    outColor = vec4(color, scene.a);
}
