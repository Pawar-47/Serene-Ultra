#version 330 compatibility

uniform sampler2D colortex0;

in vec2 vTexCoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
    // Deferred writes the lit opaque scene to colortex0 through Iris' main/alt
    // buffer flip. Post-deferred translucent gbuffers blend onto that scene.
    // This pass preserves the accumulated scene instead of copying stale data.
    outColor = texture(colortex0, vTexCoord);
}
