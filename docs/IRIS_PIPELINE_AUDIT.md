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

Iris color attachments use main/alternate backing buffers. Gbuffers and shadow programs read/write the main buffer; composite-style passes (including `deferred`, `deferred1` and `composite`) read main and write alternate, then flip after the pass. A gbuffers program may sample a different colortex attachment, but must not sample an attachment it also writes. The validator parses each fragment shader's `RENDERTARGETS` and rejects only same-attachment read/write conflicts. The default blending for transparent geometry is source-alpha blending unless overridden.

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
4. Design dedicated forward paths that preserve correct alpha/depth ordering and avoid same-attachment colortex feedback in gbuffers; sampling a different, non-output attachment is allowed by Iris.
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

The structural validator now rejects only gbuffers same-attachment feedback, matching Iris' documented main-buffer semantics. Dedicated `gbuffers_water`, `gbuffers_weather` and `gbuffers_hand_water` programs are present; their source/GLSL coverage is not a substitute for in-game validation.

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

This corrected the identified attachment-flow hazard. Subsequent work added a dedicated forward-lit translucent-terrain path with water-only depth opacity, half-resolution screen-space refraction and Fresnel-weighted screen-space reflections. These are source-level implementations, not proof of runtime correctness or full Complementary Ultra parity. Iris runtime tests remain required for water, weather, particles and first-person translucent items; the supplied Complementary and Vanilla-stock references remain active comparison sources.
## Corrected fallback coverage inventory
| Iris program | Geometry | Iris fallback | Serene dedicated implementation |
|---|---|---|---|
| gbuffers_water | Translucent terrain, including water | gbuffers_terrain | Dedicated forward lighting; fluid-gated depth opacity, half-resolution refraction from `colortex4`, Fresnel-weighted SSR using `depthtex2`, source-alpha output; waves/foam/caustics remain pending |
| gbuffers_weather | Falling rain and snow (not particles) | gbuffers_textured_lit | Dedicated post-deferred lightmap/fog path with shared rain/snow opacity option |
| gbuffers_hand_water | Translucent first-person items | gbuffers_hand | Dedicated forward lightmap/fog path; runtime depth/visual checks pending |
| gbuffers_block | Block entities and sign text | gbuffers_terrain | Dedicated G-buffer path; sign text bypasses deferred and portal/gateway IDs receive emission |
| gbuffers_entities_translucent | Translucent entities | gbuffers_entities | Dedicated forward shader exists; routing via `separateEntityDraws=true` is best-effort because current Iris docs warn it may be broken in newer versions |
| gbuffers_block_translucent | Translucent block entities | gbuffers_block | Dedicated forward shader exists; routing via `separateEntityDraws=true` is best-effort and runtime-dependent |
| gbuffers_particles | Particles | gbuffers_textured_lit | Dedicated opaque G-buffer path with lightmap, normals and emissive particle classification |
| gbuffers_particles_translucent | Translucent particles (requires particles.ordering=mixed) | gbuffers_particles | Dedicated forward lighting, shadow/fog and Complementary-guided water/rain/snow/smoke/emission heuristics |

Important distinction: Iris fallback routing prevents some geometry from simply disappearing, but does not guarantee that its material data is compatible with Serene's G-buffer or that it receives the intended lighting. The attachment-flow correction preserves post-deferred scene contributions; dedicated forward programs cover water, weather, hand-water and translucent particles. Dedicated translucent entity/block-entity shaders exist, but their post-deferred routing is conditional on `separateEntityDraws` and must not be counted as guaranteed coverage.

## Full-source Iris contract correction pass — 2026-11-23

### Corrections made after reviewing current Iris reference pages
- `shadowHardwareFiltering` and `shadowIntervalSize` are GLSL constants, not `shaders.properties` directives. They are now declared in `deferred.fsh`; the validator checks the declarations and rejects the misplaced properties keys.
- `separateAo=true` moves vanilla AO into `gl_Color.a`. The current G-buffer multiplies texture alpha by the vertex color and uses that alpha for cutout/scene transparency, so enabling `separateAo` corrupts material alpha. It is now disabled until the G-buffer explicitly stores AO separately.
- G-buffer terrain/entity/hand shaders now use Iris `alphaTestRef` rather than hard-coded 0.1 cutoffs, because Iris documents that this threshold can vary by render case and is affected by the `alphaTest` directive.
- Entity G-buffer now applies Iris `entityColor` tint with its alpha blend factor.
- Deferred world reconstruction and contact AO now use `depthtex2`, which Iris documents as excluding transparent and hand geometry. This prevents first-person hand depth and translucent depth from being treated as opaque world surfaces.
- `particles.ordering=mixed` is now explicit: opaque particles are scheduled before deferred and translucent particles after it, enabling Iris' separate translucent-particle program when present.

