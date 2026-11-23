#version 330 compatibility

#define CLOUD_SHADOW_STRENGTH 65 // [0 20 40 60 80 100] Procedural cloud-shadow strength
#define CLOUD_ALTITUDE 192 // [128 160 192 224 256] Cloud layer centre height in blocks
#define CLOUD_SPEED 100 // [0 25 50 75 100 125 150] Cloud wind speed
#define VOLUMETRIC_CLOUDS 1 // [0 1] Use procedural clouds in the sky pass instead of native flat clouds
#define CLOUD_DETAIL_STRENGTH 35 // [0 15 25 35 50 65 80 100] Multi-scale cloud detail
#define CLOUD_COVERAGE 55 // [35 45 55 65 75] Procedural cloud coverage
#define CLOUD_DENSITY 65 // [25 40 55 70 85 100] Volumetric cloud optical density
#define CLOUD_REFLECTION_STRENGTH 60 // [0 15 30 45 60 75 100] Procedural sky-cloud reflections on translucent materials

#define SHADOW_FILTER_QUALITY 8 // [4 8 12] Rotated Poisson PCF shadow samples

#define HELD_LIGHTING_STRENGTH 50 // [0 25 50 75 100] Dynamic main/offhand item light contribution
#define GLASS_REFLECTION_STRENGTH 60 // [0 15 30 45 60 75 90 100 125 150] Fresnel environment reflections for translucent surfaces

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform vec4 entityColor;
uniform sampler2DShadow shadowtex0;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform vec3 cameraPositionFract;
uniform ivec3 cameraPositionInt;
uniform sampler2D noisetex;
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 shadowLightPosition;
uniform vec3 skyColor;
uniform float sunAngle;
uniform bool hasSkylight;
uniform float endFlashIntensity;
uniform float thunderStrength;
uniform vec4 lightningBoltPosition;
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

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

#include "/lib/lighting/cloud_shadows.glsl"

#include "/lib/lighting/soft_shadow.glsl"

#include "/lib/lighting/lightning_flash.glsl"

#include "/lib/lighting/environment_reflection.glsl"

float calculateForwardFog(float distanceToCamera) {
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

#include "/lib/lighting/held_item_lighting.glsl"

vec3 calculateForwardLighting(vec3 albedoLinear) {
    vec3 vanillaLight = texture(lightmap, vLightmapCoord).rgb;
    vec3 ambient = vec3(0.018) + pow(max(vanillaLight, vec3(0.0)), vec3(2.2)) * 0.72;
#if HELD_LIGHTING_STRENGTH > 0
    vec3 heldLighting = calculateHeldItemLighting(vPlayerPosition);
    ambient = sqrt(ambient * ambient + heldLighting);
#endif

    vec3 normal = normalize(vPlayerNormal);
    if (!gl_FrontFacing) normal = -normal;
    vec3 viewLightDirection = normalize(shadowLightPosition);
    vec3 worldLightDirection = normalize(mat3(gbufferModelViewInverse) * viewLightDirection);
    float nDotL = max(dot(normal, worldLightDirection), 0.0);

    bool endFlashActive = endFlashIntensity > 0.001;
    float solarElevation = sin(sunAngle * 6.28318530718);
    float dayFactor = (hasSkylight && !endFlashActive)
        ? smoothstep(0.0, 0.30, solarElevation)
        : 0.0;
    float skyLight = clamp(vLightmapCoord.y / (30.0 / 32.0) - (1.0 / 32.0), 0.0, 1.0);
    float celestialGate = endFlashActive
        ? clamp(endFlashIntensity, 0.0, 1.0)
        : (hasSkylight ? skyLight : 0.0);

    vec3 shadow = vec3(1.0);
    if (nDotL > 0.001 && celestialGate > 0.001) {
        shadow = sampleSereneSoftShadow(vPlayerPosition, normal, worldLightDirection);
    }

    vec3 celestialColor = endFlashActive
        ? vec3(1.0)
        : (hasSkylight
            ? mix(vec3(0.36, 0.44, 0.68), vec3(1.0, 0.94, 0.82), dayFactor)
            : vec3(1.0));
    float celestialIntensity = endFlashActive
        ? 0.70
        : (hasSkylight ? mix(0.10, 0.70, dayFactor) : 0.0);
    vec3 direct = celestialColor * celestialIntensity * nDotL * shadow * celestialGate;
    float cloudShadow = sampleSereneCloudShadow(vPlayerPosition, worldLightDirection, dayFactor);
    direct *= cloudShadow;
    vec3 lightningFlash = sampleSereneLightningFlash(vPlayerPosition, normal);
    return albedoLinear * (ambient + direct + lightningFlash);
}


void main() {
    vec4 albedo = texture(gtexture, vTexCoord) * vVertexColor;
    if (albedo.a <= 0.001) discard;

    vec3 albedoLinear = pow(max(albedo.rgb, vec3(0.0)), vec3(2.2));
    vec3 tintLinear = pow(max(entityColor.rgb, vec3(0.0)), vec3(2.2));
    albedoLinear = mix(albedoLinear, tintLinear, entityColor.a);
    vec3 litLinear = calculateForwardLighting(albedoLinear);
#if GLASS_REFLECTION_STRENGTH > 0
    // Translucent block/entity materials use a low-cost environment fallback
    // with Schlick Fresnel. Water has its own depth-aware SSR path.
    if (albedo.a < 0.999) {
        vec3 surfaceNormal = normalize(vPlayerNormal);
        if (!gl_FrontFacing) surfaceNormal = -surfaceNormal;
        vec3 viewNormal = normalize(mat3(gbufferModelView) * surfaceNormal);
        vec3 incidentDirection = normalize(vViewPosition);
        vec3 reflectionDirection = normalize(reflect(incidentDirection, viewNormal));
        vec3 environmentReflection = calculateEnvironmentReflection(
            reflectionDirection, shadowLightPosition, sunAngle, hasSkylight
        );
        float nDotV = max(dot(viewNormal, normalize(-vViewPosition)), 0.0);
        float fresnel = 0.04 + 0.96 * pow(1.0 - nDotV, 5.0);
        float translucency = clamp(1.0 - albedo.a * 0.65, 0.2, 1.0);
        float reflectionWeight = clamp(
            fresnel * translucency * float(GLASS_REFLECTION_STRENGTH) * 0.01,
            0.0, 0.85
        );
        litLinear = mix(litLinear, environmentReflection, reflectionWeight);
    }
#endif
    float fogDistance = (fogShape == 1) ? max(length(vViewPosition.xz), abs(vViewPosition.y)) : length(vViewPosition);
    float fogFactor = calculateForwardFog(fogDistance);
    vec3 fogColorLinear = pow(max(fogColor, vec3(0.0)), vec3(2.2));
    litLinear = mix(litLinear, fogColorLinear, fogFactor);

    outColor = vec4(pow(max(litLinear, vec3(0.0)), vec3(1.0 / 2.2)), albedo.a);
}
