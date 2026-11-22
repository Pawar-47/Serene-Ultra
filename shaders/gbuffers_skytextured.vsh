#version 330 compatibility

out vec2 vTexCoord;
flat out vec4 vVertexColor;
out vec3 vViewPosition;

void main() {
    gl_Position = ftransform();
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vVertexColor = gl_Color;
    vViewPosition = (gl_ModelViewMatrix * gl_Vertex).xyz;
}
