#version 330 compatibility

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform sampler2D colortex4;
uniform sampler2D noisetex;
uniform sampler2D waterNormalTex;
uniform sampler2D normals;
uniform float alphaTestRef;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform ivec3 cameraPositionInt;
uniform vec3 cameraPositionFract;
uniform float frameTimeCounter;
uniform int isEyeInWater;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 shadowLightPosition;
uniform float sunAngle;
uniform bool hasSkylight;
uniform float endFlashIntensity;
uniform vec3 fogColor;
uniform vec3 skyColor;
uniform float fogStart;
uniform float fogEnd;
uniform float fogDensity;
uniform int fogMode;
uniform int fogShape;

in vec2 vTexCoord;
flat in vec2 vMidTexCoord;
flat in vec2 vTexHalfSize;
in vec2 vLightmapCoord;
in vec4 vVertexColor;
in vec3 vPlayerNormal;
in vec3 vPlayerPosition;
in vec3 vViewPosition;
in vec3 vViewNormal;
in vec3 vPlayerTangent;
flat in float vTangentHandedness;
flat in int vMaterialId;
flat in float vFluidRenderType;

/* RENDERTARGETS: 0 */

#define WATER_REFRACTION_STRENGTH 1.00 // [0.00 0.25 0.50 0.75 1.00 1.25 1.50 2.00] Screen-space water refraction strength
#define WATER_REFLECTION_STRENGTH 0.75 // [0.00 0.25 0.50 0.75 1.00 1.25 1.50] Fresnel screen-space reflection strength
#define WATER_FOG_MULT 100 // [25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100 110 120 130 140 150 160 170 180 190 200 220 240 260 280 300 325 350 375 400 425 450 475 500 550 600 650 700 750 800 850 900] Water depth opacity
#define WATER_REFLECTION_QUALITY 6 // [0 4 6 8] Screen-space water reflection samples
#define WATER_NORMAL_MAP_STRENGTH 100 // [0 25 50 75 100 125 150] Resource-pack water normal-map detail
#define GLASS_NORMAL_MAP_STRENGTH 100 // [0 25 50 75 100 125 150] Resource-pack glass/ice normal-map detail
#define WATER_WAVE_STRENGTH 100 // [0 25 50 75 100 125 150 175 200] Animated multi-scale water normal strength
#define WATER_WAVE_SPEED 60 // [15 30 45 60 75 90 120] Water wave cycles per real-time hour
#define WATER_WAVE_SCALE 100 // [50 75 100 125 150 200] Water wave spatial frequency
#define WATER_WAVE_DETAIL 0 // [0 1] Optional very-large Unbound-style normal scale; adds one texture sample
#define HELD_LIGHTING_STRENGTH 50 // [0 25 50 75 100] Held-item lighting strength
#define WATER_COLOR_STRENGTH 100 // [0 25 50 75 100] Unbound-style water base tint blend
#define WATER_NOISE_COLOR_STRENGTH 35 // [0 10 20 35 50 75 100] Animated water colour variation
#define WATER_FOAM_STRENGTH 100 // [0 25 50 75 100 125 150] Shoreline and shallow-surface foam strength
#define WATER_UNDERWATER_STRENGTH 100 // [0 25 50 75 100 125 150] Underwater tint and surface response
#define WATER_ABSORPTION_STRENGTH 100 // [0 25 50 75 100 125 150 175 200] Depth-dependent water light absorption
#define GLASS_REFLECTION_STRENGTH 60 // [0 15 30 45 60 75 90 100 125 150] Glass and stained-glass screen-space reflection
#define PORTAL_EMISSION_STRENGTH 100 // [0 25 50 75 100 125 150 200] Nether portal self-emission
#define PORTAL_DISTORTION_STRENGTH 100 // [0 25 50 75 100 125 150 200] Atlas-safe animated portal distortion
layout(location = 0) out vec4 outColor;

// Reconstruct a stable, periodic world position from Iris' unshifted integer
// camera position, fractional camera position and player-relative position.
// A 2560-block period tiles every selected water-normal octave, avoiding cameraPosition's 30,000-block wrap and large-float jitter.
vec3 getStableWaterWorldPosition(vec3 playerPosition) {
    ivec3 cameraModulo = cameraPositionInt % ivec3(2560);
    vec3 cameraOffset = mod(vec3(cameraModulo), vec3(2560.0));
    return mod(cameraOffset + cameraPositionFract + playerPosition, vec3(2560.0));
}

// Multi-scale wave bands use a tileable custom tangent-normal texture; the
// optional very-large octave follows Unbound while remaining disabled on low profiles.
vec3 calculateTranslucentNormalMap(vec3 geometricNormal, float normalMapStrength) {
    vec4 normalTexel = texture(normals, vTexCoord);
    vec3 tangentNormal;
    #ifdef MC_TEXTURE_FORMAT_LAB_PBR
        // LabPBR stores XY in RG, AO in B, and height in A. Reconstruct Z.
        tangentNormal.xy = normalTexel.rg * 2.0 - 1.0;
        tangentNormal.z = sqrt(max(1.0 - dot(tangentNormal.xy, tangentNormal.xy), 0.0));
        // LabPBR uses DirectX Y- normals; oldPBR retains the legacy Y+ convention.
        tangentNormal.y = -tangentNormal.y;
    #else
        tangentNormal = normalTexel.rgb * 2.0 - 1.0;
    #endif
    tangentNormal.xy *= normalMapStrength * 0.01;
    tangentNormal = normalize(tangentNormal);

    vec3 tangent = normalize(vPlayerTangent - geometricNormal * dot(vPlayerTangent, geometricNormal));
    // Iris defines handedness for bitangent = cross(tangent, normal).
    vec3 bitangent = normalize(cross(tangent, geometricNormal)) * vTangentHandedness;
    return normalize(
        tangent * tangentNormal.x +
        bitangent * tangentNormal.y +
        geometricNormal * tangentNormal.z
    );
}

