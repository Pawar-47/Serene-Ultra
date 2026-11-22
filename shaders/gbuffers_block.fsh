#version 330 compatibility

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform float alphaTestRef;
uniform int blockEntityId;
uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform float fogDensity;
uniform int fogMode;
uniform int fogShape;

in vec2 vTexCoord;
in vec2 vLightmapCoord;
flat in vec4 vVertexColor;
in vec3 vPlayerNormal;
in vec3 vViewPosition;

/* RENDERTARGETS: 0,1,2,3 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outLightmapData;
layout(location = 2) out vec4 outEncodedNormal;
layout(location = 3) out vec4 outEmissionData;

float calculateBlockFog(float distanceToCamera) {
    if (fogMode == 9729) {
        return clamp((distanceToCamera - fogStart) / max(fogEnd - fogStart, 0.0001), 0.0, 1.0);
    }
    if (fogMode == 2048) {
        return clamp(1.0 - exp(-fogDensity * distanceToCamera), 0.0, 1.0);
    }
    if (fogMode == 2049) {
        float densityDistance = fogDensity * distanceToCamera;
        return clamp(1.0 - exp(-densityDistance * densityDistance), 0.0, 1.0);
    }
    return 0.0;
}

void main() {
    vec4 albedo = texture(gtexture, vTexCoord) * vVertexColor;
    if (albedo.a < alphaTestRef) discard;

    vec3 vanillaLight = texture(lightmap, vLightmapCoord).rgb;
    float skyLight = clamp(vLightmapCoord.y / (30.0 / 32.0) - (1.0 / 32.0), 0.0, 1.0);
    float emissionStrength = 0.0;

    // Sign text is already vertex-colored and should not inherit the wooden
    // sign's directional shading. Bypass deferred lighting and fog it here.
    bool signText = blockEntityId == 5004 &&
                    (dot(vVertexColor.rgb, vec3(1.0)) <= 2.99 || vLightmapCoord.x > 0.999);
    if (signText) {
        float fogDistance = (fogShape == 1) ? length(vViewPosition.xz) : length(vViewPosition);
        float fogFactor = calculateBlockFog(fogDistance);
        vec3 textLinear = pow(max(albedo.rgb, vec3(0.0)), vec3(2.2));
        vec3 fogLinear = pow(max(fogColor, vec3(0.0)), vec3(2.2));
        albedo.rgb = pow(max(mix(textLinear, fogLinear, fogFactor), vec3(0.0)), vec3(1.0 / 2.2));
        vanillaLight = vec3(0.0);
        skyLight = 0.0;
    }

    // End portal/gateway surfaces are emissive; keep their texture color out
    // of ambient AO and shadow attenuation in the deferred lighting stage.
    if (blockEntityId == 5025) {
        emissionStrength = 1.25;
    }

    outColor = albedo;
    outLightmapData = vec4(vanillaLight, skyLight);
    vec3 surfaceNormal = normalize(vPlayerNormal);
    if (!gl_FrontFacing) surfaceNormal = -surfaceNormal;
    outEncodedNormal = vec4(surfaceNormal * 0.5 + 0.5, signText ? 0.0 : 1.0);
    outEmissionData = vec4(emissionStrength / 5.0, 0.0, 0.0, 1.0);
}
