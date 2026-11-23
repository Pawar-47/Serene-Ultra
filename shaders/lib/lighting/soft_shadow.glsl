// Shared soft shadow filtering for deferred and forward translucent programs.
// The caller declares shadowtex0/1, shadowcolor0, shadowModelView and shadowProjection.
vec3 sampleSereneSoftShadow(
    vec3 playerPosition,
    vec3 normal,
    vec3 lightDirection
) {
    vec4 shadowViewPosition = shadowModelView * vec4(playerPosition, 1.0);
    vec4 shadowClipPosition = shadowProjection * shadowViewPosition;
    if (abs(shadowClipPosition.w) < 0.00001) return vec3(1.0);

    float normalLight = max(dot(normal, lightDirection), 0.0);
    shadowClipPosition.z -= mix(0.0022, 0.00065, normalLight);
    vec3 shadowNdc = shadowClipPosition.xyz / shadowClipPosition.w;
    vec3 shadowPosition = shadowNdc * 0.5 + 0.5;
    if (shadowPosition.x <= 0.0 || shadowPosition.x >= 1.0 ||
        shadowPosition.y <= 0.0 || shadowPosition.y >= 1.0 ||
        shadowPosition.z <= 0.0 || shadowPosition.z >= 1.0) {
        return vec3(1.0);
    }

    const vec2 poissonDisk[12] = vec2[12](
        vec2(-0.326, -0.406), vec2( 0.326,  0.406),
        vec2(-0.840, -0.074), vec2( 0.840,  0.074),
        vec2(-0.696,  0.457), vec2( 0.696, -0.457),
        vec2(-0.203,  0.621), vec2( 0.203, -0.621),
        vec2( 0.962, -0.195), vec2(-0.962,  0.195),
        vec2( 0.473, -0.480), vec2(-0.473,  0.480)
    );
    vec2 texel = 1.0 / vec2(textureSize(shadowtex0, 0));
    float noise = fract(
        52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715)))
    );
    float angle = noise * 6.28318530718;
    float sineAngle = sin(angle);
    float cosineAngle = cos(angle);
    mat2 rotation = mat2(cosineAngle, -sineAngle, sineAngle, cosineAngle);
    float filterRadius = 2.0 * mix(0.75, 1.75, 1.0 - normalLight);
    float visibility = 0.0;

    for (int i = 0; i < SHADOW_FILTER_QUALITY; ++i) {
        vec2 offset = rotation * poissonDisk[i] * texel * filterRadius;
        vec2 sampleUV = shadowPosition.xy + offset;
        // Outside the shadow atlas is unoccluded; do not smear edge texels inward.
        if (sampleUV.x <= 0.0 || sampleUV.x >= 1.0 ||
            sampleUV.y <= 0.0 || sampleUV.y >= 1.0) {
            visibility += 1.0;
        } else {
            visibility += texture(shadowtex0, vec3(sampleUV, shadowPosition.z));
        }
    }
    visibility /= float(SHADOW_FILTER_QUALITY);

    // shadowtex1 excludes translucent casters; shadowcolor0 stores their RGB
    // transmission and opacity. Preserve the same coloured-shadow response in
    // deferred, water, translucent entities/block entities and particles.
    float centerShadow0 = texture(shadowtex0, vec3(shadowPosition.xy, shadowPosition.z));
    float centerShadow1 = texture(shadowtex1, vec3(shadowPosition.xy, shadowPosition.z));
    if (centerShadow1 > centerShadow0 + 0.5) {
        vec4 casterColor = texture(shadowcolor0, shadowPosition.xy);
        vec3 transmission = casterColor.rgb * (1.0 - casterColor.a);
        return clamp(
            mix(vec3(visibility), transmission * centerShadow1, 1.0 - visibility),
            vec3(0.0), vec3(1.0)
        );
    }
    return vec3(clamp(visibility, 0.0, 1.0));
}
