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
- colortex2: normalized player/world-aligned normal encoded from [-1, 1] into [0, 1]. Alpha 0 marks pixels invalid for deferred surface lighting; alpha 0.5 marks valid zero-smoothness geometry; values above 0.5 pack material smoothness in the remaining range.

The terrain/entity vertex stages transform normals from view space back into player-aligned space using Iris' gbufferModelViewInverse. Their fragment stages sample the vanilla lightmap so the later deferred pass can retain its warm block-light and colored skylight response. The first-person hand path writes only colortex0; it is deliberately not treated as world geometry by the current deferred-data contract.

## Deferred lighting and attachment flow
The deferred fragment pass reads the G-buffer color, lightmap, normal and depth inputs. It reconstructs player-space position, transforms the surface into shadow space, applies slope-aware depth bias and evaluates four hardware-filtered shadow comparison taps.

**Iris attachment rule:** deferred and composite are composite-style passes. They read the main backing image and write the alternate backing image, then Iris flips the pair after the pass. Therefore deferred may read and write the same logical attachment (`colortex0`) safely through this documented mechanism. Deferred writes the lit opaque scene to logical colortex0 (`RENDERTARGETS: 0`); after the deferred flip, post-deferred translucent programs blend into the new main image. Composite then performs a colortex0-to-colortex0 pass-through with its own flip, preserving the accumulated scene. Gbuffers programs may sample a different colortex attachment, but must not sample an attachment they also write; Serene's validator checks the actual RENDERTARGETS/sampler intersection.

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
- `separateEntityDraws=true` is enabled according to the current Iris ordering documentation; `ENTITY_TRANSLUCENT` is queried through `iris.features.optional`.

### Deferred depth-mask refinement
The deferred pass reconstructs opaque world positions from `depthtex2` and compares it against `depthtex0` before shading. This prevents a hand or transparent fragment already present in scene color from being shaded using the opaque surface behind it.

## Atlas and lightmap contract corrections — 2026-11-23
- Terrain/entity/hand/shadow fragment shaders now use the Iris `gtexture` atlas sampler instead of naming a sampler `texture`, which Iris warns against in modern GLSL.
- Legacy `texture2D()` calls were replaced with `texture()`.
- Terrain/entity G-buffers normalize transformed sky-light coordinates using the Iris tutorial's documented range correction before storing the direct-light mask.

## Dimension-aware lighting
Deferred celestial lighting now uses Iris `hasSkylight` to avoid applying the Overworld sun/moon cycle in dimensions without skylight. The pack enables `endFlashShadows=true` and uses Iris `endFlashIntensity` when the End flash is the active shadow source. Shadow sampling is skipped when no direct-light contribution is possible.

## Water rendering path
`gbuffers_water` is now a dedicated post-deferred forward pass. It shades the water atlas color with the vanilla lightmap and Iris shadow map, uses the active dimension's celestial source, writes only the scene color attachment, and relies on the explicit source-alpha blend directive. This replaces the terrain G-buffer fallback, which was not appropriate after deferred. Water additionally uses a separate half-resolution scene copy for refraction and Fresnel-weighted screen-space reflections; animated waves, foam, absorption colour, caustics and underwater-specific response remain future work.

## Weather rendering path
`gbuffers_weather` is now a dedicated post-deferred forward pass. It uses Iris atlas and lightmap sampling, applies the provided fog parameters, writes only scene color and relies on source-alpha blending. `rain.depth=false` keeps weather out of the depth snapshots. Volumetric weather and wetness interaction remain future work.

## Iris fog pipeline
Opaque world surfaces receive Iris fog in deferred using the documented `fogColor`, `fogStart`, `fogEnd`, `fogDensity`, `fogMode` and `fogShape` uniforms. Post-deferred water, weather and translucent particles apply the same fog model in their forward fragment programs. Fog blending is performed in linearized color space.

## First-person translucent hand-water
`gbuffers_hand_water` is now a dedicated post-deferred forward pass. It preserves the vanilla lightmap response, applies Iris fog, writes only scene color and blends with source alpha. The ordinary hand shader remains the pre-deferred hand path.

