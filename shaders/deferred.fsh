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

/* RENDERTARGETS: 0 */
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

    vec3 viewLightDirection = normalize(shadowLightPosition);
    vec3 worldLightDirection = normalize(mat3(gbufferModelViewInverse) * viewLightDirection);
    float nDotL = max(dot(normal, worldLightDirection), 0.0);
    float shadow = sampleShadow(playerPosition, normal, worldLightDirection);

    float skyLight = clamp(lightData.a, 0.0, 1.0);
    float dayFactor = 1.0 - smoothstep(0.45, 0.55, sunAngle);

    // Use Minecraft's own sampled lightmap RGB as the ambient/block-light
    // foundation so its existing colored light response is retained.
    vec3 vanillaAmbient = pow(max(lightData.rgb, vec3(0.0)), vec3(2.2));
    vec3 ambient = vec3(0.018) + vanillaAmbient * 0.72;

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
