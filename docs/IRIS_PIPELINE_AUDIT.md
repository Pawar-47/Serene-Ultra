# Iris Pipeline Audit — 2026-11-23

## Purpose and authority

Serene Ultra is an **Iris-loaded shaderpack**. Iris is the execution environment and defines the shaderpack program lifecycle, program fallbacks, render-target behavior, buffer flipping, shader options and Iris-specific extensions. Minecraft 26.3 Vanilla-stock is the reference for the engine's native rendering inputs and behavior; it is not the shaderpack's file-layout or execution contract. Complementary Reimagined is the working Iris shaderpack reference and must be inspected file-by-file alongside stock source before choosing feature implementations.

This document records an audit of the current Serene source against the published Iris shaderpack contract. It is not a substitute for inspecting the two supplied archives or testing the pack in Iris.

## Verified Iris pipeline facts

The current Iris documentation describes the broad execution order as:

1. setup
2. begin
3. shadow
4. shadowcomp
5. prepare
6. opaque gbuffers
7. deferred
8. translucent gbuffers
9. composite
10. final

The exact order of individual gbuffers programs is not fixed beyond their opaque/translucent placement. Deferred is a fullscreen composite-style pass after most opaque gbuffers and before most translucent gbuffers. Composite runs after the translucent gbuffers group.

Iris also provides fallback gbuffers programs when a specific program file is absent. Relevant documented fallbacks include:
- `gbuffers_water` handles translucent terrain/water and falls back to `gbuffers_terrain`.
- `gbuffers_weather` handles falling rain/snow and falls back to `gbuffers_textured_lit`.
- `gbuffers_hand_water` handles translucent first-person items and falls back to `gbuffers_hand`.
- `gbuffers_block` handles block entities/sign text and falls back to `gbuffers_terrain`.
- `gbuffers_entities` handles entities and nametag text; Iris adds separate translucent entity/block programs in supported ordering modes.

Iris depth samplers have distinct contracts:
- `depthtex0`: all geometry.
- `depthtex1`: excludes transparent geometry.
- `depthtex2`: excludes transparent and hand geometry.
These buffers become meaningful at different points in the pipeline; `depthtex1` is first meaningful in deferred.

Iris color attachments use main/alternate backing buffers. Gbuffers and shadow programs read/write the main buffer. Composite-style passes including deferred and composite read main and write alternate, then flip main/alternate after the pass. The default blending for transparent geometry is source-alpha blending unless overridden. Iris documents that colortex0–3 cannot be sampled from gbuffers programs; they may still be written as render targets.

Primary references:
- https://shaders.properties/current/reference/programs/overview/
- https://shaders.properties/current/reference/programs/gbuffers/
- https://shaders.properties/current/reference/programs/deferred/
- https://shaders.properties/current/reference/buffers/depthtex/
- https://shaders.properties/current/reference/buffers/colortex/
- https://shaders.properties/current/reference/shadersproperties/rendering/
- https://shaders.properties/current/reference/shadersproperties/ordering/

## Current Serene implementation coverage

Current files include:
- `gbuffers_terrain.vsh/.fsh`
- `gbuffers_entities.vsh/.fsh`
- `gbuffers_hand.vsh/.fsh`
- `shadow.vsh/.fsh`
- `deferred.vsh/.fsh`
- `composite.vsh/.fsh`
- `final.vsh/.fsh`

No dedicated files currently exist for:
- `gbuffers_water`
- `gbuffers_weather`
- `gbuffers_hand_water`
- `gbuffers_block`
- `gbuffers_entities_translucent`
- `gbuffers_block_translucent`
- `gbuffers_particles` / `gbuffers_particles_translucent`
- `gbuffers_terrain_solid` / `gbuffers_terrain_cutout`
- sky, clouds, textured, basic, beacon, glint, spider-eyes and lightning programs.

Missing files do not mean geometry is necessarily omitted: Iris applies documented fallback programs. However, fallback behavior is not equivalent to a deliberately designed material path, especially for geometry rendered after deferred.

## High-priority attachment/order hazard to resolve

Serene previously wrote deferred-lit opaque output to `colortex3` and copied it over `colortex0` in composite. That design risked overwriting geometry rendered after deferred. This design has since been replaced with Iris main/alternate buffer flipping; the remainder of this section is retained as the historical diagnosis.

Iris documents that translucent terrain/water, weather and hand-water are among the gbuffers programs that execute after deferred. In the current pack, those program names are absent, so Iris routes them through fallback shaders: `gbuffers_water` → `gbuffers_terrain`, `gbuffers_weather` → `gbuffers_textured_lit`, and `gbuffers_hand_water` → `gbuffers_hand`. These fallback shaders are not tailored to the full water/weather material requirements.

This created a likely overwrite hazard: post-deferred geometry rendered into the scene-color path could be replaced by the subsequent composite copy. The source-level hazard was addressed in the pipeline correction below; in-game behaviour remains to be confirmed.

