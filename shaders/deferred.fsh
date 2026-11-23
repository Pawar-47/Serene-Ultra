#version 330 compatibility

#define CLOUD_SHADOW_STRENGTH 65 // [0 20 40 60 80 100] Procedural cloud-shadow strength
#define CLOUD_ALTITUDE 192 // [128 160 192 224 256] Cloud layer centre height in blocks
#define CLOUD_SPEED 100 // [0 25 50 75 100 125 150] Cloud wind speed

/*
const int colortex2Format = RGBA8;
*/
/*
const int colortex3Format = RGBA8;
*/

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D depthtex0;
uniform sampler2D depthtex2;
uniform sampler2DShadow shadowtex0;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform vec3 cameraPositionFract;
uniform ivec3 cameraPositionInt;
uniform sampler2D noisetex;
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 shadowLightPosition;
uniform float sunAngle;
uniform bool hasSkylight;
uniform float endFlashIntensity;
uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform float fogDensity;
uniform int fogMode;
uniform int fogShape;

// Iris shader constants belong in GLSL, not shaders.properties.
const bool shadowHardwareFiltering = true;

in vec2 vTexCoord;

// Screen-space contact occlusion controls. AO attenuates ambient light only;
// direct sun/moon lighting and emissive/block-light contribution are retained.
#define AO_STRENGTH 0.65 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.65 0.70 0.80 0.90 1.00] Contact occlusion strength
#define AO_RADIUS 1.25 // [0.50 0.75 1.00 1.25 1.50 1.75 2.00 2.50 3.00] Contact occlusion radius in blocks
#define MATERIAL_SPECULAR_STRENGTH 100 // [0 25 50 75 100 125 150 175 200] Deferred specular response for smooth materials
#define MATERIAL_AO_STRENGTH 100 // [0 25 50 75 100] LabPBR material AO lighting strength
#define MATERIAL_SSS_STRENGTH 100 // [0 25 50 75 100 125 150 175 200] LabPBR subsurface scattering strength
#define HELD_LIGHTING_STRENGTH 50 // [0 25 50 75 100] Dynamic main/offhand item light contribution
#define SHADOW_FILTER_QUALITY 8 // [4 8 12] Rotated Poisson PCF shadow samples

// Deferred is a composite-style pass: it reads the main colortex0 image and
// writes the alternate image. Iris flips the pair after this pass, so the
// lit opaque scene becomes the main image for subsequent translucent gbuffers.
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

#include "/lib/lighting/cloud_shadows.glsl"

#include "/lib/lighting/soft_shadow.glsl"

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position) {
    vec4 homogeneous = projectionMatrix * vec4(position, 1.0);
    return homogeneous.xyz / homogeneous.w;
}

