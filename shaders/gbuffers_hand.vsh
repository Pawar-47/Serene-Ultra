#version 330 compatibility

out vec2 vTexCoord;
out vec4 vVertexColor;

void main() {
    gl_Position = ftransform();
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vVertexColor = gl_Color;
}
