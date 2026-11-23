#version 330 compatibility

uniform sampler2D colortex0;
// Bloom chain levels produced by composite1-composite4.
uniform sampler2D colortex5;
uniform sampler2D colortex7;
uniform sampler2D colortex8;
uniform sampler2D colortex10;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjectionInverse;
uniform sampler2D noisetex;
uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;
uniform int isEyeInWater;
uniform float frameTimeCounter;
uniform float nightVision;
uniform float blindness;
uniform float darknessFactor;
uniform float darknessLightFactor;

in vec2 vTexCoord;
layout(location = 0) out vec4 outColor;

#define SERENE_TAA_EXTERNAL_UNIFORMS
#include "/lib/taa_jitter.glsl"

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
#define VIBRANCE 100 // [0 25 50 75 100 125 150 175 200] Reference-style vibrance control
#define TM_WHITE_PATH 100 // [10 25 40 55 70 85 100 115 130 145 160 175 190] Highlight-to-white shoulder
#define TM_DARK_DESATURATION 25 // [0 10 20 25 35 50 65 80 100] Shadow desaturation
#define HDR_LOOK 0 // [0 1 2] 0=Neutral, 1=HDR, 2=Ultra HDR tone mapping
#define BLOOM_STRENGTH 50 // [0 10 20 30 40 50 60 70 80 90 100] Linear-light emissive bloom strength
#define BLOOM_QUALITY 2 // [0 1 2] Additional wide bloom pyramid levels
#define FXAA_ENABLED 1 // [0 1] Edge-adaptive fast approximate anti-aliasing
#define IMAGE_SHARPENING 20 // [0 10 20 30 40 50 60 70 80 90 100] Edge-aware post-AA sharpening
#define TAA_SHARPEN_STRENGTH 20 // [0 5 10 15 20 25 30 40 50] Additional sharpening after temporal resolve
#define DOF_STRENGTH 0 // [0 10 20 30 40 50 60 70 80 90 100] Depth-of-field blur strength
#define DOF_FOCUS_DISTANCE 8.0 // [2.0 4.0 6.0 8.0 10.0 12.0 16.0 24.0 32.0 48.0 64.0] Focus distance in blocks
#define DOF_FOCUS_RANGE 8.0 // [2.0 4.0 6.0 8.0 12.0 16.0 24.0 32.0] In-focus depth range in blocks
#define CHROMATIC_ABERRATION 0 // [0 10 20 30 40 50 60 70 80 90 100] Radial lens colour separation
#define VIGNETTE_STRENGTH 0 // [0 10 20 30 40 50 60 70 80 90 100] Edge darkening strength
#define FILM_GRAIN_STRENGTH 0 // [0 5 10 15 20 25 30 40 50] Animated fine-grain intensity
#define UNDERWATER_DISTORTION 55 // [0 10 20 30 40 50 60 70 80 90 100] Animated underwater refraction distortion

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



vec3 applyImageSharpening(vec3 source, vec2 uv, vec2 texelSize) {
#if IMAGE_SHARPENING > 0
    vec3 north = texture(colortex0, uv + vec2(0.0, texelSize.y)).rgb;
    vec3 south = texture(colortex0, uv - vec2(0.0, texelSize.y)).rgb;
    vec3 east = texture(colortex0, uv + vec2(texelSize.x, 0.0)).rgb;
    vec3 west = texture(colortex0, uv - vec2(texelSize.x, 0.0)).rgb;
    vec3 localAverage = (north + south + east + west) * 0.25;
    vec3 detail = source - localAverage;
    float edgeStrength = clamp(length(detail) * 3.0, 0.0, 1.0);
    float temporalSharpen = (TAA_ENABLED > 0)
        ? float(TAA_SHARPEN_STRENGTH) * 0.005 : 0.0;
    float sharpenAmount = (float(IMAGE_SHARPENING) * 0.01 + temporalSharpen)
        * mix(0.45, 1.0, edgeStrength);
    return max(source + detail * sharpenAmount * 1.35, vec3(0.0));
#else
    return source;
#endif
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
    vec3 bloom = narrowScale * 0.48 + wideScale * 0.38;
#if BLOOM_QUALITY >= 1
    vec3 veryWideScale = sampleBloomLevel(colortex8, uv, 3.0);
    bloom += veryWideScale * 0.24;
#endif
#if BLOOM_QUALITY >= 2
    vec3 ultraWideScale = sampleBloomLevel(colortex10, uv, 4.0);
    bloom += ultraWideScale * 0.14;
#endif
    return bloom;
}



vec3 applyChromaticAberration(vec3 source, vec2 uv, vec2 texelSize) {
#if CHROMATIC_ABERRATION > 0
    vec2 radial = uv - 0.5;
    float edgeWeight = smoothstep(0.08, 0.72, length(radial));
    vec2 offset = normalize(radial + vec2(0.00001)) * texelSize
        * (float(CHROMATIC_ABERRATION) * 0.018) * edgeWeight;
    float redEncoded = texture(colortex0, clamp(uv + offset, texelSize, vec2(1.0) - texelSize)).r;
    float blueEncoded = texture(colortex0, clamp(uv - offset, texelSize, vec2(1.0) - texelSize)).b;
    float redChannel = pow(max(redEncoded, 0.0), 2.2);
    float blueChannel = pow(max(blueEncoded, 0.0), 2.2);
    return vec3(redChannel, source.g, blueChannel);
#else
    return source;
#endif
}