Historical investigation checklist (the attachment-flow correction is now committed). Before adding feature-specific water/weather shading:
1. Inspect Complementary's actual `gbuffers_water`, `gbuffers_weather`, `gbuffers_hand_water`, relevant composite passes and their `shaders.properties` blending/ordering/target directives.
2. Inspect the matching Minecraft 26.3 stock shader paths to understand water/weather/hand-water native inputs and blending expectations.
3. Trace Iris target flips and blending for the selected implementation.
4. Design dedicated forward paths that preserve correct alpha/depth ordering and avoid sampling forbidden colortex0–3 from gbuffers.
5. Add static checks and Iris runtime scene tests for water, rain/snow and first-person water.
6. Compare each result to Complementary Ultra and vanilla behavior.

## Required next implementation sequence

1. Implement dedicated forward water/weather/hand-water shading and test their post-deferred behavior.
2. Add explicit block/entity/particle/terrain program coverage based on the reference program inventory and Iris fallback table.
3. Establish sky/cloud and vanilla UI/text/particle compatibility paths.
4. Only then extend material classification and the higher-cost Ultra systems (POM, reflections, colored-light propagation, volumetrics, temporal AA and dimension-specific rendering).

## Validation state

- GitHub structural + standalone GLSL CI: passed on commit `826fe3ee513e5b3d35afa42473f2717864fbef9a`, workflow run `45060295410`.
- Iris shaderpack runtime: not yet tested.
- Water/weather/hand-water ordering hazard: source-level risk identified; runtime confirmation pending.
- Complementary and Vanilla-stock file-by-file cross-check for this specific issue: pending; do not claim it has been completed.
- Visual parity and Intel HD 5500 frame-time measurements: not yet performed.


## Coordinate-space and sampler cross-check

The current terrain/entity normal conversion follows Iris' documented convention:
- `gl_NormalMatrix * gl_Normal` converts the model normal into view space.
- `mat3(gbufferModelViewInverse) * viewNormal` converts it into player-aligned space.
- In deferred, transforming the stored player-aligned normal back to view space with `transpose(mat3(gbufferModelViewInverse))` is consistent with the inverse-transpose normal transform for the view rotation.

The current deferred position/shadow transform sequence also follows the documented Iris workflow:
1. Reconstruct view position with `gbufferProjectionInverse`.
2. Convert view position to player space with `gbufferModelViewInverse`.
3. Convert player position to shadow view with `shadowModelView`.
4. Project with `shadowProjection`, divide by W and remap NDC to shadow texture coordinates.

Iris documents `shadowLightPosition` as the highest celestial body's **view-space position vector**, with length 100. The current code normalizes it and converts it to player-aligned space through `mat3(gbufferModelViewInverse)` before taking the normal dot product. This matches the documented coordinate-space contract. Iris also documents `sunAngle` as 0=sunrise, 0.25=noon, 0.5=sunset and 0.75=midnight; any day/night curve must use that cycle rather than assume 0.5 is midnight.

Iris' colortex contract explicitly prohibits sampling colortex0–3 from gbuffers programs (they may be render targets). New geometry shaders must not sample those attachments. Deferred/composite passes may use the documented main/alternate buffer flipping behavior.

These checks verify the current code against Iris' documented contracts only. The Vanilla-stock archive still needs to be inspected for the corresponding Minecraft-native attributes/lightmap behavior, and Complementary's actual source must still be traced for visual/algorithmic comparison.

## CI guard added

The structural validator now rejects gbuffers shader files that declare sampler reads from colortex0–3, matching Iris' documented restriction. It also reports missing dedicated `gbuffers_water`, `gbuffers_weather` and `gbuffers_hand_water` fragment programs as a visible non-failing warning while their implementations remain pending. This keeps the current baseline green without disguising the missing coverage.

The validator change and README update passed CI on HEAD `26d5aafb525029b31739f56e70ea5625571e0304` (run `45060856038`). This remains structural + standalone GLSL validation only, not Iris runtime validation.


## Additional lighting audit — 2026-11-23
The current deferred shader previously used `1.0 - smoothstep(0.45, 0.55, sunAngle)` as its daylight factor. This is inconsistent with Iris' documented sunAngle cycle: 0=dawn, 0.25=noon, 0.5=sunset, 0.75=midnight. The expression made dawn fully bright and failed to produce a continuous dawn transition across the cycle boundary. It has been replaced with a cyclic solar-elevation calculation:

```glsl
float solarElevation = sin(sunAngle * 6.28318530718);
float dayFactor = smoothstep(0.0, 0.30, solarElevation);
```

This uses the positive half of the solar cycle for daylight and smoothly attenuates near the horizon. The change is guarded by structural validation. It is not a runtime or visual-parity result; the actual supplied Vanilla-stock and Complementary archive files still require direct inspection before the dual-reference audit can be marked complete.

