#version 130

#include "/lib/taa_jitter.glsl"

out vec2 vTexCoord;
flat out vec4 vVertexColor;

void main() {
    gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vVertexColor = gl_Color;
    applySereneTaaJitter(gl_Position);
}
