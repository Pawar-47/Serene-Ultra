#version 130

#include "/lib/taa_jitter.glsl"

out vec3 vVertexColorLinear;
out float vVertexAlpha;
flat out vec3 vFogLinear;
flat out vec3 vSkyLinear;

uniform vec3 fogColor;
uniform vec3 skyColor;

void main() {
    gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
    vVertexColorLinear = pow(max(gl_Color.rgb, vec3(0.0)), vec3(2.2));
    vVertexAlpha = gl_Color.a;
    vFogLinear = pow(max(fogColor, vec3(0.0)), vec3(2.2));
    vSkyLinear = pow(max(skyColor, vec3(0.0)), vec3(2.2));
    applySereneTaaJitter(gl_Position);
}
