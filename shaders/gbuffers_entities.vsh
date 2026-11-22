#version 330 compatibility

out vec2 vTexCoord;
out vec4 vVertexColor;
out vec3 vViewNormal;

void main() {
    gl_Position = ftransform();
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vVertexColor = gl_Color;
    vViewNormal = normalize(gl_NormalMatrix * gl_Normal);
}
