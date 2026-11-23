# Reference Ultra Feature Preservation Matrix

## Two-reference engineering rule (mandatory)
Both supplied shader archives are active technical references, not merely one engine reference plus one visual mood board. Consult both when designing, reviewing, debugging or validating a rendering feature. When uncertain whether an approach, formula, interface, shader stage, texture lookup, buffer, pass order or code path is correct, inspect the corresponding/relevant files in **both** archives, compare how each achieves or expects the behavior, and record the evidence before choosing an implementation. If the files are not directly equivalent, trace the related stages and shared inputs/outputs rather than forcing a one-file match. Use Vanilla-stock to establish Minecraft 26.3's native contracts and behavior; use the working shader to understand proven feature implementation, visual treatment, quality controls and Ultra expectations. Then write an original Serene Ultra implementation that respects the stock engine contract while pursuing the reference's visual contribution, adapted for Intel HD 5500 without dropping Ultra features. Do not blindly copy either source, and do not claim a comparison was performed unless the relevant files were actually inspected.


**Status:** Implementation is actively underway across the G-buffer, deferred lighting, translucent materials, water, weather and particle paths. Reference inventory is established; feature parity, Iris runtime validation and Intel HD 5500 visual/performance verification remain incomplete.
**Rule:** Every feature found in the supplied reference's Ultra profile must have an explicit disposition. "Optimized" does not mean removed. A feature may be marked complete only after code inspection and visual/runtime validation.

The supplied archive is a Complementary Reimagined shaderpack and is used as a technical reference. Serene retains an independent program structure, but selected material algorithms and item-ID mappings have been adapted; their provenance and license compatibility are tracked as a release gate. This matrix records feature categories and the work required for Serene's implementation.

