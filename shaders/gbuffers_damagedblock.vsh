#version 330 compatibility

#include "/lib/taa_jitter.glsl"

out vec2 vTexCoord;
flat out vec4 vVertexColor;

void main() {
    gl_Position = ftransform();
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vVertexColor = gl_Color;
    applySereneTaaJitter(gl_Position);
}
