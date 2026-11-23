#version 330 compatibility

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform sampler2D normals;
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

        currentLocal = fract(currentLocal + stepOffset);
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
#define MATERIAL_WETNESS_STRENGTH 100 // [0 25 50 75 100 125 150] LabPBR porosity-driven wet darkening

vec3 calculateOpaquePbrNormal(vec3 geometricNormal, vec2 materialUv, vec2 uvDx, vec2 uvDy, out float materialAO, out bool hasExplicitNormal) {
    vec4 normalTexel = textureGrad(normals, materialUv, uvDx, uvDy);
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


void main() {
    vec2 uvDx = dFdx(vTexCoord);
    vec2 uvDy = dFdy(vTexCoord);
    vec2 uvFootprint = max(fwidth(vTexCoord), 1.0 / vec2(textureSize(gtexture, 0)));
    vec2 materialUv = vTexCoord;
    vec4 albedo = texture(gtexture, materialUv) * vVertexColor;
    float albedoDetail = length(fwidth(albedo.rgb));
    if (albedo.a < alphaTestRef) discard;

    float parallaxOffset = 0.0;
#if POM_STRENGTH > 0
    if (gl_FrontFacing) {
        vec2 parallaxUv = calculateParallaxUv(
            vTexCoord, uvDx, uvDy, vTexCoordAM, vTangentView,
            length(vTangentView), parallaxOffset
        );
        if (parallaxOffset > 0.00001) {
            vec4 parallaxAlbedo = textureGrad(gtexture, parallaxUv, uvDx, uvDy) * vVertexColor;
            // Preserve cutout silhouettes when a displaced lookup lands in a transparent texel.
            if (parallaxAlbedo.a >= alphaTestRef) {
                materialUv = parallaxUv;
                albedo = parallaxAlbedo;
            }
        }
    }
#endif

    // Preserve the vanilla lightmap's RGB tint (including warm block light
    // and skylight color) plus a separate sky-light factor for direct sun.
    vec3 vanillaLight = texture(lightmap, vLightmapCoord).rgb;
    float skyLight = clamp(vLightmapCoord.y / (30.0 / 32.0) - (1.0 / 32.0), 0.0, 1.0);
    outLightmapData = vec4(vanillaLight, skyLight);
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
    vec4 pbrSpecular = textureGrad(specular, materialUv, uvDx, uvDy);
    float materialSmoothness = clamp(pbrSpecular.r, 0.0, 1.0);
    float materialReflectance = 0.0;
    float pbrEmission = 0.0;
    float materialPorosity = 0.0;
    float materialSurfaceData = 0.0;
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
    float labF0Code = floor(pbrSpecular.g * 255.0 + 0.5);
    float labSurfaceCode = floor(pbrSpecular.b * 255.0 + 0.5);
    float pbrMapPresent = step(0.0001, max(max(pbrSpecular.r, pbrSpecular.g), max(pbrSpecular.b, pbrSpecular.a)));
    if (pbrMapPresent < 0.5) {
        materialReflectance = 0.04; // Neutral dielectric F0 when no specular map exists
    } else if (labF0Code >= 230.0) {
        materialReflectance = 1.0; // Metal: use albedo as F0 in deferred.
        materialPorosity = 0.0;
        materialSurfaceData = 0.0; // LabPBR reserves blue for future use on metals.
    } else {
        materialReflectance = labF0Code / 255.0;
        materialSurfaceData = clamp(pbrSpecular.b, 0.0, 1.0);
        if (labSurfaceCode < 65.0) materialPorosity = clamp(labSurfaceCode / 64.0, 0.0, 1.0);
    }
    float labEmissionCode = floor(pbrSpecular.a * 255.0 + 0.5);
    if (labEmissionCode < 254.5) pbrEmission = labEmissionCode / 254.0;
#else
    materialReflectance = clamp(pbrSpecular.g, 0.0, 1.0); // oldPBR metalness
    pbrEmission = clamp(pbrSpecular.b, 0.0, 1.0);        // oldPBR emissiveness
#endif

    // Pack material smoothness into the normal attachment alpha without
    // allocating another render target. Block IDs provide a fallback when
    // resource packs do not supply PBR maps for slime/honey.
    if (vMaterialId == 30012) {
        materialSmoothness = max(materialSmoothness, 0.62); // Slime block
    } else if (vMaterialId == 30016) {
        materialSmoothness = max(materialSmoothness, 0.48); // Honey block
    }
    // LabPBR porosity (blue codes 0-64) makes a wet material darker and
    // less reflective. The map-influence and overall lighting controls remain
    // separate; non-LabPBR and SSS-coded materials stay neutral here.
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
            if (vMaterialId == 10009 || vMaterialId == 10011 || vMaterialId == 10129 || vMaterialId == 10137) noPuddles = 1.0; // Leaves and farmland
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
    } else if (vMaterialId == 32116) {
        emissionStrength = 0.25;
    }

    emissionStrength = max(emissionStrength, pbrEmission * 5.0);
    outEmissionData = vec4(emissionStrength / 5.0, materialReflectance, materialAO, materialSurfaceData);
}