vec3 applyVignette(vec3 source, vec2 uv) {
#if VIGNETTE_STRENGTH > 0
    vec2 centered = (uv - 0.5) * vec2(1.0, 1.0);
    float radius = length(centered);
    float vignette = smoothstep(0.28, 0.78, radius);
    float amount = float(VIGNETTE_STRENGTH) * 0.01;
    return source * (1.0 - vignette * amount * 0.65);
#else
    return source;
#endif
}

vec3 applyFilmGrain(vec3 source, vec2 uv) {
#if FILM_GRAIN_STRENGTH > 0
    vec2 noiseSize = vec2(textureSize(noisetex, 0));
    vec2 noiseUv = fract(uv * noiseSize + vec2(float(frameCounter) * 0.75487766, float(frameCounter) * 0.56984029));
    float noiseValue = texture(noisetex, noiseUv).r - 0.5;
    float grain = noiseValue * float(FILM_GRAIN_STRENGTH) * 0.0018;
    return max(source + vec3(grain), vec3(0.0));
#else
    return source;
#endif
}


vec3 applyVanillaStatusEffects(vec3 color) {
    // Match Minecraft's night-vision lift: normalize toward full brightness
    // without changing hue, and blend by Iris' transition-aware strength.
    float peak = max(max(color.r, color.g), color.b);
    vec3 nightVisionColor = color / max(peak, 0.0001);
    color = mix(color, nightVisionColor, clamp(nightVision, 0.0, 1.0));

    // Blindness and the Darkness effect suppress scene visibility. Darkness
    // uses Iris' pulsing light factor so the vanilla heartbeat modulation is
    // retained instead of applying a constant black overlay.
    float blindnessAmount = clamp(blindness, 0.0, 1.0);
    float darknessAmount = clamp(darknessFactor, 0.0, 1.0)
        * clamp(darknessLightFactor, 0.0, 1.0);
    float visibility = (1.0 - blindnessAmount)
        * (1.0 - darknessAmount * 0.85);
    return color * visibility;
}

vec3 linearToDisplayRgb(vec3 color) {
    vec3 linearColor = max(color, vec3(0.0));
    vec3 lowSegment = linearColor * 12.92;
    vec3 highSegment = 1.055 * pow(linearColor, vec3(1.0 / 2.4)) - 0.055;
    return mix(highSegment, lowSegment, lessThanEqual(linearColor, vec3(0.0031308)));
}

// Complementary-guided Lottes 2016 display transform. HDR_LOOK selects the
// highlight ceiling while exposure and contrast remain independent controls.
vec3 applyReferenceToneMap(vec3 color) {
    color = max(color, vec3(0.0));
    float initialLuminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
#if HDR_LOOK == 0
    const float hdrMaximum = 8.0;
#elif HDR_LOOK == 1
    const float hdrMaximum = 12.0;
#else
    const float hdrMaximum = 16.0;
#endif
    vec3 a = vec3(CONTRAST);
    vec3 d = vec3(1.0);
    vec3 hdrMax = vec3(hdrMaximum);
    vec3 midIn = vec3(0.25);
    vec3 midOut = vec3(0.25);

    vec3 aD = a * d;
    vec3 hdrMaxA = pow(hdrMax, a);
    vec3 hdrMaxAD = pow(hdrMax, aD);
    vec3 midInA = pow(midIn, a);
    vec3 midInAD = pow(midIn, aD);
    vec3 hm1 = hdrMaxA * midOut;
    vec3 hm2 = hdrMaxAD - midInAD;
    vec3 b = (-midInA + hm1) / (hm2 * midOut);
    vec3 c = (hdrMaxAD * midInA - hm1 * midInAD) / (hm2 * midOut);
    vec3 colorOut = pow(color, a) / (pow(color, aD) * b + c);
    colorOut = linearToDisplayRgb(colorOut);

    float darkLift = 1.0 - smoothstep(0.0, 0.1, initialLuminance);
    float contrastLift = clamp((0.55 - abs(1.05 - CONTRAST)) / 0.55, 0.0, 1.0);
    vec3 readableDarkColor = pow(color, vec3(1.0 / 2.2));
    colorOut = mix(colorOut, readableDarkColor, darkLift * 0.75 * contrastLift);

    float whitePathExponent = 2.0 - float(TM_WHITE_PATH) * 0.01;
    float modifiedLuminance = pow(max(initialLuminance / 16.0, 0.0), whitePathExponent) * 16.0;
    float whitePath = smoothstep(0.0, 16.0, modifiedLuminance);
    colorOut = mix(colorOut, vec3(1.0), whitePath);

    float darkDesaturation = 1.0 - smoothstep(0.0, 0.1, initialLuminance);
    float outputLuminance = dot(colorOut, vec3(0.2126, 0.7152, 0.0722));
    colorOut = mix(
        colorOut, vec3(outputLuminance),
        darkDesaturation * float(TM_DARK_DESATURATION) * 0.01
    );
    return clamp(colorOut, 0.0, 1.0);
}

