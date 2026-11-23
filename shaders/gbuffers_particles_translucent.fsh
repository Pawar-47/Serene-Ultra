#version 330 compatibility

#define CLOUD_SHADOW_STRENGTH 65 // [0 20 40 60 80 100] Procedural cloud-shadow strength
#define CLOUD_ALTITUDE 192 // [128 160 192 224 256] Cloud layer centre height in blocks
#define CLOUD_SPEED 100 // [0 25 50 75 100 125 150] Cloud wind speed

#define SHADOW_FILTER_QUALITY 8 // [4 8 12] Rotated Poisson PCF shadow samples

#define HELD_LIGHTING_STRENGTH 50 // [0 25 50 75 100] Dynamic main/offhand item light contribution

#define PARTICLE_MATERIAL_FEATURES // Detect water, rain, snow, smoke and emissive particle textures
#define WEATHER_TEX_OPACITY 100 // [25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100 110 120 130 140 150 160 170 180 190 200 220 240 260 280 300 325 350 375 400 425 450 475 500 550 600 650 700 750 800 850 900] Weather particle opacity

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform sampler2D noisetex;
uniform sampler2DShadow shadowtex0;
uniform float frameTimeCounter;
uniform vec3 cameraPositionFract;
uniform ivec3 cameraPositionInt;
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 gbufferModelViewInverse;
uniform vec3 shadowLightPosition;
uniform float sunAngle;
uniform bool hasSkylight;
uniform float rainStrength;
uniform float endFlashIntensity;
uniform int isEyeInWater;
uniform vec3 cameraPosition;
uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform float fogDensity;
uniform int fogMode;
uniform int fogShape;

in vec2 vTexCoord;
in vec2 vLightmapCoord;
in vec4 vVertexColor;
in vec3 vViewPosition;
in vec3 vPlayerPosition;
in vec3 vPlayerNormal;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

#include "/lib/lighting/cloud_shadows.glsl"

#include "/lib/lighting/soft_shadow.glsl"

