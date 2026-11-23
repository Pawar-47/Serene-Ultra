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
uniform float frameTimeCounter;
uniform float wetness;
uniform float rainStrength;
uniform float rainfall;
uniform int biome_precipitation;
uniform float alphaTestRef;

// Low-cost, sprite-safe parallax occlusion mapping for Iris normal atlases.
// LabPBR and oldPBR both store height in normals.a; a neutral fallback has alpha 1.
#define POM_STRENGTH 25 // [0 10 20 35 50 75 100] LabPBR/oldPBR height-map parallax strength
#define GENERATED_NORMAL_STRENGTH 25 // [0 10 20 35 50 75 100] Albedo-derived normal detail when no normal map is present
#define COATED_TEXTURE_STRENGTH 20 // [0 10 20 35 50 75 100] Stable subtle noise coating on opaque material colour
#define POM_QUALITY 4 // [4 6 8] Bounded POM samples; higher values cost more
#define POM_DISTANCE 32 // [12 16 24 32 48 64] Fade POM to zero at this view distance

float sereneVanillaMaterialPorosity(int materialId) {
    if (materialId == 32160) return 0.14; // Stone and polished stone families
    if (materialId == 32161) return 0.12; // Deepslate family
    if (materialId == 32162) return 0.30; // Cobblestone and mossy cobblestone
    if (materialId == 32163) return 0.88; // Dirt, podzol and mycelium
    if (materialId == 32164) return 0.03; // Obsidian
    if (materialId == 32165) return 0.62; // Vanilla wood and planks
    if (materialId == 32166) return 0.82; // Sand, gravel, clay and mud
    if (materialId == 32167) return 0.12; // Blackstone family
    if (materialId == 32168) return 0.72; // Netherrack
    if (materialId == 32169) return 0.22; // End stone family
    if (materialId == 32170) return 0.98; // Snow and powder snow
    if (materialId == 32171) return 0.72; // Coral block family
    if (materialId == 10009 || materialId == 10011 || materialId == 32130) return 0.92;
    return 0.0;
}

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
#if POM_STRENGTH > 0
    if (viewDistance >= float(POM_DISTANCE) || tangentView.z >= -0.05) return baseUv;

    float distanceFade = 1.0 - smoothstep(
        float(POM_DISTANCE) * 0.55, float(POM_DISTANCE), viewDistance
    );
    float heightScale = clamp(float(POM_STRENGTH) * 0.003, 0.0, 0.20) * distanceFade;
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

