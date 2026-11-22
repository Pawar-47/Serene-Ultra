# Project Checkpoint — 2026-11-23

## Repository
https://github.com/Pawar-47/Serene-Ultra

## Source archive roles and mandatory comparison rule
## Two-reference engineering rule (mandatory)
Both supplied shader archives are active technical references, not merely one engine reference plus one visual mood board. Consult both when designing, reviewing, debugging or validating a rendering feature. When uncertain whether an approach, formula, interface, shader stage, texture lookup, buffer, pass order or code path is correct, inspect the corresponding/relevant files in **both** archives, compare how each achieves or expects the behavior, and record the evidence before choosing an implementation. If the files are not directly equivalent, trace the related stages and shared inputs/outputs rather than forcing a one-file match. Use Vanilla-stock to establish Minecraft 26.3's native contracts and behavior; use the working shader to understand proven feature implementation, visual treatment, quality controls and Ultra expectations. Then write an original Serene Ultra implementation that respects the stock engine contract while pursuing the reference's visual contribution, adapted for Intel HD 5500 without dropping Ultra features. Do not blindly copy either source, and do not claim a comparison was performed unless the relevant files were actually inspected.

- Minecraft 26.3 Vanilla-stock archive: stock engine source and native behavior/interface reference.
- Good working shader (Complementary Reimagined): technical implementation and visual/feature/menu reference, especially Ultra.
- For every uncertain implementation decision, inspect relevant files in both archives, compare contracts and techniques, then implement independently. Neither archive is optional; do not claim comparisons without inspecting the files.
- Serene Ultra repository: implementation source of truth.

The Vanilla-stock archive contains 89 shader source files (42 fragment, 30 vertex and 17 GLSL includes). The next audit pass must record exact stock paths and cross-check the current pipeline. Do not claim this has been completed until the archive source has actually been inspected.

## Work completed in this session
- Identified a same-attachment deferred read/write hazard: deferred previously sampled colortex0 while writing colortex0.
- Historical first implementation used colortex3 as deferred output and copied it back in composite. **Superseded on 2026-11-23:** deferred and composite now use Iris main/alternate flipping on logical colortex0; see the authoritative correction section below.
- Added an initial eight-neighbor depth-based screen-space contact AO approximation.
- AO attenuates ambient lighting only; direct celestial light is left intact.
- Added AO_STRENGTH and AO_RADIUS controls to the Quality menu and all five profile presets.
- Expanded structural validation to enforce separate deferred/composite attachments and the AO controls.
- Added a CI stage that installs glslang-tools and compiles every .vsh/.fsh shader stage; this is stronger than structural checks but still not an Iris runtime test.
- Updated architecture, feature matrix, living project brief and checkpoint.

## Current profiles
- Ultra-Light: 512 shadow map / 96-block shadow distance.
- Smooth: 1024 shadow map / 128-block shadow distance.
- Ultra: 2048 shadow map / 224-block shadow distance.
- HDR: Ultra shadow settings plus HDR-style tone mapping.
- Ultra-HDR: Ultra shadow settings plus stronger highlight compression.

These remain preliminary. AO controls currently use the same defaults in all profiles; complete system-wide quality budgets are still in progress.

## Validation status
- Shader, menu, validator and documentation changes are committed to main.
- GitHub Actions passed on latest checkpoint commit 0aa56289cc8ff55d1fd4dc489eaa27b2fb0190b3 (run 45060098775, job validate).
- CI now installs glslang-tools, compiles every .vsh/.fsh stage, and then runs the structural validator; both compiler and structural steps passed.
- No GLSL compiler or Minecraft/Iris runtime test has confirmed these passes.
- No visual parity comparison or target-machine performance measurement has been performed.
- The AO implementation is an initial screen-space approximation; depth bias, view-space reconstruction, camera stability, edge artifacts and GPU cost need calibration.
- The current stock shader archive has not yet been inspected file-by-file in this session, so do not treat vanilla interface cross-check as complete.

## Next actions
1. Inspect the actual Minecraft 26.3 Vanilla-stock files for terrain, entities, hand, shadow, deferred/composite and final/post passes; document exact paths and reconcile interfaces.
2. Continue material classification, advanced colored light, AO refinement, translucency, water/reflections, atmosphere and the remaining Ultra features.
3. Obtain GLSL/Iris runtime validation and target-machine comparisons; do not publish an unverified release.


