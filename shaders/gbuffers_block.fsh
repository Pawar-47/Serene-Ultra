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
uniform float rainStrength;
uniform float frameTimeCounter;
uniform float rainfall;
uniform int biome_precipitation;
uniform int blockEntityId;
uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform float fogDensity;
uniform int fogMode;
uniform int fogShape;

// Low-cost, sprite-safe parallax occlusion mapping for Iris normal atlases.
// LabPBR and oldPBR both store height in normals.a; a neutral fallback has alpha 1.
#define POM_STRENGTH 25 // [0 10 20 35 50 75 100] LabPBR/oldPBR height-map parallax strength
#define GENERATED_NORMAL_STRENGTH 25 // [0 10 20 35 50 75 100] Albedo-derived normal detail when no normal map is present
#define COATED_TEXTURE_STRENGTH 20 // [0 10 20 35 50 75 100] Stable subtle noise coating on opaque material colour
#define MATERIAL_WETNESS_STRENGTH 100 // [0 25 50 75 100 125 150] LabPBR porosity-driven wet darkening
#define RAIN_PUDDLE_STRENGTH 70 // [0 25 50 70 100 125 150] Rain puddles on upward-facing block-entity surfaces
#include "/lib/materials/porosity_wetness.glsl"
#define POM_QUALITY 4 // [4 6 8] Bounded POM samples; higher values cost more
#define POM_DISTANCE 32 // [12 16 24 32 48 64] Fade POM to zero at this view distance

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
flat in vec4 vVertexColor;
in vec3 vPlayerNormal;
in vec3 vPlayerTangent;
flat in float vTangentHandedness;
in vec3 vTangentView;
flat in vec4 vTexCoordAM;
in vec3 vViewPosition;
in vec3 vPlayerPosition;

