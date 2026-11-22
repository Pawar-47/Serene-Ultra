# Reference Ultra Feature Preservation Matrix

## Two-reference engineering rule (mandatory)
Both supplied shader archives are active technical references, not merely one engine reference plus one visual mood board. Consult both when designing, reviewing, debugging or validating a rendering feature. When uncertain whether an approach, formula, interface, shader stage, texture lookup, buffer, pass order or code path is correct, inspect the corresponding/relevant files in **both** archives, compare how each achieves or expects the behavior, and record the evidence before choosing an implementation. If the files are not directly equivalent, trace the related stages and shared inputs/outputs rather than forcing a one-file match. Use Vanilla-stock to establish Minecraft 26.3's native contracts and behavior; use the working shader to understand proven feature implementation, visual treatment, quality controls and Ultra expectations. Then write an original Serene Ultra implementation that respects the stock engine contract while pursuing the reference's visual contribution, adapted for Intel HD 5500 without dropping Ultra features. Do not blindly copy either source, and do not claim a comparison was performed unless the relevant files were actually inspected.


**Status:** Inventory baseline created; implementation and parity verification are pending.
**Rule:** Every feature found in the supplied reference's Ultra profile must have an explicit disposition. "Optimized" does not mean removed. A feature may be marked complete only after code inspection and visual/runtime validation.

The supplied archive is a Complementary Reimagined shaderpack. Its source is not copied into Serene Ultra; this matrix records feature categories and the work required for an independent implementation.

