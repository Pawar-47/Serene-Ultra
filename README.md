# Serene Ultra

An independently implemented, full-featured Minecraft Java shaderpack targeting Iris, engineered for Intel HD Graphics 5500-class hardware without discarding the visual feature set of the supplied Ultra reference.

## Project status

Repository initialized. The first implementation milestone is a complete reference-feature inventory and a runnable Iris shaderpack foundation. Feature preservation is mandatory: performance work must optimize implementation cost rather than silently remove visual capabilities.

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
