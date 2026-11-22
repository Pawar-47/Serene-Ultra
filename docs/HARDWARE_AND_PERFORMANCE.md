# Hardware and Performance Contract

## Primary target
- Intel Core i3-5005U (2 cores / 4 threads)
- Intel HD Graphics 5500 integrated GPU
- 8 GB system RAM shared with the GPU
- Minecraft Java 26.3 + current Iris build

## Visual contract
The target is the complete visual feature set of the supplied reference shader's Ultra profile. The project must not meet a performance target by silently disabling shadows, reflections, volumetrics, water effects, clouds, material detail, or post-processing.

## Optimisation priorities
1. Minimize memory bandwidth: avoid unnecessary full-resolution attachments, clears, copies and read/write passes.
2. Minimize texture bandwidth: reuse samples, use material masks, avoid redundant texture fetches.
3. Minimize ALU cost: share calculations and avoid repeating expensive transcendental functions.
4. Minimize overdraw: discard/cull only where correctness is preserved.
5. Use adaptive resolution for expensive intermediate effects, with edge-aware reconstruction and temporal stability.
6. Use temporal accumulation where motion rejection and history invalidation are correct.
7. Keep shader variants within the driver/compiler capabilities of the target.
8. Avoid requiring SSBO/image-load-store features when an equivalent compatible path can preserve the effect.
9. Keep a fallback for driver-sensitive features, but do not equate fallback with removing the feature.
10. Measure CPU frame time, GPU frame time where available, memory use and visual differences separately.

## Validation protocol
- Record Minecraft version, Iris version, graphics driver, OS, resolution, render distance, simulation distance, resource pack and world/scene.
- Capture identical scenes for reference Ultra and Serene Ultra.
- Test daytime, sunset, night, caves, dense foliage, water, rain, Nether, End, entities, particles and first-person hand.
- Report average FPS and 1% low only after repeatable measurements; distinguish CPU-bound from GPU-bound cases.
- Compare image differences and inspect temporal artifacts, shadow acne, banding, aliasing, ghosting, transparency ordering and shader reload stability.

## Non-goals
- Do not optimize by redefining Ultra.
- Do not claim a performance result based on GPU specifications alone.
- Do not mark runtime compatibility complete from source inspection alone.


## Shadow submission budget
The shader now sets Iris' `shadowDistanceRenderMul` to 1.0, enabling geometry culling outside the configured shadow distance instead of only scaling the shadow projection. This should reduce unnecessary shadow-pass work on low-end GPUs; measure actual frame-time benefit on the target Intel HD 5500 system.

## Emissive attachment format
`colortex3Format=R8` stores only the scalar emission strength. The deferred pass reuses colortex0 albedo as the emission tint, avoiding duplicated RGB. This cuts the attachment from RGBA8 to R8 (75% less per-pixel storage/bandwidth). Current discrete strengths are quantized with under 0.005 absolute error, which is negligible relative to the lighting calibration still required.