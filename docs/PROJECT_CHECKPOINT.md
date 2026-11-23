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