## Translucent scene flow correction — 2026-11-23
The first pipeline correction is now committed:
- deferred.fsh writes its lit opaque result to logical colortex0.
- flip.deferred.colortex0=true explicitly retains Iris' main/alternate flip. Deferred is a composite-style pass, so sampling colortex0 and writing colortex0 is safe through the flip; it is not a gbuffers read/write feedback pattern.
- gbuffers_water, gbuffers_weather and gbuffers_hand_water receive explicit source-alpha blending on colortex0.
- composite.fsh now passes through colortex0 to colortex0 with flip.composite.colortex0=true, rather than copying a potentially stale opaque-only colortex3 image over later translucent geometry.
- Water fallback auxiliary G-buffer attachments 1 and 2 are explicitly unblended. They are not consumed by a later deferred pass.

This corrects the identified attachment-flow hazard at source level. It does not yet provide dedicated forward lighting, refraction, Fresnel, absorption or reflections for water; nor does it prove runtime correctness. Iris runtime tests remain required for water, weather, particles and first-person translucent items. The working Complementary and Vanilla-stock ZIP files still need direct source-level comparison before the reference audit can be marked complete.
## Corrected fallback coverage inventory
| Iris program | Geometry | Iris fallback | Serene dedicated implementation |
|---|---|---|---|
| gbuffers_water | Translucent terrain, including water | gbuffers_terrain | Missing; current terrain fallback is not water-lit |
| gbuffers_weather | Falling rain and snow (not particles) | gbuffers_textured_lit | Missing; basic fallback only |
| gbuffers_hand_water | Translucent first-person items | gbuffers_hand | Missing; basic hand fallback only |
| gbuffers_block | Block entities and sign text | gbuffers_terrain | Missing; fallback coverage only |
| gbuffers_entities_translucent | Translucent entities | gbuffers_entities | Missing; Iris additional-program fallback |
| gbuffers_block_translucent | Translucent block entities | gbuffers_block | Missing; Iris additional-program fallback |
| gbuffers_particles | Particles | gbuffers_textured_lit | Missing; fallback coverage only |
| gbuffers_particles_translucent | Translucent particles (requires particles.ordering=mixed) | gbuffers_particles | Missing; fallback coverage only |

Important distinction: Iris fallback routing prevents some geometry from simply disappearing, but does not guarantee that its material data is compatible with Serene's G-buffer or that it receives the intended lighting. The attachment-flow fix prevents the old composite copy-back from replacing the post-deferred scene; it does not implement the missing material shading.

## Full-source Iris contract correction pass — 2026-11-23

### Corrections made after reviewing current Iris reference pages
- `shadowHardwareFiltering` and `shadowIntervalSize` are GLSL constants, not `shaders.properties` directives. They are now declared in `deferred.fsh`; the validator checks the declarations and rejects the misplaced properties keys.
- `separateAo=true` moves vanilla AO into `gl_Color.a`. The current G-buffer multiplies texture alpha by the vertex color and uses that alpha for cutout/scene transparency, so enabling `separateAo` corrupts material alpha. It is now disabled until the G-buffer explicitly stores AO separately.
- G-buffer terrain/entity/hand shaders now use Iris `alphaTestRef` rather than hard-coded 0.1 cutoffs, because Iris documents that this threshold can vary by render case and is affected by the `alphaTest` directive.
- Entity G-buffer now applies Iris `entityColor` tint with its alpha blend factor.
- Deferred world reconstruction and contact AO now use `depthtex2`, which Iris documents as excluding transparent and hand geometry. This prevents first-person hand depth and translucent depth from being treated as opaque world surfaces.
- `particles.ordering=mixed` is now explicit: opaque particles are scheduled before deferred and translucent particles after it, enabling Iris' separate translucent-particle program when present.

### Known constraints retained deliberately
- `separateEntityDraws` is not enabled: Iris documentation warns it may be broken in newer Iris versions. Translucent entities/block entities therefore remain a separate compatibility item requiring version-specific runtime verification.
- Dedicated `gbuffers_water`, `gbuffers_weather`, `gbuffers_hand_water`, particle, and translucent entity/block-entity implementations are still not present. Iris fallback routing is coverage, not material parity.
- These source corrections are grounded in current Iris documentation but are not substitutes for loading the pack in the target Iris/Minecraft build.

### Follow-up: hand/translucent depth masking
`depthtex2` is the correct depth source for opaque-world reconstruction because it excludes transparent and hand geometry, but it cannot by itself identify pixels where `colortex0` already contains first-person hand color. The deferred pass now also samples `depthtex0` and compares it with `depthtex2`. When they differ, it passes the current scene color through instead of applying the opaque surface's normal/light data to the hand or transparent overlay. This is an Iris-depth-contract source correction; verify with first-person scenes and transparent entity cases in-game.

