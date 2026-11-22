# Serene Ultra Architecture

## Design goals
A conventional GLSL Iris shaderpack with a compact, auditable pipeline. The architecture grows feature-by-feature while retaining a compatible baseline.

## Planned layers
- **Geometry capture:** terrain, entities, hand, particles, weather, translucent materials and shadow casters.
- **Material system:** albedo, lightmap coordinates and world/player-aligned normals in G-buffer attachments; later material classification for normal/specular/emissive/roughness response.
- **Lighting:** directional sun/moon, block light, ambient occlusion, indirect light and colored light.
- **Shadows:** depth rendering, alpha-tested casters, filtering, bias and distance management.
- **Atmosphere:** sky, clouds, fog, volumetric scattering and dimension-specific tuning.
- **Reflections:** water and reflective blocks, screen-space data and fallback environment response.
- **Post-processing:** temporal AA, bloom, color grading and all Ultra-enabled post effects found in the reference.
- **Compatibility:** Iris uniforms, vanilla effects, weather, dimensions, UI and resource packs.

## Current G-buffer contract
Opaque/cutout terrain and entity passes write three attachments using Iris' RENDERTARGETS mapping:
- colortex0: unmodified sampled albedo multiplied by vertex color.
- colortex1: raw lightmap texture coordinates in RG.
- colortex2: normalized player/world-aligned normal encoded from [-1, 1] into [0, 1], with alpha set to one for covered geometry.

The terrain/entity vertex stages transform normals from view space back into player-aligned space using Iris' gbufferModelViewInverse. The first-person hand path writes only colortex0; it is deliberately not treated as world geometry by the current deferred-data contract.

The composite pass currently copies colortex0 unchanged. This is intentional: G-buffer capture is being introduced before lighting so the baseline appearance is not altered by an unverified lighting approximation.

## Performance architecture
- Share common functions and constants rather than duplicate calculations.
- Keep render-target formats and lifetimes explicit.
- Avoid full-resolution intermediate buffers unless required by image quality.
- Use depth-aware reconstruction for reduced-resolution effects.
- Keep temporal history invalidation explicit on camera cuts, resize, dimension changes and shader reload.
- Prefer capability-compatible GLSL paths; do not make SSBOs a hard requirement for the Intel target.

## Current implementation
- GLSL 330-compatible terrain/entity albedo, lightmap-coordinate and normal capture.
- Texture-aware alpha-tested shadow casters.
- Explicit Iris render-target mappings and data-buffer blending rules.
- Structural CI checks for G-buffer attachment declarations and shadow alpha testing.

This remains a rendering foundation, not Ultra parity. Deferred lighting, actual shadow sampling/filtering, material classification, translucency, atmosphere and post effects are still incomplete and require Iris runtime testing.
