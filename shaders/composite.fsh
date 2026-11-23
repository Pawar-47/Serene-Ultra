#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D depthtex0;
uniform sampler2D depthtex2;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform vec3 skyColor;
uniform vec3 fogColor;
uniform vec3 shadowLightPosition;
uniform float sunAngle;
uniform bool hasSkylight;

in vec2 vTexCoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

#define PBR_REFLECTION_STRENGTH 75 // [0 25 50 75 100 125 150] Opaque material reflection strength
#define PBR_REFLECTION_QUALITY 4 // [0 4 6 8] Opaque screen-space reflection steps
#define LIGHT_SHAFT_STRENGTH 45 // [0 10 20 30 40 50 60 70 80 90 100] Screen-space sunlight scattering strength
#define LIGHT_SHAFT_QUALITY 8 // [0 4 8 12] Radial light-shaft samples
#define SCREEN_GI_STRENGTH 25 // [0 5 10 15 20 25 30 35 40 45 50] Screen-space local colour bounce

#if LIGHT_SHAFT_QUALITY > 0
vec3 sampleScreenSpaceLightShafts(vec2 uv) {
    if (!hasSkylight || sin(sunAngle * 6.28318530718) <= 0.0 || LIGHT_SHAFT_STRENGTH <= 0)
        return vec3(0.0);
    vec4 sunClip = gbufferProjection * vec4(normalize(shadowLightPosition), 0.0);
    if (sunClip.w <= 0.0001) return vec3(0.0);
    vec2 sunUv = (sunClip.xy / sunClip.w) * 0.5 + 0.5;
    if (sunUv.x <= 0.0 || sunUv.x >= 1.0 || sunUv.y <= 0.0 || sunUv.y >= 1.0)
        return vec3(0.0);

    float receiverDepth = texture(depthtex2, uv).r;
    float receiverMask = 1.0 - smoothstep(0.999, 1.0, receiverDepth);
    if (receiverMask <= 0.001) return vec3(0.0);

    vec2 rayStep = (sunUv - uv) / float(LIGHT_SHAFT_QUALITY);
    vec2 sampleUv = uv;
    float accumulatedLight = 0.0;
    float decay = 1.0;
    for (int i = 0; i < LIGHT_SHAFT_QUALITY; ++i) {
        sampleUv += rayStep;
        float sampleDepth = texture(depthtex2, sampleUv).r;
        float skyVisibility = smoothstep(0.999, 1.0, sampleDepth);
        vec3 sampleColor = pow(max(texture(colortex0, sampleUv).rgb, vec3(0.0)), vec3(2.2));
        float sourceBrightness = max(max(sampleColor.r, sampleColor.g), sampleColor.b);
        accumulatedLight += max(sourceBrightness - 0.55, 0.0) * 1.8 * skyVisibility * decay;
        decay *= 0.92;
    }
    float normalizedLight = accumulatedLight / float(LIGHT_SHAFT_QUALITY);
    float sunElevation = smoothstep(0.02, 0.35, sin(sunAngle * 6.28318530718));
    return vec3(1.0, 0.72, 0.46) * normalizedLight * receiverMask
        * sunElevation * (float(LIGHT_SHAFT_STRENGTH) * 0.01) * 1.8;
}
#else
vec3 sampleScreenSpaceLightShafts(vec2 uv) { return vec3(0.0); }
#endif


vec3 sampleScreenSpaceColorBleed(
    vec2 uv,
    float centerDepth,
    vec3 centerViewPosition,
    vec3 centerNormal,
    float normalValidity
) {
#if SCREEN_GI_STRENGTH > 0
    if (centerDepth >= 0.999999 || normalValidity < 0.49) return vec3(0.0);

    vec2 texel = 1.0 / vec2(textureSize(depthtex2, 0));
    const vec2 offsets[4] = vec2[4](
        vec2(-2.0, 0.0), vec2(2.0, 0.0),
        vec2(0.0, -2.0), vec2(0.0, 2.0)
    );
    vec3 bouncedLight = vec3(0.0);
    float totalWeight = 0.0;

    for (int i = 0; i < 4; ++i) {
        vec2 sampleUv = uv + offsets[i] * texel;
        if (sampleUv.x <= 0.0 || sampleUv.x >= 1.0 ||
            sampleUv.y <= 0.0 || sampleUv.y >= 1.0) continue;

        float sampleDepth = texture(depthtex2, sampleUv).r;
        if (sampleDepth >= 0.999999) continue;

        // Only gather from the opaque surface represented by depthtex2.
        // Reject translucent/hand overlays using the all-geometry depth and
        // reject pixels without a valid G-buffer normal. This avoids pulling
        // glass, water, particles or HUD/hand colour into the opaque GI term.
        float sampleDepthAll = texture(depthtex0, sampleUv).r;
        if (abs(sampleDepthAll - sampleDepth) > 0.000001) continue;
        vec4 sampleNormalData = texture(colortex2, sampleUv);
        if (sampleNormalData.a < 0.5) continue;

        vec3 sampleNdc = vec3(sampleUv, sampleDepth) * 2.0 - 1.0;
        vec4 sampleView4 = gbufferProjectionInverse * vec4(sampleNdc, 1.0);
        vec3 sampleViewPosition = sampleView4.xyz / max(sampleView4.w, 0.0001);
        vec3 delta = sampleViewPosition - centerViewPosition;
        float sampleDistance = length(delta);
        if (sampleDistance <= 0.0001 || sampleDistance >= 1.5) continue;

        float facing = max(dot(centerNormal, delta / sampleDistance), 0.0);
        float distanceWeight = 1.0 - smoothstep(0.15, 1.5, sampleDistance);
        float depthWeight = 1.0 - smoothstep(0.05, 1.25, abs(delta.z));
        float weight = facing * distanceWeight * depthWeight;
        if (weight <= 0.001) continue;

        vec3 sampleLinear = pow(
            max(texture(colortex0, sampleUv).rgb, vec3(0.0)),
            vec3(2.2)
        );
        bouncedLight += sampleLinear * weight;
        totalWeight += weight;
    }

    if (totalWeight <= 0.001) return vec3(0.0);
    return (bouncedLight / totalWeight)
        * (float(SCREEN_GI_STRENGTH) * 0.01) * 0.12;
#else
    return vec3(0.0);
#endif
}

