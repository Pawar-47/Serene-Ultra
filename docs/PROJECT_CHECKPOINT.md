# Project Checkpoint — 2026-11-22

## Repository
https://github.com/Pawar-47/Serene-Ultra

## Completed in this work session
- Verified the live main branch contains the cumulative project brief, checkpoint, profiles, color controls and structural CI.
- Implemented texture-aware alpha-tested shadow casters with a user-adjustable cutoff.
- Added terrain and entity G-buffer capture for albedo, sampled vanilla lightmap RGB, sky-light factor and encoded player-aligned normals.
- Added a deferred lighting pass with depth reconstruction, celestial diffuse lighting, slope-aware depth bias and four hardware-filtered shadow comparison taps.
- Preserved the game's own lightmap tint as the ambient/block-light foundation instead of replacing it with a fixed grayscale approximation.
- Added explicit Iris RENDERTARGETS mappings and G-buffer data attachment blend rules.
- Expanded structural validation to check shadow alpha testing, G-buffer attachments, vanilla lightmap sampling and deferred lighting dependencies.
- Updated the feature matrix, architecture document and living project brief.

## Current profile behavior
- Ultra-Light: 512 shadow map / 96-block shadow distance.
- Smooth: 1024 shadow map / 128-block shadow distance.
- Ultra: 2048 shadow map / 224-block shadow distance.
- HDR: Ultra shadow settings plus HDR-style tone mapping.
- Ultra-HDR: Ultra shadow settings plus stronger highlight compression.

All five profiles retain the planned full feature set. Lower-cost profiles currently change shadow-map resolution and distance; HDR profiles additionally change the output tone curve. These are not yet full-system quality budgets because the remaining systems are still being implemented.

## Validation status
- Source changes are committed to main.
- Structural CI for the newest lighting/lightmap commit has not yet been confirmed.
- Structural checks do not compile GLSL and cannot establish Iris runtime compatibility.
- No Minecraft/Iris runtime test, visual parity test, or target-machine FPS measurement has been performed.
- The deferred lighting balance and shadow bias are initial values and require in-game calibration.
- HDR and Ultra-HDR are tone-mapping looks for current output, not verified true HDR display output.

## Still in progress
- Calibrate direct/ambient lighting and shadow bias against fixed reference scenes.
- Implement advanced colored light, AO, indirect illumination and material classification.
- Complete translucent materials, water, reflections, weather and puddles.
- Add atmosphere, sky, clouds, fog and volumetrics.
- Add TAA/FXAA, bloom and remaining post effects.
- Add dimension-specific behavior and complete vanilla compatibility.
- Target-machine performance and runtime testing.

## Next actions
1. Confirm structural CI and obtain GLSL/runtime validation.
2. Compare day, night, cave, foliage and entity scenes against the reference Ultra profile; tune light and shadow behavior.
3. Continue with AO, advanced colored lighting and material classification without dropping planned features.
4. Keep the project brief and checkpoint current; do not publish an unverified release.
