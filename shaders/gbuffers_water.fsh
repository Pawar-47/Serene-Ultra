#version 330 compatibility

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform sampler2D depthtex1;
uniform float alphaTestRef;
uniform mat4 gbufferProjectionInverse;
uniform sampler2DShadow shadowtex0;

uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 shadowLightPosition;
uniform float sunAngle;
uniform bool hasSkylight;
uniform float endFlashIntensity;
uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform float fogDensity;
uniform int fogMode;
uniform int fogShape;

in vec2 vTexCoord;
in vec2 vLightmapCoord;
in vec4 vVertexColor;
in vec3 vPlayerNormal;
in vec3 vPlayerPosition;
in vec3 vViewPosition;
flat in int vMaterialId;
flat in float vFluidRenderType;

/* RENDERTARGETS: 0 */

#define WATER_FOG_MULT 100 //[25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100 110 120 130 140 150 160 170 180 190 200 220 240 260 280 300 325 350 375 400 425 450 475 500 550 600 650 700 750 800 850 900] Water depth opacity
layout(location = 0) out vec4 outColor;

float sampleTranslucentShadow(vec3 playerPosition, vec3 normal, vec3 lightDirection) {
    vec4 shadowViewPosition = shadowModelView * vec4(playerPosition, 1.0);
    vec4 shadowClipPosition = shadowProjection * shadowViewPosition;

    float normalLight = max(dot(normal, lightDirection), 0.0);
    float depthBias = mix(0.0022, 0.00065, normalLight);
    shadowClipPosition.z -= depthBias;

    vec3 shadowNdc = shadowClipPosition.xyz / shadowClipPosition.w;
    vec3 shadowPosition = shadowNdc * 0.5 + 0.5;
    if (shadowPosition.x <= 0.0 || shadowPosition.x >= 1.0 ||
        shadowPosition.y <= 0.0 || shadowPosition.y >= 1.0 ||
        shadowPosition.z <= 0.0 || shadowPosition.z >= 1.0) {
        return 1.0;
    }

    vec2 texel = 1.0 / vec2(textureSize(shadowtex0, 0));
    float visibility = 0.0;
    visibility += texture(shadowtex0, vec3(shadowPosition.xy + texel * vec2(-0.5, -0.5), shadowPosition.z));
    visibility += texture(shadowtex0, vec3(shadowPosition.xy + texel * vec2( 0.5, -0.5), shadowPosition.z));
    visibility += texture(shadowtex0, vec3(shadowPosition.xy + texel * vec2(-0.5,  0.5), shadowPosition.z));
    visibility += texture(shadowtex0, vec3(shadowPosition.xy + texel * vec2( 0.5,  0.5), shadowPosition.z));
    return visibility * 0.25;
}

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position) {
    vec4 homogeneous = projectionMatrix * vec4(position, 1.0);
    return homogeneous.xyz / homogeneous.w;
}

float calculateWaterThickness() {
    // depthtex1 is full-resolution; fetch the exact current pixel without
    // filtering, then normalize only for inverse-projection reconstruction.
    float opaqueDepth = texelFetch(depthtex1, ivec2(gl_FragCoord.xy), 0).r;
    // depthtex1 clears to 1.0. Reconstruct that far-plane sample with the
    // inverse projection instead of using Iris' "far" uniform, which is
    // render distance in blocks rather than the projection far plane.
    vec2 screenUV = gl_FragCoord.xy / vec2(textureSize(depthtex1, 0));
    vec3 opaqueNdc = vec3(screenUV, opaqueDepth) * 2.0 - 1.0;
    vec3 opaqueViewPosition = projectAndDivide(gbufferProjectionInverse, opaqueNdc);
    float opaqueDistance = length(opaqueViewPosition);
    return max(opaqueDistance - length(vViewPosition), 0.0);
}

float calculateTranslucentFog(float distanceToCamera) {
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

void main() {
    vec4 translucentAlbedo = texture(gtexture, vTexCoord) * vVertexColor;
    if (translucentAlbedo.a < alphaTestRef) discard;

    // Iris routes all translucent terrain through gbuffers_water, including
    // water and stained glass. Keep this a generic forward-lit surface path:
    // do not apply water-only material effects to non-fluid translucent blocks.
    // The pass cannot sample colortex0-3, so it uses atlas color, vanilla
    // lightmap, the already-rendered Iris shadow map and fog uniforms.
    vec3 vanillaLight = texture(lightmap, vLightmapCoord).rgb;
    float skyLight = clamp(vLightmapCoord.y / (30.0 / 32.0) - (1.0 / 32.0), 0.0, 1.0);

    vec3 normal = normalize(vPlayerNormal);
    vec3 viewLightDirection = normalize(shadowLightPosition);
    vec3 worldLightDirection = normalize(mat3(gbufferModelViewInverse) * viewLightDirection);
    float nDotL = max(dot(normal, worldLightDirection), 0.0);

    bool endFlashActive = endFlashIntensity > 0.001;
    float solarElevation = sin(sunAngle * 6.28318530718);
    float dayFactor = (hasSkylight && !endFlashActive)
        ? smoothstep(0.0, 0.30, solarElevation)
        : 0.0;
    float celestialGate = endFlashActive
        ? clamp(endFlashIntensity, 0.0, 1.0)
        : (hasSkylight ? skyLight : 0.0);

    float shadow = 1.0;
    if (nDotL > 0.001 && celestialGate > 0.001) {
        shadow = sampleTranslucentShadow(vPlayerPosition, normal, worldLightDirection);
    }

    vec3 ambient = vec3(0.018) + pow(max(vanillaLight, vec3(0.0)), vec3(2.2)) * 0.72;
    vec3 celestialColor = endFlashActive
        ? vec3(1.0)
        : (hasSkylight
            ? mix(vec3(0.36, 0.44, 0.68), vec3(1.0, 0.94, 0.82), dayFactor)
            : vec3(1.0));
    float celestialIntensity = endFlashActive
        ? 0.70
        : (hasSkylight ? mix(0.10, 0.70, dayFactor) : 0.0);
    vec3 direct = celestialColor * celestialIntensity * nDotL * shadow * celestialGate;

    // Iris mc_Entity.y identifies fluid geometry; block.properties supplies
    // stable IDs so water-only attenuation never affects glass, lava or portals.
    bool isWater = (vMaterialId == 32000) && (vFluidRenderType > 0.5);
    if (isWater) {
        // Match the reference shader's baseline water alpha shaping.
        translucentAlbedo.a = sqrt(max(translucentAlbedo.a, 0.0));
        float thickness = calculateWaterThickness() * (WATER_FOG_MULT * 0.01);
        float waterFog = clamp(1.0 - exp(-thickness * 0.075), 0.0, 1.0);
        translucentAlbedo.a *= 0.25 + 0.75 * waterFog;
    }

    vec3 albedoLinear = pow(max(translucentAlbedo.rgb, vec3(0.0)), vec3(2.2));
    vec3 litLinear = albedoLinear * (ambient + direct);
    float fogDistance = (fogShape == 1) ? length(vViewPosition.xz) : length(vViewPosition);
    float fogFactor = calculateTranslucentFog(fogDistance);
    vec3 fogColorLinear = pow(max(fogColor, vec3(0.0)), vec3(2.2));
    litLinear = mix(litLinear, fogColorLinear, fogFactor);
    vec3 litColor = pow(max(litLinear, vec3(0.0)), vec3(1.0 / 2.2));

    outColor = vec4(litColor, translucentAlbedo.a);
}
