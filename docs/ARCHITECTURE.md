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
At the initial audit stage, the pack lacked dedicated `gbuffers_water`, `gbuffers_weather` and `gbuffers_hand_water` programs. **Superseded for water:** a dedicated post-deferred forward `gbuffers_water` pair is now present and samples the Iris atlas, lightmap and shadow map. Advanced water effects (refraction, Fresnel/reflections, absorption/depth tint, wave normals and rain interaction) remain outstanding. Weather and hand-water now also have dedicated post-deferred forward paths using Iris lightmap/fog inputs and color-only outputs; advanced weather effects and dynamic held-item lighting remain pending. Runtime tests are still required. The source-level analysis and next steps are tracked in [IRIS_PIPELINE_AUDIT.md](IRIS_PIPELINE_AUDIT.md).

## Post-deferred translucent preservation correction (2026-11-23)
Iris documentation specifies that deferred and composite passes read the main image and write the alternate image, then flip the pair after execution by default. This permits a composite-style pass to sample and write the same logical colortex attachment safely. The previous Serene colortex3-to-colortex0 copy-back was unsafe for the post-deferred geometry sequence: water/weather/hand-water can render after deferred, and copying an opaque-only colortex3 over colortex0 in composite could discard those later contributions.

The pipeline now writes deferred-lit opaque output directly to logical colortex0 (RENDERTARGETS: 0) and explicitly retains flip.deferred.colortex0=true. Translucent water, weather and hand-water then blend into the new main colortex0 image. Composite samples colortex0 and writes colortex0 with flip.composite.colortex0=true, preserving the accumulated scene. Explicit source-alpha blending is configured for the three post-deferred programs; water's auxiliary G-buffer outputs are unblended. This is an architectural correction based on Iris' documented buffer semantics, not yet an in-game validation. At the time of this historical correction, water still used the terrain fallback. This was superseded on 2026-11-23 by the dedicated forward `gbuffers_water` program; advanced water effects and runtime validation remain pending.

## Additional Iris contract corrections — 2026-11-23
- Shadow sampler filtering and update interval are declared as GLSL constants (`shadowHardwareFiltering`, `shadowIntervalSize`), not as `shaders.properties` keys.
- `separateAo` is disabled because the current G-buffer treats vertex alpha as material opacity; Iris moves AO into that alpha channel when `separateAo=true`.
- G-buffer alpha discard uses Iris `alphaTestRef`; entity tint uses Iris `entityColor`.
- Deferred reconstruction/AO uses `depthtex2` to exclude transparent and hand geometry.
- `particles.ordering=mixed` explicitly separates opaque particles before deferred from translucent particles after deferred.
- `separateEntityDraws` remains disabled due Iris' documented warning about newer versions.

### Deferred depth-mask refinement
The deferred pass reconstructs opaque world positions from `depthtex2` and compares it against `depthtex0` before shading. This prevents a hand or transparent fragment already present in scene color from being shaded using the opaque surface behind it.

## Atlas and lightmap contract corrections — 2026-11-23
- Terrain/entity/hand/shadow fragment shaders now use the Iris `gtexture` atlas sampler instead of naming a sampler `texture`, which Iris warns against in modern GLSL.
- Legacy `texture2D()` calls were replaced with `texture()`.
- Terrain/entity G-buffers normalize transformed sky-light coordinates using the Iris tutorial's documented range correction before storing the direct-light mask.

## Dimension-aware lighting
Deferred celestial lighting now uses Iris `hasSkylight` to avoid applying the Overworld sun/moon cycle in dimensions without skylight. The pack enables `endFlashShadows=true` and uses Iris `endFlashIntensity` when the End flash is the active shadow source. Shadow sampling is skipped when no direct-light contribution is possible.

## Water rendering path
`gbuffers_water` is now a dedicated post-deferred forward pass. It shades the water atlas color with the vanilla lightmap and Iris shadow map, uses the active dimension's celestial source, writes only the scene color attachment, and relies on the explicit source-alpha blend directive. This replaces the terrain G-buffer fallback, which was not appropriate after deferred. Advanced water effects remain future work.

