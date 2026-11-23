#version 330 compatibility

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D noisetex;
uniform ivec3 cameraPositionInt;
uniform vec3 cameraPositionFract;
uniform float alphaTestRef;
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
    bool signText = blockEntityId == 5004 &&
                    (dot(vVertexColor.rgb, vec3(1.0)) <= 2.99 || vLightmapCoord.x > 0.999);
    vec2 uvDx = dFdx(vTexCoord);
    vec2 uvDy = dFdy(vTexCoord);
    vec2 uvFootprint = max(fwidth(vTexCoord), 1.0 / vec2(textureSize(gtexture, 0)));
    vec2 materialUv = vTexCoord;
    vec4 albedo = texture(gtexture, materialUv) * vVertexColor;
    float albedoDetail = length(fwidth(albedo.rgb));
    if (albedo.a < alphaTestRef) discard;

    float parallaxOffset = 0.0;
#if POM_STRENGTH > 0
    bool allowParallax = gl_FrontFacing && !signText && blockEntityId != 5025;
    if (allowParallax) {
        vec2 parallaxUv = calculateParallaxUv(
            vTexCoord, uvDx, uvDy, vTexCoordAM, vTangentView,
            length(vTangentView), parallaxOffset
        );
        if (parallaxOffset > 0.00001) {
            vec4 parallaxAlbedo = textureGrad(gtexture, parallaxUv, uvDx, uvDy) * vVertexColor;
            if (parallaxAlbedo.a >= alphaTestRef) {
                materialUv = parallaxUv;
                albedo = parallaxAlbedo;
            }
        }
    }
#endif

    vec3 vanillaLight = texture(lightmap, vLightmapCoord).rgb;
    float skyLight = clamp(vLightmapCoord.y / (30.0 / 32.0) - (1.0 / 32.0), 0.0, 1.0);
    float emissionStrength = 0.0;

    // Sign text is already vertex-colored and should not inherit the wooden
    // sign's directional shading. Bypass deferred lighting and fog it here.
    if (signText) {
        float fogDistance = (fogShape == 1) ? length(vViewPosition.xz) : length(vViewPosition);
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

    outLightmapData = vec4(vanillaLight, skyLight);
    vec3 surfaceNormal = normalize(vPlayerNormal);
    if (!gl_FrontFacing) surfaceNormal = -surfaceNormal;
    float materialAO = 1.0;
    bool hasExplicitNormal = false;
    if (!signText) surfaceNormal = calculateOpaquePbrNormal(surfaceNormal, materialUv, uvDx, uvDy, materialAO, hasExplicitNormal);
#if GENERATED_NORMAL_STRENGTH > 0
    if (!signText && gl_FrontFacing && !hasExplicitNormal && albedo.a >= 0.999 && albedoDetail > 0.002) {
        surfaceNormal = calculateGeneratedAlbedoNormal(surfaceNormal, materialUv, uvDx, uvDy, uvFootprint, vTexCoordAM);
    }
#endif
    vec4 pbrSpecular = textureGrad(specular, materialUv, uvDx, uvDy);
    float materialSmoothness = clamp(pbrSpecular.r, 0.0, 1.0);
    float materialReflectance = 0.0;
    float pbrEmission = 0.0;
    float materialSurfaceData = 0.0;
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
    materialSurfaceData = clamp(pbrSpecular.b, 0.0, 1.0);
    float labF0Code = floor(pbrSpecular.g * 255.0 + 0.5);
    float pbrMapPresent = step(0.0001, max(max(pbrSpecular.r, pbrSpecular.g), max(pbrSpecular.b, pbrSpecular.a)));
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
#if COATED_TEXTURE_STRENGTH > 0
    if (!signText && blockEntityId != 5025 && albedo.a >= 0.999 &&
        pbrEmission < 0.01 && emissionStrength < 0.01 &&
        materialReflectance < 0.8 && materialSmoothness < 0.85) {
        albedo.rgb = applyCoatedTexture(albedo.rgb, uvDx, uvDy, vTexCoordAM, vPlayerPosition);
    }
#endif
    emissionStrength = max(emissionStrength, pbrEmission * 5.0);
    outColor = albedo;
    outEncodedNormal = vec4(surfaceNormal * 0.5 + 0.5, signText ? 0.0 : 0.5 + 0.5 * materialSmoothness);
    outEmissionData = vec4(emissionStrength / 5.0, materialReflectance, materialAO, materialSurfaceData);
}
