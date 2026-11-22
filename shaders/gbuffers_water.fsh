#version 330 compatibility

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform sampler2D colortex4;
uniform sampler2D noisetex;
uniform float alphaTestRef;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform sampler2DShadow shadowtex0;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 shadowLightPosition;
uniform float sunAngle;
uniform bool hasSkylight;
uniform float endFlashIntensity;
uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform float fogDensity;
uniform int fogMode;
uniform int fogShape;

in vec2 vTexCoord;
in vec2 vLightmapCoord;
in vec4 vVertexColor;
in vec3 vPlayerNormal;
in vec3 vPlayerPosition;
in vec3 vViewPosition;
in vec3 vViewNormal;
flat in int vMaterialId;
flat in float vFluidRenderType;

/* RENDERTARGETS: 0 */

#define WATER_REFRACTION_STRENGTH 1.00 // [0.00 0.25 0.50 0.75 1.00 1.25 1.50 2.00] Screen-space water refraction strength
#define WATER_REFLECTION_STRENGTH 0.75 // [0.00 0.25 0.50 0.75 1.00 1.25 1.50] Fresnel screen-space reflection strength
#define WATER_FOG_MULT 100 // [25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100 110 120 130 140 150 160 170 180 190 200 220 240 260 280 300 325 350 375 400 425 450 475 500 550 600 650 700 750 800 850 900] Water depth opacity
#define WATER_REFLECTION_QUALITY 6 // [0 4 6 8] Screen-space water reflection samples
#define WATER_WAVE_STRENGTH 100 // [0 25 50 75 100 125 150 175 200] Animated multi-scale water normal strength
#define WATER_WAVE_SPEED 60 // [15 30 45 60 75 90 120] Water wave cycles per real-time hour
#define WATER_COLOR_STRENGTH 100 // [0 25 50 75 100] Unbound-style water base tint blend
#define WATER_NOISE_COLOR_STRENGTH 35 // [0 10 20 35 50 75 100] Animated water colour variation
#define WATER_FOAM_STRENGTH 100 // [0 25 50 75 100 125 150] Shoreline and shallow-surface foam strength
#define WATER_UNDERWATER_STRENGTH 100 // [0 25 50 75 100 125 150] Underwater tint and surface response
layout(location = 0) out vec4 outColor;

// Three analytic wave bands provide stable multi-scale surface normals without
// a full-screen texture fetch or an additional normal-map asset. Coordinates
// are reconstructed in absolute player/world space so camera motion does not
// make the wave pattern swim.
vec3 calculateWaterWaveNormal(vec3 geometricNormal, vec3 playerPosition) {
    if (abs(geometricNormal.y) < 0.72 || WATER_WAVE_STRENGTH <= 0) {
        return geometricNormal;
    }

    vec2 worldXZ = (playerPosition + cameraPosition).xz;
    // Iris frameTimeCounter wraps every 3600 seconds. Integer cycle counts
    // keep every wave phase continuous at that wrap for all slider values.
    float waveTime = frameTimeCounter * (6.28318530718 * float(WATER_WAVE_SPEED) / 3600.0);

    vec2 directionA = normalize(vec2(0.83, 0.55));
    vec2 directionB = normalize(vec2(-0.42, 0.91));
    vec2 directionC = normalize(vec2(0.18, -0.98));

    float phaseA = dot(worldXZ, directionA) * 0.075 + waveTime;
    float phaseB = dot(worldXZ, directionB) * 0.16 - waveTime * 2.0;
    float phaseC = dot(worldXZ, directionC) * 0.34 + waveTime * 3.0;

    vec2 slope = directionA * (0.34 * 0.075 * cos(phaseA));
    slope += directionB * (0.15 * 0.16 * cos(phaseB));
    slope += directionC * (0.055 * 0.34 * cos(phaseC));

    float strength = (WATER_WAVE_STRENGTH * 0.01) * 3.0;
    float faceSign = geometricNormal.y < 0.0 ? -1.0 : 1.0;
    vec3 waveNormal = normalize(vec3(-slope.x * strength, faceSign, -slope.y * strength));
    return normalize(mix(geometricNormal, waveNormal,
                         clamp(WATER_WAVE_STRENGTH * 0.01, 0.0, 1.0)));
}

