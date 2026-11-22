#version 330 compatibility

uniform sampler2D texture;

in vec2 vTexCoord;
in vec2 vLightmapCoord;
in vec4 vVertexColor;
in vec3 vPlayerNormal;

/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outLightmapData;
layout(location = 2) out vec4 outEncodedNormal;

void main() {
    vec4 albedo = texture2D(texture, vTexCoord) * vVertexColor;
    if (albedo.a < 0.1) discard;

    outColor = albedo;
    outLightmapData = vec4(vLightmapCoord, 0.0, 1.0);
    outEncodedNormal = vec4(normalize(vPlayerNormal) * 0.5 + 0.5, 1.0);
}
