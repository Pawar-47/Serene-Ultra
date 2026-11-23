#version 330 compatibility

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform sampler2D normals;
uniform mat4 gbufferModelViewInverse;
uniform vec3 shadowLightPosition;
uniform sampler2D specular;
uniform sampler2D noisetex;
uniform ivec3 cameraPositionInt;
uniform vec3 cameraPositionFract;
uniform float alphaTestRef;
uniform float wetness;
uniform float rainfall;
uniform int biome_precipitation;
uniform vec4 entityColor;
uniform int entityId;
uniform int currentRenderedItemId;


#define ANISOTROPIC_FILTER_QUALITY 2 // [1 2 4] Shader-level material anisotropic filtering taps

vec4 sampleAnisotropicAtlas(
    sampler2D sourceTexture,
    vec2 uv,
    vec2 uvDx,
    vec2 uvDy,
    vec4 spriteBounds
) {
#if ANISOTROPIC_FILTER_QUALITY > 1
    vec2 majorGradient = dot(uvDx, uvDx) >= dot(uvDy, uvDy)
        ? uvDx : uvDy;
    float majorLength = length(majorGradient);
    float minorLength = max(min(length(uvDx), length(uvDy)), 0.000001);
    int sampleCount = int(clamp(
        ceil(majorLength / minorLength),
        1.0, float(ANISOTROPIC_FILTER_QUALITY)
    ));
    if (sampleCount <= 1) return textureGrad(sourceTexture, uv, uvDx, uvDy);

    vec2 atlasTexel = 1.0 / vec2(textureSize(sourceTexture, 0));
    vec2 tileSize = max(spriteBounds.zw, vec2(1e-7));
    vec2 lowerBound = spriteBounds.xy + 0.5 * atlasTexel;
    vec2 upperBound = spriteBounds.xy + tileSize - 0.5 * atlasTexel;
    vec4 accumulated = vec4(0.0);
    for (int tap = 0; tap < ANISOTROPIC_FILTER_QUALITY; ++tap) {
        if (tap >= sampleCount) break;
        float tapOffset = (float(tap) + 0.5) / float(sampleCount) - 0.5;
        vec2 sampleUv = clamp(
            uv + majorGradient * tapOffset, lowerBound, upperBound
        );
        accumulated += textureGrad(sourceTexture, sampleUv, uvDx, uvDy);
    }
    return accumulated / float(sampleCount);
#else
    return textureGrad(sourceTexture, uv, uvDx, uvDy);
#endif
}


#define POM_SLOPE_NORMAL_STRENGTH 50 // [0 25 50 75 100] Height-map slope normal detail
#define POM_SELF_SHADOW_STRENGTH 65 // [0 25 50 75 100] Height-map self-shadowing strength

float calculateEntityPomSelfShadow(
    vec2 surfaceUv, vec2 uvDx, vec2 uvDy, vec4 spriteBounds,
    vec3 playerTangent, vec3 playerNormal, float tangentHandedness,
    float viewDistance
) {
#if POM_ENTITY_STRENGTH > 0 && POM_SELF_SHADOW_STRENGTH > 0
    vec3 playerLightDirection = normalize(
        mat3(gbufferModelViewInverse) * normalize(shadowLightPosition)
    );
    vec3 tangent = normalize(playerTangent);
    vec3 normal = normalize(playerNormal);
    vec3 bitangent = normalize(cross(tangent, normal)) * tangentHandedness;
    vec3 tangentLight = vec3(
        dot(playerLightDirection, tangent),
        dot(playerLightDirection, bitangent),
        dot(playerLightDirection, normal)
    );
    if (tangentLight.z <= 0.05) return 1.0;

    float distanceFade = 1.0 - smoothstep(
        float(POM_DISTANCE) * 0.55, float(POM_DISTANCE), viewDistance
    );
    float heightScale = clamp(float(POM_ENTITY_STRENGTH) * 0.003, 0.0, 0.20)
        * distanceFade;
    if (heightScale <= 0.0001) return 1.0;

    vec2 tileSize = max(spriteBounds.zw, vec2(1e-7));
    vec2 atlasTexel = 1.0 / vec2(textureSize(normals, 0));
    vec2 lowerBound = spriteBounds.xy + 0.5 * atlasTexel;
    vec2 upperBound = spriteBounds.xy + tileSize - 0.5 * atlasTexel;
    float surfaceDepth = 1.0 - textureGrad(normals, surfaceUv, uvDx, uvDy).a;
    vec2 lightRayUv = tangentLight.xy / max(tangentLight.z, 0.12)
        * heightScale * 0.72;
    float shadow = 1.0;
    for (int stepIndex = 1; stepIndex <= 4; ++stepIndex) {
        float rayProgress = float(stepIndex) * 0.25;
        vec2 sampleUv = clamp(
            surfaceUv + lightRayUv * rayProgress, lowerBound, upperBound
        );
        float sampleDepth = 1.0
            - textureGrad(normals, sampleUv, uvDx, uvDy).a;
        float rayDepth = max(surfaceDepth - rayProgress * 0.22, 0.0);
        float heightOccluder = clamp(
            (rayDepth - sampleDepth - 0.012) * 8.0, 0.0, 1.0
        );
        shadow = min(
            shadow,
            1.0 - heightOccluder
                * (float(POM_SELF_SHADOW_STRENGTH) * 0.01) * 0.78
        );
    }
    return clamp(shadow, 0.22, 1.0);
#else
    return 1.0;
#endif
}