// Unbound-style water base colour: retain biome influence, but move the
// surface away from the flat vanilla atlas tint. A single Iris noise lookup
// adds slow, low-amplitude colour variation without a second custom texture.
vec3 calculateWaterBaseColor(vec3 vertexColor, vec3 absoluteWorldPosition) {
    vec3 biomeTint = sqrt(max(vertexColor, vec3(0.0))) * vec3(1.0, 0.85, 0.8);
    vec3 waterTint = mix(vec3(0.43, 0.60, 0.80), biomeTint, 0.5);
    vec3 baseColor = 0.375 * waterTint;

    if (WATER_NOISE_COLOR_STRENGTH > 0) {
        float noiseTime = frameTimeCounter * (6.28318530718 * float(WATER_WAVE_SPEED) / 3600.0);
        vec2 noiseDrift = vec2(cos(noiseTime), sin(noiseTime)) * 0.025;
        vec2 noiseUV = absoluteWorldPosition.xz * 0.008 + noiseDrift;
        float noise = textureLod(noisetex, noiseUV, 0.0).g - 0.5;
        baseColor *= 1.0 + noise * 0.25 * (WATER_NOISE_COLOR_STRENGTH * 0.01);
    }

    return baseColor;
}

float sampleTranslucentShadow(vec3 playerPosition, vec3 normal, vec3 lightDirection) {
    vec4 shadowViewPosition = shadowModelView * vec4(playerPosition, 1.0);
    vec4 shadowClipPosition = shadowProjection * shadowViewPosition;

    float normalLight = max(dot(normal, lightDirection), 0.0);
    float depthBias = mix(0.0022, 0.00065, normalLight);
    shadowClipPosition.z -= depthBias;

    vec3 shadowNdc = shadowClipPosition.xyz / shadowClipPosition.w;
    vec3 shadowPosition = shadowNdc * 0.5 + 0.5;
    if (shadowPosition.x <= 0.0 || shadowPosition.x >= 1.0 ||
        shadowPosition.y <= 0.0 || shadowPosition.y >= 1.0 ||
        shadowPosition.z <= 0.0 || shadowPosition.z >= 1.0) {
        return 1.0;
    }

    vec2 texel = 1.0 / vec2(textureSize(shadowtex0, 0));
    float visibility = 0.0;
    visibility += texture(shadowtex0, vec3(shadowPosition.xy + texel * vec2(-0.5, -0.5), shadowPosition.z));
    visibility += texture(shadowtex0, vec3(shadowPosition.xy + texel * vec2( 0.5, -0.5), shadowPosition.z));
    visibility += texture(shadowtex0, vec3(shadowPosition.xy + texel * vec2(-0.5,  0.5), shadowPosition.z));
    visibility += texture(shadowtex0, vec3(shadowPosition.xy + texel * vec2( 0.5,  0.5), shadowPosition.z));
    return visibility * 0.25;
}

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position) {
    vec4 homogeneous = projectionMatrix * vec4(position, 1.0);
    return homogeneous.xyz / homogeneous.w;
}

float calculateWaterThickness(out vec3 opaqueViewPosition, out float opaqueDepth) {
    // depthtex1 is full-resolution; fetch the exact current pixel without
    // filtering, then normalize only for inverse-projection reconstruction.
    opaqueDepth = texelFetch(depthtex1, ivec2(gl_FragCoord.xy), 0).r;
    // depthtex1 clears to 1.0. Reconstruct that far-plane sample with the
    // inverse projection instead of using Iris' "far" uniform, which is
    // render distance in blocks rather than the projection far plane.
    vec2 screenUV = gl_FragCoord.xy / vec2(textureSize(depthtex1, 0));
    vec3 opaqueNdc = vec3(screenUV, opaqueDepth) * 2.0 - 1.0;
    opaqueViewPosition = projectAndDivide(gbufferProjectionInverse, opaqueNdc);
    float opaqueDistance = length(opaqueViewPosition);
    return max(opaqueDistance - length(vViewPosition), 0.0);
}


