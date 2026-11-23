#version 330 compatibility

#include "/lib/taa_jitter.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex14;
uniform sampler2D depthtex0;
uniform sampler2D depthtex2;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

in vec2 vTexCoord;

/* RENDERTARGETS: 0,14 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outTaaHistory;

/*
const int colortex14Format = RGBA16F;
*/

#define TAA_HISTORY_STRENGTH 85 // [0 50 65 75 85 90] Reprojected history weight
#define TAA_SHARPEN_STRENGTH 20 // [0 10 20 30 40 50] TAA resolve sharpening

vec3 sampleCurrentNeighborhoodMin(vec2 uv, vec2 texel, out vec3 neighborhoodMax) {
    vec3 neighborhoodMin = vec3(1e20);
    neighborhoodMax = vec3(-1e20);
    for (int y = -1; y <= 1; ++y) {
        for (int x = -1; x <= 1; ++x) {
            vec2 sampleUv = clamp(
                uv + vec2(float(x), float(y)) * texel,
                texel, vec2(1.0) - texel
            );
            vec3 sampleColor = pow(
                max(texture(colortex0, sampleUv).rgb, vec3(0.0)),
                vec3(2.2)
            );
            neighborhoodMin = min(neighborhoodMin, sampleColor);
            neighborhoodMax = max(neighborhoodMax, sampleColor);
        }
    }
    return neighborhoodMin;
}

void main() {
    vec4 currentColor = texture(colortex0, vTexCoord);
    float currentDepth = texture(depthtex0, vTexCoord).r;
    vec2 texel = 1.0 / vec2(textureSize(colortex0, 0));
    vec3 currentLinear = pow(max(currentColor.rgb, vec3(0.0)), vec3(2.2));
    vec3 resolvedLinear = currentLinear;
    float opaqueDepth = texture(depthtex2, vTexCoord).r;
    bool historyEligible = currentDepth >= 0.999999
        || abs(currentDepth - opaqueDepth) <= 0.000001;

#if TAA_ENABLED > 0 && TAA_HISTORY_STRENGTH > 0
    if (frameCounter > 1 && historyEligible) {
        vec2 currentJitterNdc = sereneTaaJitterNdc(frameCounter);
        vec2 unjitteredUv = vTexCoord - currentJitterNdc * 0.5;
        vec3 currentNdc = vec3(unjitteredUv, currentDepth) * 2.0 - 1.0;
        vec4 currentView4 = gbufferProjectionInverse * vec4(currentNdc, 1.0);
        vec4 previousClipPosition;

        if (currentDepth >= 0.999999) {
            vec3 currentViewRay = normalize(
                currentView4.xyz / max(abs(currentView4.w), 0.000001)
            );
            vec3 playerRay = normalize(
                mat3(gbufferModelViewInverse) * currentViewRay
            );
            vec3 previousViewRay = normalize(
                mat3(gbufferPreviousModelView) * playerRay
            );
            previousClipPosition = gbufferPreviousProjection
                * vec4(previousViewRay, 0.0);
        } else {
            vec3 currentViewPosition = currentView4.xyz
                / max(currentView4.w, 0.000001);
            vec3 playerPosition = (
                gbufferModelViewInverse * vec4(currentViewPosition, 1.0)
            ).xyz;
            vec3 previousPlayerPosition = playerPosition
                + cameraPosition - previousCameraPosition;
            vec4 previousViewPosition = gbufferPreviousModelView
                * vec4(previousPlayerPosition, 1.0);
            previousClipPosition = gbufferPreviousProjection
                * previousViewPosition;
        }

        if (previousClipPosition.w > 0.0001) {
            vec3 previousNdc = previousClipPosition.xyz
                / previousClipPosition.w;
            previousNdc.xy += sereneTaaJitterNdc((frameCounter + 7) % 8);
            vec2 previousUv = previousNdc.xy * 0.5 + 0.5;
            float expectedPreviousDepth = previousNdc.z * 0.5 + 0.5;

            if (previousUv.x > 0.001 && previousUv.x < 0.999
                && previousUv.y > 0.001 && previousUv.y < 0.999) {
                vec4 history = texture(colortex14, previousUv);
                float depthTolerance = currentDepth >= 0.999999
                    ? 0.0005
                    : max(0.00065, expectedPreviousDepth * 0.0015);
                bool depthMatches = currentDepth >= 0.999999
                    ? history.a >= 0.999
                    : abs(history.a - expectedPreviousDepth) < depthTolerance;

                if (history.a > 0.0 && depthMatches) {
                    vec3 neighborhoodMax;
                    vec3 neighborhoodMin = sampleCurrentNeighborhoodMin(
                        vTexCoord, texel, neighborhoodMax
                    );
                    vec3 clampedHistory = clamp(
                        history.rgb, neighborhoodMin, neighborhoodMax
                    );
                    float historyWeight = float(TAA_HISTORY_STRENGTH) * 0.01;
                    resolvedLinear = mix(
                        currentLinear, clampedHistory, historyWeight
                    );
                }
            }
        }
    }
#endif

#if TAA_SHARPEN_STRENGTH > 0
    vec3 neighborhoodMax;
    vec3 neighborhoodMin = sampleCurrentNeighborhoodMin(
        vTexCoord, texel, neighborhoodMax
    );
    vec3 localAverage = (neighborhoodMin + neighborhoodMax) * 0.5;
    float sharpenAmount = float(TAA_SHARPEN_STRENGTH) * 0.01 * 0.25;
    resolvedLinear = max(
        resolvedLinear + (currentLinear - localAverage) * sharpenAmount,
        vec3(0.0)
    );
#endif

    outColor = vec4(
        pow(max(resolvedLinear, vec3(0.0)), vec3(1.0 / 2.2)),
        currentColor.a
    );
    outTaaHistory = historyEligible
        ? vec4(resolvedLinear, currentDepth)
        : vec4(0.0);
}