| Feature family | Required Ultra capability | Serene implementation plan | Status |
|---|---|---|---|
| Terrain/material pipeline | Material-aware terrain rendering and material-specific behavior | Albedo, sampled vanilla lightmap RGB, player-space normal capture, oldPBR/LabPBR smoothness/F0/metalness/emission decode and slime/honey material overrides | Partial; POM and visual/runtime calibration remain pending |
| Entity rendering | Entity-specific shading and shadows | Entity albedo/tint, sampled lightmap, normal capture, oldPBR/LabPBR smoothness/F0/metalness/emission decode, Iris currentRenderedItemId fallbacks for dropped items/armor and alpha cutoff | Partial; entity/item visual and runtime calibration remain pending |
| Hand/item rendering | Correct first-person hand/item rendering and dynamic held-item world light | Hand lightmap path, tangent-space item PBR, item-specific material/emission fallbacks, and shared Iris main/offhand light-value contribution in deferred opaque and forward translucent water/glass passes | Partial; no cast shadows or occluder-aware lighting, with runtime range/color calibration pending |
| Shadow mapping | Sun/moon directional shadows | Depth reconstruction and directional shadow comparison | Partial |
| Shadow caster alpha | Transparent texels discarded so foliage/fences cast shaped rather than solid shadows | Texture-aware shadow fragment test with user-adjustable alpha threshold | Implemented; runtime verification pending |
| Shadow filtering | Soft filtered shadows and quality controls | Shared rotated-Poisson PCF at 4/8/12 taps with slope-aware bias and colored `shadowtex0`/`shadowtex1`/`shadowcolor0` transmission across deferred and forward passes | Partial; runtime softness, stability and performance tuning pending |
| Ambient occlusion | Contact/local occlusion | Eight-neighbor depth-based screen-space contact AO; edge-aware and temporal refinement remains | Partial |
| Direct lighting | Directional lighting and block light response | Iris sunAngle cyclic solar-elevation curve (dawn/noon/sunset/night) for celestial diffuse, combined with sampled vanilla lightmap ambient | Partial; source correction committed, runtime/parity pending |
| Colored lighting | Colored block/emissive light response | Preserve vanilla lightmap RGB; custom colored-light propagation and emissive response remain | Partial |
| Indirect lighting / GI | Bounced/indirect illumination appearance | Quality-scaled 4/8/12-tap depth- and normal-aware screen-space colour bounce from nearby opaque surfaces; translucent/hand overlays are rejected using depthtex0 vs depthtex2; no temporal history | Partial; spatial single-bounce approximation with 4/8/12 sample tiers, no multi-bounce or temporal stability, and runtime/parity validation pending |
| Volumetric lighting | Light shafts, cloud shadows and volumetric scattering | Screen-space radial sunlight scattering plus moving procedural cloud-shadow attenuation on opaque and forward translucent direct-light receivers | Partial; cloud shadows are a 2-scale noise approximation, with no volumetric density integration, temporal accumulation or visual parity test |
| Atmospheric scattering | Sky color, horizon and atmospheric depth | Low-cost Rayleigh/Mie-inspired sky scattering, twilight band and active sun/moon forward-scattering lobe; no texture reads | Partial; physically integrated multi-wavelength/volumetric scattering and visual parity remain pending |
| Fog | Distance, height and dimension-aware fog | Iris fog modes/shape in deferred and forward water/weather/particle/hand-water paths | Partial; source paths implemented, runtime tuning pending |
| Clouds | Native cloud lighting, surface detail and ground shadowing | Minecraft 26.3 `POSITION_COLOR` cloud pass with Iris fog/scattering, world-stable multi-scale surface detail and moving procedural cloud shadows projected along the celestial light direction | Partial; custom volumetric cloud layers/reflections and runtime parity remain pending |
| Water surface | Unbound-style water tint, transparency, animated normals, depth absorption, foam and caustics | Dedicated gbuffers_water; Unbound style-3 biome tint and above-/underwater alpha branches, fluid-gated depth opacity, Beer-Lambert absorption, resource-pack PBR normal maps for water/glass/ice, three-scale baseline plus optional fourth very-large octave, tileable custom water-normal texture and 2560-block stable period, world-height-aware noise tint, noise-broken foam, Fresnel SSR with two-step refinement, sky/horizon plus low-cost sun/moon disk fallback; projected caustics use Iris shadowcolor transmission | Partial; water parallax, full cloud/WSR reflections, caustic/absorption calibration and runtime parity pending |
| Water reflections | Reflected scene/sky and Fresnel response | Fresnel SSR (4/6/8 coarse steps) using half-resolution scene colour and full-resolution opaque depth, with two binary hit-refinement steps and Iris sky/horizon fallback; Ultra-Light uses the environment-only branch | Partial; world-space reflections and temporal stability remain pending |
| Block reflections | Reflective material response | Smoothness/F0-weighted opaque SSR (4/6/8 steps) with Iris sky/horizon and sun/moon fallback; Ultra-Light uses environment-only reflections | Partial; no world-space tracing, temporal reprojection or roughness-aware blur yet |
| Rain/wetness | Rain response and wet surfaces | LabPBR porosity wet-darkening on terrain, entities and block entities using Iris wetness and biome rainfall | Partial; oldPBR has no porosity channel and runtime tuning remains pending |
| Puddles | Rain puddles and surface reflections | Rain/biome-gated sky exposure, upward-facing masks, three-noise breakup, ripple normals, LabPBR porosity suppression and PBR smoothness/SSR integration | Partial; no voxelized water map, puddle accumulation remains terrain-only; runtime/performance calibration pending |
| Coated textures | Subtle material-specific surface coating variation | Terrain/entities use stable atlas-tile + world-cell noise with brightness/mip fade and skip mapped emissive, high-F0 and high-smoothness surfaces; block entities use Complementary per-material factors on opaque surfaces while retaining explicit PBR emission/F0 priority | Partial; material appearance, entity coverage and runtime/performance calibration pending |
| Generated normals | Albedo-derived normal detail for resource packs without explicit normal maps | Terrain, block entities and opt-in entity models use gradient-gated four-tap albedo-gradient normals; atlas-clamped sampling, alpha-edge rejection, explicit-normal-map detection and independent strength control | Partial; runtime visual calibration and target-GPU performance pending |
| Parallax/POM | Parallax occlusion material detail | Terrain, block-entity and opt-in opaque entity-model LabPBR/oldPBR height mapping from Iris normals.a; per-quad mc_midTexCoord atlas bounds; at_tangent view direction; bounded 4/6/8-step intersection, distance fade, capped displacement and cutout-safe albedo fallback | Partial; POM self-shadowing, slope normals and runtime calibration pending |
| Texture filtering | Texture quality and anisotropic behavior | Hardware filtering where supported; quality controls | Pending |
| TAA | Temporal anti-aliasing | Motion-aware history, rejection and sharpening controls | Pending |
| Other anti-aliasing | Additional AA modes/quality settings | Edge-adaptive FXAA in final pass; Ultra-Light can disable it, Smooth and higher enable it | Partial; FXAA edge quality and TAA remain unimplemented/unverified |
| Bloom/emissive | Emissive contribution and glow/post effects | Two-scale chain: soft-knee bright pass at half resolution, separable nine-tap Gaussian, quarter-resolution wide level, combined in the final pass; strength/threshold controls | Partial; two scales over a display-referred buffer, no temporal stabilisation or full mip chain, visual calibration pending |
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
The current source explicitly implements `gbuffers_water`, `gbuffers_weather`, `gbuffers_hand_water`, `gbuffers_particles`, `gbuffers_particles_translucent`, `gbuffers_entities_translucent`, `gbuffers_block_translucent` and `gbuffers_spidereyes`. Post-deferred water, weather, hand-water, translucent-particle, entity and block-entity programs use forward color outputs with Iris lightmap/fog handling; water additionally implements depth opacity, half-resolution refraction and Fresnel SSR. Entity/block-entity routing remains best-effort because Iris documents `separateEntityDraws` as potentially broken. Advanced Unbound water/weather effects and runtime/visual parity checks remain pending. See [IRIS_PIPELINE_AUDIT.md](IRIS_PIPELINE_AUDIT.md) and [UNBOUND_REFERENCE_AUDIT.md](UNBOUND_REFERENCE_AUDIT.md).

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
Dedicated `gbuffers_water` replaces the terrain fallback. It forward-shades translucent terrain after deferred using the Iris atlas, vanilla lightmap, resource-pack PBR normals, shadow map and dimension-aware celestial source. Water-only effects are gated by stable material ID plus Iris fluid render type, with a separate remapped water-cauldron surface ID. It includes depth opacity, half-resolution refraction, Fresnel SSR with two-step hit refinement and sky/horizon fallback, resource-pack tangent-space normal maps for water/glass/ice, a generated tileable 64x64 tangent-normal texture sampled at three spatial scales plus an optional fourth very-large octave, Unbound-style tint/noise, noisy shallow-water foam, Beer-Lambert absorption and a separate underwater surface response. Projected caustics are generated in the shadow pass and transmitted through RGBA shadowcolor. Water parallax remains deferred because the custom normal texture has constant alpha and no verified height channel; full cloud/world-space reflections and visual/runtime calibration remain pending.

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

