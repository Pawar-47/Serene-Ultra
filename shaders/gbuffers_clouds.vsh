#version 130

// Minecraft 26.3 Iris ShaderKey.CLOUDS uses POSITION_COLOR: no UV or normal input.

out vec4 vVertexColor;
out vec3 vViewPosition;

void main() {
    gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
    vVertexColor = gl_Color;
    vViewPosition = (gl_ModelViewMatrix * gl_Vertex).xyz;
}