| Feature family | Required Ultra capability | Serene implementation plan | Status |
|---|---|---|---|
| Terrain/material pipeline | Material-aware terrain rendering and material-specific behavior | Albedo, sampled vanilla lightmap RGB and world-aligned normal G-buffer capture; material classification remains next | Partial |
| Entity rendering | Entity-specific shading and shadows | Entity albedo, sampled lightmap and normal capture with alpha cutoff | Partial |
| Hand/item rendering | Correct first-person hand/item rendering | Hand lightmap path, dedicated post-deferred hand-water path and held-item light follow-up | Partial |
| Shadow mapping | Sun/moon directional shadows | Depth reconstruction and directional shadow comparison | Partial |
| Shadow caster alpha | Transparent texels discarded so foliage/fences cast shaped rather than solid shadows | Texture-aware shadow fragment test with user-adjustable alpha threshold | Implemented; runtime verification pending |
| Shadow filtering | Soft filtered shadows and quality controls | Four hardware-filtered comparison taps with slope-aware bias; stability/quality tuning remains | Partial |
| Ambient occlusion | Contact/local occlusion | Eight-neighbor depth-based screen-space contact AO; edge-aware and temporal refinement remains | Partial |
| Direct lighting | Directional lighting and block light response | Iris sunAngle cyclic solar-elevation curve (dawn/noon/sunset/night) for celestial diffuse, combined with sampled vanilla lightmap ambient | Partial; source correction committed, runtime/parity pending |
| Colored lighting | Colored block/emissive light response | Preserve vanilla lightmap RGB; custom colored-light propagation and emissive response remain | Partial |
| Indirect lighting / GI | Bounced/indirect illumination appearance | Screen-space/temporal approximation; preserve visual contribution | Pending |
| Volumetric lighting | Light shafts and volumetric scattering | Depth-aware low-resolution integration and reconstruction | Pending |
| Atmospheric scattering | Sky color, horizon and atmospheric depth | Analytic atmosphere with shared sky/lighting parameters | Pending |
| Fog | Distance, height and dimension-aware fog | Iris fog modes/shape in deferred and forward water/weather/particle/hand-water paths | Partial; source paths implemented, runtime tuning pending |
| Clouds | Procedural/cloud-layer appearance and lighting | Procedural cloud system with adaptive sampling | Pending |
| Water surface | Unbound-style water tint, transparency, normals and forward lighting | Dedicated `gbuffers_water`; fluid-gated depth opacity, half-resolution refraction, Fresnel SSR, lightmap/shadow/fog | Partial; waves, foam, absorption colour, underwater response and runtime parity pending |
| Water reflections | Reflected scene/sky and Fresnel response | Fresnel-weighted screen-space ray march (4/6/8 steps) using half-resolution scene colour and full-resolution opaque depth | Partial; sky-depth hits work, but environment/WSR fallback and advanced refinement remain pending |
| Block reflections | Reflective material response | Material masks and screen-space/fallback reflections | Pending |
| Rain/wetness | Rain response and wet surfaces | Weather/material masks and roughness response | Pending |
| Puddles | Rain puddles and surface reflections | Surface classification and puddle masks | Pending |
| Parallax/POM | Parallax occlusion material detail | Bounded ray steps and distance/material gating | Pending |
| Texture filtering | Texture quality and anisotropic behavior | Hardware filtering where supported; quality controls | Pending |
| TAA | Temporal anti-aliasing | Motion-aware history, rejection and sharpening controls | Pending |
| Other anti-aliasing | Additional AA modes/quality settings | Configurable AA path and edge validation | Pending |
| Bloom/emissive | Emissive contribution and glow/post effects | Thresholded multi-scale bloom with bandwidth-aware buffers | Pending |
| Color grading | Tonemapping, exposure, saturation and contrast | Reference-matched color pipeline | Foundation; parity pending |
| Depth of field | Focus/depth post-processing if present in Ultra | Depth-aware bounded blur | Pending |
| Motion blur | Motion-dependent post-processing if present | Velocity-aware path; avoid ghosting | Pending |
| Lens/post effects | Any enabled Ultra lens and post-processing effects | Individually inventoried and switchable | Pending |
| Text rendering | Correct text/UI treatment and compatibility | Preserve vanilla UI/text; no destructive post-processing | Pending |
| Weather | Rain/snow and weather-dependent material/lighting | Dedicated forward weather path with Iris lightmap/fog; volumetric and wetness effects remain | Partial |
| Dimension support | Overworld, Nether, End and special dimensions | Iris hasSkylight gating plus End-flash shadow source; full per-dimension atmosphere/material tuning remains | Partial |
| Night vision/potions | Correct vanilla effect interactions | Explicit effect compatibility tests | Pending |
| Emissive entities/blocks | Correct emissive response | Dedicated spider/enderman/dragon eye pass bypasses deferred lighting; broader emissive classification remains | Partial |
| Translucent materials | Glass, foliage, water and particles | Dedicated water/weather/hand-water/translucent-particle forward paths; glass/other translucent entity handling remains | Partial |
| Foliage | Alpha-tested leaves/grass and wind response if present | Alpha-aware shadow casters are started; material animation and parity remain | Partial |
| Voxelization/SSBO-dependent effects | Reference's voxel/structured-buffer features | Determine visible Ultra contribution; implement a hardware-compatible alternative where needed | Pending |
| Profiles/settings | Full reference Ultra quality controls | Serene Ultra master profile plus scalable implementation controls | Foundation |
| Iris compatibility | Shaderpack lifecycle and supported uniforms/programs | Iris source contracts, GLSL compile, vertex/fragment link and structural CI | Source validation passing; Minecraft/Iris runtime pending |

## Audit follow-up required

The initial archive inventory recorded:
- 446 files total, 437 under shaders/.
- Render-target usage across colortex0–8, colortex12–14, and colortex18–19.
- Dedicated world/dimension folders, material libraries, voxelization/SSBO code, antialiasing, atmospheric, lighting, reflection, text and utility modules.
- Quality profiles including POTATO through ULTRA and COMPLEMENTARY.

Next audit pass must extract the actual Ultra profile values and enumerate every program, define, material branch, render target, and post-processing stage. This matrix is intentionally conservative and must be expanded rather than treating its current rows as exhaustive.

