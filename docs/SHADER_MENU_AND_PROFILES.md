# Shader Menu, Profiles and Color Controls

## User requirement
The shader must provide multiple user-selectable profiles and well-organized in-game settings screens. The menu takes inspiration from the supplied working reference shader's extensive menu, categories, labels and tooltips, while remaining an original Serene Ultra interface.

## Current profiles
These profiles are defined in `shaders/shaders.properties` and exposed through Iris' native profile selector:

| Profile | Current implemented preset behavior |
|---|---|
| Ultra-Light | 512 shadow map, 96 block shadow distance, neutral output |
| Smooth | 1024 shadow map, 128 block shadow distance, neutral output |
| Ultra | 2048 shadow map, 224 block shadow distance, neutral output |
| HDR | Ultra shadow settings with HDR-style tone mapping |
| Ultra-HDR | Ultra shadow settings with stronger highlight compression |

Important: profiles must never silently disable a reference Ultra feature. Lower profiles may tune sampling, resolution, shadow distance, filtering and reconstruction quality. Any feature-specific quality change must be explicit and documented. As new renderers land, each profile must configure their quality budgets consistently.

## Current menu screens
- Main screen: profile selector, Quality, Color.
- Quality: shadow-map resolution and shadow distance.
- Color: independent RGB channel gains, gamma, exposure, contrast, saturation and HDR tone-mapping mode.

The menu uses Iris-native `screen`, `sliders`, `profile.*` and `.lang` mechanisms. Labels and hover tooltips are localized in `shaders/lang/en_us.lang`.

## Color controls implemented
- Red, green and blue gain sliders.
- Gamma correction.
- Exposure in photographic stops.
- Contrast around a middle-gray pivot.
- Saturation.
- Neutral, HDR-style and Ultra-HDR-style tone mapping.

The HDR options are tone-mapping looks for the shader's current display output. They do not claim to activate true HDR output through the operating system, monitor, or Minecraft framebuffer.

## Future menu expansion
As each subsystem is implemented, add its controls to dedicated screens:
- Shadows and ambient occlusion.
- Lighting and colored lighting.
- Atmosphere, fog and clouds.
- Water, reflections and weather.
- Materials, POM, normals and emission.
- Anti-aliasing and temporal settings.
- Bloom and post-processing.
- Dimension and compatibility options.

Do not add decorative or non-functional controls. Every visible setting must affect a real implemented shader path and have a useful tooltip. Add profile mappings whenever new quality controls are introduced.


## Quality menu update — 2026-11-23
The Quality screen currently includes shadow-map resolution, shadow distance, shadow alpha cutoff, contact AO strength and contact AO radius. `AO_STRENGTH` now includes the 0.65 profile default in its Iris option value list so the profile value is a valid selectable option.

## Specular anti-aliasing — 2026-11-23
- Added derivative-based Toksvig-style roughness filtering to the deferred GGX direct-specular path.
- Pixel-scale normal variation increases effective roughness, reducing unstable sub-pixel highlights on detailed normal maps and distant geometry.
- `SPECULAR_AA_STRENGTH` is exposed in the Quality screen and configured in all five profiles; zero disables the derivative work.
- This is spatial specular filtering, not temporal anti-aliasing. TAA remains a separate pending feature.


## Four-scale bloom update — 2026-11-23
- Expanded the bloom pyramid from two scales to four: half, quarter, eighth and sixteenth resolution.
- Added two low-resolution separable Gaussian blur pairs for broader halos.
- `BLOOM_QUALITY` selects compact, wide or ultra-wide output; Ultra-Light uses compact bloom while Smooth and higher profiles use wider levels.
- The additional stages operate at low resolutions to limit cost on integrated GPUs.


## POM self-shadowing — 2026-11-23
- Added four-step tangent-space height-field light occlusion to terrain and block-entity parallax materials.
- The self-shadow factor attenuates the direct-light sky factor, preserving ambient light rather than darkening the entire material.
- `POM_SELF_SHADOW_STRENGTH` is exposed in Quality and scaled across all five profiles.
- Opaque entity-model POM self-shadowing remains pending.

- Added height-gradient slope normals for terrain, block entities and opt-in opaque entity models; the strength is exposed in Quality and scales across all five profiles.


## Temporal screen-space GI — 2026-11-23
- Added a persistent RGBA16F history buffer (`colortex12`) ping-ponged by the composite pass.
- Reprojects previous GI using Iris previous model-view/projection matrices and camera positions.
- Rejects history when the reprojected depth does not match; clamps history to the current spatial estimate to limit stale-light trails.
- Exposed `SCREEN_GI_TEMPORAL_STRENGTH` across all profiles. Ultra-Light disables history; higher profiles progressively increase accumulation.
- This stabilizes the GI contribution only; it is not full temporal anti-aliasing and does not handle moving-object velocity.


## Roughness-aware opaque reflections — 2026-11-23
- Added depth-rejected four-neighbor filtering at the SSR hit location.
- Blur radius scales with squared material roughness, while depth rejection avoids mixing foreground/background surfaces.
- Exposed `PBR_REFLECTION_BLUR_STRENGTH` in Quality and across all profiles; Ultra-Light disables the extra samples.


## Temporal contact AO — 2026-11-23
- Added a persistent RGBA16F history buffer (`colortex13`) for contact AO.
- Reprojects previous AO using Iris previous camera matrices and camera positions, rejects depth mismatches, and clamps history within a narrow range around the current AO estimate.
- Added `AO_TEMPORAL_STRENGTH` to Quality and all five profiles; Ultra-Light disables history.
- This is temporal AO stabilization, not full temporal AA; moving-object velocity is not represented.


## Shader-level anisotropic material filtering — 2026-11-23
- Added sprite-bounded major-derivative sampling for albedo, normal and specular atlases in terrain, block entities and opaque entity models.
- Added 1/2/4-tap quality tiers with per-profile budgets; Ultra-Light remains single-sample, higher tiers enable 2 or 4 taps.
- Sampling clamps to Iris per-quad sprite bounds to avoid atlas bleed. Hardware anisotropy remains complementary and can still be used through Minecraft/Iris texture settings.


## Overworld sky effects — 2026-11-23
- Added procedural multi-scale nebulae and animated aurora curtains to clear night skies, with rain suppression.
- Added a spectral anti-solar rainbow arc when rain and direct sunlight overlap.
- Added a dedicated Atmosphere menu and explicit profile budgets; Ultra-Light disables the effects to preserve integrated-GPU headroom.

- Added a dedicated Nether ember-storm control and End nebula/distant-star control to the Atmosphere screen, with explicit profile budgets.
