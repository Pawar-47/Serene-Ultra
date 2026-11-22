# Project Checkpoint — 2026-11-23

## Repository
https://github.com/Pawar-47/Serene-Ultra

## Source archive roles
- Minecraft 26.3 Vanilla-stock archive: authoritative stock engine shader source for interface and behavior cross-checking.
- Good working shader (Complementary Reimagined): Ultra visual/feature/menu reference; independently implement and do not copy licensed source/assets.
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
- Updated architecture, feature matrix, living project brief and checkpoint.

## Current profiles
- Ultra-Light: 512 shadow map / 96-block shadow distance.
- Smooth: 1024 shadow map / 128-block shadow distance.
- Ultra: 2048 shadow map / 224-block shadow distance.
- HDR: Ultra shadow settings plus HDR-style tone mapping.
- Ultra-HDR: Ultra shadow settings plus stronger highlight compression.

These remain preliminary. AO controls currently use the same defaults in all profiles; complete system-wide quality budgets are still in progress.

## Validation status
- Shader and menu changes are committed to main; documentation and validator commits are still being applied in this session.
- Structural validation has been expanded but has not yet been run by CI on the newest commit.
- No GLSL compiler or Minecraft/Iris runtime test has confirmed these passes.
- No visual parity comparison or target-machine performance measurement has been performed.
- The AO implementation is an initial screen-space approximation; depth bias, view-space reconstruction, camera stability, edge artifacts and GPU cost need calibration.
- The current stock shader archive has not yet been inspected file-by-file in this session, so do not treat vanilla interface cross-check as complete.

## Next actions
1. Finish and verify the validator and documentation commits for the deferred/composite attachment change and contact AO.
2. Run CI and inspect logs; correct structural failures.
3. Inspect the actual Minecraft 26.3 Vanilla-stock files for terrain, entities, hand, shadow, deferred/composite and final/post passes; document exact paths and reconcile interfaces.
4. Continue material classification, advanced colored light, AO refinement, translucency, water/reflections, atmosphere and the remaining Ultra features.
5. Do not publish a release until Iris runtime and visual validation are complete.