## Atlas sampler and lightmap-coordinate correction — 2026-11-23
- Replaced the GLSL sampler identifier `texture` with Iris' documented `gtexture` atlas sampler in terrain, entities, hand and shadow shaders. Iris warns that `texture` is a reserved built-in name in newer GLSL and is not a valid sampler alias to rely on; the official shadow guide also uses `gtexture`.
- Replaced legacy `texture2D()` calls with `texture()` in the affected shaders.
- Removed an unused terrain view-position varying to avoid unnecessary vertex output/interpolation.
- Iris' lightmap guide notes that transformed lightmap coordinates are approximately [0.033, 0.97], not exact [0,1]. Terrain/entity G-buffers now normalize the sky coordinate with `lmcoord.y / (30.0 / 32.0) - (1.0 / 32.0)` before storing it as the direct-celestial-light mask. The original transformed coordinate remains the sampler coordinate for the vanilla lightmap texture.
- The validator now rejects the reserved sampler alias and requires the Iris `gtexture` sampler and normalized sky coordinate.

## Shadow-distance culling correction — 2026-11-23
Iris documents that `shadowDistance` scales the shadow projection but does not cull geometry beyond that range by default. Added `const float shadowDistanceRenderMul = 1.0;` to `shadow.vsh`, which enables Iris' documented shadow-distance culling. This avoids submitting shadow casters outside the configured profile distance and is especially relevant to the Intel HD 5500 target. The validator now requires this constant. Confirm culling boundaries and shadow stability in Iris runtime.

## Dedicated particle paths — 2026-11-23
Iris `particles.ordering=mixed` places opaque particles before deferred and translucent particles after it. Leaving both programs on the default fallback would be incorrect for this architecture: opaque particles need to write the Serene G-buffer before deferred, while translucent particles need a color-only forward path after deferred. Added:
- `gbuffers_particles.vsh/.fsh`: writes albedo, sampled vanilla lightmap and player-aligned normal to colortex0/1/2 for deferred lighting.
- `gbuffers_particles_translucent.vsh/.fsh`: writes color only, uses the vanilla colored lightmap, and is blended after deferred without sampling colortex0–3.
- Explicit per-program blend directives for translucent particles and disabled blending on opaque particle data attachments.
The validator now requires both pairs and their output contracts. This is Iris-program coverage and a basic rendering path, not yet reference Ultra particle parity or runtime-verified behavior.

## First-person hand lighting correction — 2026-11-23
Iris routes `gbuffers_hand` to a textured-lit fallback when no custom shader exists. The custom Serene hand shader previously sampled only albedo, so replacing that fallback removed the vanilla lightmap response. Added transformed `gl_MultiTexCoord1` coordinates in `gbuffers_hand.vsh` and a `lightmap` sample in `gbuffers_hand.fsh`, multiplying the hand albedo by the sampled lightmap RGB. This restores the documented lightmap component of the fallback behavior. `heldBlockLightValue` / `heldBlockLightValue2` dynamic held-item illumination remains a separate item-light implementation task; do not claim it is complete.

## Dimension-aware celestial lighting — 2026-11-23
- Deferred now gates ordinary sun/moon direct light with Iris `hasSkylight`; dimensions without skylight no longer receive an invented Overworld day/night direct-light cycle.
- Enabled Iris `endFlashShadows=true`. In the End, Iris redirects `shadowLightPosition` to `endFlashPosition`; deferred uses `endFlashIntensity` as the direct-light gate when `hasSkylight` is false.
- Shadow sampling is skipped when the surface faces away from the active light or the celestial gate is zero, avoiding four shadow comparisons for pixels that cannot receive direct celestial light.
- Nether receives no direct celestial term from this path; End-flash illumination is supported at source level. Runtime verification in Nether/End remains outstanding.

## Emissive eye overlay handling — 2026-11-23
Iris identifies `gbuffers_spidereyes` as the spider/enderman/dragon eye pass, falling back to `gbuffers_textured` when absent. That fallback writes color but no Serene normal-validity data. If deferred then sees the underlying entity normal, it can incorrectly apply body lighting to the emissive eye texture. Added a dedicated `gbuffers_spidereyes` pair that writes the eye color and clears the deferred-validity alpha in colortex2 for those pixels. The per-buffer blend directive disables blending on that mask so the invalid marker is deterministic. This is a source-level emissive-preservation correction; verify eye layering and depth behavior in Iris runtime.

### Conditional translucent entity programs
`gbuffers_entities_translucent` and `gbuffers_block_translucent` are only activated when `separateEntityDraws=true`. Serene intentionally leaves that option disabled because current Iris documentation warns the feature may be broken in newer Iris versions. The validator now excludes these two inactive programs from the missing-program warning unless the option is explicitly enabled. This does not mean translucent entity handling is complete; the current pre-deferred entity path still needs visual/runtime verification.

