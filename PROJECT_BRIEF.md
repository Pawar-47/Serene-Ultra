# Serene Ultra — Living Project Brief

This is the authoritative cumulative requirements brief. Update it whenever the user provides new instructions. Preserve previous requirements unless the user explicitly changes them.

## Product goal
Create an original, full-featured Minecraft Java shaderpack for Iris. Use the supplied Good Working Shader as the visual and feature reference, with its Ultra profile as the principal parity target. Use the supplied Vanilla-stock archive as a reference for vanilla rendering behavior and assets, not as a ready-made Iris shaderpack skeleton.

## Primary hardware target
- Intel Core i3-5005U
- Intel HD Graphics 5500
- 8 GB system RAM

## Non-negotiable visual requirement
The objective is to optimize the reference shader's Ultra experience for the target hardware, not to remove features to make a lightweight shader. Do not silently omit or visibly downgrade Ultra features. Preserve the feature set and optimize the algorithms, memory traffic, sampling, pass scheduling, culling, temporal reuse and reconstruction. Where a different implementation is needed for hardware compatibility, validate that its visible contribution remains comparable.

## Reference audit and licensing
- Maintain a feature-by-feature audit of the supplied reference, including Ultra profile values, programs, libraries, menu controls, dimensions and special rendering paths.
- Do not copy or redistribute the reference shader's licensed source code or assets. Implement independently.
- Keep the exact reference archive's feature inventory and menu controls as traceable requirements.

## Profiles
Provide selectable profiles including Ultra-Light, Smooth, Ultra, HDR and Ultra-HDR. Profiles are presets for quality/performance budgets and output presentation. Lower-cost profiles must not achieve speed by silently deleting features. Ultra is the principal visual parity profile. HDR and Ultra-HDR are tone-mapping/presentation profiles unless actual HDR output support is separately implemented and verified.

## In-game shader settings
Provide a clean, multi-screen Iris settings menu with readable category names, meaningful labels, sliders/buttons and hover tooltips. Expand the menu as subsystems are implemented. Do not expose non-functional settings.

## Color controls
Provide independent red, green and blue channel adjustments, gamma, exposure, contrast, saturation and tone-mapping controls. Keep neutral defaults visually neutral. HDR-style output labels must not falsely claim true display HDR support.

## Rendering implementation status
- The shadow vertex stage forwards base texture coordinates and vertex alpha; the shadow fragment stage discards transparent texels using a user-adjustable alpha cutoff.
- Terrain and entity G-buffer passes capture base albedo, lightmap coordinates and encoded player-aligned normals into colortex0, colortex1 and colortex2.
- The first-person hand path remains color-only. The composite stage intentionally copies the scene unchanged until the deferred lighting model is ready.
- These are foundations, not full Ultra parity. Filtered shadow sampling, depth bias, direct-light integration, material classification and runtime validation remain required.
- Do not mark a rendering subsystem complete based only on structural source checks.

## Quality and engineering
- Target Minecraft Java 26.3 and a current Iris release; verify exact runtime compatibility.
- Keep a working shaderpack baseline and run structural checks on each change.
- Test actual Iris compilation/runtime, not just static structure.
- Compare fixed scenes against the reference and record visual differences.
- Measure frame times and FPS on the target machine; never invent performance claims.
- Do not publish a release until it is a usable, validated shaderpack.

## User instruction continuity
Every new user instruction must be incorporated into this brief and the relevant implementation/docs. At the end of each work session, update this brief and the project checkpoint with completed work, in-progress work, validation status, blockers and next actions. The final response must summarize the current project state and retain the user's cumulative requirements.
