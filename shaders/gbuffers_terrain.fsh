#version 330 compatibility

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform float alphaTestRef;

in vec2 vTexCoord;
in vec2 vLightmapCoord;
in vec4 vVertexColor;
in vec3 vPlayerNormal;
flat in int vMaterialId;

/* RENDERTARGETS: 0,1,2,3 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outLightmapData;
layout(location = 2) out vec4 outEncodedNormal;
layout(location = 3) out vec4 outEmissionData;

void main() {
    vec4 albedo = texture(gtexture, vTexCoord) * vVertexColor;
    if (albedo.a < alphaTestRef) discard;

    // Preserve the vanilla lightmap's RGB tint (including warm block light
    // and skylight color) plus a separate sky-light factor for direct sun.
    vec3 vanillaLight = texture(lightmap, vLightmapCoord).rgb;
    outColor = albedo;
    float skyLight = clamp(vLightmapCoord.y / (30.0 / 32.0) - (1.0 / 32.0), 0.0, 1.0);
    outLightmapData = vec4(vanillaLight, skyLight);
    vec3 surfaceNormal = normalize(vPlayerNormal);
    if (!gl_FrontFacing) surfaceNormal = -surfaceNormal;
    outEncodedNormal = vec4(surfaceNormal * 0.5 + 0.5, 1.0);

    // Store a compact emissive material channel for the deferred pass.
    // Strength is normalized to [0,1] in alpha; RGB keeps the surface tint.
    float emissionStrength = 0.0;
    if (vMaterialId == 32100 || vMaterialId == 32101 ||
        vMaterialId == 32109 || vMaterialId == 32113 ||
        vMaterialId == 32114 || vMaterialId == 32115) {
        emissionStrength = 1.25;
    } else if (vMaterialId == 32103 || vMaterialId == 32108 ||
               vMaterialId == 32117 || vMaterialId == 32118 || vMaterialId == 32123) {
        emissionStrength = 0.90;
    } else if (vMaterialId == 32102 || vMaterialId == 32104 ||
               vMaterialId == 32105 || vMaterialId == 32110 ||
               vMaterialId == 32111 || vMaterialId == 32120 ||
               vMaterialId == 32121 || vMaterialId == 32122) {
        emissionStrength = 0.55;
    } else if (vMaterialId == 32116) {
        emissionStrength = 0.25;
    }

    outEmissionData = vec4(emissionStrength / 5.0, 0.0, 0.0, 1.0);
}
