#version 130

out vec4 vVertexColor;
out vec3 vViewPosition;

void main() {
    gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
    vVertexColor = gl_Color;
    vViewPosition = (gl_ModelViewMatrix * gl_Vertex).xyz;
}