vec3 calculateWaterWaveNormal(
    vec3 geometricNormal,
    vec2 waterCoord,
    vec2 waterCoordDx,
    vec2 waterCoordDy
) {
    if (abs(geometricNormal.y) < 0.72 || WATER_WAVE_STRENGTH <= 0 || WATER_WAVE_SCALE <= 0) {
        return geometricNormal;
    }

    // Forty texture periods per normalized cycle make all selected octaves
    // land on integer repeats at Iris' 3600-second timer wrap.
    float waveCycles = frameTimeCounter / 3600.0 * (float(WATER_WAVE_SPEED) * 0.01);
    vec2 wind = vec2(waveCycles * 40.0, -waveCycles * 40.0);

    // Three Unbound-style scales from a tileable, generated tangent-normal map.
    // Explicit gradients keep mip selection stable inside the translucent branch.
    vec2 normalMedium = textureGrad(
        waterNormalTex, waterCoord + wind, waterCoordDx, waterCoordDy
    ).rg - vec2(0.5);
    vec2 normalSmall = textureGrad(
        waterNormalTex, waterCoord * 4.0 - wind * 2.0,
        waterCoordDx * 4.0, waterCoordDy * 4.0
    ).rg - vec2(0.5);
    vec2 normalLarge = textureGrad(
        waterNormalTex, waterCoord * 0.25 - wind * 0.5,
        waterCoordDx * 0.25, waterCoordDy * 0.25
    ).rg - vec2(0.5);
#if WATER_WAVE_DETAIL > 0
    vec2 normalVeryLarge = textureGrad(
        waterNormalTex, waterCoord * 0.05 - wind * 0.5,
        waterCoordDx * 0.05, waterCoordDy * 0.05
    ).rg - vec2(0.5);
    normalLarge += normalVeryLarge * 0.5;
#endif

    vec2 slope = normalMedium * 0.8 + normalSmall * 0.55 + normalLarge * 0.45;
    float strength = float(WATER_WAVE_STRENGTH) * 0.01 * 4.0;
    float faceSign = geometricNormal.y < 0.0 ? -1.0 : 1.0;
    // Add the wave slope to the existing PBR normal rather than replacing it.
    vec3 waveNormal = normalize(
        geometricNormal + vec3(-slope.x * strength * faceSign, 0.0,
                               -slope.y * strength * faceSign)
    );
    return waveNormal;
}

// Unbound-style water base colour: retain biome influence, but move the
// surface away from the flat vanilla atlas tint. A single Iris noise lookup
// adds slow, low-amplitude colour variation without a second custom texture.
vec2 calculateWaterNoiseDrift() {
    float noiseTime = frameTimeCounter * (6.28318530718 * float(WATER_WAVE_SPEED) / 3600.0);
    return vec2(cos(noiseTime), sin(noiseTime)) * 0.025;
}

vec2 calculateWaterNoisePosition(vec3 stableWorldPosition) {
    // Match Unbound's world-height-aware coordinates while keeping the
    // 2560-block stable-world period exactly tileable: 2560 * 0.03125 = 80 repeats.
    // This is a wrap-safe 1/32 approximation of Unbound's 0.032 scale.
    return 0.03125 * (stableWorldPosition.xz + stableWorldPosition.y * 2.0);
}

vec3 calculateWaterBaseColor(vec3 vertexColor, vec3 stableWorldPosition) {
    // Unbound style 3 uses the biome/vertex tint directly after its
    // square-root colour preparation; the fixed blue fallback belongs to
    // the older Reimagined-style water treatment.
    vec3 biomeTint = sqrt(max(vertexColor, vec3(0.0))) * vec3(1.0, 0.85, 0.8);
    vec3 baseColor = 0.375 * biomeTint;

    if (WATER_NOISE_COLOR_STRENGTH > 0) {
        vec2 waterPosition = calculateWaterNoisePosition(stableWorldPosition);
        vec2 noiseUV = (waterPosition + calculateWaterNoiseDrift()) * 0.25;
        float noise = textureLod(noisetex, noiseUV, 0.0).g - 0.5;
        noise *= 0.25 * (WATER_NOISE_COLOR_STRENGTH * 0.01);
        // Unbound perturbs the water tint through a small colour exponent.
        baseColor = pow(max(baseColor, vec3(0.0)), vec3(1.0 + noise));
    }

    return baseColor;
}

vec3 sampleTranslucentShadow(vec3 playerPosition, vec3 normal, vec3 lightDirection) {
    vec4 shadowViewPosition = shadowModelView * vec4(playerPosition, 1.0);
    vec4 shadowClipPosition = shadowProjection * shadowViewPosition;

    float normalLight = max(dot(normal, lightDirection), 0.0);
    float depthBias = mix(0.0022, 0.00065, normalLight);
    shadowClipPosition.z -= depthBias;

    vec3 shadowNdc = shadowClipPosition.xyz / shadowClipPosition.w;
    vec3 shadowPosition = shadowNdc * 0.5 + 0.5;
    if (shadowPosition.x <= 0.0 || shadowPosition.x >= 1.0 ||
        shadowPosition.y <= 0.0 || shadowPosition.y >= 1.0 ||
        shadowPosition.z <= 0.0 || shadowPosition.z >= 1.0) {
        return vec3(1.0);
    }

    vec2 texel = 1.0 / vec2(textureSize(shadowtex0, 0));
    float visibility = 0.0;
    visibility += texture(shadowtex0, vec3(shadowPosition.xy + texel * vec2(-0.5, -0.5), shadowPosition.z));
    visibility += texture(shadowtex0, vec3(shadowPosition.xy + texel * vec2( 0.5, -0.5), shadowPosition.z));
    visibility += texture(shadowtex0, vec3(shadowPosition.xy + texel * vec2(-0.5,  0.5), shadowPosition.z));
    visibility += texture(shadowtex0, vec3(shadowPosition.xy + texel * vec2( 0.5,  0.5), shadowPosition.z));
    visibility *= 0.25;

    float centerShadow0 = texture(shadowtex0, vec3(shadowPosition.xy, shadowPosition.z));
    float centerShadow1 = texture(shadowtex1, vec3(shadowPosition.xy, shadowPosition.z));
    if (centerShadow1 > centerShadow0 + 0.5) {
        vec4 casterColor = texture(shadowcolor0, shadowPosition.xy);
        vec3 translucentTransmission = casterColor.rgb * (1.0 - casterColor.a);
        return clamp(
            mix(vec3(visibility), translucentTransmission, 1.0 - visibility),
            vec3(0.0), vec3(1.0)
        );
    }
    return vec3(clamp(visibility, 0.0, 1.0));
}

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position) {
    vec4 homogeneous = projectionMatrix * vec4(position, 1.0);
    return homogeneous.xyz / homogeneous.w;
}