## Latest implementation note

The G-buffer preserves base albedo in colortex0, sampled vanilla lightmap RGB plus sky-light factor in colortex1, and encoded player-aligned normals in colortex2 for terrain and entities. Deferred reads those buffers and depth, then writes lit output to logical colortex0 through Iris' main/alternate buffer flip. Post-deferred translucent geometry blends into that lit scene, and composite performs a colortex0 pass-through with its own flip to preserve the accumulated result. The deferred pass includes directional celestial lighting, four hardware-filtered shadow comparison taps and eight-neighbor contact AO that attenuates ambient only. The hand and sky remain unchanged by deferred world lighting. These paths are initial implementations only; visual parity and runtime stability remain unverified.


## Iris program coverage audit (2026-11-23)
The current source explicitly implements `gbuffers_water`, `gbuffers_weather`, `gbuffers_hand_water`, `gbuffers_particles`, `gbuffers_particles_translucent` and `gbuffers_spidereyes`. All three post-deferred translucent programs use color-only forward outputs with Iris lightmap/fog handling; water additionally implements depth opacity, half-resolution refraction and Fresnel SSR. Advanced Unbound water/weather effects and all runtime/visual parity checks remain pending. See [IRIS_PIPELINE_AUDIT.md](IRIS_PIPELINE_AUDIT.md) and [UNBOUND_REFERENCE_AUDIT.md](UNBOUND_REFERENCE_AUDIT.md).

Do not equate Iris fallback coverage with correct feature implementation. The matrix must track both the native geometry category and the actual Iris program that receives it.

## Post-deferred scene preservation correction
The old colortex3-to-colortex0 copy-back has been removed. Deferred and composite use Iris main/alternate flips. Water, weather and hand-water have explicit source-alpha blend rules on colortex0. The water scene copy is produced separately by half-resolution `deferred1` into `colortex4`; `gbuffers_water` samples this separate attachment and never reads its own `colortex0` output. This is source-level architecture, not runtime proof.

## Iris contract correction status — 2026-11-23
| Area | Corrected source contract | Remaining validation |
|---|---|---|
| Shadow filtering | GLSL `const bool shadowHardwareFiltering = true` | Iris runtime sampler binding and visual PCF |
| Shadow update interval | GLSL `const float shadowIntervalSize = 2.0` | Runtime update cadence |
| Vertex AO alpha | `separateAo=false` to preserve material alpha | Revisit only when AO has a separate G-buffer channel |
| Cutout alpha | `alphaTestRef` uniform in terrain/entities/hand | Runtime cutout edge checks |
| Entity tint | `entityColor` tint blended in linear space using its alpha | Damage/team/potion tint checks |
| Deferred depth | `depthtex2` opaque-world reconstruction plus `depthtex0` hand/translucent mask | Verify all target-version depth stages in game |
| Particle ordering | `particles.ordering=mixed` | Dedicated opaque G-buffer and translucent forward particle programs |

Do not mark these as fully validated until Iris/Minecraft runtime checks are performed.

## Iris atlas/lightmap correction status — 2026-11-23
| Area | Current implementation | Remaining validation |
|---|---|---|
| Block/entity atlas | `gtexture` sampler | Resource-pack atlas and modded texture checks |
| GLSL sampling | `texture()` function | Target Iris compiler/runtime check |
| Sky light coordinate | Iris transformed-coordinate normalization before storing G-buffer mask | Compare light levels across time/weather/dimensions |


## Particle coverage update — 2026-11-23
The two particle programs are now implemented:
- Opaque `gbuffers_particles` writes the three G-buffer attachments for deferred lighting.
- Translucent `gbuffers_particles_translucent` is a post-deferred forward path with vanilla lightmap response and explicit alpha blending.
This replaces the earlier 'missing particle programs' entry. Material-specific particle behavior and runtime parity still require testing.

