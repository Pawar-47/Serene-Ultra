#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform sampler2DShadow shadowtex0;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 shadowLightPosition;
uniform float sunAngle;

in vec2 vTexCoord;

// Screen-space contact occlusion controls. AO attenuates ambient light only;
// direct sun/moon lighting and emissive/block-light contribution are retained.
#define AO_STRENGTH 0.65 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00] Contact occlusion strength
#define AO_RADIUS 1.25 // [0.50 0.75 1.00 1.25 1.50 1.75 2.00 2.50 3.00] Contact occlusion radius in blocks

// Deferred reads colortex0 and writes a different attachment. Composite later
// copies colortex3 back to colortex0, avoiding read/write feedback on one image.
/* RENDERTARGETS: 3 */
layout(location = 0) out vec4 outColor;

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position) {
    vec4 homogeneous = projectionMatrix * vec4(position, 1.0);
    return homogeneous.xyz / homogeneous.w;
}

float sampleShadow(vec3 playerPosition, vec3 normal, vec3 worldLightDirection) {
    vec4 shadowViewPosition = shadowModelView * vec4(playerPosition, 1.0);
    vec4 shadowClipPosition = shadowProjection * shadowViewPosition;

    float normalLight = max(dot(normal, worldLightDirection), 0.0);
    float depthBias = mix(0.0022, 0.00065, normalLight);
    shadowClipPosition.z -= depthBias;

    vec3 shadowNdc = shadowClipPosition.xyz / shadowClipPosition.w;
    vec3 shadowPosition = shadowNdc * 0.5 + 0.5;

    if (shadowPosition.x <= 0.0 || shadowPosition.x >= 1.0 ||
        shadowPosition.y <= 0.0 || shadowPosition.y >= 1.0 ||
        shadowPosition.z <= 0.0 || shadowPosition.z >= 1.0) {
        return 1.0;
    }

    // Four hardware-filtered comparison taps provide a wider soft edge
    // without a large software PCF kernel on the Intel HD target.
    vec2 texel = 1.0 / vec2(textureSize(shadowtex0, 0));
    float visibility = 0.0;
    visibility += texture(shadowtex0, vec3(shadowPosition.xy + texel * vec2(-0.5, -0.5), shadowPosition.z));
    visibility += texture(shadowtex0, vec3(shadowPosition.xy + texel * vec2( 0.5, -0.5), shadowPosition.z));
    visibility += texture(shadowtex0, vec3(shadowPosition.xy + texel * vec2(-0.5,  0.5), shadowPosition.z));
    visibility += texture(shadowtex0, vec3(shadowPosition.xy + texel * vec2( 0.5,  0.5), shadowPosition.z));
    return visibility * 0.25;
}

float sampleContactAO(vec3 viewPosition, vec3 viewNormal) {
    const vec2 samplePattern[8] = vec2[8](
        vec2(-1.0, -1.0), vec2( 0.0, -1.0),
        vec2( 1.0, -1.0), vec2( 1.0,  0.0),
        vec2( 1.0,  1.0), vec2( 0.0,  1.0),
        vec2(-1.0,  1.0), vec2(-1.0,  0.0)
    );

    vec2 texelSize = 1.0 / vec2(textureSize(depthtex0, 0));
    float occlusion = 0.0;
    float validSamples = 0.0;

    for (int i = 0; i < 8; ++i) {
        vec2 sampleUV = vTexCoord + samplePattern[i] * texelSize * 2.0;
        if (sampleUV.x <= 0.0 || sampleUV.x >= 1.0 ||
            sampleUV.y <= 0.0 || sampleUV.y >= 1.0) {
            continue;
        }

        float sampleDepth = texture(depthtex0, sampleUV).r;
        if (sampleDepth >= 0.999999) {
            continue;
        }

        vec3 sampleNdc = vec3(sampleUV, sampleDepth) * 2.0 - 1.0;
        vec3 sampleViewPosition = projectAndDivide(gbufferProjectionInverse, sampleNdc);
        vec3 delta = sampleViewPosition - viewPosition;
        float distanceToSample = length(delta);

        if (distanceToSample < 0.0001 || distanceToSample >= AO_RADIUS) {
            continue;
        }

        vec3 sampleDirection = delta / distanceToSample;
        float facing = max(dot(viewNormal, sampleDirection), 0.0);
        float nearerSurface = step(viewPosition.z + 0.015, sampleViewPosition.z);
        float distanceWeight = 1.0 - smoothstep(AO_RADIUS * 0.35, AO_RADIUS, distanceToSample);

        occlusion += facing * nearerSurface * distanceWeight;
        validSamples += 1.0;
    }

    float normalizedOcclusion = occlusion / max(validSamples, 1.0);
    return clamp(1.0 - normalizedOcclusion * AO_STRENGTH * 1.8, 0.55, 1.0);
}

