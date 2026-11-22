#version 330 compatibility

uniform sampler2D colortex0;

in vec2 vTexCoord;
layout(location = 0) out vec4 outColor;

// User-facing color controls. These are defined only in this program so Iris
// discovers one authoritative definition for each option.
#define RED_GAIN 1.00 // [0.50 0.60 0.70 0.80 0.90 1.00 1.10 1.20 1.30 1.40 1.50] Red channel gain
#define GREEN_GAIN 1.00 // [0.50 0.60 0.70 0.80 0.90 1.00 1.10 1.20 1.30 1.40 1.50] Green channel gain
#define BLUE_GAIN 1.00 // [0.50 0.60 0.70 0.80 0.90 1.00 1.10 1.20 1.30 1.40 1.50] Blue channel gain
#define GAMMA 1.00 // [0.70 0.80 0.90 1.00 1.10 1.20 1.30 1.40 1.50] Display gamma correction
#define EXPOSURE 0.00 // [-2.00 -1.50 -1.00 -0.50 0.00 0.50 1.00 1.50 2.00] Exposure in stops
#define CONTRAST 1.00 // [0.60 0.70 0.80 0.90 1.00 1.10 1.20 1.30 1.40] Contrast
#define SATURATION 1.00 // [0.00 0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00] Color saturation
#define HDR_LOOK 0 // [0 1 2] 0=Neutral, 1=HDR, 2=Ultra HDR tone mapping

vec3 applyHdrLook(vec3 color) {
#if HDR_LOOK == 1
    // Filmic shoulder: retain highlight detail while keeping output display-safe.
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((color * (a * color + b)) / (color * (c * color + d) + e), 0.0, 1.0);
#elif HDR_LOOK == 2
    // Stronger highlight compression and a slightly lifted midtone response.
    vec3 x = max(color, vec3(0.0));
    vec3 mapped = x / (1.0 + x);
    mapped = pow(mapped, vec3(0.92));
    return clamp(mapped, 0.0, 1.0);
#else
    return color;
#endif
}

void main() {
    vec4 scene = texture2D(colortex0, vTexCoord);
    vec3 color = max(scene.rgb, vec3(0.0));

    // Exposure is expressed in photographic stops.
    color *= exp2(EXPOSURE);

    // Independent channel gains provide white-balance and creative RGB tuning.
    color *= vec3(RED_GAIN, GREEN_GAIN, BLUE_GAIN);

    // Contrast is applied around a perceptual mid-gray pivot.
    color = (color - vec3(0.18)) * CONTRAST + vec3(0.18);

    // Luminance-preserving saturation adjustment.
    float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = mix(vec3(luminance), color, SATURATION);
    color = max(color, vec3(0.0));

    color = applyHdrLook(color);

    // Gamma is an explicit user control. 1.0 leaves the tone-mapped result unchanged.
    color = pow(max(color, vec3(0.0)), vec3(1.0 / GAMMA));

    outColor = vec4(color, scene.a);
}
