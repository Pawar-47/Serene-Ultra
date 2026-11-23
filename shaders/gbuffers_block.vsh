#version 330 compatibility

in vec4 at_tangent;
in vec2 mc_midTexCoord;

uniform mat4 gbufferModelViewInverse;
uniform int blockEntityId;
uniform vec3 cameraPositionFract;

out vec2 vTexCoord;
out vec2 vLightmapCoord;
flat out vec4 vVertexColor;
out vec3 vPlayerNormal;
out vec3 vPlayerTangent;
out vec3 vTangentView;
flat out vec4 vTexCoordAM;
flat out float vTangentHandedness;
out vec3 vViewPosition;
out vec3 vPlayerPosition;

void main() {
    gl_Position = ftransform();
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vVertexColor = gl_Color;

    vec4 viewPosition = gl_ModelViewMatrix * gl_Vertex;
    vViewPosition = viewPosition.xyz;
    vPlayerPosition = (gbufferModelViewInverse * viewPosition).xyz;

    // Complementary chest seam correction, using Iris' split camera position
    // so the fractional world height remains stable at large coordinates.
    if (blockEntityId == 5008) {
        float fractWorldPosY = fract(vPlayerPosition.y + cameraPositionFract.y);
        if (fractWorldPosY > 0.56 && fractWorldPosY < 0.57) {
            gl_Position.z -= 0.0001;
        }
    }
    vec3 viewNormal = normalize(gl_NormalMatrix * normalize(gl_Normal));
    vPlayerNormal = normalize(mat3(gbufferModelViewInverse) * viewNormal);
    vec3 viewTangent = normalize(gl_NormalMatrix * normalize(at_tangent.xyz));
    vPlayerTangent = normalize(mat3(gbufferModelViewInverse) * viewTangent);
    vec3 viewBitangent = normalize(cross(viewTangent, viewNormal))
        * (at_tangent.w < 0.0 ? -1.0 : 1.0);
    vTangentView = vec3(
        dot(viewTangent, viewPosition.xyz),
        dot(viewBitangent, viewPosition.xyz),
        dot(viewNormal, viewPosition.xyz)
    );

    // Iris mc_midTexCoord is the per-quad sprite centre. Preserve atlas bounds
    // so block-entity POM cannot sample adjacent texture sprites.
    vec2 midTexCoord = (gl_TextureMatrix[0] * vec4(mc_midTexCoord, 0.0, 1.0)).st;
    vec2 texMinMidCoord = vTexCoord - midTexCoord;
    vTexCoordAM = vec4(
        min(vTexCoord, midTexCoord - texMinMidCoord),
        abs(texMinMidCoord) * 2.0
    );
    vTangentHandedness = at_tangent.w < 0.0 ? -1.0 : 1.0;
}
