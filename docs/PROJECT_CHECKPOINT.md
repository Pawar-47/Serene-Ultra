# Project Checkpoint — 2026-11-23

## Repository
https://github.com/Pawar-47/Serene-Ultra

## Source archive clarification
The user confirmed that the supplied **Vanilla-stock .zip is the actual stock Minecraft Java 26.3 shader source** and is available for direct cross-checking. It is not just a generic reference pack. It contains 89 source files (42 fragment shaders, 30 vertex shaders and 17 GLSL includes). Treat it as the authoritative engine-baseline source for shader interfaces, attributes/uniforms, texture and lightmap behavior, render-target conventions, pass ordering, fog/lighting, post-processing and compatibility.

Use the two supplied archives for distinct purposes:
- Minecraft 26.3 Vanilla-stock: engine behavior and compatibility cross-check.
- Good working shader (Complementary Reimagined): Ultra visual/feature/menu reference; independently implement, do not copy its licensed code/assets.

## Completed in the preceding work session
- Implemented texture-aware alpha-tested shadow casters with a user-adjustable cutoff.
- Added terrain and entity G-buffer capture for albedo, sampled vanilla lightmap RGB, sky-light factor and encoded player-aligned normals.
- Added a deferred lighting pass with depth reconstruction, celestial diffuse lighting, slope-aware depth bias and four hardware-filtered shadow comparison taps.
- Preserved the game's sampled lightmap tint as the ambient/block-light foundation.
- Added explicit Iris render-target mappings and G-buffer data attachment blend rules.
- Expanded structural validation and updated the feature matrix, architecture document and living project brief.

## Current profile behavior
- Ultra-Light: 512 shadow map / 96-block shadow distance.
- Smooth: 1024 shadow map / 128-block shadow distance.
- Ultra: 2048 shadow map / 224-block shadow distance.
- HDR: Ultra shadow settings plus HDR-style tone mapping.
- Ultra-HDR: Ultra shadow settings plus stronger highlight compression.

These are preliminary profiles, not completed system-wide quality budgets. All required Ultra features remain planned; no feature should be silently removed from lower profiles.

## Validation status
- Latest known commit before this checkpoint update: 3126912381f1e5656e44c803544b8835c3d992cb.
- Structural CI for the latest lighting/lightmap commit has not been confirmed.
- Structural checks do not compile GLSL and cannot establish Iris runtime compatibility.
- No Minecraft/Iris runtime test, visual parity test or target-machine FPS measurement has been performed.
- Deferred lighting balance, lightmap interpretation and shadow bias require cross-checking against the actual Minecraft 26.3 stock shader files and in-game calibration.
- HDR and Ultra-HDR are tone-mapping looks, not verified true HDR display output.

## Next actions
1. Cross-check current G-buffer, hand, shadow, deferred and composite/final paths against the exact Minecraft 26.3 Vanilla-stock shader sources. Record the stock file paths, interfaces, data flow and any mismatches.
2. Correct our shader interfaces and behavior based on the stock source where required, while retaining Iris-specific requirements and the reference Ultra visual goal.
3. Continue with AO, advanced colored lighting, material classification and the remaining reference Ultra features.
4. Obtain real GLSL/Iris runtime validation and fixed-scene comparisons; do not present structural CI as runtime validation.
5. Keep this checkpoint and PROJECT_BRIEF.md updated. Do not publish an unverified release.
