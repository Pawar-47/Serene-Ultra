#version 330 compatibility

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform float alphaTestRef;

in vec2 vTexCoord;
in vec2 vLightmapCoord;
in vec4 vVertexColor;
in vec3 vPlayerNormal;

/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outLightmapData;
layout(location = 2) out vec4 outEncodedNormal;

void main() {
    vec4 albedo = texture(gtexture, vTexCoord) * vVertexColor;
    if (albedo.a < alphaTestRef) discard;

    // Preserve the vanilla lightmap's RGB tint (including warm block light
    // and skylight color) plus a separate sky-light factor for direct sun.
    vec3 vanillaLight = texture(lightmap, vLightmapCoord).rgb;
    outColor = albedo;
    outLightmapData = vec4(vanillaLight, vLightmapCoord.y);
    outEncodedNormal = vec4(normalize(vPlayerNormal) * 0.5 + 0.5, 1.0);
}