#if WATER_REFLECTION_QUALITY > 0
// The deferred1 pass writes a separate half-resolution opaque/sky color snapshot to colortex4.
// depthtex2 excludes both translucent geometry and first-person hand geometry,
// so this forward pass never samples colortex0 while writing to it.
vec3 sampleWaterScreenReflection(vec3 viewPosition, vec3 viewNormal, out float hitConfidence) {
    const float maxDistance = 24.0;
    float stepLength = maxDistance / float(WATER_REFLECTION_QUALITY);
    vec3 incidentDirection = normalize(viewPosition);
    vec3 reflectionDirection = normalize(reflect(incidentDirection, viewNormal));
    vec3 rayOrigin = viewPosition + viewNormal * 0.06 + reflectionDirection * 0.03;

    vec3 reflectionColor = vec3(0.0);
    hitConfidence = 0.0;

    for (int i = 0; i < WATER_REFLECTION_QUALITY; ++i) {
        float travelDistance = (float(i) + 1.0) * stepLength;
        vec3 rayPosition = rayOrigin + reflectionDirection * travelDistance;
        vec4 clipPosition = gbufferProjection * vec4(rayPosition, 1.0);
        if (clipPosition.w <= 0.0001) break;

        vec3 rayNdc = clipPosition.xyz / clipPosition.w;
        vec2 sampleUV = rayNdc.xy * 0.5 + 0.5;
        if (sampleUV.x <= 0.001 || sampleUV.x >= 0.999 ||
            sampleUV.y <= 0.001 || sampleUV.y >= 0.999) {
            break;
        }

        ivec2 depthPixel = ivec2(sampleUV * vec2(textureSize(depthtex2, 0)));
        ivec2 reflectionPixel = ivec2(sampleUV * vec2(textureSize(colortex4, 0)));
        depthPixel = clamp(depthPixel, ivec2(0), textureSize(depthtex2, 0) - ivec2(1));
        reflectionPixel = clamp(reflectionPixel, ivec2(0), textureSize(colortex4, 0) - ivec2(1));
        float sceneDepth = texelFetch(depthtex2, depthPixel, 0).r;
        vec4 sceneSample = texelFetch(colortex4, reflectionPixel, 0);

        // Alpha zero marks pixels where the deferred scene snapshot contained
        // first-person hand or transparent overlays rather than opaque/sky color.
        if (sceneSample.a < 0.5) continue;

        vec2 edgeDistance = min(sampleUV, vec2(1.0) - sampleUV);
        float edgeFade = smoothstep(0.0, 0.08, min(edgeDistance.x, edgeDistance.y));
        float distanceFade = 1.0 - smoothstep(16.0, maxDistance, travelDistance);

        // A clear depth sample is the sky; its color is already present in the
        // deferred snapshot and is a valid reflection source.
        if (sceneDepth >= 0.999999) {
            reflectionColor = sceneSample.rgb;
            hitConfidence = edgeFade * distanceFade;
            return reflectionColor;
        }

        vec3 sceneNdc = vec3(sampleUV, sceneDepth) * 2.0 - 1.0;
        vec3 sceneViewPosition = projectAndDivide(gbufferProjectionInverse, sceneNdc);
        float depthDelta = rayPosition.z - sceneViewPosition.z;

        // View-space Z is negative in front of the camera. A negative delta
        // means the reflection ray has crossed behind the opaque depth surface.
        if (depthDelta <= 0.0 && depthDelta > -stepLength * 0.75) {
            float depthConfidence = 1.0 - smoothstep(0.0, stepLength * 0.75, abs(depthDelta));
            reflectionColor = sceneSample.rgb;
            hitConfidence = edgeFade * distanceFade * depthConfidence;
            return reflectionColor;
        }
    }

    return reflectionColor;
}
#endif

