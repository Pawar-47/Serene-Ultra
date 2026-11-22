#version 330 compatibility

uniform sampler2D gtexture;
uniform float alphaTestRef;
uniform int renderStage;
uniform int isEyeInWater;
uniform float rainStrength;
uniform bool hasSkylight;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform mat4 gbufferModelView;

in vec2 vTexCoord;
flat in vec4 vVertexColor;
in vec3 vViewPosition;

/* RENDERTARGETS: 0,2 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outDeferredValidity;

void main() {
    vec4 skyTexture = texture(gtexture, vTexCoord) * vVertexColor;
    if (skyTexture.a < alphaTestRef) discard;

    vec3 colorLinear = pow(max(skyTexture.rgb, vec3(0.0)), vec3(2.2));
    vec3 upVector = normalize(gbufferModelView[1].xyz);
    float sunElevation = dot(normalize(sunPosition), upVector);
    float moonElevation = dot(normalize(moonPosition), upVector);

    bool isSun = false;
    bool isMoon = false;
    #ifdef MC_RENDER_STAGE_SUN
        isSun = (renderStage == MC_RENDER_STAGE_SUN);
    #endif
    #ifdef MC_RENDER_STAGE_MOON
        isMoon = (renderStage == MC_RENDER_STAGE_MOON);
    #endif

    if (hasSkylight && isSun) {
        float sunVisibility = smoothstep(0.0, 0.35, sunElevation);
        vec3 horizonSun = vec3(1.0, 0.48, 0.22);
        vec3 noonSun = vec3(1.0, 0.92, 0.78);
        colorLinear *= mix(horizonSun, noonSun, sunVisibility);
        colorLinear *= 0.45 + 0.55 * sunVisibility;
        skyTexture.a *= 1.0 - 0.8 * rainStrength;
    } else if (hasSkylight && isMoon) {
        float moonVisibility = smoothstep(-0.1, 0.2, moonElevation);
        colorLinear *= vec3(0.68, 0.75, 0.95) * (0.75 + 0.25 * moonVisibility);
        skyTexture.a *= 1.0 - 0.8 * rainStrength;
    }

    if (isEyeInWater == 1 && (isSun || isMoon)) {
        colorLinear *= 0.25;
    }

    skyTexture.rgb = pow(max(colorLinear, vec3(0.0)), vec3(1.0 / 2.2));
    outColor = skyTexture;
    // Sky textures are background overlays, not deferred-lit world surfaces.
    outDeferredValidity = vec4(0.0);
}
