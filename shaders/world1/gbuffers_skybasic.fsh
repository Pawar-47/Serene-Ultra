#version 130

uniform int renderStage;
uniform float viewWidth;
uniform float viewHeight;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

in vec3 vVertexColorLinear;
in float vVertexAlpha;
flat in vec3 vFogLinear;
flat in vec3 vSkyLinear;

/* RENDERTARGETS: 0,2 */
out vec4 outColor0;
out vec4 outColor1;

vec3 reconstructPlayerDirection() {
    vec2 screenUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
    vec4 clipPosition = vec4(screenUV * 2.0 - 1.0, gl_FragCoord.z * 2.0 - 1.0, 1.0);
    vec4 viewPosition = gbufferProjectionInverse * clipPosition;
    vec3 viewRay = abs(viewPosition.w) > 0.00001
        ? viewPosition.xyz / viewPosition.w
        : viewPosition.xyz;
    vec3 playerRay = mat3(gbufferModelViewInverse) * viewRay;
    float rayLength = length(playerRay);
    return rayLength > 0.00001 ? playerRay / rayLength : vec3(0.0, 1.0, 0.0);
}

void main() {
    bool isSky = false;
    bool isSunset = false;
    bool isStars = false;
    bool isVoid = false;
#ifdef MC_RENDER_STAGE_SKY
    isSky = renderStage == MC_RENDER_STAGE_SKY;
#endif
#ifdef MC_RENDER_STAGE_SUNSET
    isSunset = renderStage == MC_RENDER_STAGE_SUNSET;
#endif
#ifdef MC_RENDER_STAGE_STARS
    isStars = renderStage == MC_RENDER_STAGE_STARS;
#endif
#ifdef MC_RENDER_STAGE_VOID
    isVoid = renderStage == MC_RENDER_STAGE_VOID;
#endif

    vec3 colorLinear = vVertexColorLinear;
    float alpha = vVertexAlpha;
    if (isVoid) {
        colorLinear = vec3(0.0);
        alpha = 1.0;
    } else if (isStars) {
        colorLinear *= vec3(0.62, 0.48, 0.92);
    } else if (isSky || isSunset) {
        vec3 ray = reconstructPlayerDirection();
        float horizon = 1.0 - smoothstep(-0.10, 0.48, ray.y);
        colorLinear = mix(vec3(0.006, 0.003, 0.018), vec3(0.105, 0.026, 0.16), horizon);
        colorLinear = mix(colorLinear, vFogLinear, 0.12);
        alpha = 1.0;
    }

    outColor0 = vec4(pow(max(colorLinear, vec3(0.0)), vec3(1.0 / 2.2)), alpha);
    outColor1 = vec4(0.0);
}
