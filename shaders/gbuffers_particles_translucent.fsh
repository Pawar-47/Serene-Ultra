#version 330 compatibility

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform float alphaTestRef;
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

void main() {
    vec4 particle = texture(gtexture, vTexCoord) * vVertexColor;
    if (particle.a < alphaTestRef) discard;

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
