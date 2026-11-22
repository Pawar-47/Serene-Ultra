# Project Checkpoint — 2026-11-22

## Repository
https://github.com/Pawar-47/Serene-Ultra

## Completed in this work session
- Verified the live main branch contains the cumulative project brief, checkpoint, profiles, color controls and structural CI.
- Implemented texture-aware alpha-tested shadow casters with a user-adjustable cutoff.
- Added terrain and entity G-buffer capture for albedo, lightmap UVs and encoded player-aligned normals.
- Added explicit Iris RENDERTARGETS mapping for terrain, entities, hand and composite passes.
- Added non-blended G-buffer data attachment settings for terrain and entity data buffers.
- Expanded structural validation to check the alpha-tested shadow path and required G-buffer attachments.
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
- The GitHub Actions run for the latest commit has not yet been confirmed.
- Structural checks do not compile GLSL and cannot establish Iris runtime compatibility.
- No Minecraft/Iris runtime test, visual parity test, or target-machine FPS measurement has been performed.
- HDR and Ultra-HDR are tone-mapping looks for current output, not verified true HDR display output.

## Still in progress
- Deferred lighting using the captured albedo, lightmap and normal data.
- Filtered shadow sampling, depth bias and direct-light integration.
- Material classification, translucent geometry and full material response.
- AO, block lighting, indirect/colored lighting and emissive response.
- Water, reflections, weather and puddles.
- Atmosphere, sky, clouds, fog and volumetrics.
- TAA/FXAA, bloom and remaining post effects.
- Dimension-specific behavior, vanilla compatibility and menu expansion for each implemented subsystem.
- Target-machine performance and runtime testing.

## Next actions
1. Confirm structural CI for the latest commit.
2. Implement depth reconstruction and shadow-aware directional lighting using Iris-documented uniforms and buffers.
3. Keep the identity composite until the deferred lighting result can be tested against the neutral baseline.
4. Do not publish a release until a usable shaderpack passes runtime validation.
