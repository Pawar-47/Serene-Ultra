#version 330 compatibility

#define HAND_PBR_STRENGTH 100 // [0 25 50 75 100]

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform sampler2D normals;
uniform sampler2D specular;
uniform float alphaTestRef;
uniform int currentRenderedItemId;
uniform vec3 shadowLightPosition;
uniform bool hasSkylight;

in vec2 vTexCoord;
in vec2 vLightmapCoord;
in vec4 vVertexColor;
in vec3 vViewPosition;
in vec3 vViewNormal;
in vec3 vViewTangent;
in vec3 vViewBitangent;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

const float HAND_PI = 3.14159265359;

void main() {
    vec2 uvDx = dFdx(vTexCoord);
    vec2 uvDy = dFdy(vTexCoord);
    vec4 albedo = textureGrad(gtexture, vTexCoord, uvDx, uvDy) * vVertexColor;
    if (albedo.a < alphaTestRef) discard;

    vec3 handLinear = pow(max(albedo.rgb, vec3(0.0)), vec3(2.2));
    vec3 lightmapLinear = pow(max(texture(lightmap, vLightmapCoord).rgb, vec3(0.0)), vec3(2.2));
    vec3 finalLinear = handLinear * lightmapLinear;

#if HAND_PBR_STRENGTH > 0
    vec4 normalTexel = textureGrad(normals, vTexCoord, uvDx, uvDy);
    vec3 tangentNormal;
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
    tangentNormal.xy = normalTexel.rg * 2.0 - 1.0;
    tangentNormal.z = sqrt(max(1.0 - dot(tangentNormal.xy, tangentNormal.xy), 0.0));
    tangentNormal.y = -tangentNormal.y;
#else
    tangentNormal = normalTexel.rgb * 2.0 - 1.0;
#endif
    tangentNormal.xy *= float(HAND_PBR_STRENGTH) * 0.01;
    tangentNormal = normalize(tangentNormal);

    vec3 surfaceNormal = normalize(
        normalize(vViewTangent) * tangentNormal.x +
        normalize(vViewBitangent) * tangentNormal.y +
        normalize(vViewNormal) * tangentNormal.z
    );

    vec4 pbrSpecular = textureGrad(specular, vTexCoord, uvDx, uvDy);
    float specularMapMagnitude = max(max(pbrSpecular.r, pbrSpecular.g), max(pbrSpecular.b, pbrSpecular.a));
    bool hasSpecularMap = specularMapMagnitude > 0.0001;
    float materialSmoothness = clamp(pbrSpecular.r, 0.0, 1.0);
    float materialMetalness = 0.0;
    vec3 f0 = vec3(0.04);
    float pbrEmission = 0.0;

#ifdef MC_TEXTURE_FORMAT_LAB_PBR
    float labF0Code = floor(pbrSpecular.g * 255.0 + 0.5);
    if (hasSpecularMap && labF0Code >= 230.0) {
        materialMetalness = 1.0;
        f0 = handLinear;
    } else if (hasSpecularMap) {
        f0 = vec3(labF0Code / 255.0);
    }
    float labEmissionCode = floor(pbrSpecular.a * 255.0 + 0.5);
    if (labEmissionCode < 254.5) pbrEmission = labEmissionCode / 254.0;
#else
    materialMetalness = clamp(pbrSpecular.g, 0.0, 1.0);
    f0 = mix(vec3(0.04), handLinear, materialMetalness);
    pbrEmission = clamp(pbrSpecular.b, 0.0, 1.0);
#endif

    if (!hasSpecularMap) {
        if (currentRenderedItemId == 45004) {
            float woodGloss = dot(albedo.rgb, vec3(0.3));
            materialSmoothness = clamp(woodGloss * woodGloss, 0.0, 0.4);
        } else if (currentRenderedItemId == 45008) {
            materialSmoothness = clamp(pow(albedo.g, 4.0) * 2.0, 0.0, 0.4);
        } else if (currentRenderedItemId == 45012 || currentRenderedItemId == 45013) {
            materialSmoothness = clamp(pow(albedo.r, 2.0), 0.0, 1.0);
            materialMetalness = 0.75;
        } else if (currentRenderedItemId == 45016 || currentRenderedItemId == 45017) {
            float goldGreenFourth = pow(albedo.g, 4.0);
            materialSmoothness = clamp(max(albedo.g, 0.8) - goldGreenFourth * 0.5, 0.0, 1.0);
            materialMetalness = 0.9;
        } else if (currentRenderedItemId == 45020 || currentRenderedItemId == 45021) {
            materialSmoothness = clamp(max(albedo.g, 0.8) - pow(albedo.g, 4.0) * 0.4, 0.0, 1.0);
            materialMetalness = 0.55;
        } else if (currentRenderedItemId == 45024 || currentRenderedItemId == 45025 || currentRenderedItemId == 45026) {
            materialSmoothness = clamp(albedo.b * 1.65, 0.0, 1.0);
            materialMetalness = 0.85;
        } else if (currentRenderedItemId == 45036) {
            float colorDifference = max(max(abs(albedo.r - albedo.g), abs(albedo.g - albedo.b)), abs(albedo.r - albedo.b));
            materialSmoothness = colorDifference < 0.01
                ? clamp(pow(albedo.r, 2.0), 0.0, 1.0)
                : clamp(albedo.b, 0.0, 1.0);
            materialMetalness = colorDifference < 0.01 ? 0.75 : 0.1;
        } else if (currentRenderedItemId == 45056) {
            materialSmoothness = clamp(0.8 - pow(albedo.r, 2.0) * 0.3, 0.0, 1.0);
            materialMetalness = 0.15;
        } else if (currentRenderedItemId == 45060) {
            materialSmoothness = clamp(min(albedo.r * albedo.g * albedo.b * 4.0, 0.7) * 0.7, 0.0, 1.0);
        } else if (currentRenderedItemId == 45064) {
            materialSmoothness = clamp(albedo.g * 0.7, 0.0, 1.0);
        } else if (currentRenderedItemId == 45068) {
            materialSmoothness = 1.0;
        } else if (currentRenderedItemId == 45076 || currentRenderedItemId == 45108) {
            // Clock and totem use the reference's gold-block response.
            float goldGreenFourth = pow(albedo.g, 4.0);
            materialSmoothness = clamp(max(albedo.g, 0.8) - goldGreenFourth * 0.5, 0.0, 1.0);
            materialMetalness = 0.75;
            float goldLuminance = dot(albedo.rgb, vec3(0.2126, 0.7152, 0.0722));
            albedo.rgb *= 0.5 + 0.4 * goldLuminance;
        } else if (currentRenderedItemId == 45080 || currentRenderedItemId == 45084) {
            // Compass, echo shard, recovery compass and music disc 5 use iron response.
            materialSmoothness = clamp(pow(albedo.r, 2.0), 0.0, 1.0);
            materialMetalness = 0.75;
            float ironLuminance = dot(albedo.rgb, vec3(0.2126, 0.7152, 0.0722));
            albedo.rgb *= 0.6 + 0.5 * ironLuminance;
        } else if (currentRenderedItemId == 44013 &&
                   albedo.r + albedo.g <= albedo.b * 2.0) {
            // Non-lava contents of a lava bucket fall back to iron material response.
            materialSmoothness = clamp(pow(albedo.r, 2.0), 0.0, 1.0);
            materialMetalness = 0.75;
        } else if (currentRenderedItemId == 44085) {
            materialSmoothness = clamp(albedo.g, 0.0, 1.0);
            materialMetalness = 0.65;
        } else if (currentRenderedItemId == 45116 || currentRenderedItemId == 45117) {
            float copperSmoothness = pow(albedo.r, 4.0)
                + pow(max(albedo.g - albedo.r * 0.5, 0.0), 2.0) * 0.3;
            materialSmoothness = clamp(copperSmoothness, 0.0, 1.0);
            materialMetalness = 0.65;
            float copperLuminance = dot(albedo.rgb, vec3(0.2126, 0.7152, 0.0722));
            albedo.rgb *= clamp(0.6 + 0.7 * copperLuminance, 0.0, 1.0);
        }
        f0 = mix(vec3(0.04), handLinear, materialMetalness);
    }

    if (pbrEmission < 0.01) {
        if (currentRenderedItemId == 44090) {
            if (!hasSpecularMap) materialSmoothness = 1.0;
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
            if (albedo.g < albedo.r) {
                pbrEmission = 3.0;
                albedo.r *= 1.1;
            }
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
            float trialKeyEmission = abs(albedo.r - albedo.b) * 3.0;
            pbrEmission = trialKeyEmission;
            albedo.rgb = pow(max(albedo.rgb, vec3(0.0)), vec3(1.0 + 0.5 * sqrt(trialKeyEmission)));
        } else if (currentRenderedItemId == 44002 || currentRenderedItemId == 44003 ||
                   currentRenderedItemId == 44010 || currentRenderedItemId == 44011 ||
                   currentRenderedItemId == 44012 || currentRenderedItemId == 44018 ||
                   currentRenderedItemId == 44019 || currentRenderedItemId == 44028 ||
                   currentRenderedItemId == 44029 || currentRenderedItemId == 44030 ||
                   currentRenderedItemId == 44035) {
            pbrEmission = max(max(albedo.r, albedo.g), albedo.b) * 0.5;
        }
    }

    vec3 viewDirection = normalize(-vViewPosition);
    vec3 lightDirection = normalize(shadowLightPosition);
    float nDotL = max(dot(surfaceNormal, lightDirection), 0.0);
    float nDotV = max(dot(surfaceNormal, viewDirection), 0.001);
    float skyFactor = hasSkylight ? clamp(vLightmapCoord.y, 0.0, 1.0) : 0.0;

    if (nDotL > 0.001 && skyFactor > 0.001) {
        vec3 halfVector = normalize(viewDirection + lightDirection);
        float nDotH = max(dot(surfaceNormal, halfVector), 0.0);
        float vDotH = max(dot(viewDirection, halfVector), 0.0);
        float roughness = max(1.0 - materialSmoothness, 0.045);
        float alpha = roughness * roughness;
        float alphaSquared = alpha * alpha;
        float distributionDenominator = nDotH * nDotH * (alphaSquared - 1.0) + 1.0;
        float distribution = alphaSquared / (HAND_PI * distributionDenominator * distributionDenominator + 0.00001);
        float geometryK = (roughness + 1.0) * (roughness + 1.0) * 0.125;
        float geometryV = nDotV / (nDotV * (1.0 - geometryK) + geometryK);
        float geometryL = nDotL / (nDotL * (1.0 - geometryK) + geometryK);
        vec3 fresnel = f0 + (vec3(1.0) - f0) * pow(1.0 - vDotH, 5.0);
        vec3 directSpecular = distribution * geometryV * geometryL * fresnel /
            max(4.0 * nDotV * nDotL, 0.001);
        finalLinear += directSpecular * nDotL * skyFactor *
            (0.35 * float(HAND_PBR_STRENGTH) * 0.01);
    }

    finalLinear += handLinear * pbrEmission * (1.5 * float(HAND_PBR_STRENGTH) * 0.01);
#endif

    albedo.rgb = pow(max(finalLinear, vec3(0.0)), vec3(1.0 / 2.2));
    outColor = albedo;
}
