#version 130

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
uniform sampler2D noisetex;
uniform ivec3 cameraPositionInt;
uniform vec3 cameraPositionFract;
uniform float frameTimeCounter;
uniform float thunderStrength;
uniform vec4 lightningBoltPosition;

in vec3 vVertexColorLinear;
in float vVertexAlpha;
flat in vec3 vFogLinear;
flat in vec3 vSkyLinear;

/* RENDERTARGETS: 0,2 */
out vec4 outColor0;
out vec4 outColor1;

vec3 reconstructPlayerDirection() {
    vec2 screenUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
    vec4 clipPosition = vec4(screenUV * 2.0 - 1.0, gl_FragCoord.z * 2.0 - 1.0, 1.0);
    vec4 viewPosition = gbufferProjectionInverse * clipPosition;

    // A sky ray can map to a homogeneous direction at infinity (w ~= 0).
    // In that case xyz is already the ray direction; never divide by zero.
    vec3 viewRay = abs(viewPosition.w) > 0.00001
        ? viewPosition.xyz / viewPosition.w
        : viewPosition.xyz;
    vec3 playerRay = mat3(gbufferModelViewInverse) * viewRay;
    float rayLength = length(playerRay);
    return rayLength > 0.00001
        ? playerRay / rayLength
        : vec3(0.0, 1.0, 0.0);
}

#define SKY_ATMOSPHERE_STRENGTH 100 // [0 25 50 75 100 125 150] Atmospheric scattering intensity
#define VOLUMETRIC_CLOUDS 1 // [0 1] Use procedural clouds in the sky pass instead of native flat clouds
#define VOLUMETRIC_CLOUD_QUALITY 12 // [6 8 12 16 20] Volumetric cloud raymarch samples
#define CLOUD_ALTITUDE 192 // [128 160 192 224 256] Cloud layer centre height in blocks
#define CLOUD_THICKNESS 64 // [32 48 64 80 96] Cloud layer vertical thickness
#define CLOUD_COVERAGE 55 // [35 45 55 65 75] Procedural cloud coverage
#define CLOUD_DENSITY 65 // [25 40 55 70 85 100] Volumetric cloud optical density
#define CLOUD_SPEED 100 // [0 25 50 75 100 125 150] Cloud wind speed
#define CLOUD_SCATTERING_STRENGTH 100 // [0 25 50 75 100 125 150] Cloud lighting and silver-lining response
#define CLOUD_DETAIL_STRENGTH 35 // [0 15 25 35 50 65 80 100] Multi-scale cloud detail
#define AURORA_STRENGTH 45 // [0 10 25 40 55 70 85 100] Procedural night aurora
#define NEBULA_STRENGTH 35 // [0 10 20 35 50 65 80 100] Procedural night-sky nebulae
#define RAINBOW_STRENGTH 45 // [0 10 25 40 55 70 85 100] Atmospheric rainbow arc

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



float sampleCloudDensity(
    vec3 worldPosition,
    float cloudBase,
    float cloudThickness,
    vec2 wind,
    float coverage,
    float detailStrength,
    float rain
) {
    float heightFraction = clamp(
        (worldPosition.y - cloudBase) / max(cloudThickness, 1.0), 0.0, 1.0
    );
    float verticalProfile = smoothstep(0.02, 0.18, heightFraction)
        * (1.0 - smoothstep(0.72, 1.0, heightFraction));
    if (verticalProfile <= 0.001) return 0.0;

    vec2 noiseUv = worldPosition.xz * 0.0016 + wind
        + vec2(0.0, heightFraction * 0.22);
    float broadNoise = textureLod(noisetex, noiseUv, 0.0).r;
    float detailNoise = textureLod(
        noisetex, noiseUv * 2.73 + vec2(0.37, 0.19), 0.0
    ).g;
    float cloudNoise = mix(
        broadNoise, broadNoise * 0.72 + detailNoise * 0.28, detailStrength
    );
    float cloudShape = smoothstep(
        coverage, min(coverage + 0.22, 0.999), cloudNoise
    );
    return cloudShape * verticalProfile * (1.0 + rain * 0.25);
}

