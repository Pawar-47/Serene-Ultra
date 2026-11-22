#version 330 compatibility

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform sampler2D normals;
uniform sampler2D specular;
uniform float alphaTestRef;
uniform vec4 entityColor;

in vec2 vTexCoord;
in vec2 vLightmapCoord;
in vec4 vVertexColor;
in vec3 vPlayerNormal;
in vec3 vPlayerTangent;
flat in float vTangentHandedness;

/* RENDERTARGETS: 0,1,2,3 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outLightmapData;
layout(location = 2) out vec4 outEncodedNormal;
layout(location = 3) out vec4 outEmissionData;

#define OPAQUE_NORMAL_MAP_STRENGTH 100 // [0 25 50 75 100 125 150] Resource-pack PBR normal-map detail

vec3 calculateOpaquePbrNormal(vec3 geometricNormal) {
    vec4 normalTexel = textureLod(normals, vTexCoord, 0.0);
    vec3 tangentNormal;
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
    tangentNormal.xy = normalTexel.rg * 2.0 - 1.0;
    tangentNormal.z = sqrt(max(1.0 - dot(tangentNormal.xy, tangentNormal.xy), 0.0));
    tangentNormal.y = -tangentNormal.y;
#else
    tangentNormal = normalTexel.rgb * 2.0 - 1.0;
#endif
    tangentNormal.xy *= OPAQUE_NORMAL_MAP_STRENGTH * 0.01;
    tangentNormal = normalize(tangentNormal);

    vec3 tangent = normalize(vPlayerTangent - geometricNormal * dot(vPlayerTangent, geometricNormal));
    vec3 bitangent = normalize(cross(tangent, geometricNormal)) * vTangentHandedness;
    return normalize(
        tangent * tangentNormal.x +
        bitangent * tangentNormal.y +
        geometricNormal * tangentNormal.z
    );
}



void main() {
    vec4 albedo = texture(gtexture, vTexCoord) * vVertexColor;
    if (albedo.a < alphaTestRef) discard;

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
#if OPAQUE_NORMAL_MAP_STRENGTH > 0
    surfaceNormal = calculateOpaquePbrNormal(surfaceNormal);
#endif
    vec4 pbrSpecular = texture(specular, vTexCoord);
    float materialSmoothness = clamp(pbrSpecular.r, 0.0, 1.0);
    float materialReflectance = 0.0;
    float pbrEmission = 0.0;
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
    float labF0Code = floor(pbrSpecular.g * 255.0 + 0.5);
    float pbrMapPresent = step(0.0001, max(max(pbrSpecular.r, pbrSpecular.g), max(pbrSpecular.b, pbrSpecular.a)));
    if (pbrMapPresent < 0.5) {
        materialReflectance = 0.04;
    } else if (labF0Code >= 230.0) {
        materialReflectance = 1.0;
    } else {
        materialReflectance = (labF0Code / 229.0) * 0.08;
    }
    float labEmissionCode = floor(pbrSpecular.a * 255.0 + 0.5);
    if (labEmissionCode < 254.5) pbrEmission = labEmissionCode / 254.0;
#else
    materialReflectance = clamp(pbrSpecular.g, 0.0, 1.0);
    pbrEmission = clamp(pbrSpecular.b, 0.0, 1.0);
#endif
    outEncodedNormal = vec4(surfaceNormal * 0.5 + 0.5, 0.5 + 0.5 * materialSmoothness);
    outEmissionData = vec4(pbrEmission, materialReflectance, 0.0, 1.0);
}
