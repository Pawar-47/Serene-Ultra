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
    vec4 particle = texture(gtexture, vTexCoord) * vVertexColor;
    if (particle.a < alphaTestRef) discard;

    // This is a post-deferred forward path: retain Minecraft's colored
    // lightmap response without sampling forbidden colortex0-3 attachments.
    particle.rgb *= texture(lightmap, vLightmapCoord).rgb;
    outColor = particle;
}