float calculateParticleFog(float distanceToCamera) {
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

void main() {
    vec4 particleTexture = texture(gtexture, vTexCoord);
    vec4 particle = particleTexture * vVertexColor;
    if (particle.a < 0.01) discard;

    float emission = 0.0;
    bool suppressLightmap = false;
    float rainTexOpacity = 0.25;
    float snowTexOpacity = 0.5;
    #if WEATHER_TEX_OPACITY != 100
        float opacityExponent = 100.0 / WEATHER_TEX_OPACITY;
        rainTexOpacity = pow(0.25, opacityExponent);
        snowTexOpacity = pow(0.5, opacityExponent);
    #endif

    // This is a post-deferred forward path: retain Minecraft's colored
    // lightmap response without sampling forbidden colortex0-3 attachments.
    #ifdef PARTICLE_MATERIAL_FEATURES
        if (float(textureSize(gtexture, 0).x) < 1100.0) {
            if (particle.b > 1.15 * (particle.r + particle.g) &&
                particle.g > particle.r * 1.25 && particle.g < 0.425 && particle.b > 0.75) {
                // Water splash/drop particles: reduce saturation and opacity.
                particle.rgb = pow(max(particle.rgb, vec3(0.0)), vec3(1.0 / 3.0)) * 0.7;
                float particleDither = textureLod(noisetex, gl_FragCoord.xy / 128.0, 0.0).b;
                if (particleDither > 0.4) discard;
            } else if (hasSkylight && rainStrength > 0.001 && particle.b > 0.7 && particle.r < 0.28 &&
                       particle.g < 0.425 && particle.g > particle.r * 1.4) {
                // Physics-mod rain particles; require Iris to report active sky weather.
                if (particle.a < 0.1 || isEyeInWater == 3) discard;
                particle.a *= rainTexOpacity;
                particle.rgb = sqrt(max(particle.rgb, vec3(0.0)));
            } else if (hasSkylight && rainStrength > 0.001 && all(equal(particle.rgb, vec3(1.0))) &&
                       particle.a < 0.765 && particle.a > 0.605) {
                // Physics-mod snow particles.
                if (particle.a < 0.1 || isEyeInWater == 3) discard;
                particle.a *= snowTexOpacity;
                particle.rgb = sqrt(max(particle.rgb, vec3(0.0)));
            } else if (abs(particle.r - particle.g) < 0.001 &&
                       particle.r - 0.5 * particle.b < 0.06) {
                // Underwater particle sprites are suppressed outside water.
                if (isEyeInWater == 1) {
                    particle.rgb = sqrt(max(particle.rgb, vec3(0.0))) * 0.35;
                    if (fract(vPlayerPosition.y + cameraPosition.y) > 0.25) discard;
                }
            } else if (particle.a < 0.99 && dot(particle.rgb, particle.rgb) < 1.0) {
                // Campfire smoke is intentionally softer and more transparent.
                particle.a *= 0.5;
            } else if (max(abs(particleTexture.r - particleTexture.b),
                           abs(particleTexture.b - particleTexture.g)) < 0.001) {
                float dotColor = dot(particle.rgb, particle.rgb);
                if (dotColor > 0.25 && particle.g < 0.5 &&
                    ((particle.b > particle.r * 1.1 && particle.r > 0.3) ||
                     particle.r > (particle.g + particle.b) * 3.0)) {
                    // Ender, crying-obsidian and redstone particles.
                    emission = clamp(particle.r * 8.0, 1.6, 5.0);
                    suppressLightmap = true;
                    particle.rgb = pow(max(particle.rgb, vec3(0.0)), vec3(1.5));
                } else if (particle.r > 0.83 && particle.g > 0.23 && particle.b < 0.4) {
                    // Lava particles.
                    emission = 2.0;
                    particle.b *= 0.5;
                    particle.r *= 1.2;
                }
            }
        }
    #endif

    vec3 vanillaLight = texture(lightmap, vLightmapCoord).rgb;
    float skyLight = clamp(vLightmapCoord.y / (30.0 / 32.0) - (1.0 / 32.0), 0.0, 1.0);
    if (suppressLightmap) {
        vanillaLight = vec3(0.0);
        skyLight = 0.0;
    }

    vec3 normal = normalize(vPlayerNormal);
    if (!gl_FrontFacing) normal = -normal;
    vec3 viewLightDirection = normalize(shadowLightPosition);
    vec3 playerLightDirection = normalize(mat3(gbufferModelViewInverse) * viewLightDirection);
    float nDotL = max(dot(normal, playerLightDirection), 0.0);

    bool endFlashActive = endFlashIntensity > 0.001;
    float solarElevation = sin(sunAngle * 6.28318530718);
    float dayFactor = (hasSkylight && !endFlashActive)
        ? smoothstep(0.0, 0.30, solarElevation)
        : 0.0;
    float celestialGate = suppressLightmap
        ? 0.0
        : (endFlashActive
            ? clamp(endFlashIntensity, 0.0, 1.0)
            : (hasSkylight ? skyLight : 0.0));

    vec3 shadow = vec3(1.0);
    if (emission <= 0.001 && nDotL > 0.001 && celestialGate > 0.001) {
        shadow = sampleSereneSoftShadow(vPlayerPosition, normal, playerLightDirection);
    }

    vec3 ambient = vec3(0.018) + pow(max(vanillaLight, vec3(0.0)), vec3(2.2)) * 0.72;
#if HELD_LIGHTING_STRENGTH > 0
    vec3 heldLighting = calculateHeldItemLighting(vPlayerPosition);
    ambient = sqrt(ambient * ambient + heldLighting);
#endif
    vec3 celestialColor = endFlashActive
        ? vec3(1.0)
        : (hasSkylight
            ? mix(vec3(0.36, 0.44, 0.68), vec3(1.0, 0.94, 0.82), dayFactor)
            : vec3(1.0));
    float celestialIntensity = endFlashActive
        ? 0.70
        : (hasSkylight ? mix(0.10, 0.70, dayFactor) : 0.0);
    vec3 direct = celestialColor * celestialIntensity * nDotL * shadow * celestialGate;
    float cloudShadow = sampleSereneCloudShadow(vPlayerPosition, playerLightDirection, dayFactor);
    direct *= cloudShadow;

    vec3 particleLinear = pow(max(particle.rgb, vec3(0.0)), vec3(2.2));
    vec3 litLinear = particleLinear * (ambient + direct) + particleLinear * emission;
    float fogDistance = (fogShape == 1) ? max(length(vViewPosition.xz), abs(vViewPosition.y)) : length(vViewPosition);
    float fogFactor = calculateParticleFog(fogDistance);
    vec3 fogColorLinear = pow(max(fogColor, vec3(0.0)), vec3(2.2));
    particle.rgb = pow(max(mix(litLinear, fogColorLinear, fogFactor), vec3(0.0)), vec3(1.0 / 2.2));
    outColor = particle;
}
