// Atlas-bounded anisotropic sampling shared by forward translucent passes.
// The caller supplies the sprite rectangle from mc_midTexCoord and UV half-size.
vec4 sampleAnisotropicAtlas(
    sampler2D sourceTexture,
    vec2 uv,
    vec2 uvDx,
    vec2 uvDy,
    vec4 spriteBounds
) {
#if ANISOTROPIC_FILTER_QUALITY > 1
    vec2 majorGradient = dot(uvDx, uvDx) >= dot(uvDy, uvDy)
        ? uvDx : uvDy;
    float majorLength = length(majorGradient);
    float minorLength = max(min(length(uvDx), length(uvDy)), 0.000001);
    int sampleCount = int(clamp(
        ceil(majorLength / minorLength),
        1.0, float(ANISOTROPIC_FILTER_QUALITY)
    ));
    if (sampleCount <= 1) return textureGrad(sourceTexture, uv, uvDx, uvDy);

    vec2 atlasTexel = 1.0 / vec2(textureSize(sourceTexture, 0));
    vec2 tileSize = max(spriteBounds.zw, vec2(1e-7));
    vec2 lowerBound = spriteBounds.xy + 0.5 * atlasTexel;
    vec2 upperBound = spriteBounds.xy + tileSize - 0.5 * atlasTexel;
    vec4 accumulated = vec4(0.0);
    for (int tap = 0; tap < ANISOTROPIC_FILTER_QUALITY; ++tap) {
        if (tap >= sampleCount) break;
        float tapOffset = (float(tap) + 0.5) / float(sampleCount) - 0.5;
        vec2 sampleUv = clamp(uv + majorGradient * tapOffset, lowerBound, upperBound);
        accumulated += textureGrad(sourceTexture, sampleUv, uvDx, uvDy);
    }
    return accumulated / float(sampleCount);
#else
    return textureGrad(sourceTexture, uv, uvDx, uvDy);
#endif
}