## First-person hand path update — 2026-11-23
The hand fragment shader now samples the Iris `lightmap` texture using `gl_TextureMatrix[1]`-transformed lightmap coordinates and applies its RGB response. This corrects the earlier albedo-only hand path. Dynamic held-item emission using Iris `heldBlockLightValue` and `heldBlockLightValue2` remains outstanding.

## Emissive eye path update — 2026-11-23
A dedicated `gbuffers_spidereyes` program now writes emissive eye color and marks those pixels as ineligible for opaque deferred lighting, preventing the body normal behind the eyes from shading the emissive overlay.

## Water program update — 2026-11-23
Dedicated `gbuffers_water` replaces the terrain fallback. It forward-shades translucent terrain after deferred using the Iris atlas, vanilla lightmap, normals, shadow map and dimension-aware celestial source. Water-only effects are gated by stable material ID plus Iris fluid render type. Water depth opacity, half-resolution refraction and Fresnel SSR are implemented; waves, absorption colour, foam and underwater response remain pending.

## Weather program update — 2026-11-23
Dedicated `gbuffers_weather` now replaces the textured-lit fallback. It forward-shades rain/snow using the Iris lightmap and fog uniforms, writes only colortex0, and retains source-alpha blending. `rain.depth=false` keeps it out of scene depth. Volumetric rain/snow, wind-aware streaks, wetness interaction and reference parity remain pending.

## Fog coverage update — 2026-11-23
| Program path | Fog implementation | Status |
|---|---|---|
| Opaque terrain/entities/particles | Deferred Iris fog using fogColor/start/end/density/mode/shape | Implemented at source level |
| Water | Forward Iris fog, depth opacity, half-resolution refraction and Fresnel SSR in `gbuffers_water` | Implemented at source level; runtime/visual validation pending |
| Weather | Forward Iris fog in `gbuffers_weather` | Implemented at source level |
| Translucent particles | Forward Iris fog in `gbuffers_particles_translucent` | Implemented at source level |
| Hand-water | Dedicated forward color-only path with lightmap and Iris fog | Implemented at source level; runtime check pending |


## Hand-water program update — 2026-11-23
Dedicated `gbuffers_hand_water` now replaces the ordinary hand fallback for post-deferred first-person translucent geometry. It samples the Iris atlas and lightmap, applies Iris fog and writes color only with source-alpha blending.

## Translucent terrain scope correction — 2026-11-23
Iris' `gbuffers_water` program handles all translucent terrain, including but not limited to water. Serene keeps a generic forward-lit translucent surface path for non-water materials and gates water-only opacity/refraction/reflection on both the stable water material ID and Iris' `mc_Entity.y` fluid render type (`1.0` for fluids, `-1.0` for other translucent terrain).

## Water depth-opacity update — 2026-11-23
The generic `gbuffers_water` translucent-terrain path now uses Iris `mc_Entity` material IDs to isolate actual water/water-cauldron from glass and portals. It reads opaque-only `depthtex1` and reconstructs the underlying view-space distance to apply depth-dependent water opacity. `WATER_FOG_MULT` exposes the reference-style 25–900% control range. This is a first reference-guided water-material feature; it is not yet full water parity.

## Water path update — 2026-11-23
| Iris contract | Implementation |
|---|---|
| `mc_Entity.x` maps to `block.properties` ID; `.y` is fluid render type | Water branch requires ID 32000 and fluid type `> 0.5` |
| `depthtex1` excludes transparent geometry and is valid from deferred onward | Water thickness samples it in post-deferred `gbuffers_water` |
| `far` is render distance, not the projection far plane | Clear depth and opaque depth are reconstructed through `gbufferProjectionInverse` |
| Iris alpha-test contract | Water shader uses `alphaTestRef`, set to `GREATER 0.0001` by the Complementary-matched `alphaTest.gbuffers_water` directive |