// Complementary/BSL-style saturation and vibrance, applied after display mapping.
vec3 applyReferenceSaturation(vec3 color) {
    float saturationFactor = SATURATION + 0.07;
    float vibranceFactor = float(VIBRANCE) * 0.01;
    float grayVibrance = (color.r + color.g + color.b) / 3.0;
    float graySaturation = grayVibrance;
    if (saturationFactor < 1.0) {
        graySaturation = dot(color, vec3(0.299, 0.587, 0.114));
    }
    float minimumChannel = min(color.r, min(color.g, color.b));
    float maximumChannel = max(color.r, max(color.g, color.b));
    float saturationMask = (1.0 - (maximumChannel - minimumChannel))
        * (1.0 - maximumChannel) * grayVibrance * 5.0;
    vec3 lightness = vec3((minimumChannel + maximumChannel) * 0.5);
    color = mix(color, mix(color, lightness, 1.0 - vibranceFactor), saturationMask);
    color = mix(
        color, lightness,
        (1.0 - lightness) * (2.0 - vibranceFactor) * 0.5
            * abs(vibranceFactor - 1.0)
    );
    color = color * saturationFactor - graySaturation * (saturationFactor - 1.0);
    return clamp(color, 0.0, 1.0);
}

// Screen-space underwater distortion inspired by the reference camera effect.
// Keep the displacement sub-pixel to a few pixels, and only activate for the
// player's underwater state (not lava or powder snow).
vec2 applyUnderwaterDistortion(vec2 uv) {
#if UNDERWATER_DISTORTION > 0
    if (isEyeInWater == 1) {
        // Iris wraps frameTimeCounter after one hour. Choose integer-cycle
        // angular rates so the animated waves meet at the wrap without a jump.
        float time = frameTimeCounter;
        float waveX = sin(uv.y * 58.0 + time * 1.74532925
            + sin(uv.x * 19.0 - time * 0.54977871) * 0.8);
        float waveY = sin(uv.x * 46.0 - time * 1.24991090
            + sin(uv.y * 16.0 + time * 0.64926248) * 0.7);
        vec2 noiseUv = uv * vec2(2.6, 3.4)
            + vec2(time * 0.013888889, -time * 0.008888889);
        vec2 noise = texture(noisetex, noiseUv).rg * 2.0 - 1.0;
        vec2 displacement = vec2(waveX, waveY) * 0.00062 + noise * 0.00032;
        uv += displacement * (float(UNDERWATER_DISTORTION) * 0.01);
        vec2 halfTexel = 0.5 / vec2(textureSize(colortex0, 0));
        uv = clamp(uv, halfTexel, vec2(1.0) - halfTexel);
    }
#endif
    return uv;
}

void main() {
    vec2 sceneUv = applyUnderwaterDistortion(vTexCoord);
    vec4 scene = texture(colortex0, sceneUv);
    vec2 texelSize = 1.0 / vec2(textureSize(colortex0, 0));
#if DOF_STRENGTH > 0
    float focusDepth = getLinearViewDepth(sceneUv);
    vec3 dofColor = sampleDepthOfField(sceneUv, texelSize, focusDepth);
#else
    vec3 dofColor = scene.rgb;
#endif
#if FXAA_ENABLED > 0
    vec3 fxaaColor = max(sampleFxaa(sceneUv, texelSize), vec3(0.0));
    vec3 color = mix(fxaaColor, max(dofColor, vec3(0.0)), float(DOF_STRENGTH) * 0.01);
#else
    vec3 color = max(dofColor, vec3(0.0));
#endif

    color = applyImageSharpening(color, sceneUv, texelSize);

    // G-buffer/deferred/composite output is display-encoded. Decode once before
    // bloom addition, exposure, grading and tone mapping; re-encode only at output.
    color = pow(max(color, vec3(0.0)), vec3(2.2));

#if BLOOM_STRENGTH > 0
    vec3 bloom = sampleBloomChain(sceneUv);
    color += bloom * (float(BLOOM_STRENGTH) * 0.01);
#endif

    color = applyChromaticAberration(color, sceneUv, texelSize);

    // Exposure is expressed in photographic stops; RGB gains provide white balance.
    color *= exp2(EXPOSURE);
    color *= vec3(RED_GAIN, GREEN_GAIN, BLUE_GAIN);

    color = applyVanillaStatusEffects(color);
    color = applyReferenceToneMap(color);
    color = applyReferenceSaturation(color);
    color = applyVignette(color, vTexCoord);
    color = applyFilmGrain(color, vTexCoord);

    // The reference tone mapper already converts linear light to display RGB.
    // GAMMA is a separate creative display adjustment; 1.0 leaves it unchanged.
    color = pow(max(color, vec3(0.0)), vec3(1.0 / GAMMA));

    outColor = vec4(color, scene.a);
}
