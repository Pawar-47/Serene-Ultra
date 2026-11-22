#version 330 compatibility

uniform int renderStage;
uniform vec3 fogColor;
uniform vec3 skyColor;
uniform float sunAngle;
uniform float rainStrength;
uniform bool hasSkylight;
uniform float viewWidth;
uniform float viewHeight;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

flat in vec4 vVertexColor;

/* RENDERTARGETS: 0,2 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outDeferredValidity;

vec3 reconstructPlayerDirection() {
    vec2 screenUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
    vec4 clipPosition = vec4(screenUV * 2.0 - 1.0, gl_FragCoord.z * 2.0 - 1.0, 1.0);
    vec4 viewPosition = gbufferProjectionInverse * clipPosition;
    viewPosition.xyz /= viewPosition.w;
    return normalize(mat3(gbufferModelViewInverse) * viewPosition.xyz);
}

void main() {
    vec3 color = vVertexColor.rgb;
    float alpha = vVertexColor.a;

    vec3 playerDirection = reconstructPlayerDirection();
    float upDot = clamp(playerDirection.y, -1.0, 1.0);
    float horizonBlend = smoothstep(-0.12, 0.48, upDot);

    float solarElevation = sin(sunAngle * 6.28318530718);
    float dayFactor = smoothstep(0.0, 0.30, solarElevation);
    float twilight = hasSkylight
        ? exp(-abs(solarElevation) * 12.0) * (1.0 - rainStrength)
        : 0.0;

    bool isSky = false;
    bool isSunset = false;
    bool isStars = false;
    bool isVoid = false;
    #ifdef MC_RENDER_STAGE_SKY
        isSky = (renderStage == MC_RENDER_STAGE_SKY);
    #endif
    #ifdef MC_RENDER_STAGE_SUNSET
        isSunset = (renderStage == MC_RENDER_STAGE_SUNSET);
    #endif
    #ifdef MC_RENDER_STAGE_STARS
        isStars = (renderStage == MC_RENDER_STAGE_STARS);
    #endif
    #ifdef MC_RENDER_STAGE_VOID
        isVoid = (renderStage == MC_RENDER_STAGE_VOID);
    #endif

    if (isVoid) {
        color = vec3(0.0);
        alpha = 1.0;
    } else if (isStars) {
        float nightFactor = 1.0 - smoothstep(-0.15, 0.20, solarElevation);
        color *= nightFactor * (1.0 - 0.9 * rainStrength);
    } else if (isSky || isSunset) {
        color = mix(fogColor, skyColor, horizonBlend);
        if (isSunset) {
            float horizonBand = exp(-abs(upDot) * 10.0);
            vec3 twilightColor = mix(vec3(0.95, 0.38, 0.20), vec3(0.42, 0.34, 0.55), 1.0 - dayFactor);
            color = mix(color, twilightColor, horizonBand * twilight * 0.18);
        }
        color = mix(color, fogColor, 0.35 * rainStrength);
        alpha = 1.0;
    }

    outColor = vec4(color, alpha);
    // Sky, stars and void have no deferred surface normal. Explicitly keep
    // them outside opaque deferred lighting.
    outDeferredValidity = vec4(0.0);
}