float calculateWaterThickness(out vec3 opaqueViewPosition, out float opaqueDepth) {
    // depthtex1 is full-resolution; fetch the exact current pixel without
    // filtering, then normalize only for inverse-projection reconstruction.
    opaqueDepth = texelFetch(depthtex1, ivec2(gl_FragCoord.xy), 0).r;
    // depthtex1 clears to 1.0. Reconstruct that far-plane sample with the
    // inverse projection instead of using Iris' "far" uniform, which is
    // render distance in blocks rather than the projection far plane.
    vec2 screenUV = gl_FragCoord.xy / vec2(textureSize(depthtex1, 0));
    vec3 opaqueNdc = vec3(screenUV, opaqueDepth) * 2.0 - 1.0;
    opaqueViewPosition = projectAndDivide(gbufferProjectionInverse, opaqueNdc);
    float opaqueDistance = length(opaqueViewPosition);
    return max(opaqueDistance - length(vViewPosition), 0.0);
}


#if WATER_REFLECTION_QUALITY > 0
// The deferred1 pass writes a separate half-resolution opaque/sky color snapshot to colortex4.
// depthtex2 excludes both translucent geometry and first-person hand geometry,
// so this forward pass never samples colortex0 while writing to it.
vec3 sampleTranslucentScreenReflection(vec3 viewPosition, vec3 viewNormal, out float hitConfidence) {
    const float maxDistance = 24.0;
    float stepLength = maxDistance / float(WATER_REFLECTION_QUALITY);
    vec3 incidentDirection = normalize(viewPosition);
    vec3 reflectionDirection = normalize(reflect(incidentDirection, viewNormal));
    vec3 rayOrigin = viewPosition + viewNormal * 0.06 + reflectionDirection * 0.03;

    vec3 reflectionColor = vec3(0.0);
    hitConfidence = 0.0;
    float previousDepthDelta = 1e20;
    float previousTravelDistance = 0.0;
    ivec2 depthSize = textureSize(depthtex2, 0);
    ivec2 reflectionSize = textureSize(colortex4, 0);

    for (int i = 0; i < WATER_REFLECTION_QUALITY; ++i) {
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

        ivec2 depthPixel = clamp(
            ivec2(sampleUV * vec2(depthSize)), ivec2(0), depthSize - ivec2(1)
        );
        ivec2 reflectionPixel = clamp(
            ivec2(sampleUV * vec2(reflectionSize)), ivec2(0), reflectionSize - ivec2(1)
        );
        float sceneDepth = texelFetch(depthtex2, depthPixel, 0).r;
        vec4 sceneSample = texelFetch(colortex4, reflectionPixel, 0);

        // A clear depth sample is the sky; its color is a valid reflection source.
        if (sceneDepth >= 0.999999) {
            if (sceneSample.a >= 0.5) {
                vec2 edgeDistance = min(sampleUV, vec2(1.0) - sampleUV);
                float edgeFade = smoothstep(0.0, 0.08, min(edgeDistance.x, edgeDistance.y));
                float distanceFade = 1.0 - smoothstep(16.0, maxDistance, travelDistance);
                hitConfidence = edgeFade * distanceFade;
                return sceneSample.rgb;
            }
            previousDepthDelta = 1e20;
            previousTravelDistance = travelDistance;
            continue;
        }

        vec3 sceneNdc = vec3(sampleUV, sceneDepth) * 2.0 - 1.0;
        vec3 sceneViewPosition = projectAndDivide(gbufferProjectionInverse, sceneNdc);
        float depthDelta = rayPosition.z - sceneViewPosition.z;

        // View-space Z is negative in front of the camera. A positive-to-negative
        // transition brackets the opaque surface and can be refined with two taps.
        if (depthDelta <= 0.0 && previousDepthDelta > 0.0 && i > 0 && sceneSample.a >= 0.5) {
            float refineLow = previousTravelDistance;
            float refineHigh = travelDistance;
            vec2 hitUV = sampleUV;
            vec4 hitSample = sceneSample;
            float hitDepthDelta = depthDelta;

            // Two bounded binary-search steps sharpen the coarse hit without
            // adopting Unbound's much more expensive high-quality ray budget.
            for (int refineStep = 0; refineStep < 2; ++refineStep) {
                float refineDistance = (refineLow + refineHigh) * 0.5;
                vec3 refineRayPosition = rayOrigin + reflectionDirection * refineDistance;
                vec4 refineClipPosition = gbufferProjection * vec4(refineRayPosition, 1.0);
                if (refineClipPosition.w <= 0.0001) break;

                vec3 refineNdc = refineClipPosition.xyz / refineClipPosition.w;
                vec2 refineUV = refineNdc.xy * 0.5 + 0.5;
                if (refineUV.x <= 0.001 || refineUV.x >= 0.999 ||
                    refineUV.y <= 0.001 || refineUV.y >= 0.999) {
                    break;
                }

                ivec2 refineDepthPixel = clamp(
                    ivec2(refineUV * vec2(depthSize)), ivec2(0), depthSize - ivec2(1)
                );
                ivec2 refineReflectionPixel = clamp(
                    ivec2(refineUV * vec2(reflectionSize)), ivec2(0), reflectionSize - ivec2(1)
                );
                float refineDepth = texelFetch(depthtex2, refineDepthPixel, 0).r;
                vec4 refineSample = texelFetch(colortex4, refineReflectionPixel, 0);

                if (refineDepth >= 0.999999 || refineSample.a < 0.5) {
                    refineLow = refineDistance;
                    continue;
                }

                vec3 refineSceneNdc = vec3(refineUV, refineDepth) * 2.0 - 1.0;
                vec3 refineScenePosition = projectAndDivide(gbufferProjectionInverse, refineSceneNdc);
                float refineDepthDelta = refineRayPosition.z - refineScenePosition.z;
                if (refineDepthDelta <= 0.0) {
                    refineHigh = refineDistance;
                    hitUV = refineUV;
                    hitSample = refineSample;
                    hitDepthDelta = refineDepthDelta;
                } else {
                    refineLow = refineDistance;
                }
            }

            vec2 edgeDistance = min(hitUV, vec2(1.0) - hitUV);
            float edgeFade = smoothstep(0.0, 0.08, min(edgeDistance.x, edgeDistance.y));
            float distanceFade = 1.0 - smoothstep(16.0, maxDistance, refineHigh);
            float depthConfidence = 1.0 - smoothstep(
                0.0, stepLength * 0.75, abs(hitDepthDelta)
            );
            hitConfidence = edgeFade * distanceFade * depthConfidence;
            return hitSample.rgb;
        }

        // If the first coarse sample begins inside geometry, retain the old
        // conservative tolerance rather than manufacturing a false bracket.
        if (depthDelta <= 0.0 && depthDelta > -stepLength * 0.75 && sceneSample.a >= 0.5) {
            vec2 edgeDistance = min(sampleUV, vec2(1.0) - sampleUV);
            float edgeFade = smoothstep(0.0, 0.08, min(edgeDistance.x, edgeDistance.y));
            float distanceFade = 1.0 - smoothstep(16.0, maxDistance, travelDistance);
            float depthConfidence = 1.0 - smoothstep(
                0.0, stepLength * 0.75, abs(depthDelta)
            );
            hitConfidence = edgeFade * distanceFade * depthConfidence;
            return sceneSample.rgb;
        }

        previousDepthDelta = depthDelta;
        previousTravelDistance = travelDistance;
    }

    return reflectionColor;
}
#endif