## Weather rendering path
`gbuffers_weather` is now a dedicated post-deferred forward pass. It uses Iris atlas and lightmap sampling, applies the provided fog parameters, writes only scene color and relies on source-alpha blending. `rain.depth=false` keeps weather out of the depth snapshots. Volumetric weather and wetness interaction remain future work.

## Iris fog pipeline
Opaque world surfaces receive Iris fog in deferred using the documented `fogColor`, `fogStart`, `fogEnd`, `fogDensity`, `fogMode` and `fogShape` uniforms. Post-deferred water, weather and translucent particles apply the same fog model in their forward fragment programs. Fog blending is performed in linearized color space.

## First-person translucent hand-water
`gbuffers_hand_water` is now a dedicated post-deferred forward pass. It preserves the vanilla lightmap response, applies Iris fog, writes only scene color and blends with source alpha. The ordinary hand shader remains the pre-deferred hand path.

## Translucent terrain scope
The `gbuffers_water` program is Iris' post-deferred translucent-terrain program, not a water-only callback. It covers water and other translucent terrain (e.g. stained glass). The current forward shader therefore uses generic surface lighting, vanilla lightmap, shadowing and fog. Fluid-only effects must branch on Iris' `mc_Entity.y` attribute and will be implemented only after comparison with the supplied reference source.

## Translucent material classification and water depth
The `gbuffers_water` vertex stage consumes Iris `mc_Entity` and passes the material ID and fluid render type to the fragment stage. `shaders/block.properties` assigns stable IDs to water, water cauldrons, lava, lava cauldrons and nether portals. The forward fragment stage applies depth-dependent opacity only to water/water-cauldron, using Iris `depthtex1` and `gbufferProjectionInverse` to reconstruct the opaque surface behind the water. Other translucent terrain keeps its own alpha. `WATER_FOG_MULT` controls the depth response.

## Water material handling
`gbuffers_water` is Iris' generic translucent-terrain pass. The vertex shader receives `mc_Entity`: `.x` is the custom block ID from `block.properties`, `.y` is the render type (`1.0` for fluids, `-1.0` for other blocks). Serene Ultra assigns ID 32000 to `minecraft:water` and applies water depth opacity only when both the ID and fluid type match. Thickness uses opaque-only `depthtex1` (available after deferred) and reconstructs view-space distance with `gbufferProjectionInverse`; the `far` uniform is not used as a projection plane because Iris defines it as render distance. Iris' `alphaTestRef` is used as the shader threshold and set to `0.0001` by the reference-matched `alphaTest.gbuffers_water=GREATER 0.0001` directive. The depth-opacity curve follows the same form as the Complementary reference. This is not yet the full water material: refraction, Fresnel reflections, wave normals, foam and absorption tint remain planned.

## Special geometry overlay handling
Armor glint, beacon beams and lightning are rendered in dedicated Iris gbuffers programs before deferred. Their forward fragment paths write scene color and clear the colortex2 deferred-validity mask, preventing the opaque normal beneath an overlay from being reused. Armor glint keeps the game-managed blend state; beacon beams and lightning apply Iris fog. Lightning's separate depth path is provided by `gbuffers_basic` according to Iris' program documentation.

The current water baseline additionally matches the Complementary reference's low alpha-test threshold and square-root water alpha shaping. Opaque depth is read using an exact-pixel `texelFetch` from `depthtex1`, avoiding filtering and normalized UV calculations.

## Weather and cloud paths
`gbuffers_weather` uses the reference's rain/snow texture classification and default alpha multipliers, with a user opacity control. It uses Iris `alphaTestRef`, `isEyeInWater`, `rainStrength` and `eyeBrightnessSmooth` for powdered-snow suppression and optional vertex motion. `gbuffers_clouds` is a dedicated pre-deferred overlay that preserves vanilla cloud texture/vertex tint, applies Iris fog, hides clouds while the camera is submerged, and clears the deferred normal mask. Custom volumetric clouds remain a later feature.

