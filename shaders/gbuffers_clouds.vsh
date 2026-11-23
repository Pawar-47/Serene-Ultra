#version 130

// Minecraft 26.3 Iris ShaderKey.CLOUDS uses POSITION_COLOR: no UV or normal input.

out vec4 vVertexColor;
uniform mat4 gbufferModelViewInverse;
out vec3 vViewPosition;
out vec3 vPlayerPosition;

void main() {
    gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
    vVertexColor = gl_Color;
    vec4 viewPosition = gl_ModelViewMatrix * gl_Vertex;
    vViewPosition = viewPosition.xyz;
    vPlayerPosition = (gbufferModelViewInverse * viewPosition).xyz;
}
