#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform float viewWidth;
uniform float viewHeight;

in vec2 vTexCoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

#define MOTION_BLUR_STRENGTH 0 // [0 5 10 15 20 25 30 40 50 60 75 100] Camera-motion blur strength
#define MOTION_BLUR_QUALITY 4 // [0 4 6 8] Camera-motion blur samples

float linearViewDepth(vec2 uv) {
    float depth = texture(depthtex0, uv).r;
    if (depth >= 0.999999) return 10000.0;
    vec4 viewPosition = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    return abs(viewPosition.z / max(abs(viewPosition.w), 0.000001));
}

vec2 previousFrameUv(vec2 uv, float depth) {
    vec4 currentClip = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 currentView = gbufferProjectionInverse * currentClip;
    vec4 previousClip;

    if (depth >= 0.999999) {
        vec3 currentRay = normalize(currentView.xyz / max(abs(currentView.w), 0.000001));
        vec3 playerRay = normalize(mat3(gbufferModelViewInverse) * currentRay);
        vec3 previousViewRay = normalize(mat3(gbufferPreviousModelView) * playerRay);
        previousClip = gbufferPreviousProjection * vec4(previousViewRay, 0.0);
    } else {
        vec3 playerPosition = (gbufferModelViewInverse * currentView).xyz / max(abs(currentView.w), 0.000001);
        vec3 previousPlayerPosition = playerPosition + cameraPosition - previousCameraPosition;
        vec4 previousViewPosition = gbufferPreviousModelView * vec4(previousPlayerPosition, 1.0);
        previousClip = gbufferPreviousProjection * previousViewPosition;
    }

    if (previousClip.w <= 0.0001) return uv;
    return previousClip.xy / previousClip.w * 0.5 + 0.5;
}

// Camera-motion blur for static world geometry. Depth-aware gathering limits
// foreground/background bleeding; per-object velocity is not exposed here.
vec3 cameraMotionBlur(vec2 uv, vec3 centerColor) {
#if MOTION_BLUR_STRENGTH > 0 && MOTION_BLUR_QUALITY > 0
    float rawDepth = texture(depthtex0, uv).r;
    vec2 oldUv = previousFrameUv(uv, rawDepth);
    vec2 motion = (uv - oldUv) * (float(MOTION_BLUR_STRENGTH) * 0.01);
    if (length(motion) < (1.0 / max(viewWidth, viewHeight)) * 0.75) return centerColor;

    motion = clamp(motion, vec2(-0.035), vec2(0.035));
    float centerDepth = linearViewDepth(uv);
    float depthTolerance = max(0.08, centerDepth * 0.02);
    vec3 accumulated = centerColor * 2.0;
    float totalWeight = 2.0;

    for (int i = 0; i < MOTION_BLUR_QUALITY; ++i) {
        float alongMotion = (float(i) + 0.5) / float(MOTION_BLUR_QUALITY) - 0.5;
        vec2 sampleUv = clamp(uv - motion * alongMotion, vec2(0.001), vec2(0.999));
        float sampleDepth = linearViewDepth(sampleUv);
        float depthWeight = exp(-abs(sampleDepth - centerDepth) / depthTolerance);
        accumulated += texture(colortex0, sampleUv).rgb * depthWeight;
        totalWeight += depthWeight;
    }
    return accumulated / max(totalWeight, 0.0001);
#else
    return centerColor;
#endif
}

void main() {
    vec4 scene = texture(colortex0, vTexCoord);
#if MOTION_BLUR_STRENGTH > 0 && MOTION_BLUR_QUALITY > 0
    outColor = vec4(cameraMotionBlur(vTexCoord, scene.rgb), scene.a);
#else
    outColor = scene;
#endif
}
