#version 330 compatibility

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform float alphaTestRef;

in vec2 vTexCoord;
in vec2 vLightmapCoord;
in vec4 vVertexColor;
in vec3 vPlayerNormal;

#define PARTICLE_MATERIAL_FEATURES // Detect emissive particle textures

/* RENDERTARGETS: 0,1,2,3 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outLightmapData;
layout(location = 2) out vec4 outEncodedNormal;
layout(location = 3) out vec4 outEmissionData;

void main() {
    vec4 particleTexture = texture(gtexture, vTexCoord);
    vec4 particle = particleTexture * vVertexColor;
    if (particle.a < alphaTestRef) discard;

    float emissionStrength = 0.0;
    bool suppressLightmap = false;

    #ifdef PARTICLE_MATERIAL_FEATURES
    // The 1.20+ particle atlas is below 1100 px wide in the reference setup.
    // Avoid applying particle heuristics to a larger resource-pack atlas.
    if (float(textureSize(gtexture, 0).x) < 1100.0) {
        float textureColorSpread = max(
            max(abs(particleTexture.r - particleTexture.g), abs(particleTexture.g - particleTexture.b)),
            abs(particleTexture.b - particleTexture.r)
        );
        float particleColorSum = dot(particle.rgb, vec3(1.0));

        if (textureColorSpread < 0.001 && particleColorSum > 2.9 && particle.a > 0.99) {
            if (particleTexture.r < 0.75) {
                // Ender-family, crying obsidian and redstone emissive particles.
                emissionStrength = clamp(particle.r * 8.0, 1.6, 5.0);
                suppressLightmap = true;
                particle.rgb = pow(max(particle.rgb, vec3(0.0)), vec3(1.5));
            } else {
                // Lava particles retain their normal lightmap contribution.
                emissionStrength = 2.0;
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

    outColor = particle;
    outLightmapData = vec4(vanillaLight, skyLight);
    vec3 surfaceNormal = normalize(vPlayerNormal);
    if (!gl_FrontFacing) surfaceNormal = -surfaceNormal;
    outEncodedNormal = vec4(surfaceNormal * 0.5 + 0.5, 1.0);
    outEmissionData = vec4(emissionStrength / 5.0, 0.0, 0.0, 1.0);
}
