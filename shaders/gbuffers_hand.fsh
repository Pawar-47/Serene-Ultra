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
    // Iris' fog guide converts sampled colors to linear space before lighting.
    vec3 handLinear = pow(max(albedo.rgb, vec3(0.0)), vec3(2.2));
    vec3 lightmapLinear = pow(max(texture(lightmap, vLightmapCoord).rgb, vec3(0.0)), vec3(2.2));
    albedo.rgb = pow(max(handLinear * lightmapLinear, vec3(0.0)), vec3(1.0 / 2.2));
    outColor = albedo;
}