#include "/lib/lighting/environment_reflection.glsl"
#include "/lib/lighting/held_item_lighting.glsl"

vec3 sampleEnvironmentReflection(vec3 viewReflectionDirection) {
    return calculateEnvironmentReflection(
        viewReflectionDirection, shadowLightPosition, sunAngle, hasSkylight
    );
}

float calculateTranslucentFog(float distanceToCamera) {
    if (fogMode == 9729) {
        return clamp((distanceToCamera - fogStart) / max(fogEnd - fogStart, 0.0001), 0.0, 1.0);
    }
    if (fogMode == 2048) {
        return clamp(1.0 - exp(-fogDensity * distanceToCamera), 0.0, 1.0);
    }
    if (fogMode == 2049) {
        float densityDistance = fogDensity * distanceToCamera;
        return clamp(1.0 - exp(-densityDistance * densityDistance), 0.0, 1.0);
    }
    return 0.0;
}

void main() {
    vec4 translucentAlbedo = texture(gtexture, vTexCoord) * vVertexColor;
    float portalEmissionSignal = 0.0;
    if (translucentAlbedo.a < alphaTestRef) discard;

    // Iris routes all translucent terrain through gbuffers_water. Fluid IDs
    // receive water depth/refraction/foam; glass and portals use separate
    // material branches while other translucent terrain stays generic.
    vec3 vanillaLight = texture(lightmap, vLightmapCoord).rgb;
    float skyLight = clamp(vLightmapCoord.y / (30.0 / 32.0) - (1.0 / 32.0), 0.0, 1.0);

    bool isFluidWater = (vMaterialId == 32000) && (vFluidRenderType > 0.5);
    bool isWater = isFluidWater || (vMaterialId == 32001);
    bool isClearGlass = (vMaterialId == 32008 || vMaterialId == 32012);
    bool isClearGlassPane = (vMaterialId == 32012);
    // Match Unbound's CTM/Opti pane edge guard without discarding valid faces:
    // only near-horizontal clear-pane fragments with effectively zero alpha.
    if (isClearGlassPane && translucentAlbedo.a < 0.001
        && abs(normalize(vPlayerNormal).y) > 0.95) discard;
    bool isStainedGlass = (vMaterialId >= 31000 && vMaterialId <= 31031);
    bool isTintedGlass = (vMaterialId == 30008);
    bool isIce = (vMaterialId == 32004);
    bool isGlass = isClearGlass || isStainedGlass || isTintedGlass;
    bool isPortal = (vMaterialId == 30020);
    vec3 normal = normalize(vPlayerNormal);
    vec3 viewNormal = normalize(vViewNormal);
    if (!gl_FrontFacing) {
        normal = -normal;
        viewNormal = -viewNormal;
    }
    // Complementary's Iris-water workaround: orient the geometric normal
    // toward the camera before shadowing, Fresnel and reflection calculations.
    if (isWater && dot(normalize(vViewPosition), viewNormal) > 0.0) {
        normal = -normal;
        viewNormal = -viewNormal;
    }
    // Keep the geometric normal for shadow-map bias; PBR and wave detail
    // are applied only to the forward lighting/reflection normal.
    vec3 shadowNormal = normal;
    vec3 stableWaterWorldPosition = getStableWaterWorldPosition(vPlayerPosition);
    float waterNormalScale = 0.03125 * float(WATER_WAVE_SCALE) * 0.01;
    vec2 waterNormalCoord = stableWaterWorldPosition.xz * waterNormalScale;
    // Derivatives use continuous camera-relative position; only the texture
    // coordinate itself is reduced to the stable world-position period.
    vec2 waterNormalCoordDx = dFdx(vPlayerPosition.xz * waterNormalScale);
    vec2 waterNormalCoordDy = dFdy(vPlayerPosition.xz * waterNormalScale);
    if (isWater) {
        #if WATER_NORMAL_MAP_STRENGTH > 0
            if (abs(normal.y) > 0.72) {
                normal = calculateTranslucentNormalMap(normal, WATER_NORMAL_MAP_STRENGTH);
            }
        #endif
        normal = calculateWaterWaveNormal(normal, waterNormalCoord, waterNormalCoordDx, waterNormalCoordDy);
        // Iris documents gbufferModelView as player-space to view-space.
        // Transform the perturbed normal for Fresnel, refraction and SSR.
        viewNormal = normalize(mat3(gbufferModelView) * normal);
    } else if (isClearGlass || isStainedGlass || isTintedGlass || isIce) {
        #if GLASS_NORMAL_MAP_STRENGTH > 0
            normal = calculateTranslucentNormalMap(normal, GLASS_NORMAL_MAP_STRENGTH);
            viewNormal = normalize(mat3(gbufferModelView) * normal);
        #endif
    }
    vec3 viewLightDirection = normalize(shadowLightPosition);
    vec3 worldLightDirection = normalize(mat3(gbufferModelViewInverse) * viewLightDirection);
    float nDotL = max(dot(normal, worldLightDirection), 0.0);

    bool endFlashActive = endFlashIntensity > 0.001;
    float solarElevation = sin(sunAngle * 6.28318530718);
    float dayFactor = (hasSkylight && !endFlashActive)
        ? smoothstep(0.0, 0.30, solarElevation)
        : 0.0;
    float celestialGate = endFlashActive
        ? clamp(endFlashIntensity, 0.0, 1.0)
        : (hasSkylight ? skyLight : 0.0);

    bool cameraUnderwater = (isEyeInWater == 1);
    vec3 shadow = vec3(1.0);
    if (nDotL > 0.001 && celestialGate > 0.001 && !(isWater && cameraUnderwater) && !isPortal) {
        shadow = sampleTranslucentShadow(vPlayerPosition, shadowNormal, worldLightDirection);
    }

    vec3 ambient = vec3(0.018) + pow(max(vanillaLight, vec3(0.0)), vec3(2.2)) * 0.72;
#if HELD_LIGHTING_STRENGTH > 0
    vec3 heldLighting = calculateHeldItemLighting(vPlayerPosition);
    ambient = sqrt(ambient * ambient + heldLighting);
#endif
    vec3 celestialColor = endFlashActive
        ? vec3(1.0)
        : (hasSkylight
            ? mix(vec3(0.36, 0.44, 0.68), vec3(1.0, 0.94, 0.82), dayFactor)
            : vec3(1.0));
    float celestialIntensity = endFlashActive
        ? 0.70
        : (hasSkylight ? mix(0.10, 0.70, dayFactor) : 0.0);
    vec3 direct = celestialColor * celestialIntensity * nDotL * shadow * celestialGate;
    if ((isWater && cameraUnderwater) || isPortal) direct = vec3(0.0);

    float waterThickness = 0.0;
    float waterFog = 0.0;
    float waterFresnel = 0.0;
    float waterFoam = 0.0;
    vec3 waterFoamColor = vec3(0.90, 0.95, 1.05);
    vec2 waterRefractionOffset = vec2(0.0);
    float refractionConfidence = 0.0;
    vec3 refractedSceneLinear = vec3(0.0);
    vec3 waterAbsorptionTintLinear = vec3(0.0);

    if (isWater) {
        float nDotV = clamp(dot(viewNormal, normalize(-vViewPosition)), 0.0, 1.0);
        waterFresnel = 0.02 + 0.98 * pow(1.0 - nDotV, 5.0);

        // Apply the Unbound-inspired water tint before sampling/refraction so
        // the same material colour also becomes the Beer-Lambert absorption tint.
        vec3 unboundWaterColor = calculateWaterBaseColor(vVertexColor.rgb, stableWaterWorldPosition);
        translucentAlbedo.rgb = mix(
            translucentAlbedo.rgb,
            unboundWaterColor,
            clamp(WATER_COLOR_STRENGTH * 0.01, 0.0, 1.0)
        );
        if (cameraUnderwater) {
            translucentAlbedo.rgb *= mix(
                vec3(1.0),
                vec3(0.78, 0.90, 1.05),
                clamp(WATER_UNDERWATER_STRENGTH * 0.01, 0.0, 1.0)
            );
        }
        waterAbsorptionTintLinear = pow(max(translucentAlbedo.rgb, vec3(0.0)), vec3(2.2));

        vec3 opaqueViewPosition = vec3(0.0);
        float opaqueDepth = 1.0;
        // Unbound skips surface-depth work while the camera is underwater.
        if (!cameraUnderwater) {
            waterThickness = calculateWaterThickness(opaqueViewPosition, opaqueDepth);
            float waterFogThickness = waterThickness * (WATER_FOG_MULT * 0.01);
            waterFog = clamp(1.0 - exp(-waterFogThickness * 0.075), 0.0, 1.0);
        }

        // Unbound-inspired shallow-water foam. Reconstructed view-space
        // thickness is the stable signal for a nearby opaque intersection;
        // avoid a world-Y test, which misses sloped shorelines and depends on
        // the sign of the opaque surface's vertical offset.
        if (!cameraUnderwater && isFluidWater && WATER_FOAM_STRENGTH > 0 && opaqueDepth < 0.999999 &&
            abs(vPlayerNormal.y) > 0.99) {
            vec2 foamNoiseUV = calculateWaterNoisePosition(stableWaterWorldPosition) * 4.0
                + calculateWaterNoiseDrift() * 0.5;
            float foamNoise = textureLod(noisetex, foamNoiseUV, 0.0).g;
            float foamThreshold = mix(0.06, 0.42, foamNoise * foamNoise);
            float shallowFoam = 1.0 - smoothstep(0.035, foamThreshold, waterThickness);
            waterFoam = shallowFoam * (hasSkylight ? (0.4 + 0.25 * skyLight) : 0.6);
            #if WATER_FOAM_STRENGTH < 100
                waterFoam *= WATER_FOAM_STRENGTH * 0.01;
            #elif WATER_FOAM_STRENGTH > 100
                waterFoamColor *= WATER_FOAM_STRENGTH * 0.01;
            #endif
            waterFoam = clamp(waterFoam, 0.0, 1.0);
        }

        // Complementary Unbound style 3 uses a stable 0.98 surface alpha
        // above water, then applies depth opacity. Underwater it retains the
        // sampled material alpha and applies the reference's 0.75 reduction.
        if (cameraUnderwater) {
            translucentAlbedo.a *= 0.75;
        } else {
            translucentAlbedo.a = 0.98;
        }
        float waterAlpha = cameraUnderwater
            ? translucentAlbedo.a
            : translucentAlbedo.a * (0.25 + 0.75 * waterFog);
        // Keep the Unbound grazing-angle opacity response.
        waterAlpha = mix(waterAlpha, 1.0, waterFresnel * 0.25);
        translucentAlbedo.a = clamp(waterAlpha, 0.0, 1.0);

        // deferred1 snapshots the opaque scene into half-resolution colortex4.
        // This gbuffers pass writes colortex0 but reads colortex4, so it avoids
        // same-attachment feedback and keeps refraction bandwidth bounded.
        if (!cameraUnderwater && WATER_REFRACTION_STRENGTH > 0.001 && opaqueDepth < 0.999999) {
            vec2 screenUV = gl_FragCoord.xy / vec2(textureSize(depthtex1, 0));
            waterRefractionOffset = viewNormal.xy
                * min(waterThickness * 0.0025, 0.035)
                * WATER_REFRACTION_STRENGTH;
            vec2 halfTexel = 0.5 / vec2(textureSize(colortex4, 0));
            vec2 refractedUV = clamp(screenUV + waterRefractionOffset,
                                     halfTexel, vec2(1.0) - halfTexel);

            ivec2 refractedPixel = ivec2(refractedUV * vec2(textureSize(depthtex1, 0)));
            refractedPixel = clamp(refractedPixel, ivec2(0), textureSize(depthtex1, 0) - ivec2(1));
            float refractedDepth = texelFetch(depthtex1, refractedPixel, 0).r;
            vec2 refractedDepthUV = (vec2(refractedPixel) + 0.5)
                / vec2(textureSize(depthtex1, 0));
            if (refractedDepth < 0.999999) {
                vec3 refractedNdc = vec3(refractedDepthUV, refractedDepth) * 2.0 - 1.0;
                vec3 refractedViewPosition = projectAndDivide(gbufferProjectionInverse, refractedNdc);
                float depthDelta = abs(length(refractedViewPosition) - length(opaqueViewPosition));
                refractionConfidence = 1.0 - smoothstep(0.5, 4.0, depthDelta);

                // Reject offsets that cross onto geometry in front of the water.
                if (refractedViewPosition.z > vViewPosition.z + 0.05) {
                    refractionConfidence = 0.0;
                }

                vec4 refractedScene = texture(colortex4, refractedUV);
                if (refractedScene.a >= 0.5) {
                    refractedSceneLinear = pow(
                        max(refractedScene.rgb, vec3(0.0)),
                        vec3(2.2)
                    );
                    // Beer-Lambert absorption: red light attenuates fastest,
                    // followed by green and blue, so deeper water becomes blue.
                    vec3 absorptionCoefficient = vec3(0.12, 0.045, 0.018)
                        * (WATER_ABSORPTION_STRENGTH * 0.01);
                    vec3 transmission = exp(-absorptionCoefficient * waterThickness);
                    refractedSceneLinear = refractedSceneLinear * transmission
                        + waterAbsorptionTintLinear * (1.0 - transmission);
                } else {
                    refractionConfidence = 0.0;
                }
            }
        }
    }

    if (isPortal) {
        // Use Iris' per-quad midpoint attribute to keep every ray sample inside
        // the current portal sprite; never let distortion bleed into adjacent
        // atlas tiles. Four taps are a bounded low-cost approximation.
        if (PORTAL_DISTORTION_STRENGTH > 0) {
            vec2 atlasTexel = 1.0 / vec2(textureSize(gtexture, 0));
            vec2 portalMinUV = vMidTexCoord - vTexHalfSize + atlasTexel;
            vec2 portalMaxUV = vMidTexCoord + vTexHalfSize - atlasTexel;
            // Iris frameTimeCounter resets after 3600 seconds. Use an integer
            // cycle count so the portal distortion phase is continuous at wrap.
            float portalPhase = frameTimeCounter * (6.28318530718 * 458.0 / 3600.0);
            vec2 portalView = clamp(
                vViewPosition.xy / max(abs(vViewPosition.z), 0.25),
                vec2(-1.0), vec2(1.0)
            );
            vec2 portalSwirl = vec2(
                sin(vTexCoord.y * 20.0 + portalPhase),
                cos(vTexCoord.x * 20.0 - portalPhase)
            ) * 0.003;
            vec2 portalOffset = (
                portalView * 0.006 + portalSwirl
            ) * (PORTAL_DISTORTION_STRENGTH * 0.01);

            vec4 portalAccum = vec4(0.0);
            float portalWeightSum = 0.0;
            for (int i = 0; i < 4; ++i) {
                float portalStep = (float(i) + 0.5) * 0.25;
                vec2 portalUV = clamp(
                    vTexCoord + portalOffset * portalStep,
                    portalMinUV, portalMaxUV
                );
                vec4 portalTap = textureLod(gtexture, portalUV, 0.0) * vVertexColor;
                float portalWeight = pow(1.0 - portalStep, 0.1);
                portalAccum += portalTap * portalWeight;
                portalWeightSum += portalWeight;
            }
            translucentAlbedo = portalAccum / max(portalWeightSum, 0.0001);
        }
        // Preserve the pre-tint signal for emission, then apply the warm
        // nonlinear portal colour treatment.
        portalEmissionSignal = max(translucentAlbedo.r, 0.0);
        translucentAlbedo.rgb *= translucentAlbedo.rgb * vec3(1.25, 1.0, 0.65);
        translucentAlbedo.a = sqrt(max(translucentAlbedo.a, 0.0)) * 0.8;
    }

    if (isFluidWater && waterFoam > 0.0) {
        translucentAlbedo.rgb = mix(
            translucentAlbedo.rgb,
            waterFoamColor,
            waterFoam
        );
    }

    vec3 albedoLinear = pow(max(translucentAlbedo.rgb, vec3(0.0)), vec3(2.2));
    vec3 litLinear = albedoLinear * (ambient + direct);
    // Complementary Unbound derives ice smoothness and highlight strength
    // from the green texture channel. Recreate that compact response with
    // the existing normal/light/view vectors; no additional texture reads.
    if (isClearGlass && translucentAlbedo.a > 0.001
        && nDotL > 0.001 && celestialGate > 0.001) {
        // Unbound clear glass uses its smoothest translucent material response
        // and a 3.5 direct-highlight multiplier when the sampled alpha is solid.
        // The existing alpha product is the equivalent min-alpha gate here.
        vec3 clearGlassLightDirection = normalize(mat3(gbufferModelView) * worldLightDirection);
        vec3 clearGlassViewDirection = normalize(-vViewPosition);
        vec3 clearGlassHalfVector = normalize(clearGlassLightDirection + clearGlassViewDirection);
        float clearGlassSpecular = pow(
            max(dot(normalize(viewNormal), clearGlassHalfVector), 0.0),
            128.0
        ) * 3.5 * nDotL;
        litLinear += celestialColor * celestialIntensity * shadow * celestialGate * clearGlassSpecular;
    }
    if (isStainedGlass && nDotL > 0.001 && celestialGate > 0.001) {
        // Unbound assigns stained glass a medium-smooth surface and a 1.5
        // direct-highlight multiplier. Keep this as a cheap arithmetic-only
        // Blinn term; no new texture reads or material-buffer dependencies.
        vec3 stainedLightDirection = normalize(mat3(gbufferModelView) * worldLightDirection);
        vec3 stainedViewDirection = normalize(-vViewPosition);
        vec3 stainedHalfVector = normalize(stainedLightDirection + stainedViewDirection);
        float stainedSpecular = pow(
            max(dot(normalize(viewNormal), stainedHalfVector), 0.0),
            32.0
        ) * 1.5 * nDotL;
        litLinear += celestialColor * celestialIntensity * shadow * celestialGate * stainedSpecular;
    }
    if (isIce && nDotL > 0.001 && celestialGate > 0.001) {
        float iceSmoothness = translucentAlbedo.g * translucentAlbedo.g * translucentAlbedo.g;
        float iceHighlight = pow(
            min(translucentAlbedo.g * translucentAlbedo.g * 1.5, 1.0),
            2.0
        ) * 3.5;
        vec3 viewLightDirectionForIce = normalize(mat3(gbufferModelView) * worldLightDirection);
        vec3 iceViewDirection = normalize(-vViewPosition);
        vec3 iceHalfVector = normalize(viewLightDirectionForIce + iceViewDirection);
        float iceSpecularExponent = mix(8.0, 128.0, iceSmoothness);
        float iceSpecular = pow(max(dot(normalize(viewNormal), iceHalfVector), 0.0),
                                iceSpecularExponent) * iceHighlight * nDotL * 0.7;
        litLinear += celestialColor * celestialIntensity * shadow * celestialGate * iceSpecular;
    }
    // Lava shares the post-deferred fluid pass but retains its self-emission.
    float lavaEmission = (vMaterialId == 32118) ? 0.9 : 0.0;
    float portalEmission = isPortal
        ? clamp(pow(portalEmissionSignal, 8.0) * 120.0, 0.03, 1.2) * 8.0
          * (PORTAL_EMISSION_STRENGTH * 0.01)
        : 0.0;
    litLinear += albedoLinear * (lavaEmission + portalEmission);

    float fogDistance = (fogShape == 1) ? length(vViewPosition.xz) : length(vViewPosition);
    float fogFactor = calculateTranslucentFog(fogDistance);
    vec3 fogColorLinear = pow(max(fogColor, vec3(0.0)), vec3(2.2));
    litLinear = mix(litLinear, fogColorLinear, fogFactor);

    if ((isGlass || isIce) && GLASS_REFLECTION_STRENGTH > 0.001) {
        vec3 glassViewNormal = normalize(viewNormal);
        if (dot(normalize(vViewPosition), glassViewNormal) > 0.0) {
            glassViewNormal = -glassViewNormal;
        }
        float glassNdotV = clamp(dot(glassViewNormal, normalize(-vViewPosition)), 0.0, 1.0);
        float glassFresnel = 0.02 + 0.98 * pow(1.0 - glassNdotV, 5.0);
        vec3 glassReflectionDirection = normalize(
            reflect(normalize(vViewPosition), glassViewNormal)
        );
        vec3 glassReflectionLinear;
        #if WATER_REFLECTION_QUALITY > 0
        float glassReflectionConfidence = 0.0;
        vec3 glassReflectionColor = sampleTranslucentScreenReflection(
            vViewPosition, glassViewNormal, glassReflectionConfidence
        );
        vec3 glassEnvironmentLinear = glassReflectionConfidence < 0.999
            ? sampleEnvironmentReflection(glassReflectionDirection)
            : vec3(0.0);
        vec3 glassScreenReflectionLinear = pow(max(glassReflectionColor, vec3(0.0)), vec3(2.2));
        glassReflectionLinear = mix(
            glassEnvironmentLinear, glassScreenReflectionLinear, glassReflectionConfidence
        );
        #else
        // Ultra-Light keeps a cheap sky/horizon Fresnel reflection without SSR depth/color samples.
        glassReflectionLinear = sampleEnvironmentReflection(glassReflectionDirection);
        #endif
        float materialReflectionScale = isIce ? 0.7 : ((isTintedGlass || isStainedGlass) ? 1.0 : (isClearGlass ? 0.50 : 0.32));
        float glassCameraDistance = length(vViewPosition);
        float closeReflectionFade = smoothstep(0.3, 1.8, glassCameraDistance);
        float glassReflectionWeight = clamp(
            glassFresnel * materialReflectionScale * closeReflectionFade * (GLASS_REFLECTION_STRENGTH * 0.01),
            0.0, 0.85
        );
        litLinear = mix(litLinear, glassReflectionLinear, glassReflectionWeight);
    }

    if (isTintedGlass) {
        // Unbound raises tinted-glass opacity toward grazing angles using
        // alpha^(1-Fresnel); reuse the reflection path's camera-facing normal.
        vec3 tintedGlassNormal = normalize(viewNormal);
        if (dot(normalize(vViewPosition), tintedGlassNormal) > 0.0) {
            tintedGlassNormal = -tintedGlassNormal;
        }
        float tintedGlassNdotV = clamp(
            dot(tintedGlassNormal, normalize(-vViewPosition)), 0.0, 1.0
        );
        float tintedGlassFresnel = 0.02 + 0.98 * pow(1.0 - tintedGlassNdotV, 5.0);
        translucentAlbedo.a = pow(
            max(translucentAlbedo.a, 0.0), 1.0 - tintedGlassFresnel
        );
    }

    if (isGlass) {
        // Complementary's translucent tweaks slightly reduce glass opacity
        // at very close range to avoid an overpowering near-camera pane.
        float glassCameraDistance = length(vViewPosition);
        float closeGlassFactor = (1.0 - smoothstep(0.5, 4.0, glassCameraDistance)) * 0.5;
        translucentAlbedo.a = mix(
            translucentAlbedo.a,
            translucentAlbedo.a * translucentAlbedo.a,
            closeGlassFactor
        );
    }

    if (isWater) {
        float offsetStrength = clamp(length(waterRefractionOffset) * 25.0, 0.0, 1.0);
        float refractionMix = clamp(
            0.55 * WATER_REFRACTION_STRENGTH * waterFog
            * refractionConfidence * offsetStrength,
            0.0, 0.75
        );
        // The scene copy is already fogged by deferred; do not fog it twice.
        litLinear = mix(litLinear, refractedSceneLinear, refractionMix);

        // Fresnel reflections always retain the cheap Iris sky/horizon and
        // sun/moon fallback. The quality control only enables screen-space rays.
        vec3 reflectionViewNormal = viewNormal;
        float nDotV = clamp(dot(reflectionViewNormal, normalize(-vViewPosition)), 0.0, 1.0);
        float fresnel = 0.02 + 0.98 * pow(1.0 - nDotV, 5.0);
        vec3 reflectionDirection = normalize(
            reflect(normalize(vViewPosition), reflectionViewNormal)
        );
        vec3 reflectionLinear;
        #if WATER_REFLECTION_QUALITY > 0
        // Screen-space reflections use opaque depth and the half-resolution
        // colortex4 snapshot. Quality controls the bounded ray-march steps.
        float reflectionConfidence = 0.0;
        vec3 reflectionColor = sampleTranslucentScreenReflection(
            vViewPosition, reflectionViewNormal, reflectionConfidence
        );
        vec3 environmentReflectionLinear = reflectionConfidence < 0.999
            ? sampleEnvironmentReflection(reflectionDirection)
            : vec3(0.0);
        vec3 screenReflectionLinear = pow(max(reflectionColor, vec3(0.0)), vec3(2.2));
        reflectionLinear = mix(
            environmentReflectionLinear, screenReflectionLinear, reflectionConfidence
        );
        #else
        // Ultra-Light retains environment reflections without SSR depth/color samples.
        reflectionLinear = sampleEnvironmentReflection(reflectionDirection);
        #endif
        float reflectionWeight = clamp(
            min(fresnel * 2.5, 0.85) * WATER_REFLECTION_STRENGTH
            * (1.0 - waterFoam) * (cameraUnderwater ? 0.5 : 1.0),
            0.0, 0.95
        );
        litLinear = mix(litLinear, reflectionLinear, reflectionWeight);
    }

    vec3 litColor = pow(max(litLinear, vec3(0.0)), vec3(1.0 / 2.2));
    outColor = vec4(litColor, translucentAlbedo.a);
}
