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
in vec3 vPlayerPosition;

/* RENDERTARGETS: 0,1,2,3 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outLightmapData;
layout(location = 2) out vec4 outEncodedNormal;
layout(location = 3) out vec4 outEmissionData;

#define OPAQUE_NORMAL_MAP_STRENGTH 100 // [0 25 50 75 100 125 150] Item normal-map strength
#define PBR_AO_STRENGTH 100 // [0 25 50 75 100] LabPBR item material AO

vec3 calculateItemNormal(vec3 geometricNormal, vec2 uv, out float materialAO) {
    vec2 uvDx = dFdx(uv);
    vec2 uvDy = dFdy(uv);
    vec4 normalTexel = textureGrad(normals, uv, uvDx, uvDy);
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
    materialAO = mix(1.0, clamp(normalTexel.b, 0.0, 1.0), PBR_AO_STRENGTH * 0.01);
    vec2 normalXY = normalTexel.rg * 2.0 - 1.0;
    normalXY.y = -normalXY.y; // LabPBR uses DirectX Y-
    vec3 tangentNormal = vec3(normalXY, sqrt(max(1.0 - dot(normalXY, normalXY), 0.0)));
#else
    materialAO = 1.0;
    vec3 tangentNormal = normalTexel.rgb * 2.0 - 1.0;
#endif

    if (OPAQUE_NORMAL_MAP_STRENGTH <= 0 ||
        all(lessThan(abs(normalTexel.rg - vec2(0.5)), vec2(0.01)))) {
        return geometricNormal;
    }

    tangentNormal.xy *= OPAQUE_NORMAL_MAP_STRENGTH * 0.01;
    tangentNormal = normalize(tangentNormal);

    // Reconstruct a per-fragment tangent frame from position/UV derivatives.
    // This supports item atlas normal maps without requiring a non-vanilla
    // tangent vertex attribute on Minecraft's item vertex format.
    vec3 positionDx = dFdx(vPlayerPosition);
    vec3 positionDy = dFdy(vPlayerPosition);
    float determinant = uvDx.x * uvDy.y - uvDx.y * uvDy.x;
    if (abs(determinant) < 0.000001) return geometricNormal;

    vec3 tangent = (positionDx * uvDy.y - positionDy * uvDx.y) / determinant;
    tangent -= geometricNormal * dot(tangent, geometricNormal);
    float tangentLengthSquared = dot(tangent, tangent);
    if (tangentLengthSquared < 0.000001) return geometricNormal;
    tangent *= inversesqrt(tangentLengthSquared);

    vec3 rawBitangent = (-positionDx * uvDy.x + positionDy * uvDx.x) / determinant;
    float handedness = dot(cross(geometricNormal, tangent), rawBitangent) < 0.0
        ? -1.0 : 1.0;
    vec3 bitangent = normalize(cross(geometricNormal, tangent)) * handedness;
    return normalize(
        tangent * tangentNormal.x +
        bitangent * tangentNormal.y +
        geometricNormal * tangentNormal.z
    );
}

void main() {
    vec4 albedo = texture(gtexture, vTexCoord) * vVertexColor;
    if (albedo.a < alphaTestRef) discard;

    vec3 vanillaLight = texture(lightmap, vLightmapCoord).rgb;
    float skyLight = clamp(vLightmapCoord.y / (30.0 / 32.0) - (1.0 / 32.0), 0.0, 1.0);
    outLightmapData = vec4(vanillaLight, skyLight);

    vec3 geometricNormal = normalize(vPlayerNormal);
    if (!gl_FrontFacing) geometricNormal = -geometricNormal;
    float materialAO = 1.0;
    vec3 surfaceNormal = calculateItemNormal(geometricNormal, vTexCoord, materialAO);

    vec4 pbrSpecular = textureGrad(specular, vTexCoord, dFdx(vTexCoord), dFdy(vTexCoord));
    float specularMagnitude = max(
        max(pbrSpecular.r, pbrSpecular.g),
        max(pbrSpecular.b, pbrSpecular.a)
    );
    bool hasSpecularMap = specularMagnitude > 0.0001;
    float materialSmoothness = hasSpecularMap ? clamp(pbrSpecular.r, 0.0, 1.0) : 0.0;
    float materialReflectance = 0.0;
    float materialEmission = 0.0;
    float materialSurfaceData = 0.0;

#ifdef MC_TEXTURE_FORMAT_LAB_PBR
    if (!hasSpecularMap) {
        materialReflectance = 0.04;
    } else {
        float f0Code = floor(pbrSpecular.g * 255.0 + 0.5);
        float surfaceCode = floor(pbrSpecular.b * 255.0 + 0.5);
        if (f0Code >= 230.0) {
            materialReflectance = 1.0;
        } else {
            materialReflectance = f0Code / 255.0;
            materialSurfaceData = clamp(pbrSpecular.b, 0.0, 1.0);
        }
        float emissionCode = floor(pbrSpecular.a * 255.0 + 0.5);
        if (emissionCode < 254.5) materialEmission = emissionCode / 254.0;
    }
#else
    if (hasSpecularMap) {
        materialReflectance = clamp(pbrSpecular.g, 0.0, 1.0);
        materialEmission = clamp(pbrSpecular.b, 0.0, 1.0);
    }
#endif

    outColor = albedo;
    outEncodedNormal = vec4(
        surfaceNormal * 0.5 + 0.5,
        0.5 + materialSmoothness * 0.5
    );
    outEmissionData = vec4(
        materialEmission,
        materialReflectance,
        materialAO,
        materialSurfaceData
    );
}
