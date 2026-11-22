# Serene Ultra Architecture

## Design goals
A conventional GLSL Iris shaderpack with a compact, auditable pipeline. The architecture grows feature-by-feature while retaining a compatible baseline.

## Planned layers
- **Geometry capture:** terrain, entities, hand, particles, weather, translucent materials and shadow casters.
- **Material system:** albedo, sampled vanilla lightmap RGB, sky-light factor and world/player-aligned normals in G-buffer attachments; later material classification for normal/specular/emissive/roughness response.
- **Lighting:** directional sun/moon, block light, ambient occlusion, indirect light and colored light.
- **Shadows:** depth rendering, alpha-tested casters, filtered comparisons, bias and distance management.
- **Atmosphere:** sky, clouds, fog, volumetric scattering and dimension-specific tuning.
- **Reflections:** water and reflective blocks, screen-space data and fallback environment response.
- **Post-processing:** temporal AA, bloom, color grading and all Ultra-enabled post effects found in the reference.
- **Compatibility:** Iris uniforms, vanilla effects, weather, dimensions, UI and resource packs.

## Current G-buffer contract
Opaque/cutout terrain and entity passes write three attachments using Iris' RENDERTARGETS mapping:
- colortex0: unmodified sampled albedo multiplied by vertex color.
- colortex1: sampled vanilla lightmap RGB in RGB and sky-light coordinate in alpha.
- colortex2: normalized player/world-aligned normal encoded from [-1, 1] into [0, 1], with alpha set to one for covered geometry.

The terrain/entity vertex stages transform normals from view space back into player-aligned space using Iris' gbufferModelViewInverse. Their fragment stages sample the vanilla lightmap so the later deferred pass can retain its warm block-light and colored skylight response. The first-person hand path writes only colortex0; it is deliberately not treated as world geometry by the current deferred-data contract.

## Deferred lighting stage
The deferred fragment pass reconstructs player-space position from depth using Iris projection/model-view inverse matrices. It decodes the G-buffer normal and sampled lightmap, transforms Iris' shadowLightPosition into player space, projects the surface into the shadow map, applies a slope-aware depth bias, and evaluates four hardware-filtered shadow comparison taps.

The initial lighting model uses the sampled vanilla lightmap RGB as its ambient/block-light foundation, adds a separate day/night-adjusted direct celestial diffuse term, and preserves the sky-light coordinate to gate direct light. Sky pixels and fragments without world-normal data are passed through unchanged. This is an initial functional lighting model, not a claim of reference visual parity; light balance, shadow stability, dimension behavior and performance require in-game comparison.

The composite pass remains an identity copy. This keeps later post-processing stages separate from geometry lighting.

## Performance architecture
- Share common functions and constants rather than duplicate calculations.
- Keep render-target formats and lifetimes explicit.
- Avoid full-resolution intermediate buffers unless required by image quality.
- Use depth-aware reconstruction for reduced-resolution effects.
- Keep temporal history invalidation explicit on camera cuts, resize, dimension changes and shader reload.
- Prefer capability-compatible GLSL paths; do not make SSBOs a hard requirement for the Intel target.

## Current implementation
- GLSL 330-compatible terrain/entity albedo, lightmap and normal capture.
- Texture-aware alpha-tested shadow casters.
- Deferred position reconstruction, direct celestial lighting and four-tap hardware-filtered shadow comparisons.
- Vanilla lightmap RGB preservation for colored ambient/block-light response.
- Explicit Iris render-target mappings and data-buffer blending rules.
- Structural CI checks for G-buffer attachments, alpha-tested shadows and deferred-lighting dependencies.

This remains an early rendering foundation, not Ultra parity. AO, advanced colored light, indirect illumination, shadow softness/bias calibration, material classification, translucency, atmosphere and post effects remain incomplete and require Iris runtime testing.