vec4 calculateVolumetricClouds(vec3 rayDirection, float solarElevation, float rain) {
#if VOLUMETRIC_CLOUDS > 0
    if (!hasSkylight) return vec4(0.0);

    vec3 cameraWorldPosition = vec3(cameraPositionInt) + cameraPositionFract;
    float cloudBase = float(CLOUD_ALTITUDE) - float(CLOUD_THICKNESS) * 0.5;
    float cloudTop = float(CLOUD_ALTITUDE) + float(CLOUD_THICKNESS) * 0.5;
    float startDistance = 0.0;
    float endDistance = 0.0;

    if (abs(rayDirection.y) > 0.012) {
        float baseDistance = (cloudBase - cameraWorldPosition.y) / rayDirection.y;
        float topDistance = (cloudTop - cameraWorldPosition.y) / rayDirection.y;
        startDistance = max(min(baseDistance, topDistance), 0.0);
        endDistance = min(max(baseDistance, topDistance), 1400.0);
    } else if (cameraWorldPosition.y >= cloudBase && cameraWorldPosition.y <= cloudTop) {
        // When the camera is inside the cloud slab and looking almost horizontally,
        // trace a bounded distance through it instead of dividing by a near-zero Y.
        startDistance = 0.0;
        endDistance = 1400.0;
    } else {
        return vec4(0.0);
    }

    if (endDistance <= startDistance + 0.01) return vec4(0.0);

    float sampleCount = float(VOLUMETRIC_CLOUD_QUALITY);
    float stepLength = (endDistance - startDistance) / sampleCount;
    float jitter = fract(
        sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453
    );
    float cloudSpeed = float(CLOUD_SPEED) * 0.01;
    vec2 wind = vec2(
        frameTimeCounter * 0.00004 * cloudSpeed,
        -frameTimeCounter * 0.000025 * cloudSpeed
    );

    float detailStrength = float(CLOUD_DETAIL_STRENGTH) * 0.01;
    float coverage = mix(
        float(CLOUD_COVERAGE) * 0.01,
        float(CLOUD_COVERAGE) * 0.01 - 0.08,
        clamp(rain, 0.0, 1.0)
    );
    float densityStrength = float(CLOUD_DENSITY) * 0.01;
    float dayFactor = smoothstep(-0.08, 0.20, solarElevation);
    float lightLength = length(shadowLightPosition);
    vec3 lightDirection = lightLength > 0.0001
        ? normalize(mat3(gbufferModelViewInverse) * shadowLightPosition)
        : vec3(0.0, 1.0, 0.0);

    vec3 ambientColor = mix(
        vec3(0.12, 0.16, 0.25),
        vec3(0.43, 0.53, 0.66),
        dayFactor
    );
    vec3 directColor = mix(
        vec3(0.20, 0.25, 0.38),
        vec3(1.0, 0.84, 0.66),
        dayFactor
    );
    float forwardPhase = pow(max(dot(rayDirection, lightDirection), 0.0), 4.0);
    float scatteringStrength = float(CLOUD_SCATTERING_STRENGTH) * 0.01;

    vec3 cloudRadiance = vec3(0.0);
    float transmittance = 1.0;

    for (int i = 0; i < VOLUMETRIC_CLOUD_QUALITY; ++i) {
        float sampleDistance = startDistance + (float(i) + jitter) * stepLength;
        if (sampleDistance > endDistance) break;

        vec3 samplePosition = cameraWorldPosition + rayDirection * sampleDistance;
        float heightFraction = clamp(
            (samplePosition.y - cloudBase) / max(float(CLOUD_THICKNESS), 1.0),
            0.0, 1.0
        );
        float verticalProfile = smoothstep(0.02, 0.18, heightFraction)
            * (1.0 - smoothstep(0.72, 1.0, heightFraction));
        if (verticalProfile <= 0.001) continue;

        float density = sampleCloudDensity(
            samplePosition, cloudBase, float(CLOUD_THICKNESS),
            wind, coverage, detailStrength, rain
        );
        float opticalDepth = density * stepLength * 0.08 * densityStrength;
        float sampleAlpha = 1.0 - exp(-opticalDepth);
        if (sampleAlpha <= 0.001) continue;

        // Approximate cloud self-shadowing by sampling optical density toward
        // the active celestial light at two points inside the cloud slab.
        // This gives cloud interiors a darker base and preserves a bright
        // silver lining at exposed edges without a second full raymarch.
        float cloudLightTransmittance = 1.0;
#if VOLUMETRIC_CLOUD_QUALITY >= 16
        const int CLOUD_LIGHT_STEPS = 3;
#elif VOLUMETRIC_CLOUD_QUALITY >= 12
        const int CLOUD_LIGHT_STEPS = 2;
#else
        const int CLOUD_LIGHT_STEPS = 1;
#endif
        if (lightDirection.y > 0.02) {
            for (int lightStep = 0; lightStep < CLOUD_LIGHT_STEPS; ++lightStep) {
                float lightDistance = 22.0 + float(lightStep) * 34.0;
                vec3 lightSamplePosition = samplePosition
                    + lightDirection * lightDistance;
                float lightDensity = sampleCloudDensity(
                    lightSamplePosition, cloudBase, float(CLOUD_THICKNESS),
                    wind, coverage, detailStrength, rain
                );
                cloudLightTransmittance *= exp(
                    -lightDensity * lightDistance * 0.0028 * densityStrength
                );
            }
        }

        float heightLighting = mix(0.72, 1.08, heightFraction);
        float silverLining = pow(forwardPhase, 8.0) * 0.18 * scatteringStrength;
        vec3 sampleColor = ambientColor * heightLighting;
        sampleColor += directColor * (
            0.08 + 0.20 * forwardPhase + silverLining
        ) * scatteringStrength * cloudLightTransmittance;
        // A small isotropic multiple-scattering floor keeps dense cloud cores
        // from becoming unnaturally black as direct light is attenuated.
        sampleColor += ambientColor * (1.0 - cloudLightTransmittance) * 0.12;
        sampleColor *= mix(1.0, 0.56, rain * 0.85);

        float cloudFog = smoothstep(600.0, 1400.0, sampleDistance);
        sampleColor = mix(sampleColor, vFogLinear, cloudFog * 0.75);

        cloudRadiance += cloudRadiance * 0.0 + transmittance * sampleAlpha * sampleColor;
        transmittance *= 1.0 - sampleAlpha;
        if (transmittance < 0.015) break;
    }

    return vec4(cloudRadiance, 1.0 - transmittance);
#else
    return vec4(0.0);
#endif
}


