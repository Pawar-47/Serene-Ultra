# Serene Ultra Architecture

## Two-reference engineering rule (mandatory)
Both supplied shader archives are active technical references, not merely one engine reference plus one visual mood board. Consult both when designing, reviewing, debugging or validating a rendering feature. When uncertain whether an approach, formula, interface, shader stage, texture lookup, buffer, pass order or code path is correct, inspect the corresponding/relevant files in **both** archives, compare how each achieves or expects the behavior, and record the evidence before choosing an implementation. If the files are not directly equivalent, trace the related stages and shared inputs/outputs rather than forcing a one-file match. Use Vanilla-stock to establish Minecraft 26.3's native contracts and behavior; use the working shader to understand proven feature implementation, visual treatment, quality controls and Ultra expectations. Then write an original Serene Ultra implementation that respects the stock engine contract while pursuing the reference's visual contribution, adapted for Intel HD 5500 without dropping Ultra features. Do not blindly copy either source, and do not claim a comparison was performed unless the relevant files were actually inspected.


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

## Deferred lighting and attachment flow
The deferred fragment pass reads the G-buffer color, lightmap, normal and depth inputs. It reconstructs player-space position, transforms the surface into shadow space, applies slope-aware depth bias and evaluates four hardware-filtered shadow comparison taps.

**Iris attachment rule:** deferred and composite are composite-style passes. They read the main backing image and write the alternate backing image, then Iris flips the pair after the pass. Therefore deferred may read and write the same logical attachment (`colortex0`) safely through this documented mechanism. Deferred writes the lit opaque scene to logical colortex0 (`RENDERTARGETS: 0`); after the deferred flip, post-deferred translucent programs blend into the new main image. Composite then performs a colortex0-to-colortex0 pass-through with its own flip, preserving the accumulated scene. This is distinct from gbuffers programs, which must not sample colortex0–3.

The lighting model uses sampled vanilla lightmap RGB as its ambient/block-light foundation, adds a day/night-adjusted direct celestial diffuse term and gates direct light with the sky-light coordinate. Its daylight factor follows Iris' documented cyclic sunAngle convention (0=dawn, 0.25=noon, 0.5=sunset, 0.75=midnight): the sine of the full cycle is passed through a smooth elevation threshold, yielding continuous dawn/day/dusk/night transitions rather than treating sunrise as full daylight. Eight depth-neighbor samples provide a first screen-space contact-occlusion approximation. AO attenuates ambient light only, preserving direct celestial and emissive contributions. Sky pixels and fragments without world-normal data pass through unchanged.

This AO is a deliberately bounded first implementation, not a final GTAO-quality solution. Radius, bias, edge behavior, camera motion stability and performance need scene-based calibration. It must be compared with the actual Minecraft 26.3 stock shader source before its interfaces and behavior are treated as verified.

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
- Iris main/alternate buffer flipping for deferred lighting and composite scene preservation.
- Eight-tap screen-space contact AO with adjustable strength and radius.
- Structural CI checks for G-buffer attachments, alpha-tested shadows, deferred attachment separation and AO controls.
- GitHub Actions installs glslang-tools and compiles every .vsh/.fsh stage as a standalone GLSL stage; this catches shader-language errors but does not replace Iris/Minecraft runtime testing.

This remains an early rendering foundation, not Ultra parity. Advanced colored light, indirect illumination, shadow softness/bias calibration, material classification, translucency, atmosphere and post effects remain incomplete and require Iris runtime testing.


## Iris is the execution contract
Serene Ultra is loaded by Iris. The shaderpack's program filenames, opaque/deferred/translucent order, gbuffers fallbacks, blending, color/depth attachment behavior, flips and settings must follow Iris documentation and be verified in Iris itself. Vanilla-stock source establishes Minecraft-native behavior and inputs; it does not define the Iris shaderpack file layout or pass execution. Complementary Reimagined is a working Iris implementation reference and should be traced at source level alongside stock code when choosing feature algorithms.

### Iris pipeline audit finding
The current pack has no dedicated `gbuffers_water`, `gbuffers_weather` or `gbuffers_hand_water` programs. Iris documents these as post-deferred translucent programs, falling back respectively to terrain, textured-lit and hand programs. The former colortex3 copy-back hazard has been removed by the main/alternate flip pipeline. However, the fallback shaders are not purpose-built forward material implementations: water still lacks dedicated lighting/reflections, weather lacks custom atmospheric treatment, and hand-water lacks its own translucent shading. Runtime tests are still required. The source-level analysis and next steps are tracked in [IRIS_PIPELINE_AUDIT.md](IRIS_PIPELINE_AUDIT.md).

## Post-deferred translucent preservation correction (2026-11-23)
Iris documentation specifies that deferred and composite passes read the main image and write the alternate image, then flip the pair after execution by default. This permits a composite-style pass to sample and write the same logical colortex attachment safely. The previous Serene colortex3-to-colortex0 copy-back was unsafe for the post-deferred geometry sequence: water/weather/hand-water can render after deferred, and copying an opaque-only colortex3 over colortex0 in composite could discard those later contributions.

The pipeline now writes deferred-lit opaque output directly to logical colortex0 (RENDERTARGETS: 0) and explicitly retains flip.deferred.colortex0=true. Translucent water, weather and hand-water then blend into the new main colortex0 image. Composite samples colortex0 and writes colortex0 with flip.composite.colortex0=true, preserving the accumulated scene. Explicit source-alpha blending is configured for the three post-deferred programs; water's auxiliary G-buffer outputs are unblended. This is an architectural correction based on Iris' documented buffer semantics, not yet an in-game validation. Water's fallback shading is still not equivalent to a dedicated forward-lit water implementation.

## Additional Iris contract corrections — 2026-11-23
- Shadow sampler filtering and update interval are declared as GLSL constants (`shadowHardwareFiltering`, `shadowIntervalSize`), not as `shaders.properties` keys.
- `separateAo` is disabled because the current G-buffer treats vertex alpha as material opacity; Iris moves AO into that alpha channel when `separateAo=true`.
- G-buffer alpha discard uses Iris `alphaTestRef`; entity tint uses Iris `entityColor`.
- Deferred reconstruction/AO uses `depthtex2` to exclude transparent and hand geometry.
- `particles.ordering=mixed` explicitly separates opaque particles before deferred from translucent particles after deferred.
- `separateEntityDraws` remains disabled due Iris' documented warning about newer versions.

### Deferred depth-mask refinement
The deferred pass reconstructs opaque world positions from `depthtex2` and compares it against `depthtex0` before shading. This prevents a hand or transparent fragment already present in scene color from being shaded using the opaque surface behind it.