#if PBR_REFLECTION_QUALITY > 0
vec3 sampleOpaqueScreenReflection(vec3 viewPosition, vec3 viewNormal, out float hitConfidence) {
    const float maxDistance = 32.0;
    float stepLength = maxDistance / float(PBR_REFLECTION_QUALITY);
    vec3 incidentDirection = normalize(viewPosition);
    vec3 reflectionDirection = normalize(reflect(incidentDirection, viewNormal));
    vec3 rayOrigin = viewPosition + viewNormal * 0.06 + reflectionDirection * 0.03;

    vec3 reflectionColor = vec3(0.0);
    hitConfidence = 0.0;

    for (int i = 0; i < PBR_REFLECTION_QUALITY; ++i) {
        float travelDistance = (float(i) + 1.0) * stepLength;
        vec3 rayPosition = rayOrigin + reflectionDirection * travelDistance;
        vec4 clipPosition = gbufferProjection * vec4(rayPosition, 1.0);
        if (clipPosition.w <= 0.0001) break;

        vec3 rayNdc = clipPosition.xyz / clipPosition.w;
        vec2 sampleUV = rayNdc.xy * 0.5 + 0.5;
        if (sampleUV.x <= 0.001 || sampleUV.x >= 0.999 ||
            sampleUV.y <= 0.001 || sampleUV.y >= 0.999) {
            break;
        }

        ivec2 depthSize = textureSize(depthtex2, 0);
        ivec2 reflectionSize = textureSize(colortex4, 0);
        ivec2 depthPixel = clamp(
            ivec2(sampleUV * vec2(depthSize)),
            ivec2(0), depthSize - ivec2(1)
        );
        ivec2 reflectionPixel = clamp(
            ivec2(sampleUV * vec2(reflectionSize)),
            ivec2(0), reflectionSize - ivec2(1)
        );
        float sceneDepth = texelFetch(depthtex2, depthPixel, 0).r;
        vec4 sceneSample = texelFetch(colortex4, reflectionPixel, 0);

        // Alpha zero marks hand/translucent pixels excluded from the opaque snapshot.
        if (sceneSample.a < 0.5) continue;

        vec2 edgeDistance = min(sampleUV, vec2(1.0) - sampleUV);
        float edgeFade = smoothstep(0.0, 0.08, min(edgeDistance.x, edgeDistance.y));
        float distanceFade = 1.0 - smoothstep(20.0, maxDistance, travelDistance);

        if (sceneDepth >= 0.999999) {
            reflectionColor = sceneSample.rgb;
            hitConfidence = edgeFade * distanceFade;
            return reflectionColor;
        }

        vec3 sceneNdc = vec3(sampleUV, sceneDepth) * 2.0 - 1.0;
        vec4 sceneViewPosition4 = gbufferProjectionInverse * vec4(sceneNdc, 1.0);
        vec3 sceneViewPosition = sceneViewPosition4.xyz / max(sceneViewPosition4.w, 0.0001);
        float depthDelta = rayPosition.z - sceneViewPosition.z;

        if (depthDelta <= 0.0 && depthDelta > -stepLength * 0.75) {
            float depthConfidence = 1.0 - smoothstep(0.0, stepLength * 0.75, abs(depthDelta));
            reflectionColor = sceneSample.rgb;
            hitConfidence = edgeFade * distanceFade * depthConfidence;
            return reflectionColor;
        }
    }

    return reflectionColor;
}
#endif

#include "/lib/lighting/environment_reflection.glsl"

vec3 sampleOpaqueEnvironmentReflection(vec3 viewReflectionDirection) {
    return calculateEnvironmentReflection(
        viewReflectionDirection, shadowLightPosition, sunAngle, hasSkylight
    );
}