vec3 calculateNightSkyEffects(vec3 playerDirection, float solarElevation, float rain) {
    float nightFactor = 1.0 - smoothstep(-0.10, 0.18, solarElevation);
    float skyFade = smoothstep(0.02, 0.22, playerDirection.y);
    float azimuth = atan(playerDirection.z, playerDirection.x);
    float elevation = asin(clamp(playerDirection.y, -1.0, 1.0));
    vec2 skyUv = vec2(azimuth * 0.15915494 + 0.5, elevation * 0.31830989 + 0.5);

    vec3 result = vec3(0.0);
#if NEBULA_STRENGTH > 0
    vec2 nebulaUv = skyUv * vec2(4.0, 7.0)
        + vec2(frameTimeCounter * 0.00035, -frameTimeCounter * 0.00012);
    float nebulaBroad = textureLod(noisetex, nebulaUv, 0.0).r;
    float nebulaFine = textureLod(
        noisetex, nebulaUv * 2.71 + vec2(0.31, 0.63), 0.0
    ).g;
    float nebulaCloud = smoothstep(
        0.48, 0.78, nebulaBroad * 0.68 + nebulaFine * 0.32
    );
    vec3 nebulaColor = mix(
        vec3(0.10, 0.035, 0.24),
        vec3(0.035, 0.22, 0.32),
        smoothstep(0.28, 0.78, nebulaFine)
    );
    result += nebulaColor * nebulaCloud * skyFade * nightFactor
        * (1.0 - rain * 0.75) * (float(NEBULA_STRENGTH) * 0.0018);
#endif

#if AURORA_STRENGTH > 0
    vec2 auroraUv = vec2(
        azimuth * 1.7 + frameTimeCounter * 0.0012,
        elevation * 2.6
    );
    float auroraBroad = textureLod(noisetex, auroraUv, 0.0).r;
    float auroraDetail = textureLod(
        noisetex, auroraUv * 3.3 + vec2(0.17, 0.41), 0.0
    ).g;
    float curtainWave = sin(azimuth * 18.0 + auroraBroad * 8.0
        + frameTimeCounter * 0.16);
    float curtainMask = smoothstep(0.32, 0.72, auroraDetail)
        * smoothstep(0.10, 0.24, playerDirection.y)
        * (1.0 - smoothstep(0.58, 0.78, playerDirection.y));
    float auroraRays = pow(max(0.5 + 0.5 * curtainWave, 0.0), 3.0);
    vec3 auroraColor = mix(
        vec3(0.10, 0.95, 0.42),
        vec3(0.20, 0.38, 1.0),
        smoothstep(0.35, 0.85, auroraBroad)
    );
    result += auroraColor * curtainMask * auroraRays * nightFactor
        * (1.0 - rain * 0.82) * (float(AURORA_STRENGTH) * 0.004);
#endif
    return result;
}