## Dedicated forward water baseline — 2026-11-23
Iris documents `gbuffers_water` as post-deferred translucent terrain, with `gbuffers_terrain` as its fallback. The old fallback therefore supplied G-buffer outputs that no later deferred pass consumed and left water without Serene's forward lighting. Added dedicated `gbuffers_water.vsh/.fsh`:
- Uses Iris `gtexture`, transformed lightmap UVs and geometry normals.
- Reconstructs player-space water position in the vertex stage and samples `shadowtex0` in the fragment stage.
- Applies the same dimension-aware sun/moon/End-flash direct-light gate and hardware-filtered shadow taps as the opaque lighting path.
- Writes color only to `colortex0`; it does not sample forbidden `colortex0–3` in a gbuffers program.
- Uses the existing source-alpha blend directive.
This is a forward-lit baseline, not full Ultra water parity. Refraction, Fresnel/reflection, absorption/depth tint, wave normals, rain ripples and water-specific reference tuning remain outstanding pending line-by-line source comparison and runtime testing.

## Dedicated weather forward path — 2026-11-23
Iris documents `gbuffers_weather` as post-deferred rain/snow geometry, with `gbuffers_textured_lit` as its fallback. Added a dedicated color-only `gbuffers_weather.vsh/.fsh` pair. It samples Iris `gtexture` and `lightmap`, preserves the vanilla lightmap response, applies the Iris fog uniforms (`fogColor`, `fogStart`, `fogEnd`, `fogDensity`, `fogMode`, `fogShape`), and writes only colortex0 with the existing source-alpha blend rule. `rain.depth=false` is explicit so weather does not alter depth used by other scene stages. Rain splash particles remain handled by the particle programs. This is a forward baseline, not volumetric weather, rain streak reconstruction, wet-surface response or reference Ultra parity.

## Iris fog integration — 2026-11-23
The current code had no shared Iris fog implementation in the deferred world pass, and the first forward weather/water/particle paths needed consistent fog treatment. Added the documented Iris fog uniforms (`fogColor`, `fogStart`, `fogEnd`, `fogDensity`, `fogMode`, `fogShape`) to deferred and the relevant post-deferred forward programs. Fog distance uses spherical or cylindrical distance according to `fogShape`; linear, exponential and exponential-squared modes use Iris/OpenGL mode values. Fog blending is performed in linearized color space before re-encoding. Opaque terrain/entities/particles receive fog in deferred; water, weather and translucent particles receive fog in their own forward passes. Hand-water still uses the hand fallback and remains a dedicated-path item.

## Dedicated hand-water forward path — 2026-11-23
Iris documents `gbuffers_hand_water` as post-deferred first-person translucent geometry, falling back to `gbuffers_hand`. Added a dedicated color-only forward pair. It uses `gtexture`, transformed lightmap coordinates, view-space distance and Iris fog uniforms; it writes only colortex0 and uses the existing source-alpha blend directive. It does not sample colortex0–3. This removes reliance on the ordinary hand fallback for this stage. Dynamic held-item illumination and in-game first-person water verification remain outstanding.

## Linear-space color correction — 2026-11-23
Iris' fog guide explicitly converts fog and sampled colors to linear space before lighting. Applied that same documented color-space discipline to the custom first-person hand lightmap multiplication and entityColor tint blend: decode sampled/vertex colors, perform the multiplication or tint blend in linear space, then re-encode for the current G-buffer representation. The deferred, water, weather and translucent-particle paths already perform lighting/fog in linear space. Exact buffer color-space assumptions still need comparison against the supplied stock/reference shader sources and in-game validation.

## Emissive-eye fog correction — 2026-11-23
The dedicated `gbuffers_spidereyes` path now also applies Iris fog using view-space distance and the documented fog uniforms. It still clears deferred-validity alpha so eye pixels remain emissive, but distant eyes now fade consistently with the rest of the scene.

## Full Iris gbuffers fallback inventory — 2026-11-23
The validator now inventories the documented Iris fallback chain for the remaining special geometry programs, not just the three translucent programs. Current dedicated Serene implementations include terrain, entities, hand, water, weather, hand-water, opaque/translucent particles and spider eyes. The remaining fallbacks being tracked are:

| Iris program | Geometry | Iris fallback | Serene status |
|---|---|---|---|
| `gbuffers_block` | Block entities/sign text | `gbuffers_terrain` | Fallback; terrain path currently covers it |
| `gbuffers_damagedblock` | Block-breaking overlay | `gbuffers_terrain` | Fallback; overlay-specific validation pending |
| `gbuffers_beaconbeam` | Beacon beam | `gbuffers_textured` | Fallback; beam compositing pending |
| `gbuffers_armor_glint` | Enchantment glint | `gbuffers_textured` | Fallback; preserve glint against deferred lighting |
| `gbuffers_clouds` | Vanilla clouds | `gbuffers_textured` | Fallback; cloud/fog integration pending |
| `gbuffers_skybasic` | Sky color/horizon/stars/void | `gbuffers_basic` | Fallback; custom sky pending |
| `gbuffers_skytextured` | Sun/moon textures | `gbuffers_textured` | Fallback; celestial disc handling pending |
| `gbuffers_lightning` | Lightning/dragon death beams | `gbuffers_entities` | Fallback; special depth/color handling pending |
| `gbuffers_line` | Block outline/fishing line | `gbuffers_basic` | Fallback; outline preservation pending |
| `gbuffers_textured_lit` | Most lit particles | `gbuffers_textured` | Fallback used by some non-dedicated geometry |
| `gbuffers_textured` | World border/unlit particles | `gbuffers_basic` | Fallback chain |

