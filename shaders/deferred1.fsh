#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform sampler2D depthtex2;

in vec2 vTexCoord;

/* RENDERTARGETS: 4 */
layout(location = 0) out vec4 outOpaqueSceneCopy;

void main() {
    // Iris executes deferred1 after deferred and before translucent gbuffers.
    // colortex4 is half resolution, so explicitly box-filter the four source
    // pixels covered by this destination pixel. Downsample RGB in linear
    // space, then re-encode to match the scene-color buffer contract.
    ivec2 destinationPixel = ivec2(gl_FragCoord.xy);
    ivec2 sourceBase = destinationPixel * 2;
    ivec2 sourceMax = textureSize(colortex0, 0) - ivec2(1);

    ivec2 pixel00 = min(sourceBase, sourceMax);
    ivec2 pixel10 = min(sourceBase + ivec2(1, 0), sourceMax);
    ivec2 pixel01 = min(sourceBase + ivec2(0, 1), sourceMax);
    ivec2 pixel11 = min(sourceBase + ivec2(1, 1), sourceMax);

    vec4 color00 = texelFetch(colortex0, pixel00, 0);
    vec4 color10 = texelFetch(colortex0, pixel10, 0);
    vec4 color01 = texelFetch(colortex0, pixel01, 0);
    vec4 color11 = texelFetch(colortex0, pixel11, 0);

    // depthtex0 includes hand/translucent depth; depthtex2 excludes both.
    // Average only valid opaque/sky samples so hand pixels do not contaminate
    // the low-resolution scene copy used by forward water.
    float valid00 = abs(texelFetch(depthtex0, pixel00, 0).r - texelFetch(depthtex2, pixel00, 0).r) <= 0.000001 ? 1.0 : 0.0;
    float valid10 = abs(texelFetch(depthtex0, pixel10, 0).r - texelFetch(depthtex2, pixel10, 0).r) <= 0.000001 ? 1.0 : 0.0;
    float valid01 = abs(texelFetch(depthtex0, pixel01, 0).r - texelFetch(depthtex2, pixel01, 0).r) <= 0.000001 ? 1.0 : 0.0;
    float valid11 = abs(texelFetch(depthtex0, pixel11, 0).r - texelFetch(depthtex2, pixel11, 0).r) <= 0.000001 ? 1.0 : 0.0;

    float validCount = valid00 + valid10 + valid01 + valid11;
    vec3 linearAverage = (
        pow(max(color00.rgb, vec3(0.0)), vec3(2.2)) * valid00 +
        pow(max(color10.rgb, vec3(0.0)), vec3(2.2)) * valid10 +
        pow(max(color01.rgb, vec3(0.0)), vec3(2.2)) * valid01 +
        pow(max(color11.rgb, vec3(0.0)), vec3(2.2)) * valid11
    ) / max(validCount, 1.0);

    outOpaqueSceneCopy = vec4(
        pow(max(linearAverage, vec3(0.0)), vec3(1.0 / 2.2)),
        step(0.5, validCount)
    );
}
