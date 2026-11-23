#version 330 compatibility

uniform int renderStage;
uniform float sunAngle;
uniform float rainStrength;
uniform bool hasSkylight;
uniform float viewWidth;
uniform float viewHeight;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 shadowLightPosition;

in vec3 vVertexColorLinear;
in float vVertexAlpha;
flat in vec3 vFogLinear;
flat in vec3 vSkyLinear;

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

#define SKY_ATMOSPHERE_STRENGTH 100 // [0 25 50 75 100 125 150] Atmospheric scattering intensity

vec3 calculateAtmosphericScattering(
    vec3 viewDirection,
    float upDot,
    float solarElevation,
    float rain
) {
    float lightLength = length(shadowLightPosition);
    if (lightLength < 0.0001 || !hasSkylight) return vec3(0.0);

    vec3 lightDirection = shadowLightPosition / lightLength;
    float viewLightCosine = clamp(dot(viewDirection, lightDirection), -1.0, 1.0);
    float cosineSquared = viewLightCosine * viewLightCosine;

    // Rayleigh scattering is broad and blue-weighted; the Henyey-Greenstein
    // lobe approximates the narrow forward scattering of atmospheric aerosols.
    float rayleighPhase = 0.75 * (1.0 + cosineSquared);
    const float mieAnisotropy = 0.76;
    float mieDenominator = max(
        1.0 + mieAnisotropy * mieAnisotropy
            - 2.0 * mieAnisotropy * viewLightCosine,
        0.08
    );
    float miePhase = (1.0 - mieAnisotropy * mieAnisotropy)
        / (12.5663706144 * pow(mieDenominator, 1.5));

    float dayFactor = smoothstep(-0.08, 0.20, solarElevation);
    float nightFactor = 1.0 - dayFactor;
    float twilight = exp(-abs(solarElevation) * 10.0) * (1.0 - rain);
    float horizonPath = pow(
        1.0 - smoothstep(0.02, 0.98, abs(upDot)),
        2.0
    );

    vec3 rayleighColor = mix(
        vec3(0.018, 0.028, 0.065),
        vec3(0.095, 0.22, 0.48),
        dayFactor
    );
    float rayleighEnergy = (0.025 + 0.055 * dayFactor)
        * (0.45 + 0.55 * horizonPath);
    vec3 mieColor = mix(
        vec3(0.10, 0.13, 0.20),
        vec3(1.0, 0.52, 0.25),
        dayFactor
    );
    float mieEnergy = miePhase * (0.004 + 0.012 * dayFactor)
        * (0.35 + 0.65 * horizonPath);

    // A warm horizon band is strongest while the sun crosses the horizon,
    // but fades under heavy rain so the vanilla biome fog remains authoritative.
    vec3 twilightColor = mix(
        vec3(0.24, 0.16, 0.28),
        vec3(1.0, 0.25, 0.08),
        dayFactor
    );
    float twilightEnergy = twilight * horizonPath
        * (0.08 + 0.08 * (1.0 - abs(viewLightCosine)));

    vec3 scattering = rayleighColor * rayleighPhase * rayleighEnergy;
    scattering += mieColor * mieEnergy;
    scattering += twilightColor * twilightEnergy;
    scattering *= 1.0 - rain * 0.72;
    scattering *= float(SKY_ATMOSPHERE_STRENGTH) * 0.01;

    // Preserve a restrained blue night atmosphere without making the End or
    // dimensions without skylight inherit an overworld sky.
    scattering *= mix(1.0, 0.45, nightFactor);
    return scattering;
}

void main() {
    vec3 colorLinear = vVertexColorLinear;
    float alpha = vVertexAlpha;

    float upDot = 0.0;
    float horizonBlend = 0.0;
    vec3 viewDirection = vec3(0.0, 1.0, 0.0);

    float solarElevation = sin(sunAngle * 6.28318530718);
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

    if (isSky || isSunset) {
        vec3 playerDirection = reconstructPlayerDirection();
        viewDirection = normalize(mat3(gbufferModelView) * playerDirection);
        upDot = clamp(playerDirection.y, -1.0, 1.0);
        horizonBlend = smoothstep(-0.12, 0.48, upDot);
    }

    if (isVoid) {
        colorLinear = vec3(0.0);
        alpha = 1.0;
    } else if (isStars) {
        float nightFactor = 1.0 - smoothstep(-0.15, 0.20, solarElevation);
        colorLinear *= nightFactor * (1.0 - 0.9 * rainStrength);
    } else if (isSky || isSunset) {
        colorLinear = mix(vFogLinear, vSkyLinear, horizonBlend);
        colorLinear += calculateAtmosphericScattering(
            viewDirection, upDot, solarElevation, rainStrength
        );
        if (isSunset) {
            float horizonBand = exp(-abs(upDot) * 10.0);
            float dawnSide = step(0.0, cos(sunAngle * 6.28318530718));
            vec3 dawnColor = vec3(1.0, 0.195, 0.055);
            vec3 duskColor = vec3(0.64, 0.083, 0.144);
            vec3 twilightColor = mix(duskColor, dawnColor, dawnSide);
            colorLinear = mix(colorLinear, twilightColor, horizonBand * twilight * 0.18);
        }
        colorLinear = mix(colorLinear, vFogLinear, 0.35 * rainStrength);

        // Low-cost active-celestial glare, adapted from Complementary's
        // low-quality sky path. shadowLightPosition is Iris view space.
        if (hasSkylight) {
            float celestialAlignment = max(
                dot(viewDirection, normalize(shadowLightPosition)),
                0.0
            );
            float glareScatter = 3.0 * (2.0 - clamp(celestialAlignment * 1000.0, 0.0, 1.0));
            float glarePower = pow(celestialAlignment, glareScatter);
            const float glareVisibility = 0.075;
            float celestialGlare = glareVisibility
                / max(1.0 - (1.0 - glareVisibility) * glarePower, 0.075)
                - glareVisibility;
            celestialGlare *= 0.7 * (1.0 - 0.8 * rainStrength);

            float dayFactor = smoothstep(-0.05, 0.25, solarElevation);
            float noonFactor = smoothstep(0.35, 0.9, solarElevation);
            vec3 nightGlareColor = vec3(0.38, 0.40, 0.50) * 0.3;
            vec3 dayGlareColor = vec3(1.5, 0.7, 0.3)
                + vec3(0.0, 0.5, 0.5) * noonFactor;
            vec3 glareColor = mix(nightGlareColor, dayGlareColor, dayFactor);
            colorLinear += glareColor * celestialGlare;
        }
        alpha = 1.0;
    }

    // Subtle screen-space dither prevents visible banding in smooth sky gradients.
    if (isSky || isSunset) {
        float dither = fract(
            sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453
        );
        colorLinear += vec3((dither - 0.5) / 255.0);
    }
    vec3 outputColor = pow(max(colorLinear, vec3(0.0)), vec3(1.0 / 2.2));
    outColor = vec4(outputColor, alpha);
    // Sky, stars and void have no deferred surface normal. Explicitly keep
    // them outside opaque deferred lighting.
    outDeferredValidity = vec4(0.0);
}