`gbuffers_entities_translucent` and `gbuffers_block_translucent` remain conditional on `separateEntityDraws=true`; that option stays disabled due Iris' current warning. This inventory is driven by the official Iris fallback table and the validator now reports missing dedicated vertex/fragment pairs with their immediate fallback.

## Shadow cutout threshold correction — 2026-11-23
The shadow fragment shader now combines Iris' per-program `alphaTestRef` with the Serene user-controlled `SHADOW_ALPHA_CUTOFF` using the stricter threshold. This preserves Iris' render-layer cutout behavior while retaining the pack's adjustable shadow cutout control.

## Translucent particle alpha correction — 2026-11-23
The post-deferred `gbuffers_particles_translucent` program no longer uses Iris `alphaTestRef`. That uniform is a cutout threshold; applying it to blended particles could discard valid low-alpha smoke/spark/particle edges. The program now discards only effectively transparent texels (`alpha <= 0.001`) and retains fractional alpha for source-alpha blending. Opaque `gbuffers_particles` continues to use `alphaTestRef`.

## Correction: `gbuffers_water` covers all translucent terrain — 2026-11-23
Iris' program table defines `gbuffers_water` as **translucent terrain, including water**, not water blocks alone. This includes other translucent block surfaces such as stained glass. The dedicated program is therefore a generic forward-lit translucent-terrain baseline; its variables and comments have been renamed accordingly so they do not imply that water-only refraction, Fresnel, or absorption is already active. Iris exposes `mc_Entity.y` in `gbuffers_water.vsh` (`1.0` for fluids, `-1.0` for other terrain), which is the documented discriminator to use when implementing fluid-only effects. That classification and material-specific behavior remain pending until the supplied Complementary reference implementation can be traced. The current shader still uses a shared diffuse/lightmap/shadow/fog baseline for all translucent terrain.

## Reference-guided fluid classification and depth opacity — 2026-11-23
Cross-checked the current Complementary Reimagined `gbuffers_water.glsl`, `translucentMaterials.glsl`, `water.glsl`, `block.properties` and Iris attribute/depth documentation. The reference classifies translucent terrain with `mc_Entity.x` material IDs and `mc_Entity.y` fluid render type, then uses `depthtex1` to estimate opaque geometry behind the water surface and attenuate alpha with depth. Implemented the compatible subset:
- Added stable `block.properties` IDs for water, water cauldrons, lava, lava cauldrons and nether portals.
- `gbuffers_water.vsh` now reads Iris' documented `mc_Entity` attribute and passes material ID and fluid type to the fragment stage.
- Water and water-cauldron only receive depth-based opacity; glass and other translucent blocks keep their original alpha.
- The water thickness calculation reads `depthtex1` (opaque-only depth, meaningful after deferred), reconstructs view position with `gbufferProjectionInverse`, and uses the reference Beer-Lambert-style `1-exp(-thickness*0.075)` response.
- Added `WATER_FOG_MULT` with the reference control range, plus Iris `alphaTestRef` handling and `alphaTest.gbuffers_water` configuration.
This is not full Complementary water parity: water normal maps, animated waves, Fresnel reflections, refraction, foam, caustics, underwater-specific response and PBR/material handling remain outstanding. Iris depth and attribute semantics are documented in the links below.

## Water depth / material contract correction — 2026-11-23
Re-checked the current Iris reference pages before implementation: `mc_Entity` is valid in `gbuffers_water.vsh`; `.x` is the ID assigned by `block.properties`, while `.y` is `1.0` for fluid render geometry and `-1.0` for other blocks. `depthtex1` excludes transparent geometry and first contains meaningful data at `deferred`; `gbuffers_water` runs after deferred, so it is valid for opaque-behind-water thickness. The `far` uniform is render distance, not the projection far plane, so the water thickness code now reconstructs the sampled depth (including clear depth 1.0) through `gbufferProjectionInverse`. The alpha threshold is taken from Iris `alphaTestRef`, with `alphaTest.gbuffers_water=GREATER 0.0001` intentionally setting the reference to the low value used by Complementary Reimagined for translucent water; the shader still uses the Iris uniform rather than a hardcoded threshold. Water-only opacity is gated by both the stable `minecraft:water` material ID and Iris' fluid render type. Complementary Reimagined's reference water path uses the same depthtex1 distance-difference and exponential opacity form (`1-exp(-thickness*0.075)`, with `WATER_FOG_MULT` scaling). This is still a baseline: refraction, Fresnel, reflection, waves/normals, foam, absorption color and full water material handling are not yet implemented.