### Known constraints retained deliberately
- `separateEntityDraws=true` is a documented routing directive, but the current Iris ordering page explicitly warns that it may be broken in newer Iris versions. Keep it as a best-effort compatibility setting only; do not claim that the dedicated translucent entity/block-entity programs are guaranteed to execute post-deferred. The `ENTITY_TRANSLUCENT` feature flag only exposes a compile-time capability define; it does not enable routing, so the unused optional declaration was removed.
- Dedicated `gbuffers_water`, `gbuffers_weather`, `gbuffers_hand_water`, particle and translucent entity/block-entity implementations are now present. Iris fallback routing is coverage, not material parity; source implementations still require runtime sorting, blend and visual checks.
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
`gbuffers_entities_translucent` and `gbuffers_block_translucent` are intended for the `separateEntityDraws=true` route. Current Iris documentation warns that this route may be broken in newer Iris versions. Their shaders are implemented and compile, but their post-deferred execution is conditional and must be verified in the exact target Iris build.

## Dedicated forward water, refraction and reflection path — 2026-11-23
Iris documents `gbuffers_water` as post-deferred translucent terrain, with `gbuffers_terrain` as its fallback. The dedicated `gbuffers_water.vsh/.fsh` now forward-lights this stage and applies fluid-only effects when both the stable water block ID and Iris `mc_Entity.y` fluid render type match:
- Uses Iris `gtexture`, transformed lightmap UVs, view/player-space normals, `shadowtex0`, the dimension-aware celestial gate and Iris fog.
- Preserves reference-style `sqrt(alpha)` shaping and depth opacity using full-resolution `depthtex1` plus `gbufferProjectionInverse`.
- Adds screen-space refraction from a half-resolution scene-color snapshot in `colortex4`, controlled by `WATER_REFRACTION_STRENGTH`.
- Adds Fresnel-weighted screen-space reflections with 4/6/8 ray steps, using full-resolution opaque depth from `depthtex2` and the separate half-resolution color snapshot; `WATER_REFLECTION_QUALITY` and `WATER_REFLECTION_STRENGTH` control quality/strength.
- `deferred` remains a full-resolution `RENDERTARGETS: 0` pass. `deferred1` runs after it and before translucent gbuffers, reads `colortex0` plus `depthtex0/depthtex2`, and writes only half-resolution `colortex4`. It averages valid scene pixels in linear color space and masks first-person hand/translucent depth mismatches. Explicit flips keep the read-only `colortex0` source stable and expose the new `colortex4` output to water.
- `gbuffers_water` samples `colortex4`/depth textures but writes only `colortex0`; it does not sample the attachment it writes. This follows Iris' documented cross-attachment rule and avoids feedback.

This is a low-bandwidth source-level approximation, not full Complementary Ultra water parity. Animated normal maps/waves, absorption color, foam, caustics, underwater-specific response, rain ripples and runtime/visual calibration remain outstanding.

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

`gbuffers_textured_lit` now has a dedicated G-buffer fallback pair for lit particles and generic lit geometry. `gbuffers_terrain_solid` and `gbuffers_terrain_cutout` intentionally retain Iris' documented fallback to `gbuffers_terrain`: Iris exposes `mc_Entity` in `gbuffers_terrain.vsh`, and keeping the common terrain path preserves stable block-ID/fluid classification rather than duplicating the shader under split-program names.

## Shadow cutout threshold correction — 2026-11-23
The shadow fragment shader now combines Iris' per-program `alphaTestRef` with the Serene user-controlled `SHADOW_ALPHA_CUTOFF` using the stricter threshold. This preserves Iris' render-layer cutout behavior while retaining the pack's adjustable shadow cutout control.