## Textured fallback and sky
The `gbuffers_textured` path preserves unlit texture/vertex color and Iris fog while clearing deferred-normal validity. `gbuffers_skytextured` uses Iris render-stage macros to identify sun/moon textures, applying rain and underwater dimming. `gbuffers_skybasic` builds a lightweight sky gradient from Iris `skyColor` and `fogColor`, with distinct sunset, stars and void handling. These baseline paths keep overlays out of opaque deferred lighting; full atmospheric scattering and custom sky systems remain future work.

## Sky and unlit geometry
Iris routes sky/horizon, stars and void through `gbuffers_skybasic`, and sun/moon textures through `gbuffers_skytextured`. The pack implements these as dedicated programs using the documented `renderStage` uniform and `MC_RENDER_STAGE_*` macros. Celestial positions are read from Iris `sunPosition` and `moonPosition` (view space, length 100) and compared against the view-space up vector. Sky/fog colors are converted to linear space in the vertex stage, while the sky-basic fragment shader reconstructs direction only for sky/sunset stages. `gbuffers_textured` provides a fogged unlit atlas fallback for world border and unlit particles. All sky/overlay paths clear the deferred-validity mask and disable blending on that attachment. CI compiles the render-stage branches with explicit macro definitions; visual parity remains pending.

## Line overlays
`gbuffers_line` is a dedicated forward overlay. It preserves vertex color, applies Iris fog to ordinary lines, skips fog for selection outlines and debug lines using Iris render-stage macros, and clears the deferred-normal validity mask.

## Translucent particle lighting
The post-deferred `gbuffers_particles_translucent` path forward-shades particles using vanilla lightmap data, player-space normals/positions, the active celestial source, one hardware-filtered shadow lookup and Iris fog. The one-tap shadow lookup is the low-cost integrated-GPU baseline. Special particle material/emission handling remains future work.

## Iris entity-translucency compatibility
The separate translucent entity/block passes are retained as dormant forward implementations. They are not enabled because current Iris documentation warns that `separateEntityDraws` is broken in newer versions. The active configuration keeps `separateEntityDraws=false`, and the validator prevents accidental activation.

## Translucent entity and particle pipeline
When Iris supports `ENTITY_TRANSLUCENT`, `separateEntityDraws=true` moves translucent entities and block entities after deferred. Serene Ultra implements dedicated forward-only programs for both. They preserve fractional alpha, sample the vanilla lightmap, apply the celestial shadow map and Iris fog, and blend into scene color only. The entity path uses Iris `entityColor` with its alpha blend factor.

The translucent-particle path uses Complementary Reimagined's material-color heuristics as reference, guarded by particle-atlas width so the block atlas is not misclassified. It recognizes water splashes, Physics-mod rain/snow, underwater particles, campfire smoke, Ender/Crying Obsidian/Redstone particles and lava particles. It uses Iris `noisetex` for the water-splash dither, shares the weather opacity control, and gates rain/snow handling on `hasSkylight` and `rainStrength`. Emissive Ender-family particles suppress lightmap/celestial lighting and skip shadow sampling. These are baseline heuristics and require visual validation against the supplied working shader.

## Particle material path
The translucent particle path has an optional Complementary-guided material classifier for water splashes, physics rain/snow, underwater particles, campfire smoke and emissive ender/redstone/lava particles. It uses Iris `noisetex` for water-particle dithering and runtime skylight/rain uniforms for weather gating. Emission is added after surface lighting and avoids a shadow lookup. Opaque particle classification remains future work.

## Emissive material buffer
Opaque G-buffer programs write a dedicated RGBA8 emissive target in `colortex3`. Terrain classification uses Iris `mc_Entity` and `block.properties` IDs; deferred adds tinted emission after AO/direct lighting and before fog. Lava is emitted directly in the post-deferred fluid pass. The target is read-only during deferred and does not participate in scene-color flips. Full material/emission maps and bloom are not yet implemented.