float calculateFogFactor(float distanceToCamera) {
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

float sampleContactAO(vec3 viewPosition, vec3 viewNormal) {
    const vec2 samplePattern[8] = vec2[8](
        vec2(-1.0, -1.0), vec2( 0.0, -1.0),
        vec2( 1.0, -1.0), vec2( 1.0,  0.0),
        vec2( 1.0,  1.0), vec2( 0.0,  1.0),
        vec2(-1.0,  1.0), vec2(-1.0,  0.0)
    );

    vec2 texelSize = 1.0 / vec2(textureSize(depthtex2, 0));
    float occlusion = 0.0;
    float validSamples = 0.0;

    for (int i = 0; i < 8; ++i) {
        vec2 sampleUV = vTexCoord + samplePattern[i] * texelSize * 2.0;
        if (sampleUV.x <= 0.0 || sampleUV.x >= 1.0 ||
            sampleUV.y <= 0.0 || sampleUV.y >= 1.0) {
            continue;
        }

        float sampleDepth = texture(depthtex2, sampleUV).r;
        if (sampleDepth >= 0.999999) {
            continue;
        }

        vec3 sampleNdc = vec3(sampleUV, sampleDepth) * 2.0 - 1.0;
        vec3 sampleViewPosition = projectAndDivide(gbufferProjectionInverse, sampleNdc);
        vec3 delta = sampleViewPosition - viewPosition;
        float distanceToSample = length(delta);

        if (distanceToSample < 0.0001 || distanceToSample >= AO_RADIUS) {
            continue;
        }

        vec3 sampleDirection = delta / distanceToSample;
        float facing = max(dot(viewNormal, sampleDirection), 0.0);
        float nearerSurface = step(viewPosition.z + 0.015, sampleViewPosition.z);
        float distanceWeight = 1.0 - smoothstep(AO_RADIUS * 0.35, AO_RADIUS, distanceToSample);

        occlusion += facing * nearerSurface * distanceWeight;
        validSamples += 1.0;
    }

    float normalizedOcclusion = occlusion / max(validSamples, 1.0);
    return clamp(1.0 - normalizedOcclusion * AO_STRENGTH * 1.8, 0.55, 1.0);
}

#include "/lib/lighting/held_item_lighting.glsl"

void main() {
    vec4 scene = texture(colortex0, vTexCoord);
    float sceneDepth = texture(depthtex0, vTexCoord).r;
    float opaqueWorldDepth = texture(depthtex2, vTexCoord).r;
    vec4 normalData = texture(colortex2, vTexCoord);

    // depthtex2 excludes translucent and first-person hand geometry, but
    // colortex0 already contains the hand color. Compare against depthtex0
    // (which includes all geometry) so hand/transparent pixels are passed
    // through instead of shading their color with the opaque surface behind.
    if (opaqueWorldDepth >= 0.999999 ||
        abs(sceneDepth - opaqueWorldDepth) > 0.000001 ||
        normalData.a < 0.5) {
        outColor = scene;
        return;
    }

    vec4 lightData = texture(colortex1, vTexCoord);
    vec3 normal = normalize(normalData.rgb * 2.0 - 1.0);
    float materialSmoothness = clamp((normalData.a - 0.5) * 2.0, 0.0, 1.0);

    vec3 ndcPosition = vec3(vTexCoord, opaqueWorldDepth) * 2.0 - 1.0;
    vec3 viewPosition = projectAndDivide(gbufferProjectionInverse, ndcPosition);
    vec3 playerPosition = (gbufferModelViewInverse * vec4(viewPosition, 1.0)).xyz;
    vec3 viewNormal = normalize(transpose(mat3(gbufferModelViewInverse)) * normal);

    vec3 viewLightDirection = normalize(shadowLightPosition);
    vec3 worldLightDirection = normalize(mat3(gbufferModelViewInverse) * viewLightDirection);
    float nDotL = max(dot(normal, worldLightDirection), 0.0);
    float skyLight = clamp(lightData.a, 0.0, 1.0);
    // Iris sunAngle: 0=dawn, 0.25=noon, 0.5=sunset, 0.75=midnight.
    // Celestial lighting is only used in dimensions with skylight.
    float solarElevation = sin(sunAngle * 6.28318530718);
    bool endFlashActive = endFlashIntensity > 0.001;
    float dayFactor = (hasSkylight && !endFlashActive)
        ? smoothstep(0.0, 0.30, solarElevation)
        : 0.0;
    // Iris can redirect shadowLightPosition to the End flash when enabled.
    // Nether has neither skylight nor an End flash, so its direct term is zero.
    float celestialGate = endFlashActive
        ? clamp(endFlashIntensity, 0.0, 1.0)
        : (hasSkylight ? skyLight : 0.0);
    vec3 shadow = vec3(1.0);
    if (nDotL > 0.001 && celestialGate > 0.001) {
        shadow = sampleSereneSoftShadow(playerPosition, normal, worldLightDirection);
    }

    // Use Minecraft's own sampled lightmap RGB as the ambient/block-light
    // foundation so its existing colored light response is retained.
    vec4 emissionData = texture(colortex3, vTexCoord);
    float materialAO = clamp(emissionData.b, 0.0, 1.0);
    float materialAOFactor = mix(1.0, materialAO, MATERIAL_AO_STRENGTH * 0.01);
    vec3 vanillaAmbient = pow(max(lightData.rgb, vec3(0.0)), vec3(2.2));
    vec3 ambient = vec3(0.018) + vanillaAmbient * 0.72;

    // Contact and LabPBR material AO attenuate indirect/block light only;
    // direct celestial illumination remains separate and unaffected.
    float contactAO = sampleContactAO(viewPosition, viewNormal);
    ambient *= contactAO;
    ambient *= materialAOFactor;

#if HELD_LIGHTING_STRENGTH > 0
    vec3 heldLighting = calculateHeldItemLighting(playerPosition);
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
    float cloudShadow = sampleSereneCloudShadow(playerPosition, worldLightDirection, dayFactor);
    direct *= cloudShadow;

    // Decode sampled sRGB albedo for lighting, then encode it again for the
    // existing color-grading/final pass. This keeps the output contract intact.
    vec3 albedoLinear = pow(max(scene.rgb, vec3(0.0)), vec3(2.2));
    float materialReflectance = clamp(emissionData.g, 0.0, 1.0);
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
    float labDielectricF0 = materialReflectance;
    vec3 specularColor = (materialReflectance >= (230.0 / 255.0))
        ? albedoLinear
        : vec3(labDielectricF0);
#else
    vec3 specularColor = mix(vec3(0.04), albedoLinear, materialReflectance);
#endif
    vec3 litLinear = albedoLinear * (ambient + direct);

    // Low-cost GGX direct specular. The branch is skipped for non-glossy
    // surfaces and when no direct celestial light reaches the pixel.
    if (materialSmoothness > 0.01 && MATERIAL_SPECULAR_STRENGTH > 0
        && nDotL > 0.001 && celestialGate > 0.001) {
        vec3 viewDirectionPlayer = normalize(mat3(gbufferModelViewInverse) * normalize(-viewPosition));
        vec3 halfVector = worldLightDirection + viewDirectionPlayer;
        float halfVectorLengthSquared = dot(halfVector, halfVector);
        if (halfVectorLengthSquared > 0.000001) {
            vec3 halfDirection = halfVector * inversesqrt(halfVectorLengthSquared);
            float nDotV = max(dot(normal, viewDirectionPlayer), 0.001);
            float nDotH = max(dot(normal, halfDirection), 0.0);
            float vDotH = max(dot(viewDirectionPlayer, halfDirection), 0.0);
            float roughness = max(1.0 - materialSmoothness, 0.08);
            float alpha = roughness * roughness;
            float alphaSquared = alpha * alpha;
            float distributionDenominator = nDotH * nDotH * (alphaSquared - 1.0) + 1.0;
            float distribution = alphaSquared
                / max(3.14159265359 * distributionDenominator * distributionDenominator, 0.000001);
            float geometryK = (roughness + 1.0) * (roughness + 1.0) * 0.125;
            float geometryV = nDotV / (nDotV * (1.0 - geometryK) + geometryK);
            float geometryL = nDotL / (nDotL * (1.0 - geometryK) + geometryK);
            float fresnelFactor = 1.0 - vDotH;
            fresnelFactor *= fresnelFactor;
            fresnelFactor *= fresnelFactor * (1.0 - vDotH);
            vec3 fresnel = specularColor + (1.0 - specularColor) * fresnelFactor;
            vec3 specularBRDF = distribution * geometryV * geometryL * fresnel
                / max(4.0 * nDotV * nDotL, 0.001);
            vec3 specularContribution = direct * specularBRDF
                * (MATERIAL_SPECULAR_STRENGTH * 0.01) * 0.18;
            // Keep very sharp PBR peaks stable on low-bandwidth integrated GPUs.
            specularContribution /= (1.0 + 0.125 * specularContribution);
            litLinear += specularContribution;
        }
    }

    // LabPBR blue stores porosity (0-64) or subsurface scattering (65-255).
    // Decode the SSS range here; porosity remains packed for later wet-surface work.
    float materialSSS = 0.0;
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
    float materialSurfaceCode = floor(emissionData.a * 255.0 + 0.5);
    if (materialSurfaceCode >= 65.0) {
        materialSSS = clamp((materialSurfaceCode - 65.0) / 190.0, 0.0, 1.0);
    }
#endif
    float sssStrength = materialSSS * MATERIAL_SSS_STRENGTH * 0.01;
    if (sssStrength > 0.001 && celestialGate > 0.001) {
        float backLighting = pow(max(dot(-normal, worldLightDirection), 0.0), 2.0);
        vec3 sssVisibility = mix(shadow, vec3(1.0), sssStrength * 0.65);
        vec3 sssContribution = albedoLinear * celestialColor
            * (celestialIntensity * celestialGate) * backLighting
            * sssStrength * sssVisibility * 0.25 * cloudShadow;
        litLinear += sssContribution;
    }

    // Emission is stored separately from albedo/lightmap/normal so it is not
    // attenuated by contact AO or the celestial shadow term.
    litLinear += albedoLinear * (emissionData.r * 5.0);

    float fogDistance = (fogShape == 1) ? max(length(viewPosition.xz), abs(viewPosition.y)) : length(viewPosition);
    float fogFactor = calculateFogFactor(fogDistance);
    vec3 fogColorLinear = pow(max(fogColor, vec3(0.0)), vec3(2.2));
    litLinear = mix(litLinear, fogColorLinear, fogFactor);

    vec3 litColor = pow(max(litLinear, vec3(0.0)), vec3(1.0 / 2.2));

    outColor = vec4(litColor, scene.a);
}
