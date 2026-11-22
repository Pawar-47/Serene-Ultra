#version 330 compatibility

uniform sampler2D gtexture;
uniform float alphaTestRef;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;

in vec2 vShadowTexCoord;
in vec4 vShadowVertexColor;
in vec3 vShadowPlayerPosition;
flat in int vShadowMaterialId;
flat in float vShadowFluidRenderType;

/* RENDERTARGETS: 0 */

layout(location = 0) out vec4 outShadowColor;

// Keep the cutoff conservative: it removes transparent texels while
// retaining thin foliage and partially transparent cutout edges.
#define SHADOW_ALPHA_CUTOFF 0.10 // [0.05 0.10 0.15 0.20 0.25 0.30 0.40 0.50] Alpha threshold for shadow casters
#define WATER_WAVE_SPEED 60 // [15 30 45 60 75 90 120] Water wave cycles per real-time hour
#define WATER_CAUSTICS_STRENGTH 100 // [0 25 50 75 100 125 150] Water caustic contrast
#define WATER_CAUSTICS_SCALE 100 // [50 75 100 125 150 200] Water caustic spatial frequency

float calculateWaterCaustics(vec3 absoluteWorldPosition) {
    vec2 p = absoluteWorldPosition.xz * (WATER_CAUSTICS_SCALE * 0.01);
    float timePhase = frameTimeCounter * (6.28318530718 * float(WATER_WAVE_SPEED) / 3600.0);
    vec2 dirA = normalize(vec2(0.83, 0.55));
    vec2 dirB = normalize(vec2(-0.42, 0.91));
    vec2 dirC = normalize(vec2(0.18, -0.98));
    float phaseA = dot(p, dirA) * 0.075 + timePhase;
    float phaseB = dot(p, dirB) * 0.16 - timePhase * 2.0;
    float phaseC = dot(p, dirC) * 0.34 + timePhase * 3.0;
    float interference = abs(
        sin(phaseA) * sin(phaseB) +
        sin(phaseB) * sin(phaseC) +
        sin(phaseC) * sin(phaseA)
    );
    float causticLines = smoothstep(0.15, 0.85, interference);
    float causticPattern = mix(0.55, 1.0, causticLines);
    return mix(0.85, causticPattern, clamp(WATER_CAUSTICS_STRENGTH * 0.01, 0.0, 1.0));
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
    outShadowColor = vec4(1.0, 1.0, 1.0, 0.0);

    if (vShadowMaterialId == 32000 && vShadowFluidRenderType > 0.5) {
        vec3 absoluteWorldPosition = vShadowPlayerPosition + cameraPosition;
        float caustic = calculateWaterCaustics(absoluteWorldPosition);
        outShadowColor = vec4(vec3(caustic * 0.82, caustic * 0.92, caustic), 0.12);
    } else if (vShadowMaterialId == 30008) {
        // Tinted glass transmits less light and keeps a cool neutral cast.
        outShadowColor = vec4(vec3(0.42, 0.46, 0.52), 0.72);
    } else if (vShadowMaterialId >= 31000 && vShadowMaterialId <= 31031) {
        // Preserve the stained-glass hue without making its shadow fully opaque.
        vec3 stainedTint = mix(vec3(1.0), clamp(materialSample.rgb, 0.0, 1.0), 0.55);
        outShadowColor = vec4(stainedTint, 0.38);
    } else if (vShadowMaterialId == 32008 || vShadowMaterialId == 32012) {
        outShadowColor = vec4(vec3(0.92, 0.96, 1.0), 0.15);
    } else if (vShadowMaterialId == 32004) {
        outShadowColor = vec4(vec3(0.72, 0.88, 1.0), 0.22);
    } else if (vShadowMaterialId == 30020) {
        outShadowColor = vec4(vec3(0.82, 0.52, 1.0), 0.78);
    }
}
