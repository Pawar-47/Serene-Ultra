#version 330 compatibility

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform float alphaTestRef;
uniform vec4 entityColor;

in vec2 vTexCoord;
in vec2 vLightmapCoord;
in vec4 vVertexColor;
in vec3 vPlayerNormal;

/* RENDERTARGETS: 0,1,2,3 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outLightmapData;
layout(location = 2) out vec4 outEncodedNormal;
layout(location = 3) out vec4 outEmissionData;

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
    outEncodedNormal = vec4(surfaceNormal * 0.5 + 0.5, 1.0);
    outEmissionData = vec4(0.0);
}