## Translucent particle alpha correction — 2026-11-23
The post-deferred `gbuffers_particles_translucent` program no longer uses Iris `alphaTestRef`. That uniform is a cutout threshold; applying it to blended particles could discard valid low-alpha smoke/spark/particle edges. The program now discards only effectively transparent texels (`alpha <= 0.001`) and retains fractional alpha for source-alpha blending. Opaque `gbuffers_particles` continues to use `alphaTestRef`.

## Correction: `gbuffers_water` covers all translucent terrain — 2026-11-23
Iris' program table defines `gbuffers_water` as **translucent terrain, including water**, not water blocks alone. This includes other translucent block surfaces such as stained glass. The dedicated program is therefore a generic forward-lit translucent-terrain baseline; its variables and comments have been renamed accordingly so they do not imply that water-only refraction, Fresnel, or absorption is already active. Iris exposes `mc_Entity.y` in `gbuffers_water.vsh` (`1.0` for fluids, `-1.0` for other terrain), which is the documented discriminator to use when implementing fluid-only effects. That historical baseline was superseded by the later fluid-gated water implementation: only actual water receives depth opacity, refraction and Fresnel SSR; glass and other translucent terrain retain the generic diffuse/lightmap/shadow/fog path. The remaining water material features are documented in the dedicated water section above.

## Reference-guided fluid classification and depth opacity — 2026-11-23
Cross-checked the current Complementary Reimagined `gbuffers_water.glsl`, `translucentMaterials.glsl`, `water.glsl`, `block.properties` and Iris attribute/depth documentation. The reference classifies translucent terrain with `mc_Entity.x` material IDs and `mc_Entity.y` fluid render type, then uses `depthtex1` to estimate opaque geometry behind the water surface and attenuate alpha with depth. Implemented the compatible subset:
- Added stable `block.properties` IDs for water, water cauldrons, lava, lava cauldrons and nether portals.
- `gbuffers_water.vsh` now reads Iris' documented `mc_Entity` attribute and passes material ID and fluid type to the fragment stage.
- Water and water-cauldron only receive depth-based opacity; glass and other translucent blocks keep their original alpha.
- The water thickness calculation reads `depthtex1` (opaque-only depth, meaningful after deferred), reconstructs view position with `gbufferProjectionInverse`, and uses the reference Beer-Lambert-style `1-exp(-thickness*0.075)` response.
- Added `WATER_FOG_MULT` with the reference control range, plus Iris `alphaTestRef` handling and `alphaTest.gbuffers_water` configuration.
This is not full Complementary water parity: water normal maps/animated waves, absorption color, foam, caustics, underwater-specific response and PBR/material handling remain outstanding. Fresnel reflections and refraction have since been implemented as source-level approximations; runtime and visual parity remain unverified.

## Water depth / material contract correction — 2026-11-23
Re-checked the current Iris reference pages before implementation: `mc_Entity` is valid in `gbuffers_water.vsh`; `.x` is the ID assigned by `block.properties`, while `.y` is `1.0` for fluid render geometry and `-1.0` for other blocks. `depthtex1` excludes transparent geometry and first contains meaningful data at `deferred`; `gbuffers_water` runs after deferred, so it is valid for opaque-behind-water thickness. The `far` uniform is render distance, not the projection far plane, so the water thickness code now reconstructs the sampled depth (including clear depth 1.0) through `gbufferProjectionInverse`. The alpha threshold is taken from Iris `alphaTestRef`, with `alphaTest.gbuffers_water=GREATER 0.0001` intentionally setting the reference to the low value used by Complementary Reimagined for translucent water; the shader still uses the Iris uniform rather than a hardcoded threshold. Water-only opacity is gated by both the stable `minecraft:water` material ID and Iris' fluid render type. Complementary Reimagined's reference water path uses the same depthtex1 distance-difference and exponential opacity form (`1-exp(-thickness*0.075)`, with `WATER_FOG_MULT` scaling). Refraction and Fresnel SSR are now implemented through the separate half-resolution `colortex4` snapshot described above. Waves/normals, foam, absorption color and full water material handling remain outstanding; runtime verification is still required.

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
An earlier audit temporarily enabled and then disabled `separateEntityDraws` based on an incorrect interpretation of the Iris documentation. The current official ordering page contains no such warning: it explicitly states that `separateEntityDraws=true` moves translucent entities and block entities to `gbuffers_entities_translucent` and `gbuffers_block_translucent`. The active configuration now enables this documented route, queries `ENTITY_TRANSLUCENT` through `iris.features.optional`, and applies source-alpha blending to both forward programs. Runtime verification remains outstanding.

