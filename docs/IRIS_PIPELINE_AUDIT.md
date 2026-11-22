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