/* RENDERTARGETS: 0,1,2,3 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outLightmapData;
layout(location = 2) out vec4 outEncodedNormal;
layout(location = 3) out vec4 outEmissionData;

#define OPAQUE_NORMAL_MAP_STRENGTH 100 // [0 25 50 75 100 125 150] Resource-pack PBR normal-map detail
#define PBR_AO_STRENGTH 100 // [0 25 50 75 100] LabPBR material ambient occlusion

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


float calculateBlockFog(float distanceToCamera) {
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
    bool signText = blockEntityId == 5004 &&
                    (dot(vVertexColor.rgb, vec3(1.0)) <= 2.99 || vLightmapCoord.x > 0.999);
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
    bool allowParallax = gl_FrontFacing && !signText && blockEntityId != 5025 && blockEntityId != 5036;
    if (allowParallax) {
        vec2 parallaxUv = calculateParallaxUv(
            vTexCoord, uvDx, uvDy, vTexCoordAM, vTangentView,
            length(vTangentView), parallaxOffset
        );
        if (parallaxOffset > 0.00001) {
            vec4 parallaxAlbedo = sampleAnisotropicAtlas(gtexture, parallaxUv, uvDx, uvDy, vTexCoordAM) * vVertexColor;
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

    vec3 vanillaLight = texture(lightmap, vLightmapCoord).rgb;
    float skyLight = clamp(vLightmapCoord.y / (30.0 / 32.0) - (1.0 / 32.0), 0.0, 1.0);
    float emissionStrength = 0.0;

    // Sign text is already vertex-colored and should not inherit the wooden
    // sign's directional shading. Bypass deferred lighting and fog it here.
    if (signText) {
        float fogDistance = (fogShape == 1) ? max(length(vViewPosition.xz), abs(vViewPosition.y)) : length(vViewPosition);
        float fogFactor = calculateBlockFog(fogDistance);
        vec3 textLinear = pow(max(albedo.rgb, vec3(0.0)), vec3(2.2));
        vec3 fogLinear = pow(max(fogColor, vec3(0.0)), vec3(2.2));
        albedo.rgb = pow(max(mix(textLinear, fogLinear, fogFactor), vec3(0.0)), vec3(1.0 / 2.2));
        vanillaLight = vec3(0.0);
        skyLight = 0.0;
    }

    // End portal/gateway surfaces are emissive; keep their texture color out
    // of ambient AO and shadow attenuation in the deferred lighting stage.
    if (blockEntityId == 5025) {
        emissionStrength = 1.25;
    }

    vec3 surfaceNormal = normalize(vPlayerNormal);
    if (!gl_FrontFacing) surfaceNormal = -surfaceNormal;
    float materialAO = 1.0;
    bool hasExplicitNormal = false;
    if (!signText) surfaceNormal = calculateOpaquePbrNormal(surfaceNormal, materialUv, uvDx, uvDy, materialAO, hasExplicitNormal);
bool skipGeneratedNormals = signText || blockEntityId == 5036;
#if GENERATED_NORMAL_STRENGTH > 0
    if (!skipGeneratedNormals && gl_FrontFacing && !hasExplicitNormal && albedo.a >= 0.999 && albedoDetail > 0.002) {
        surfaceNormal = calculateGeneratedAlbedoNormal(surfaceNormal, materialUv, uvDx, uvDy, uvFootprint, vTexCoordAM);
    }
#endif
    vec4 pbrSpecular = sampleAnisotropicAtlas(specular, materialUv, uvDx, uvDy, vTexCoordAM);
    float specularMapMagnitude = max(max(pbrSpecular.r, pbrSpecular.g), max(pbrSpecular.b, pbrSpecular.a));
    bool hasMaterialSpecularMap = specularMapMagnitude > 0.0001;
    float materialSmoothness = clamp(pbrSpecular.r, 0.0, 1.0);
    float materialReflectance = 0.0;
    float pbrEmission = 0.0;
    float materialSurfaceData = 0.0;
    float materialPorosity = 0.0;
    float materialCoatingFactor = 0.0;
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
    materialSurfaceData = clamp(pbrSpecular.b, 0.0, 1.0);
    float labF0Code = floor(pbrSpecular.g * 255.0 + 0.5);
    float labSurfaceCode = floor(pbrSpecular.b * 255.0 + 0.5);
    if (labF0Code < 65.0) {
        materialPorosity = clamp(labSurfaceCode / 64.0, 0.0, 1.0);
        materialSurfaceData = 0.0; // Blue is porosity here, not SSS.
    }
    float pbrMapPresent = hasMaterialSpecularMap ? 1.0 : 0.0;
    if (pbrMapPresent < 0.5) {
        materialReflectance = 0.04; // Neutral dielectric F0 when no specular map exists
    } else if (labF0Code >= 230.0) {
        materialReflectance = 1.0;
        materialSurfaceData = 0.0; // LabPBR reserves blue for future use on metals.
    } else {
        materialReflectance = labF0Code / 255.0;
    }
    float labEmissionCode = floor(pbrSpecular.a * 255.0 + 0.5);
    if (labEmissionCode < 254.5) pbrEmission = labEmissionCode / 254.0;
#else
    materialReflectance = clamp(pbrSpecular.g, 0.0, 1.0);
    pbrEmission = clamp(pbrSpecular.b, 0.0, 1.0);
#endif
// Complementary material dispatch for block entities.
    // Material identity controls coating on both vanilla and PBR resource packs.
    // Smoothness/F0 fallbacks never override an explicit oldPBR/LabPBR specular map.
    if (blockEntityId == 5004) { // Sign boards; sign text is filtered separately.
        materialCoatingFactor = 0.66;
    } else if (blockEntityId == 5008) { // Chest and trapped chest
        materialCoatingFactor = 0.66;
        if (!hasMaterialSpecularMap) {
            materialSmoothness = clamp(pow(albedo.g, 2.0), 0.0, 1.0);
        }
    } else if (blockEntityId == 5012) { // Ender chest
        materialCoatingFactor = 0.66;
        if (!hasMaterialSpecularMap) {
            float enderChestFactor = min(pow(albedo.g, 2.0), 0.25);
            materialSmoothness = enderChestFactor * 2.0;
        }
    } else if (blockEntityId == 5016) { // Shulker boxes, heads and beds
        materialCoatingFactor = 0.2;
    } else if (blockEntityId == 5028) { // Bell: distinguish gold from stone
        if (albedo.r + albedo.g > albedo.b + 0.5) {
            materialCoatingFactor = 0.33;
            if (!hasMaterialSpecularMap) {
                float goldGreenSquared = albedo.g * albedo.g;
                materialSmoothness = max(materialSmoothness,
                    min(max(albedo.g, 0.8) - goldGreenSquared * 0.5, 1.0));
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
                materialReflectance = 1.0; // LabPBR metal: deferred uses albedo as F0
#else
                materialReflectance = max(materialReflectance, 0.72); // oldPBR fallback metalness
#endif
            }
            albedo.rgb *= 0.5 + 0.4 * dot(albedo.rgb, vec3(0.2126, 0.7152, 0.0722));
        } else {
            materialCoatingFactor = 0.77;
            if (!hasMaterialSpecularMap) {
                float stoneSmoothness = pow(albedo.g, 4.0) * 2.0;
                materialSmoothness = max(materialSmoothness, min(stoneSmoothness, 1.0));
            }
        }
    } else if (blockEntityId == 5032) { // Copper chests and copper golem statues
        materialCoatingFactor = 0.5;
        if (!hasMaterialSpecularMap) {
            float copperSmoothness = pow(albedo.r, 4.0)
                + pow(max(albedo.g - albedo.r * 0.5, 0.0), 2.0) * 0.3;
            materialSmoothness = max(materialSmoothness, min(copperSmoothness, 1.0));
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
            materialReflectance = 1.0; // LabPBR metal: deferred uses albedo as F0
#else
            materialReflectance = max(materialReflectance, 0.58); // oldPBR fallback metalness
#endif
        }
        float copperLuminance = dot(albedo.rgb, vec3(0.2126, 0.7152, 0.0722));
        albedo.rgb *= clamp(0.6 + 0.7 * copperLuminance, 0.0, 1.0);
    } else if (blockEntityId == 5036) { // Banners
        materialCoatingFactor = 0.2;
    } else if (blockEntityId == 10548 && !hasMaterialSpecularMap) { // Enchanting-table book
        materialSmoothness = max(materialSmoothness, clamp(pow(albedo.g, 2.0) * 0.35, 0.0, 1.0));
    }

    // The conduit lightmap adjustment is independent of whether its texture has a PBR emission map.
    if (blockEntityId == 5020) {
        vanillaLight = texture(lightmap, vec2(0.9, vLightmapCoord.y)).rgb;
    }

    // Explicit PBR-map emission wins; use the reference's colour cues only when emission is absent.
    if (pbrEmission < 0.01) {
        if (blockEntityId == 5012) { // Ender chest
            float enderChestFactor = min(pow(albedo.g, 2.0), 0.25);
            float enderChestEmission = 0.35;
            if (albedo.g > albedo.r || albedo.b > albedo.g) {
                enderChestEmission += enderChestFactor * enderChestFactor * 20.0;
            }
            emissionStrength = max(emissionStrength, enderChestEmission);
        } else if (blockEntityId == 5020) { // Conduit
            if (albedo.b > albedo.r) {
                emissionStrength = max(emissionStrength, albedo.r * 16.0);
            } else if (albedo.r > albedo.b * 2.5) {
                emissionStrength = max(emissionStrength, 20.0);
                albedo.rgb *= vec3(1.0, 0.25, 0.1);
            }
        } else if (blockEntityId == 10548) { // Enchanting-table book
            if (albedo.b < 0.0001 && albedo.r > albedo.g) {
                emissionStrength = max(emissionStrength, albedo.g * 3.5);
            }
        }
    }

    outLightmapData = vec4(vanillaLight, skyLight * pomSelfShadow);
#if COATED_TEXTURE_STRENGTH > 0
    if (!signText && blockEntityId != 5025 && albedo.a >= 0.999 &&
        materialCoatingFactor > 0.0 && pbrEmission < 0.01 &&
        materialReflectance < 0.8) {
        albedo.rgb = applyCoatedTexture(albedo.rgb, uvDx, uvDy, vTexCoordAM,
            vPlayerPosition, materialCoatingFactor);
    }
#endif
    emissionStrength = max(emissionStrength, pbrEmission * 5.0);
    if (materialPorosity > 0.0 && emissionStrength < 0.01) {
        float precipitationFactor = biome_precipitation == 1
            ? clamp(rainfall, 0.0, 1.0) : 0.0;
        float wetnessFactor = clamp(wetness * precipitationFactor, 0.0, 1.0);
        applyPorosityWetness(
            albedo.rgb, materialReflectance, materialSmoothness,
            materialPorosity, wetnessFactor, emissionStrength
        );
    }
    // Apply the terrain puddle model to horizontal block-entity surfaces
    // (chest lids, shulker boxes and similar); signs, banners and portals are excluded.
    float puddlePrecipitation = biome_precipitation == 1
        ? clamp(rainfall, 0.0, 1.0) : 0.0;
    float puddleWetness = clamp(wetness * puddlePrecipitation, 0.0, 1.0);
    float puddleRain = clamp(rainStrength * puddlePrecipitation, 0.0, 1.0);
#if RAIN_PUDDLE_STRENGTH > 0
    if (!signText && blockEntityId != 5025 && blockEntityId != 5036
        && puddleWetness > 0.001 && puddleRain > 0.001) {
        float puddleLightFactor = max(0.0, vLightmapCoord.y * 32.0 - 31.0)
            * clamp((1.0 - 1.15 * vLightmapCoord.x) * 10.0, 0.0, 1.0);
        float puddleNormalFactor = pow(
            max(0.0, dot(surfaceNormal, vec3(0.0, 1.0, 0.0)) - 0.5) * 2.0, 2.0
        );
        float puddleMixer = puddleLightFactor * puddleRain * puddleNormalFactor;
        if (puddleMixer > 0.0001) {
            vec3 puddleWorldPosition = vec3(cameraPositionInt)
                + cameraPositionFract + vPlayerPosition;
            puddleWorldPosition.xz = mod(puddleWorldPosition.xz, 2560.0);
            vec2 puddleCoord = puddleWorldPosition.xz * 0.1;
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
            float wetnessSquared = puddleWetness * puddleWetness;
            float puddleMask = clamp(wetnessSquared * wetnessSquared * puddleMixer
                * puddleForm * (1.0 - noPuddles)
                * (float(RAIN_PUDDLE_STRENGTH) * 0.01), 0.0, 1.0);
            if (puddleMask > 0.001) {
                vec2 normalOffset = (puddleNoise1.xy + puddleNoise2.xy - vec2(1.0)) * 0.03;
                vec3 tangentCandidate = vPlayerTangent
                    - surfaceNormal * dot(surfaceNormal, vPlayerTangent);
                float tangentLengthSquared = dot(tangentCandidate, tangentCandidate);
                if (tangentLengthSquared > 0.000001) {
                    vec3 tangent = tangentCandidate * inversesqrt(tangentLengthSquared);
                    vec3 bitangent = normalize(cross(tangent, surfaceNormal)) * vTangentHandedness;
                    vec3 puddleNormal = normalize(
                        surfaceNormal + tangent * normalOffset.x + bitangent * normalOffset.y
                    );
                    surfaceNormal = normalize(mix(surfaceNormal, puddleNormal, sqrt(puddleMask) * 0.98));
                }
                materialSmoothness = mix(materialSmoothness, 0.7 - puddleRain * 0.3, puddleMask);
                albedo.rgb *= 1.0 - puddleMask * 0.12;
            }
        }
    }
#endif

    outColor = albedo;
    outEncodedNormal = vec4(surfaceNormal * 0.5 + 0.5, signText ? 0.0 : 0.5 + 0.5 * materialSmoothness);
    outEmissionData = vec4(emissionStrength / 5.0, materialReflectance, materialAO, materialSurfaceData);
}
