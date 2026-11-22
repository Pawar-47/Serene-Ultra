#version 330 compatibility

uniform sampler2D colortex0;

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

    vec4 color00 = texelFetch(colortex0, min(sourceBase, sourceMax), 0);
    vec4 color10 = texelFetch(colortex0, min(sourceBase + ivec2(1, 0), sourceMax), 0);
    vec4 color01 = texelFetch(colortex0, min(sourceBase + ivec2(0, 1), sourceMax), 0);
    vec4 color11 = texelFetch(colortex0, min(sourceBase + ivec2(1, 1), sourceMax), 0);

    vec3 linearAverage = (
        pow(max(color00.rgb, vec3(0.0)), vec3(2.2)) +
        pow(max(color10.rgb, vec3(0.0)), vec3(2.2)) +
        pow(max(color01.rgb, vec3(0.0)), vec3(2.2)) +
        pow(max(color11.rgb, vec3(0.0)), vec3(2.2))
    ) * 0.25;
    float alphaAverage = (color00.a + color10.a + color01.a + color11.a) * 0.25;

    outOpaqueSceneCopy = vec4(
        pow(max(linearAverage, vec3(0.0)), vec3(1.0 / 2.2)),
        alphaAverage
    );
}