float calculateTranslucentFog(float distanceToCamera) {
    if (fogMode == 9729) {
        return clamp((distanceToCamera - fogStart) / max(fogEnd - fogStart, 0.0001), 0.0, 1.0);
    }
    if (fogMode == 2048) {
        return clamp(1.0 - exp(-fogDensity * distanceToCamera), 0.0, 1.0);
    }
    if (fogMode == 2049) {
        float densityDistance = fogDensity * distanceToCamera;
        return clamp(1.0 - exp(-densityDistance * densityDistance), 0.0, 1.0);
    }
    return 0.0;
}

void main() {
    vec4 translucentAlbedo = texture(gtexture, vTexCoord) * vVertexColor;
    if (translucentAlbedo.a < alphaTestRef) discard;

    // Iris routes translucent terrain through gbuffers_water. Only fluid
    // material IDs receive water depth/refraction/reflection effects; glass
    // and other translucent terrain retain the generic forward-lit path.
    vec3 vanillaLight = texture(lightmap, vLightmapCoord).rgb;
    float skyLight = clamp(vLightmapCoord.y / (30.0 / 32.0) - (1.0 / 32.0), 0.0, 1.0);

    bool isWater = (vMaterialId == 32000) && (vFluidRenderType > 0.5);
    vec3 normal = normalize(vPlayerNormal);
    vec3 viewNormal = normalize(vViewNormal);
    if (!gl_FrontFacing) {
        normal = -normal;
        viewNormal = -viewNormal;
    }
    // Complementary's Iris-water workaround: orient the geometric normal
    // toward the camera before shadowing, Fresnel and reflection calculations.
    if (isWater && dot(normalize(vViewPosition), viewNormal) > 0.0) {
        normal = -normal;
        viewNormal = -viewNormal;
    }
    if (isWater) {
        normal = calculateWaterWaveNormal(normal, vPlayerPosition);
        // Iris documents gbufferModelView as player-space to view-space.
        // Transform the perturbed normal for Fresnel, refraction and SSR.
        viewNormal = normalize(mat3(gbufferModelView) * normal);
    }
    vec3 viewLightDirection = normalize(shadowLightPosition);
    vec3 worldLightDirection = normalize(mat3(gbufferModelViewInverse) * viewLightDirection);
    float nDotL = max(dot(normal, worldLightDirection), 0.0);

    bool endFlashActive = endFlashIntensity > 0.001;
    float solarElevation = sin(sunAngle * 6.28318530718);
    float dayFactor = (hasSkylight && !endFlashActive)
        ? smoothstep(0.0, 0.30, solarElevation)
        : 0.0;
    float celestialGate = endFlashActive
        ? clamp(endFlashIntensity, 0.0, 1.0)
        : (hasSkylight ? skyLight : 0.0);

    bool cameraUnderwater = (isEyeInWater == 1);
    float shadow = 1.0;
    if (nDotL > 0.001 && celestialGate > 0.001 && !(isWater && cameraUnderwater)) {
        shadow = sampleTranslucentShadow(vPlayerPosition, normal, worldLightDirection);
    }

    vec3 ambient = vec3(0.018) + pow(max(vanillaLight, vec3(0.0)), vec3(2.2)) * 0.72;
    vec3 celestialColor = endFlashActive
        ? vec3(1.0)
        : (hasSkylight
            ? mix(vec3(0.36, 0.44, 0.68), vec3(1.0, 0.94, 0.82), dayFactor)
            : vec3(1.0));
    float celestialIntensity = endFlashActive
        ? 0.70
        : (hasSkylight ? mix(0.10, 0.70, dayFactor) : 0.0);
    vec3 direct = celestialColor * celestialIntensity * nDotL * shadow * celestialGate;
    if (isWater && cameraUnderwater) direct = vec3(0.0);

    float waterThickness = 0.0;
    float waterFog = 0.0;
    float waterFresnel = 0.0;
    float waterFoam = 0.0;
    vec2 waterRefractionOffset = vec2(0.0);
    float refractionConfidence = 0.0;
    vec3 refractedSceneLinear = vec3(0.0);

    if (isWater) {
        float nDotV = clamp(dot(viewNormal, normalize(-vViewPosition)), 0.0, 1.0);
        waterFresnel = 0.02 + 0.98 * pow(1.0 - nDotV, 5.0);

        vec3 opaqueViewPosition;
        float opaqueDepth;
        waterThickness = calculateWaterThickness(opaqueViewPosition, opaqueDepth)
            * (WATER_FOG_MULT * 0.01);
        waterFog = clamp(1.0 - exp(-waterThickness * 0.075), 0.0, 1.0);

        // Unbound-inspired shallow-water foam. Reconstructed view-space
        // thickness is the stable signal for a nearby opaque intersection;
        // avoid a world-Y test, which misses sloped shorelines and depends on
        // the sign of the opaque surface's vertical offset.
        if (WATER_FOAM_STRENGTH > 0 && opaqueDepth < 0.999999 &&
            abs(vPlayerNormal.y) > 0.99) {
            float shallowFoam = 1.0 - smoothstep(0.035, 0.42, waterThickness);
            waterFoam = shallowFoam * (0.4 + 0.25 * skyLight);
            waterFoam = clamp(waterFoam * (WATER_FOAM_STRENGTH * 0.01), 0.0, 1.0);
        }

        // Match the working reference's depth-based opacity and add a modest
        // Fresnel opacity increase at grazing angles.
        translucentAlbedo.a = sqrt(max(translucentAlbedo.a, 0.0));
        float waterAlpha = translucentAlbedo.a * (0.25 + 0.75 * waterFog);
        waterAlpha = mix(waterAlpha, 1.0, waterFresnel * 0.25);
        // Complementary Unbound uses a distinct underwater branch: soften
        // water opacity, cool the surface tint and suppress directional light.
        if (cameraUnderwater) {
            waterAlpha *= mix(1.0, 0.75, clamp(WATER_UNDERWATER_STRENGTH * 0.01, 0.0, 1.5));
            translucentAlbedo.rgb *= mix(
                vec3(1.0),
                vec3(0.78, 0.90, 1.05),
                clamp(WATER_UNDERWATER_STRENGTH * 0.01, 0.0, 1.0)
            );
        }
        translucentAlbedo.a = clamp(waterAlpha, 0.0, 1.0);

        // deferred1 snapshots the opaque scene into half-resolution colortex4.
        // This gbuffers pass writes colortex0 but reads colortex4, so it avoids
        // same-attachment feedback and keeps refraction bandwidth bounded.
        if (WATER_REFRACTION_STRENGTH > 0.001 && opaqueDepth < 0.999999) {
            vec2 screenUV = gl_FragCoord.xy / vec2(textureSize(depthtex1, 0));
            waterRefractionOffset = viewNormal.xy
                * min(waterThickness * 0.0025, 0.035)
                * WATER_REFRACTION_STRENGTH;
            vec2 halfTexel = 0.5 / vec2(textureSize(colortex4, 0));
            vec2 refractedUV = clamp(screenUV + waterRefractionOffset,
                                     halfTexel, vec2(1.0) - halfTexel);

            ivec2 refractedPixel = ivec2(refractedUV * vec2(textureSize(depthtex1, 0)));
            refractedPixel = clamp(refractedPixel, ivec2(0), textureSize(depthtex1, 0) - ivec2(1));
            float refractedDepth = texelFetch(depthtex1, refractedPixel, 0).r;
            vec2 refractedDepthUV = (vec2(refractedPixel) + 0.5)
                / vec2(textureSize(depthtex1, 0));
            if (refractedDepth < 0.999999) {
                vec3 refractedNdc = vec3(refractedDepthUV, refractedDepth) * 2.0 - 1.0;
                vec3 refractedViewPosition = projectAndDivide(gbufferProjectionInverse, refractedNdc);
                float depthDelta = abs(length(refractedViewPosition) - length(opaqueViewPosition));
                refractionConfidence = 1.0 - smoothstep(0.5, 4.0, depthDelta);

                // Reject offsets that cross onto geometry in front of the water.
                if (refractedViewPosition.z > vViewPosition.z + 0.05) {
                    refractionConfidence = 0.0;
                }

                vec4 refractedScene = texture(colortex4, refractedUV);
                if (refractedScene.a >= 0.5) {
                    refractedSceneLinear = pow(
                        max(refractedScene.rgb, vec3(0.0)),
                        vec3(2.2)
                    );
                } else {
                    refractionConfidence = 0.0;
                }
            }
        }
    }

    if (isWater) {
        vec3 absoluteWorldPosition = vPlayerPosition + cameraPosition;
        vec3 unboundWaterColor = calculateWaterBaseColor(vVertexColor.rgb, absoluteWorldPosition);
        translucentAlbedo.rgb = mix(
            translucentAlbedo.rgb,
            unboundWaterColor,
            clamp(WATER_COLOR_STRENGTH * 0.01, 0.0, 1.0)
        );
    }

    if (isWater && waterFoam > 0.0) {
        translucentAlbedo.rgb = mix(
            translucentAlbedo.rgb,
            vec3(0.90, 0.95, 1.05),
            waterFoam
        );
    }

    vec3 albedoLinear = pow(max(translucentAlbedo.rgb, vec3(0.0)), vec3(2.2));
    vec3 litLinear = albedoLinear * (ambient + direct);
    // Lava shares the post-deferred fluid pass but retains its self-emission.
    float lavaEmission = (vMaterialId == 32118) ? 0.9 : 0.0;
    litLinear += albedoLinear * lavaEmission;

    float fogDistance = (fogShape == 1) ? length(vViewPosition.xz) : length(vViewPosition);
    float fogFactor = calculateTranslucentFog(fogDistance);
    vec3 fogColorLinear = pow(max(fogColor, vec3(0.0)), vec3(2.2));
    litLinear = mix(litLinear, fogColorLinear, fogFactor);

    if (isWater) {
        float offsetStrength = clamp(length(waterRefractionOffset) * 25.0, 0.0, 1.0);
        float refractionMix = clamp(
            0.55 * WATER_REFRACTION_STRENGTH * waterFog
            * refractionConfidence * offsetStrength,
            0.0, 0.75
        );
        // The scene copy is already fogged by deferred; do not fog it twice.
        litLinear = mix(litLinear, refractedSceneLinear, refractionMix);

        // Fresnel-weighted screen-space reflections use depthtex2 (opaque
        // world depth without first-person hand/translucent depth) and the
        // separate colortex4 scene snapshot. Quality controls ray-march steps.
        #if WATER_REFLECTION_QUALITY > 0
        vec3 reflectionViewNormal = normalize(vViewNormal);
        if (dot(normalize(vViewPosition), reflectionViewNormal) > 0.0) {
            reflectionViewNormal = -reflectionViewNormal;
        }
        float nDotV = clamp(dot(reflectionViewNormal, normalize(-vViewPosition)), 0.0, 1.0);
        float fresnel = 0.02 + 0.98 * pow(1.0 - nDotV, 5.0);
        float reflectionConfidence = 0.0;
        vec3 reflectionColor = sampleWaterScreenReflection(
            vViewPosition, reflectionViewNormal, reflectionConfidence
        );
        vec3 reflectionLinear = pow(max(reflectionColor, vec3(0.0)), vec3(2.2));
        float reflectionWeight = clamp(
            min(fresnel * 2.5, 0.85) * reflectionConfidence * WATER_REFLECTION_STRENGTH
            * (1.0 - waterFoam) * (cameraUnderwater ? 0.5 : 1.0),
            0.0, 0.95
        );
        litLinear = mix(litLinear, reflectionLinear, reflectionWeight);
        #endif
    }

    vec3 litColor = pow(max(litLinear, vec3(0.0)), vec3(1.0 / 2.2));
    outColor = vec4(litColor, translucentAlbedo.a);
}