## Separate translucent entities and block entities — 2026-11-23
Iris documents `separateEntityDraws=true` as moving translucent entities and block entities to post-deferred `gbuffers_entities_translucent` and `gbuffers_block_translucent`. The pack enables this route and declares `iris.features.optional=ENTITY_TRANSLUCENT` to query support. Dedicated forward programs sample `gtexture`, `lightmap` and `shadowtex0`, apply forward celestial/shadow lighting and Iris fog, then blend only into colortex0. The entity path also applies Iris `entityColor` using its alpha blend factor. These programs do not sample colortex0–3 or write deferred G-buffer attachments after deferred. Runtime sorting, alpha behavior and compatibility still require in-game verification.

## Complementary particle-material heuristics ported — 2026-11-23
The post-deferred particle program now has an optional `PARTICLE_MATERIAL_FEATURES` path based on the supplied Complementary `gbuffers_textured.glsl` heuristics: water-splash particle color/opacity treatment with Iris `noisetex` dither, physics-mod rain and snow opacity, underwater particle suppression, campfire smoke alpha reduction, and emissive ender/crying-obsidian/redstone/lava particle handling. Emission is added after direct/ambient lighting and skips the shadow lookup to save work. Rain/snow classification is runtime-gated by `hasSkylight && rainStrength` rather than relying on Complementary's `OVERWORLD` macro, which is defined by its dimension wrapper and is not automatically available in this base Iris shader file. `WEATHER_TEX_OPACITY` is shared with the dedicated weather path. The option is exposed in the Quality menu. The same reference-aligned emissive ender/redstone/crying-obsidian and lava classification is also implemented in the opaque `gbuffers_particles` and `gbuffers_textured_lit` G-buffer paths. Broader modded-particle classification remains to audit.

## Emissive G-buffer channel — 2026-11-23
Added a compact dedicated emissive attachment using Iris `colortex3` (`RGBA8`). The opaque terrain/entity/particle G-buffer programs now write attachments 0–3; non-emissive entities and opaque particles explicitly write zero emission. `gbuffers_terrain.vsh` consumes the documented Iris `in vec2 mc_Entity` attribute (valid in `gbuffers_terrain.vsh`) and forwards its block ID. `block.properties` now assigns stable IDs to glowstone, sea lantern, torches, end rods, redstone lamp/torch lit states, shroomlight, campfires, froglights, glow lichen, beacon, fire/soul fire, lanterns and lava. Terrain stores tinted emission RGB and normalized intensity in colortex3. Deferred samples that channel and adds emission after contact AO/direct-light computation but before fog, so emissive surfaces are not darkened by AO or celestial shadows. The post-deferred fluid shader adds a separate lava self-emission term. `colortex3` is explicitly read-only in deferred (`flip.deferred.colortex3=false`), uses RGBA8 storage and has blending disabled in the opaque G-buffer programs. This is a compact block-ID emissive baseline, not yet a full PBR/emissive-texture-map system or bloom implementation.

## Remaining core geometry programs — 2026-11-23
Current Iris program documentation identifies `gbuffers_basic` for leash/debug chunk-border overlays, `gbuffers_damagedblock` for block-breaking texture, and `gbuffers_block` for block entities/sign text. Dedicated programs now exist for all three. `gbuffers_basic` writes color plus a zero deferred-validity mask and applies Iris fog. `gbuffers_damagedblock` is color-only and uses Iris `alphaTestRef` with the Complementary reference threshold `0.004`; it deliberately retains the underlying block's G-buffer normal/lightmap so the crack overlay receives the block's lighting. `gbuffers_block` writes the same four G-buffer attachments as terrain, uses documented `blockEntityId` mappings for signs and portals, and bypasses deferred lighting for sign text after applying Iris fog directly. Portal/gateway block-entity IDs receive a separate emission value. This is a baseline; signs, portals, block entity animations and crack blending still need runtime/visual comparison.

