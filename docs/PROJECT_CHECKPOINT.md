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
- Changed deferred to read the scene from colortex0 and write lit output to colortex3.
- Changed composite to read colortex3 and write the completed scene back to colortex0.
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
- Identified a high-priority likely overwrite hazard: `gbuffers_water`, `gbuffers_weather` and `gbuffers_hand_water` run after deferred, while the current composite copies colortex3 over colortex0. Those dedicated program files are absent, so Iris fallback behavior may route them through opaque G-buffer shaders and the later copy-back may overwrite their contribution.
- This is a source-level risk, not a runtime-confirmed bug. Do not claim water/weather compatibility until explicit paths and in-game tests exist.
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