## Special overlay programs — 2026-11-23
Iris documents armor glint, beacon beams and lightning as separate gbuffers programs, with lightning falling back to entities and beacon beams to textured geometry. They render before deferred, so a color-only fallback can leave an unrelated opaque normal beneath the overlay. The Complementary source confirms the glint strength multiplier (`color.rgb *= glColor.a`) and the forward/emissive treatment of beacon/lightning overlays. Added dedicated `gbuffers_armor_glint`, `gbuffers_beaconbeam` and `gbuffers_lightning` pairs. Each writes scene color plus a zero deferred-validity mask in colortex2; the mask has blending disabled. Color blending is deliberately left to Minecraft/Iris' active render state, rather than imposing a generic alpha blend on enchantment glint. Beacon beams use Iris alphaTestRef and fog; lightning preserves entityColor tint and fog. These are source-level overlay paths; runtime blend/depth validation remains pending.

### Reference parity refinement
A further source comparison confirmed Complementary Reimagined sets `alphaTest.gbuffers_water=GREATER 0.0001` and shapes water alpha with `sqrt(alpha)` before applying the depth-opacity term. Serene Ultra now deliberately uses the same low Iris alpha-test reference, reads it through `alphaTestRef`, applies the square-root alpha shaping, and uses `texelFetch(depthtex1, ivec2(gl_FragCoord.xy), 0)` to sample the exact opaque-depth pixel without filtering. This supersedes the earlier mistaken note that the alpha-test directive had been removed.

## Weather and vanilla-cloud corrections — 2026-11-23
The Complementary reference's weather path uses different baseline alpha multipliers for rain and snow, rejects very faint weather texels, and suppresses the weather pass when the camera is in powdered snow. Added the same rain/snow classification (`r+g < 1.5`), default opacity factors (0.25 rain / 0.5 snow), adjustable `WEATHER_TEX_OPACITY` control, `alphaTestRef` handling and Iris `isEyeInWater==3` behavior. Added optional `WAVING_RAIN` vertex motion using Iris `rainStrength`, `eyeBrightnessSmooth` and `frameTimeCounter`.

Iris routes vanilla clouds through `gbuffers_clouds` before deferred. Added a dedicated pass that preserves the vanilla texture/vertex color, applies Iris fog, hides clouds while the camera is in fluid, and clears the deferred-normal validity mask so the clouds are not shaded using terrain normals underneath. This is vanilla-cloud compatibility, not the full custom volumetric/cloud system from Complementary.

## Textured fallback and sky stages — 2026-11-23
Added a dedicated `gbuffers_textured` path for Iris' unlit textured fallback (world border and particles without a dedicated lighting path). It samples `gtexture`, respects `alphaTestRef`, applies Iris fog, writes color only plus an invalid deferred-normal mask, and preserves the active game blend state.

Added dedicated `gbuffers_skytextured` and `gbuffers_skybasic` paths. The textured sky program uses Iris `renderStage` macros (`MC_RENDER_STAGE_SUN`, `MC_RENDER_STAGE_MOON`) to distinguish sun and moon textures, applies rain/underwater dimming and leaves custom sky textures unchanged. The basic sky program uses Iris `skyColor`/`fogColor` and render-stage macros for upper sky, sunset, stars and void; it reconstructs view direction only for sky/sunset stages and performs color-space conversion once per vertex for the uniform sky colors. Both clear deferred validity so sky overlays are not shaded with world normals.
These are lightweight vanilla-sky bridges, not the complete Complementary atmospheric scattering, star field, custom clouds or volumetric sky system. `gbuffers_textured` is also a safe unlit fallback, not full Complementary particle lighting.

## Iris sky-program audit — 2026-11-23
Iris documents `gbuffers_skybasic` for sky/horizon, stars and void, and `gbuffers_skytextured` for sun/moon textures. The new paths use the documented `renderStage` uniform with the actual `MC_RENDER_STAGE_*` macros (SKY, SUNSET, STARS, VOID, SUN, MOON). `sunPosition` and `moonPosition` are documented view-space positions of length 100; the shader compares their normalized directions against the view-space up vector from `gbufferModelView`. `skyColor` and `fogColor` are Iris rendering uniforms. Sky programs write color plus a zero deferred-validity mask, with blending disabled on colortex2 so they cannot inherit opaque surface normals. The sky-texture path uses the low `alphaTestRef` setting, and the sky-basic path only reconstructs a player direction for sky/sunset stages (not stars/void). GLSL macro branches are separately compiled in CI using injected preprocessor defines. These are source/CI checks, not visual or runtime proof.