Reference refinement: retained `alphaTest.gbuffers_water=GREATER 0.0001` (matching the working Iris reference), used Iris `alphaTestRef` in the shader, aligned water surface alpha with Complementary Unbound style 3 (`0.98` above water and a `0.75` underwater reduction before depth opacity), and switched to exact-pixel `texelFetch` for opaque depth.

## Weather/cloud feature update — 2026-11-23
- Weather: reference-style rain/snow texture classification and alpha multipliers; adjustable `WEATHER_TEX_OPACITY`; Iris `alphaTestRef`; powdered-snow camera suppression; optional wind motion using Iris `rainStrength` and `eyeBrightnessSmooth`.
- Vanilla clouds: dedicated forward pass preserves vanilla texture/vertex lighting, applies Iris fog, hides clouds underwater/in fluids, and clears the deferred normal-validity mask.
- World-stable procedural cloud shadows now attenuate direct lighting across deferred and forward translucent receivers; native cloud faces also receive subtle world-stable detail. Custom volumetric cloud layers, physically based cloud volumes and cloud reflections remain pending.

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
| `gbuffers_clouds` | Vanilla clouds | Consumes POSITION_COLOR CloudColor/face shading; Iris fog, bounded scattering and world-stable surface detail; deferred validity mask cleared |

Render-stage macro names and celestial uniforms were checked against current Iris documentation. These are baseline implementations, not yet visual parity with Complementary Ultra.

## Line overlays — 2026-11-23
Dedicated `gbuffers_line` now handles line geometry, using Iris `renderStage` macros to skip fog on selection outlines/debug lines while fogging ordinary lines. It clears deferred-normal validity and leaves color blending to the game.

