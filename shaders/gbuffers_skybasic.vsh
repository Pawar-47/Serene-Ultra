#version 330 compatibility

flat out vec4 vVertexColor;

void main() {
    gl_Position = ftransform();
    vVertexColor = gl_Color;
}
