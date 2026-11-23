// Atlas-bounded anisotropic sampling shared by forward translucent passes.
// The caller supplies the sprite rectangle from mc_midTexCoord and UV half-size.
// The major footprint axis is the principal eigenvector of the UV derivative
// covariance matrix, so oblique UV gradients are filtered along their true
// major axis instead of whichever screen derivative happens to be longer.
vec4 sampleAnisotropicAtlas(
    sampler2D sourceTexture,
    vec2 uv,
    vec2 uvDx,
    vec2 uvDy,
    vec4 spriteBounds
) {
#if ANISOTROPIC_FILTER_QUALITY > 1
    float xx = dot(uvDx, uvDx);
    float xy = dot(uvDx, uvDy);
    float yy = dot(uvDy, uvDy);
    float discriminant = sqrt(max((xx - yy) * (xx - yy) + 4.0 * xy * xy, 0.0));
    float majorEigenvalue = max(0.5 * (xx + yy + discriminant), 0.0);
    float minorEigenvalue = max(0.5 * (xx + yy - discriminant), 1e-12);
    float majorAngle = 0.5 * atan(2.0 * xy, xx - yy);
    vec2 majorAxisVector = uvDx * cos(majorAngle) + uvDy * sin(majorAngle);
    float majorAxisLength = length(majorAxisVector);
    vec2 majorDirection = majorAxisLength > 1e-7
        ? majorAxisVector / majorAxisLength : vec2(1.0, 0.0);
    float majorLength = sqrt(majorEigenvalue);
    float minorLength = sqrt(minorEigenvalue);
    int sampleCount = int(clamp(
        ceil(majorLength / max(minorLength, 1e-6)),
        1.0, float(ANISOTROPIC_FILTER_QUALITY)
    ));
    if (sampleCount <= 1) return textureGrad(sourceTexture, uv, uvDx, uvDy);

    vec2 atlasTexel = 1.0 / vec2(textureSize(sourceTexture, 0));
    vec2 tileSize = max(spriteBounds.zw, vec2(1e-7));
    vec2 lowerBound = spriteBounds.xy + 0.5 * atlasTexel;
    vec2 upperBound = spriteBounds.xy + tileSize - 0.5 * atlasTexel;
    vec2 majorFootprint = majorDirection * majorLength;
    vec4 accumulated = vec4(0.0);
    for (int tap = 0; tap < ANISOTROPIC_FILTER_QUALITY; ++tap) {
        if (tap >= sampleCount) break;
        float tapOffset = (float(tap) + 0.5) / float(sampleCount) - 0.5;
        vec2 sampleUv = clamp(
            uv + majorFootprint * tapOffset, lowerBound, upperBound
        );
        accumulated += textureGrad(sourceTexture, sampleUv, uvDx, uvDy);
    }
    return accumulated / float(sampleCount);
#else
    return textureGrad(sourceTexture, uv, uvDx, uvDy);
#endif
}
