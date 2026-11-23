#version 130

#include "/lib/taa_jitter.glsl"

out vec4 vVertexColor;
out vec3 vViewPosition;

void main() {
    vec4 viewPosition = gl_ModelViewMatrix * gl_Vertex;
    gl_Position = gl_ProjectionMatrix * viewPosition;
    vVertexColor = gl_Color;
    vViewPosition = (gl_ModelViewMatrix * gl_Vertex).xyz;
    applySereneTaaJitter(gl_Position);
}
