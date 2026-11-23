#version 130

uniform int renderStage;
uniform float viewWidth;
uniform float viewHeight;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform sampler2D noisetex;
uniform float frameTimeCounter;

in vec3 vVertexColorLinear;
in float vVertexAlpha;
flat in vec3 vFogLinear;
flat in vec3 vSkyLinear;

/* RENDERTARGETS: 0,2 */
out vec4 outColor0;
out vec4 outColor1;

#define END_NEBULA_STRENGTH 55 // [0 10 25 40 55 70 85 100] End dimension nebulae

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


vec3 calculateEndNebula(vec3 ray) {
#if END_NEBULA_STRENGTH > 0
    float azimuth = atan(ray.z, ray.x);
    float elevation = asin(clamp(ray.y, -1.0, 1.0));
    vec2 nebulaUv = vec2(azimuth * 0.15915494 + 0.5, elevation * 0.31830989 + 0.5);
    nebulaUv = nebulaUv * vec2(5.0, 8.0)
        + vec2(frameTimeCounter * 0.00016, -frameTimeCounter * 0.00008);
    float broad = texture2D(noisetex, nebulaUv).r;
    float detail = texture2D(noisetex, nebulaUv * 2.9 + vec2(0.37, 0.21)).g;
    float nebulaMask = smoothstep(0.48, 0.78, broad * 0.7 + detail * 0.3)
        * smoothstep(-0.08, 0.25, ray.y);
    vec3 nebulaColor = mix(
        vec3(0.12, 0.025, 0.30),
        vec3(0.025, 0.24, 0.40),
        smoothstep(0.3, 0.8, detail)
    );
    float distantStars = pow(max(texture2D(noisetex, nebulaUv * 17.0).b - 0.86, 0.0), 3.0);
    return (nebulaColor * nebulaMask + vec3(0.45, 0.55, 0.95) * distantStars)
        * (float(END_NEBULA_STRENGTH) * 0.0022);
#else
    return vec3(0.0);
#endif
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
        colorLinear += calculateEndNebula(ray);
        alpha = 1.0;
    }

    outColor0 = vec4(pow(max(colorLinear, vec3(0.0)), vec3(1.0 / 2.2)), alpha);
    outColor1 = vec4(0.0);
}
