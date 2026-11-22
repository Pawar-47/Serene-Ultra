# Serene Ultra

An independently implemented, full-featured Minecraft Java shaderpack targeting Iris, engineered for Intel HD Graphics 5500-class hardware without discarding the visual feature set of the supplied Ultra reference.

## Project status

Rendering foundation now includes terrain/entity/hand/particle G-buffers, an emissive spider-eyes path, a dedicated forward-lit water program, alpha-tested shadow casters, dimension-aware deferred celestial lighting, initial contact AO, Iris settings/profiles, and CI GLSL compilation plus vertex/fragment linking. This is not yet Ultra parity or a runtime-validated release. Current priority is weather and hand-water forward paths, advanced water effects, and remaining special-geometry coverage. See [the project checkpoint](docs/PROJECT_CHECKPOINT.md), [Iris pipeline audit](docs/IRIS_PIPELINE_AUDIT.md) and [reference feature matrix](docs/REFERENCE_FEATURE_MATRIX.md). Feature preservation is mandatory: performance work must optimize implementation cost rather than silently remove visual capabilities.

## Target hardware

- Intel Core i3-5005U
- Intel HD Graphics 5500
- 8 GB system RAM

## Compatibility target

Minecraft Java 26.3 with a current Iris release. Actual compatibility must be verified in-game; static shader compilation is not a substitute for runtime testing.

## Reference and licensing

The supplied working shader is used only as a visual/feature reference. Its source code and assets are not copied into this repository. Implementations here are original.

## Development principles

1. Preserve every Ultra-profile feature from the reference inventory.
2. Keep expensive features available; optimize sampling, pass scheduling, precision, culling, temporal reuse and resolution strategy.
3. Keep a working baseline at every milestone.
4. Record validation honestly; never claim FPS or visual parity without measurements.



Iris fog is now applied to deferred opaque surfaces and the dedicated forward water, weather and translucent-particle paths using the documented fog uniforms and modes. This remains source-level implementation pending in-game fog calibration.


Dedicated forward paths now exist for water, weather and first-person hand-water, replacing all three Iris fallbacks for the post-deferred translucent stage. These are baseline paths; advanced water effects and runtime/visual validation remain pending.