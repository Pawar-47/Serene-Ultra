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

## Two-reference engineering rule (mandatory)
Both supplied shader archives are active technical references, not merely one engine reference plus one visual mood board. Consult both when designing, reviewing, debugging or validating a rendering feature. When uncertain whether an approach, formula, interface, shader stage, texture lookup, buffer, pass order or code path is correct, inspect the corresponding/relevant files in **both** archives, compare how each achieves or expects the behavior, and record the evidence before choosing an implementation. If the files are not directly equivalent, trace the related stages and shared inputs/outputs rather than forcing a one-file match. Use Vanilla-stock to establish Minecraft 26.3's native contracts and behavior; use the working shader to understand proven feature implementation, visual treatment, quality controls and Ultra expectations. Then write an original Serene Ultra implementation that respects the stock engine contract while pursuing the reference's visual contribution, adapted for Intel HD 5500 without dropping Ultra features. Do not blindly copy either source, and do not claim a comparison was performed unless the relevant files were actually inspected.

## Source-of-truth roles
- **Minecraft 26.3 Vanilla-stock archive:** authoritative baseline for stock shader behavior, vanilla shader interfaces, attributes, uniforms, texture/lightmap sampling, render-target formats, pass ordering, post-processing conventions, fog/lighting behavior and engine compatibility. Cross-check our implementation against it whenever changing or debugging a corresponding rendering path.
- **Good working shader archive:** technical and visual implementation reference for feature algorithms, shader-stage organization, material handling, effects, quality controls and Ultra behavior. Inspect its relevant source alongside the matching stock source whenever evaluating an approach. Do not copy or redistribute its licensed source/assets.
- **Serene Ultra repository:** sole source of truth for our own implementation, decisions, code and checkpoints.

The Vanilla-stock archive contains 89 shader source files (42 fragment shaders, 30 vertex shaders and 17 GLSL include files) from the supplied Minecraft 26.3 stock source set. Treat those files as real source material to inspect and compare—not as optional reading. When useful, document exact vanilla file paths and the behavior/interface each one establishes.

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
- Deferred reads the G-buffer and depth, reconstructs player-space position, computes a day/night celestial diffuse term, preserves vanilla lightmap color for ambient/block light, and applies four hardware-filtered shadow comparison taps with a slope-aware depth bias.
- Deferred writes lit output to colortex3; composite copies colortex3 to colortex0. Never sample and write the same color attachment in one pass.
- An initial eight-neighbor depth-based screen-space contact AO attenuates ambient light only. AO strength and radius are exposed in the Quality menu. This is an early approximation requiring edge, temporal, lighting and performance calibration.
- The first-person hand and sky are passed through unchanged by deferred world lighting.
- This is an early lighting implementation, not reference parity. Light balance, advanced colored light, AO refinement, indirect light, shadow stability, dimension behavior, material classification and runtime validation remain required.
- Cross-check every affected path against the supplied Minecraft 26.3 stock shader source before treating its interfaces or behavior as correct. Do not infer vanilla behavior from memory when the actual stock source is available.
- Do not mark a rendering subsystem complete based only on structural source checks.

## Quality and engineering
- Target Minecraft Java 26.3 and a current Iris release; verify exact runtime compatibility.
- Keep a working shaderpack baseline and run structural checks on each change.
- Compile every vertex/fragment stage with glslangValidator in CI; treat this as GLSL syntax validation, not proof of Iris runtime compatibility.
- Test actual Iris compilation/runtime, not just static structure.
- Compare fixed scenes against both the vanilla stock pipeline (for engine behavior) and the reference Ultra profile (for visual feature goals).
- Measure frame times and FPS on the target machine; never invent performance claims.
- Do not publish a release until it is a usable, validated shaderpack.

## User instruction continuity
Every new user instruction must be incorporated into this brief and the relevant implementation/docs. At the end of each work session, update this brief and the project checkpoint with completed work, in-progress work, validation status, blockers and next actions. The final response must summarize the current project state and retain the user's cumulative requirements.
