#version 330 compatibility

#define PARTICLE_MATERIAL_FEATURES // Detect emissive, water, rain, snow and smoke particles

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform sampler2DShadow shadowtex0;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 gbufferModelViewInverse;
uniform vec3 shadowLightPosition;
uniform float sunAngle;
uniform bool hasSkylight;
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

float sampleParticleShadow(vec3 playerPosition, vec3 normal, vec3 lightDirection) {
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
    return texture(shadowtex0, vec3(shadowPosition.xy, shadowPosition.z));
}

void main() {
    vec4 particleTexture = texture(gtexture, vTexCoord);
    vec4 particle = particleTexture * vVertexColor;
    if (particle.a < 0.01) discard;

    float emission = 0.0;

    // This is a post-deferred forward path: retain Minecraft's colored
    // lightmap response without sampling forbidden colortex0-3 attachments.
    #ifdef PARTICLE_MATERIAL_FEATURES
        if (float(textureSize(gtexture, 0).x) < 1100.0) {
            if (particle.b > 1.15 * (particle.r + particle.g) &&
                particle.g > particle.r * 1.25 && particle.g < 0.425 && particle.b > 0.75) {
                // Water splash/drop particles: reduce saturation and opacity.
                particle.rgb = pow(max(particle.rgb, vec3(0.0)), vec3(1.0 / 3.0)) * 0.7;
                particle.a *= 0.6;
            } else if (particle.b > 0.7 && particle.r < 0.28 &&
                       particle.g < 0.425 && particle.g > particle.r * 1.4) {
                // Physics-mod rain particles.
                if (particle.a < 0.1 || isEyeInWater == 3) discard;
                particle.a *= 0.25;
                particle.rgb = sqrt(max(particle.rgb, vec3(0.0)));
            } else if (all(equal(particleTexture.rgb, vec3(1.0))) &&
                       particle.a < 0.765 && particle.a > 0.605) {
                // Physics-mod snow particles.
                if (particle.a < 0.1 || isEyeInWater == 3) discard;
                particle.a *= 0.5;
                particle.rgb = sqrt(max(particle.rgb, vec3(0.0)));
            } else if (abs(particleTexture.r - particleTexture.g) < 0.001 &&
                       particleTexture.r - 0.5 * particleTexture.b < 0.06) {
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

    vec3 normal = normalize(vPlayerNormal);
    vec3 viewLightDirection = normalize(shadowLightPosition);
    vec3 playerLightDirection = normalize(mat3(gbufferModelViewInverse) * viewLightDirection);
    float nDotL = max(dot(normal, playerLightDirection), 0.0);

    bool endFlashActive = endFlashIntensity > 0.001;
    float solarElevation = sin(sunAngle * 6.28318530718);
    float dayFactor = (hasSkylight && !endFlashActive)
        ? smoothstep(0.0, 0.30, solarElevation)
        : 0.0;
    float celestialGate = endFlashActive
        ? clamp(endFlashIntensity, 0.0, 1.0)
        : (hasSkylight ? skyLight : 0.0);

    float shadow = 1.0;
    if (emission <= 0.001 && nDotL > 0.001 && celestialGate > 0.001) {
        shadow = sampleParticleShadow(vPlayerPosition, normal, playerLightDirection);
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

    vec3 particleLinear = pow(max(particle.rgb, vec3(0.0)), vec3(2.2));
    vec3 litLinear = particleLinear * (ambient + direct) + particleLinear * emission;
    float fogDistance = (fogShape == 1) ? length(vViewPosition.xz) : length(vViewPosition);
    float fogFactor = calculateParticleFog(fogDistance);
    vec3 fogColorLinear = pow(max(fogColor, vec3(0.0)), vec3(2.2));
    particle.rgb = pow(max(mix(litLinear, fogColorLinear, fogFactor), vec3(0.0)), vec3(1.0 / 2.2));
    outColor = particle;
}
