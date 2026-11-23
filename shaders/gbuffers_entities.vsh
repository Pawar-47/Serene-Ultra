#version 330 compatibility

in vec4 at_tangent;
in vec2 mc_midTexCoord;

uniform mat4 gbufferModelViewInverse;

out vec2 vTexCoord;
out vec2 vLightmapCoord;
out vec4 vVertexColor;
out vec3 vPlayerNormal;
out vec3 vPlayerTangent;
out vec3 vTangentView;
out vec3 vPlayerPosition;
flat out vec4 vTexCoordAM;
flat out float vTangentHandedness;

void main() {
    gl_Position = ftransform();
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vVertexColor = gl_Color;

    vec3 viewNormal = normalize(gl_NormalMatrix * normalize(gl_Normal));
    vPlayerNormal = normalize(mat3(gbufferModelViewInverse) * viewNormal);
    vec3 viewTangent = normalize(gl_NormalMatrix * normalize(at_tangent.xyz));
    vPlayerTangent = normalize(mat3(gbufferModelViewInverse) * viewTangent);
    vec4 viewPosition = gl_ModelViewMatrix * gl_Vertex;
    vPlayerPosition = (gbufferModelViewInverse * viewPosition).xyz;
    vec3 viewBitangent = normalize(cross(viewTangent, viewNormal))
        * (at_tangent.w < 0.0 ? -1.0 : 1.0);
    vTangentView = vec3(dot(viewTangent, viewPosition.xyz),
                        dot(viewBitangent, viewPosition.xyz),
                        dot(viewNormal, viewPosition.xyz));
    vec2 midTexCoord = (gl_TextureMatrix[0] * vec4(mc_midTexCoord, 0.0, 1.0)).st;
    vec2 texMinMidCoord = vTexCoord - midTexCoord;
    vTexCoordAM = vec4(min(vTexCoord, midTexCoord - texMinMidCoord),
                       abs(texMinMidCoord) * 2.0);
    vTangentHandedness = at_tangent.w < 0.0 ? -1.0 : 1.0;
}