in vec2 vTexCoord;
in vec2 vLightmapCoord;
in vec4 vVertexColor;
in vec3 vPlayerNormal;
in vec3 vPlayerTangent;
flat in float vTangentHandedness;
in vec3 vTangentView;
flat in vec4 vTexCoordAM;
in vec3 vPlayerPosition;

/* RENDERTARGETS: 0,1,2,3 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outLightmapData;
layout(location = 2) out vec4 outEncodedNormal;
layout(location = 3) out vec4 outEmissionData;

#define OPAQUE_NORMAL_MAP_STRENGTH 100 // [0 25 50 75 100 125 150] Resource-pack PBR normal-map detail
#define PBR_AO_STRENGTH 100 // [0 25 50 75 100] LabPBR material ambient occlusion
#define POM_ENTITY_STRENGTH 0 // [0 10 20 35 50] Entity-model POM
#define POM_QUALITY 4 // [4 6 8] Bounded POM samples; higher values cost more
#define POM_DISTANCE 32 // [12 16 24 32 48 64] Fade POM to zero at this view distance
//#define ENTITY_GN_AND_CT // Optional entity generated normals and coated textures; off by default
#define GENERATED_NORMAL_STRENGTH 25 // [0 10 20 35 50 75 100] Albedo-derived normal detail when no normal map is present
#define COATED_TEXTURE_STRENGTH 20 // [0 10 20 35 50 75 100] Stable subtle noise coating on opaque material colour
#define MATERIAL_WETNESS_STRENGTH 100 // [0 25 50 75 100 125 150] LabPBR porosity-driven wet darkening
#include "/lib/materials/porosity_wetness.glsl"

vec2 calculateParallaxUv(
    vec2 baseUv,
    vec2 uvDx,
    vec2 uvDy,
    vec4 spriteBounds,
    vec3 tangentView,
    float viewDistance,
    out float appliedOffset
) {
    appliedOffset = 0.0;
#if POM_ENTITY_STRENGTH > 0
    if (viewDistance >= float(POM_DISTANCE) || tangentView.z >= -0.05) return baseUv;

    float distanceFade = 1.0 - smoothstep(
        float(POM_DISTANCE) * 0.55, float(POM_DISTANCE), viewDistance
    );
    float heightScale = clamp(float(POM_ENTITY_STRENGTH) * 0.003, 0.0, 0.20) * distanceFade;
    if (heightScale <= 0.0001) return baseUv;

    vec2 tileSize = max(spriteBounds.zw, vec2(1e-7));
    vec2 localUv = clamp((baseUv - spriteBounds.xy) / tileSize, vec2(0.0), vec2(1.0));
    vec4 initialNormal = textureGrad(normals, baseUv, uvDx, uvDy);
    if (initialNormal.a >= 0.9995) return baseUv;

    vec2 totalOffset = tangentView.xy / max(-tangentView.z, 0.12) * heightScale;
    float offsetLength = length(totalOffset);
    if (offsetLength > 0.20) totalOffset *= 0.20 / offsetLength;
    vec2 stepOffset = totalOffset / float(POM_QUALITY);

    vec2 atlasTexel = 1.0 / vec2(textureSize(normals, 0));
    vec2 lowerBound = spriteBounds.xy + 0.5 * atlasTexel;
    vec2 upperBound = spriteBounds.xy + tileSize - 0.5 * atlasTexel;

    vec2 previousLocal = localUv;
    float previousLayerDepth = 0.0;
    float previousSurfaceDepth = 1.0 - initialNormal.a;
    vec2 currentLocal = localUv;
    float currentLayerDepth = 0.0;
    float currentSurfaceDepth = previousSurfaceDepth;

    for (int stepIndex = 0; stepIndex < POM_QUALITY; ++stepIndex) {
        // LabPBR height alpha 1 is the top surface; lower alpha is deeper.
        if (currentLayerDepth >= currentSurfaceDepth) break;

        previousLocal = currentLocal;
        previousLayerDepth = currentLayerDepth;
        previousSurfaceDepth = currentSurfaceDepth;

        currentLocal = clamp(currentLocal + stepOffset, vec2(0.0), vec2(1.0));
        currentLayerDepth += 1.0 / float(POM_QUALITY);
        vec2 sampleUv = clamp(
            spriteBounds.xy + currentLocal * tileSize, lowerBound, upperBound
        );
        float sampledHeight = textureGrad(normals, sampleUv, uvDx, uvDy).a;
        currentSurfaceDepth = 1.0 - sampledHeight;
    }

    // Refine the intersection between the last above-surface and below-surface steps.
    float beforeDelta = previousLayerDepth - previousSurfaceDepth;
    float afterDelta = currentLayerDepth - currentSurfaceDepth;
    float denominator = beforeDelta - afterDelta;
    float interpolation = abs(denominator) > 1e-5
        ? clamp(beforeDelta / denominator, 0.0, 1.0) : 1.0;
    vec2 hitLocal = mix(previousLocal, currentLocal, interpolation);
    vec2 hitUv = clamp(spriteBounds.xy + hitLocal * tileSize, lowerBound, upperBound);
    appliedOffset = length(hitLocal - localUv);
    return hitUv;
#else
    return baseUv;
#endif
}


vec3 calculateOpaquePbrNormal(vec3 geometricNormal, vec2 materialUv, vec2 uvDx, vec2 uvDy, out float materialAO, out bool hasExplicitNormal) {
    vec4 normalTexel = sampleAnisotropicAtlas(normals, materialUv, uvDx, uvDy, vTexCoordAM);
    hasExplicitNormal = any(greaterThan(abs(normalTexel.rg - vec2(0.5)), vec2(0.01)));
    vec3 tangentNormal;
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
    // LabPBR blue stores material AO; XY are the DirectX Y- tangent normal.
    materialAO = mix(1.0, clamp(normalTexel.b, 0.0, 1.0), PBR_AO_STRENGTH * 0.01);
    tangentNormal.xy = normalTexel.rg * 2.0 - 1.0;
    tangentNormal.z = sqrt(max(1.0 - dot(tangentNormal.xy, tangentNormal.xy), 0.0));
    tangentNormal.y = -tangentNormal.y;
#else
    materialAO = 1.0;
    tangentNormal = normalTexel.rgb * 2.0 - 1.0;
#endif
#if POM_ENTITY_STRENGTH > 0 && POM_SLOPE_NORMAL_STRENGTH > 0
    if (normalTexel.a < 0.9995) {
        vec2 heightTexel = 1.0 / vec2(textureSize(normals, 0));
        vec2 tileSize = max(vTexCoordAM.zw, vec2(1e-7));
        vec2 lowerBound = vTexCoordAM.xy + 0.5 * heightTexel;
        vec2 upperBound = vTexCoordAM.xy + tileSize - 0.5 * heightTexel;
        float heightLeft = textureGrad(normals,
            clamp(materialUv - vec2(heightTexel.x, 0.0), lowerBound, upperBound),
            uvDx, uvDy).a;
        float heightRight = textureGrad(normals,
            clamp(materialUv + vec2(heightTexel.x, 0.0), lowerBound, upperBound),
            uvDx, uvDy).a;
        float heightDown = textureGrad(normals,
            clamp(materialUv - vec2(0.0, heightTexel.y), lowerBound, upperBound),
            uvDx, uvDy).a;
        float heightUp = textureGrad(normals,
            clamp(materialUv + vec2(0.0, heightTexel.y), lowerBound, upperBound),
            uvDx, uvDy).a;
        vec2 heightSlope = vec2(heightLeft - heightRight, heightDown - heightUp);
        tangentNormal.xy += clamp(
            heightSlope * (float(POM_SLOPE_NORMAL_STRENGTH) * 0.015),
            vec2(-0.5), vec2(0.5)
        );
    }
#endif
#if OPAQUE_NORMAL_MAP_STRENGTH > 0
    tangentNormal.xy *= OPAQUE_NORMAL_MAP_STRENGTH * 0.01;
    tangentNormal = normalize(tangentNormal);

    vec3 tangentCandidate = vPlayerTangent - geometricNormal * dot(vPlayerTangent, geometricNormal);
    float tangentLengthSquared = dot(tangentCandidate, tangentCandidate);
    if (tangentLengthSquared < 0.000001) return geometricNormal;

    vec3 tangent = tangentCandidate * inversesqrt(tangentLengthSquared);
    vec3 bitangent = normalize(cross(tangent, geometricNormal)) * vTangentHandedness;
    return normalize(
        tangent * tangentNormal.x +
        bitangent * tangentNormal.y +
        geometricNormal * tangentNormal.z
    );
#else
    return geometricNormal;
#endif
}




vec3 calculateGeneratedAlbedoNormal(
    vec3 geometricNormal,
    vec2 materialUv,
    vec2 uvDx,
    vec2 uvDy,
    vec2 uvFootprint,
    vec4 spriteBounds
) {
#if GENERATED_NORMAL_STRENGTH > 0
    vec2 atlasTexel = 1.0 / vec2(textureSize(gtexture, 0));
    vec2 sampleOffset = max(uvFootprint, atlasTexel);
    vec2 tileSize = max(spriteBounds.zw, vec2(1e-7));
    vec2 lowerBound = spriteBounds.xy + 0.5 * atlasTexel;
    vec2 upperBound = spriteBounds.xy + tileSize - 0.5 * atlasTexel;

    vec2 rightUv = clamp(materialUv + vec2(sampleOffset.x, 0.0), lowerBound, upperBound);
    vec2 leftUv  = clamp(materialUv - vec2(sampleOffset.x, 0.0), lowerBound, upperBound);
    vec2 upUv    = clamp(materialUv + vec2(0.0, sampleOffset.y), lowerBound, upperBound);
    vec2 downUv  = clamp(materialUv - vec2(0.0, sampleOffset.y), lowerBound, upperBound);

    vec4 rightSample = textureGrad(gtexture, rightUv, uvDx, uvDy) * vVertexColor;
    vec4 leftSample  = textureGrad(gtexture, leftUv, uvDx, uvDy) * vVertexColor;
    vec4 upSample    = textureGrad(gtexture, upUv, uvDx, uvDy) * vVertexColor;
    vec4 downSample  = textureGrad(gtexture, downUv, uvDx, uvDy) * vVertexColor;

    // Avoid synthesizing slopes across cutout holes or partial-alpha edges.
    if (min(min(rightSample.a, leftSample.a), min(upSample.a, downSample.a)) < 0.999) {
        return geometricNormal;
    }

    const vec3 luminanceWeights = vec3(0.2126, 0.7152, 0.0722);
    float rightHeight = dot(rightSample.rgb, luminanceWeights);
    float leftHeight = dot(leftSample.rgb, luminanceWeights);
    float upHeight = dot(upSample.rgb, luminanceWeights);
    float downHeight = dot(downSample.rgb, luminanceWeights);

    float deltaX = rightHeight - leftHeight;
    float deltaY = upHeight - downHeight;
    if (abs(deltaX) < 0.05) deltaX = 0.0;
    if (abs(deltaY) < 0.05) deltaY = 0.0;
    deltaX = clamp(deltaX, -0.2, 0.2);
    deltaY = clamp(deltaY, -0.2, 0.2);
    if (deltaX == 0.0 && deltaY == 0.0) return geometricNormal;

    vec3 tangentNormal = normalize(vec3(-deltaX, -deltaY, 1.0));
    tangentNormal.xy *= float(GENERATED_NORMAL_STRENGTH) * 0.025;
    tangentNormal = normalize(tangentNormal);

    vec3 tangentCandidate = vPlayerTangent - geometricNormal * dot(vPlayerTangent, geometricNormal);
    float tangentLengthSquared = dot(tangentCandidate, tangentCandidate);
    if (tangentLengthSquared < 0.000001) return geometricNormal;

    vec3 tangent = tangentCandidate * inversesqrt(tangentLengthSquared);
    vec3 bitangent = normalize(cross(tangent, geometricNormal)) * vTangentHandedness;
    return normalize(
        tangent * tangentNormal.x +
        bitangent * tangentNormal.y +
        geometricNormal * tangentNormal.z
    );
#else
    return geometricNormal;
#endif
}


vec3 applyCoatedTexture(
    vec3 color,
    vec2 uvDx,
    vec2 uvDy,
    vec4 spriteBounds,
    vec3 playerPosition
) {
#if COATED_TEXTURE_STRENGTH > 0
    vec2 atlasSize = vec2(textureSize(gtexture, 0));
    vec2 spriteCenter = spriteBounds.xy + spriteBounds.zw * 0.5;
    vec2 noiseCoord = floor(spriteCenter * atlasSize / 16.0 * 64.0) / 64.0 / 3.0;

    vec3 worldPosition = vec3(cameraPositionInt) + cameraPositionFract + playerPosition;
    vec3 floorWorldPosition = floor(worldPosition + vec3(0.001));
    noiseCoord += 0.84 * (floorWorldPosition.xz + vec2(floorWorldPosition.y));

    float noiseValue = textureLod(noisetex, noiseCoord, 0.0).r + 0.6;
    float colorBrightness = dot(color, color) * 0.3;
    float texelFootprint = max(length(uvDx * atlasSize), length(uvDy * atlasSize));
    float mipLevel = max(0.0, log2(max(texelFootprint, 1.0)));
    float noiseFactor = float(COATED_TEXTURE_STRENGTH) * 0.0027
        * max(1.0 - colorBrightness, 0.0);
    noiseFactor *= max(1.0 - mipLevel * 0.25, 0.0);
    color *= pow(max(noiseValue, 0.01), noiseFactor);
#endif
    return color;
}

void main() {
    vec2 uvDx = dFdx(vTexCoord);
    vec2 uvDy = dFdy(vTexCoord);
    vec2 uvFootprint = max(fwidth(vTexCoord), 1.0 / vec2(textureSize(gtexture, 0)));
    vec2 materialUv = vTexCoord;
    vec4 albedo = sampleAnisotropicAtlas(gtexture, materialUv, uvDx, uvDy, vTexCoordAM) * vVertexColor;
    float albedoDetail = length(fwidth(albedo.rgb));
    if (albedo.a < alphaTestRef) discard;
    float parallaxOffset = 0.0;
    float pomSelfShadow = 1.0;
#if POM_ENTITY_STRENGTH > 0
    if (gl_FrontFacing && entityId != 50128 && entityId != 50132) {
        vec2 parallaxUv = calculateParallaxUv(vTexCoord, uvDx, uvDy, vTexCoordAM,
            vTangentView, length(vTangentView), parallaxOffset);
        if (parallaxOffset > 0.00001) {
            vec4 parallaxAlbedo = sampleAnisotropicAtlas(gtexture, parallaxUv, uvDx, uvDy, vTexCoordAM) * vVertexColor;
            if (parallaxAlbedo.a >= alphaTestRef) {
                materialUv = parallaxUv;
                albedo = parallaxAlbedo;
            }
        }
    }
#endif

    // Iris entity tint carries a blend factor in alpha. Blend sampled colors
    // in linear space, then re-encode for the G-buffer color representation.
    vec3 entityAlbedoLinear = pow(max(albedo.rgb, vec3(0.0)), vec3(2.2));
    vec3 entityTintLinear = pow(max(entityColor.rgb, vec3(0.0)), vec3(2.2));
    albedo.rgb = pow(max(mix(entityAlbedoLinear, entityTintLinear, entityColor.a), vec3(0.0)), vec3(1.0 / 2.2));

    vec3 vanillaLight = texture(lightmap, vLightmapCoord).rgb;
    float skyLight = clamp(vLightmapCoord.y / (30.0 / 32.0) - (1.0 / 32.0), 0.0, 1.0);
#if POM_ENTITY_STRENGTH > 0 && POM_SELF_SHADOW_STRENGTH > 0
    if (parallaxOffset > 0.00001) {
        pomSelfShadow = calculateEntityPomSelfShadow(
            materialUv, uvDx, uvDy, vTexCoordAM,
            vPlayerTangent, vPlayerNormal, vTangentHandedness,
            length(vTangentView)
        );
    }
#endif
    outLightmapData = vec4(vanillaLight, skyLight * pomSelfShadow);
    vec3 surfaceNormal = normalize(vPlayerNormal);
    if (!gl_FrontFacing) surfaceNormal = -surfaceNormal;
    float materialAO = 1.0;
    bool hasExplicitNormal = false;
    surfaceNormal = calculateOpaquePbrNormal(surfaceNormal, materialUv, uvDx, uvDy, materialAO, hasExplicitNormal);
#ifdef ENTITY_GN_AND_CT
#if GENERATED_NORMAL_STRENGTH > 0
    if (gl_FrontFacing && !hasExplicitNormal && albedo.a >= 0.999 && albedoDetail > 0.002 &&
        entityId != 50128 && entityId != 50132) {
        surfaceNormal = calculateGeneratedAlbedoNormal(surfaceNormal, materialUv, uvDx, uvDy, uvFootprint, vTexCoordAM);
    }
#endif
#endif
    vec4 pbrSpecular = sampleAnisotropicAtlas(specular, materialUv, uvDx, uvDy, vTexCoordAM);
    float specularMapMagnitude = max(max(pbrSpecular.r, pbrSpecular.g), max(pbrSpecular.b, pbrSpecular.a));
    bool hasMaterialSpecularMap = specularMapMagnitude > 0.0001;
    float materialSmoothness = clamp(pbrSpecular.r, 0.0, 1.0);
    float materialReflectance = 0.0;
    float pbrEmission = 0.0;
    float materialSurfaceData = 0.0;
    float materialPorosity = 0.0;
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
    materialSurfaceData = clamp(pbrSpecular.b, 0.0, 1.0);
    float labF0Code = floor(pbrSpecular.g * 255.0 + 0.5);
    float labSurfaceCode = floor(pbrSpecular.b * 255.0 + 0.5);
    if (labF0Code < 65.0) {
        materialPorosity = clamp(labSurfaceCode / 64.0, 0.0, 1.0);
        materialSurfaceData = 0.0; // Blue is porosity here, not SSS.
    }
    if (!hasMaterialSpecularMap) {
        materialReflectance = 0.04;
    } else if (labF0Code >= 230.0) {
        materialReflectance = 1.0;
        materialSurfaceData = 0.0;
    } else {
        materialReflectance = labF0Code / 255.0;
    }
    float labEmissionCode = floor(pbrSpecular.a * 255.0 + 0.5);
    if (labEmissionCode < 254.5) pbrEmission = labEmissionCode / 254.0;
#else
    materialReflectance = clamp(pbrSpecular.g, 0.0, 1.0);
    pbrEmission = clamp(pbrSpecular.b, 0.0, 1.0);
#endif

    // The deferred buffer interprets LabPBR reflectance as F0 and oldPBR as metalness.
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
    float itemIronReflectance = 1.0;
    float itemGoldReflectance = 1.0;
    float itemDiamondReflectance = 1.0;
    float itemNetheriteReflectance = 1.0;
    float itemCopperReflectance = 1.0;
    float itemClockReflectance = 1.0;
#else
    float itemIronReflectance = 0.75;
    float itemGoldReflectance = 0.9;
    float itemDiamondReflectance = 0.55;
    float itemNetheriteReflectance = 0.85;
    float itemCopperReflectance = 0.65;
    float itemClockReflectance = 0.75;
#endif
    if (!hasMaterialSpecularMap) {
        if (currentRenderedItemId == 45000) { // Armor trims
            materialSmoothness = 0.5;
            materialReflectance = 0.2;
        } else if (currentRenderedItemId == 45004) { // Wooden tools and bows
            float woodGloss = dot(albedo.rgb, vec3(0.3));
            materialSmoothness = clamp(woodGloss * woodGloss, 0.0, 0.4);
        } else if (currentRenderedItemId == 45008) { // Stone tools
            materialSmoothness = clamp(pow(albedo.g, 4.0) * 2.0, 0.0, 1.0);
        } else if (currentRenderedItemId == 45012 || currentRenderedItemId == 45013) {
            materialSmoothness = clamp(pow(albedo.r, 2.0), 0.0, 1.0);
            materialReflectance = itemIronReflectance;
        } else if (currentRenderedItemId == 45016 || currentRenderedItemId == 45017 || currentRenderedItemId == 45108) {
            float goldGreenFourth = pow(albedo.g, 4.0);
            materialSmoothness = clamp(max(albedo.g, 0.8) - goldGreenFourth * 0.5, 0.0, 1.0);
            materialReflectance = itemGoldReflectance;
        } else if (currentRenderedItemId == 45020 || currentRenderedItemId == 45021) {
            materialSmoothness = clamp(max(albedo.g, 0.8) - pow(albedo.g, 4.0) * 0.4, 0.0, 1.0);
            materialReflectance = itemDiamondReflectance;
        } else if (currentRenderedItemId == 45024 || currentRenderedItemId == 45025 || currentRenderedItemId == 45026) {
            materialSmoothness = clamp(albedo.b * 1.65, 0.0, 1.0);
            materialReflectance = itemNetheriteReflectance;
        } else if (currentRenderedItemId == 45036) {
            float colorDifference = max(max(abs(albedo.r - albedo.g), abs(albedo.g - albedo.b)), abs(albedo.r - albedo.b));
            materialSmoothness = colorDifference < 0.01
                ? clamp(pow(albedo.r, 2.0), 0.0, 1.0)
                : clamp(albedo.b, 0.0, 1.0);
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
            materialReflectance = colorDifference < 0.01 ? 1.0 : 0.04;
#else
            materialReflectance = colorDifference < 0.01 ? 0.75 : 0.1;
#endif
        } else if (currentRenderedItemId == 45056) {
            materialSmoothness = clamp(0.8 - pow(albedo.r, 2.0) * 0.3, 0.0, 1.0);
            materialReflectance = 0.15;
        } else if (currentRenderedItemId == 45060) {
            materialSmoothness = clamp(min(albedo.r * albedo.g * albedo.b * 4.0, 0.7) * 0.7, 0.0, 1.0);
        } else if (currentRenderedItemId == 45064) {
            materialSmoothness = clamp(albedo.g * 0.7, 0.0, 1.0);
        } else if (currentRenderedItemId == 45068) {
            materialSmoothness = 1.0;
        } else if (currentRenderedItemId == 45076 || currentRenderedItemId == 45108) {
            float goldGreenFourth = pow(albedo.g, 4.0);
            materialSmoothness = clamp(max(albedo.g, 0.8) - goldGreenFourth * 0.5, 0.0, 1.0);
            materialReflectance = itemClockReflectance;
        } else if (currentRenderedItemId == 45080 || currentRenderedItemId == 45084) {
            materialSmoothness = clamp(pow(albedo.r, 2.0), 0.0, 1.0);
            materialReflectance = itemIronReflectance;
        } else if (currentRenderedItemId == 44013 && albedo.r + albedo.g <= albedo.b * 2.0) {
            materialSmoothness = clamp(pow(albedo.r, 2.0), 0.0, 1.0);
            materialReflectance = itemIronReflectance;
        } else if (currentRenderedItemId == 44085) {
            materialSmoothness = clamp(albedo.g, 0.0, 1.0);
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
            materialReflectance = 1.0;
#else
            materialReflectance = 0.65;
#endif
        } else if (currentRenderedItemId == 45116 || currentRenderedItemId == 45117) {
            float copperSmoothness = pow(albedo.r, 4.0)
                + pow(max(albedo.g - albedo.r * 0.5, 0.0), 2.0) * 0.3;
            materialSmoothness = clamp(copperSmoothness, 0.0, 1.0);
            materialReflectance = itemCopperReflectance;
        }
    }

    if (pbrEmission < 0.01) {
        // Entity-specific vanilla emissive fallbacks. Restrict these cues to
        // mapped entity IDs so unrelated orange/blue textures are unaffected.
        if (entityId == 50140) { // Glow squid
            pbrEmission = clamp(albedo.b * 0.85 + albedo.g * 0.15, 0.0, 1.0);
        } else if (entityId == 50144) { // Blaze rods/body
            pbrEmission = clamp(max(albedo.r + albedo.g * 0.35 - albedo.b, 0.0) * 0.42, 0.0, 0.85);
        } else if (entityId == 50148) { // Magma cube hot core
            float hotCore = max(albedo.r - albedo.g * 0.72, 0.0);
            pbrEmission = clamp(hotCore * 0.65, 0.0, 0.75);
        } else if (entityId == 50152) { // End crystal
            pbrEmission = clamp(max(albedo.r, max(albedo.g, albedo.b)) * 0.72, 0.0, 0.9);
        } else if (entityId == 50156) { // Experience orb
            float orbGreen = max(albedo.g - albedo.r * 0.35 - albedo.b * 0.20, 0.0);
            pbrEmission = clamp(orbGreen * 1.35, 0.0, 0.85);
        } else if (currentRenderedItemId == 44090) {
            if (!hasMaterialSpecularMap) materialSmoothness = 1.0;
            pbrEmission = max(albedo.g - albedo.b * 0.25, 0.0);
        } else if (currentRenderedItemId == 44013) {
            if (albedo.r + albedo.g > albedo.b * 2.0) {
                pbrEmission = max(albedo.r + albedo.g - albedo.b * 1.5, 0.0) * 1.8;
                albedo.rg += albedo.b * vec2(0.4, 0.15);
                albedo.b *= 0.8;
            }
        } else if (currentRenderedItemId == 44040) {
            pbrEmission = 1.0;
        } else if (currentRenderedItemId == 44053) {
            if (albedo.g < albedo.r) pbrEmission = 3.0;
        } else if (currentRenderedItemId == 44085) {
            float tridentFactor = min(dot(albedo.rgb, albedo.rgb), 2.5);
            pbrEmission = min(max(tridentFactor - 1.0, 0.0) * 6.0, 1.0);
        } else if (currentRenderedItemId == 44086) {
            pbrEmission = albedo.b * 2.0;
        } else if (currentRenderedItemId == 44092) {
            pbrEmission = albedo.b * 2.0;
        } else if (currentRenderedItemId == 44093) {
            pbrEmission = albedo.g;
        } else if (currentRenderedItemId == 44094) {
            pbrEmission = dot(albedo.rgb, albedo.rgb) * 0.5 + 1.0;
        } else if (currentRenderedItemId == 44095) {
            pbrEmission = pow(max(albedo.r, 0.0), 1.5) * 2.5 + 0.2;
        } else if (currentRenderedItemId == 44096) {
            pbrEmission = pow(max(albedo.r + albedo.g, 0.0), 2.0) * 0.5;
        } else if (currentRenderedItemId == 45048) {
            pbrEmission = max(albedo.r + albedo.g - albedo.b * 0.5, 0.0);
        } else if (currentRenderedItemId == 45052) {
            pbrEmission = max(albedo.b * 2.0 - albedo.r, 0.0) * 1.5;
        } else if (currentRenderedItemId == 45084) {
            pbrEmission = max(albedo.b + albedo.g - albedo.r * 2.0, 0.0);
        } else if (currentRenderedItemId == 45112) {
            pbrEmission = abs(albedo.r - albedo.b) * 3.0;
        } else if (currentRenderedItemId == 44002 || currentRenderedItemId == 44003 ||
                   currentRenderedItemId == 44007 || currentRenderedItemId == 44008 ||
                   currentRenderedItemId == 44009 || currentRenderedItemId == 44010 ||
                   currentRenderedItemId == 44011 || currentRenderedItemId == 44012 ||
                   currentRenderedItemId == 44015 || currentRenderedItemId == 44018 ||
                   currentRenderedItemId == 44019 || currentRenderedItemId == 44028 ||
                   currentRenderedItemId == 44029 || currentRenderedItemId == 44030 ||
                   currentRenderedItemId == 44035 || currentRenderedItemId == 44084) {
            pbrEmission = max(max(albedo.r, albedo.g), albedo.b) * 0.5;
        }
    }
#ifdef ENTITY_GN_AND_CT
#if COATED_TEXTURE_STRENGTH > 0
    if (entityId != 50128 && entityId != 50132 && albedo.a >= 0.999 &&
        pbrEmission < 0.01 && materialReflectance < 0.8 && materialSmoothness < 0.85) {
        albedo.rgb = applyCoatedTexture(albedo.rgb, uvDx, uvDy, vTexCoordAM, vPlayerPosition);
    }
#endif
#endif
    if (materialPorosity > 0.0 && pbrEmission < 0.01) {
        float precipitationFactor = biome_precipitation == 1
            ? clamp(rainfall, 0.0, 1.0) : 0.0;
        float wetnessFactor = clamp(wetness * precipitationFactor, 0.0, 1.0);
        applyPorosityWetness(
            albedo.rgb, materialReflectance, materialSmoothness,
            materialPorosity, wetnessFactor, pbrEmission
        );
    }
    outColor = albedo;
    outEncodedNormal = vec4(surfaceNormal * 0.5 + 0.5, 0.5 + 0.5 * materialSmoothness);
    outEmissionData = vec4(pbrEmission, materialReflectance, materialAO, materialSurfaceData);
}