## Line and outline overlay path — 2026-11-23
Iris documents `gbuffers_line` as the line-geometry program and exposes `MC_RENDER_STAGE_OUTLINE` and `MC_RENDER_STAGE_DEBUG` for distinguishing selection outlines/debug lines from other line geometry. Added a dedicated forward overlay pair. It preserves vertex color, applies Iris fog to ordinary lines, leaves selection/debug overlays crisp, writes only scene color plus a zero deferred-validity mask, and preserves the game's color blend state. This prevents fishing lines/leads/outlines from inheriting the opaque terrain normal underneath.

## Translucent particle forward lighting — 2026-11-23
Iris' `particles.ordering=mixed` sends translucent particles through `gbuffers_particles_translucent` after deferred. This program therefore cannot rely on deferred G-buffer lighting. Added player-space particle position/normal outputs and a forward lighting path that samples the vanilla lightmap, applies the active sun/moon or End-flash source, and receives shadows through one hardware-filtered `shadowtex0` comparison. The single PCF lookup is intentional for the Intel HD 5500 target; fog is applied in linear color space. The program writes only colortex0 and keeps source-alpha blending. Particle-specific emission classification (lava/ender/redstone), underwater particles, campfire smoke and other Complementary material heuristics remain outstanding.

## Entity-translucent feature gate revalidated — 2026-11-23
A later edit had temporarily enabled `separateEntityDraws=true` and `iris.features.optional=ENTITY_TRANSLUCENT`. This was reverted after rechecking current Iris documentation, which warns that `separateEntityDraws` is broken in newer versions. `shaders.properties` now explicitly sets `separateEntityDraws=false`; the optional feature flag and active blend directives were removed. The forward `gbuffers_entities_translucent` and `gbuffers_block_translucent` source pairs are retained in the repository for a future Iris version/runtime where this path is verified, but they are not activated or required by the current pack. The validator now rejects accidental re-enabling.

## Separate translucent entities and block entities — 2026-11-23
Iris documents `separateEntityDraws=true` as moving translucent entities and block entities to post-deferred `gbuffers_entities_translucent` and `gbuffers_block_translucent`. The pack now enables this route and declares `iris.features.optional=ENTITY_TRANSLUCENT` to query Iris support. Dedicated forward programs sample `gtexture`, `lightmap` and `shadowtex0`, apply the pack's forward celestial/shadow lighting and Iris fog, then blend only into colortex0. The entity path also applies Iris `entityColor` using its alpha blend factor. These programs do not sample colortex0–3 and do not write deferred G-buffer attachments after deferred. Runtime testing is still required, particularly on Iris versions that do not expose ENTITY_TRANSLUCENT.

## Complementary particle-material heuristics ported — 2026-11-23
The post-deferred particle program now has an optional `PARTICLE_MATERIAL_FEATURES` path based on the supplied Complementary `gbuffers_textured.glsl` heuristics: water-splash particle color/opacity treatment with Iris `noisetex` dither, physics-mod rain and snow opacity, underwater particle suppression, campfire smoke alpha reduction, and emissive ender/crying-obsidian/redstone/lava particle handling. Emission is added after direct/ambient lighting and skips the shadow lookup to save work. Rain/snow classification is runtime-gated by `hasSkylight && rainStrength` rather than relying on Complementary's `OVERWORLD` macro, which is defined by its dimension wrapper and is not automatically available in this base Iris shader file. `WEATHER_TEX_OPACITY` is shared with the dedicated weather path. The option is exposed in the Quality menu. This implementation is currently in the translucent particle path; opaque-particle material emission and broader modded-particle classification remain to audit.

## Emissive G-buffer channel — 2026-11-23
Added a compact dedicated emissive attachment using Iris `colortex3` (`RGBA8`). The opaque terrain/entity/particle G-buffer programs now write attachments 0–3; non-emissive entities and opaque particles explicitly write zero emission. `gbuffers_terrain.vsh` consumes the documented Iris `in vec2 mc_Entity` attribute (valid in `gbuffers_terrain.vsh`) and forwards its block ID. `block.properties` now assigns stable IDs to glowstone, sea lantern, torches, end rods, redstone lamp/torch lit states, shroomlight, campfires, froglights, glow lichen, beacon, fire/soul fire, lanterns and lava. Terrain stores tinted emission RGB and normalized intensity in colortex3. Deferred samples that channel and adds emission after contact AO/direct-light computation but before fog, so emissive surfaces are not darkened by AO or celestial shadows. The post-deferred fluid shader adds a separate lava self-emission term. `colortex3` is explicitly read-only in deferred (`flip.deferred.colortex3=false`), uses RGBA8 storage and has blending disabled in the opaque G-buffer programs. This is a compact block-ID emissive baseline, not yet a full PBR/emissive-texture-map system or bloom implementation.