## Translucent particles — 2026-11-23
`gbuffers_particles_translucent` forward-lights post-deferred particles using player-space normals/positions, vanilla lightmap, day/night/End-flash direct light, the shared rotated-Poisson soft/colored shadow helper at `SHADOW_FILTER_QUALITY` 4/8/12, and Iris fog. Its material option ports Complementary-guided water-splash, physics rain/snow, underwater, smoke and emissive heuristics; opaque ender/redstone/crying-obsidian/lava emission is also written to the scalar G-buffer. Visual material calibration remains pending.

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
An RGBA8 `colortex3` material buffer is written by opaque G-buffer programs: red stores emission strength, green stores oldPBR metalness or LabPBR dielectric F0/metal classification, blue stores LabPBR material AO and alpha stores LabPBR porosity/SSS data. Terrain, entities and block entities consume Iris `specular` atlas data for smoothness and emission decoding; deferred adds tinted emission after AO/direct lighting and uses a GGX direct-specular BRDF with decoded material F0/metal response, plus Fresnel-weighted opaque SSR from a half-resolution scene snapshot. Opaque particle paths retain their emissive heuristics. Material AO attenuates indirect/block light, LabPBR SSS adds a low-cost backlighting approximation, and porosity drives wet darkening/reflectance loss plus reduced puddle pooling; bloom remains pending. Resource-pack tangent-space normal maps now cover opaque terrain, entities and block entities.

## Core overlay/block-entity coverage — 2026-11-23
| Iris program | Geometry | Current implementation |
|---|---|---|
| `gbuffers_basic` | Leash and debug chunk-border overlay | Vertex color + Iris fog; clears deferred-validity mask |
| `gbuffers_damagedblock` | Block-breaking texture | Color-only crack overlay; `alphaTestRef` set to 0.004 |
| `gbuffers_block` | Block entities and sign text | Four-target G-buffer; sign text fogged and bypasses deferred lighting; chest/ender-chest smoothness and emission, conduit glow, bell/copper material response, banner normal exclusion, enchanting-book material cues, and portal/gateway emission |

`block.properties` maps sign families to ID 5004 and End portal/gateway to 5025, read through Iris `blockEntityId`.

Emission remains a scalar in colortex3 red and reuses scene albedo for tint; green stores material reflectance, blue material AO and alpha LabPBR porosity/SSS. The attachment is RGBA8 to retain all four material channels without adding another render target; this costs two extra bytes per pixel versus the intermediate RG8 layout and must be profiled on Intel HD 5500.

## Complementary Unbound water/material parity — 2026-11-23
The primary visual/material reference is now Complementary Unbound (Unbound water style branch `WATER_STYLE == 3`) in the official r5.10 upstream codebase. The supplied working Reimagined ZIP remains the functioning Iris implementation reference. The upstream Unbound water target includes animated multi-scale normals, water noise colouring, depth-based opacity, foam, underwater response, Fresnel/specular highlights, screen-space reflections and sky/world-space reflection fallbacks. The broader material reference includes IntegratedPBR+ terrain/entity/translucent classification, material-specific emission/smoothness, normal maps, generated normals, coated textures, POM and parallax self-shadow.

Serene now has depth thickness, half-resolution scene snapshot/refraction, Fresnel SSR with sky/horizon fallback, normal-orientation correction, resource-pack PBR normals for translucent water/glass/ice, three-band analytic waves, Unbound-inspired water tint/noise, depth-based absorption, noisy foam breakup, underwater response, projected shadowcolor caustics, forward lighting and Iris fog. Remaining Unbound water gaps include its generated multi-scale normal texture/parallax refinement, world-space reflections and more advanced/temporally stable SSR. Opaque terrain/entity/block-entity PBR normals, material AO and SSS are implemented; POM, generated normals, coated textures and complete material dispatch remain outstanding. These are feature gaps, not approved removals. See [UNBOUND_REFERENCE_AUDIT.md](UNBOUND_REFERENCE_AUDIT.md).


