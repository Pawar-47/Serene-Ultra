#version 330 compatibility

uniform sampler2D colortex0;
uniform float viewWidth;
uniform float viewHeight;

in vec2 vTexCoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
    // Until deferred lighting is integrated, preserve the captured scene
    // exactly while keeping this pass explicitly bound to colortex0.
    outColor = texture2D(colortex0, vTexCoord);
}
