#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform sampler2D depthtex2;

in vec2 vTexCoord;

/* RENDERTARGETS: 4 */
layout(location = 0) out vec4 outOpaqueSceneCopy;

void main() {
    // Iris truncates relative buffer dimensions (0.5 * source size). A 5-pixel
    // source therefore becomes 2 pixels, not 2.5. Integrate each destination
    // pixel's actual source-space footprint so odd viewport edges are retained.
    // The footprint spans at most three source texels per axis at half scale.
    ivec2 destinationPixel = ivec2(gl_FragCoord.xy);
    ivec2 destinationSize = textureSize(colortex4, 0);
    ivec2 sourceSize = textureSize(colortex0, 0);
    vec2 sourceStart = vec2(destinationPixel) * vec2(sourceSize) / vec2(destinationSize);
    vec2 sourceEnd = vec2(destinationPixel + ivec2(1)) * vec2(sourceSize) / vec2(destinationSize);
    ivec2 sourceBase = ivec2(floor(sourceStart));

    vec3 linearAccumulation = vec3(0.0);
    float validWeight = 0.0;
    float totalWeight = 0.0;

    // Fixed 3x3 bounds; zero-overlap taps are skipped. Even dimensions retain
    // the original four-fetch path, while odd dimensions cover their edge texels.
    for (int y = 0; y < 3; ++y) {
        for (int x = 0; x < 3; ++x) {
            ivec2 sourcePixel = sourceBase + ivec2(x, y);
            if (sourcePixel.x >= sourceSize.x || sourcePixel.y >= sourceSize.y) continue;

            vec2 pixelMinimum = vec2(sourcePixel);
            vec2 pixelMaximum = pixelMinimum + 1.0;
            vec2 overlap = max(
                min(sourceEnd, pixelMaximum) - max(sourceStart, pixelMinimum),
                vec2(0.0)
            );
            float sampleWeight = overlap.x * overlap.y;
            if (sampleWeight <= 0.0) continue;

            totalWeight += sampleWeight;
            float opaqueValidity = abs(
                texelFetch(depthtex0, sourcePixel, 0).r -
                texelFetch(depthtex2, sourcePixel, 0).r
            ) <= 0.000001 ? 1.0 : 0.0;
            if (opaqueValidity > 0.5) {
                vec3 sourceLinear = pow(
                    max(texelFetch(colortex0, sourcePixel, 0).rgb, vec3(0.0)),
                    vec3(2.2)
                );
                linearAccumulation += sourceLinear * sampleWeight;
                validWeight += sampleWeight;
            }
        }
    }

    vec3 linearAverage = linearAccumulation / max(validWeight, 0.000001);
    float validCoverage = validWeight / max(totalWeight, 0.000001);
    outOpaqueSceneCopy = vec4(
        pow(max(linearAverage, vec3(0.0)), vec3(1.0 / 2.2)),
        step(0.5, validCoverage)
    );
}