## Water refraction and reflection implementation — 2026-11-23
Iris-verified buffer flow: `deferred` writes full-resolution `colortex0` only; `deferred1` writes the half-resolution scene snapshot to `colortex4` after masking invalid hand/translucent samples with `depthtex0` versus `depthtex2`. `gbuffers_water` reads `colortex4` plus full-resolution `depthtex1` / `depthtex2` and writes only `colortex0`, avoiding same-attachment feedback.

Water currently includes fluid-gated depth opacity, exact-texel depth validation, half-resolution refraction, Fresnel SSR with 4/6/8 ray steps, sky/horizon environment fallback, resource-pack tangent-space normal maps for water/glass/ice, paired view/player normal orientation, analytic waves, Unbound-inspired noise tint, noisy foam breakup, Beer-Lambert absorption, underwater response and projected caustics through colored shadow transmission. This remains a low-bandwidth source implementation, not full Unbound parity or runtime proof. Unbound's generated multi-scale normal texture/parallax refinement, world-space reflections and advanced/temporal SSR remain outstanding.


## Iris translucent entity routing caveat — 2026-11-23
The dedicated `gbuffers_entities_translucent` and `gbuffers_block_translucent` shader pairs remain implemented, but the route that schedules them after deferred (`separateEntityDraws=true`) is documented by Iris with a warning that it may be broken in newer Iris versions. Treat this as conditional coverage, not guaranteed active rendering, until verified against the exact target Iris build. The unused `iris.features.optional=ENTITY_TRANSLUCENT` declaration was removed: it only exposes a compile-time capability define and does not enable the routing directive. Do not remove the shader pairs; retain them for compatible Iris versions and future routing fixes.


## Water-wave feature update — 2026-11-23
`gbuffers_water` now applies three world-anchored analytic wave bands to water-surface normals, with user controls for strength and cycle rate. The implementation uses Iris-documented `cameraPosition`, `frameTimeCounter` and `gbufferModelView`. It is an original low-bandwidth substitute for the reference's texture-driven multi-scale normal maps; visual parity and runtime performance remain unverified.


## Water colour feature update — 2026-11-23
The water-only branch applies an Unbound-inspired biome-aware base tint and animated `noisetex` colour variation. The world-height-aware coordinates are tiled exactly over Serene's 256-block stable-world period, and the animation is periodic across Iris' `frameTimeCounter` wrap. Foam uses a separate higher-frequency noise sample to break up the depth-based shoreline mask. Visual calibration and target-GPU performance remain pending.


## Water foam feature update — 2026-11-23
Shallow-water foam now uses Iris opaque-depth thickness, top-facing water geometry and a noise-varying threshold for breakup. Foam is applied before lighting and suppresses SSR locally; strengths below/above 100 adjust coverage/tint. It is source-validated; in-game appearance and performance remain unverified.


## Foam implementation correction — 2026-11-23
Water foam is driven by the already reconstructed opaque-view thickness (`depthtex1` plus inverse projection), restricted to top-facing water. The earlier world-Y/block-height approximation was discarded because it was not robust for sloped shorelines. Runtime appearance and threshold calibration remain pending.


## Glass and portal material coverage — 2026-11-23
- Clear glass and panes, all stained-glass colours and panes, tinted glass, and nether portal now have dedicated Iris `block.properties` IDs.
- Clear/stained/tinted glass receive material-scaled Fresnel SSR from the existing opaque scene snapshot.
- Nether portal receives warm nonlinear colour treatment, self-emission and four-tap animated UV distortion clamped to the current Iris atlas sprite using `mc_midTexCoord`.
- Portal animation uses an integer cycle count over Iris' 3600-second timer to avoid wrap discontinuities. Full Unbound raymarch/edge treatment, glass absorption/connected-glass treatment, and visual/runtime validation remain outstanding.


## Translucent ice feature update — 2026-11-23
Ice/frosted ice now has a dedicated Iris material ID and shares the Fresnel SSR path with glass, with a distinct reflection scale. Water-only depth/refraction/foam remain isolated to the water ID. Ice-specific roughness, thickness and visual calibration remain pending.


## Glossy terrain material update — 2026-11-23
Iris IDs now classify slime and honey blocks in the terrain G-buffer. Smoothness is packed into the existing normal attachment alpha (validity remains distinguishable), and deferred adds a low-cost sun/moon specular highlight only for classified smooth materials. `MATERIAL_SPECULAR_STRENGTH` is adjustable. Broader PBR material classification, normal/roughness maps and runtime visual calibration remain pending.


