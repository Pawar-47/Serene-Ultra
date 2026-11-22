#version 330 compatibility

uniform sampler2D colortex3;

in vec2 vTexCoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
    // Deferred lighting writes to colortex3; this pass safely transfers the
    // completed result into colortex0 for the final post-processing stage.
    outColor = texture(colortex3, vTexCoord);
}
