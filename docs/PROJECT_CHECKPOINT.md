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

- Historical repository HEAD at this earlier checkpoint: `26d5aafb525029b31739f56e70ea5625571e0304` (superseded by the later audit and implementation commits below).
- Historical CI run on that exact HEAD: `45060856038`, conclusion `success`; later source and validator changes are tracked by the newer run IDs recorded below.
- At that earlier checkpoint the validator used an overbroad blanket ban on colortex0–3 reads in gbuffers and the dedicated water/weather/hand-water programs were absent. Both conditions were superseded: the current validator rejects only same-attachment read/write conflicts, and all three dedicated post-deferred programs are now implemented.


## Lighting correction — 2026-11-23
- Reviewed the live deferred lighting source and found its former day/night expression `1.0 - smoothstep(0.45, 0.55, sunAngle)` inconsistent with Iris' documented cycle (0=dawn, 0.25=noon, 0.5=sunset, 0.75=midnight): it treated dawn as full daylight and had a discontinuity at the cycle wrap.
- Replaced it with `solarElevation = sin(sunAngle * 2π)` and `smoothstep(0.0, 0.30, solarElevation)`. This produces a continuous daylight envelope: zero at dawn/sunset, peak at noon and zero through night.
- Extended the structural validator to require the cyclic expression and reject the previous incorrect formula.
- This is an Iris-contract source correction. It has not yet been validated in Minecraft/Iris or compared against the actual supplied archive contents.
- Historical checkpoint: the initial translucent water/weather/hand-water path was unresolved. Superseded for water by the dedicated forward water program committed 2026-11-23; weather and hand-water remain outstanding.


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
- Historical note: water/weather/hand-water were all fallback-covered at the time. Superseded for water by a dedicated forward-lit path; advanced water effects, dedicated weather and dedicated hand-water remain pending.
- This continuation has not inspected the actual bytes of the supplied Complementary and Vanilla-stock ZIPs; no line-by-line archive comparison is claimed. Iris documentation and the current repository source are the evidence used here.
- Next implementation target after the water baseline is dedicated weather and first-person hand-water rendering, followed by remaining special geometry and advanced water effects.

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
- The earlier decision to disable `separateEntityDraws` was based on an incorrect interpretation of the docs; current Iris documentation explicitly supports the true setting and dedicated translucent entity/block-entity passes. The active config now enables it and queries `ENTITY_TRANSLUCENT`.
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

- The validator now requires the dedicated `gbuffers_entities_translucent` and `gbuffers_block_translucent` pairs because the documented Iris `separateEntityDraws=true` route is enabled. Translucent entity sorting and compatibility remain runtime test items.

## Dedicated water forward path — 2026-11-23
- Added `gbuffers_water.vsh/.fsh` as a dedicated post-deferred forward renderer.
- It uses Iris `gtexture`, transformed lightmap coordinates, player-space position/normal, `shadowtex0`, `shadowModelView` and `shadowProjection`.
- It reuses the dimension-aware sun/moon/End-flash gate and shadow sampling, outputs only `colortex0`, and uses the existing source-alpha blending directive.
- Added validator checks for its forward-only output, lightmap and shadow contracts.
- This removes reliance on the unlit `gbuffers_terrain` fallback for water. Refraction, Fresnel/reflections, absorption/depth tint, wave normals, rain ripples and reference Ultra parity are still pending.

## Dedicated weather forward path — 2026-11-23
- Added `gbuffers_weather.vsh/.fsh` for Iris post-deferred rain/snow geometry.
- It samples `gtexture` and `lightmap`, applies the documented Iris fog uniforms and writes only colortex0.
- Added explicit `rain.depth=false` to preserve the color-only weather path and the existing source-alpha blend directive.
- Extended structural validation to require weather atlas/lightmap/fog contracts.
- Volumetric weather, rain streaks, wet-surface response and reference Ultra parity remain pending.

## Iris fog integration — 2026-11-23
- Added Iris fog uniforms and linear/exp/exp2 calculations to deferred opaque lighting.
- Added matching fog to forward water, weather and translucent-particle programs.
- Used `fogShape` to choose spherical or cylindrical distance.
- Fog color is converted to linear space and blended before re-encoding to avoid mixing encoded colors.
- Extended structural validation for the fog contracts. Hand-water remains on the hand fallback and needs a dedicated path.

## Dedicated hand-water path — 2026-11-23
- Added `gbuffers_hand_water.vsh/.fsh` as a post-deferred forward color-only program.
- It samples `gtexture` and `lightmap`, applies the Iris fog uniforms, and writes only colortex0.
- It uses the existing source-alpha blend directive and does not sample colortex0–3.
- Extended structural validation to require the dedicated hand-water pair and forward output contract.
- Runtime verification and dynamic held-item illumination remain pending.

- Updated first-person hand lightmap multiplication and `entityColor` tint blending to occur in linear space, following Iris' fog guide's color conversion guidance. Source-buffer color-space assumptions remain subject to supplied reference-source comparison and runtime calibration.

## Current post-deferred program state — 2026-11-23
- `gbuffers_water`, `gbuffers_weather` and `gbuffers_hand_water` now all have dedicated forward color-only programs; none relies on its former Iris fallback.
- Water uses Iris gtexture/lightmap/shadow map, dimension-aware celestial lighting and fog.
- Weather uses Iris gtexture/lightmap and fog; `rain.depth=false` remains explicit.
- Hand-water uses Iris gtexture/lightmap and fog.
- All use explicit source-alpha blending and avoid sampling `colortex0`, the attachment they write. Iris permits sampling a different, non-output colortex attachment; the validator checks only same-attachment conflicts.
- Advanced water effects, volumetric weather, dynamic held-item illumination, special geometry and runtime/visual parity remain outstanding.


- Added Iris fog to the emissive spider-eyes program while retaining its colortex2 deferred-validity mask.

## Expanded Iris geometry coverage audit — 2026-11-23
- Extended the validator's fallback inventory to include damaged blocks, beacon beams, armor glint, clouds, skybasic/skytextured, lightning, lines, textured-lit and textured fallback programs.
- The remaining special geometry is now visible as non-failing CI warnings with documented Iris fallback destinations; it is not silently treated as feature-complete.

## Verified continuation checkpoint — 2026-11-23

- Current main HEAD at checkpoint: d21c8861cd56ba819c16261432a05c441b91452c.
- CI run 45064958176 passed all stages: GLSL compile, vertex/fragment program linking, and structural Iris-contract validation.
- Dedicated post-deferred programs now exist for water, weather and hand-water. Opaque/translucent particle programs are dedicated; spider eyes have an emissive path that invalidates deferred normal data and still applies fog.
- Deferred and forward passes use Iris fog uniforms; water/weather/hand-water/translucent particles apply fog in their forward programs.
- Existing code corrections include Iris gtexture sampler naming, alphaTestRef, entityColor, lightmap UV normalization, depthtex0/depthtex2 masking, shadow constants, shadow-distance culling, dimension/End-flash lighting, and linear-space lightmap/tint/fog operations.
- The validator tracks the broader Iris gbuffers fallback table. Remaining special paths include armor glint, beacon beams, clouds, skybasic/skytextured, lightning, line and damaged-block. Dedicated translucent entity/block-entity programs are now enabled through `separateEntityDraws=true`.
- The supplied Complementary Reimagined and Vanilla-stock inventories remain the source-reference baseline. This continuation has not claimed a fresh byte-for-byte/line-by-line archive comparison; reference-dependent advanced water/material decisions must still be traced against those archives before finalizing.
- CI passing proves standalone GLSL compile/link and structural checks only. Minecraft 26.3 + Iris loading, visual correctness, feature parity and Intel HD 5500 performance remain unverified.
- No release is ready or being declared.

### Next work
1. Continue special geometry paths in order of visual impact, beginning with emissive/additive overlays (armor glint, beacon beam, lightning) and clouds/sky, validating each program and its fallback against Iris docs before editing.
2. Cross-reference the supplied Complementary water, fog, shadow and material implementations and the Vanilla-stock inputs before advanced water/reflection/material algorithms.
3. Implement wet surfaces/puddles, material classification, emissive/colored lighting, improved AO, reflections, volumetrics and anti-aliasing without removing Ultra features.
4. Keep CI green after each coherent change; then perform actual Iris runtime and target-hardware tests.

- Shadow caster alpha testing now uses the stricter of Iris `alphaTestRef` and the Serene `SHADOW_ALPHA_CUTOFF` option; validator enforces both.

- Translucent particle shader now preserves fractional alpha and only discards near-zero alpha; Iris `alphaTestRef` remains on opaque/cutout particle paths.

## Iris scope correction — `gbuffers_water` — 2026-11-23
- Iris documents `gbuffers_water` as all translucent terrain, including water and stained glass.
- Renamed water-specific local symbols to generic translucent-surface symbols and corrected the pipeline comments.
- The current shader applies the same forward diffuse/lightmap/shadow/fog baseline to all geometry routed through this program; it does not claim fluid-specific refraction, Fresnel, or absorption.
- Iris' `mc_Entity.y` is the documented fluid discriminator (`1.0` fluids, `-1.0` other terrain) and is reserved for the next reference-guided material-specific pass.

## Latest verified HEAD — 2026-11-23
- Current main HEAD: cb09a49bd55517a3d76f6eb7bed9d885e065e2cd.
- CI run 45065219372 passed GLSL compilation, vertex/fragment linking for every program pair, and structural Iris-contract validation.
- Final audit refinements in this checkpoint: shadow cutout uses max(Iris alphaTestRef, SHADOW_ALPHA_CUTOFF); translucent particles retain fractional alpha and discard only near-zero alpha; stale water-fallback comments and unused water auxiliary blend directives were removed.
- No runtime, visual parity or Intel HD 5500 performance claims are made.

## Reference-guided water material checkpoint — 2026-11-23
- Added `shaders/block.properties` stable material IDs and Iris `mc_Entity` handling in `gbuffers_water.vsh`.
- Water/water-cauldron are isolated from other translucent terrain; only these materials receive depth-dependent alpha attenuation.
- Uses `depthtex1`, which Iris documents as excluding transparent geometry and becoming valid by deferred; the post-deferred `gbuffers_water` stage can safely sample it.
- Reconstructs underlying opaque view position with `gbufferProjectionInverse` and applies the reference water-depth opacity curve.
- Added `WATER_FOG_MULT` control with Complementary's 25–900% range and Iris alphaTestRef support.
- CI run 45065527686 passed GLSL compilation, stage linking and structural validation before the final slider-range refinement; the final refinement has a separate run pending.
- Still pending: water normals/waves, Fresnel/reflections, refraction, foam/caustics, underwater response, and runtime/visual parity.

## Latest correction — water material and depth handling (2026-11-23)
- Confirmed from Iris docs: `gbuffers_water` handles all translucent terrain; `mc_Entity` is valid in its vertex shader; `.x` is `block.properties` ID and `.y` is fluid render type.
- Added stable water-only ID 32000 and gated fluid effects on both ID and `mc_Entity.y > 0.5`.
- Corrected depth thickness reconstruction to use `depthtex1` plus `gbufferProjectionInverse`, including clear depth 1.0. Removed incorrect use of Iris `far` as projection far plane (it is render distance).
- Water alpha-test directive is intentionally set to `GREATER 0.0001`, matching Complementary Reimagined; shader reads the resulting Iris `alphaTestRef` uniform.
- Matched the reference shader's depth-difference exponential water opacity formula and retained a `WATER_FOG_MULT` control.
- Still pending: reference-guided water Fresnel/reflections/refraction/waves/normals/foam/absorption and in-game validation.

## Special geometry update — 2026-11-23
- Added `gbuffers_armor_glint.vsh/.fsh`; preserves the Complementary glint-strength RGB multiplier and clears colortex2 validity only for nontransparent glint fragments. Color blend state is intentionally not overridden.
- Added `gbuffers_lightning.vsh/.fsh`; preserves entityColor tint, applies Iris fog and clears the deferred normal mask. Iris docs note dragon-death beam depth is supplied by `gbuffers_basic`.
- Added `gbuffers_beaconbeam.vsh/.fsh`; applies emissive response and Iris fog, uses alphaTestRef, and clears the deferred normal mask.
- Added per-program `colortex2=off` mask blending and structural checks.
- CI run 45066097345 passed GLSL compilation, vertex/fragment linking and structural validation.
- Runtime blend/depth behavior is not yet verified in Minecraft 26.3 + Iris.

Correction to the water alpha note: `alphaTest.gbuffers_water=GREATER 0.0001` is intentionally retained to match the working Complementary reference. The fragment shader reads the resulting Iris `alphaTestRef`; it does not hardcode the threshold. Water alpha now also uses the reference `sqrt(alpha)` shaping and exact-pixel `texelFetch` from `depthtex1`.

## Weather and cloud checkpoint — 2026-11-23
- `gbuffers_weather` now classifies rain vs snow using the Complementary reference's texture-color test and applies reference defaults (0.25 rain / 0.5 snow) with a 25–900% `WEATHER_TEX_OPACITY` control.
- Weather uses Iris `alphaTestRef`, discards when `isEyeInWater==3` (powdered snow), and has optional `WAVING_RAIN` vertex motion driven by `rainStrength`, `eyeBrightnessSmooth` and `frameTimeCounter`.
- Added dedicated `gbuffers_clouds`; it preserves vanilla cloud texture/vertex color, applies Iris fog, discards while the camera is in fluid, and bypasses deferred lighting via colortex2 validity mask.
- These are baseline paths, not custom cloud/volumetric parity. Runtime depth, blend and visual behavior remains pending.

## Sky and textured fallback checkpoint — 2026-11-23
- Added `gbuffers_textured` to handle unlit texture fallback geometry with Iris alphaTestRef/fog and deferred-normal bypass.
- Added `gbuffers_skytextured`; uses `renderStage` macros for sun/moon, dims by rain and underwater state, and preserves other sky textures.
- Added `gbuffers_skybasic`; uses `skyColor`/`fogColor`, render-stage macros for sky/sunset/stars/void, and reconstructs direction only for sky/sunset fragments.
- These are lightweight baseline sky paths, not Complementary's full atmospheric scattering, stars or volumetric clouds. Textured particle lighting remains incomplete.

## Sky and unlit textured geometry — 2026-11-23
- Added dedicated `gbuffers_skybasic`, `gbuffers_skytextured` and `gbuffers_textured` programs rather than relying on generic fallbacks.
- Sky-basic uses Iris render-stage macros for sky, sunset, stars and void; sky-textured distinguishes sun and moon render stages and uses Iris view-space celestial positions.
- Sky colors are linearized in the vertex stage; sky direction reconstruction is limited to sky/sunset fragments to avoid unnecessary per-fragment matrix work for stars/void.
- Sky and overlay paths write a zero deferred-validity mask; colortex2 blending is disabled for each relevant program.
- The textured fallback preserves atlas/vertex color and applies Iris fog without sampling forbidden G-buffer color attachments.
- Added CI compilation of Iris render-stage macro branches using injected GLSL preprocessor defines.
- Current checks are source/GLSL/structural only; sky gradient, twilight, celestial tint and weather transitions still need in-game visual calibration.

## Line geometry update — 2026-11-23
- Added `gbuffers_line.vsh/.fsh` for Iris line geometry.
- Uses `MC_RENDER_STAGE_OUTLINE` and `MC_RENDER_STAGE_DEBUG` to keep selection/debug lines crisp while fogging ordinary line geometry.
- Writes color plus zero colortex2 validity; per-buffer mask blending is disabled, color blend state remains game-managed.
- Added CI compilation of Iris render-stage macro branches for sky and line programs.