vec3 calculateRainbow(vec3 viewDirection, float solarElevation, float rain) {
#if RAINBOW_STRENGTH > 0
    if (!hasSkylight || solarElevation < 0.08 || rain < 0.15) return vec3(0.0);
    float lightLength = length(shadowLightPosition);
    if (lightLength < 0.0001) return vec3(0.0);
    vec3 antiSolarDirection = -shadowLightPosition / lightLength;
    float angularDistance = acos(clamp(dot(viewDirection, antiSolarDirection), -1.0, 1.0));
    float arc = exp(-pow((angularDistance - 0.735) / 0.012, 2.0));
    float spectrum = clamp((angularDistance - 0.714) / 0.042, 0.0, 1.0);
    vec3 rainbowColor = mix(vec3(1.0, 0.12, 0.06), vec3(1.0, 0.52, 0.06), smoothstep(0.0, 0.2, spectrum));
    rainbowColor = mix(rainbowColor, vec3(0.95, 0.9, 0.12), smoothstep(0.16, 0.38, spectrum));
    rainbowColor = mix(rainbowColor, vec3(0.12, 0.82, 0.28), smoothstep(0.34, 0.58, spectrum));
    rainbowColor = mix(rainbowColor, vec3(0.10, 0.42, 1.0), smoothstep(0.54, 0.78, spectrum));
    rainbowColor = mix(rainbowColor, vec3(0.48, 0.16, 0.88), smoothstep(0.74, 1.0, spectrum));
    float visibility = smoothstep(0.10, 0.35, solarElevation)
        * smoothstep(0.15, 0.55, rain)
        * (1.0 - rain * 0.35);
    return rainbowColor * arc * visibility
        * (float(RAINBOW_STRENGTH) * 0.0018);
#else
    return vec3(0.0);
#endif
}

void main() {
    vec3 colorLinear = vVertexColorLinear;
    float alpha = vVertexAlpha;

    float upDot = 0.0;
    float horizonBlend = 0.0;
    vec3 viewDirection = vec3(0.0, 1.0, 0.0);
    vec3 playerDirection = vec3(0.0, 1.0, 0.0);

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
        playerDirection = reconstructPlayerDirection();
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
        float lightningSkyFlash = (lightningBoltPosition.w > 0.5)
            ? clamp(thunderStrength, 0.0, 1.0) * 0.42
            : 0.0;
        colorLinear = mix(colorLinear, vec3(0.82, 0.88, 1.0), lightningSkyFlash);
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
        colorLinear += calculateNightSkyEffects(
            playerDirection, solarElevation, rainStrength
        );
        colorLinear += calculateRainbow(
            viewDirection, solarElevation, rainStrength
        );

        // Volumetric clouds are integrated into the sky pass so they use the
        // exact same sky ray, fog, celestial direction and depth ordering.
        if (isSky && VOLUMETRIC_CLOUDS > 0) {
            vec4 cloudLayer = calculateVolumetricClouds(
                playerDirection, solarElevation, rainStrength
            );
            colorLinear = cloudLayer.rgb + colorLinear * (1.0 - cloudLayer.a);
        }

        // Low-cost active-celestial glare, adapted from Complementary's
        // low-quality sky path. shadowLightPosition is Iris view space.
        float lightLength = length(shadowLightPosition);
        if (hasSkylight && lightLength > 0.0001) {
            vec3 lightDirection = shadowLightPosition / lightLength;
            float celestialAlignment = max(
                dot(viewDirection, lightDirection),
                0.0
            );
            float glareScatter = 3.0 * (2.0 - clamp(celestialAlignment * 1000.0, 0.0, 1.0));
            float glarePower = pow(celestialAlignment, glareScatter);
            const float glareVisibility = 0.075;
            float celestialGlare = glareVisibility
                / max(1.0 - (1.0 - glareVisibility) * glarePower, 0.075)
                - glareVisibility;
            celestialGlare *= 0.28 * (1.0 - 0.8 * rainStrength);

            float dayFactor = smoothstep(-0.05, 0.25, solarElevation);
            float noonFactor = smoothstep(0.35, 0.9, solarElevation);
            vec3 nightGlareColor = vec3(0.38, 0.40, 0.50) * 0.3;
            vec3 dayGlareColor = vec3(1.0, 0.82, 0.68)
                + vec3(0.0, 0.12, 0.16) * noonFactor;
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
    outColor0 = vec4(outputColor, alpha);
    // Sky, stars and void have no deferred surface normal. Explicitly keep
    // them outside opaque deferred lighting.
    outColor1 = vec4(0.0);
}
