#version 330 compatibility

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform sampler2D normals;
uniform sampler2D specular;
uniform float alphaTestRef;
uniform vec4 entityColor;
uniform int entityId;

in vec2 vTexCoord;
in vec2 vLightmapCoord;
in vec4 vVertexColor;
in vec3 vPlayerNormal;
in vec3 vPlayerTangent;
flat in float vTangentHandedness;
in vec3 vTangentView;
flat in vec4 vTexCoordAM;

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


vec3 calculateOpaquePbrNormal(vec3 geometricNormal, vec2 materialUv, vec2 uvDx, vec2 uvDy, out float materialAO) {
    vec4 normalTexel = textureGrad(normals, materialUv, uvDx, uvDy);
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


void main() {
    vec2 uvDx = dFdx(vTexCoord);
    vec2 uvDy = dFdy(vTexCoord);
    vec2 materialUv = vTexCoord;
    vec4 albedo = texture(gtexture, materialUv) * vVertexColor;
    if (albedo.a < alphaTestRef) discard;
    float parallaxOffset = 0.0;
#if POM_ENTITY_STRENGTH > 0
    if (gl_FrontFacing && entityId != 50128 && entityId != 50132) {
        vec2 parallaxUv = calculateParallaxUv(vTexCoord, uvDx, uvDy, vTexCoordAM,
            vTangentView, length(vTangentView), parallaxOffset);
        if (parallaxOffset > 0.00001) {
            vec4 parallaxAlbedo = textureGrad(gtexture, parallaxUv, uvDx, uvDy) * vVertexColor;
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
    outColor = albedo;
    float skyLight = clamp(vLightmapCoord.y / (30.0 / 32.0) - (1.0 / 32.0), 0.0, 1.0);
    outLightmapData = vec4(vanillaLight, skyLight);
    vec3 surfaceNormal = normalize(vPlayerNormal);
    if (!gl_FrontFacing) surfaceNormal = -surfaceNormal;
    float materialAO = 1.0;
    surfaceNormal = calculateOpaquePbrNormal(surfaceNormal, materialUv, uvDx, uvDy, materialAO);
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
    outEncodedNormal = vec4(surfaceNormal * 0.5 + 0.5, 0.5 + 0.5 * materialSmoothness);
    outEmissionData = vec4(pbrEmission, materialReflectance, materialAO, materialSurfaceData);
}