## Iris-specific continuation update — 2026-11-23
- Confirmed current `main` HEAD before this audit was `826fe3ee513e5b3d35afa42473f2717864fbef9a`.
- Verified the latest CI run for that HEAD: `45060295410`, conclusion `success` (structural validation + standalone GLSL stage compilation).
- Corrected the validation record: this latest run is newer than the previously cited `0aa562...` checkpoint.
- Clarified the execution boundary: Iris is the shaderpack loader/runtime contract; Vanilla-stock describes native Minecraft pipeline behavior; Complementary Reimagined is the working Iris source/visual reference.
- Added `docs/IRIS_PIPELINE_AUDIT.md` using the published Iris program, buffer, depth and blending contracts.
- Identified a high-priority likely overwrite hazard in the former colortex3 copy-back design. **Superseded:** the attachment flow was corrected using Iris main/alternate flips. Dedicated water/weather/hand-water shading and in-game tests are still required.
- The exact supplied ZIP archives were not available through the current Project Files listing during this pass; no file-by-file comparison of their contents is claimed. Continue using already recorded archive inventory, and obtain the actual archive bytes through the normal attachment/project access path before making feature-specific choices that require line-level reference evidence.

### Next actions (priority order)
1. Inspect the actual Complementary water/weather/hand-water programs and their render-target/blend/order configuration, alongside the relevant Vanilla-stock source and Iris docs.
2. Design explicit post-deferred handling for water, weather and hand-water, respecting Iris attachment flips and blending.
3. Add Iris program coverage for block entities, particles, translucent entities and remaining required geometry using the reference inventory and Iris fallback table.
4. Expand tests to detect missing post-deferred program coverage and invalid attachment contracts.
5. Run Iris runtime tests in scenes containing water, rain/snow, first-person hand water, particles, entities, signs/text and all dimensions.

- Latest repository HEAD after this audit: `26d5aafb525029b31739f56e70ea5625571e0304`.
- Latest CI run on that exact HEAD: `45060856038`, conclusion `success`; both standalone GLSL compilation and structural validation completed successfully.
- Structural validation now rejects gbuffers shaders that declare sampler reads from Iris-forbidden colortex0–3 and prints a non-failing warning while the dedicated post-deferred water/weather/hand-water programs remain absent.


## Lighting correction — 2026-11-23
- Reviewed the live deferred lighting source and found its former day/night expression `1.0 - smoothstep(0.45, 0.55, sunAngle)` inconsistent with Iris' documented cycle (0=dawn, 0.25=noon, 0.5=sunset, 0.75=midnight): it treated dawn as full daylight and had a discontinuity at the cycle wrap.
- Replaced it with `solarElevation = sin(sunAngle * 2π)` and `smoothstep(0.0, 0.30, solarElevation)`. This produces a continuous daylight envelope: zero at dawn/sunset, peak at noon and zero through night.
- Extended the structural validator to require the cyclic expression and reject the previous incorrect formula.
- This is an Iris-contract source correction. It has not yet been validated in Minecraft/Iris or compared against the actual supplied archive contents.
- Translucent water/weather/hand-water path remains unresolved and is still the next major pipeline task; do not add speculative fallback shaders until the exact reference source and Iris attachment behavior can be traced.


- Added a numeric validator check for dawn/noon/sunset/midnight samples of the Iris cyclic daylight envelope; it checks the expected phase values rather than relying only on source-token matching.
- The validator update is commit `acf8636551ab25b279cd8a943e78bae6e863eb14`; feature matrix now records the corrected sunAngle curve as implemented at source level but pending runtime/parity validation.
- The previous validator commit `82ae4bd54c68367318cbff3db72ad076eb9a62a7` passed CI run `45061812544` (GLSL compilation and structural validation). The newer documentation commit `534ea3ff5afba82b6a09068c914f609b3a4f30c3` triggered run `45061849870`, which was still compiling GLSL at the time of this checkpoint update. The latest validator commit will trigger another run; check its result before reporting success.
- Latest known source commit before this checkpoint update: `acf8636551ab25b279cd8a943e78bae6e863eb14` (validator); matrix update commit: `eef5a0c173ac5e4e9abccb16bde407973476dbf2`.