The depth-opacity calculation follows the same thickness/exponential form used by Complementary. Half-resolution refraction and Fresnel SSR are now present; advanced Unbound water materials remain pending.

## Special overlay coverage — 2026-11-23
Dedicated paths now exist for armor glint, beacon beams and lightning. Each writes color and clears the deferred-normal validity mask so overlays are not shaded using the opaque surface beneath them. Armor-glint color blending remains under Minecraft/Iris' active render state. Beacon beams and lightning receive Iris fog. Runtime depth/blend validation remains pending.

Reference refinement: retained `alphaTest.gbuffers_water=GREATER 0.0001` (matching Complementary Reimagined), used Iris `alphaTestRef` in the shader, applied the reference `sqrt(alpha)` water shaping, and switched to exact-pixel `texelFetch` for opaque depth.

## Weather/cloud feature update — 2026-11-23
- Weather: reference-style rain/snow texture classification and alpha multipliers; adjustable `WEATHER_TEX_OPACITY`; Iris `alphaTestRef`; powdered-snow camera suppression; optional wind motion using Iris `rainStrength` and `eyeBrightnessSmooth`.
- Vanilla clouds: dedicated forward pass preserves vanilla texture/vertex lighting, applies Iris fog, hides clouds underwater/in fluids, and clears the deferred normal-validity mask.
- Custom cloud layers, volumetric clouds, cloud shadows and cloud reflections remain pending.

## Textured and sky program coverage — 2026-11-23
- `gbuffers_textured`: dedicated unlit texture fallback with Iris alpha test/fog and deferred-normal bypass; game blend state is preserved.
- `gbuffers_skytextured`: uses Iris render-stage macros to distinguish sun/moon textures and applies rain/underwater dimming.
- `gbuffers_skybasic`: uses `skyColor`/`fogColor` and Iris render stages for sky gradient, sunset band, stars and void; direction reconstruction is skipped for stars/void.
- All three clear colortex2 validity for overlays. Full atmospheric scattering, custom stars/clouds and lit textured-particle parity remain pending.

## Sky and fallback geometry — 2026-11-23
| Iris program | Geometry | Current implementation |
|---|---|---|
| `gbuffers_skybasic` | Sky/horizon, stars, void | Render-stage-specific gradient, twilight and void handling; deferred validity mask cleared |
| `gbuffers_skytextured` | Sun and moon textures (also leaves custom sky textures unchanged) | Render-stage sun/moon tint, rain attenuation and low alpha threshold |
| `gbuffers_textured` | World border and unlit-texture particle fallback | Atlas/vertex color, Iris fog and deferred validity mask cleared |
| `gbuffers_clouds` | Vanilla clouds | Preserves atlas RGB and vertex alpha; hides clouds underwater; deferred validity mask cleared |

Render-stage macro names and celestial uniforms were checked against current Iris documentation. These are baseline implementations, not yet visual parity with Complementary Ultra.

## Line overlays — 2026-11-23
Dedicated `gbuffers_line` now handles line geometry, using Iris `renderStage` macros to skip fog on selection outlines/debug lines while fogging ordinary lines. It clears deferred-normal validity and leaves color blending to the game.

## Translucent particles — 2026-11-23
`gbuffers_particles_translucent` forward-lights post-deferred particles using player-space normals/positions, vanilla lightmap, day/night/End-flash direct light, one hardware-filtered shadow comparison and Iris fog. Its material option ports Complementary-guided water-splash, physics rain/snow, underwater, smoke and emissive heuristics; opaque ender/redstone/crying-obsidian/lava emission is also written to the scalar G-buffer. Visual material calibration remains pending.

## Entity translucent gate — 2026-11-23
`separateEntityDraws=true` is active as documented by Iris. The pack queries `ENTITY_TRANSLUCENT` as an optional feature and uses dedicated forward entity/block-entity programs after deferred. Runtime sorting and blending still require testing.

