#version 330 compatibility

uniform sampler2D gtexture;

in vec2 vTexCoord;
flat in vec4 vVertexColor;

/* RENDERTARGETS: 0,2 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outDeferredValidity;

void main() {
    vec4 glintColor = texture(gtexture, vTexCoord) * vVertexColor;
    if (glintColor.a <= 0.001) discard;

    // Preserve Minecraft's glint-strength modulation and its active blend state.
    glintColor.rgb *= vVertexColor.a;
    outColor = glintColor;

    // Glint is an overlay, not a lit surface. Prevent deferred from reusing
    // the armor/entity normal stored underneath it.
    outDeferredValidity = vec4(0.0);
}