## Post-deferred scene preservation — 2026-11-23
- Re-read the Iris rendering documentation: deferred/composite passes read the main buffer, write the alternate buffer, and flip after the pass by default. Same-logical-attachment read/write is therefore supported in these composite-style passes.
- Corrected the previous colortex3 copy-back architecture. Deferred now writes its lit opaque result to logical colortex0 with explicit flip.deferred.colortex0=true.
- Added explicit source-alpha blending on colortex0 for gbuffers_water, gbuffers_weather and gbuffers_hand_water. Water fallback auxiliary attachments colortex1/2 are explicitly unblended.
- Composite now performs a colortex0-to-colortex0 pass-through with explicit flip.composite.colortex0=true, preserving post-deferred translucent geometry instead of copying an opaque-only colortex3 image over it.
- Extended structural validation to enforce the deferred/composite attachment and flip directives plus all three translucent blend directives.
- This is an Iris-documentation-grounded source correction. It still requires Iris/Minecraft runtime validation; fallback water shading remains basic and does not yet implement the full Ultra water feature set.
## Authoritative pipeline correction and fallback audit — 2026-11-23
- Current main HEAD at start of this continuation: e52e0447ca949d488f7d0c520c1ec772ed15c627. CI run 45062112552 completed successfully (standalone GLSL compilation + structural validation).
- Corrected stale architecture commentary: deferred no longer writes colortex3 and composite no longer copies colortex3 back to colortex0. Both passes use Iris main/alternate flipping on logical colortex0.
- Verified Iris fallback routing from the current Iris program reference: gbuffers_water → gbuffers_terrain; gbuffers_weather → gbuffers_textured_lit; gbuffers_hand_water → gbuffers_hand; gbuffers_block → gbuffers_terrain; gbuffers_entities_translucent → gbuffers_entities; gbuffers_block_translucent → gbuffers_block; gbuffers_particles → gbuffers_textured_lit; gbuffers_particles_translucent → gbuffers_particles (translucent particle ordering requires particles.ordering=mixed).
- The missing dedicated water/weather/hand-water programs are fallback-covered but are not feature-complete. Dedicated water lighting/reflections, weather treatment and hand-water shading remain pending.
- This continuation has not inspected the actual bytes of the supplied Complementary and Vanilla-stock ZIPs; no line-by-line archive comparison is claimed. Iris documentation and the current repository source are the evidence used here.
- Next implementation target remains dedicated water forward shading, then weather and first-person translucent coverage, followed by other missing program families.

## Current authoritative state (2026-11-23)
- `main` currently uses deferred `RENDERTARGETS: 0`, with `flip.deferred.colortex0=true`; composite reads/writes logical colortex0 with `flip.composite.colortex0=true`.
- The old colortex3 output/copy-back architecture is historical only. Earlier sections above describe the original implementation and should not be used as current instructions.
- Iris CI run `45062112552` passed on commit `e52e0447ca949d488f7d0c520c1ec772ed15c627`. The current documentation/validator reconciliation commits are newer and their CI must be checked separately.
- Iris fallback routing is documented in `docs/IRIS_PIPELINE_AUDIT.md`. Missing dedicated water/weather/hand-water shaders currently fall back to terrain/textured-lit/hand; fallback routing is not feature parity.
- Dedicated water/weather/hand-water material implementations, broader geometry coverage, archive line-by-line comparison, Iris runtime testing, visual parity and target hardware measurements remain outstanding.

- Expanded `tools/validate_pack.py` to report the complete current Iris fallback coverage set (water, weather, hand-water, block entities, translucent entities/block entities, particles/translucent particles, solid and cutout terrain). Each missing dedicated vertex+fragment pair is reported with its documented immediate Iris fallback; this remains a non-failing warning until those programs are implemented and runtime-tested.
- Added a guard against stale colortex3 scene-output references in deferred.fsh.
- Validator expansion commit: `99682a6765f47579c311412bed11cb87984953c0`; check its CI result and the latest main HEAD before treating it as green.

## Full-source Iris audit correction pass — 2026-11-23
- Verified Iris docs: `shadowHardwareFiltering` and `shadowIntervalSize` are GLSL constants. Moved both into `deferred.fsh`; removed their invalid `shaders.properties` assignments; corrected validator accordingly.
- Disabled `separateAo`: with this setting enabled Iris moves AO into `gl_Color.a`, but current G-buffer uses vertex alpha as material opacity. Keeping it false preserves cutout/transparency semantics.
- Replaced hard-coded G-buffer alpha cutoffs with Iris `alphaTestRef` in terrain, entity and hand fragment shaders.
- Applied Iris `entityColor` tint to entity albedo using the documented alpha blend factor.
- Changed deferred world reconstruction and contact AO from `depthtex0` to `depthtex2`, which excludes transparent and first-person hand geometry.
- Explicitly set `particles.ordering=mixed` so opaque particles run before deferred and translucent particles after deferred.
- `separateEntityDraws` remains disabled because Iris warns it may not work in newer versions.
- Updated the validator to require these Iris contracts and reject the prior incorrect settings.
- These are source-level corrections; CI compilation/structural checks and runtime validation remain separate.