void main() {
    vec4 scene = texture(colortex0, vTexCoord);
    float depth = texture(depthtex0, vTexCoord).r;
    vec4 normalData = texture(colortex2, vTexCoord);

    // Sky and first-person hand do not have world G-buffer normals. Preserve
    // them exactly rather than applying world lighting to undefined data.
    if (depth >= 0.999999 || normalData.a < 0.5) {
        outColor = scene;
        return;
    }

    vec4 lightData = texture(colortex1, vTexCoord);
    vec3 normal = normalize(normalData.rgb * 2.0 - 1.0);

    vec3 ndcPosition = vec3(vTexCoord, depth) * 2.0 - 1.0;
    vec3 viewPosition = projectAndDivide(gbufferProjectionInverse, ndcPosition);
    vec3 playerPosition = (gbufferModelViewInverse * vec4(viewPosition, 1.0)).xyz;
    vec3 viewNormal = normalize(transpose(mat3(gbufferModelViewInverse)) * normal);

    vec3 viewLightDirection = normalize(shadowLightPosition);
    vec3 worldLightDirection = normalize(mat3(gbufferModelViewInverse) * viewLightDirection);
    float nDotL = max(dot(normal, worldLightDirection), 0.0);
    float shadow = sampleShadow(playerPosition, normal, worldLightDirection);

    float skyLight = clamp(lightData.a, 0.0, 1.0);
    // Iris sunAngle: 0=dawn, 0.25=noon, 0.5=sunset, 0.75=midnight.
    // The sine curve wraps continuously through dawn and keeps the night side at zero.
    float solarElevation = sin(sunAngle * 6.28318530718);
    float dayFactor = smoothstep(0.0, 0.30, solarElevation);

    // Use Minecraft's own sampled lightmap RGB as the ambient/block-light
    // foundation so its existing colored light response is retained.
    vec3 vanillaAmbient = pow(max(lightData.rgb, vec3(0.0)), vec3(2.2));
    vec3 ambient = vec3(0.018) + vanillaAmbient * 0.72;

    // Eight depth taps add local contact shading. Only ambient light is
    // occluded, so direct celestial illumination is not unnaturally darkened.
    float contactAO = sampleContactAO(viewPosition, viewNormal);
    ambient *= contactAO;

    vec3 celestialColor = mix(vec3(0.36, 0.44, 0.68), vec3(1.0, 0.94, 0.82), dayFactor);
    float celestialIntensity = mix(0.10, 0.70, dayFactor);
    vec3 direct = celestialColor * celestialIntensity * nDotL * shadow * skyLight;

    // Decode sampled sRGB albedo for lighting, then encode it again for the
    // existing color-grading/final pass. This keeps the output contract intact.
    vec3 albedoLinear = pow(max(scene.rgb, vec3(0.0)), vec3(2.2));
    vec3 litLinear = albedoLinear * (ambient + direct);
    vec3 litColor = pow(max(litLinear, vec3(0.0)), vec3(1.0 / 2.2));

    outColor = vec4(litColor, scene.a);
}