## Single-channel emission attachment optimization — 2026-11-23
Iris' image-format documentation confirms `RGBA8` is a supported normalized render-target format. `colortex3` stores emission in red, oldPBR metalness/LabPBR F0 code in green, material AO in blue and LabPBR porosity/SSS data in alpha, declared with `const int colortex3Format = RGBA8;` in a block comment in `deferred.fsh`. Deferred reuses scene albedo for emission tint and material-coloured specular response, avoiding duplicated RGB data. RGBA8 uses four bytes per pixel to retain all four material channels without a separate attachment. `flip.deferred.colortex3=false` and `blend.*.colortex3=off` preserve the data contract.

## Iris uniform, attribute and depth contract audit — 2026-11-23
- Verified `mc_Entity` is valid in `gbuffers_terrain.vsh`, `gbuffers_water.vsh` and `shadow.vsh`; its `x` component is the `block.properties` ID and `y` is `1.0` for fluids / `-1.0` otherwise. The water program's fluid/material-ID test therefore uses the documented attribute in a valid program.
- Verified `blockEntityId` is the documented `gbuffers_block` uniform and that `block.properties` uses `block.<ID>` entries for both block and block-entity IDs.
- Verified `entityColor`, `alphaTestRef`, `renderStage`, `sunPosition`, `moonPosition`, `shadowLightPosition`, `sunAngle`, `rainStrength`, `hasSkylight`, `endFlashIntensity`, `isEyeInWater`, fog uniforms and `gbufferModelViewInverse` against current Iris uniform documentation.
- Verified `depthtex1` excludes transparent geometry and first becomes meaningful in deferred. `gbuffers_water` executes after deferred, so using `depthtex1` to reconstruct opaque depth for water thickness is correctly staged.
- Verified `shadowtex0` includes all geometry and `shadowHardwareFiltering=true` enables comparison sampling as `sampler2DShadow`; the forward water/entity/particle paths use that contract.
- Verified `noisetex` is a generated square RGB8 texture (default 256×256); the particle dither path queries its actual size and uses `texelFetch`, avoiding a hardcoded resolution.
- Normalized the `WATER_FOG_MULT` value-list comment to Iris shader-option syntax. `WEATHER_TEX_OPACITY` is declared identically in weather and translucent-particle shaders; `PARTICLE_MATERIAL_FEATURES` is declared identically in opaque, translucent and generic lit-fallback programs. The validator now checks these declarations.
- Corrected over-escaped validator regular expressions so duplicate uniform declarations and forbidden G-buffer sampling are actually detected.
- CI run [45072296773](https://github.com/Pawar-47/Serene-Ultra/actions/runs/45072296773) passed vertex/fragment compilation, Iris render-stage macro compilation, program linking and structural validation. The only program-coverage notices are the intentional Iris fallbacks `gbuffers_terrain_solid` and `gbuffers_terrain_cutout` → `gbuffers_terrain`.
- This is an Iris contract/source audit, not an in-game runtime, visual-parity or performance result.


## Translucent-particle noise sampling re-aligned — 2026-11-23
The current Iris NoiseTex reference documents `noisetex` as a generated RGB8 square noise texture (256×256 by default), sampled with the normal sampler interface. The Complementary Reimagined `shaders/program/gbuffers_textured.glsl` reference samples its blue channel using `texture2DLod(noisetex, gl_FragCoord.xy / 128.0, 0.0).b`. Serene's post-deferred particle path previously used integer `texelFetch` modulo the texture dimensions, which changed the screen-space noise tile frequency and did not match the known-good reference. It now uses the same normalized-coordinate, explicit-LOD sampling form. The structural validator checks that exact expression. This is a source-level alignment; the visual dither pattern still needs in-game review.

## Opaque particle emissive classifier corrected — 2026-11-23
The Complementary Reimagined `gbuffers_textured.glsl` source was re-read around its particle-material block. Serene's opaque `gbuffers_particles` and `gbuffers_textured_lit` programs had a simplified classifier that treated nearly every bright grayscale texture as either an ender-family emitter or lava. This did not match the reference conditions and risked false positives. Replaced it with the source's actual grayscale-texture gate, color-energy and channel-ratio test for ender/crying-obsidian/redstone particles, and the separate red/orange lava test. Lava now also receives the reference RGB adjustment; the ender-family branch retains lightmap suppression and the 1.5 power adjustment. The validator checks the exact distinguishing predicates and rejects the superseded broad classifier. Iris contracts for `gtexture`, `lightmap`, `alphaTestRef`, `gl_Normal` and G-buffer outputs were checked before changing these stages.

## Iris gbuffers colortex sampling rule correction — 2026-11-23
Current Iris documentation says colortex samplers can be read from any program. The important distinction is buffer flipping: gbuffers and shadow programs read the main buffer and write the main buffer, so sampling an attachment that the same pass also writes can create a read/write race. Deferred/composite-style passes read main and write alt, then flip. The validator previously rejected every colortex0–3 sampler in every gbuffers shader; that was too broad and was not supported by the docs. It now parses each fragment shader's `RENDERTARGETS`/legacy `DRAWBUFFERS` targets and rejects only samplers that overlap the same pass's output attachments. Sampling a different, non-output colortex attachment is permitted by the validator, consistent with Iris documentation. The active water shader still avoids colortex sampling because it writes colortex0 and does not yet need a separate scene-color copy.


## Water refraction and screen-space reflection buffer audit — 2026-11-23
The latest water implementation was rechecked against Iris' current program-order, buffer-size, colortex-flip and depth-buffer documentation before changes were finalized. The crucial constraint is that a single pass cannot write render targets of different dimensions. Therefore `deferred.fsh` writes only full-resolution `colortex0`, while `deferred1.fsh` (which Iris runs after deferred and before translucent gbuffers) writes only half-resolution `colortex4`. `deferred1` reads the lit scene from `colortex0` and depth masks from `depthtex0` / `depthtex2`, excludes first-person hand/translucent pixels, and downsamples valid color in linear space. `flip.deferred1.colortex0=false` preserves its read-only source, `flip.deferred1.colortex4=true` publishes its output, and `size.buffer.colortex4=0.5 0.5` keeps the copy half resolution.

The forward `gbuffers_water` pass reads `depthtex1` for behind-water thickness/refraction validation, `depthtex2` for opaque-only SSR depth, and `colortex4` for the separate scene color. It writes only `colortex0`, so no same-attachment feedback occurs. Refraction and SSR are source/GLSL/structural validated, including a water-normal orientation correction based on Complementary's Iris-water workaround. They are not runtime or visual proof; low-step SSR and half-resolution refraction remain performance-oriented approximations.


## Routing caveat correction — 2026-11-23
The current Iris ordering reference documents `separateEntityDraws=true` but also warns that it may be broken in newer Iris versions. Accordingly, this directive is retained only as a best-effort request; the dedicated translucent entity/block-entity programs are not counted as guaranteed post-deferred coverage until tested in the target Iris build. `iris.features.optional=ENTITY_TRANSLUCENT` was removed because the feature flag only creates `IRIS_FEATURE_ENTITY_TRANSLUCENT` for shader-side capability checks; it does not activate routing, and no shader currently consumes that define. Particle ordering remains independently and explicitly set to `particles.ordering=mixed`.


## Animated water normal path — 2026-11-23
The water fragment stage now derives a three-band analytic wave normal from absolute player/world XZ coordinates. Iris documents `cameraPosition`, `frameTimeCounter`, and `gbufferModelView`; the code uses the first two to keep the pattern world-anchored and the third to transform the perturbed player-space normal into view space for Fresnel/refraction/SSR. The direct-light and shadow calculations retain the player-space normal. Wave strength and speed are shader options. Speed is an integer cycle count per 3600-second Iris timer interval so the phases remain continuous when `frameTimeCounter` wraps. This is a low-bandwidth approximation, not a claim of parity with Unbound's texture-driven normal map/parallax method.


## Water colour and noise sampler audit — 2026-11-23
The water fragment stage now samples Iris' documented read-only `noisetex` sampler once per water fragment for subtle colour variation. The sampler is only read; no custom image or texture binding is assumed. The base tint is restricted to the classified water material and preserves the incoming alpha. Its world-space UVs use `cameraPosition + vPlayerPosition`; temporal drift is periodic using the integer-cycle `frameTimeCounter` phase already used by the wave system, avoiding a discontinuity at the timer wrap. The two colour controls are exposed as shader options. The exact noise appearance and cost still require in-game calibration on Intel HD 5500.


## Water foam depth reconstruction — 2026-11-23
The water pass reuses the existing opaque-view thickness reconstructed from Iris `depthtex1` and `gbufferProjectionInverse`. The foam mask is `1.0 - smoothstep(0.035, 0.42, waterThickness)`, gated to top-facing water and valid opaque depth. It is applied to albedo before lighting and reduces the reflection contribution. This avoids a second depth fetch and does not add any gbuffers feedback. The threshold remains a first-pass approximation requiring runtime and visual calibration.


### Water foam depth signal correction — 2026-11-23
The foam mask now uses the existing `calculateWaterThickness` result, derived from Iris `depthtex1` and `gbufferProjectionInverse`, rather than comparing world-Y coordinates. The mask is `1 - smoothstep(0.035, 0.42, waterThickness)` and only runs on top-facing water fragments with valid opaque depth. This reuses the depth reconstruction already performed for refraction/absorption and adds no new depth texture fetch. The foam threshold is a first-pass world/view-space approximation and needs runtime visual calibration.


## Iris eye-fluid uniform declaration fix — 2026-11-23
A CI compile exposed that `gbuffers_water.fsh` referenced `isEyeInWater` without declaring it. Iris' current Player Status Uniforms reference defines it as `uniform int isEyeInWater` with values 0 (none), 1 (water), 2 (lava), and 3 (powdered snow). The water pass now declares the exact documented integer type and tests `== 1` for underwater-camera behavior. Structural validation now checks this declaration. Source: https://shaders.properties/current/reference/uniforms/status/.


## Translucent block material classification — 2026-11-23
The water vertex stage already receives Iris `mc_Entity.x` and forwards it to the fragment stage; Iris documents this attribute as valid in `gbuffers_water.vsh`, with IDs assigned by `block.properties`, while `mc_Entity.y` independently reports fluid render type. Added stable IDs for clear glass/panes, all stained-glass colours/panes, tinted glass and nether portal. The fragment stage now dispatches water-only depth/refraction/foam separately from glass reflection and portal emission. The glass reflection path reuses the existing `depthtex2`/`colortex4` screen-space reflection helper; it does not sample the current output attachment. The portal path uses the already animated vanilla atlas texture and adds self-emission without custom atlas raymarch. All mappings and branches are structurally validated; actual block routing, alpha sorting and visual response still require in-game checks.


## Translucent ice ID — 2026-11-23
Added `block.32004` for Minecraft ice/frosted ice using the documented `block.properties` to `mc_Entity.x` mapping. The water fragment stage treats ID 32004 as a reflective translucent material, not as water, so it receives Fresnel SSR but not water depth opacity/refraction/foam. Runtime render-layer routing and alpha behavior still need verification.


## G-buffer smoothness packing — 2026-11-23
The `colortex2` normal attachment now packs both deferred validity and a scalar smoothness value in alpha without adding another attachment. Alpha 0 is invalid (sky/overlay/sign text); 0.5 is valid non-smooth geometry; 0.5–1.0 encodes smoothness. The deferred validity test remains `normalData.a < 0.5`, so existing overlay masks remain deterministic. Terrain assigns smoothness only to the Iris `mc_Entity.x` IDs for slime and honey; entities, block entities, and lit particles use the valid zero-smoothness value. Deferred decodes the value and computes a specular half-vector only when smoothness is nonzero. This is an internal pack-owned G-buffer contract, not an Iris-provided alpha semantic.


## Beer-Lambert absorption path — 2026-11-23
The water pass applies absorption only after a valid refraction sample has passed the existing `depthtex1`/`colortex4` scene-copy checks. It operates on linearized scene colour and uses reconstructed `waterThickness` to compute per-channel exponential transmission. The tint comes from the same water material colour used for the surface, avoiding an independent hardcoded colour path. No new sampler or render target is introduced. The strength is a shader option; runtime colour/performance calibration remains required.


## Per-quad portal atlas sampling — 2026-11-23
The portal effect now uses Iris `mc_midTexCoord`, which the attribute reference documents as the center of the current quad's texture region and valid in `gbuffers_*.vsh`. The vertex stage applies the same texture matrix as `gl_MultiTexCoord0`, then forwards the midpoint and half extents as flat varyings. Four fragment samples are clamped to the per-quad region with a one-texel inset. This prevents sampling neighboring atlas sprites and does not require a custom texture or a screen-space attachment. It remains a bounded four-tap approximation; verify on the exact Iris/Minecraft runtime and with resource packs that alter portal atlas dimensions.


## Translucent shadowcolor pipeline — 2026-11-23
Iris documents `shadowtex0` as including all shadow casters, `shadowtex1` as opaque-only, and `shadowcolor0` as a color attachment writable from `shadow.fsh`. Serene now enables `shadowTranslucent=true`; the shadow fragment writes RGBA8 transmission data to `shadowcolor0` for water, clear/stained/tinted glass, ice and nether portal. The deferred pass keeps its four-tap `shadowtex0` PCF filter, then uses a center `shadowtex0`/`shadowtex1` comparison to detect a translucent caster and reads `shadowcolor0` only in that case. The result is RGB shadow transmission rather than a scalar shadow factor. `blend.shadow.shadowcolor0=off` prevents blending with stale values, and `flip.shadow.shadowcolor0=false` keeps the shadow pass's main attachment available to deferred. Iris clears shadowcolor buffers to white by default. This is a source-level implementation; verify actual shadow buffer ordering, alpha behavior and performance in Iris runtime.


## Water cauldron ID remap — 2026-11-23
The `block.properties` entry maps `minecraft:water_cauldron` to ID 10049. The `gbuffers_water.vsh` and `shadow.vsh` stages remap 10049 to the pack's cauldron-water ID 32001 before forwarding the material ID. This follows the same Iris `mc_Entity.x`/`block.properties` contract as other material IDs and avoids misclassifying the cauldron as a flowing-fluid render type. Water and shadow fragments treat 32001 as water material independently of `mc_Entity.y`.


## Forward translucent colored-shadow sampling — 2026-11-23
The post-deferred `gbuffers_water` pass now uses the same Iris `shadowtex0`/`shadowtex1`/`shadowcolor0` contract as deferred. This is necessary because water, glass and other translucent geometry are lit forward after deferred; using only `shadowtex0` there would treat the translucent blocker as opaque and produce inconsistent lighting. The water pass retains its four-tap `shadowtex0` PCF, then conditionally samples `shadowcolor0` when the center comparison detects a translucent caster. The returned RGB transmission modulates the water's direct lighting. No screen attachment feedback is introduced; the shadow samplers are separate from `colortex0`.


## Resource-pack tangent-space water normals — 2026-11-23
Verified Iris `at_tangent` documentation: the attribute is valid in `gbuffers_*.vsh`, stores an approximate model-space tangent in xyz and a handedness sign in w. The water vertex shader transforms the tangent with `gl_NormalMatrix` and back into player space with `gbufferModelViewInverse`. The fragment shader samples Iris' `normals` atlas; `MC_TEXTURE_FORMAT_LAB_PBR` controls the DirectX Y inversion, while oldPBR retains Y+. The bitangent uses `cross(tangent, geometricNormal) * handedness`. Iris supplies a neutral `(127,127,255)` normal when no `_n` map exists, so packs without PBR normals retain the analytic wave normal. This uses documented Iris attributes/samplers and does not assume the resource pack supplies a normal map.


## Iris PBR specular atlas decoding — 2026-11-23
Verified Iris' `specular` sampler and `MC_TEXTURE_FORMAT_LAB_PBR` macro. Terrain, entity and block-entity G-buffer programs sample the resource-pack specular atlas once per fragment. Red is smoothness in both formats; oldPBR green/blue are metalness/emissive, while LabPBR green stores the normalized raw F0/metal code (`code / 255`), which deferred decodes to 0–0.08 dielectric F0 for codes 0–229 and albedo-tinted metal for codes 230–255; alpha is emissive (255 means none). The resulting reflectance scalar is stored in `colortex3.g`, with emission in `.r`; all three opaque G-buffer families also use Iris `normals` plus `at_tangent`/handedness for tangent-space normal maps. `colortex3Format=RGBA8` preserves emission, reflectance, AO and LabPBR surface data in one attachment. Deferred reads the scalar and uses albedo-coloured F0 for metal or dielectric F0 for non-metal. CI now compiles both default oldPBR and explicit LabPBR macro branches.
