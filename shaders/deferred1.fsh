#version 330 compatibility

uniform sampler2D colortex0;

in vec2 vTexCoord;

/* RENDERTARGETS: 4 */
layout(location = 0) out vec4 outOpaqueSceneCopy;

void main() {
    // Iris executes deferred1 after deferred and before translucent gbuffers.
    // colortex4 is half resolution, so explicitly box-filter the four source
    // pixels covered by this destination pixel. This keeps the water refraction
    // copy compact for low-bandwidth GPUs without reading/writing one attachment.
    ivec2 destinationPixel = ivec2(gl_FragCoord.xy);
    ivec2 sourceBase = destinationPixel * 2;
    ivec2 sourceMax = textureSize(colortex0, 0) - ivec2(1);

    vec4 color00 = texelFetch(colortex0, min(sourceBase, sourceMax), 0);
    vec4 color10 = texelFetch(colortex0, min(sourceBase + ivec2(1, 0), sourceMax), 0);
    vec4 color01 = texelFetch(colortex0, min(sourceBase + ivec2(0, 1), sourceMax), 0);
    vec4 color11 = texelFetch(colortex0, min(sourceBase + ivec2(1, 1), sourceMax), 0);

    outOpaqueSceneCopy = (color00 + color10 + color01 + color11) * 0.25;
}
