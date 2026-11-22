# Project Checkpoint — 2026-11-22

## Repository
https://github.com/Pawar-47/Serene-Ultra

## Completed in this work session
- Added Iris-native profile selector and organized Quality / Color menu screens.
- Added five presets: Ultra-Light, Smooth, Ultra, HDR and Ultra-HDR.
- Added independent red, green and blue channel gain controls.
- Added gamma, exposure, contrast and saturation controls.
- Added neutral, HDR-style and Ultra-HDR-style output tone mapping.
- Added English menu labels and hover tooltips.
- Added a living cumulative requirements brief at repository root.
- Expanded structural CI checks to guard profile names, menu screens and color controls.

## Current profile behavior
- Ultra-Light: 512 shadow map / 96-block shadow distance.
- Smooth: 1024 shadow map / 128-block shadow distance.
- Ultra: 2048 shadow map / 224-block shadow distance.
- HDR: Ultra shadow settings plus HDR-style tone mapping.
- Ultra-HDR: Ultra shadow settings plus stronger highlight compression.

All five profiles retain the planned full feature set. Lower-cost profiles currently change only shadow-map resolution and distance; further quality budgets will be connected as their rendering systems are implemented.

## Validation status
- Prior structural CI passed on commit `5fa4a229`.
- The current menu/profile/color changes have been committed; CI must run on the new head.
- No GLSL compiler or Minecraft/Iris runtime validation has yet been performed.
- No visual parity or FPS claim is made.
- HDR and Ultra-HDR are tone-mapping looks for current output, not verified true HDR display output.

## Still in progress
- Full Ultra feature implementation and visual parity.
- Material classification and complete terrain/entity/translucent pipeline.
- Directional shadows, filtering, AO, direct/indirect/colored lighting.
- Water, reflections, weather and puddles.
- Atmosphere, sky, clouds, fog and volumetrics.
- TAA/FXAA, bloom and remaining post effects.
- Dimension-specific behavior, vanilla compatibility and menu expansion for each implemented subsystem.
- Target-machine performance and runtime testing.

## Next actions
1. Verify the latest CI run and correct any failures.
2. Build out shadow and material pipelines while keeping the new menu options functional.
3. Expand settings screens only alongside real implementations.
4. Keep this checkpoint and `PROJECT_BRIEF.md` updated with every new user instruction and development milestone.