### Deferred depth-mask refinement
- Added `depthtex0` as an all-geometry mask alongside `depthtex2` for opaque-world reconstruction.
- If `depthtex0` and `depthtex2` differ at a pixel, deferred preserves the accumulated scene color rather than applying the opaque background's lighting to hand/translucent pixels.
- Validator now requires this mask and confirms world reconstruction uses `depthtex2`.
- Runtime verification remains pending, especially first-person hand and translucent entity edge cases.

## Atlas and lightmap correction — 2026-11-23
- Replaced the reserved `texture` sampler alias with Iris' documented `gtexture` atlas sampler in terrain, entity, hand and shadow fragments; switched to modern `texture()` calls.
- Removed the unused terrain view-position varying.
- Normalized the Iris transformed sky-light coordinate before storing the direct-light mask in terrain/entity G-buffers. The vanilla lightmap sample still uses the unmodified transformed UV.
- Extended structural validation to enforce the atlas sampler and lightmap normalization contracts.

## Shadow-distance culling correction — 2026-11-23
- Added Iris GLSL constant `shadowDistanceRenderMul = 1.0` to `shadow.vsh`.
- Iris docs state that `shadowDistance` alone changes projection scale but does not cull out-of-range geometry; a positive `shadowDistanceRenderMul` enables culling.
- Added a validator requirement for the culling constant. Runtime performance and boundary behavior remain to be measured.

## Particle implementation — 2026-11-23
- Added `gbuffers_particles.vsh/.fsh` for opaque particles before deferred. It writes albedo, vanilla lightmap RGB plus normalized sky-light mask, and player-aligned normals to colortex0/1/2.
- Added `gbuffers_particles_translucent.vsh/.fsh` for translucent particles after deferred. It writes only colortex0, applies the vanilla lightmap, and uses explicit source-alpha blending.
- Added explicit per-program blending configuration and expanded `tools/validate_pack.py` to require both particle program pairs and their output contracts.
- Corrected the `AO_STRENGTH` option values to include the 0.65 profile default.
- This closes the missing Iris particle program paths at source level; it does not establish Complementary Ultra parity or runtime validation.

## First-person hand lightmap correction — 2026-11-23
- Added transformed lightmap UVs to `gbuffers_hand.vsh` using Iris `gl_TextureMatrix[1] * gl_MultiTexCoord1`.
- Added `lightmap` sampling to `gbuffers_hand.fsh`, restoring the vanilla colored lightmap response that the Iris `gbuffers_textured_lit` fallback provides.
- Validator now requires hand lightmap sampling.
- Iris `heldBlockLightValue` and `heldBlockLightValue2` dynamic held-item lighting is not yet implemented.

## Dimension-aware lighting correction — 2026-11-23
- Added Iris `hasSkylight` and `endFlashIntensity` uniforms to deferred lighting.
- Gated sun/moon direct light to dimensions with skylight; dimensions without skylight no longer receive the Overworld solar cycle.
- Enabled `endFlashShadows=true` so Iris can set `shadowLightPosition` to the End flash. End direct light is gated by `endFlashIntensity`.
- Added an early condition to avoid shadow-map sampling when `nDotL` or the active celestial gate is zero.
- Validator now requires the Iris dimension and End-flash contracts. Runtime dimension testing remains pending.

## Emissive eye overlay correction — 2026-11-23
- Added `gbuffers_spidereyes.vsh/.fsh` using Iris `gtexture` and `alphaTestRef`.
- The pass writes color to colortex0 and a zero deferred-validity mask to colortex2, preventing opaque entity normals behind spider/enderman/dragon eyes from darkening the emissive overlay.
- Added `blend.gbuffers_spidereyes.colortex2=off` and structural validation for the mask.

- Refined validator reporting so `gbuffers_entities_translucent` and `gbuffers_block_translucent` are only reported as missing when `separateEntityDraws=true`; that Iris option remains intentionally disabled due the current docs warning. Translucent entity compatibility remains a runtime test item.

## Dedicated water forward path — 2026-11-23
- Added `gbuffers_water.vsh/.fsh` as a dedicated post-deferred forward renderer.
- It uses Iris `gtexture`, transformed lightmap coordinates, player-space position/normal, `shadowtex0`, `shadowModelView` and `shadowProjection`.
- It reuses the dimension-aware sun/moon/End-flash gate and shadow sampling, outputs only `colortex0`, and uses the existing source-alpha blending directive.
- Added validator checks for its forward-only output, lightmap and shadow contracts.
- This removes reliance on the unlit `gbuffers_terrain` fallback for water. Refraction, Fresnel/reflections, absorption/depth tint, wave normals, rain ripples and reference Ultra parity are still pending.