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
| Hand/item rendering | Correct first-person hand/item rendering | Dedicated hand pipeline and parity tests | Foundation |
| Shadow mapping | Sun/moon directional shadows | Depth reconstruction and directional shadow comparison | Partial |
| Shadow caster alpha | Transparent texels discarded so foliage/fences cast shaped rather than solid shadows | Texture-aware shadow fragment test with user-adjustable alpha threshold | Implemented; runtime verification pending |
| Shadow filtering | Soft filtered shadows and quality controls | Four hardware-filtered comparison taps with slope-aware bias; stability/quality tuning remains | Partial |
| Ambient occlusion | Contact/local occlusion | Eight-neighbor depth-based screen-space contact AO; edge-aware and temporal refinement remains | Partial |
| Direct lighting | Directional lighting and block light response | Iris sunAngle cyclic solar-elevation curve (dawn/noon/sunset/night) for celestial diffuse, combined with sampled vanilla lightmap ambient | Partial; source correction committed, runtime/parity pending |
| Colored lighting | Colored block/emissive light response | Preserve vanilla lightmap RGB; custom colored-light propagation and emissive response remain | Partial |
| Indirect lighting / GI | Bounced/indirect illumination appearance | Screen-space/temporal approximation; preserve visual contribution | Pending |
| Volumetric lighting | Light shafts and volumetric scattering | Depth-aware low-resolution integration and reconstruction | Pending |
| Atmospheric scattering | Sky color, horizon and atmospheric depth | Analytic atmosphere with shared sky/lighting parameters | Pending |
| Fog | Distance, height and dimension-aware fog | Unified fog model with per-world tuning | Pending |
| Clouds | Procedural/cloud-layer appearance and lighting | Procedural cloud system with adaptive sampling | Pending |
| Water surface | Water tint, transparency, normals and lighting | Dedicated translucent/water material path | Pending |
| Water reflections | Reflected scene/sky and Fresnel response | Screen-space reflection plus fallback hierarchy | Pending |
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
| Weather | Rain/snow and weather-dependent material/lighting | Weather-aware material and atmosphere paths | Pending |
| Dimension support | Overworld, Nether, End and special dimensions | World-specific shader programs/configuration | Pending |
| Night vision/potions | Correct vanilla effect interactions | Explicit effect compatibility tests | Pending |
| Emissive entities/blocks | Correct emissive response | Emissive classification and lighting path | Pending |
| Translucent materials | Glass, foliage, water and particles | Ordered/appropriate translucent passes and alpha rules | Pending |
| Foliage | Alpha-tested leaves/grass and wind response if present | Alpha-aware shadow casters are started; material animation and parity remain | Partial |
| Voxelization/SSBO-dependent effects | Reference's voxel/structured-buffer features | Determine visible Ultra contribution; implement a hardware-compatible alternative where needed | Pending |
| Profiles/settings | Full reference Ultra quality controls | Serene Ultra master profile plus scalable implementation controls | Foundation |
| Iris compatibility | Shaderpack lifecycle and supported uniforms/programs | Current Iris 26.3 validation | Pending |

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
The current source contains terrain, entities, hand and shadow programs, but it does not yet explicitly implement the Iris post-deferred programs `gbuffers_water`, `gbuffers_weather` or `gbuffers_hand_water`. Iris documents these as translucent-stage programs executed after deferred; absent files use fallback programs. Because Serene currently copies colortex3 back to colortex0 in composite, this requires a dedicated attachment/blending design and runtime validation before water/weather/hand-water can be marked supported. See [IRIS_PIPELINE_AUDIT.md](IRIS_PIPELINE_AUDIT.md).

Do not equate Iris fallback coverage with correct feature implementation. The matrix must track both the native geometry category and the actual Iris program that receives it.

## Post-deferred scene preservation correction
The old colortex3-to-colortex0 copy-back has been removed. Deferred and composite now use Iris-supported same-logical-attachment read/write with their default main/alternate flips explicitly enabled. Water, weather and hand-water have explicit source-alpha blend rules on colortex0. This addresses the source-level overwrite risk but is not runtime verification or a substitute for dedicated forward-lit water and material implementations.

## Iris contract correction status — 2026-11-23
| Area | Corrected source contract | Remaining validation |
|---|---|---|
| Shadow filtering | GLSL `const bool shadowHardwareFiltering = true` | Iris runtime sampler binding and visual PCF |
| Shadow update interval | GLSL `const float shadowIntervalSize = 2.0` | Runtime update cadence |
| Vertex AO alpha | `separateAo=false` to preserve material alpha | Revisit only when AO has a separate G-buffer channel |
| Cutout alpha | `alphaTestRef` uniform in terrain/entities/hand | Runtime cutout edge checks |
| Entity tint | `entityColor` RGB mixed by its alpha | Damage/team/potion tint checks |
| Deferred depth | `depthtex2` excludes transparent and hand geometry | Verify all target-version depth stages in game |
| Particle ordering | `particles.ordering=mixed` | Dedicated particle programs and visual order checks |

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