# Reference Ultra Feature Preservation Matrix

**Status:** Inventory baseline created; implementation and parity verification are pending.
**Rule:** Every feature found in the supplied Good Working Shader's Ultra profile must have an explicit disposition. "Optimized" does not mean removed. A feature may be marked complete only after code inspection and visual/runtime validation.

The supplied archive is a Complementary Reimagined shaderpack. Its source is not copied into Serene Ultra; this matrix records feature categories and the work required for an independent implementation.

| Feature family | Required Ultra capability | Serene implementation plan | Status |
|---|---|---|---|
| Terrain/material pipeline | Material-aware terrain rendering and material-specific behavior | Explicit material classification and shared material functions | Pending |
| Entity rendering | Entity-specific shading and shadows | Entity material path with alpha handling | Pending |
| Hand/item rendering | Correct first-person hand/item rendering | Dedicated hand pipeline and parity tests | Foundation |
| Shadow mapping | Sun/moon directional shadows | Depth map, cascade/clip strategy if needed, culling | Foundation |
| Shadow filtering | Soft filtered shadows and quality controls | Tunable PCF/rotated sampling with temporal stability | Pending |
| Ambient occlusion | Contact/local occlusion | Horizon/contact approximation with edge-aware filtering | Pending |
| Direct lighting | Directional lighting and block light response | Shared physically coherent lighting model | Pending |
| Colored lighting | Colored block/emissive light response | Efficient light sampling and material response | Pending |
| Indirect lighting / GI | Bounced/indirect illumination appearance | Screen-space/temporal approximation; preserve visual contribution | Pending |
| Volumetric lighting | Light shafts and volumetric scattering | Depth-aware low-resolution integration and reconstruction | Pending |
| Atmospheric scattering | Sky color, horizon and atmospheric depth | Analytic atmosphere with shared sky/lighting parameters | Pending |
| Fog | Distance, height and dimension-aware fog | Unified fog model with per-world tuning | Pending |
| Clouds | Procedural/cloud-layer appearance and lighting | Procedural cloud system with adaptive sampling | Pending |
| Water surface | Water tint, transparency, normals and lighting | Dedicated translucent/water material path | Pending |
| Water reflections | Reflected scene/sky and Fresnel response | Screen-space reflection plus fallback hierarchy | Pending |
| Block reflections | Reflective material response | Material masks and screen-space/fallback reflections | Pending |
| Rain/wetness | Rain response and wet surfaces | Weather/material masks and roughness response | Pending |
| Puddles | Rain puddles and surface reflections | Surface classification and puddle masks | Pending |
| Parallax/POM | Parallax occlusion material detail | Bounded ray steps and distance/material gating | Pending |
| Texture filtering | Texture quality and anisotropic behavior | Hardware filtering where supported; quality controls | Pending |
| TAA | Temporal anti-aliasing | Motion-aware history, rejection and sharpening controls | Pending |
| Other anti-aliasing | Additional AA modes/quality settings | Configurable AA path and edge validation | Pending |
| Bloom/emissive | Emissive contribution and glow/post effects | Thresholded multi-scale bloom with bandwidth-aware buffers | Pending |
| Color grading | Tonemapping, exposure, saturation and contrast | Reference-matched color pipeline | Pending |
| Depth of field | Focus/depth post-processing if present in Ultra | Depth-aware bounded blur | Pending |
| Motion blur | Motion-dependent post-processing if present | Velocity-aware path; avoid ghosting | Pending |
| Lens/post effects | Any enabled Ultra lens and post-processing effects | Individually inventoried and switchable | Pending |
| Text rendering | Correct text/UI treatment and compatibility | Preserve vanilla UI/text; no destructive post-processing | Pending |
| Weather | Rain/snow and weather-dependent material/lighting | Weather-aware material and atmosphere paths | Pending |
| Dimension support | Overworld, Nether, End and special dimensions | World-specific shader programs/configuration | Pending |
| Night vision/potions | Correct vanilla effect interactions | Explicit effect compatibility tests | Pending |
| Emissive entities/blocks | Correct emissive response | Emissive classification and lighting path | Pending |
| Translucent materials | Glass, foliage, water and particles | Ordered/appropriate translucent passes and alpha rules | Pending |
| Foliage | Alpha-tested leaves/grass and wind response if present | Alpha-aware shadows and material animation | Pending |
| Voxelization/SSBO-dependent effects | Reference's voxel/structured-buffer features | Determine visible Ultra contribution; implement a hardware-compatible alternative where needed | Pending |
| Profiles/settings | Full reference Ultra quality controls | Serene Ultra master profile plus scalable implementation controls | Pending |
| Iris compatibility | Shaderpack lifecycle and supported uniforms/programs | Current Iris 26.3 validation | Pending |

## Audit follow-up required

The initial archive inventory recorded:
- 446 files total, 437 under `shaders/`.
- Render-target usage across `colortex0–8`, `colortex12–14`, and `colortex18–19`.
- Dedicated world/dimension folders, material libraries, voxelization/SSBO code, antialiasing, atmospheric, lighting, reflection, text and utility modules.
- Quality profiles including POTATO through ULTRA and COMPLEMENTARY.

Next audit pass must extract the actual Ultra profile values and enumerate every program, define, material branch, render target, and post-processing stage. This matrix is intentionally conservative and must be expanded rather than treating its current rows as exhaustive.
