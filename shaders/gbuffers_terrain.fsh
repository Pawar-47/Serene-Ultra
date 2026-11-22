#version 330 compatibility

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform sampler2D normals;
uniform sampler2D specular;
uniform float alphaTestRef;

in vec2 vTexCoord;
in vec2 vLightmapCoord;
in vec4 vVertexColor;
in vec3 vPlayerNormal;
in vec3 vPlayerTangent;
flat in float vTangentHandedness;
flat in int vMaterialId;

/* RENDERTARGETS: 0,1,2,3 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outLightmapData;
layout(location = 2) out vec4 outEncodedNormal;
layout(location = 3) out vec4 outEmissionData;

#define OPAQUE_NORMAL_MAP_STRENGTH 100 // [0 25 50 75 100 125 150] Resource-pack PBR normal-map detail
#define PBR_AO_STRENGTH 100 // [0 25 50 75 100] LabPBR material ambient occlusion

vec3 calculateOpaquePbrNormal(vec3 geometricNormal, out float materialAO) {
    vec4 normalTexel = texture(normals, vTexCoord);
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
    vec4 albedo = texture(gtexture, vTexCoord) * vVertexColor;
    if (albedo.a < alphaTestRef) discard;

    // Preserve the vanilla lightmap's RGB tint (including warm block light
    // and skylight color) plus a separate sky-light factor for direct sun.
    vec3 vanillaLight = texture(lightmap, vLightmapCoord).rgb;
    outColor = albedo;
    float skyLight = clamp(vLightmapCoord.y / (30.0 / 32.0) - (1.0 / 32.0), 0.0, 1.0);
    outLightmapData = vec4(vanillaLight, skyLight);
    vec3 surfaceNormal = normalize(vPlayerNormal);
    if (!gl_FrontFacing) surfaceNormal = -surfaceNormal;
    float materialAO = 1.0;
    surfaceNormal = calculateOpaquePbrNormal(surfaceNormal, materialAO);
    // Iris exposes the resource-pack specular atlas for oldPBR and LabPBR.
    // Both formats store smoothness in red; green is metalness (oldPBR) or
    // dielectric F0 / metal code (LabPBR).
    vec4 pbrSpecular = texture(specular, vTexCoord);
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
        materialReflectance = 1.0; // Metal: use albedo as F0 in deferred.
    } else {
        materialReflectance = labF0Code / 255.0;
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