## Translucent entity coverage — 2026-11-23
| Iris program | Geometry | Current implementation |
|---|---|---|
| `gbuffers_entities_translucent` | Translucent entities | Active forward lightmap + celestial shadow + Iris fog; applies `entityColor`; source-alpha blend |
| `gbuffers_block_translucent` | Translucent block entities | Forward lightmap + celestial shadow + Iris fog; source-alpha blend |

Enabled with `separateEntityDraws=true` and `iris.features.optional=ENTITY_TRANSLUCENT`. The programs write only colortex0 after deferred; runtime compatibility remains to be checked.

## Particle material effects — 2026-11-23
`PARTICLE_MATERIAL_FEATURES` is shared by opaque, translucent and generic lit-fallback particle paths. The opaque path writes reference-aligned ender/redstone/crying-obsidian/lava emission into colortex3; the translucent path uses forward lightmap/shadow/fog and ports Complementary-guided water splash, physics rain/snow, underwater, campfire-smoke and emissive heuristics. It uses Iris `noisetex` with `textureLod(noisetex, gl_FragCoord.xy / 128.0, 0.0)` to match the working reference's dither scale; rain/snow detection is gated by runtime `hasSkylight` and `rainStrength`.

## Iris generic lit-texture fallback — 2026-11-23
`gbuffers_textured_lit` now has a dedicated G-buffer vertex/fragment pair, matching the Iris fallback table for most lit particles. It writes albedo, lightmap, player-space normal and scalar emission to colortex0–3, applies Iris `alphaTestRef` at 0.01, and disables blending on the opaque G-buffer attachments. The generic path reuses the same atlas-size-guarded particle material classifier. `gbuffers_terrain_solid` and `gbuffers_terrain_cutout` deliberately retain the documented fallback to `gbuffers_terrain`, which is also the program where Iris exposes `mc_Entity` for stable block/fluid IDs.

## Emissive materials — 2026-11-23
A compact single-channel R8 `colortex3` emission buffer is now written by opaque G-buffer programs. Terrain uses Iris `mc_Entity` plus `block.properties` IDs to classify luminous blocks; deferred adds their tinted emission after AO/direct lighting and before fog. Opaque particle paths use the Complementary grayscale-texture, channel-ratio and lava predicates to write emissive strength. Richer entity/resource-pack material maps and bloom remain pending.

## Core overlay/block-entity coverage — 2026-11-23
| Iris program | Geometry | Current implementation |
|---|---|---|
| `gbuffers_basic` | Leash and debug chunk-border overlay | Vertex color + Iris fog; clears deferred-validity mask |
| `gbuffers_damagedblock` | Block-breaking texture | Color-only crack overlay; `alphaTestRef` set to 0.004 |
| `gbuffers_block` | Block entities and sign text | Four-target G-buffer; sign text fogged and bypasses deferred lighting; portal/gateway emission ID |

`block.properties` maps sign families to ID 5004 and End portal/gateway to 5025, read through Iris `blockEntityId`.

Emissive data is now a single R8 scalar in colortex3; deferred reuses scene albedo for its color. This reduces the emissive attachment footprint/bandwidth by 75% compared with default RGBA8, with negligible quantization error for the current material levels.

## Complementary Unbound water/material parity — 2026-11-23
The primary visual/material reference is now Complementary Unbound (Unbound water style branch `WATER_STYLE == 3`) in the official r5.10 upstream codebase. The supplied working Reimagined ZIP remains the functioning Iris implementation reference. The upstream Unbound water target includes animated multi-scale normals, water noise colouring, depth-based opacity, foam, underwater response, Fresnel/specular highlights, screen-space reflections and sky/world-space reflection fallbacks. The broader material reference includes IntegratedPBR+ terrain/entity/translucent classification, material-specific emission/smoothness, normal maps, generated normals, coated textures, POM and parallax self-shadow.

