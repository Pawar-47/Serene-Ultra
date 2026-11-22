#version 330 compatibility

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform float alphaTestRef;

in vec2 vTexCoord;
in vec2 vLightmapCoord;
in vec4 vVertexColor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
    vec4 albedo = texture(gtexture, vTexCoord) * vVertexColor;
    if (albedo.a < alphaTestRef) discard;
    // Hand geometry is not shaded by deferred; preserve its vanilla colored lightmap.
    albedo.rgb *= texture(lightmap, vLightmapCoord).rgb;
    outColor = albedo;
}