void main() {
    ivec2 pixel = ivec2(gl_FragCoord.xy);
    vec4 sceneColor = texelFetch(colortex0, pixel, 0);
    vec4 normalData = texelFetch(colortex2, pixel, 0);
    vec3 lightShafts = sampleScreenSpaceLightShafts(vTexCoord);
    float centerDepth = texelFetch(depthtex2, pixel, 0).r;
    vec3 centerNdc = vec3(vTexCoord, centerDepth) * 2.0 - 1.0;
    vec4 centerView4 = gbufferProjectionInverse * vec4(centerNdc, 1.0);
    vec3 centerViewPosition = centerView4.xyz / max(centerView4.w, 0.0001);
    vec3 centerNormal = normalize(mat3(gbufferModelView) * (normalData.rgb * 2.0 - 1.0));
    float currentDepthAll = texelFetch(depthtex0, pixel, 0).r;
    bool opaqueReceiver = centerDepth < 0.999999
        && abs(currentDepthAll - centerDepth) <= 0.000001
        && normalData.a >= 0.5;
    vec3 screenGi = opaqueReceiver
        ? sampleScreenSpaceColorBleed(
            vTexCoord, centerDepth, centerViewPosition, centerNormal, normalData.a
        )
        : vec3(0.0);

    // The alpha channel below 0.525 is sky/unlit geometry or a surface without
    // a meaningful PBR smoothness value. Avoid all reflection work for it.
    if (normalData.a <= 0.525 || PBR_REFLECTION_STRENGTH <= 0) {
        vec3 sceneLinearNoReflection = pow(max(sceneColor.rgb, vec3(0.0)), vec3(2.2));
        sceneLinearNoReflection += lightShafts + screenGi;
        outColor = vec4(pow(max(sceneLinearNoReflection, vec3(0.0)), vec3(1.0 / 2.2)), sceneColor.a);
        return;
    }

    // The composite pass runs after translucent gbuffers. Skip pixels where
    // water, glass, particles or the first-person hand overlay an opaque surface.
    if (!opaqueReceiver) {
        vec3 sceneLinearNoReflection = pow(max(sceneColor.rgb, vec3(0.0)), vec3(2.2));
        sceneLinearNoReflection += lightShafts;
        outColor = vec4(pow(max(sceneLinearNoReflection, vec3(0.0)), vec3(1.0 / 2.2)), sceneColor.a);
        return;
    }

    float materialSmoothness = clamp((normalData.a - 0.5) * 2.0, 0.0, 1.0);
    vec4 materialData = texelFetch(colortex3, pixel, 0);
    float materialReflectance = clamp(materialData.g, 0.0, 1.0);

    vec3 albedoLinear = pow(max(sceneColor.rgb, vec3(0.0)), vec3(2.2));
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
    vec3 f0Color = materialReflectance >= (230.0 / 255.0)
        ? albedoLinear
        : vec3(materialReflectance);
#else
    vec3 f0Color = mix(vec3(0.04), albedoLinear, materialReflectance);
#endif

    // Reuses the opaque view-space position already reconstructed above from
    // centerDepth; a second identical reconstruction would only duplicate it.
    vec3 viewPosition = centerViewPosition;
    vec3 playerNormal = normalize(normalData.rgb * 2.0 - 1.0);
    vec3 viewNormal = normalize(mat3(gbufferModelView) * playerNormal);
    vec3 viewDirection = normalize(-viewPosition);
    float nDotV = clamp(dot(viewNormal, viewDirection), 0.0, 1.0);

    vec3 reflectionDirection = normalize(reflect(normalize(viewPosition), viewNormal));
    vec3 environmentReflectionLinear = vec3(0.0);
    vec3 reflectionLinear = vec3(0.0);

#if PBR_REFLECTION_QUALITY > 0
    float hitConfidence = 0.0;
    vec3 screenReflection = sampleOpaqueScreenReflection(
        viewPosition, viewNormal, hitConfidence
    );
    vec3 screenReflectionLinear = pow(max(screenReflection, vec3(0.0)), vec3(2.2));
    if (hitConfidence < 0.999) {
        environmentReflectionLinear = sampleOpaqueEnvironmentReflection(reflectionDirection);
    }
    reflectionLinear = mix(environmentReflectionLinear, screenReflectionLinear, hitConfidence);
#else
    environmentReflectionLinear = sampleOpaqueEnvironmentReflection(reflectionDirection);
    reflectionLinear = environmentReflectionLinear;
#endif

    float fresnelFactor = 1.0 - nDotV;
    fresnelFactor *= fresnelFactor;
    fresnelFactor *= fresnelFactor * (1.0 - nDotV);
    vec3 fresnelColor = f0Color + (1.0 - f0Color) * fresnelFactor;
    vec3 reflectionWeight = clamp(
        fresnelColor * materialSmoothness * (PBR_REFLECTION_STRENGTH * 0.01),
        0.0,
        0.85
    );

    vec3 sceneLinear = pow(max(sceneColor.rgb, vec3(0.0)), vec3(2.2));
    vec3 resultLinear = mix(sceneLinear, reflectionLinear, reflectionWeight);
    resultLinear += lightShafts + screenGi;
    outColor = vec4(pow(max(resultLinear, vec3(0.0)), vec3(1.0 / 2.2)), sceneColor.a);
}
