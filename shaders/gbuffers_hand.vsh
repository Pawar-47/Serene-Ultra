#version 330 compatibility

in vec4 at_tangent;

out vec2 vTexCoord;
out vec2 vLightmapCoord;
out vec4 vVertexColor;
out vec3 vViewPosition;
out vec3 vViewNormal;
out vec3 vViewTangent;
out vec3 vViewBitangent;

void main() {
    gl_Position = ftransform();
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vVertexColor = gl_Color;

    vec3 viewNormal = normalize(gl_NormalMatrix * gl_Normal);
    vec3 tangentCandidate = gl_NormalMatrix * at_tangent.xyz;
    tangentCandidate -= viewNormal * dot(tangentCandidate, viewNormal);
    if (dot(tangentCandidate, tangentCandidate) < 0.000001) {
        vec3 helperAxis = abs(viewNormal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
        tangentCandidate = cross(helperAxis, viewNormal);
    }
    vec3 viewTangent = normalize(tangentCandidate);
    float tangentHandedness = at_tangent.w < 0.0 ? -1.0 : 1.0;
    vec3 bitangentCandidate = gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * tangentHandedness;
    bitangentCandidate -= viewNormal * dot(bitangentCandidate, viewNormal);
    if (dot(bitangentCandidate, bitangentCandidate) < 0.000001) {
        bitangentCandidate = cross(viewTangent, viewNormal) * tangentHandedness;
    }

    vViewPosition = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vViewNormal = viewNormal;
    vViewTangent = viewTangent;
    vViewBitangent = normalize(bitangentCandidate);
}