## Depth-dependent water absorption — 2026-11-23
Water refraction now receives linear-space Beer-Lambert attenuation based on reconstructed opaque-scene thickness. Red/green/blue transmission coefficients create depth-dependent blue tint; the water's own base tint is the absorption colour. A strength slider is available. Coefficient tuning and in-game visual parity remain pending.


## Nether portal distortion update — 2026-11-23
Nether portals now receive a four-tap animated UV distortion, with each sample clamped to the current quad's texture region using Iris `mc_midTexCoord`. The pre-tint portal signal drives self-emission, followed by a warm nonlinear tint. The full Unbound raymarch/edge treatment is not yet implemented.


### Water wave spatial scale — 2026-11-23
`WATER_WAVE_SCALE` now adjusts the spatial frequency of the three analytic wave bands independently of wave strength and animation speed. It is exposed as a Quality slider; in-game tuning remains pending.


## Colored translucent shadows — 2026-11-23
The shadow pass writes RGBA8 transmission data for water, clear/stained/tinted glass, ice and Nether portals. A shared rotated-Poisson PCF helper now combines `shadowtex0`, opaque-only `shadowtex1` and Iris' `shadowcolor0.rgb * (1.0 - shadowcolor0.a)` transmission formula across deferred, water, translucent entities, block entities and particles. Runtime and performance validation remain pending.


## Water cauldron material coverage — 2026-11-23
Filled water cauldrons now map to material ID 32001 and use the water surface pipeline (refraction, absorption, waves, foam, underwater response and caustic shadow transmission). Empty cauldrons remain unaffected.


## Forward translucent shadow consistency — 2026-11-23
The forward water, translucent entity, block-entity and particle paths now call the same shared soft/colored shadow helper as deferred, so all post-deferred translucent receivers use consistent PCF and material transmission.


## Resource-pack water normal maps — 2026-11-23
The water path now supports Iris `normals` atlas maps via `at_tangent`, with LabPBR Y- inversion selected by Iris' `MC_TEXTURE_FORMAT_LAB_PBR` macro and tangent handedness applied to the bitangent. A neutral normal is supplied when no `_n` texture exists. The `WATER_NORMAL_MAP_STRENGTH` slider controls the contribution; resource-pack/runtime validation remains pending.


## oldPBR/LabPBR terrain material decoding — 2026-11-23
Terrain, entities and block entities now sample Iris' `specular` atlas and `normals` atlas through their `at_tangent` basis, decoding both oldPBR and LabPBR conventions. Smoothness comes from red; oldPBR green is metalness and blue is emissive; LabPBR green stores the normalized raw code `code / 255.0`; deferred uses the raw normalized value `code / 255.0` as dielectric F0 for codes 0–229 (code 229 is approximately 0.90), while codes 230–254 identify predefined metals and 255 selects albedo as F0. Serene currently treats the whole 230–255 range as albedo-tinted metal; distinct 230–254 metal presets remain a known simplification, following the shaderLABS LabPBR 1.3 standard (https://shaderlabs.org/wiki/LabPBR_Material_Standard), while alpha is emissive. `colortex3` is RGBA8 (emission red, reflectance/metal code green, material AO blue, LabPBR porosity/SSS alpha), and deferred decodes dielectric F0, applies material AO/SSS and uses albedo for colored metal highlights. CI run 919 passed compilation and linking for both default oldPBR and explicit LabPBR macro branches. In-game validation with actual oldPBR and LabPBR resource packs remains pending.


## LabPBR material ambient occlusion — 2026-11-23
The opaque terrain, entity and block-entity G-buffers now decode the LabPBR normal-map blue channel as linear material AO and store it in `colortex3.b`; deferred applies it once to indirect/block-light ambient, leaving direct celestial illumination unchanged. `PBR_AO_STRENGTH` controls map influence and `MATERIAL_AO_STRENGTH` controls lighting impact. LabPBR specular blue values 65–255 are decoded as SSS in `colortex3.a` and add low-cost backlighting controlled by `MATERIAL_SSS_STRENGTH`; values 0–64 are decoded as porosity for wet darkening and puddle suppression. oldPBR and neutral/missing AO remain unaffected. The existing attachment was upgraded to RGBA8, adding bandwidth versus the RG8 intermediate but no new render target. Runtime and performance validation remain pending.

