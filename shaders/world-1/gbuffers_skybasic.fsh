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

#define NETHER_STORM_STRENGTH 45 // [0 10 25 40 55 70 85 100] Animated Nether ember storms

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


vec3 calculateNetherStorm(vec3 ray) {
#if NETHER_STORM_STRENGTH > 0
    float azimuth = atan(ray.z, ray.x);
    float elevation = asin(clamp(ray.y, -1.0, 1.0));
    vec2 stormUv = vec2(azimuth * 0.15915494 + 0.5, elevation * 0.31830989 + 0.5);
    stormUv = stormUv * vec2(8.0, 3.5)
        + vec2(frameTimeCounter * 0.0018, -frameTimeCounter * 0.00055);
    float broad = texture2D(noisetex, stormUv).r;
    float detail = texture2D(noisetex, stormUv * 3.7 + vec2(0.29, 0.61)).g;
    float stormNoise = broad * 0.65 + detail * 0.35;
    float stormCloud = smoothstep(0.52, 0.82, stormNoise)
        * smoothstep(0.04, 0.22, ray.y)
        * (1.0 - smoothstep(0.72, 0.94, ray.y));
    float emberPulse = pow(max(sin(frameTimeCounter * 0.72 + stormNoise * 9.0), 0.0), 12.0);
    vec3 stormColor = mix(
        vec3(0.12, 0.012, 0.003),
        vec3(1.0, 0.18, 0.025),
        clamp(detail * 0.8 + emberPulse * 0.4, 0.0, 1.0)
    );
    return stormColor * stormCloud
        * (float(NETHER_STORM_STRENGTH) * 0.0025);
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
        colorLinear *= vec3(0.20, 0.08, 0.06);
    } else if (isSky || isSunset) {
        vec3 ray = reconstructPlayerDirection();
        float horizon = 1.0 - smoothstep(-0.10, 0.48, ray.y);
        colorLinear = mix(vec3(0.018, 0.004, 0.006), vec3(0.22, 0.045, 0.012), horizon);
        colorLinear = mix(colorLinear, vFogLinear, 0.12);
        colorLinear += calculateNetherStorm(ray);
        alpha = 1.0;
    }

    outColor0 = vec4(pow(max(colorLinear, vec3(0.0)), vec3(1.0 / 2.2)), alpha);
    outColor1 = vec4(0.0);
}