## Translucent terrain scope
The `gbuffers_water` program is Iris' post-deferred translucent-terrain program, not a water-only callback. It covers water and other translucent terrain (e.g. stained glass). The current forward shader therefore uses generic surface lighting, vanilla lightmap, shadowing and fog. Fluid-only effects branch on the stable water material ID and Iris' `mc_Entity.y` fluid render type; only actual water receives depth opacity, refraction and reflection.

## Translucent material classification and water depth
The `gbuffers_water` vertex stage consumes Iris `mc_Entity` and passes the material ID and fluid render type to the fragment stage. `shaders/block.properties` assigns stable IDs to water, water cauldrons, lava, lava cauldrons and nether portals. The forward fragment stage applies depth-dependent opacity only to water/water-cauldron, using Iris `depthtex1` and `gbufferProjectionInverse` to reconstruct the opaque surface behind the water. Other translucent terrain keeps its own alpha. `WATER_FOG_MULT` controls the depth response.

## Water material handling
`gbuffers_water` is Iris' generic translucent-terrain pass. The vertex shader receives `mc_Entity`: `.x` is the custom block ID from `block.properties`, `.y` is the render type (`1.0` for fluids, `-1.0` for other blocks). Serene Ultra assigns ID 32000 to `minecraft:water` and applies water depth opacity only when both the ID and fluid type match. Thickness uses opaque-only `depthtex1` (available after deferred) and reconstructs view-space distance with `gbufferProjectionInverse`; the `far` uniform is not used as a projection plane because Iris defines it as render distance. Iris' `alphaTestRef` is used as the shader threshold and set to `0.0001` by the reference-matched `alphaTest.gbuffers_water=GREATER 0.0001` directive. The depth-opacity curve follows the same form as the Complementary reference. Refraction and Fresnel SSR are now implemented as source-level approximations. Full water parity still requires animated normal maps/waves, absorption tint, foam, caustics, underwater-specific response and runtime/visual calibration.

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
The separate translucent entity/block passes are active forward implementations. Current Iris ordering documentation explicitly states that `separateEntityDraws=true` moves translucent entities and block entities to these post-deferred programs. The pack also queries `ENTITY_TRANSLUCENT` through `iris.features.optional`. Runtime sorting, blending and version compatibility remain unverified.

## Translucent entity and particle pipeline
When Iris supports `ENTITY_TRANSLUCENT`, `separateEntityDraws=true` moves translucent entities and block entities after deferred. Serene Ultra implements dedicated forward-only programs for both. They preserve fractional alpha, sample the vanilla lightmap, apply the celestial shadow map and Iris fog, and blend into scene color only. The entity path uses Iris `entityColor` with its alpha blend factor.

Opaque and translucent particle paths now use a shared `PARTICLE_MATERIAL_FEATURES` boolean option with identical declarations. The translucent path ports Complementary-guided water-splash, Physics-mod rain/snow, underwater, campfire-smoke and emissive Ender/Crying Obsidian/Redstone/lava heuristics; it uses Iris `noisetex`, and rain/snow is gated by `hasSkylight` and `rainStrength`. Opaque particles write emissive strength into the R8 G-buffer channel. `WEATHER_TEX_OPACITY` is identically declared in the weather and translucent-particle programs. These remain baseline heuristics requiring visual calibration.

## Particle material path
The opaque and translucent particle paths both use the shared `PARTICLE_MATERIAL_FEATURES` option. Opaque particles store emissive material strength in colortex3; translucent particles are forward-lit and classify water splashes, physics rain/snow, underwater particles, campfire smoke and emissive ender/redstone/lava particles. The weather opacity option is identically declared in both `gbuffers_weather` and `gbuffers_particles_translucent`.

