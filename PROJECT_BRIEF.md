# Serene Ultra — Living Project Brief

This is the authoritative cumulative requirements brief. Update it whenever the user provides new instructions. Preserve previous requirements unless the user explicitly changes them.

## Product goal
Create an original, full-featured Minecraft Java shaderpack for Iris. Use the supplied Good Working Shader as the visual and feature reference, with its Ultra profile as the principal parity target. Use the supplied **Vanilla-stock .zip as the actual stock Minecraft Java 26.3 shader source** for engine-behavior cross-checking—not merely as generic vanilla inspiration and not as a ready-made Iris shaderpack skeleton.

## Primary hardware target
- Intel Core i3-5005U
- Intel HD Graphics 5500
- 8 GB system RAM

## Non-negotiable visual requirement
The objective is to optimize the reference shader's Ultra experience for the target hardware, not to remove features to make a lightweight shader. Do not silently omit or visibly downgrade Ultra features. Preserve the feature set and optimize the algorithms, memory traffic, sampling, pass scheduling, culling, temporal reuse and reconstruction. Where a different implementation is needed for hardware compatibility, validate that its visible contribution remains comparable.

## Source-of-truth roles
- **Minecraft 26.3 Vanilla-stock archive:** authoritative baseline for stock shader behavior, vanilla shader interfaces, attributes, uniforms, texture/lightmap sampling, render-target formats, pass ordering, post-processing conventions, fog/lighting behavior and engine compatibility. Cross-check our implementation against it whenever changing or debugging a corresponding rendering path.
- **Good working shader archive:** visual/feature/menu reference, with its Ultra profile as the target feature inventory. Do not copy or redistribute its licensed source/assets.
- **Serene Ultra repository:** sole source of truth for our own implementation, decisions, code and checkpoints.

The Vanilla-stock archive contains 89 shader source files (42 fragment, 30 vertex and 17 GLSL include files) from the supplied Minecraft 26.3 stock source set. Treat those files as real source material to inspect and compare—not as optional reading. When useful, document exact vanilla file paths and the behavior/interface each one establishes.

## Reference audit and licensing
- Maintain a feature-by-feature audit of the reference, including Ultra profile values, programs, libraries, menu controls, dimensions and special rendering paths.
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
- Terrain and entity G-buffer passes capture base albedo, sampled vanilla lightmap RGB plus sky-light factor, and encoded player-aligned normals into colortex0, colortex1 and colortex2.
- The deferred pass reconstructs player-space position, computes a day/night celestial diffuse term, preserves vanilla lightmap color for ambient/block light, and applies four hardware-filtered shadow comparison taps with a slope-aware depth bias.
- The first-person hand and sky are passed through unchanged by deferred world lighting. The composite pass remains an identity copy.
- This is an early lighting implementation, not reference parity. Light balance, advanced colored light, AO, indirect light, shadow stability, dimension behavior, material classification and runtime validation remain required.
- Cross-check every affected path against the supplied Minecraft 26.3 stock shader source before treating its interfaces or behavior as correct. Do not infer vanilla behavior from memory when the actual stock source is available.
- Do not mark a rendering subsystem complete based only on structural source checks.

## Quality and engineering
- Target Minecraft Java 26.3 and a current Iris release; verify exact runtime compatibility.
- Keep a working shaderpack baseline and run structural checks on each change.
- Test actual Iris compilation/runtime, not just static structure.
- Compare fixed scenes against both the vanilla stock pipeline (for engine behavior) and the reference Ultra profile (for visual feature goals).
- Measure frame times and FPS on the target machine; never invent performance claims.
- Do not publish a release until it is a usable, validated shaderpack.

## User instruction continuity
Every new user instruction must be incorporated into this brief and the relevant implementation/docs. At the end of each work session, update this brief and the project checkpoint with completed work, in-progress work, validation status, blockers and next actions. The final response must summarize the current project state and retain the user's cumulative requirements.
