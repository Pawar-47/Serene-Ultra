// LabPBR porosity wet-darkening for opaque entity and block-entity materials.
// The caller supplies the biome/rainfall-gated, smoothed Iris wetness factor.
void applyPorosityWetness(
    inout vec3 albedo,
    inout float materialReflectance,
    inout float materialSmoothness,
    float materialPorosity,
    float wetnessFactor,
    float emissionStrength
) {
    if (materialPorosity <= 0.0 || wetnessFactor <= 0.001 || emissionStrength >= 0.01) return;

    float porousWetness = clamp(
        wetnessFactor * materialPorosity * (MATERIAL_WETNESS_STRENGTH * 0.01),
        0.0, 1.0
    );
    albedo *= 1.0 - porousWetness * 0.22;
    materialReflectance *= 1.0 - porousWetness * 0.45;
    materialSmoothness *= 1.0 - porousWetness * 0.35;
}