float calculatePomSelfShadow(
    vec2 surfaceUv,
    vec2 uvDx,
    vec2 uvDy,
    vec4 spriteBounds,
    vec3 playerTangent,
    vec3 playerNormal,
    float tangentHandedness,
    float viewDistance
) {
#if POM_STRENGTH > 0 && POM_SELF_SHADOW_STRENGTH > 0
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
    float heightScale = clamp(float(POM_STRENGTH) * 0.003, 0.0, 0.20)
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

    // Four short height-field samples approximate the light ray above the
    // displaced surface. Keep samples inside the current atlas sprite.
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
in vec3 vPlayerPosition;
in vec4 vVertexColor;
in vec3 vPlayerNormal;
in vec3 vPlayerTangent;
flat in float vTangentHandedness;
in vec3 vTangentView;
flat in vec4 vTexCoordAM;
flat in int vMaterialId;

/* RENDERTARGETS: 0,1,2,3 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outLightmapData;
layout(location = 2) out vec4 outEncodedNormal;
layout(location = 3) out vec4 outEmissionData;

#define OPAQUE_NORMAL_MAP_STRENGTH 100 // [0 25 50 75 100 125 150] Resource-pack PBR normal-map detail
#define PBR_AO_STRENGTH 100 // [0 25 50 75 100]
#define RAIN_PUDDLE_STRENGTH 70 // [0 25 50 70 85 100] Unbound-inspired exposed-surface puddle coverage
#define MATERIAL_WETNESS_STRENGTH 100 // [0 25 50 75 100 125 150] LabPBR/vanilla material porosity wet darkening

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
#if POM_STRENGTH > 0 && POM_SLOPE_NORMAL_STRENGTH > 0
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
    vec3 playerPosition,
    float materialCoatingFactor
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
        * max(1.0 - colorBrightness, 0.0) * materialCoatingFactor;
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
#if POM_STRENGTH > 0
    if (gl_FrontFacing) {
        vec2 parallaxUv = calculateParallaxUv(
            vTexCoord, uvDx, uvDy, vTexCoordAM, vTangentView,
            length(vTangentView), parallaxOffset
        );
        if (parallaxOffset > 0.00001) {
            vec4 parallaxAlbedo = sampleAnisotropicAtlas(gtexture, parallaxUv, uvDx, uvDy, vTexCoordAM) * vVertexColor;
            // Preserve cutout silhouettes when a displaced lookup lands in a transparent texel.
            if (parallaxAlbedo.a >= alphaTestRef) {
                materialUv = parallaxUv;
                albedo = parallaxAlbedo;
            }
        }
    }
#endif


#if POM_STRENGTH > 0 && POM_SELF_SHADOW_STRENGTH > 0
    if (parallaxOffset > 0.00001) {
        pomSelfShadow = calculatePomSelfShadow(
            materialUv, uvDx, uvDy, vTexCoordAM,
            vPlayerTangent, vPlayerNormal, vTangentHandedness,
            length(vTangentView)
        );
    }
#endif

    // Preserve the vanilla lightmap's RGB tint (including warm block light
    // and skylight color) plus a separate sky-light factor for direct sun.
    vec3 vanillaLight = texture(lightmap, vLightmapCoord).rgb;
    float skyLight = clamp(vLightmapCoord.y / (30.0 / 32.0) - (1.0 / 32.0), 0.0, 1.0);
    outLightmapData = vec4(vanillaLight, skyLight * pomSelfShadow);
    vec3 surfaceNormal = normalize(vPlayerNormal);
    if (!gl_FrontFacing) surfaceNormal = -surfaceNormal;
    float materialAO = 1.0;
    bool hasExplicitNormal = false;
    surfaceNormal = calculateOpaquePbrNormal(surfaceNormal, materialUv, uvDx, uvDy, materialAO, hasExplicitNormal);
#if GENERATED_NORMAL_STRENGTH > 0
    if (gl_FrontFacing && !hasExplicitNormal && albedo.a >= 0.999 && albedoDetail > 0.002) {
        surfaceNormal = calculateGeneratedAlbedoNormal(surfaceNormal, materialUv, uvDx, uvDy, uvFootprint, vTexCoordAM);
    }
#endif
    // Iris exposes the resource-pack specular atlas for oldPBR and LabPBR.
    // Both formats store smoothness in red; green is metalness (oldPBR) or
    // dielectric F0 / metal code (LabPBR).
    vec4 pbrSpecular = sampleAnisotropicAtlas(specular, materialUv, uvDx, uvDy, vTexCoordAM);
    float specularMapMagnitude = max(max(pbrSpecular.r, pbrSpecular.g), max(pbrSpecular.b, pbrSpecular.a));
    bool hasMaterialSpecularMap = specularMapMagnitude > 0.0001;
    float materialSmoothness = clamp(pbrSpecular.r, 0.0, 1.0);
    float materialReflectance = 0.0;
    float pbrEmission = 0.0;
    float materialPorosity = 0.0;
    float materialSurfaceData = 0.0;
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
    float labF0Code = floor(pbrSpecular.g * 255.0 + 0.5);
    float labSurfaceCode = floor(pbrSpecular.b * 255.0 + 0.5);
    float pbrMapPresent = hasMaterialSpecularMap ? 1.0 : 0.0;
    if (pbrMapPresent < 0.5) {
        materialReflectance = 0.04; // Neutral dielectric F0 when no specular map exists
        materialPorosity = sereneVanillaMaterialPorosity(vMaterialId);
    } else if (labF0Code >= 230.0) {
        materialReflectance = 1.0; // Metal: use albedo as F0 in deferred.
        materialPorosity = 0.0;
        materialSurfaceData = 0.0; // LabPBR reserves blue for future use on metals.
    } else {
        materialReflectance = labF0Code / 255.0;
        materialSurfaceData = clamp(pbrSpecular.b, 0.0, 1.0);
        materialPorosity = labSurfaceCode < 65.0
            ? clamp(labSurfaceCode / 64.0, 0.0, 1.0)
            : sereneVanillaMaterialPorosity(vMaterialId);
    }
    float labEmissionCode = floor(pbrSpecular.a * 255.0 + 0.5);
    if (labEmissionCode < 254.5) pbrEmission = labEmissionCode / 254.0;
#else
    materialReflectance = clamp(pbrSpecular.g, 0.0, 1.0); // oldPBR metalness
    pbrEmission = clamp(pbrSpecular.b, 0.0, 1.0);        // oldPBR emissiveness
    materialPorosity = sereneVanillaMaterialPorosity(vMaterialId);
    // Vanilla/oldPBR have no LabPBR SSS code. Use conservative material-ID
    // fallbacks for thin foliage and soft translucent-looking block surfaces.
    if (vMaterialId == 10009 || vMaterialId == 10011) {
        materialSurfaceData = 0.52; // Leaves
    } else if (vMaterialId == 32130) {
        materialSurfaceData = 0.46; // Grass, crops, vines, flowers and roots
    } else if (vMaterialId == 30012) {
        materialSurfaceData = 0.38; // Slime block
    } else if (vMaterialId == 30016) {
        materialSurfaceData = 0.48; // Honey block
    }
#endif

    // Built-in emissive blocks are excluded even when no specular map exists.
    bool fallbackEmissiveMaterial =
        vMaterialId == 32100 || vMaterialId == 32101 || vMaterialId == 32102 ||
        vMaterialId == 32103 || vMaterialId == 32104 || vMaterialId == 32105 ||
        vMaterialId == 32108 || vMaterialId == 32109 || vMaterialId == 32110 ||
        vMaterialId == 32111 || vMaterialId == 32113 || vMaterialId == 32114 ||
        vMaterialId == 32115 || vMaterialId == 32116 || vMaterialId == 32117 ||
        vMaterialId == 32118 || vMaterialId == 32120 || vMaterialId == 32121 ||
        vMaterialId == 32122 || vMaterialId == 32123 ||
        vMaterialId == 32124 || vMaterialId == 32125 || vMaterialId == 32126 ||
        vMaterialId == 32127 || vMaterialId == 32128 || vMaterialId == 32129 ||
        vMaterialId == 10352 || vMaterialId == 10608 ||
        (vMaterialId >= 32131 && vMaterialId <= 32137) ||
        (vMaterialId >= 32140 && vMaterialId <= 32152);
    bool fallbackMetalMaterial =
        vMaterialId == 10248 || vMaterialId == 10264 || vMaterialId == 10268 ||
        vMaterialId == 10280 || vMaterialId == 10292 || vMaterialId == 10296 ||
        vMaterialId == 10312;
    // Complementary's raw-metal and netherite handlers have no coated-texture
    // factor; gold/iron use 0.33 and copper uses 0.5.
    float materialCoatingFactor = fallbackMetalMaterial ? 0.0 : 1.0;
    // Reference coating factors for dielectric minerals remain active with PBR maps.
    if (vMaterialId == 10316 || vMaterialId == 10336 ||
        vMaterialId == 10352 || vMaterialId == 10364) {
        materialCoatingFactor = 0.5;
    } else if (vMaterialId == 10608) {
        materialCoatingFactor = 0.77;
    } else if (vMaterialId == 10328) {
        materialCoatingFactor = 0.0;
    }

    // Vanilla fallback heuristics mirror Complementary's terrain material
    // dispatch and run only when the resource pack has no specular map.
    if (!hasMaterialSpecularMap) {
        if (vMaterialId == 10248) { // Netherite block
            materialSmoothness = max(materialSmoothness, clamp(pow(albedo.r * 2.0, 2.0), 0.0, 1.0));
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
            materialReflectance = 1.0;
#else
            materialReflectance = max(materialReflectance, 0.85);
#endif
        } else if (vMaterialId == 10264) { // Iron block
            materialCoatingFactor = 0.33;
            materialSmoothness = max(materialSmoothness, pow(albedo.r, 4.0));
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
            materialReflectance = 1.0;
#else
            materialReflectance = max(materialReflectance, 0.75);
#endif
        } else if (vMaterialId == 10268) { // Raw iron block
            materialSmoothness = max(materialSmoothness, pow(albedo.r, 4.0) * 0.7);
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
            materialReflectance = 1.0;
#else
            materialReflectance = max(materialReflectance, 0.70);
#endif
        } else if (vMaterialId == 10280) { // Raw copper block
            materialSmoothness = max(materialSmoothness, clamp(pow(albedo.r + albedo.g * 0.25, 2.0) * 0.4, 0.0, 1.0));
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
            materialReflectance = 1.0;
#else
            materialReflectance = max(materialReflectance, 0.55);
#endif
        } else if (vMaterialId == 10292) { // Copper block and oxidation/wax variants
            materialCoatingFactor = 0.5;
            float copperSmoothness = pow(albedo.r, 4.0)
                + pow(max(albedo.g - albedo.r * 0.5, 0.0), 2.0) * 0.3;
            materialSmoothness = max(materialSmoothness, clamp(copperSmoothness, 0.0, 1.0));
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
            materialReflectance = 1.0;
#else
            materialReflectance = max(materialReflectance, 0.65);
#endif
        } else if (vMaterialId == 10296) { // Raw gold block
            materialSmoothness = max(materialSmoothness, pow(albedo.g, 4.0));
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
            materialReflectance = 1.0;
#else
            materialReflectance = max(materialReflectance, 0.90);
#endif
        } else if (vMaterialId == 10312) { // Gold block
            materialCoatingFactor = 0.33;
            float goldGreenFourth = pow(albedo.g, 4.0);
            materialSmoothness = max(materialSmoothness,
                clamp(max(albedo.g, 0.8) - goldGreenFourth * 0.5, 0.0, 1.0));
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
            materialReflectance = 1.0;
#else
            materialReflectance = max(materialReflectance, 0.90);
#endif
        } else if (vMaterialId == 10316) { // Diamond block: glossy dielectric
            float factor = max(albedo.g, 0.8);
            materialSmoothness = max(materialSmoothness,
                clamp(factor - pow(albedo.g, 4.0) * 0.4, 0.0, 1.0));
        } else if (vMaterialId == 10328) { // Amethyst and budding amethyst
            materialSmoothness = max(materialSmoothness,
                clamp(0.8 - pow(albedo.r, 2.0) * 0.3, 0.0, 1.0));
        } else if (vMaterialId == 10336) { // Emerald block: glossy dielectric
            float mineralLuminance = dot(albedo.rgb, vec3(0.2126, 0.7152, 0.0722));
            materialSmoothness = max(materialSmoothness,
                clamp(mineralLuminance - pow(mineralLuminance, 4.0) * 0.4, 0.0, 1.0));
        } else if (vMaterialId == 10352) { // Lapis block
            materialSmoothness = max(materialSmoothness, pow(albedo.b, 2.0) * 0.8);
        } else if (vMaterialId == 10364) { // Quartz block family
            float quartzGreenSquared = pow(albedo.g, 2.0);
            float quartzGreenFourth = pow(quartzGreenSquared, 2.0);
            float quartzGreenEighth = pow(quartzGreenFourth, 2.0);
            materialSmoothness = max(materialSmoothness,
                clamp(albedo.g - quartzGreenEighth * 0.5, 0.0, 1.0));
        } else if (vMaterialId == 10608) { // Redstone block
            materialSmoothness = max(materialSmoothness, 0.4);
        } else if (vMaterialId == 32160) { // Stone, polished stone and tuff families
            materialSmoothness = max(
                materialSmoothness, clamp(pow(albedo.g, 4.0) * 2.0, 0.0, 1.0)
            );
            materialCoatingFactor = 0.77;
        } else if (vMaterialId == 32161) { // Deepslate family
            materialSmoothness = max(
                materialSmoothness, clamp(pow(albedo.g, 1.5) * 0.55, 0.0, 1.0)
            );
        } else if (vMaterialId == 32162) { // Cobblestone family
            float cobbleSmoothness = dot(albedo.rgb, albedo.rgb) * 0.17;
            float mossHighlight = (albedo.g > albedo.b * 1.5)
                ? 0.30 * albedo.g : 0.0;
            materialSmoothness = max(
                materialSmoothness, clamp(max(cobbleSmoothness, mossHighlight), 0.0, 1.0)
            );
        } else if (vMaterialId == 32163) { // Dirt, coarse dirt, rooted dirt, podzol and mycelium
            materialSmoothness = max(materialSmoothness, albedo.r * 0.1 + 0.1);
        } else if (vMaterialId == 32164) { // Obsidian
            float obsidianFactor = max(0.3 - abs(albedo.r - 0.3), 0.0) * 1.5;
            materialSmoothness = max(
                materialSmoothness, clamp(obsidianFactor, 0.0, 1.0)
            );
            materialReflectance = max(materialReflectance, 0.08);
        } else if (vMaterialId == 32167) { // Blackstone family
            materialSmoothness = max(materialSmoothness, albedo.r);
        } else if (vMaterialId == 32168) { // Netherrack
            materialSmoothness = max(
                materialSmoothness, clamp(pow(albedo.r, 2.0) * 1.5, 0.0, 1.0)
            );
        } else if (vMaterialId == 32169) { // End stone and end-stone bricks
            materialSmoothness = max(
                materialSmoothness, clamp(pow(albedo.r, 4.0) * 0.65, 0.0, 1.0)
            );
            materialCoatingFactor = 0.66;
        } else if (vMaterialId == 32170) { // Snow and powder snow
            float snowSmoothness = (1.0 - pow(albedo.g, 64.0) * 0.3) * 0.4;
            materialSmoothness = max(
                materialSmoothness, clamp(snowSmoothness, 0.0, 1.0)
            );
        } else if (vMaterialId == 32171) { // Coral block family
            materialSmoothness = max(
                materialSmoothness, clamp(length(albedo.rgb) * 0.2, 0.0, 1.0)
            );
            materialCoatingFactor = 0.66;
        }
    }

    // Pack material smoothness into the normal attachment alpha without
    // allocating another render target. Block IDs provide a fallback when
    // resource packs do not supply PBR maps for slime/honey.
    if (vMaterialId == 30012) {
        materialSmoothness = max(materialSmoothness, 0.62); // Slime block
    } else if (vMaterialId == 30016) {
        materialSmoothness = max(materialSmoothness, 0.48); // Honey block
    }
#if COATED_TEXTURE_STRENGTH > 0
    if (albedo.a >= 0.999 && pbrEmission < 0.01 &&
        !fallbackEmissiveMaterial && materialCoatingFactor > 0.0 &&
        (!hasMaterialSpecularMap || materialReflectance < 0.8) &&
        materialSmoothness < 0.85) {
        albedo.rgb = applyCoatedTexture(
            albedo.rgb, uvDx, uvDy, vTexCoordAM, vPlayerPosition, materialCoatingFactor
        );
    }
#endif
    // LabPBR blue codes 0-64 take priority; vanilla/oldPBR and SSS-coded
    // surfaces use conservative material-ID porosity fallbacks when available.
    float precipitationFactor = biome_precipitation == 1
        ? clamp(rainfall, 0.0, 1.0) : 0.0;
    float wetnessFactor = clamp(wetness * precipitationFactor, 0.0, 1.0);
    float rainFactor = clamp(rainStrength * precipitationFactor, 0.0, 1.0);
    float porousWetness = clamp(
        wetnessFactor * materialPorosity * (MATERIAL_WETNESS_STRENGTH * 0.01),
        0.0, 1.0
    );
    albedo.rgb *= 1.0 - porousWetness * 0.22;
    materialReflectance *= 1.0 - porousWetness * 0.45;
    materialSmoothness *= 1.0 - porousWetness * 0.35;

    // Low-cost Unbound-inspired puddles: no 3D voxel map or extra target.
    // Only rainy biomes, sky-exposed upward-facing terrain can accumulate water.
    float puddleMask = 0.0;
#if RAIN_PUDDLE_STRENGTH > 0
    if (wetnessFactor > 0.001 && rainFactor > 0.001) {
        float puddleLightFactor = max(0.0, vLightmapCoord.y * 32.0 - 31.0)
            * clamp((1.0 - 1.15 * vLightmapCoord.x) * 10.0, 0.0, 1.0);
        float puddleNormalFactor = pow(max(0.0, dot(surfaceNormal, vec3(0.0, 1.0, 0.0)) - 0.5) * 2.0, 2.0);
        float puddleMixer = puddleLightFactor * rainFactor * puddleNormalFactor;
        if (puddleMixer > 0.0001) {
            vec3 stableWorldPosition = vec3(cameraPositionInt) + cameraPositionFract + vPlayerPosition;
            stableWorldPosition.xz = mod(stableWorldPosition.xz, 2560.0);
            vec2 puddleCoord = stableWorldPosition.xz * 0.1;
            // 60-second periodic drift also stays phase-continuous at Iris' 3600s timer wrap.
            float puddleTime = mod(frameTimeCounter, 60.0);
            vec2 puddleWind = vec2(puddleTime / 30.0, puddleTime / 60.0);
            vec3 puddleNoise1 = texture(noisetex, puddleCoord + puddleWind).rgb;
            vec3 puddleNoise2 = texture(noisetex, puddleCoord * 1.7
                - puddleWind * vec2(1.5, 2.0)).rgb;
            vec3 puddleNoise3 = texture(noisetex, puddleCoord * 0.5
                + puddleWind * vec2(0.5, 2.0)).rgb;
            float puddleForm = clamp(puddleNoise1.b * 3.0 + puddleNoise2.b * 5.0
                + puddleNoise3.b * 8.0 - 7.0, 0.0, 1.0);
            float noPuddles = clamp(materialPorosity, 0.0, 1.0);
            if (vMaterialId == 10009 || vMaterialId == 10011 || vMaterialId == 10129 || vMaterialId == 10137 || vMaterialId == 32170) noPuddles = 1.0; // Leaves, farmland and snow
            float wetnessSquared = wetnessFactor * wetnessFactor;
            puddleMask = clamp(wetnessSquared * wetnessSquared * puddleMixer * puddleForm
                * (1.0 - noPuddles) * (RAIN_PUDDLE_STRENGTH * 0.01), 0.0, 1.0);
            if (puddleMask > 0.001) {
                vec2 normalOffset = (puddleNoise1.xy + puddleNoise2.xy - vec2(1.0)) * 0.03;
                vec3 tangentCandidate = vPlayerTangent - surfaceNormal * dot(surfaceNormal, vPlayerTangent);
                float tangentLengthSquared = dot(tangentCandidate, tangentCandidate);
                if (tangentLengthSquared > 0.000001) {
                    vec3 tangent = tangentCandidate * inversesqrt(tangentLengthSquared);
                    vec3 bitangent = normalize(cross(tangent, surfaceNormal)) * vTangentHandedness;
                    vec3 puddleNormal = normalize(surfaceNormal + tangent * normalOffset.x + bitangent * normalOffset.y);
                    surfaceNormal = normalize(mix(surfaceNormal, puddleNormal, sqrt(puddleMask) * 0.98));
                }
                float puddleSmoothness = 0.7 - rainFactor * 0.3;
                materialSmoothness = mix(materialSmoothness, puddleSmoothness, puddleMask);
                albedo.rgb *= 1.0 - puddleMask * 0.12;
            }
        }
    }
#endif

    outColor = albedo;
    outEncodedNormal = vec4(surfaceNormal * 0.5 + 0.5, 0.5 + 0.5 * materialSmoothness);

    // Store emission in R and material reflectance/metalness in G.
    float emissionStrength = 0.0;
    if (vMaterialId == 32100 || vMaterialId == 32101 ||
        vMaterialId == 32109 || vMaterialId == 32113 ||
        vMaterialId == 32114 || vMaterialId == 32115) {
        emissionStrength = 1.25;
    } else if (vMaterialId == 32103 || vMaterialId == 32108 ||
               vMaterialId == 32117 || vMaterialId == 32118 || vMaterialId == 32123) {
        emissionStrength = 0.90;
    } else if (vMaterialId == 32102 || vMaterialId == 32104 ||
               vMaterialId == 32105 || vMaterialId == 32110 ||
               vMaterialId == 32111 || vMaterialId == 32120 ||
               vMaterialId == 32121 || vMaterialId == 32122) {
        emissionStrength = 0.55;
    } else if (vMaterialId == 32116 || vMaterialId == 32128 || vMaterialId == 32129) {
        emissionStrength = 0.25;
    } else if (vMaterialId == 32124) {
        // Sea pickles only emit when waterlogged; the vanilla block-light
        // coordinate distinguishes their lit state from dry pickles.
        emissionStrength = vLightmapCoord.x > 0.05 ? 0.45 : 0.0;
    } else if (vMaterialId == 32125) {
        emissionStrength = 0.45; // Coloured lit candles and candle cakes.
    } else if (vMaterialId == 32126) {
        emissionStrength = 0.90; // Charged respawn anchors.
    } else if (vMaterialId == 32127) {
        emissionStrength = 0.90; // Lit copper bulbs.
    } else if (vMaterialId == 32131) {
        emissionStrength = 0.70; // Lit furnace, smoker and blast furnace.
    } else if (vMaterialId == 32132) {
        emissionStrength = 0.85; // Lava cauldron.
    } else if (vMaterialId == 32133) {
        emissionStrength = 0.35; // Crying obsidian.
    } else if (vMaterialId == 32134) {
        emissionStrength = 0.30; // Magma block.
    } else if (vMaterialId == 32135 || vMaterialId == 32136) {
        emissionStrength = 0.25; // Dragon egg and chorus flower.
    } else if (vMaterialId == 32137 || vMaterialId == 10352 || vMaterialId == 10608) {
        emissionStrength = 0.18; // Brewing stand, redstone block and lapis block.
    } else if (vMaterialId >= 32140 && vMaterialId <= 32148) {
        emissionStrength = 0.22; // Subtle ore/mineral and ancient-debris accents.
    } else if (vMaterialId == 32149) {
        emissionStrength = 0.35; // Active end portal frame.
    } else if (vMaterialId == 32150) {
        emissionStrength = 0.45; // Cave vines with glow berries.
    } else if (vMaterialId == 32151) {
        emissionStrength = 0.10; // Powered redstone wire/repeater/comparator.
    } else if (vMaterialId == 32152) {
        emissionStrength = 0.25; // Spawner core.
    }

    emissionStrength = max(emissionStrength, pbrEmission * 5.0);
    outEmissionData = vec4(emissionStrength / 5.0, materialReflectance, materialAO, materialSurfaceData);
}
