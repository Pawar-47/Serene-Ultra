# Project Checkpoint — 2026-11-22

## Repository
https://github.com/Pawar-47/Serene-Ultra

## Completed in this work session
- Verified the live `main` branch contains the living project brief, checkpoint, profile menu, color controls and structural CI workflow.
- Implemented a texture-aware shadow fragment path: samples the caster's base texture and discards transparent texels.
- Forwarded texture UVs and vertex alpha from the shadow vertex stage.
- Added the `SHADOW_ALPHA_CUTOFF` Iris option to the Quality screen with an explanatory tooltip.
- Added the alpha-test option to all five profiles without removing any planned feature.
- Expanded structural CI to check shadow varying agreement, texture sampling, alpha discard and menu exposure.
- Updated the reference feature matrix and living project brief to record the implementation and its limits.

## Current profile behavior
- Ultra-Light: 512 shadow map / 96-block shadow distance.
- Smooth: 1024 shadow map / 128-block shadow distance.
- Ultra: 2048 shadow map / 224-block shadow distance.
- HDR: Ultra shadow settings plus HDR-style tone mapping.
- Ultra-HDR: Ultra shadow settings plus stronger highlight compression.

All five profiles retain the planned full feature set. Lower-cost profiles currently change shadow-map resolution and distance; HDR profiles additionally change the output tone curve. These presets are not yet full-system quality budgets because the remaining systems are still being implemented.

## Validation status
- Source structure has been updated, but the new GitHub Actions run has not yet been inspected.
- Structural checks do not compile GLSL and cannot establish Iris runtime compatibility.
- No Minecraft/Iris runtime test, visual parity test, or target-machine FPS measurement has been performed.
- HDR and Ultra-HDR are tone-mapping looks for current output, not verified true HDR display output.

## Still in progress
- Full Ultra feature implementation and visual parity.
- Filtered shadow sampling, depth bias and direct-light integration.
- Material classification and complete terrain/entity/translucent pipeline.
- AO, block lighting, indirect/colored lighting and emissive response.
- Water, reflections, weather and puddles.
- Atmosphere, sky, clouds, fog and volumetrics.
- TAA/FXAA, bloom and remaining post effects.
- Dimension-specific behavior, vanilla compatibility and menu expansion for each implemented subsystem.
- Target-machine performance and runtime testing.

## Next actions
1. Inspect the new structural CI run and correct any failures.
2. Continue from shadow casters into depth-aware lighting and material-buffer design; avoid exposing options without an active implementation.
3. Expand the feature matrix and keep this checkpoint and `PROJECT_BRIEF.md` current.
4. Do not publish a release until a usable shaderpack passes runtime validation.
