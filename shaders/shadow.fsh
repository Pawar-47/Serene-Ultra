#version 130

uniform sampler2D gtexture;
uniform float alphaTestRef;
uniform ivec3 cameraPositionInt;
uniform vec3 cameraPositionFract;
uniform float frameTimeCounter;

in vec2 vShadowTexCoord;
in vec4 vShadowVertexColor;
in vec3 vShadowPlayerPosition;
flat in int vShadowMaterialId;
flat in float vShadowFluidRenderType;

/* RENDERTARGETS: 0 */
/* const int shadowcolor0Format = RGBA8; */

out vec4 outColor0;

// Keep the cutoff conservative: it removes transparent texels while
// retaining thin foliage and partially transparent cutout edges.
#define SHADOW_ALPHA_CUTOFF 0.10 // [0.05 0.10 0.15 0.20 0.25 0.30 0.40 0.50] Alpha threshold for shadow casters
#define WATER_WAVE_SPEED 60 // [15 30 45 60 75 90 120] Water wave cycles per real-time hour
#define WATER_CAUSTICS_STRENGTH 100 // [0 25 50 75 100 125 150] Water caustic contrast
#define WATER_CAUSTICS_SCALE 100 // [50 75 100 125 150 200] Water caustic spatial frequency

vec3 getStableShadowWorldPosition(vec3 playerPosition) {
    ivec3 cameraModulo = cameraPositionInt % ivec3(256);
    vec3 cameraOffset = mod(vec3(cameraModulo), vec3(256.0));
    return mod(cameraOffset + cameraPositionFract + playerPosition, vec3(256.0));
}

float calculateWaterCaustics(vec3 stableWorldPosition) {
    vec2 p = stableWorldPosition.xz;
    float timePhase = frameTimeCounter * (6.28318530718 * float(WATER_WAVE_SPEED) / 3600.0);
    float causticsScale = WATER_CAUSTICS_SCALE * 0.01;
    float frequencyA = (6.28318530718 / 64.0) * causticsScale;
    float frequencyB = (6.28318530718 / 32.0) * causticsScale;
    float frequencyC = (6.28318530718 / 16.0) * causticsScale;
    float phaseA = dot(p, vec2(1.0, 2.0)) * frequencyA + timePhase;
    float phaseB = dot(p, vec2(-2.0, 1.0)) * frequencyB - timePhase * 2.0;
    float phaseC = dot(p, vec2(1.0, -1.0)) * frequencyC + timePhase * 3.0;
    float interference = abs(
        sin(phaseA) * sin(phaseB) +
        sin(phaseB) * sin(phaseC) +
        sin(phaseC) * sin(phaseA)
    );
    float causticLines = smoothstep(0.15, 0.85, interference);
    float causticPattern = mix(0.55, 1.0, causticLines);
    float causticsStrength = WATER_CAUSTICS_STRENGTH * 0.01;
    // Zero strength is neutral transmission; values above 100 increase contrast.
    return clamp(1.0 + (causticPattern - 1.0) * causticsStrength, 0.0, 1.0);
}

void main() {
    vec4 materialSample = texture(gtexture, vShadowTexCoord) * vShadowVertexColor;
    float materialAlpha = materialSample.a;
    // Iris may raise alphaTestRef for a particular cutout render layer.
    // Retain the pack's user cutoff without bypassing Iris' per-layer threshold.
    float effectiveAlphaCutoff = max(alphaTestRef, SHADOW_ALPHA_CUTOFF);
    if (materialAlpha < effectiveAlphaCutoff) {
        discard;
    }

    // Default unknown translucent materials to full white transmission.
    // Opaque blockers are distinguished by shadowtex1 in deferred.
    outColor0 = vec4(1.0, 1.0, 1.0, 0.0);

    if ((vShadowMaterialId == 32000 && vShadowFluidRenderType > 0.5) ||
        (vShadowMaterialId == 32001 && materialAlpha < 0.999)) {
        vec3 absoluteWorldPosition = getStableShadowWorldPosition(vShadowPlayerPosition);
        float caustic = calculateWaterCaustics(absoluteWorldPosition);
        outColor0 = vec4(vec3(caustic * 0.82, caustic * 0.92, caustic), 0.12);
    } else if (vShadowMaterialId == 30008) {
        // Tinted glass transmits less light and keeps a cool neutral cast.
        outColor0 = vec4(vec3(0.42, 0.46, 0.52), 0.72);
    } else if (vShadowMaterialId >= 31000 && vShadowMaterialId <= 31031) {
        // Preserve the stained-glass hue without making its shadow fully opaque.
        vec3 stainedTint = mix(vec3(1.0), clamp(materialSample.rgb, 0.0, 1.0), 0.55);
        outColor0 = vec4(stainedTint, 0.38);
    } else if (vShadowMaterialId == 32008 || vShadowMaterialId == 32012) {
        outColor0 = vec4(vec3(0.92, 0.96, 1.0), 0.15);
    } else if (vShadowMaterialId == 32004) {
        outColor0 = vec4(vec3(0.72, 0.88, 1.0), 0.22);
    } else if (vShadowMaterialId == 30020) {
        outColor0 = vec4(vec3(0.82, 0.52, 1.0), 0.78);
    }
}