## Latest CI verification — 2026-11-23
- Run [45067162625](https://github.com/Pawar-47/Serene-Ultra/actions/runs/45067162625) passed after adding the dedicated line overlay and compiling Iris render-stage macro branches for sky-basic, sky-textured and line programs.
- Run [45067030813](https://github.com/Pawar-47/Serene-Ultra/actions/runs/45067030813) also passed the complete shader compile/link/structural checks with sky render-stage macros enabled.
- These runs validate GLSL and structure only. Iris 1.x runtime loading, Minecraft 26.3 rendering, visual parity, and Intel HD 5500 performance are not yet tested.


## Translucent particle lighting checkpoint — 2026-11-23
- `gbuffers_particles_translucent.vsh` now passes player-space position and normal using Iris `gbufferModelViewInverse`.
- The fragment path samples the vanilla lightmap, computes the active celestial source, applies one hardware-filtered `shadowtex0` comparison and Iris fog.
- One shadow comparison is intentional to limit bandwidth/ALU cost on Intel HD 5500; this is a source-level performance choice, not measured FPS.
- Particle-specific emissive classification, campfire smoke, underwater particles and water/rain/snow material heuristics are now implemented in opaque/translucent particle paths; visual parity remains pending.

## Iris compatibility correction — 2026-11-23
- Rechecked the current Iris ordering documentation: it explicitly documents `separateEntityDraws=true` for post-deferred translucent entities and block entities. The prior decision to disable it was incorrect and has been reversed.
- Added `iris.features.optional=ENTITY_TRANSLUCENT` to query Iris support for the translucent entity program.
- The dedicated forward `gbuffers_entities_translucent` and `gbuffers_block_translucent` pairs are active through `separateEntityDraws=true`; runtime sorting and blend behavior still need testing.
- Validator now requires `separateEntityDraws=true`, the optional feature query and both dedicated forward program pairs.
- CI run [45068091455](https://github.com/Pawar-47/Serene-Ultra/actions/runs/45068091455) passed GLSL compile, macro-branch compile, vertex/fragment linking and structural validation.

## New post-deferred geometry and particle update — 2026-11-23
- Enabled Iris `separateEntityDraws=true` and optional `ENTITY_TRANSLUCENT` support.
- Added dedicated forward `gbuffers_entities_translucent` and `gbuffers_block_translucent` pairs. Both write only colortex0, preserve fractional alpha, use vanilla lightmap, celestial shadowing and Iris fog; the entity path also honors Iris `entityColor`.
- Particle material heuristics now follow the current Complementary Reimagined `gbuffers_textured.glsl` reference: water splashes, Physics-mod rain/snow, underwater particles, campfire smoke, Ender/Crying Obsidian/Redstone emission and lava emission.
- Particle atlas-size guard uses the Complementary 1.20+ threshold (1100 px), preventing classification against the block atlas. Water-splash dither uses Iris `noisetex`; rain/snow opacity shares the `WEATHER_TEX_OPACITY` option and only activates when Iris reports skylight plus active rain.
- Ender/Crying Obsidian/Redstone particles suppress lightmap and celestial lighting while retaining their additive emission; emissive particles skip shadow-map lookup.
- Source-level and GLSL/structural CI checks are not a substitute for in-game validation of translucent sorting, particles or FPS.

## Particle material implementation — 2026-11-23
- Added optional `PARTICLE_MATERIAL_FEATURES` (default enabled) to `gbuffers_particles_translucent.fsh`.
- Ported Complementary's water-splash, physics rain/snow, underwater-particle, campfire-smoke, ender/crying-obsidian/redstone and lava-particle heuristics.
- Used Iris `noisetex` with `textureSize` and `texelFetch` for the water-particle dither lookup.
- Replaced the unsupported assumption that `OVERWORLD` is a globally defined macro with runtime `hasSkylight && rainStrength` gating. Complementary defines `OVERWORLD` in its own dimension wrapper; the base Iris program does not.
- Emissive particles add light after ambient/direct shading and skip shadow sampling for lower cost.
- The feature is exposed in the Quality menu and shares `WEATHER_TEX_OPACITY` with the weather path.
- Current coverage is the translucent particle program; opaque particle material emission and additional modded-particle types remain to audit.

## Emissive G-buffer checkpoint — 2026-11-23
- The initial emissive attachment was wired as RGBA8, then reduced to R8; the later PBR material milestone superseded R8 with RGBA8 to store emission, reflectance, AO and LabPBR surface data.
- Extended terrain/entities/opaque-particle G-buffers to `RENDERTARGETS: 0,1,2,3`.
- Added Iris `mc_Entity` (`in vec2`, valid in `gbuffers_terrain.vsh`) and stable `block.properties` IDs for emissive blocks.
- Terrain writes emission RGB plus normalized strength; entities and opaque particles explicitly write zero until their material classification is implemented.
- Deferred adds emission after contact AO/direct lighting and before fog, keeping it independent of AO/shadow attenuation.
- Added lava self-emission to the post-deferred water/fluid shader.
- This is a compact block-ID emission baseline; PBR emission maps, entity emissive classification, bloom and runtime visual tuning remain pending.

## Dedicated basic/block/damaged-block programs — 2026-11-23
- Added `gbuffers_basic` for leash/debug overlays. It applies Iris fog, writes scene color and clears the deferred-validity mask.
- Added `gbuffers_damagedblock` for crack overlays. It writes color only, uses Iris `alphaTestRef`, and matches Complementary's `alphaTest.gbuffers_damagedblock=GREATER 0.004` threshold. Deferred lighting continues to use the underlying block's G-buffer data.
- Added `gbuffers_block` for block entities/sign text. It writes albedo/lightmap/normal/emission attachments, uses documented `blockEntityId`, fogs sign text in the forward stage and marks it as deferred-bypass; portal/gateway IDs have a dedicated emission strength.
- Added `block.properties` mappings for sign families (5004) and End portal/gateway (5025), plus blend/alpha-test directives and structural checks.
- Runtime validation remains pending for signs, portal animation, block-entity rendering and block-breaking overlays.

## Low-end bandwidth optimization — emissive attachment
- Initially changed colortex3 from default RGBA8 to `R8`; the current PBR implementation uses Iris-supported `RGBA8` for emission, reflectance, AO and SSS/porosity data.
- Terrain and block-entity G-buffers write emission strength into red only; deferred reuses scene albedo as emission tint.
- This reduces the emissive attachment from 4 bytes/pixel to 1 byte/pixel (75% less storage/bandwidth) with under 0.005 quantization error for current emission strengths.
- `flip.deferred.colortex3=false` and disabled blending on all emissive G-buffer writers remain required.

## Iris buffer-format directive correction — 2026-11-23
- Current Iris documentation defines attachment formats through GLSL directives such as `const int colortex2Format = RGBA16F;` and `const int colortex3Format = RGBA8;`, placed in block comments in a shader source file.
- Removed invalid `format.colortex2=...`, `format.colortex3=...` and `colortex3Format=...` key/value entries from `shaders.properties`.
- Added the documented format declarations to `deferred.fsh`; validator now checks the source directives and rejects the invalid properties syntax.
- Corrected the opaque-particle atlas-size validator to match the actual explicit float conversion around `textureSize`.
- Iris noisetex documentation confirms a generated square RGB8 noise texture (default 256×256); the translucent-particle dither path uses its runtime size and `texelFetch`, so it does not assume a fixed resolution.
- Latest completed CI before the lit-fallback additions passed GLSL compilation, macro-branch compilation, program linking and structural validation; the new lit-fallback and option-synchronization commits are awaiting their own run.

## Iris lit fallback and shared shader-option correction — 2026-11-23
- Added dedicated `gbuffers_textured_lit.vsh/.fsh`, the documented Iris fallback for most lit particles and generic lit geometry. It writes the same G-buffer contract as opaque particles: albedo, vanilla lightmap, player-space normal and scalar emission.
- The generic lit fallback uses Iris `alphaTestRef` with `alphaTest.gbuffers_textured_lit=GREATER 0.01`, and disables blending for its opaque G-buffer outputs.
- `gbuffers_terrain_solid` and `gbuffers_terrain_cutout` intentionally continue to fall back to `gbuffers_terrain`. Iris documents these fallbacks, and `mc_Entity` is valid in `gbuffers_terrain.vsh` (not the split program names), so the common terrain program preserves stable block/fluid IDs.
- Iris shader-settings documentation requires a macro option to be declared identically in every file where it is used. Unified `PARTICLE_MATERIAL_FEATURES` across opaque particles, translucent particles and `gbuffers_textured_lit`.
- Unified `WEATHER_TEX_OPACITY` across `gbuffers_weather` and `gbuffers_particles_translucent`; the validator now checks the exact identical option declaration.
- CI run [45071600491](https://github.com/Pawar-47/Serene-Ultra/actions/runs/45071600491) passed after adding the generic lit fallback and its structural checks.
- CI run [45071787808](https://github.com/Pawar-47/Serene-Ultra/actions/runs/45071787808) passed after synchronizing the shared weather-opacity option and validating its identical declarations.
- These runs validate GLSL compilation, macro-branch compilation, vertex/fragment linking and structural checks only. Iris/Minecraft runtime sorting, visuals and Intel HD 5500 performance remain unverified.


## Iris uniform, attribute and depth contract audit — 2026-11-23
- Verified `mc_Entity` is valid in `gbuffers_terrain.vsh`, `gbuffers_water.vsh` and `shadow.vsh`; its `x` component is the `block.properties` ID and `y` is `1.0` for fluids / `-1.0` otherwise. The water program's fluid/material-ID test therefore uses the documented attribute in a valid program.
- Verified `blockEntityId` is the documented `gbuffers_block` uniform and that `block.properties` uses `block.<ID>` entries for both block and block-entity IDs.
- Verified `entityColor`, `alphaTestRef`, `renderStage`, `sunPosition`, `moonPosition`, `shadowLightPosition`, `sunAngle`, `rainStrength`, `hasSkylight`, `endFlashIntensity`, `isEyeInWater`, fog uniforms and `gbufferModelViewInverse` against current Iris uniform documentation.
- Verified `depthtex1` excludes transparent geometry and first becomes meaningful in deferred. `gbuffers_water` executes after deferred, so using `depthtex1` to reconstruct opaque depth for water thickness is correctly staged.
- Verified `shadowtex0` includes all geometry and `shadowHardwareFiltering=true` enables comparison sampling as `sampler2DShadow`; the forward water/entity/particle paths use that contract.
- Verified `noisetex` is a generated square RGB8 texture (default 256×256); the translucent-particle dither now uses the same normalized-coordinate `textureLod(noisetex, gl_FragCoord.xy / 128.0, 0.0)` sampling pattern as the working Complementary reference.
- Normalized the `WATER_FOG_MULT` value-list comment to Iris shader-option syntax. `WEATHER_TEX_OPACITY` is declared identically in weather and translucent-particle shaders; `PARTICLE_MATERIAL_FEATURES` is declared identically in opaque, translucent and generic lit-fallback programs. The validator now checks these declarations.
- Corrected over-escaped validator regular expressions so duplicate uniform declarations and forbidden G-buffer sampling are actually detected.
- CI run [45072296773](https://github.com/Pawar-47/Serene-Ultra/actions/runs/45072296773) passed vertex/fragment compilation, Iris render-stage macro compilation, program linking and structural validation. The only program-coverage notices are the intentional Iris fallbacks `gbuffers_terrain_solid` and `gbuffers_terrain_cutout` → `gbuffers_terrain`.
- This is an Iris contract/source audit, not an in-game runtime, visual-parity or performance result.


## Latest particle-reference correction — 2026-11-23
After the interruption, resumed the particle audit at the live `main` state. Verified Iris' documented `noisetex` sampler contract and re-opened Complementary Reimagined's `gbuffers_textured.glsl` material-classification source. Corrected Serene's water-splash dither sampling to match the reference expression `textureLod(noisetex, gl_FragCoord.xy / 128.0, 0.0).b` rather than a custom modulo/`texelFetch` tile. Updated structural validation to require this exact Iris-compatible/reference-matched path. The subsequent CI run passed; no runtime or visual claim is made.

## Opaque particle material parity correction — 2026-11-23
Corrected the two opaque lit-particle G-buffer paths (`gbuffers_particles` and `gbuffers_textured_lit`) after comparing their classifier with the exact Complementary `gbuffers_textured.glsl` logic. Removed a broad brightness/grayscale shortcut that could falsely label unrelated particles as emissive. Both paths now use the reference's raw-texture grayscale test, ender-family channel/energy predicate, separate lava predicate and lava color adjustment. The validator enforces those predicates. This complements the already corrected post-deferred translucent-particle dither sampler. Runtime material identification and visual parity still require in-game testing.

## Complementary Unbound reference update — 2026-11-23
The user has selected Complementary Unbound as the primary visual/material reference for water and the broader material system. The official source is the r5.10 revision of `ComplementaryDevelopment/ComplementaryReimagined` (`e10d27dec5acfb18509fdcc3cda704152dc2f7df)); the same upstream codebase contains both visual styles. The official site explains that Unbound and Reimagined differ by default settings, and the upstream language file maps `WATER_STYLE_DEFINE=3` to Unbound. Keep the supplied working Reimagined ZIP as the proven Iris implementation reference; do not discard it. Vanilla-stock remains the Minecraft 26.3 native-behavior reference, and Iris documentation remains the implementation contract. See [UNBOUND_REFERENCE_AUDIT.md](UNBOUND_REFERENCE_AUDIT.md) for the file-level water/material map, Iris checks, current gaps and implementation sequence.

## Water pipeline validation checkpoint — 2026-11-23
- Corrected the water-normal path to orient both player-space and view-space normals consistently, using the Iris water-normal workaround as the reference pattern.
- Refraction now fetches the clamped exact depth texel and reconstructs view position using that texel's centre UV, avoiding a filtered-depth/UV mismatch.
- Fresnel reflection strength is bounded after user scaling; the validator checks the current screen-space reflection path and correct vertex-stage varying direction.
- CI run [45074177714](https://github.com/Pawar-47/Serene-Ultra/actions/runs/45074177714) passed shader compilation, render-stage macro compilation, vertex/fragment linking and structural validation for source commit `7cf83a758257731980b1b40a71e7ac0ac53b6f53`.
- This remains source/CI validation only. Iris runtime loading, visual parity and Intel HD 5500 performance are not yet proven.


## Water refraction/SSR and Iris buffer checkpoint — 2026-11-23
- The working reference hierarchy is now explicit: Complementary Unbound (water/material visual target), supplied Complementary Reimagined ZIP (proven Iris implementation reference), Minecraft 26.3 Vanilla-stock ZIP (native engine behavior), and Iris documentation (mandatory implementation contract). The Unbound r5.10 source is pinned in `docs/UNBOUND_REFERENCE_AUDIT.md`.
- `deferred.fsh` writes only full-resolution `colortex0`. The half-resolution scene copy is produced separately by `deferred1.fsh`, which reads the lit scene plus `depthtex0` / `depthtex2`, excludes invalid hand/translucent pixels, downsamples in linear space and writes only half-resolution `colortex4`.
- `gbuffers_water` reads `colortex4` and depth buffers while writing only `colortex0`. Water uses `depthtex1` for behind-surface thickness/refraction validation and `depthtex2` for opaque-only SSR intersections. No same-attachment feedback is used.
- Implemented water effects: water-ID/fluid-type gating; depth-based opacity; half-resolution screen-space refraction with validity/depth rejection; Fresnel-weighted SSR with configurable 4/6/8 steps; bounded reflection strength; exact-texel refraction depth reconstruction; paired view/player normal orientation correction.
- Remaining Unbound parity gaps: animated multi-scale normal maps/waves, water noise colour, foam, full underwater response, sky/environment and optional world-space reflection fallback, advanced SSR refinement, and complete glass/stained-glass/portal material dispatch. These are feature gaps, not approved removals.
- Latest full CI run [45074371926](https://github.com/Pawar-47/Serene-Ultra/actions/runs/45074371926) passed GLSL compilation, Iris render-stage macro compilation, vertex/fragment linking and structural validation on repository HEAD `f80577ff2e81ad94cba24ce3a21c1bb334e28537`.
- Validation boundary: no Iris/Minecraft runtime loading, visual parity, or Intel HD 5500 FPS has been verified. Continue to distinguish source/CI correctness from in-game proof.


## Iris translucent entity routing correction — 2026-11-23
- Rechecked the current Iris `Programs / Ordering` documentation before further implementation. It documents `separateEntityDraws=true` for routing translucent entities and block entities into dedicated post-deferred programs, but explicitly warns that the feature may be broken in newer Iris versions.
- Corrected earlier project notes that described this route as unconditionally active. Dedicated shader pairs remain in the repository, but post-deferred execution is conditional until verified against the exact target Iris build.
- Removed the unused `iris.features.optional=ENTITY_TRANSLUCENT` declaration. Iris feature flags expose compile-time capability defines; they do not activate the separate-entity routing directive, and no shader consumed the define.
- `particles.ordering=mixed` remains a separate, documented Iris mechanism for opaque-before-deferred and translucent-after-deferred particle ordering.
- Source/CI success is not proof that translucent entity/block-entity routing works in-game. Keep this limitation visible in future checkpoints.


## Unbound water-wave implementation checkpoint — 2026-11-23
- Reviewed the pinned Unbound water source and identified animated multi-scale normal detail as a missing water feature.
- Before implementation, verified Iris documentation for `cameraPosition`, `frameTimeCounter`, `gbufferModelView` and player/view coordinate transforms.
- Added three analytic wave bands anchored to absolute player/world XZ coordinates. The player-space perturbed normal feeds direct lighting/shadowing; the view-space transformed normal feeds Fresnel, refraction and SSR.
- Added `WATER_WAVE_STRENGTH` and `WATER_WAVE_SPEED` to the Quality menu and slider list. Speed is an integer complete-cycle count per 3600-second Iris timer interval, preventing phase discontinuity at `frameTimeCounter` wrap.
- This is an original, low-bandwidth approximation of Unbound's texture-driven multi-scale normal map. Texture-based normals/parallax refinement, water noise colour, foam, absorption tint, full underwater response and reflection fallback remain outstanding.
- Structural validation now requires the Iris uniforms, all three wave bands, and both menu/slider entries. Wait for the new CI run before reporting the change as validated.


## Unbound-style water colour checkpoint — 2026-11-23
- Implemented a water-ID-only Unbound-inspired base tint using a stable blue base and restrained biome vertex-colour contribution. Incoming water alpha is preserved.
- Added one read-only Iris `noisetex` sample for subtle animated water colour variation. No custom texture binding is assumed.
- Noise UVs are anchored to absolute world XZ and drift with a periodic integer-cycle phase derived from `frameTimeCounter`, avoiding a jump at Iris' 3600-second timer wrap.
- Added `WATER_COLOR_STRENGTH` and `WATER_NOISE_COLOR_STRENGTH` controls to the Quality menu and sliders. Structural validation requires both controls and the documented sampler path.
- Remaining water work includes foam, absorption/depth tint calibration, underwater-specific colour/lighting, caustics, sky/environment reflection fallback and stronger SSR refinement. No runtime or visual parity claim is made.


## Unbound water foam checkpoint — 2026-11-23
- Added a first shoreline/shallow-surface foam approximation from the existing opaque-view thickness reconstructed through Iris `depthtex1` and `gbufferProjectionInverse`.
- Foam uses `1.0 - smoothstep(0.035, 0.42, waterThickness)`, is restricted to top-facing water with valid opaque depth, blends into water albedo before lighting, and attenuates SSR. This supersedes the earlier world-Y/block-height gate.
- Added `WATER_FOAM_STRENGTH` to the Quality menu and sliders. The validator checks the depth reconstruction, surface gating and reflection attenuation path.
- This is a low-cost approximation, not full Unbound foam parity. Runtime/visual calibration, caustics and complete underwater response remain outstanding.


## Foam source-review correction — 2026-11-23
- Reviewed the first foam implementation and rejected its world-Y/block-height gate because it was not a robust signal for sloped shorelines and could invert depending on vertical offset.
- Replaced it with a shallow-water mask derived from the already reconstructed opaque-view thickness: `1 - smoothstep(0.035, 0.42, waterThickness)`, gated to top-facing water and valid opaque depth.
- This reuses the existing Iris `depthtex1` reconstruction and adds no extra texture fetch. It remains an initial approximation; runtime calibration and foam breakup remain outstanding.


## Iris water uniform compile correction — 2026-11-23
- CI exposed undeclared `isEyeInWater` in `gbuffers_water.fsh`.
- Checked current Iris Player Status Uniforms documentation: it is `uniform int isEyeInWater`, with 0 none, 1 water, 2 lava, 3 powdered snow.
- Added the exact integer uniform declaration; underwater logic tests `isEyeInWater == 1`. Validator now requires the declaration. Re-run full GLSL and structural CI before treating the current HEAD as passing.


## Unbound translucent material dispatch checkpoint — 2026-11-23
- Reviewed Unbound's `translucentMaterials.glsl`, glass/stained-glass/nether-portal handlers and `block.properties` material IDs.
- Verified Iris `mc_Entity.x` is valid in `gbuffers_water.vsh` and reads IDs assigned by `block.properties`; `mc_Entity.y` remains the separate fluid render-type check.
- Added IDs for clear glass, glass panes, all stained-glass colours/panes, tinted glass and nether portal.
- Added material dispatch: water retains depth/refraction/foam; clear/stained/tinted glass receive material-scaled Fresnel SSR using the existing opaque scene snapshot; nether portal receives a warm nonlinear tint and self-emission.
- Added `GLASS_REFLECTION_STRENGTH` and `PORTAL_EMISSION_STRENGTH` to the Quality menu and slider list. Validator checks the block IDs and shader branches.
- This is not full Unbound parity: portal UV raymarch/edge effects, connected-glass behavior, absorption, and in-game visual/alpha sorting checks remain pending.


## Translucent ice material checkpoint — 2026-11-23
- Added `block.32004` for ice/frosted ice, following the r5.10 shared Complementary material ID map and Iris `block.properties`/`mc_Entity` contract.
- Ice is classified separately from water and now uses the shared screen-space Fresnel reflection helper with its own reflection scale. It does not receive water refraction, depth opacity or foam.
- Added the ID and branch to structural validation. Ice-specific roughness, thickness, tint and in-game calibration remain outstanding.


## Glossy terrain material checkpoint — 2026-11-23
- Added Iris IDs for slime and honey blocks based on the shared r5.10 material classification.
- Packed a smoothness scalar into `colortex2.a`: 0 remains invalid for deferred, 0.5 is valid non-smooth geometry, and 0.5–1.0 encodes smoothness. This avoids another render target/attachment.
- Updated terrain, entity, block-entity, particle and lit-texture G-buffer writers to use the new validity encoding. Sign text and dedicated overlays remain invalid for deferred surface lighting.
- Deferred decodes smoothness and computes a specular half-vector only for nonzero-smoothness materials. Added `MATERIAL_SPECULAR_STRENGTH` to the Quality menu and slider list.
- Structural validation checks the block IDs, G-buffer encoding and deferred specular path. Full GLSL/CI and runtime verification are still required.


## Deferred glossy-material specular correction — 2026-11-23

A source review of the new slime/honey specular path found that deriving the view vector as `normalize(-playerPosition)` assumes the player-space origin is exactly the camera origin. Iris distinguishes feet/player and eye/player coordinate spaces, so this assumption can shift highlights with camera-relative offsets. The deferred pass now transforms the normalized view-space camera-to-surface direction through the rotational part of `gbufferModelViewInverse`:

```glsl
vec3 viewDirectionPlayer = normalize(mat3(gbufferModelViewInverse) * normalize(-viewPosition));
```

This transforms a direction without applying matrix translation. Iris documents `gbufferModelViewInverse` as view-to-player space and `gbufferModelView` as player-to-view space. The validator now guards this expression.

The latest CI run at this checkpoint is `45075658130` for commit `d42ab0940fd54ca2228c0e664802bfe72f283307`; it was queued when recorded. Do not mark it passed until its final job conclusion is checked. The previous run `45075562637` compiled and linked all shader programs but failed structural validation on two stale expectations: the validator did not recognize the textured-lit fallback's zero-default emission scalar and still expected the old block-entity smoothness alpha value. The current validator source now checks the revised encoding; confirm this with the new CI run.


## Water absorption checkpoint — 2026-11-23
- Added Beer-Lambert absorption to the valid water-refraction path. The existing opaque scene sample is linearized, attenuated by per-channel `exp(-coefficient * waterThickness)`, and blended toward the same water tint used by the surface.
- Red attenuation is strongest, green intermediate, blue weakest, producing depth-dependent blue tint. No additional sampler or render target was added.
- Added `WATER_ABSORPTION_STRENGTH` to the Quality menu and slider list; validator requires the coefficient, transmission and tint-mix path.
- This is an initial physical approximation. Compare coefficient strength and colour against Unbound in actual Minecraft scenes; runtime/visual parity is not claimed.


## Water absorption and reflection fallback — 2026-11-23

- Added depth-dependent Beer-Lambert absorption to refracted water colour. The current absorption coefficients attenuate red more strongly than green and blue, blending transmitted scene light toward the water's linear-space tint as thickness increases. `WATER_ABSORPTION_STRENGTH` is exposed in the Iris Quality menu and slider list with a tooltip.
- Added an Iris-uniform environment reflection fallback for water, glass and ice. `skyColor` and `fogColor` are blended by the reflected direction's player-space elevation; valid screen-space hits are blended over that fallback according to hit confidence. This prevents SSR misses/off-screen rays from collapsing to black.
- Iris docs consulted: [rendering uniforms](https://shaders.properties/current/reference/uniforms/rendering/) documents `skyColor` and `fogColor`; [matrix uniforms](https://shaders.properties/current/reference/uniforms/matrices/) documents player/view transforms; [gbuffers](https://shaders.properties/current/reference/programs/gbuffers/) documents that translucent terrain, including water, runs in `gbuffers_water`.
- The reflection fallback adds no extra texture fetches. It uses the existing reflection direction and two Iris colour uniforms. It remains an approximate sky/horizon environment, not a cubemap or world-space reflection system.
- The validator now checks the fallback path and no longer expects reflection confidence to be multiplied into the reflection weight; confidence selects between environment and screen-space reflection instead.
- Runtime appearance, water absorption calibration, glass/ice tint and Intel HD 5500 performance remain unverified.


## Atlas-safe nether portal checkpoint — 2026-11-23
- Verified Iris `mc_midTexCoord` documentation: it provides the current quad's texture-region center and is valid in `gbuffers_*.vsh`.
- `gbuffers_water.vsh` now forwards transformed per-quad midpoint and half extents. The fragment stage uses four animated portal taps, clamped to the current sprite bounds with a one-texel inset, avoiding atlas bleeding.
- Portal emission is derived from the pre-tint texture signal; warm nonlinear colour tint is applied afterward.
- Added `PORTAL_DISTORTION_STRENGTH` to the Quality menu and slider list. Structural validation checks the Iris attribute, UV bounds and sample path.
- This is a four-tap low-cost approximation, not full Unbound portal raymarch/edge treatment. Runtime atlas, alpha and performance checks remain pending.


## Portal animation timer-wrap correction — 2026-11-23

The four-tap atlas-safe portal distortion now uses an integer number of complete cycles over Iris' 3600-second `frameTimeCounter` interval:

```glsl
float portalPhase = frameTimeCounter * (6.28318530718 * 458.0 / 3600.0);
```

This preserves animation continuity when Iris resets the timer. The validator checks the cycle expression. Iris' system-uniform documentation confirms that `frameTimeCounter` resets after 3600 seconds. The exact animation rate remains a visual-tuning parameter.


### Water wave scale option — 2026-11-23
Added `WATER_WAVE_SCALE` to control spatial frequency independently from normal strength and temporal speed. It is exposed in the Quality menu and slider list and is required by structural validation.


## Unbound water-noise and foam-breakup refinement — 2026-11-23

The water tint now uses a world-height-aware noise coordinate inspired by the pinned Unbound water source. Foam now uses a second, higher-frequency `noisetex` sample to break up the shallow-water mask; the threshold is noise-driven, and foam strength above 100 increases the foam tint while values below 100 reduce coverage. This adds one additional noise lookup on water pixels when foam is enabled.

A source review caught a periodicity mismatch in the initial coordinate scale: Unbound's `0.032` scale multiplied by Serene's 256-block stable-world period gives 8.192 texture repeats, which would not meet at the modulo boundary. Serene now uses `0.03125` (1/32), giving exactly 8 repeats per 256 blocks; the tint path at quarter scale gives 2 repeats and the foam path at 4× scale gives 32 repeats. This small scale adjustment preserves world-coordinate continuity while closely approximating Unbound's coordinate density.

Iris docs consulted: `noisetex` is a square generated RGB white-noise texture with default 256×256 resolution; `frameTimeCounter` resets after 3600 seconds. The validator checks the stable-world tiling coefficient. Visual comparison, water/foam calibration and Intel HD 5500 performance measurements remain pending.


## Water-noise, foam and wave-scale validation — 2026-11-23

The latest source checkpoint also wires `WATER_WAVE_SCALE` into all three analytic wave frequencies. The exposed scale values (50, 75, 100, 125, 150, 200 percent) are quarter-step multiples, so each frequency continues to tile the 256-block stable-world domain. The option is present in the Iris Quality screen, slider list and English labels.

GitHub Actions run [45076104051](https://github.com/Pawar-47/Serene-Ultra/actions/runs/45076104051) for commit `c1bdc86575e6944e99efd0b30e3ae4d5509cebad` completed successfully. GLSL compilation, Iris render-stage macro compilation, vertex/fragment linking and structural validation all passed for that exact source state. This is not Minecraft/Iris runtime or visual validation.


## Iris resource-pack water normal maps — 2026-11-23

The dedicated water vertex/fragment pair now consumes Iris' documented `at_tangent` attribute and `normals` atlas. The tangent and handedness are transformed into player space; water top-face normal maps are decoded in tangent space and blended into the analytic wave normal before Fresnel/refraction/SSR. The original geometric normal is retained for shadow-map bias and shoreline orientation. A `WATER_NORMAL_MAP_STRENGTH` Quality slider controls the contribution.

Iris documents `at_tangent` as available in `gbuffers_*.vsh`, and `normals` as the resource-pack PBR normal atlas. When no `_n` texture exists, Iris returns the neutral normal (127,127,255), so the feature is effectively flat and does not invent surface detail. This is resource-pack PBR integration, not a replacement for Unbound's own generated multi-scale water normal texture. The implementation adds one normal-atlas lookup only for top-facing water fragments when the option is enabled. Runtime behavior with actual LabPBR/oldPBR packs and Intel HD 5500 cost remain unverified.


## Colored shadow transmission checkpoint — 2026-11-23
- Verified Iris shadow documentation: `shadowtex0` includes all casters, `shadowtex1` includes opaque casters only, and `shadowcolor0` is writable from `shadow.fsh` and readable by deferred.
- Enabled `shadowTranslucent=true`; `shadow.fsh` writes RGBA8 transmission for water caustics, clear/stained/tinted glass, ice and Nether portal. Unknown translucent materials default to neutral full transmission.
- Deferred retains four `shadowtex0` PCF taps, then performs a center `shadowtex0`/`shadowtex1` comparison and samples `shadowcolor0` only when a translucent blocker is detected. RGB transmission affects direct and specular lighting.
- Added `blend.shadow.shadowcolor0=off` and `flip.shadow.shadowcolor0=false` to preserve the shadow pass's output for deferred.
- This adds an RGBA8 shadow-color attachment and an extra translucent shadow render; measure cost on Intel HD 5500. No in-game visual validation is claimed.


## Stable projected caustics and colored translucent shadows — 2026-11-23

The shadow pass reconstructs stable world coordinates from Iris' split integer/fractional camera uniforms and shadow-view-to-player transform, then wraps them to a 256-block period. Three animated caustic interference bands use integer-lattice spatial frequencies and integer cycle counts over Iris' 3600-second timer, preventing both camera-wrap and timer-wrap seams. `WATER_CAUSTICS_SCALE` uses quarter-step values that preserve the 256-block period; `WATER_CAUSTICS_STRENGTH=0` returns neutral caustic modulation.

The shadow color target is RGBA8 because it now carries RGB transmission and alpha for water, clear/stained/tinted glass, ice and portals. Deferred combines the existing four-tap `shadowtex0` PCF with the opaque-only `shadowtex1` comparison, and only samples `shadowcolor0` when a translucent blocker is detected. The resulting RGB transmission attenuates both direct diffuse and material specular light. This is source-validated only; the extra translucent shadow render and RGBA8 target need performance and visual checks on Intel HD 5500.


## Water cauldron checkpoint — 2026-11-23
- Added `block.10049=minecraft:water_cauldron`, then remapped ID 10049 to 32001 in both `gbuffers_water.vsh` and `shadow.vsh`, following the shared r5.10 material mapping.
- Water cauldron surfaces now enter the water material path even though they do not rely on the ordinary fluid render-type flag. They receive the water depth/refraction/absorption/foam/underwater treatment and caustic shadow transmission.
- Structural validation requires the block mapping and both vertex-stage remaps. Empty cauldrons remain unaffected.


## Water cauldron material routing — 2026-11-23

Mapped `minecraft:water_cauldron` to a dedicated water material ID in `block.properties`, then remapped that ID in both the gbuffers-water and shadow vertex stages. The water fragment path treats the translucent water surface as water even though it is a block model rather than an Iris fluid render type. The shadow pass applies caustic transmission to the cauldron surface only when its sampled material alpha is below 0.999, preventing the opaque cauldron shell from receiving water-caustic transmission. This relies on Minecraft 26.1+ per-sprite cutout/translucent block-model routing; runtime behavior on the target 26.3 build remains to be verified.


## Forward translucent shadow consistency checkpoint — 2026-11-23
- Corrected the post-deferred `gbuffers_water` forward-lighting path to use Iris `shadowtex0`, opaque-only `shadowtex1` and `shadowcolor0` transmission, matching the deferred shadow path.
- The forward pass retains four-tap PCF, performs a center translucent-blocker comparison and conditionally reads the RGBA8 material transmission. Its direct lighting now uses RGB shadow colour rather than a scalar shadow factor.
- This prevents water/glass surfaces from treating the same translucent blocker as opaque after deferred has already applied its colored transmission. Structural and GLSL validation pending for this latest correction.


## Water depth/fog control separation — 2026-11-23

A source comparison with the pinned Unbound water path showed that `WATER_FOG_MULT` scales the depth term used for the water opacity/fog response, not the physical distance used by every other water effect. Serene now keeps `waterThickness` as the reconstructed geometric distance and derives a separate `waterFogThickness` for `waterFog`. Beer-Lambert absorption, refraction offset and foam breakup use physical thickness; only the water opacity/fog term responds to `WATER_FOG_MULT`. This avoids a fog-menu adjustment unintentionally changing refraction, absorption and shoreline foam.


## Glass and ice PBR normal-map support — 2026-11-23

The shared Iris tangent-space normal-map decoder now also applies to clear glass, stained glass, tinted glass and ice. A separate `GLASS_NORMAL_MAP_STRENGTH` slider controls these materials independently from water. LabPBR flips the DirectX Y- channel while oldPBR retains its legacy Y+ convention; tangent handedness follows Iris' documented `cross(tangent, normal)` basis. The original geometric normal remains in use for shadow bias. Neutral Iris fallback normals leave materials unchanged when no resource-pack normal map is present.


## LabPBR normal-map channel correction — 2026-11-23

A deeper check against the shaderLABS LabPBR 1.3 specification found that the blue channel of a LabPBR normal map stores ambient occlusion, not the normal's Z component. The shared translucent normal decoder now reconstructs Z as `sqrt(max(1 - dot(xy, xy), 0))` from the red/green XY channels, flips Y for LabPBR's DirectX convention, and keeps RGB decoding for oldPBR. This prevents AO data from corrupting the normal direction on modern PBR resource packs.


## Terrain oldPBR/LabPBR checkpoint — 2026-11-23
- Added Iris `specular` atlas sampling to `gbuffers_terrain.fsh`, `gbuffers_entities.fsh` and `gbuffers_block.fsh`. Smoothness is decoded from red for both oldPBR and LabPBR. oldPBR green/blue decode metalness/emission; LabPBR green decodes dielectric F0 or metal code (230–255), and alpha decodes emission with 255 treated as no emission.
- `colortex3` is now RGBA8: red stores normalized emission, green stores reflectance/metal code, blue stores material AO and alpha stores LabPBR porosity/SSS data. Deferred uses this value for dielectric F0 or albedo-coloured metal F0, and the smoothness-gated specular lobe now uses material colour.
- Slime/honey block-ID smoothness remains as a fallback when resource-pack PBR maps are absent. Terrain, entities and block entities also decode Iris `normals` atlas maps using their `at_tangent` handedness basis. The new resource-pack path does not add another render target.
- CI now compiles the LabPBR macro branches for terrain, water and deferred in addition to the default branch. Runtime checks with actual oldPBR and LabPBR resource packs remain pending.


## Opaque terrain/entity/block PBR specular coverage — 2026-11-23

Iris' `specular` atlas is now consumed by the terrain, entity and block-entity G-buffers. All three paths pack perceptual smoothness into `colortex2.a`; `colortex3` is RGBA8 with emission in R, reflectance/metal classification in G, material AO in B and LabPBR porosity/SSS data in A. This reuses the existing attachment without adding another render target, but increases its bandwidth versus the earlier RG8 intermediate.

A standards review corrected LabPBR F0 decoding: non-metal green-channel values 0–229 are stored linearly as `code / 255`; values 230–254 are predefined metal IDs and 255 selects albedo as F0. Serene currently treats the full 230–255 range as albedo-tinted metal; distinct metal-ID presets remain a simplification. Deferred now tests the exact 230/255 boundary instead of treating high-F0 dielectrics as metals. oldPBR continues to use green as metalness and blue as emissiveness. The shader uses the specular atlas fallback of zero when no `_s` map is present, with a 0.04 dielectric F0 fallback for LabPBR. This path is source-validated; visual calibration with actual LabPBR and oldPBR resource packs remains outstanding.


## Opaque terrain/entity/block-entity PBR normals — 2026-11-23

The opaque terrain, entity and block-entity vertex/fragment pairs now pass Iris' `at_tangent` basis and sample the `normals` atlas. LabPBR reconstructs Z from RG, reads AO from B, and flips Y for DirectX orientation; oldPBR decodes RGB directly. Tangent handedness follows Iris' documented `cross(tangent, normal)` convention. Sign text deliberately bypasses normal perturbation. `OPAQUE_NORMAL_MAP_STRENGTH` controls the feature independently of translucent water/glass normal controls.

This adds one normal-atlas lookup per opaque G-buffer fragment when enabled, with no extra render target or additional full-resolution buffer. Iris' neutral fallback normal leaves geometry unchanged without resource-pack `_n` maps. Runtime validation with real LabPBR/oldPBR packs and Intel HD 5500 performance remain outstanding.

Normal-atlas sampling uses implicit-derivative `texture(normals, vTexCoord)` rather than forcing mip level 0. This follows the working Complementary reference's implicit `texture2D(normals, ...)` sampling and lets the atlas select appropriate mip levels at distance, reducing aliasing and avoiding unnecessary full-resolution sampling. Iris documents the neutral `_n`-map fallback and the `at_tangent` handedness convention. CI's LabPBR matrix now includes terrain, water, entities, block entities and deferred; the expanded matrix still needs a green run after the tangent-interface cleanup.


## GGX direct specular — 2026-11-23

Replaced the earlier Blinn-Phong highlight with a compact GGX microfacet direct-specular term, guided by the pinned Unbound `ggx.glsl` reference. The implementation uses the PBR smoothness map, a roughness floor for stable low-end rendering, GGX normal distribution, Schlick-Smith geometry, Schlick Fresnel with decoded oldPBR/LabPBR reflectance, and the existing colored shadow/direct-celestial radiance. A branch skips the BRDF on non-glossy pixels and when no direct celestial light is present; a soft peak compression controls extreme highlights on Intel HD 5500.

This is direct-light GGX only. Full energy-conserving metal diffuse, image-based/environment specular, area-light sun approximation and runtime visual calibration remain outstanding.


The exact-source GLSL and structural validation for the GGX/PBR material state passed in GitHub Actions run [45078017437](https://github.com/Pawar-47/Serene-Ultra/actions/runs/45078017437), commit `b9fa362951f49a7b26870ce4110ca4ed97fa9aca`. This includes default and LabPBR macro-branch compilation, shader program linking and structural checks. It does not substitute for Iris/Minecraft 26.3 runtime or visual testing.


## Dual-format PBR CI validation — 2026-11-23
GitHub Actions run 919 (`bc0dd3d`) passed all stages: shader compilation, Iris render-stage macro branches, LabPBR macro compilation/linking for terrain/entities/block entities/water/deferred, full vertex-fragment program linking and structural validation. The source keeps Iris' documented `in vec4 at_tangent;` declarations; the earlier duplicate-symbol failure was transient and the direct-source workflow now passes. Minecraft 26.3 runtime loading, real resource-pack decoding and Intel HD 5500 performance remain unverified.


## LabPBR material AO and subsurface scattering — 2026-11-23
The opaque G-buffers now store LabPBR normal-map blue-channel AO in `colortex3.b`, reusing the normal-map sample. Deferred applies this AO once to indirect/block-light ambient only; direct celestial lighting remains unchanged. `PBR_AO_STRENGTH` controls map influence and `MATERIAL_AO_STRENGTH` controls lighting impact. oldPBR and missing-map fallbacks remain neutral. LabPBR specular blue values 65–255 are decoded as subsurface scattering in `colortex3.a`; the deferred pass adds a low-cost backlighting approximation controlled by `MATERIAL_SSS_STRENGTH`. Values 0–64 are now decoded as porosity: porous LabPBR surfaces darken and lose reflectance/smoothness when wet, while porosity also reduces puddle pooling. The material attachment is RGBA8, so no new render target is added but the extra channels cost more bandwidth than the former RG8 intermediate. Runtime visual validation and Intel HD 5500 profiling remain outstanding.


## Opaque PBR screen-space reflections — 2026-11-23

The `composite` pass now adds Fresnel-weighted reflections to glossy opaque terrain, entities and block entities. It uses the existing half-resolution opaque/sky snapshot from `deferred1` (`colortex4`), full-resolution `depthtex2`, the PBR normal/smoothness G-buffer and decoded material F0/metal response. A short 4/6/8-step view-space ray march finds screen-space hits; sky/horizon colors provide the fallback. `PBR_REFLECTION_STRENGTH` and `PBR_REFLECTION_QUALITY` are exposed in the quality menu.

Because composite runs after translucent gbuffers, it compares current `depthtex0` with opaque-only `depthtex2` and skips pixels covered by water/glass/particles/hand, avoiding reflections being blended onto translucent overlays. The pass reuses the existing half-resolution scene snapshot and does not add a new render target. Known limitations: reflections do not include translucent objects, roughness blur or temporal accumulation; metallic F0 tint uses the lit scene color as an albedo proxy; environment fallback is sky/horizon only. Runtime visual and Intel HD 5500 performance checks remain outstanding.


## colortex1 lightmap output correction — 2026-11-23
Restored `outLightmapData = vec4(vanillaLight, skyLight);` in terrain, entity and block-entity fragment programs. The source was computing these values but had omitted the actual colortex1 write, which would leave deferred ambient/direct light inputs undefined. Structural validation now requires colortex1 writes in all five opaque G-buffer fragment families.


The combined material AO/SSS, opaque PBR normals, GGX direct specular, opaque SSR and corrected G-buffer lightmap state passed exact-source GLSL compilation, LabPBR macro-branch compilation, program linking and structural validation in GitHub Actions run [45079135476](https://github.com/Pawar-47/Serene-Ultra/actions/runs/45079135476), commit `d07e45b3e95e3e728c3a98c450174fbf874b9960`. Minecraft/Iris runtime, visual parity and Intel HD 5500 performance remain unverified.


## Porosity-driven wetness and rain puddles — 2026-11-23

The terrain G-buffer now decodes LabPBR specular-blue codes 0–64 as porosity (0–1); codes 65–255 remain SSS data. Porous materials darken and lose reflectance/smoothness under wet conditions, controlled by `MATERIAL_WETNESS_STRENGTH`. The puddle mask follows the Unbound-style exposure model: rain-only biome precipitation, biome rainfall, sky exposure, low block light and upward-facing normals. Three noise samples provide breakup and ripple normals; the tangent basis follows Iris' documented `cross(tangent, normal)` handedness. `RAIN_PUDDLE_STRENGTH` controls pooling, and LabPBR porosity reduces it. Leaves/farmland are excluded by material ID. A 60-second periodic noise drift avoids a phase jump when Iris' `frameTimeCounter` wraps at 3600 seconds. No 3D voxel map or new render target is used.

Known limits: this is a screen-space/terrain-G-buffer approximation rather than Unbound's full material/voxel pipeline; it does not wet entities or block entities, and still needs in-game weather/biome visual calibration and HD 5500 performance testing.


## LabPBR reserved metal-channel correction — 2026-11-23

- Confirmed the deferred pass already decodes LabPBR SSS codes 65–255 as `(code - 65) / 190`; no change to that correct mapping was needed.
- Terrain already zeroed the packed surface-data channel for metal IDs. Entity and block-entity G-buffers now also clear `materialSurfaceData` when LabPBR green selects a metal (230–255), because the blue channel is reserved/undefined for metals.
- Extended `tools/validate_pack.py` to prevent regression in both shader paths.
- The supplied working Complementary archive was consulted for the material-system reference; the Vanilla-stock terrain pipeline was checked to preserve the native vertex/lightmap/albedo contract. LabPBR channel semantics were checked against the shaderLABS LabPBR 1.3 specification.
- Previous baseline CI run 1040 passed all nine stages on `eb070b7566e6c6b12f43f548298be210d858d92c`. The combined correction commit below requires its own fresh CI run. Minecraft/Iris runtime and Intel HD 5500 visual/performance validation remain outstanding.


## Unbound style-3 water parity correction — 2026-11-23
- Compared the supplied working shader archive's `shaders/lib/materials/specificMaterials/translucents/water.glsl`; its `WATER_STYLE == 3` branch is the Unbound implementation.
- Unbound style 3 prepares the biome/vertex tint with square-root colour and the multiplier `(1.0, 0.85, 0.8)`, then applies a `0.375` base multiplier. Serene previously mixed that tint 50/50 with the fixed Reimagined blue tint. The fixed tint has been removed from the Unbound path; `WATER_COLOR_STRENGTH` still controls blending with the atlas colour.
- Unbound style 3 sets above-water surface alpha to `0.98`, then applies depth opacity and Fresnel. Underwater it applies a separate `0.75` alpha reduction. Serene previously used the Reimagined-style square-root of sampled atlas alpha. The water pass now follows the Unbound branch.
- Cross-checked Minecraft 26.3 Vanilla-stock `core/terrain.fsh` (sampled atlas colour multiplied by vertex colour, then fog while preserving alpha), `core/terrain.vsh` (vertex colour multiplied by vanilla lightmap), and `include/fog.glsl` (fog affects RGB while preserving alpha). Those native inputs remain intact; the Unbound surface-alpha treatment is isolated to Iris' water program.
- Added validator assertions for the Unbound base tint and above-/underwater alpha branches.
- This is a source-parity correction, not a runtime-verified visual claim. Validate above-water, underwater, shore and transparent-boundary scenes in Iris.


## Bounded water SSR hit refinement — 2026-11-23
- Compared Serene's water SSR with Complementary Unbound's shared reflection method. Unbound's high-quality path uses a substantially larger coarse ray budget and a refinement phase; copying that sample count would be inappropriate for Intel HD 5500.
- Added a positive-to-negative view-space depth-crossing test to the water SSR ray marcher. A bracketed opaque hit receives exactly two binary refinement steps; the existing 4/6/8 coarse quality presets and 24-block maximum ray distance remain unchanged.
- Sky fallback, screen-edge fade, distance fade, invalid snapshot alpha rejection and the conservative first-sample-inside-geometry path are preserved.
- Extended structural validation to require the bounded two-step refinement loop.
- The extra depth/colour reads occur only after a candidate hit, rather than for every ray step. This is a source-level bounded-cost improvement; actual GPU cost, temporal stability and visual hit quality still require Iris runtime testing.


## Water SSR refinement validation — 2026-11-23
- Commit `d9413778a0f03627a23171cbabac178139a80790` added two bounded binary refinement steps after a positive-to-negative view-space depth crossing in the water SSR marcher.
- Follow-up `235415b1fae9f8a8dfb7a9665b441def4cc7e6f9` explicitly rejects invalid deferred-snapshot alpha at the coarse hit, preventing hand/transparent-mask pixels from being returned as reflection hits.
- CI run `45107408270` (run #1045) passed all nine stages on the follow-up commit. This validates GLSL compilation and structural assertions only; water reflection quality, temporal stability and Intel HD 5500 cost remain unmeasured in Iris.


## Bounded terrain POM implementation — 2026-11-23
- Added an inline terrain-fragment POM implementation for Iris normals.a height data (LabPBR and oldPBR), with compile-time 4/6/8 sample limits, distance fade, capped UV displacement and linear intersection interpolation.
- Terrain vertex stage forwards Iris mc_midTexCoord sprite bounds plus tangent-space view direction derived from at_tangent and handedness. Height samples wrap within the current sprite and clamp by half an atlas texel to avoid adjacent atlas-tile sampling.
- Terrain fragment stage resamples albedo, normal and specular data at the displaced UV. A displaced albedo sample below alphaTestRef is rejected in favour of the original UV to protect cutout silhouettes.
- Added POM_STRENGTH, POM_QUALITY and POM_DISTANCE Iris settings. Ultra-Light disables POM; Smooth uses 4 samples and a short fade; Ultra/HDR use 6 samples. The feature remains neutral when the normal atlas has no height data (alpha near 1). The helper is inlined in the terrain fragment source because the CI compiler validates shader files directly without preprocessing GLSL include directives.
- Reference comparison: supplied working shader pomEffects.glsl/customMaterials.glsl use normals.a, tangent-space view direction, per-quad atlas bounds, textureGrad and distance fade. This implementation adopts those principles with fewer samples and a shorter displacement cap for low-end GPUs.
- Iris documentation confirms normals is the normal-map atlas, at_tangent provides model-space tangent and handedness, mc_midTexCoord is the current quad texture centre, and LabPBR 1.3 stores linear height in normal-map alpha (0 = 25% depth, 255 = no depth).
- Static validation is not runtime proof. Remaining checks: oldPBR/LabPBR resource packs, oblique camera angles, sprite edges, cutout foliage and Intel HD 5500 frame cost in Minecraft 26.3 + Iris.


## POM CI checkpoint — 2026-11-23
- Latest POM source commit: 3d68fdf80f05c4c8377d48a58469cb1589cef5bf.
- GitHub Actions run #1050 (45108422197) passed all nine stages: shader compilation, Iris render-stage macro compilation, LabPBR branches, vertex/fragment linking and structural validation.
- Earlier runs #1047–#1049 failed during the POM bring-up due to (1) a direct-compiler include directive, then (2) stale validator paths and (3) stale terrain-normal assertions. These were corrected; the latest run is green.
- Scope remains terrain-only POM. Do not claim runtime or target-GPU performance verification.


## Block-entity POM coverage — 2026-11-23
- Extended the same bounded sprite-safe POM path to Iris gbuffers_block (block entities), reusing the same LabPBR/oldPBR normals.a height convention, 4/6/8 steps, fade distance, displacement cap and cutout-alpha fallback.
- Block-entity vertex data now forwards mc_midTexCoord sprite bounds and tangent-space view direction from at_tangent. The displaced UV is used consistently for albedo, normal and specular maps.
- Sign text and Nether portal surfaces are explicitly excluded. The ordinary sign wood texture and other block-entity materials may use POM when their height atlas contains non-neutral data.
- POM remains terrain + block-entity only; entity models, self-shadowing, slope-normal reconstruction and runtime/target-GPU calibration remain outstanding.


## POM terrain + block-entity validation — 2026-11-23
- CI run #1054 (45108839328) passed all nine stages on commit fe4a10a after removing a duplicated interface block introduced during the block-entity extension.
- Both terrain and block-entity programs compile and link with the same Iris mc_midTexCoord/at_tangent POM varyings. Structural validation confirms atlas bounds, bounded sampling, cutout fallback, and sign-text/portal exclusions.
- Tuned the depth control mapping to give the low-end 20/35 presets a more visible displacement while retaining a 0.20 UV-offset cap and 4/6/8 sample limit. This is a source-level calibration only; real resource-pack appearance and Intel HD 5500 cost still need runtime checks.
- POM remains unavailable for generic entity models and held items; their stable per-object exclusions are not yet mapped in this pack. Self-shadowing and slope-normal reconstruction also remain pending.


## Albedo-derived generated normals — 2026-11-23
- Added four-neighbour albedo-gradient normal generation to terrain and block-entity G-buffers. It runs only when the resource normal map's XY channels are effectively flat, and only on fully opaque texels; explicit PBR normal maps retain priority.
- Uses precomputed screen derivatives, a one-texel minimum footprint, per-quad mc_midTexCoord atlas bounds, and a half-texel inset for all four textureGrad samples. Any neighbour with partial/cutout alpha rejects the generated normal to avoid lighting across leaf/plant holes.
- Generated tangent-space gradients are thresholded and clamped before conversion through the existing at_tangent/handedness basis. GENERATED_NORMAL_STRENGTH is independently configurable; Ultra-Light disables it.
- This is a low-sample adaptation of Complementary's generatedNormals.glsl, not a claim of visual parity. Entity models, runtime comparison, texture-pack coverage and Intel HD 5500 performance remain pending.

- Performance refinement: generated-normal sampling is now gated by the screen-space albedo contrast before issuing its four neighbour taps; flat-colour regions avoid the extra reads. This is a heuristic optimisation and still requires GPU profiling.


## Coated texture variation — 2026-11-23
- Added an optional low-cost noise coating to opaque terrain and block-entity albedo, adapting the supplied Complementary coatedTextures.glsl approach.
- Noise coordinates combine the sprite's atlas centre with floored world-cell position, so the variation is stable in world space rather than swimming with the camera. The noise modulation is reduced for bright materials and fades with mip level/distance.
- Added COATED_TEXTURE_STRENGTH control; Ultra-Light disables it, Smooth uses a subtle value, and Ultra/HDR use a stronger preset. It is one noise lookup per eligible opaque fragment and is skipped for transparent/cutout texels, sign text and portal surfaces.
- This is a source-level low-cost adaptation. Entity-model coverage, material appearance and GPU cost require runtime validation.


## Generated normals + coated textures validation — 2026-11-23
- Terrain and block entities now have four-tap albedo-gradient generated normals, gated by screen-space albedo contrast and skipped when explicit normal-map XY detail is present. Cutout/partial-alpha neighbour samples reject generated-normal synthesis.
- Terrain and block entities also have optional stable noise coating. Noise is keyed by sprite-atlas centre and floored world-cell position, then attenuated for bright materials and distant/mipmapped surfaces.
- Run #1058 (45109244596) passed all nine stages for generated normals. Run #1060 (45109448675) passed all nine stages for coated textures and the corrected uniform declarations.
- Source-level validation only: visual material response, atlas seams, oldPBR/LabPBR pack compatibility and Intel HD 5500 GPU cost still require Minecraft 26.3 + Iris runtime testing.
- Remaining reference gaps include generic entity/held-item POM, POM self-shadowing, slope-normal reconstruction and runtime calibration.


## Coated-texture material filtering — 2026-11-23
- Moved coating modulation after oldPBR/LabPBR material decoding so the shader can avoid tinting material-map emissives, high-F0 metals and highly smooth surfaces.
- Terrain additionally excludes all built-in emissive material IDs, including glowstone, sea lantern, torches, froglights, beacon, lava and jack-o-lantern. Block entities skip sign text, portals and their fallback emissive state.
- The effect remains a single Iris noisetex lookup on eligible opaque fragments, with atlas/world-cell-stable coordinates and derivative-based mip fade. This refinement reduces unintended changes to emissive/metallic PBR response.
- Iris noisetex documentation confirms the sampler is a generated RGB8 white-noise buffer (256x256 by default) and can be replaced via texture.noise. The cameraPositionInt/cameraPositionFract uniforms used for stable world-space variation are Iris-supported.
- Corrected coating filter requires a fresh CI run; runtime material appearance and GPU cost remain unverified.


## Multi-scale Unbound-style water normals — 2026-11-23
- Replaced the three analytic sine-wave slopes with three animated scales sampled from an original tileable 64x64 tangent-normal texture generated for Serene-Ultra. This follows Unbound's multi-scale normal-map approach without copying the reference pack's cloud-water asset.
- The normal field is sampled at medium, 4x-small and 0.25x-large scales with explicit textureGrad derivatives. Stable world coordinates anchor the pattern; camera-relative derivatives avoid discontinuities at the 2560-block coordinate wrap.
- Wind shifts by whole texture periods at Iris' 3600-second frameTimeCounter wrap for every quarter-step speed preset. Existing WATER_WAVE_STRENGTH, SCALE and SPEED controls remain authoritative.
- The custom texture is bound through Iris customTexture.waterNormalTex and uses blur=true/clamp=false metadata. This is Iris-specific by design; the pack's target renderer is Iris.
- This source change aims for better Unbound-style surface detail while keeping three texture reads per water fragment. Runtime water appearance, texture filtering and Intel HD 5500 cost remain to be checked in Minecraft 26.3 + Iris.

- Water-normal refinement: the multi-scale wave slope is now added to the existing resource-pack PBR normal instead of replacing it. Setting WATER_WAVE_SCALE to 0 disables the custom normal field cleanly. CI's first failure on this feature was only an overly strict validator token split across GLSL lines; shader compilation and linking had already passed.


## Entity-model POM extension — 2026-11-23
- Added opt-in LabPBR/oldPBR height mapping to the opaque entity G-buffer. The entity vertex stage now forwards Iris mc_midTexCoord atlas bounds and at_tangent-derived view direction.
- Entity POM uses the same bounded 4/6/8-step intersection, 32-block maximum fade, 0.20 UV displacement cap and cutout-alpha fallback as terrain/block entities. Item frames and glow item frames are excluded through explicit entity.properties mappings (50128 and 50132).
- POM_ENTITY_STRENGTH defaults to 0 and is disabled in Ultra-Light/Smooth; Ultra/HDR opt in at 20 to protect low-end performance. Generic translucent entities and held items are not covered.
- CI #1065 (45110274115) compiled and linked all shader variants but failed structural validation because the validator still expected pre-POM implicit normal/specular sampling and the old normal-function signature. The source compiled; the validator has now been updated to recognise explicit textureGrad sampling and entity POM exclusions. Re-run CI before marking this extension validated.


## Entity POM validation follow-up — 2026-11-23
- CI run #1066 (45110449563) passed all nine stages after updating structural checks for the entity path's displaced-UV specular/normal samples and POM normal-function signature.
- A final Iris-options audit found the POM_QUALITY option comment differed between entity and terrain/block shader files. Iris requires an option to be defined identically in every file where it is used; the entity definition and validator now enforce identical POM_QUALITY/POM_DISTANCE definitions.
- Await the new CI run after this options-consistency correction. Runtime entity rendering and target-GPU profiling remain pending.


## Entity-model generated normals + coated textures — 2026-11-23
- Extended the optional generated-normal and coated-texture paths to opaque entity models. The entity G-buffer now forwards player-relative position for stable world-cell noise and reuses mc_midTexCoord sprite bounds and the at_tangent basis.
- Generated normals run only when no explicit normal-map XY detail exists, on opaque texels with visible albedo contrast. Coated texture noise skips item frames/glow item frames, transparent texels, emissive materials and high-F0/high-smoothness surfaces.
- POM_ENTITY_STRENGTH remains separately opt-in; entity POM is disabled in Ultra-Light/Smooth and enabled only in Ultra/HDR. Generic translucent entities and held items remain outside this pass.
- This extends source coverage; runtime resource-pack compatibility, entity-specific visual checks and GPU cost remain unverified.


## Entity material-feature coverage + CI expansion — 2026-11-23
- Run #1068 (45110765737) passed all nine stages after generated normals and coated textures were extended to opaque entity models. Entity item frames/glow item frames are explicitly excluded.
- Added a dedicated CI step that compiles and links the opt-in entity POM branch twice: oldPBR and LabPBR, both with POM_ENTITY_STRENGTH forced to 20. The default entity profile remains POM-off to protect low-end GPUs; this test ensures the optional code path cannot silently rot.
- Structural validation now requires the CI opt-in POM variants. This is a test-coverage improvement, not a runtime visual verification.


## Entity POM and entity material-effect CI — 2026-11-23
- Run #1067 (45110640697) passed all nine stages after POM option definitions were aligned across terrain, block and entity shaders.
- Run #1068 (45110765737) passed all nine stages after generated normals and coated textures were extended to opaque entity models.
- Run #1069 (45110882840) added and passed dedicated oldPBR and LabPBR opt-in entity POM compile/link variants.
- Run #1070 (45111042199) passed after entity generated normals/coating were placed behind ENTITY_GN_AND_CT, off by default. Entity POM remains independently opt-in in Ultra/HDR.
- Next CI update also compiles the combined entity POM + ENTITY_GN_AND_CT path for both oldPBR and LabPBR, so the optional entity material branches remain tested rather than only the default-off branch.
- Runtime testing of mobs, armor, item frames, resource-pack height maps and Intel HD 5500 cost remains pending.


## Unbound water-normal wrap validator correction — 2026-11-23
- Run #1072 compiled all shader stages, Iris render-stage branches, LabPBR branches, opt-in entity POM branches, and linked all programs. It failed only because a structural assertion still expected the former 256-block camera wrap.
- The water-normal implementation now uses a 2560-block stable-world period. This is required for the optional 0.05 very-large normal octave to repeat at the wrap boundary: at the 0.03125 world scale, the four octave frequencies (1.0, 4.0, 0.25, 0.05) produce integer repeat counts (80, 320, 20, 4).
- Updated structural validation to assert the 2560-block integer-camera wrap, the fractional-camera offset, and integer repeat counts for every selected octave. Also added checks that WATER_WAVE_DETAIL is exposed with a tooltip and remains disabled on Ultra-Light/Smooth while enabled only on Ultra/HDR profiles.
- This is a validator correction, not a shader behavior change. Await the new CI result before marking the expanded water-normal branch validated.


## Unbound water-normal octave validation — 2026-11-23
- Run #1073 (45111506086) passed all nine stages after the validator was updated from the old 256-block camera period to the 2560-block stable period and taught to verify the optional 0.05 octave.
- WATER_WAVE_DETAIL adds one texture lookup only in Ultra/HDR/Ultra-HDR. Ultra-Light and Smooth retain the three-sample baseline.
- Structural validation now checks all six WATER_WAVE_SCALE presets against all four octave frequencies and all seven WATER_WAVE_SPEED presets against integer wind cycles at Iris' 3600-second timer wrap.
- The language tooltip now describes WATER_WAVE_SPEED as a relative speed control, not an inaccurate literal cycle count.
- Water parallax remains deferred until the custom normal texture's alpha/height data can be verified. Runtime visual and performance calibration remain pending.


## Opt-in water-wave branch CI coverage — 2026-11-23
- Run #1074 (45111618598) passed all nine stages, including all wave-scale and timer-wrap math checks.
- Added a dedicated CI step to force WATER_WAVE_DETAIL=1 and compile/link the optional fourth 0.05 octave in both oldPBR and LabPBR branches. This prevents the higher-profile-only water code from being validated only in its default-off configuration.
- Water parallax remains deferred until alpha-height data is verified; visual water calibration and target-GPU profiling are still pending.


## Low-end and high-quality profile calibration — 2026-11-23
- Rebalanced Ultra-Light and Smooth presets across water, reflections, material specular/SSS/AO, glass and portal effects. Ultra-Light keeps features available but lowers sample counts/strengths; it uses 4-step water/opaque SSR, 25% wave/foam/caustics, reduced refraction/reflection, and disables POM/generated normals/coating. Smooth uses intermediate strengths and 6-step water SSR.
- Ultra/HDR retain higher-quality water and material settings and enable the optional fourth very-large water-normal scale. WATER_WAVE_DETAIL is a checkbox with an explicit one-extra-texture-sample tooltip.
- Water caustics are implemented in the shadow pass through WATER_CAUSTICS_STRENGTH/SCALE and translucent shadow-colour output; these profile values tune that existing path.
- This is preset-level performance intent, not measured FPS. Target-device profiling on Intel HD 5500 remains required.


## Block-entity material dispatch — 2026-11-23
- Ported Complementary's Iris block-entity ID map for chests/trapped chests (5008), ender chests (5012), shulker boxes/heads/beds (5016), conduits (5020), bells (5028), copper chests/statues (5032), banners (5036), and enchanting-table books (10548). IDs and block names were copied from the supplied working shader's block.properties reference.
- Added reference-guided chest and ender-chest smoothness/emission fallbacks, conduit color-coded emission and lightmap boost, bell gold/stone classification, copper material smoothness/reflectance, and enchanting-book smoothness/emission cues.
- Explicit oldPBR/LabPBR specular maps retain priority for material smoothness and reflectance; fallback dispatch is used only when no specular map exists. PBR-map emission retains priority over fallback emissive cues.
- Banner surfaces skip generated normals and POM to preserve their flat patterned appearance. Other block entities keep existing atlas-safe material paths.
- Added structural regression checks for all mapped IDs and dispatch branches. Await CI before treating the new material branch as validated; no runtime visuals or Intel HD 5500 performance are claimed.


## Block-entity fallback priority correction — 2026-11-23
- Follow-up audit separated fallback smoothness/reflectance from fallback emission. Smoothness and reflectance remain fallback-only when no specular map exists; ender-chest, conduit and enchanting-book emission cues now remain available when a specular map exists but does not encode emission.
- The conduit lightmap-coordinate boost is now applied independently of specular-map emission, matching the reference's material lighting behavior.
- Added regression assertions for the separated material-map and emission fallback branches. CI must pass before validation is complete.


## Block-entity material-dispatch refinement — 2026-11-23
- Run #1077 (45111905855) passed the initial dispatch. A detailed comparison then found the conduit lightmap was written to the G-buffer before its boost, conduit fallback emission was capped below the reference values, and bell gold smoothness used an extra square.
- Moved outLightmapData after the conduit adjustment; restored conduit blue/wind emission to albedo.r * 16 and red-eye emission to 20; corrected bell gold smoothness to color.g squared.
- Added per-material coating factors from Complementary's blockEntityIPBR reference: chest/ender chest 0.66, shulker/head/bed 0.2, bell gold 0.33, bell stone 0.77, copper 0.5, banner 0.2. Explicit specular maps retain priority and do not receive fallback coating.
- The corrected commit needs a fresh CI run. Chest seam, conduit lighting, bell material and copper appearance still need in-game visual validation.


## Block-entity coating priority follow-up — 2026-11-23
- Run #1079 (45112309599) passed all stages for the corrected conduit lightmap/emission, bell gold and material-specific coating dispatch.
- Final review removed fallback-emission and smoothness gates from the block-entity coating call. Complementary applies coating to ender chests even when their fallback glow is active, and the per-material factors are already deliberately conservative. Explicit PBR-map emission and explicit specular maps still retain priority.
- CI now guards that fallback coating is not accidentally suppressed by emissionStrength or smoothness thresholds while explicit PBR emission remains protected.


## Block-entity coating validator alignment — 2026-11-23
- Run #1080 (45112397002) compiled and linked all shaders but the structural validator still required the old generic block-entity smoothness/emission gates. The reference-guided material-factor path intentionally allows ender-chest fallback coating while keeping explicit PBR-map emission/specular priority.
- Updated the validator to keep the generic smoothness gate for terrain/entities, but validate block entities through their explicit materialCoatingFactor and PBR-map priority conditions instead.
- A fresh CI run is required for this validator correction.


## Chest block-entity seam correction — 2026-11-23
- Added Complementary's narrow chest depth-bias correction for blockEntityId 5008 when the fractional world Y coordinate is in the 0.56–0.57 seam band.
- Uses vPlayerPosition.y + cameraPositionFract.y rather than a large absolute cameraPosition float, preserving the fractional coordinate with Iris' split integer/fractional camera uniforms.
- The bias is a 0.0001 clip-space Z adjustment and applies only to chest/trapped-chest block entities. CI validation is pending; visual confirmation of the chest seam in-game remains required.


## Water-normal alpha inspection — 2026-11-23
- Run #1082 (45112646920) passed all nine stages after the chest seam correction.
- Added a lightweight CI asset inspection for water-normal.png. It reports image dimensions, channel layout and alpha min/max/unique-value count. A varying alpha channel is not automatically treated as height; its semantics must still be verified before implementing water parallax.
- The inspection is diagnostic only and does not change shader behavior. Water POM remains disabled until the asset is confirmed to contain a valid height field.


## Water-normal PNG integrity repair — 2026-11-23
- Run #1083 failed in the new asset-inspection step because the checked-in water-normal PNG raised a broken-data-stream error when Pillow decoded its IDAT payload. Shader compilation had already passed.
- Regenerated the 64x64 tileable RGBA normal field from periodic multi-frequency height waves. The new PNG fully decodes and verifies; alpha is constant 255 (one unique value), so it is not a height map and water POM remains disabled.
- Pixel alpha and RGB channel metadata are inspected in CI. The normal field remains three spatial samples in low profiles and the optional fourth sample in Ultra/HDR.
- The replacement texture has no runtime appearance or GPU performance claim until tested in Minecraft 26.3 + Iris.


## Block-entity coating parity with PBR resource packs — 2026-11-23
- Comparison with the supplied Complementary materialMethods/coatedTextures.glsl and gbuffers_block.glsl showed that per-material coating factors are applied independently of whether a resource pack provides a specular map.
- Corrected Serene's block-entity dispatch so chest, ender chest, shulker/head/bed, bell, copper and banner coating factors are assigned for both vanilla and PBR resource packs. Explicit specular maps still retain priority for smoothness/F0 fallback decoding.
- The coating pass remains blocked by explicit PBR emission and high reflectance/metal response, but no longer disappears merely because a non-emissive PBR specular map exists.
- Gold-bell and copper base-colour response remains material-specific; their fallback smoothness/F0 values are only applied when no explicit specular map exists.
- CI now guards the per-material factors and verifies that the coating gate does not require the absence of a PBR map. Runtime visuals and performance remain pending.


## First-person held-item PBR — 2026-11-23
- Added the Iris item.properties IDs from the supplied Complementary reference and a forward-rendered PBR path in gbuffers_hand. Iris docs confirm currentRenderedItemId reads item.properties in gbuffers programs, and at_tangent is valid in gbuffers vertex shaders.
- The hand path preserves vanilla colored-lightmap diffuse, then adds tangent-space oldPBR/LabPBR normal mapping, specular decoding and a low-cost GGX-style direct highlight. Item-ID fallbacks cover tool/armor material groups, ender pearls, clocks/compasses, amethyst and selected emissive items.
- HAND_PBR_STRENGTH is an explicit Quality slider: Ultra-Light=0 (skips the two additional material texture reads), Smooth=50, Ultra/HDR=100. No G-buffer targets are written by gbuffers_hand; it remains a forward pass.
- CI now links the hand program in the LabPBR branch in addition to compiling the default oldPBR branch. Runtime lighting, held-item tint, and target-GPU performance remain unverified.


## Hand PBR derivative-sampling validator correction — 2026-11-23
- Run #1087 compiled and linked every shader program, including gbuffers_hand in both oldPBR and LabPBR branches.
- Structural validation failed because the shared hand/terrain/entity/block atlas check accepted only texture(gtexture...), while the new hand PBR stage correctly uses textureGrad(gtexture, ...) so atlas derivatives remain available for normal/specular sampling.
- Updated the structural assertion to accept both ordinary texture() and derivative-aware textureGrad() atlas reads. This does not alter shader behavior; a fresh CI result is required.


## Held-item tangent-frame correction — 2026-11-23
- Run #1088 passed the hand PBR default and LabPBR compile/link variants after the earlier atlas-validator adjustment.
- Iris documents at_tangent.xyz as the model-space tangent approximation and at_tangent.w as tangent-frame handedness. The held-item vertex shader previously transformed a model-space cross product through the normal matrix, which can skew the bitangent under non-uniform transforms.
- Rebuilt the bitangent in view space from the already transformed and orthogonalized tangent and normal: cross(viewTangent, viewNormal) multiplied by Iris handedness. This now matches the Iris tangent-frame construction used by the terrain, entity and block-entity paths.
- Added CI checks for the view-space hand bitangent and item.properties unsigned 16-bit ID range/duplicate assignments. Runtime hand lighting and item appearance remain unverified.


## Hand tangent-frame refinement and CI result — 2026-11-23
- The follow-up audit corrected the hand bitangent construction to derive it from the already transformed view-space tangent and normal, matching Iris' documented tangent-space basis convention.
- Run #1089 passed all nine CI stages after the correction, including the LabPBR hand compile/link and full structural validation.
- Hand PBR remains runtime-unverified; check both first-person hand projection and held-item normal-map orientation in Minecraft 26.3 with Iris.

## Third-party reference/license review before public release
- The supplied working shader archive contains Complementary License Agreement 1.8. Its modified-pack grant lists visible credit, retention of the unmodified license, a noticeably different result, significant original additions, and no conflicting additional license terms.
- Serene's current root LICENSE declares MIT for original project files and states the reference shader is not included/copied/redistributed. Because material algorithms and item-ID mappings have been ported or adapted from the supplied Complementary reference, this needs deliberate compatibility review before public release.
- No license file or project license was changed. Keep this as a release gate: confirm applicable permissions/attribution with the rights holder or legal counsel, or replace directly derived material tables/code with independently authored equivalents before publishing releases.
- Official Complementary documentation states Unbound and Reimagined share the same engine and differ in default settings; Unbound remains the primary style reference for water/material tuning.


## Held-item material fallback coverage — 2026-11-23
- Compared gbuffers_hand material handling against the supplied Complementary irisIPBR.glsl and its iron/gold/diamond/copper/trident material helpers.
- Corrected clock versus compass classification: clocks/totems use the gold response; compass and echo/recovery-compass/music-disc items use the iron response. Added copper tool/armor fallbacks and the trident's smoothness/emission treatment.
- Added reference-aligned fallbacks for lava buckets, spectral-arrow group, end crystals, experience bottles and trial keys. Explicit PBR specular/emission maps still take priority; these are fallback heuristics only.
- Added CI assertions for the new item branches. Some reference item classes (notably harnesses, elytra and less common block-item IDs) still need a dedicated material review; held-item visuals and target-GPU cost remain unverified.


## Held-item material formula alignment — 2026-11-23
- Corrected the stone-tool smoothness cap to match the supplied Complementary stone material formula (pow(green,4) * 2, clamped to 1.0 rather than 0.4).
- Added the reference's mid-smoothness fallback for armor trims, and included the mapped froglight/campfire/copper-lantern item group in the low-cost emissive fallback.
- Normalized hand skylight using the same 30/32 lightmap range used by the terrain and block-entity paths, avoiding a small but systematic direct-highlight mismatch.
- These are fallback-only material heuristics; explicit PBR maps remain authoritative. CI compile/structure validation is required, and runtime held-item appearance is still pending.


## Water-normal audit status correction — 2026-11-23
- Updated the older reference-audit status text: texture-driven multi-scale water normals are implemented with a generated 64x64 tangent-normal asset, not merely analytic sine waves.
- The baseline uses three texture samples per water fragment; the optional fourth very-large octave remains disabled in Ultra-Light/Smooth and enabled in Ultra/HDR.
- Corrected the water-colour coordinate comment to document the actual 2560-block wrap (80 repeats at 1/32 scale), and made CI assert that the comment cannot drift from the stable-world period.
- The custom normal's alpha is constant 255, so it is not a verified height map. Water POM remains deferred; richer cloud/world-space reflections and runtime calibration remain outstanding.
- CI #1092 passed after held-item material fallback coverage was expanded. This does not substitute for Minecraft/Iris runtime testing.


## Entity item/armor material classification — 2026-11-23
- Extended Iris currentRenderedItemId handling into gbuffers_entities so dropped item models and worn armor use the same item.properties material groups as first-person held items.
- Resource-pack specular maps retain priority for smoothness, reflectance and emission. When no specular map exists, item IDs provide material fallbacks for armor trims, wood/stone/iron/gold/diamond/netherite/copper tools and armor, buckets, amethyst, shields, turtle shells, ender pearls, clocks/compasses, totems and tridents.
- Item emission fallbacks are applied only when the resource-pack specular map does not encode emission. LabPBR metals use the metal F0 code path; oldPBR items use deferred metalness. The entity pass reuses its existing specular sample and adds no texture fetches.
- CI must validate both oldPBR and LabPBR branches. Runtime dropped-item/armor appearance remains unverified.


## Low-cost celestial environment reflection — 2026-11-23
- Added one shared environment-reflection include for opaque and translucent materials. It retains the Iris sky/horizon gradient and adds a narrow sun/moon disk lobe from view-space shadowLightPosition and sunAngle.
- The lobe is procedural (dot product plus repeated multiplications), adds no texture fetches, and is evaluated only when SSR confidence is below 0.999. Full-confidence SSR hits skip the fallback work.
- The implementation follows Iris' documented view-space shadowLightPosition and normalized sunAngle; hasSkylight gates the celestial disk in dimensions without a sky.
- This is a low-cost approximation of Unbound's richer atmospheric/cloud reflection background, not full sky rendering or voxelized world-space reflection. Runtime appearance and HD 5500 cost remain unverified.


## Held-item world lighting — implemented, runtime calibration pending
- Deferred ambient now consumes Iris heldBlockLightValue/heldBlockLightValue2, heldItemId/heldItemId2 and relativeEyePosition.
- oldHandLight=false exposes independent main/offhand values. Item IDs select warm, cool, soul-blue, redstone, froglight, copper and emissive-item colors. The lava bucket alone receives the reference's explicit full-light override; all other items use Iris' actual held block-light value.
- Light energy is attenuated by player-space distance from the player-head origin. Main/offhand contributions are combined quadratically with existing ambient; no extra texture fetches are introduced.
- HELD_LIGHTING_STRENGTH is a Quality slider: Ultra-Light=0 (compiled out), Smooth=50, Ultra/HDR/Ultra-HDR=100.
- This is a screen-space ambient approximation. It does not cast shadows or respect occluders. Runtime range/color calibration and target-GPU cost remain pending.


## GLSL include-aware CI correction — 2026-11-23
- Run #1095 failed at the first standalone GLSL compile because glslangValidator does not expand Iris shaderpack #include directives unless the Google include extension is enabled.
- Iris handles shaderpack includes before the driver compiler; adding GL_GOOGLE_include_directive as a required runtime extension would unnecessarily narrow driver compatibility.
- Added a small recursive include expander for CI only. It resolves absolute Iris include paths from the shaders root, resolves relative paths from the including file, rejects path traversal and cycles, and expands nested includes into temporary compile sources.
- Updated every default, Iris-macro, LabPBR, entity-POM, water-detail and program-link compile stage to use the expander before glslangValidator. Runtime shader sources retain standard Iris #include syntax with no extra extension requirement.
- The shared celestial environment include remains unvalidated until the fresh CI run completes.


## Include-file version validation correction — 2026-11-23
- Run #1099 compiled every standalone shader, Iris macro branch, LabPBR branch, opt-in entity POM branch, opt-in Unbound water-detail branch and linked all vertex/fragment programs.
- Structural validation then incorrectly required the reusable `.glsl` include to declare its own `#version 330`. Iris includes are preprocessor fragments inserted into the parent stage; they must inherit the parent's version directive instead.
- Updated the structural check to require GLSL 330 only on standalone stage files. No runtime shader code changed.


## Gold/copper block-entity PBR fallback correction — 2026-11-23
- The shared deferred reflectance channel is format-dependent: oldPBR stores metalness, while LabPBR uses its G-channel F0 code and treats metal IDs (230–255) as albedo-colored conductors.
- Updated vanilla fallback shading for gold bell parts and copper chests/statues to mirror the existing item-material convention: LabPBR uses 1.0 metal classification; oldPBR retains the calibrated fallback metalness values (gold 0.72, copper 0.58).
- This only applies when no explicit resource-pack specular map is present. Explicit PBR maps remain authoritative.
- Added structural regression checks for both format-specific branches. CI required; visual calibration remains pending.


## Sign-board coating parity — 2026-11-23
- Compared `shaders/gbuffers_block.fsh` against the supplied Complementary `blockEntityIPBR.glsl`. Complementary assigns coating/noise factor 0.66 to sign block entities while separately identifying sign text.
- Serene already excluded sign text from coating, but had no material coating factor for the wooden sign board itself. Added the missing 0.66 factor for blockEntityId 5004; text remains excluded by the existing `!signText` gate.
- Added a structural regression assertion. Iris block.properties docs confirm block-entity IDs are supplied through `blockEntityId` in gbuffers. Await CI; no runtime appearance claim is made.


## Vanilla terrain metal material fallbacks — 2026-11-23
- Added Iris block.properties IDs matching the supplied Complementary reference for netherite, iron/raw iron, copper/raw copper (including oxidation and wax variants), raw gold and gold blocks.
- When no resource-pack specular map exists, terrain now derives bounded smoothness from the existing albedo sample and applies format-correct metal response: LabPBR uses metal classification 1.0; oldPBR uses calibrated material metalness values.
- Explicit resource-pack PBR maps remain authoritative. The coating modulation was moved after fallback classification and now skips these vanilla metal groups, preventing noise from perturbing their metal response.
- No additional texture fetches or render targets are introduced. The material branches use the existing specular/albedo samples and Iris mc_Entity material IDs.
- CI must validate the new mappings and both PBR branches. Runtime appearance and low-end GPU cost remain unverified.


## Dynamic held-item world lighting implementation — 2026-11-23
- Implemented the deferred main/offhand light contribution using Iris held-item IDs, block-light values and relativeEyePosition.
- The Ultra-Light profile compiles the path out; Smooth and Ultra/HDR profiles use progressively stronger settings.
- CI structural assertions now verify Iris uniforms, color/energy dispatch, quality gating and the quadratic ambient combine. In-game range, color and third-person placement remain unverified.


## Terrain metal coating parity — 2026-11-23
- Aligned vanilla fallback metal coating with the supplied Complementary material handlers: gold and iron blocks use a reduced 0.33 coating factor, copper uses 0.5, and raw-metal/netherite groups remain uncoated.
- Extended the existing terrain coating helper with a scalar material factor, matching the already-used block-entity coating design. The same single noisetex lookup is retained; no new texture fetches are added.
- Explicit PBR metal maps remain protected from coating. Fallback gold/iron/copper retain subtle reference-style coating without letting the default material threshold suppress their calibrated metal response.
- CI must compile both PBR branches and validate per-material factors. Runtime appearance and GPU cost remain unverified.


## Held-light item-energy parity refinement — 2026-11-23
- Compared the held-light path against Complementary's heldLighting.glsl and blocklightColors.glsl. The reference explicitly promotes only the lava bucket to full held light; other mapped items retain Iris' actual heldBlockLightValue.
- Removed unsupported light floors from spectral arrows, end crystals, tridents, experience bottles and other inventory items so non-light-emitting items do not glow merely because of their item ID.
- Updated the low-cost color table to match the reference families more closely: soul fire, redstone, froglights, copper lights, end rods, sea lantern, shroomlight, glow lichen, amethyst, end crystal, trident, experience bottle, eye of ender, glow ink, blaze, glowstone dust, prismarine crystals, nether star and ice crystal.
- CI now asserts the lava-bucket-only light override. Runtime color and range calibration remain pending.


## Vanilla gemstone/mineral terrain fallbacks — 2026-11-23
- Extended the Complementary-guided terrain material ID set to diamond, amethyst/budding amethyst, emerald, lapis, quartz-family and redstone blocks.
- These are treated as glossy dielectrics rather than metals: only smoothness is inferred from the existing albedo sample, while neutral dielectric F0 remains unchanged.
- Per-material coating factors follow the reference families (0.5 for diamond/emerald/lapis/quartz, 0.77 for redstone, disabled for amethyst). Explicit resource-pack specular maps remain authoritative for smoothness and reflectance.
- No extra texture reads or render targets are added. CI must validate the new IDs and both PBR branches; runtime appearance remains pending.


## Shared held-item lighting in translucent surfaces — 2026-11-23
- Moved the main/offhand energy, item-color and distance functions into a shared Iris include so the deferred opaque pass and forward translucent water/glass pass use identical logic.
- The include exits early when both Iris held light values are zero, avoiding distance and color work for ordinary items. The Ultra-Light quality setting compiles the path out entirely.
- Water uses its existing player-space position varying, so third-person camera offsets are handled by the same Iris relativeEyePosition calculation.
- CI now checks both call sites and the shared include. The effect still has no cast shadows or screen-space occlusion; runtime appearance and GPU cost remain pending.


## Shared held-light refactor integrity correction — 2026-11-23
- Corrected a source-splicing error in the first shared-include commit by rebuilding deferred.fsh from its intact parent revision and replacing the entire held-light function block at a verified boundary.
- Restored the water-wave-detail tooltip to the WATER_WAVE_DETAIL define and gave HELD_LIGHTING_STRENGTH its own correct slider annotation.
- Added a validator assertion for the early return when both held light values are zero. The shared opaque/translucent path remains pending the fresh CI result.


## Ultra-Light reflection quality path — 2026-11-23
- Changed Ultra-Light opaque and water SSR quality to 0 while retaining reflection strength. Opaque composite already falls back to the shared Iris environment reflection when SSR quality is zero.
- Added the matching water quality-zero branch: Fresnel reflections still use the shared sky/horizon and sun/moon environment approximation, but skip water SSR depth/color ray samples.
- Smooth remains at 6 steps and Ultra/HDR remain at 8 steps. Higher profiles retain screen-space reflections.
- Added validator checks for the environment-only water branch and the Ultra-Light zero-step profile. This is a quality/performance preset change; actual FPS and visual balance require in-game testing.


## Low-end reflection branch CI coverage — 2026-11-23
- Added explicit glslang compile/link coverage for the Ultra-Light quality-zero reflection branches in composite and water.
- The water quality-zero branch is compiled in both oldPBR and LabPBR; it must retain environment reflection while compiling out SSR sampling.
- Profile regression checks now enforce Ultra-Light=0 steps, Smooth=6 and Ultra=8 for both opaque and water SSR.


## Low-cost sky celestial glare — 2026-11-23
- Added a reference-guided active-celestial glare lobe to the sky-basic path, using Iris shadowLightPosition (sun by day, moon by night) and the player-to-view transform.
- The glare color shifts from cool lunar to warm solar and midday tones using the cyclic sunAngle elevation, and is attenuated by rain. It is applied only to sky/sunset render stages.
- This ports the low-quality glare concept from Complementary's sky path without its additional noise sampling. The implementation adds no texture reads or render targets.
- Iris documentation confirms shadowLightPosition is the view-space position of the highest celestial body (sun by day, moon by night), length 100, and gbufferModelView maps player space to view space.
- Full Rayleigh/Mie atmospheric scattering, volumetric light transport and visual calibration remain pending.


## Translucent entity held-item lighting — 2026-11-23
- Extended the shared Iris held-item lighting path to translucent entity models (for example, translucent entity layers) using the same player-relative position and relativeEyePosition correction as opaque and water paths.
- The path is controlled by HELD_LIGHTING_STRENGTH and exits early when both held-light values are zero; ambient contribution is combined quadratically to avoid a linear brightness spike.
- CI now requires the shared include, quality option and ambient combine in the translucent entity shader. This is source/CI coverage only; verify entity layers in Iris runtime, especially glass-like modded entities and third-person held-light placement.


## Translucent particle held-item lighting — 2026-11-23
- Added the shared dynamic main/offhand held-light contribution to the post-deferred translucent-particle forward pass, using its existing `vPlayerPosition` varying.
- The light is combined only into ambient illumination; vanilla particle lightmap, direct shadowed celestial light, material emission, fog, and fractional alpha/blending remain unchanged.
- Uses the existing `HELD_LIGHTING_STRENGTH` quality option and shared helper; no new texture samples or render targets are added. CI checks the include, quality gate and quadratic ambient combination.
- This is shader/CI validation only. Particle sorting, weather effects and translucent visual response still require Iris runtime testing.


## Translucent block held-item lighting — 2026-11-23
- Added shared dynamic held-item lighting to the forward translucent-block program (glass and other translucent block surfaces), using the existing player-space position varying.
- Preserves vanilla lightmap RGB, shadowed celestial direct light, fog, alpha and the color-only post-deferred output. No extra texture samples are introduced beyond the shared helper's Iris held-item uniforms; the helper exits early when both hand-light values are zero.
- Added the program to CI's shared-helper/quality-gate/quadratic-ambient regression checks. Iris runtime sorting and glass brightness still require visual testing.


## LabPBR porosity wetness on entity materials — 2026-11-23
- Extended the existing terrain porosity wet-darkening to opaque entities and block entities through a shared helper. LabPBR blue codes 0-64 are decoded to normalized porosity; codes 65-255 remain SSS data and metal blue channels remain reserved.
- Entity/block wetness uses Iris wetness, rainfall and biome_precipitation uniforms, with the same coefficients as the terrain path. Emissive and non-porous surfaces are unchanged.
- Explicit PBR maps remain authoritative. OldPBR has no porosity channel. The puddle accumulation effect remains terrain-only.
- No extra texture samples or render targets are added. CI and in-game wet-weather visual calibration are required.


## Porosity helper include ordering correction — 2026-11-23
- Run #1117 found the new helper was included before the MATERIAL_WETNESS_STRENGTH macro in the entity shader, so standalone GLSL compilation correctly rejected the undefined macro.
- Moved the helper include below the option macro in both entity and block passes and added a structural ordering assertion.
- No shader behavior changed; CI must revalidate both material paths.


## Ultra-Light glass reflection fallback — 2026-11-23
- Fixed a quality-tier gap in the Unbound-guided glass/ice path: previously all glass reflections were compiled out whenever `WATER_REFLECTION_QUALITY=0`, even though Ultra-Light retains the shared low-cost environment reflection helper.
- Clear, stained and tinted glass plus ice now retain Fresnel-weighted sky/horizon environment reflections in the zero-SSR branch. Higher tiers continue to blend screen-space hits with environment fallback.
- The zero-quality branch performs no SSR depth/color sampling. CI's existing zero-quality macro build and a new structural assertion cover the fallback; runtime intensity/tint calibration remains outstanding.


## Flowing-water-only shoreline foam — 2026-11-23
- Compared the water foam dispatch with Complementary Unbound's `water.glsl`: its shoreline foam branch explicitly requires material ID 32000 (actual fluid water), while cauldron water is classified separately.
- Split `isFluidWater` from the broader water-surface predicate. Flowing water and water cauldrons retain shared depth, refraction, absorption and underwater treatment, but shoreline foam calculation/application now runs only on actual fluid water.
- Added validator assertions for both the foam-generation and foam-composition gates. This is a source-parity correction; runtime shoreline/cauldron appearance still needs Iris testing.


## Near-camera glass response — 2026-11-23
- Compared the working Complementary reference's `translucentTweaks.glsl`: it reduces glass reflectivity within roughly 1.8 blocks and slightly reduces pane opacity within 4 blocks to avoid an overpowering near-camera surface.
- Serene now applies the same bounded distance response to clear, stained and tinted glass: reflection fades to zero at very close range, while alpha blends halfway toward alpha-squared at point-blank distance and returns to the sampled alpha by four blocks.
- The change uses the existing view-space position and adds no texture reads, loops or render targets. CI asserts both distance gates. Runtime tuning across panes, connected-texture packs and resource-pack alpha variants remains outstanding.


## Unbound ice highlight response — 2026-11-23
- The supplied Complementary reference's translucent IPBR dispatch derives ice smoothness from the cube of the texture green channel, scales the highlight with the squared green-channel response, and uses a 0.7 reflection multiplier.
- Serene previously gave ice only the shared Fresnel reflection path; it had no direct specular highlight. Added a bounded Blinn-Phong highlight using the existing geometric/PBR normal, view vector, celestial light and translucent shadow result. Smoothness controls an 8–128 exponent; the reference-inspired green-channel highlight multiplier and 0.7 scale are retained.
- The implementation is ice-only and adds arithmetic but no texture samples, loops, render targets or new varyings. It remains subject to in-game appearance/performance calibration.


### Stained and tinted glass response — 2026-11-23
Stained glass now receives a low-cost direct specular highlight and reference-aligned reflection multiplier (1.0); tinted glass reflection multiplier is raised to 1.0. Clear glass remains 0.5 and ice 0.7. The stained-glass highlight approximates Unbound's medium-smoothness/1.5 highlight settings with existing lighting vectors and no extra samples. Runtime visual calibration remains pending.


### Clear-glass specular distinction — 2026-11-23
Clear glass now receives a sharper exponent-128 direct highlight with the Unbound reference multiplier 3.5, gated by sampled alpha > 0.001. Stained glass keeps its medium exponent-32 highlight and 1.5 multiplier. The two materials no longer share one direct-highlight response. No additional texture samples or render targets; visual calibration remains pending.


### Tinted-glass grazing opacity — 2026-11-23
Tinted glass now follows Unbound's default alpha^(1-Fresnel) opacity curve, increasing opacity toward grazing angles while preserving the existing reflection scale. The calculation reuses view-space normals and adds no texture samples. Runtime visual calibration remains pending.


### Underwater depth-opacity separation — 2026-11-23
- Complementary Unbound's `water.glsl` skips surface-depth, water-fog opacity and shoreline-foam work while `isEyeInWater == 1`; underwater it applies the separate 0.75 alpha reduction.
- Serene previously applied the above-water depth-opacity curve and screen-space refraction underwater. It now skips depth reconstruction, foam and refraction underwater, and retains the 0.75 alpha reduction without the surface-depth opacity multiplier.
- Above-water thickness, Beer-Lambert absorption, foam, refraction and SSR/environment reflections remain unchanged. The underwater branch also avoids a full-resolution depth fetch.
- Validator assertions cover the underwater gates and both alpha branches. In-game underwater/waterline appearance and GPU profiling remain outstanding.


### Opaque water depth excludes first-person hand — 2026-11-23
- Iris' current DepthTex reference specifies `depthtex1` excludes transparent geometry, while `depthtex2` excludes both transparent geometry and hand geometry. Water thickness and refraction need the opaque scene depth, not the first-person hand depth.
- The water pass previously sampled `depthtex1`, allowing a hand held in front of the water to become the reconstructed opaque intersection and distort thickness/absorption/refraction. These lookups now use `depthtex2`, which is already the opaque depth source used by the water SSR marcher. Both buffers are full resolution, so pixel mapping is unchanged.
- The change removes the redundant `depthtex1` declaration and updates structural validation. Verify first-person hand-over-water scenes in Iris at runtime; CI validates shader compilation and source structure only.


- Follow-up validator guard: the water shader must not regress to `depthtex1`, and the refraction lookup assertion now explicitly requires `depthtex2`.


### Water scene-copy odd-dimension fix — 2026-11-23
The half-resolution `colortex4` scene snapshot now integrates the exact full-resolution footprint of each destination texel. This fixes edge texel omission and depth/color alignment at odd framebuffer dimensions while preserving the four-tap path for even dimensions. The bounded 3x3 fallback only performs nonzero-overlap fetches. Runtime testing and low-end GPU profiling remain pending.


## Alpha release pipeline — 2026-11-23
- Added a GitHub Actions release workflow that waits for the existing shader validation workflow to succeed on a push to `main`.
- The workflow packages the `shaders/` directory and pack metadata at the exact validated commit, generates a SHA-256 checksum, and publishes a GitHub pre-release tagged `alpha-<short-sha>`.
- Alpha packages are explicitly experimental. CI checks compilation and structure only; in-game visual, compatibility and performance validation remain required.
- Release page: https://github.com/Pawar-47/Serene-Ultra/releases


### Water cylindrical-fog metric — 2026-11-23
- Corrected `gbuffers_water.fsh` cylindrical fog distance to `max(length(vViewPosition.xz), abs(vViewPosition.y))`, matching Minecraft's stock `fog_cylindrical_distance` implementation and Iris' documented `fogShape == 1` meaning.
- Spherical fog remains Euclidean `length(vViewPosition)`.
- Added a structural regression guard. GLSL/structure CI does not validate visual fog calibration; verify vertical look angles and waterline transitions in-game.


### First-person hand-water fog consistency — 2026-11-23
- Applied the same vanilla cylindrical fog distance to `gbuffers_hand_water.fsh` as the world-water pass: `max(length(vViewPosition.xz), abs(vViewPosition.y))`.
- Extended structural validation to prevent the first-person water pass from regressing independently.


### Forward weather cylindrical-fog consistency — 2026-11-23
- Corrected `gbuffers_weather.fsh` to use `max(length(vViewPosition.xz), abs(vViewPosition.y))` when Iris reports cylindrical fog.
- World water, first-person hand-water and weather now share the stock Minecraft cylinder distance; spherical mode remains unchanged.
- Added a weather-specific structural regression guard.


### Unbound water grazing-opacity parity — 2026-11-23
- Compared Serene's water-alpha path with Complementary's Unbound-style branch in `water.glsl`. Unbound applies a final `mix(alpha, 1.0, fresnel^4)` where its water-facing Fresnel term is `1 - NdotV`.
- Serene previously used a Schlick reflection-style Fresnel term and multiplied its opacity blend by 0.25, leaving water noticeably more transparent at grazing angles than the reference response.
- Separated the opacity curve from the Schlick reflection curve: the water opacity now uses `(1 - NdotV)^4` at full strength, while the independent reflection Fresnel remains unchanged.
- Added structural regression checks. Validate the waterline, shallow shorelines, and oblique camera angles in Iris at runtime; compiler CI cannot confirm visual calibration.


### Correct modern Unbound underwater alpha parity — 2026-11-23
- A closer read of Complementary's current Unbound-style water branch showed that the 0.75 alpha reduction previously attributed to modern Unbound is not applied for current Minecraft versions; the underwater branch preserves the sampled texture alpha.
- Removed Serene's extra `translucentAlbedo.a *= 0.75` underwater multiplier. Above water, Unbound style 3 continues to force alpha to 0.98 and then applies depth opacity; underwater Serene now keeps the sampled alpha before its grazing-angle blend.
- Updated structural validation to reject the obsolete multiplier and require the above-water-only 0.98 assignment. Runtime underwater/waterline validation remains outstanding.


### Iris buffer-blend parser startup failure — 2026-11-23
- User-reported Iris startup error: `Failed to parse buffer blend! Index = -1`, with shaderpack visuals remaining vanilla.
- Traced Iris 26.1 `ShaderProperties` parser: for `blend.<program>.<buffer>`, the buffer name must resolve to a legacy render target or a numeric `colortexN`. `shadowcolor0` resolves to index -1 and is rejected. The offending directive was `blend.shadow.shadowcolor0=off`.
- Removed the invalid buffer-blend override. Retained `shadowTranslucent=true` and the separate `flip.shadow.shadowcolor0=false` setting; no color-buffer blend directive is needed for the shadow-color target.
- Added a structural regression guard to reject any future `blend.shadow.shadowcolor0` directive. This is a pack-loading fix; test the new alpha in Iris to confirm startup proceeds past the reported parser error.


## Shader interface, Iris fallback and release-gate continuation — 2026-11-23

- Current source HEAD before this checkpoint update: `d859ed8ea1df974aa9c0fa3d01ade567c1d65fc4`.
- CI run `45147173862` (run #1165) passed on that exact commit: standalone GLSL compilation, optional macro branches, water-normal inspection, program linking and structural validation.
- Audited all current paired vertex/fragment programs. Fragment inputs match vertex outputs by varying name, GLSL type and interpolation qualifier. Added automated regression validation; run #1159 passed this check.
- Added render-target output-location validation: each modern fragment program's sequential output locations must match the ordered `RENDERTARGETS` slots.
- Expanded the missing-program warning inventory from Iris 26.1 `ProgramId.java`, including item, glowing entities and all standard shadow subprogram fallbacks. These are explicit Iris fallbacks, not proof of dedicated material behavior.
- Removed the unused `iris.features.optional=ENTITY_TRANSLUCENT` directive. It only requests a shader feature macro and does not activate translucent entity routing; the validator now reports `separateEntityDraws=true` as best-effort and requires runtime confirmation.
- Added manual runtime regression checks for dropped items, glowing entities, shadow subprograms, terrain cutout/solid routing, translucent entity sorting, blend-parser startup errors and shaderpack cache/restart behavior.
- **Release safety correction:** the alpha workflow previously published a prerelease after every successful push. Its job now requires the repository Actions variable `ENABLE_ALPHA_PUBLISH=true`; with the variable unset, publishing is skipped. The latest validation run #1165 passed and the corresponding publish workflow run #29 was skipped.
- An older public prerelease `alpha-25b0ee0` was already published before this gate was added. It is experimental and has not been runtime-verified; do not treat it as a validated working build. No newer prerelease was created for `d859ed8`.
- Current HEAD `d859ed8` remains source/CI validated only. Actual Iris/Minecraft runtime testing, visual parity, and Intel HD 5500 performance measurements remain outstanding.


## Continuation — audit inventory and verification gates (2026-11-23)

- Reconfirmed `main` at `c6dfc29327b9e15bd0bb195962ed2bc9cbee6ed5`; the recorded CI run `45147325818` (#1166) is successful.
- Inspected the current source pairs for `gbuffers_water`, `gbuffers_weather`, `gbuffers_hand_water`, `gbuffers_block`, `gbuffers_entities_translucent`, and the deferred half-resolution opaque-scene copy. All three post-deferred water/weather/hand-water pairs are present; water samples opaque depth from `depthtex2` and the half-resolution opaque snapshot in `colortex4`, while weather and hand-water use dedicated forward lightmap/fog paths.
- Confirmed that the previous top-level coverage inventory and next-step list in `IRIS_PIPELINE_AUDIT.md` had become stale and contradicted later implementation notes. Updated them to match the current source inventory and to distinguish source presence from runtime correctness.
- Current risk boundary: these are source-level implementations only. Water refraction/SSR, translucent alpha/depth behavior, weather rendering, hand-water, entity/block/particle sorting and full scene preservation remain unverified in Iris/Minecraft.
- The two supplied archives remain mandatory comparison sources. No new file-by-file archive comparison is claimed in this continuation.
- Alpha publishing remains disabled by default; do not set `ENABLE_ALPHA_PUBLISH=true` until runtime smoke tests and visual checks pass.
- Next: continue stage-by-stage review of translucent paths and their buffer/blend contracts, then reconcile corresponding Vanilla-stock and Complementary source files before feature changes.


## Follow-up correction — historical wording and weather-state test (2026-11-23)

- Clarified the Iris pipeline audit so its original fallback/attachment hazard is explicitly historical; it no longer says the current source lacks water, weather or hand-water program pairs.
- Added an Iris-uniform contract note: `isEyeInWater == 3` means powdered snow, and added a runtime test for weather rendering across camera states.
- CI runs #1168–#1170 were triggered by the documentation/checkpoint commits; #1166 remains the latest confirmed successful run at this point. Check the newest run before treating these documentation commits as CI-validated.

## Continued Iris routing audit (2026-11-23)

- Latest `main` before this continuation was `ec7f416871e7fb51f70801779a6e7d7e43dfbafe`; CI #1172 passed on that commit.
- Rechecked current Iris docs and the Iris source snapshot for `separateEntityDraws`. The directive is parsed/stored and the pipeline maps translucent entity/item render pipelines to the translucent shader keys, but current docs warn that separate entity drawing may be broken in newer Iris versions. The pack's setting and shader files are not proof of runtime routing.
- Added a dedicated release-blocking runtime test for actual translucent entity and block-entity program routing. Kept `particles.ordering=mixed`, which Iris documents as the intended split for opaque vs translucent particles.
- No runtime pass or alpha publication is claimed.

## Final-pass bloom implementation — 2026-11-23
- Added a real five-tap, thresholded single-scale bloom contribution to `final.fsh`, reusing the existing scene buffer and adding no render target.
- Exposed bloom strength and highlight threshold in the Color screen, slider list, user-facing tooltips and all five profiles. Ultra-Light compiles bloom out; Smooth/Ultra/HDR/Ultra-HDR progressively increase strength.
- Added structural regression checks for shader implementation, menu exposure, tooltips and profile values.
- This is a low-bandwidth baseline, not the reference's multi-scale bloom system. Multi-scale blur and visual calibration remain outstanding; no claim of reference parity is made.


## Final-pass spatial anti-aliasing — 2026-11-23
- Added an edge-adaptive FXAA pass in `final.fsh`, with luminance range detection and direction-limited sampling.
- FXAA uses the existing scene attachment and no temporal history or extra render target. It is disabled in Ultra-Light and enabled in Smooth and higher profiles.
- Added the user-facing Color-screen toggle, slider entry, tooltip, profile presets and structural regression checks.
- FXAA is a spatial AA baseline only; TAA, temporal reprojection and reference edge-quality comparison remain pending.


## FXAA profile validation correction — 2026-11-23
- The first combined bloom/FXAA CI run compiled and linked every shader successfully but the structural validator correctly caught missing `FXAA_ENABLED:1` entries in HDR and Ultra-HDR presets.
- Added the missing values to both HDR profiles. The failing run is not treated as a passing validation; the corrected commit has a new CI run pending.


## Screen-space sunlight shafts — 2026-11-23
- Added a depth-gated radial sunlight-scattering approximation to `composite.fsh`. It projects Iris' active view-space shadow-light direction, samples bright visible sky along the ray and adds a warm contribution only to opaque receivers.
- Added strength and 0/4/8/12-sample quality controls to the Quality screen, sliders, tooltips and all five profiles. Ultra-Light compiles the effect out; Smooth, Ultra and HDR tiers progressively increase the sample budget.
- Added structural checks for the shader path, UI exposure and per-profile settings.
- This is not full volumetric fog/cloud-shadow integration or a world-space volumetric system. It is a low-cost screen-space baseline and needs Iris runtime/visual validation before being considered complete.


## Verified post-processing continuation checkpoint — 2026-11-23
- Latest source commit: `79737edaeeb68f6c4be2798d512d04f98a754590`.
- CI run `45197005372` passed all stages: standalone GLSL compilation, Iris render-stage macro branches, LabPBR, entity POM, Unbound water-wave detail, Ultra-Light reflection branch, water-normal asset inspection, vertex/fragment linking and structural validation.
- This verifies shader compilation/linking and declared structural contracts only. It does not verify Minecraft 26.3 + Iris runtime loading, image quality, performance or visual parity.
- Alpha publication remains disabled; workflow run `45197020825` was skipped.
- Bloom, FXAA and screen-space sunlight shafts are implemented as low-cost source-level approximations with profile controls. Multi-scale bloom, TAA, full volumetric integration, world-space GI, procedural cloud layers, custom colored-light propagation and archive-level feature-by-feature source reconciliation remain outstanding.


## POM atlas-boundary correction — 2026-11-23
- Fixed terrain, block-entity and entity-model POM traversal: UV steps now clamp to the current sprite's local [0,1] bounds instead of using `fract()`, which wrapped a ray to the opposite edge of the same atlas tile and could create visible discontinuities.
- Added structural regression checks to reject wrapped POM traversal and require local sprite clamping.
- Shader compilation and POM visual behavior remain subject to the next CI run and in-game resource-pack tests.



## Composite depth redeclaration compile fix — 2026-11-23
- CI job `137776432847` on `cd193d0` failed at `shaders/composite.fsh:282` with `'currentDepthAll' : redefinition`.
- The screen-space GI commit added the opaque-receiver gate but left the previous depth block behind: `currentDepthAll` was declared twice, and `float depth` re-fetched `depthtex2`, whose value was already held in `centerDepth`.
- Removed the duplicate declarations and reused the existing `opaqueReceiver` predicate for the translucent-overlay early return. Reflection and GI behaviour are unchanged; every structural validator token from the GI contract is preserved.
- The compile loop aborts at the first failure, so the stages ordered after `composite.fsh` were not compiled in that run. The next CI run is the first evidence for those stages and must be checked before any status claim.
- This is a compilation fix only; the runtime checklist from the handover is still untouched.

- Follow-up on the same defect: removing the duplicate declaration also removed the only assignment to `depth`, which the reflection path still used at its view-position reconstruction. That reconstruction was identical to the `centerViewPosition` already computed from `centerDepth`, so the reflection path now reuses it instead of rebuilding the matrix product. Structural validator tokens are still satisfied.



## Two-scale bloom chain — 2026-11-23
- Replaced the single-scale five-tap full-resolution bloom with a four-stage chain. `composite1` thresholds the lit scene with a soft knee and resolves it to a half-resolution level (`colortex5`); `composite2` runs the horizontal nine-tap Gaussian into `colortex6`; `composite3` runs the vertical half back into `colortex5`; `composite4` resolves the wide quarter-resolution level (`colortex7`). `final.fsh` combines both levels with four-tap tent upsampling.
- The previous implementation could not produce a wide halo at all: five taps around one pixel at full resolution only ever spreads a few texels. The half-resolution level now carries a real separable blur, and the quarter-resolution level supplies the wide falloff.
- Buffer sizes are declared in `shaders.properties` (`colortex5`/`colortex6` at 0.5, `colortex7` at 0.25). Formats stay at the default RGBA8 to avoid doubling bandwidth on the HD 5500 target.
- **Flip contract:** the first revision of this change set `flip.*=<buffer>=false` for every bloom stage, which was wrong. The existing `deferred`/`deferred1` settings show the actual contract: a buffer a pass writes must flip so the next pass reads the new contents (`flip.deferred1.colortex4=true`), and a buffer it only reads must not flip (`flip.deferred.colortex3=false`). Each stage now flips exactly the buffer it writes, and all four decline to flip `colortex0`, which they only sample. The validator asserts both directions.
- `BLOOM_STRENGTH` is declared identically in all five participating programs, matching the existing `POM_QUALITY` and `WEATHER_TEX_OPACITY` convention for options shared across programs. `BLOOM_THRESHOLD` moved to `composite1.fsh`, where the bright pass now lives; it is still exposed in the Color screen, the slider list and the locale file.
- Ultra-Light keeps `BLOOM_STRENGTH:0`, so the chain writes zeroed buffers and `final.fsh` adds nothing; the passes still execute, which is the honest cost of a fixed pass graph.
- Structural validation now covers stage presence, render-target wiring, the separable axis per blur stage, declared buffer sizes, both directions of the flip contract, and that both levels reach `final.fsh`.
- **Scope:** compiled/structural validation only. Actual appearance, halo width, threshold calibration and HD 5500 cost are unverified and need the in-game checklist. This is two scales, not the reference's full mip chain, and it still operates on the pack's display-referred LDR scene buffer rather than a linear HDR one.



## Flip directive audit against Iris source — 2026-11-23
- Checked `ShaderProperties`, `PackRenderTargetDirectives`, `CompositeRenderer` and `RenderTargets` in the Iris repository instead of relying on the existing comments in `shaders.properties`.
- `ShaderProperties` stores `flip.<pass>.<buffer>` per program in `explicitFlips`. `CompositeRenderer` then flips **every draw buffer of the pass by default**, and additionally applies each explicit entry that is `true`: `for (int buffer : drawBuffers) { if (explicitFlips.get(buffer) == Boolean.FALSE) continue; bufferFlipper.flip(buffer); }` followed by `explicitFlips.forEach((buffer, shouldFlip) -> { if (shouldFlip) bufferFlipper.flip(buffer); });`
- `RenderTargets.createColorFramebuffer` binds main when the buffer is in the flipped snapshot and alt otherwise, so a pass writes main while reading alt, and the default flip swaps the pair so the next pass reads what was just written. A **second** flip cancels that swap and the next pass reads the texture that was never written.
- Consequence: `flip.<pass>.<buffer>=true` on a buffer that same pass writes is never merely redundant — it is a double flip. It is only meaningful for a buffer the pass does not write, which the explicit loop flips on its own.
- **Defect found and fixed:** `flip.composite.colortex0=true` was set while `composite.fsh` writes colortex0 (`RENDERTARGETS: 0`). That cancelled the swap, so `final` sampled the pre-composite image and everything the composite pass produced — opaque screen-space reflections, screen-space sunlight shafts and the new screen-space GI — was discarded. This is a strong candidate for the repeated "shaderpack still looks largely vanilla" reports, because it silently removes the whole composite stage while every compile and structural check still passes.
- Bloom stages now declare no flip for the buffer they write and pin only the buffers they read to `false`. Structural validation derives each composite pass' draw buffers from its `RENDERTARGETS` line and rejects any `flip.<pass>.colortexN=true` on one of them.
- **Still unverified:** `flip.deferred.colortex0=true` and `flip.deferred1.colortex4=true` are the same shape and are probably the same defect, but the deferred stage is rendered by `DeferredWorldRenderingPipeline`, whose flip handling was not inspected. They were left unchanged rather than guessed at. Confirm that renderer before touching them.
- Nothing here is runtime-verified. The expected visible change is that reflections, sunlight shafts and screen-space GI now actually appear; if the scene instead loses its lit appearance, this analysis is wrong and the line should be restored.


### Flip contract confirmed against the Iris documentation site — 2026-11-23
- Checked `shaders.properties/current/reference/shadersproperties/rendering/#flip`, which states the behaviour directly: composite-style passes "read from the main buffer and write to the alt buffer, and after that program the main and alt buffers are swapped so data written by the current program is read by the next program", and `flip.<program>.<buffer>=false` "will disable the buffer flip that would happen after the end of that program".
- That is a single default flip per written buffer, matching `CompositeRenderer`. An explicit `=true` therefore adds a second flip that cancels the swap. The earlier decision to remove `flip.composite.colortex0=true` is confirmed correct by the documentation, not only by the source.
- Extended the fix to the remaining occurrences, which were the same defect: `flip.deferred.colortex0=true` (`deferred.fsh` writes colortex0) and `flip.deferred1.colortex4=true` (`deferred1.fsh` writes colortex4). The latter meant the water pass read a colortex4 that deferred1 had not actually published, so the half-resolution opaque-scene copy used for refraction and screen-space reflections was never seen by its consumer.
- Removing these is safe under either implementation reading: with no directive the documented and implemented default still applies exactly one flip. Only read-only buffers remain pinned, to `false`.
- Structural validation now derives every program's draw buffers from its own `RENDERTARGETS` line and rejects any `flip.<program>.colortexN=true` where that program writes colortex N, so this class of error cannot return.
- Confirmed supporting facts from the same documentation pass: program order is gbuffers opaque → deferred → gbuffers translucent → composite → final (so the bloom chain sits correctly between composite and final); colortex buffers default to `RGBA8` and are cleared every frame; a buffer whose size is changed cannot be written by a gbuffers program, and a single program may only render to identically sized buffers — the bloom stages each write exactly one sized buffer, so both rules hold.
- Still runtime-unverified. The expected visible result is that water refraction/reflections and the composite-stage effects appear at all.


## Clouds celestial lighting and manual alpha trigger — 2026-11-23
- `gbuffers_clouds.fsh` previously applied only texture, vertex alpha and fog, so the cloud layer read as flat paint. It now applies a bounded day/night exposure from `sunAngle`, and a forward-scattering silver-lining term from the view direction and `shadowLightPosition`. Both use uniforms already in Iris' contract and used by other gbuffers programs. Normalisation is guarded so a dimension without a celestial body cannot produce NaN.
- Scope: this is a low-cost forward approximation, not volumetric or self-shadowed clouds, and it does not cast cloud shadows. Those remain pending.
- `alpha-release.yml` gained a `workflow_dispatch` trigger with a `publish` input, so a testable build can be produced on demand. Automatic publishing on every validated push remains gated by `ENABLE_ALPHA_PUBLISH=true` and is still off.
- Structural validation now checks the new cloud terms.
- Status: source and CI compile/structure only. No Minecraft/Iris runtime run has occurred for any change in this session.


## Screen-space GI quality tiers — 2026-11-23
- Expanded the local colour-bounce pass from a fixed four-cardinal-sample pattern to selectable 4/8/12 depth-aware neighbour samples.
- Added `SCREEN_GI_QUALITY` to the Quality menu, slider list, language labels/tooltips and all five profiles: Ultra-Light 0, Smooth 4, Ultra 8, HDR 8, Ultra-HDR 12. Strength values remain unchanged.
- The 4-sample tier uses cardinal taps; 8 adds diagonal coverage; 12 adds a wider cardinal ring. The pass retains its opaque receiver/depth/normal rejection.
- Updated structural validation to require the 12-sample pattern, quality loop, UI exposure and exact profile values.
- This remains a spatial single-bounce screen-space approximation, not full GI. Higher tap counts increase texture sampling and have not been benchmarked on Intel HD 5500. CI and in-game runtime validation are required before calling the change verified.



## Continuation update — 2026-11-23 (reference archives, validator and 26.3 transparency)

### Source archives inspected
The two user-supplied archives are now available in the active workspace and have been inspected directly; this supersedes the earlier checkpoint note that their bytes were unavailable.

- Working Complementary Reimagined archive: 415 shader/include sources under `shaders/`; 213 declare GLSL 130, 3 declare GLSL 400 compatibility (shadow vertex exceptions), and 199 are include fragments without their own version declaration. Relevant water/weather files inspected include `world0/gbuffers_water.vsh/.fsh`, `program/gbuffers_water.glsl`, `world0/gbuffers_weather.vsh/.fsh` and `program/gbuffers_weather.glsl`.
- Vanilla-stock Minecraft 26.3 archive: 89 shader/include sources; 72 declare GLSL 330 and 17 are includes without a version declaration. The stock terrain and OIT files were inspected, including `core/terrain.vsh/.fsh`, `core/rendertype_water_mask.vsh/.fsh`, `core/oit_composite.fsh`, `core/oit_depth_bounds_cull.fsh` and the OIT include family.

### Iris 26.3 transparency decision
Inspected Iris source snapshot `IrisShaders/Iris@bff1e69cb6c5519d8745784aa9c8b92984de67e7`. It maps translucent terrain to `ProgramId.Water` / `gbuffers_water`, water mask to `gbuffers_basic`, and translucent particles to `gbuffers_particles_translucent`. The inspected shaderpack path does not expose Minecraft's native `OIT_*` phases. Serene will keep Iris-specific forward alpha blending; no native OIT shader files or attachments will be copied into the pack. Runtime testing on the exact target Iris 26.3 build remains mandatory.

### Validator defects corrected
- Fixed indentation that had accidentally nested alpha-test and deferred-mask blending checks under the missing-`WAVING_RAIN` branch.
- Moved particle material option/label checks outside the per-file weather loop.
- Added output-slot validation for GLSL 130 `outColorN` declarations against ordered `RENDERTARGETS`, while retaining explicit-layout validation for GLSL 330.
- Tightened Iris buffer-format validation so the required RGBA8 directives must appear in valid block comments.
- Corrected buffer-flip validation to match Iris implementation: composite-style draw outputs ping-pong automatically; `flip=false` suppresses that output swap, read-only inputs are not flipped and need no override, and `shadowcolor0` is a separate shadow attachment rather than a colortex target.

### Commits and validation
- `a1e4ffca863c0a2ce5f1be2c9e33b65e06998313` — skipped validation checks and GLSL 130 output-slot validation.
- `e60eda79e075b3b1bc6374e4a381ce3b5afc55fc` — correct Iris buffer-flip validation semantics.
- `cc9ef59d445696a3c3728c541b36632b1869ed11` — correct buffer-flip comments in `shaders.properties`.
- Latest recorded main HEAD: `cc9ef59d445696a3c3728c541b36632b1869ed11`.
- CI run `45210941836` passed on that exact HEAD, including standalone GLSL compilation, Iris macro branches, LabPBR, opt-in entity POM, Unbound water detail, Ultra-Light reflection branch, water-normal inspection, program linking and structural validation.
- Alpha publishing remains skipped/disabled. No Minecraft/Iris runtime or visual test has been performed.

### Next work
1. Run the 26.3 transparency regression on the exact Iris/Sodium build.
2. Continue exact-file comparisons for shadow, terrain, entities, block entities, hand, particles, sky and post-processing against both supplied archives.
3. Fix source-level gaps found by those comparisons, with validator coverage where the invariant can be checked statically.


## Authoritative Iris flip and shadow-buffer correction — 2026-11-23

This section supersedes every earlier checkpoint statement that explicit `flip.*=true` is required to publish an output, that read-only buffers need `flip=false`, or that `shadowcolor0` can be controlled by `flip`.

- Iris 26.1's `CompositeRenderer` automatically flips every colour attachment listed in a composite-style pass's draw buffers after the pass. An explicit `flip.<pass>.<buffer>=false` suppresses that automatic output flip. An explicit `true` is applied as an additional flip after the default output flip, so it can cancel the intended hand-off.
- A read-only attachment is not in the pass's draw-buffer list and is not automatically flipped. Setting `flip=false` for such a read-only input is therefore a no-op; it is not needed to keep the source stable. Setting `true` explicitly forces a flip and must be used only for a deliberate alternate-buffer algorithm.
- Iris resolves flip target names through the eight legacy colour aliases (`gcolor`, `gdepth`, `gnormal`, `composite`, `gaux1`–`gaux4`) or numeric `colortexN`. `shadowcolor0` is a separate shadow-colour attachment and is not a valid flip target. The old `flip.shadow.shadowcolor0=false` directive was ineffective/invalid and has been removed. Likewise, `blend.shadow.shadowcolor0=off` is not a valid colortex blend directive and must not be reintroduced.
- Current Serene source intentionally contains no explicit `flip.*` directives. `deferred`, `deferred1`, `composite`, and the bloom passes rely on Iris' default ping-pong for their declared `RENDERTARGETS`. The `deferred1` output `colortex4` is published by its default flip before the post-deferred water pass samples it.
- `tools/validate_pack.py` now rejects unsupported flip targets, non-composite flip program names, and explicit flip overrides on a pass's own output attachment. It supports dimension-qualified composite pass names and resolves the exact shader source path.

Iris 26.1 implementation references:
- `common/src/main/java/net/irisshaders/iris/pipeline/CompositeRenderer.java`
- `common/src/main/java/net/irisshaders/iris/shaderpack/properties/PackDirectives.java`
- `common/src/main/java/net/irisshaders/iris/shaderpack/properties/PackRenderTargetDirectives.java`

The cleanup is source/configuration-verified; the latest validator workflow must pass before it is marked CI-verified. Runtime rendering remains unverified.



## Continuation update — 2026-11-23 (26.3 clouds, fog, shadows and routing)

### Implemented source changes
- Inspected the supplied Minecraft 26.3 stock cloud shaders and the Iris `ShaderKey.CLOUDS` definition. Dedicated `gbuffers_clouds` now consumes the actual `POSITION_COLOR` interface; it no longer samples nonexistent cloud UVs. Cloud scattering has a zero-strength neutral path and remains neutral without skylight.
- Corrected the stock cylindrical fog metric in all 12 fragment programs that use `fogShape`. The validator now scans every fragment stage using `fogShape` and requires `max(length(position.xz), abs(position.y))`.
- Added a shared `lib/lighting/soft_shadow.glsl` rotated-Poisson PCF/colored-transmission helper and wired it into deferred, water, translucent entity, translucent block-entity and translucent particle lighting. Water shadow bias retains its geometric normal before wave perturbation.
- Updated validator expectations to the shared shadow helper. CI had first exposed stale inline-function assumptions; those checks were migrated to verify the helper implementation and every caller rather than bypassed.

### Iris 26.3 routing and transparency research
- Vanilla 26.3 stock contains native OIT accumulation/depth-bounds/composite shader files. The audited Iris shaderpack route maps translucent terrain to `gbuffers_water`, translucent particles to `gbuffers_particles_translucent`, and water-mask handling to `gbuffers_basic`; no shaderpack OIT phases are exposed in the inspected Iris source. Do not transplant vanilla OIT attachments/macros into Serene without an Iris-supported contract.
- Iris parses `separateEntityDraws` and maps translucent entity/block-entity/item shader keys, but the current official ordering docs warn that this feature may be broken in newer Iris versions. Keep it best-effort and require runtime confirmation; do not treat source mappings as proof of draw routing.
- Correct Iris flip semantics are documented in the authoritative section above: only declared composite-style draw outputs ping-pong; read-only flip overrides are no-ops, and `shadowcolor0` is a separate shadow attachment, not a colortex target.

### Validation
- Latest verified shader/code CI before this documentation update: run `45215046668`, success, on commit `f0de944e79b7ceed15c021586ae1eed09a80aec5`.
- This run included the shared soft-shadow validator update. No Minecraft 26.3/Iris runtime or visual test has been performed.
- Alpha publishing remains disabled.

### Next priority
Run the exact Minecraft 26.3 + Iris + Sodium runtime matrix for clouds, fog, colored shadows, translucent entity routing and native OIT interaction. Continue feature-parity implementation only after the active render routes are confirmed.


## User-directed project priority correction — 2026-11-23

The user explicitly corrected the recent work pattern: do not spend the next development cycles primarily on CI, structural validation, GLSL linting, or speculative Iris debugging. The priority is to finish the shaderpack's feature implementation comprehensively first. Iris runtime debugging and compatibility correction begin only after the planned shader feature set has been implemented and an actual Minecraft/Iris test environment is available.

### Required execution order
1. **Feature completion first:** implement the full Serene Ultra feature set against the tracked Ultra reference inventory in `docs/REFERENCE_ULTRA_AUDIT.md`, including all major visual systems, settings, quality tiers, dimension behavior, material handling, lighting, water, reflections, weather, clouds, atmosphere, and post-processing. Do not treat source-level placeholders, generic fallbacks, or a passing validator as feature completion.
2. **Reference-led implementation:** use both supplied archives for relevant work: Vanilla-stock establishes Minecraft 26.3 interfaces and stage behavior; Good working shader (Complementary Reimagined) establishes proven feature techniques, Ultra behavior, settings and visual targets. Inspect the actual relevant files before making feature-specific decisions. Preserve Intel HD 5500 viability through explicit quality/resource strategies, not by silently deleting Ultra features.
3. **Track actual feature coverage:** maintain the feature matrix/checkpoint as an implementation ledger. Distinguish implemented, partial, not implemented, and runtime-unverified. A feature is not complete merely because its source compiles or its tokens satisfy a validator.
4. **Batch static checks, don't let them drive the roadmap:** run structural/GLSL checks after coherent implementation batches or when a source change warrants them. Do not repeatedly spend cycles rerunning CI without meaningful feature work.
5. **Runtime phase later:** after the planned feature implementation is substantially complete, test the pack in Minecraft with Iris, then debug actual observed failures, rendering differences, pass ordering, attachment behavior, compatibility and performance. Do not claim runtime success before those tests occur.

### Immediate development directive
Resume implementation from current `main` HEAD. Prioritize the largest remaining Ultra feature gaps identified by the reference audit and feature matrix. Each development cycle should deliver real shader functionality and user-facing controls, not just validator changes or documentation. Update the checkpoint with concrete files/features changed and clearly label anything still partial or untested.

### Validation boundary
CI success means only that the checks in that workflow passed. It is not a substitute for feature completeness, Iris runtime behavior, visual comparison, or Intel HD 5500 performance testing. Keep these as separate evidence categories.


## Feature implementation cycle — depth of field — 2026-11-23

User priority remains feature completion before Iris runtime debugging. This cycle added a real final-pass depth-of-field path rather than more validation-only work:
- `shaders/final.fsh`: samples `depthtex0`, reconstructs positive view-space depth with Iris' `gbufferProjectionInverse`, calculates defocus from user focus distance/range, and performs an eight-direction bounded gather blur with bilateral depth weighting to reduce silhouette bleeding. Maximum blur radius is capped at six pixels.
- `shaders/shaders.properties`: exposes DOF strength, focus distance and focus range on the Quality screen and slider list. Profiles budget the effect: Ultra-Light 0, Smooth 15, Ultra 35, HDR 40, Ultra-HDR 45.
- `shaders/lang/en_us.lang`: adds labels and practical tooltips.
- `docs/REFERENCE_FEATURE_MATRIX.md`: moves DOF from pending to source-implemented/runtime-unverified.

This is a source implementation, not a claim of runtime correctness. It has not been tested in Minecraft/Iris. The next work remains feature implementation (temporal AA/motion handling, post/lens effects, expanded lighting/material parity and remaining reference systems); runtime debugging is deferred until the feature set is substantially complete. The uploaded archive contents were not available for fresh inspection during this cycle, so this DOF implementation is not claimed as a direct formula match to Complementary.


## Feature implementation cycle — lens/post effects — 2026-11-23

A second source feature batch followed the DOF work:
- `shaders/final.fsh`: added configurable radial chromatic aberration (edge-weighted red/blue channel separation), a smooth adjustable vignette, and animated monochrome film grain using Iris `noisetex` plus `frameCounter`.
- `shaders/shaders.properties`: added all three options to the Color menu and slider list; all five profiles receive explicit values. Ultra-Light disables them; higher profiles use restrained values.
- Vanilla vignette overlay is disabled so the Serene vignette control is authoritative and does not double-darken the corners.
- `shaders/lang/en_us.lang`: labels and tooltips added.
- `docs/REFERENCE_FEATURE_MATRIX.md`: lens/post effects moved from pending to source-implemented/runtime-unverified.

The two post-processing batches are source changes only. No Minecraft/Iris runtime or visual comparison was performed. The current archive inspection limitation remains; no direct Complementary parity claim is made for these effects. Continue feature work before runtime debugging.


## Feature implementation cycle — camera motion blur — 2026-11-23

Added a camera-motion blur path to `shaders/final.fsh` using Iris-documented `gbufferPreviousModelView`, `gbufferPreviousProjection`, `gbufferProjectionInverse`, `gbufferModelViewInverse`, `cameraPosition` and `previousCameraPosition`. Static world positions are reprojected into the previous camera, then the resulting screen-space vector drives a depth-rejected 4/6/8-tap gather. The Quality menu, slider list, English labels/tooltips and all five profile budgets were updated. Ultra-Light disables it; Smooth/Ultra/HDR/Ultra-HDR use progressively higher budgets.

**Scope limit:** this is camera-motion blur only. Independently moving entities/blocks do not have per-object velocity vectors in this implementation and are not claimed to receive correct object-motion blur. No runtime validation has occurred. Iris uniform names were checked against the current Iris documentation; this confirms the documented interfaces, not actual Minecraft rendering behavior.


## Profile option-value consistency correction — 2026-11-23

After adding the DOF and lens/motion controls, the profile values were reconciled against each option's declared Iris value list. DOF now uses only supported values (Ultra-Light 0, Smooth 20, Ultra/HDR 40, Ultra-HDR 50); chromatic aberration, vignette and film grain presets likewise use values present in their declared lists. This is a settings-integrity correction within the feature implementation batch, not a new validation cycle.


## Camera-motion blur pipeline refinement — 2026-11-23

The initial camera-motion blur prototype was moved out of `final.fsh` into a dedicated `composite5` pass so blur is applied to the scene before final FXAA, depth of field, bloom composition and color grading. Added `shaders/composite5.vsh` and `shaders/composite5.fsh`; the pass reads the completed composite scene and depth, reprojects through Iris previous-camera matrices, applies depth-aware 4/6/8-tap camera blur, and writes the resolved scene to colortex0 using the standard composite output flip. The final pass no longer owns motion-blur uniforms or code. This improves effect ordering and keeps the post stack modular. Still source-only and untested in Minecraft/Iris.


## Feature implementation cycle — POM, temporal stability, reflections, clouds and dimension fog — 2026-11-23

Continued feature-first implementation on `main` after the user reiterated that development should be completed before requesting a Minecraft test.

### Source changes delivered
- `shaders/gbuffers_terrain.fsh`, `gbuffers_block.fsh`, `gbuffers_entities.fsh`: added height-map slope normals blended into LabPBR/oldPBR tangent normals; added four-step tangent-space height-field self-shadowing that attenuates the direct-light sky factor. Entity-model support follows its opt-in POM strength.
- `shaders/shaders.properties`, `shaders/lang/en_us.lang`: exposed POM slope-normal and self-shadow strengths across all five profiles.
- `shaders/deferred.fsh`: added normal-edge-aware contact AO and a persistent RGBA16F history buffer (`colortex13`) with previous-camera reprojection, depth rejection and bounded history clamping. Added the `AO_TEMPORAL_STRENGTH` control.
- `shaders/composite.fsh`: added persistent RGBA16F temporal history for screen-space GI (`colortex12`), with previous-camera reprojection, depth rejection and clamped history. Added `SCREEN_GI_TEMPORAL_STRENGTH`.
- `shaders/composite.fsh`: added roughness-scaled, depth-rejected cross filtering for opaque SSR hits. Added `PBR_REFLECTION_BLUR_STRENGTH`.
- `shaders/gbuffers_skybasic.fsh`: added two-/three-step light-direction density sampling for volumetric cloud self-shadowing and a bounded multiple-scattering floor. Cloud self-shadow sample count scales with volumetric cloud quality.
- `shaders/composite.fsh`: added a separate low-altitude height-fog density profile for ceiling dimensions, preserving Iris' native dimension fog color.
- Updated `docs/REFERENCE_FEATURE_MATRIX.md` and `docs/SHADER_MENU_AND_PROFILES.md` to distinguish these source implementations from runtime-verified behavior.

### Current status boundary
These are source implementations only. No Minecraft 26.3 + Iris runtime, visual parity, performance or Intel HD 5500 test has been performed. Temporal GI/AO are temporal accumulation features, **not** full jittered TAA. Full TAA, texture filtering strategy, remaining reference-specific feature parity, and runtime calibration remain open.

### Reference archive availability
The supplied ZIPs exist in the conversation runtime, but data analysis became temporarily unavailable during the latest attempt to enumerate/read them. Do not claim that their contents have been audited or that these additions match Complementary formulas until their actual relevant files are inspected.

### Latest code checkpoint
Latest code HEAD before this checkpoint update: `26ccae859ea37b4619cad016c21009dc8ec6139c`. Continue feature implementation from current `main`; do not request user testing yet.


## Latest continuation — 2026-11-23 (lightning and volumetric cloud work)
- Added volumetric-cloud self-shadowing in `shaders/gbuffers_skybasic.fsh`: cloud density is now sampled along the celestial light direction with quality-scaled 1/2/3 sample counts, attenuating direct cloud lighting and adding a bounded multiple-scattering floor. Feature matrix updated.
- Added a shared `shaders/lib/lighting/lightning_flash.glsl` helper using Iris `lightningBoltPosition` (player-space bolt position; `w` indicates a visible bolt) and `thunderStrength`.
- Integrated localized, distance-attenuated lightning illumination into deferred opaque surfaces, translucent entities, translucent block entities and translucent particles. Added a restrained sky flash while a bolt is present.
- Iris uniform contract checked against the current Iris documentation: `thunderStrength` is a 0–1 thunderstorm strength and `lightningBoltPosition` is a player-space position with `w=1` while a bolt is present. This is source-level integration only; intensity/range and frame timing still need in-game calibration.
- Commits: cloud self-shadowing `e755e5c0002e72abf07d37a0930e62930674c52e`; localized lightning helper `24bda52f6cdcf62cfc79488dde835ca00631fd3f`; deferred integration `74f54180944e12a229983217272caca107d2a4e9`; entity translucent `88654e9e4d62fe6f46f763df909281584e8ac82d`; block translucent `5c899a4f0e577e15581a8720f0921b7701217fbb`; particle translucent `b9ff6e7628ed70983e6d81999aa7873312b035e2`; sky flash `b6fd36bd44ad5c8e97dd0054431e6ea6c7307c3d`; matrix `6f3f1c9a3bfd6220891272c8ce1c15182091e9b9`.
- Current next priority: continue closing the remaining feature-matrix gaps, with special focus on colored light propagation and translucent/material consistency. Do not switch to a validation-only loop; reserve full GLSL/Iris validation for the next meaningful implementation milestone.
- The supplied ZIP archives still require actual content inspection. Do not claim their feature code or stock interfaces were compared during this continuation.


## Coloured emissive bounce implementation — 2026-11-23
- The two supplied ZIP archives became available in the active runtime and were extracted for direct inspection. This is the first actual file-level comparison in this continuation; earlier notes correctly stated that archive contents had not yet been inspected.
- Vanilla-stock files inspected: `Vanilla-stock /core/lightmap.fsh`, `Vanilla-stock /include/light.glsl`, and `Vanilla-stock /include/sample_lightmap.glsl`. The stock lightmap contract builds coloured block light from `LightmapInfo.BlockLightTint`, sky light from `SkyLightColor`, and ambient/night-vision values from its UBO. Serene already samples the Iris lightmap RGB in terrain/entity/block G-buffers and carries that RGB into deferred lighting.
- Complementary Reimagined files inspected: `shaders/lib/colors/blocklightColors.glsl` and `shaders/lib/colors/lightAndAmbientColors.glsl`. The working reference has a broad material-ID-to-colour table for torches, fire, lava, portals, froglights, sea lanterns, soul fire, redstone, ores, candles, copper lights, entities and other emitters; its comments explicitly describe colour as affecting travel/dominance in its light propagation system. Its dimension-specific ambient/direct colours are separately defined.
- Serene cannot reproduce that floodfill by changing only the vanilla lightmap sample: the stock shader interface exposes the completed lightmap, not a world-neighbour voxel-light query. Instead, added a bounded screen-space emissive colour-bounce approximation in `shaders/deferred.fsh`: eight nearby G-buffer samples, emissive-channel gating, depth separation, reconstructed view-space distance attenuation, and normal compatibility. The source emitter's sampled albedo supplies the bounce colour. This deliberately does not claim world-space or off-screen propagation.
- Added `EMISSIVE_BOUNCE_STRENGTH` as a Quality menu control and profile budgets: Ultra-Light 0, Smooth 20, Ultra 45, HDR 55, Ultra-HDR 65. Updated the feature matrix to retain the explicit gap: no voxel floodfill, off-screen propagation or full per-block coloured transport.
- Commits: deferred implementation `eb95633bbededd0d13c74f43688598f870a1bffa`; profile/menu control `1aba36a43fed029dff20c04cea4545fb65ae650c`; feature matrix `6455a87ed54f4ccce2fbe0aa3d6d659596148b20`.
- Not yet GLSL-compiled or run in Iris after these changes. Screen-space colour bounce can miss off-screen emitters and may show view-dependent leakage; runtime scene tests and performance calibration remain necessary.


### Validation follow-up — 2026-11-23
- First CI attempt after emissive bounce failed during standalone GLSL compilation because `deferred.fsh` used Iris' `gbufferModelView` matrix without declaring it for the standalone compiler. Added the explicit uniform declaration; this is required by the pack's compile harness and matches the Iris matrix contract.
- The subsequent CI run compiled every standalone vertex/fragment stage, all configured Iris render-stage macro branches, LabPBR branches, opt-in entity POM, Unbound water detail, Ultra-Light reflection branches, the water normal alpha-height inspection and vertex/fragment program links successfully.
- Structural validation then failed on numerous stale exact-string assertions unrelated to the new shader compilation. Examples include expecting old `textureGrad(...)` calls where current code uses `sampleAnisotropicAtlas(...)`, an outdated deferred target declaration, old sky shader expressions and an outdated FXAA menu contract. One stale assertion also expected the block lightmap output before conduit logic using an exact string that no longer matches the current `skyLight * pomSelfShadow` output; that assertion was changed to match the current assignment prefix and ordering.
- The validator is not green yet. Its assertions need to be reconciled against current source semantics without weakening real coverage. Do not interpret this structural-validator failure as a GLSL compile failure: all GLSL compile/link stages passed in run `45226274621`, job `137873673354`.
- This is not an Iris/Minecraft runtime test.


### Lightning receiver coverage expansion — 2026-11-23
- Extended the existing Iris bolt-position flash to the dedicated translucent water/glass/ice/portal pass, the weather particle pass (rain/snow) and the first-person hand-water overlay.
- Weather vertex stage now passes player-space position to its fragment stage so lightning attenuation uses the same coordinate system as the Iris bolt position.
- These remain source-level integrations; exact visual intensity, lightning bolt visibility timing and overlay behavior require Iris runtime scenes.
- Commits: water `7fa22c0173cf22ae317c9bccf66a31c9fb9195c6`; weather vertex `645db20beea907eddb7a33c84f1406b1df19722e`; weather fragment `60a231cf40e0eb0787ea057a55f937d301df75b0`; hand-water `19b3d2a809a432a249352f4dabe19499b9aea368`; feature matrix `4f96a272724000172f2c5893b8fce3126ab4e553`.


- Added the same bounded lightning flash to the native `gbuffers_clouds` path (the pass used when volumetric clouds are disabled). The volumetric sky path retains its existing sky flash. Commit: `82e5ccac1c446f138cf85881a1bbb13b5d464db6`; matrix update: `6a1a885cda1b4caf0ffe4aebb76cf64e53f460e1`.


### Expanded vanilla emissive material coverage — 2026-11-23
- Compared the Complementary Reimagined `blocklightColors.glsl` material table and `block.properties` mappings against Serene's terrain material-ID dispatch. Added stable Iris IDs for sea pickles, all lit candle/candle-cake colours, charged respawn anchors, lit copper bulbs, amethyst buds/clusters and lit redstone/deepslate-redstone ores.
- Added corresponding terrain G-buffer emission fallback strengths. Sea-pickle fallback is gated by the vanilla block-light coordinate so dry sea pickles do not glow. Existing albedo supplies emitter hue to the screen-space emissive bounce.
- Removed the duplicate glow-lichen assignment from the waving-foliage ID; glow lichen keeps its dedicated emissive material ID instead of being overwritten by a second ID mapping.
- Commits: block mappings `8bc9cdd88ac137e50e1351fc9f1a1fe246eba685`; terrain emission fallbacks `654c37a45730637c4e37957fad9b96d59b04a263`; matrix `c36549dff70e42b59b7ae46c8d42f9ba21b718f6`.
- These are source-level material mappings; block-state parsing, colour/intensity and light-bounce appearance still require Iris runtime checks.


### Validation milestone — 2026-11-23 17:27 UTC
- The structural validator was brought back into agreement with the current shader architecture without dropping the checks: canonical root-level stages now take precedence over same-named dimension overrides; POM/PBR checks recognize the sprite-bounded anisotropic atlas sampler; lightmap checks accept the intended POM self-shadow multiplier; deferred/composite checks recognize the active temporal-history MRTs; FXAA is validated in the Antialiasing menu with actual profile values; screen-GI validation recognizes the temporally accumulated result.
- Fixed a genuine syntax error in the expanded vanilla emissive fallback chain: the lit-copper-bulb branch had a missing closing brace. This was introduced with the new material fallbacks and is now fixed.
- Resolved a duplicate block ID assignment for glow lichen: it retains its dedicated emissive material ID and is no longer included in the waving-foliage material list.
- CI run `45227697354` on commit `03d42ffb2d781af9b795c0f92203a1d7363a4e24` completed successfully. All stages passed: standalone GLSL compilation, Iris render-stage macro branches, LabPBR, entity POM, Unbound water-wave detail, Ultra-Light reflection branches, water-normal alpha-height inspection, vertex/fragment linking, and structural validation.
- This is source/compile/link validation only; it does not replace an actual Minecraft 26.3 + Iris runtime scene test.


### Block-entity rain puddles — 2026-11-23
- Extended the terrain puddle treatment to upward-facing opaque block-entity surfaces, including chest lids and shulker boxes. It reuses the same rain/biome gating, sky-exposure/lightmap mask, stable world-space three-noise breakup, tangent-space ripple normal, smoothness and albedo darkening.
- Signs, banners and portals are excluded; PBR porosity suppresses puddle formation on porous surfaces. The existing `RAIN_PUDDLE_STRENGTH` menu/profile control drives both terrain and block-entity puddles.
- Commit: `11b5810b65a55ee325fe7708526e294682e8206c`; feature matrix: `439126f6c8ec5cadbcedb4c1226cac9c10679084`.
- Source-level implementation only; verify chest/shulker top faces, modded block entities, rainfall, and performance in Iris.


### Latest compiler/validator checkpoint — 2026-11-23
- GitHub Actions run `45227697354` on commit `03d42ffb2d781af9b795c0f92203a1d7363a4e24` passed: every standalone shader stage compiled, all configured Iris/LabPBR/POM/water branches compiled, water alpha-height inspection passed, all vertex/fragment program links passed, and structural validation passed.
- The structural validator's last failures were stale exact-string checks expecting direct `textureGrad` calls. The source now uses the atlas-bounded `sampleAnisotropicAtlas` helper; validator assertions were updated to check the current bounded helper calls instead of obsolete source spellings.
- After that green run, block-entity puddles were added and separately validated at source level; `tools/validate_pack.py` now checks the shared puddle option, rain gating, surface normal/tangent ripple, world-stable noise and sign/banner/portal exclusions.
- Latest implementation commits after the green run: block-entity puddles `11b5810b65a55ee325fe7708526e294682e8206c`; matrix `439126f6c8ec5cadbcedb4c1226cac9c10679084`; checkpoint `6fdcdc07358d852e7d44cf639ae307ea191835ec`; puddle validator coverage `9edf2fbeb47970344ed8b660c2260b648f249958`.
- The new block-puddle code compiled and linked successfully in run `45228033759`; structural validation also passed. The latest validator-only extension has a new CI run pending.


### Expanded vanilla material emissive fallbacks — 2026-11-23
- Extended Complementary-guided vanilla material-ID fallbacks beyond the core light sources: lit furnace/smoker/blast furnace, lava cauldron, crying obsidian, magma block, dragon egg, chorus flower, brewing stand, redstone/lapis blocks (reusing their existing unique material IDs), iron/gold/copper/lapis/emerald/diamond/nether-quartz ores, gilded blackstone, ancient debris, active End portal frames, glow berries, powered redstone components and spawners.
- Added bounded, deliberately subtle emission levels for ores/minerals and circuit components; stronger fallback values remain for actual light sources. Existing albedo hue is used by the screen-space bounce. The new material IDs are also excluded from coated-texture fallback so emissive materials do not receive a competing surface coating.
- Block-state IDs were checked for duplicate assignments; no duplicates remain. Validator now requires representative mappings and the fallback ID range.
- Commits: block IDs `1c7613353cd32617e293c0805f8b99bf3ac7c0e7`, unique-ID reconciliation `2f2b13f11d1635e99974fac4708cd5eedae56e61`; terrain fallback `1d373238c07c254d8175f7f69301ab9c06d7dc01`, ID reuse correction `c08ada1742157e624f8508759032f0189e3ccbde`; validator `70a90826050256e1c6c242a34786aa0489ae0244` and `3de327beac2364714943c504ed04aaa721ce5cd0`; matrix `d2f37bd78f6e69e45dc1b947e48800a37f8fd111`.
- New block-state names and intensities require Minecraft 26.3 + Iris runtime verification; these remain fallback visual approximations, not world-space light floodfill.


### Extended vanilla block-emitter mapping follow-up — 2026-11-23
- Added Complementary-guided low-level terrain emission fallbacks for lit furnaces/smokers/blast furnaces, lava cauldrons, crying obsidian, magma blocks, dragon eggs, chorus flowers, brewing stands, ore/mineral accents, active End portal frames, glow-berry cave vines, powered redstone components and spawner cores.
- Redstone block and lapis block were removed from the new material-ID map after the structural validator identified duplicate assignments: both already have Serene material IDs for mineral treatment. Their optional Complementary emissive toggles are not forced on by default.
- Commits: added mapping `1c7613353cd32617e293c0805f8b99bf3ac7c0e7`; added terrain fallback dispatch `1d373238c07c254d8175f7f69301ab9c06d7dc01`; expanded coverage tests `70a90826050256e1c6c242a34786aa0489ae0244`; duplicate-ID correction commits `e3d3b1105221da9a91007df3bcc2b166f7bc5c61`, `eb2ee0774ed91afe8c249d5538dd974c80f85589`, `0fa9b1f91bb4a79cfe0a119ba81067388e7b33c6`; matrix `4985168a685bac0430cc49199a48fb07c8ab91fe`.
- GLSL compilation and program linking passed on the preceding extended-emitter commit; the structural failure was only duplicate block-ID assignment for redstone/lapis, now corrected. Latest correction is awaiting CI.


### Emissive fallback validation result — 2026-11-23 17:34 UTC
- The follow-up validator now checks the actual split ID ranges after preserving existing unique redstone/lapis IDs; it no longer assumes a continuous 32131–32152 range.
- CI run `45228817698` on `8d7f334e434de2475ee5767d4e7bd82fe02b13ce` completed successfully. All compile, macro-branch, LabPBR, entity-POM, Unbound water-detail, Ultra-Light reflection, water-normal inspection, link and structural validation stages passed.
- This confirms the expanded material fallback source compiles and the structural material-ID checks pass. It does not verify the new emission appearance in a live Minecraft world.


### Extended emitter map validation — 2026-11-23
- The extended vanilla emitter dispatch now covers unique mapped IDs `32131–32137` and `32140–32152`, plus the existing `10352`/`10608` mineral IDs where applicable. Duplicate redstone/lapis assignments were removed; their existing material IDs remain the sole source of identity.
- The latest full GitHub Actions validation passed on commit `8d7f334e434de2475ee5767d4e7bd82fe02b13ce`, run `45228817698`: all vertex/fragment stages, configured Iris/LabPBR/POM/water macro branches, alpha-height inspection, program links and structural validation succeeded.
- This confirms source compilation and structural consistency, not visual/runtime behavior in Minecraft/Iris.


### Reference color pipeline implementation — 2026-11-23
- Compared the supplied Complementary Reimagined `shaders/lib/program/composite5.glsl` and `lib/common.glsl` controls against Serene's final pass. The reference uses a Lottes 2016 tone mapper, linear-to-display transfer, dark-region readability lift, highlight-to-white path, dark desaturation and a separate BSL-style saturation/vibrance pass.
- Replaced Serene's previous simple HDR shoulder with a Lottes-based display transform. `HDR_LOOK` now selects 8/12/16 input highlight ceilings; existing exposure stops, contrast and RGB gains are preserved. Added user controls for `VIBRANCE`, `TM_WHITE_PATH` and `TM_DARK_DESATURATION`, exposed them in the Color menu and set consistent defaults in all five profiles.
- Added structural checks for the new functions, menu entries and profile values.
- Commits: final shader `d1b997dde7a618874f02be764ef545be2d62b1a9`; profile/menu `dda36dee664c33ca0965660df98e0baad01a1cbf`; validator `f830aac6ce58e529cc2dc01c56204e3117579c9d`; feature matrix `1c5dba35e3d83cadfbd4b4810ddba6cdca3a7e91`.
- Runtime color parity, gamma behavior and HDR display calibration remain unverified; the shader compiler/structural CI run is pending.


### Weather lighting integration — 2026-11-23
- Updated `shaders/gbuffers_weather.fsh` to preserve the vanilla RGB lightmap while adding a subtle solar-elevation-dependent sky tint and the shared animated cloud-shadow field. Cloud attenuation is gated by the interpolated sky-light coordinate so the block-light contribution is not fully suppressed by overhead clouds.
- The weather pass uses the same stable-world cloud-shadow helper and quality defines as terrain/forward translucent receivers; Iris fog, rain/snow opacity and lightning illumination remain in the existing forward path.
- Updated `docs/REFERENCE_FEATURE_MATRIX.md` and `tools/validate_pack.py` to record and assert the new weather path.
- Commits: shader `7f28b010eb9bdc1e707bf9b715898324edbc5505`; matrix `464938e2458e62842e61552e3dbf2c1466459502`; validator `09452035a21eabd9dcf27edd8d78532926eee57a`.
- The weather-specific change has not yet been confirmed by a completed CI run on a commit containing all three changes. The latest confirmed all-green validation remains run `45228817698` at `8d7f334e`; Minecraft/Iris runtime testing is still outstanding.


### Linear-light bloom and final color pipeline — 2026-11-23
- Corrected bloom thresholding: the main scene is display-encoded after deferred/composite, so the half-resolution bright pass now decodes its four-tap scene average to linear light before the soft-knee threshold. All subsequent bloom pyramid blur/downsample stages therefore operate on linear radiance.
- Updated the final pass to decode the scene once after FXAA/DOF/sharpening, add the linear bloom pyramid, then apply exposure and RGB white-balance gains before the Complementary-guided Lottes 2016 display transform and saturation/vibrance. The tone mapper performs the linear-to-display transfer itself; the additional gamma step is only the user-controlled display adjustment. Chromatic-aberration samples are decoded to the same linear domain before they are combined.
- Updated the bloom-threshold tooltip to specify linear-light units, the bloom-strength tooltip to describe all four scales, the feature matrix and structural checks. This avoids mixing gamma-encoded scene values with linear bloom energy and prevents double display encoding after the Lottes transform.
- Commits: bright-pass 5cd8cb4e283978ab2e882f815dedc65d80a20dbc; final linear pipeline efcac03a4694c5d26b94998e8d127b91b649ff4d; chromatic sampling 26b7e07e64584ea46732bd8ede9835c48671d5f0; language/validator 0fe1277b4b3101eb351127d3e630f6dc39820c1a, 06bfcc0f88d27c9f01a42ec1952aeca087b2ff38, 1192ba314f7fb50f16df9d7f5c551ed4b1e0a5a9, 745a54c7c17395440568f66ad57eb323c37fdc30, 91dcb1c8aae22805b9f41d5245224111f3712375, 244313bc6ae735cca17c70fcee3bec2aac072124, 60a0346017221bdcd0ce4f45c932793bcfbdbd4c.
- CI for this color-pipeline milestone is queued/running; no compile or runtime result is claimed yet.


### Linear-light color pipeline validation — 2026-11-23 17:38 UTC
- CI run 45229840172 on commit 2e53605a76aec0589c1e4e73fed8f06b091920b3 passed: all standalone shader compilation, Iris macro branches, LabPBR, entity POM, Unbound water detail, Ultra-Light reflection, water-normal inspection, program linking and structural validation stages completed successfully.
- A review of the Lottes display transform confirmed that it already performs linear-to-display conversion. The final gamma control was therefore corrected to apply only its optional user adjustment, avoiding a second 2.2 display encoding pass.
- This validates source compilation and the structural contract; it is not a Minecraft/Iris visual runtime result.


### Underwater camera distortion — 2026-11-23
- Implemented an animated screen-space underwater refraction effect in `shaders/final.fsh`. It combines two low-amplitude travelling wave fields with Iris `noisetex` modulation, clamps UVs to the active scene buffer, and only activates while `isEyeInWater == 1` (not lava or other fluids).
- The effect is applied consistently to the scene, FXAA, depth-of-field, sharpening, bloom and chromatic-aberration sampling coordinates, while vignette and film grain remain anchored to the physical screen coordinates.
- Added `UNDERWATER_DISTORTION` as a dedicated quality slider, localized label/tooltip, and profile values: Ultra-Light 20, Smooth 40, Ultra 60, HDR 70, Ultra-HDR 80.
- Updated `docs/REFERENCE_FEATURE_MATRIX.md` and `tools/validate_pack.py` to document and validate the implementation.
- Reference basis: Complementary Reimagined exposes an `UNDERWATER_DISTORTION` camera control; its water pass also uses a dedicated reflection/refraction/material path. Minecraft 26.3's stock archive exposes a dedicated water-mask pass and shared fog include; Serene retains Iris' native underwater state and fog path, adding only a post-process displacement rather than replacing stock water-mask semantics.
- Commits: shader `b81e1f2fef3a05d89be31fd955c32e6bee1142d6`; UI/profile `ee66e135ed46d77770a9824f348ba3f733cfa1bc`; language `ff1a97bd2a710df3498aac901364597d1f8c3313`; validator `a4447fe63e8e56f80d82ef74a8cec27b736a4fa3`, follow-up `f971ab9ffc0d0a7c99f357c80742d65dd4f7246b`; matrix `912782c892fbd17d873966637b36e91198100458`.
- Not yet confirmed by a completed CI run after this feature. In-game underwater visual testing remains pending.