| Vanilla terrain material fallbacks | Correct material response for common metals, gems and minerals without PBR resource packs | Complementary-guided Iris block IDs, albedo-derived smoothness, LabPBR/oldPBR metal classification and per-material coating factors | Partial; runtime calibration pending |



## Minecraft 26.3 transparency architecture

The Vanilla-stock archive contains 89 GLSL source files: 72 declare GLSL 330 and 17 are include fragments without a version declaration. Sixteen archive paths contain OIT-related files. The stock `core/terrain.fsh` and OIT includes implement a native multi-phase OIT path.

The inspected Iris source maps translucent terrain to the shaderpack's `gbuffers_water` program, water-mask rendering to `gbuffers_basic`, and translucent particles to `gbuffers_particles_translucent`. It does not expose the stock OIT phase macros as shaderpack stages in the inspected source snapshot. Serene therefore targets Iris' conventional alpha-blended gbuffers path; native Minecraft OIT is an engine reference, not a shaderpack subsystem to copy. This remains subject to the 26.3 runtime regression test described in `docs/TEST_PLAN.md`.



## Minecraft 26.3 native clouds and soft/coloured shadows

- **Native clouds:** dedicated `gbuffers_clouds` is aligned with Iris' `POSITION_COLOR` cloud vertex format and the stock 26.3 cloud shader. It preserves CloudColor/face shading, applies Iris fog and optional bounded scattering. Custom volumetric clouds remain unimplemented.
- **Cylindrical fog:** all 12 fragment programs that use `fogShape` now use `max(length(position.xz), abs(position.y))`; the validator enforces the invariant globally.
- **Soft/coloured shadows:** one rotated-Poisson helper is shared by deferred lighting and forward water/entity/block-entity/particle paths. It uses `shadowtex0`, `shadowtex1` and `shadowcolor0` according to Iris' documented alpha-transmission contract. Runtime softness, color accumulation and performance still need visual testing.
- **Entity routing:** the pack contains the required translucent entity/block-entity/particle programs and requests `separateEntityDraws=true`, but current Iris docs warn that the routing may be broken in newer versions. Treat it as best-effort until runtime draw routing is confirmed.


## Iris item-render routing audit — 2026-11-23

The dedicated `gbuffers_item` pair was removed after checking Iris 26.1 source. Although Iris declares `ProgramId.Item` with a fallback to `TexturedLit`, the built-in `IrisPipelines` mapping routes `RenderPipelines.ITEM_CUTOUT` through `getCutout()` and `RenderPipelines.ITEM_TRANSLUCENT` through `getTranslucent()`; those select `ShaderKey.ENTITIES_CUTOUT` / `ShaderKey.ENTITIES_TRANSLUCENT` (or the block-entity equivalents when applicable). There is no built-in `ShaderKey.ITEM` or main-pipeline assignment to a dedicated item stage in the inspected Iris 26.1 source. Item-specific material handling therefore belongs in the active entity/block-entity G-buffer paths, where `currentRenderedItemId` is already decoded; first-person held items use the dedicated hand path. A standalone `gbuffers_item` shader would compile but would not prove that normal item draws reach it. Sources inspected: Iris `ShaderKey.java`, `ProgramId.java`, and `IrisPipelines.java` on branch `26.1`.


## World-stable cloud noise at large coordinates — 2026-11-23

Both native cloud surface detail and projected cloud shadows now use `lib/lighting/stable_world_position.glsl`. It reduces the integer camera origin modulo the chosen period before converting to float, then adds the fractional camera offset and player-relative position. This avoids float precision loss near Minecraft's world border. The cloud-shadow period is 62,500 blocks: 62,500 × 0.0016 = 100 base-noise repeats and 100 × 2.73 = 273 detail repeats. The cloud-surface-detail period is 100,000 blocks: 100,000 × 0.0021 = 210 base repeats and 210 × 3.1 = 651 detail repeats. Both are seamless because Iris 26.1's `NoiseTexture` configures `noisetex` with `GL_REPEAT` on both axes. Runtime camera-motion, boundary-seam and visual calibration tests remain outstanding.