## Emissive material buffer
Opaque G-buffer programs write an RG8 material target in `colortex3`: red stores normalized emission strength and green stores oldPBR metalness or LabPBR dielectric F0/metal classification. Terrain samples Iris' `specular` atlas; red stores smoothness in both supported formats, blue supplies oldPBR emissiveness, and alpha supplies LabPBR emissiveness. Deferred reuses albedo for emissive tint and uses the packed reflectance for colored specular highlights. Lava remains supported by block-ID emission. The target is read-only during deferred and does not participate in scene-color flips.

## Basic overlays, block entities and damage cracks
`gbuffers_basic` handles leash/debug overlays as vertex-colored, fogged forward geometry and clears the deferred-validity mask. `gbuffers_damagedblock` handles the crack texture as a color-only overlay with Iris `alphaTestRef` at the Complementary-matched 0.004 threshold; it intentionally inherits the opaque block's underlying G-buffer lighting. `gbuffers_block` handles block entities and sign text using Iris `blockEntityId`. Sign text is fogged in this stage and marked as deferred-bypass so it does not inherit wooden-sign lighting. End portal/gateway IDs receive an emissive G-buffer value. Sign and portal IDs are assigned in `block.properties`. These paths are source/CI verified but still need runtime and visual checks.

## Emissive G-buffer bandwidth
The material attachment uses the GLSL buffer-format directive `const int colortex3Format = RG8;` in a block comment in `deferred.fsh`. Red stores normalized emission; green stores the scalar reflectance/metalness code. Compared with default RGBA8, RG8 uses two bytes instead of four per pixel, reducing this attachment's bandwidth/storage by 50% while retaining the material data needed for PBR highlights.

## Iris generic lit-texture fallback
`gbuffers_textured_lit` is implemented as a dedicated G-buffer path for lit particles and generic lit geometry. It writes albedo, vanilla lightmap, player-space normal and scalar emission to colortex0–3, uses Iris `alphaTestRef` at 0.01, and disables blending on opaque G-buffer outputs. Its particle material classification is guarded by the atlas-size threshold to avoid classifying the block atlas. The `gbuffers_terrain_solid` and `gbuffers_terrain_cutout` Iris additional programs intentionally use the documented fallback to `gbuffers_terrain`; this retains the valid `mc_Entity` attribute and the same block/fluid material classification without duplicating terrain shaders under names where that attribute is not documented.


## Iris-safe half-resolution water refraction and SSR
The Unbound water reference requires refraction and Fresnel reflections, but a gbuffers pass cannot safely sample and write the same logical scene-color attachment. Iris also requires all render targets written by one pass to have matching dimensions. Serene therefore keeps `deferred.fsh` full resolution and writing only `colortex0`. A separate `deferred1.fsh` pass runs after deferred and before translucent gbuffers; it reads the lit `colortex0` plus `depthtex0` / `depthtex2`, filters invalid hand/translucent samples, averages valid color in linear space, and writes only half-resolution `colortex4`.

The forward `gbuffers_water` pass reads `colortex4` and full-resolution `depthtex1` / `depthtex2`, but writes only `colortex0`. `depthtex1` validates opaque depth behind water for thickness/refraction; `depthtex2` provides opaque-only SSR intersections. The scene copy's alpha marks valid samples, and the water pass samples the half-resolution attachment at its own texture size. Fresnel SSR quality supports 4/6/8 steps; refraction and reflection strengths are user-adjustable. Water normals are oriented consistently in player and view space before shadowing/reflection calculations.

This pipeline is source/GLSL/structural validated, not in-game proven. It remains a low-bandwidth approximation of Unbound; animated multi-scale normals/waves, water noise colour, foam, full underwater response, environment/WSR reflection fallback, advanced SSR refinement and complete translucent PBR dispatch remain outstanding.


### Translucent shadow data
The shadow pass writes material transmission into Iris `shadowcolor0` (RGBA8). `shadowtex0` contains all shadow casters; `shadowtex1` contains opaque casters only. Deferred uses their center comparison to detect translucent blockers and applies the stored RGB transmission to direct/specular light. Recognized materials include water caustics, glass variants, ice and nether portal. The shadow color buffer is separate from the screen-space `colortex` G-buffer.
