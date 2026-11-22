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

Serene's current `deferred.fsh` writes opaque lit output to `colortex3`. The current `composite.fsh` then copies `colortex3` to `colortex0`.

Iris documents that translucent terrain/water, weather and hand-water are among the gbuffers programs that execute after deferred. In the current pack, those program names are absent, so Iris can route them through fallback shaders such as `gbuffers_terrain` or `gbuffers_hand`. Those existing fallback shaders write scene color/G-buffer data, while the later composite copy-back takes its source from the opaque deferred result in `colortex3`.

This creates a likely overwrite hazard: post-deferred geometry rendered into the scene-color path may be replaced by the subsequent composite copy. The exact visual manifestation must be confirmed in Iris runtime/debug mode, but the current architecture must not be considered water/weather/hand-water compatible until this is resolved.

Do not patch this by guesswork. Before implementing the fix:
1. Inspect Complementary's actual `gbuffers_water`, `gbuffers_weather`, `gbuffers_hand_water`, relevant composite passes and their `shaders.properties` blending/ordering/target directives.
2. Inspect the matching Minecraft 26.3 stock shader paths to understand water/weather/hand-water native inputs and blending expectations.
3. Trace Iris target flips and blending for the selected implementation.
4. Design explicit post-deferred forward paths or isolated translucent accumulation targets; preserve correct alpha/depth ordering and avoid sampling forbidden colortex0–3 from gbuffers.
5. Add static checks and Iris runtime scene tests for water, rain/snow and first-person water.
6. Compare each result to Complementary Ultra and vanilla behavior.

## Required next implementation sequence

1. Resolve and test the post-deferred water/weather/hand-water path.
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
