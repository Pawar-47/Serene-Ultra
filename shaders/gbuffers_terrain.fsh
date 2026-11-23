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

#include "/lib/materials/parallax.glsl"

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

vec3 calculateOpaquePbrNormal(vec3 geometricNormal, vec2 materialUv, out float materialAO) {
    vec4 normalTexel = texture(normals, materialUv);
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
    surfaceNormal = calculateOpaquePbrNormal(surfaceNormal, materialUv, materialAO);
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
