#version 330 compatibility

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
    vec4 particle = texture(gtexture, vTexCoord) * vVertexColor;
    if (particle.a <= 0.001) discard;

    // This is a post-deferred forward path: retain Minecraft's colored
    // lightmap response without sampling forbidden colortex0-3 attachments.
    vec3 lightmapLinear = pow(max(texture(lightmap, vLightmapCoord).rgb, vec3(0.0)), vec3(2.2));
    vec3 particleLinear = pow(max(particle.rgb, vec3(0.0)), vec3(2.2)) * lightmapLinear;
    float fogDistance = (fogShape == 1) ? length(vViewPosition.xz) : length(vViewPosition);
    float fogFactor = calculateParticleFog(fogDistance);
    vec3 fogColorLinear = pow(max(fogColor, vec3(0.0)), vec3(2.2));
    particle.rgb = pow(max(mix(particleLinear, fogColorLinear, fogFactor), vec3(0.0)), vec3(1.0 / 2.2));
    outColor = particle;
}