Serene currently has a forward water baseline with depth thickness, half-resolution scene snapshot, refraction, Fresnel-weighted SSR, normal-orientation correction, forward lighting and Iris fog. The following Unbound parity items remain outstanding: animated water normals, noise colour, foam, full underwater response, sky/WSR reflection fallback and higher-quality SSR refinement. Broader terrain/entity PBR, normal/roughness maps, POM, generated normals, coated textures and full translucent material dispatch are also outstanding. These are feature gaps, not approved removals. See [UNBOUND_REFERENCE_AUDIT.md](UNBOUND_REFERENCE_AUDIT.md).


## Water refraction and reflection implementation — 2026-11-23
Iris-verified buffer flow: `deferred` writes full-resolution `colortex0` only; `deferred1` writes the half-resolution scene snapshot to `colortex4` after masking invalid hand/translucent samples with `depthtex0` versus `depthtex2`. `gbuffers_water` reads `colortex4` plus full-resolution `depthtex1` / `depthtex2` and writes only `colortex0`, avoiding same-attachment feedback.

Water currently includes fluid-gated depth opacity, exact-texel depth validation, half-resolution refraction, Fresnel-weighted SSR with 4/6/8 ray steps, bounded user reflection strength, and paired view/player normal orientation correction. This is a low-bandwidth source implementation, not full Unbound parity or runtime proof. Animated multi-scale normals, noise colour, foam, full underwater response, environment/WSR fallback and advanced SSR refinement remain outstanding.


## Iris translucent entity routing caveat — 2026-11-23
The dedicated `gbuffers_entities_translucent` and `gbuffers_block_translucent` shader pairs remain implemented, but the route that schedules them after deferred (`separateEntityDraws=true`) is documented by Iris with a warning that it may be broken in newer Iris versions. Treat this as conditional coverage, not guaranteed active rendering, until verified against the exact target Iris build. The unused `iris.features.optional=ENTITY_TRANSLUCENT` declaration was removed: it only exposes a compile-time capability define and does not enable the routing directive. Do not remove the shader pairs; retain them for compatible Iris versions and future routing fixes.


## Water-wave feature update — 2026-11-23
`gbuffers_water` now applies three world-anchored analytic wave bands to water-surface normals, with user controls for strength and cycle rate. The implementation uses Iris-documented `cameraPosition`, `frameTimeCounter` and `gbufferModelView`. It is an original low-bandwidth substitute for the reference's texture-driven multi-scale normal maps; visual parity and runtime performance remain unverified.


## Water colour feature update — 2026-11-23
The water-only branch now applies an Unbound-inspired biome-aware base tint and a single-sample animated `noisetex` colour variation. Both effects are user-adjustable; noise animation is periodic across Iris' `frameTimeCounter` wrap. Underwater tint/absorption and visual calibration remain pending.


## Water foam feature update — 2026-11-23
A first shoreline foam approximation now uses Iris opaque depth reconstruction to estimate the vertical intersection behind top-facing water surfaces. Foam is applied before lighting and suppresses SSR locally. It is adjustable and source-validated; in-game appearance and performance remain unverified.


## Foam implementation correction — 2026-11-23
Water foam is driven by the already reconstructed opaque-view thickness (`depthtex1` plus inverse projection), restricted to top-facing water. The earlier world-Y/block-height approximation was discarded because it was not robust for sloped shorelines. Runtime appearance and threshold calibration remain pending.


## Glass and portal material coverage — 2026-11-23
- Clear glass and panes, all stained-glass colours and panes, tinted glass, and nether portal now have dedicated Iris `block.properties` IDs.
- Clear/stained/tinted glass receive material-scaled Fresnel SSR from the existing opaque scene snapshot.
- Nether portal receives warm nonlinear colour treatment and self-emission.
- Full Unbound portal distortion/edge effect, glass absorption/connected-glass treatment, and visual/runtime validation remain outstanding.
