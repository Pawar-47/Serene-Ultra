#version 330 compatibility

uniform sampler2D colortex0;
uniform float viewWidth;
uniform float viewHeight;

in vec2 vTexCoord;
layout(location = 0) out vec4 outColor;

void main() {
    vec4 scene = texture2D(colortex0, vTexCoord);
    outColor = scene;
}
