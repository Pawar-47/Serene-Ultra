#version 330 compatibility

// Minecraft 26.3 Iris ShaderKey.CLOUDS uses POSITION_COLOR: no UV or normal input.

out vec4 vVertexColor;
out vec3 vViewPosition;

void main() {
    gl_Position = ftransform();
    vVertexColor = gl_Color;
    vViewPosition = (gl_ModelViewMatrix * gl_Vertex).xyz;
}
