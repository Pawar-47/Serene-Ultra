# Serene Ultra

An independently implemented, full-featured Minecraft Java shaderpack targeting Iris, engineered for Intel HD Graphics 5500-class hardware without discarding the visual feature set of the supplied Ultra reference.

## Project status

Rendering foundation now includes terrain/entity/hand/particle G-buffers, emissive spider-eyes handling, dedicated forward water/weather/hand-water paths, alpha-tested shadow casters, dimension-aware deferred celestial lighting, Iris fog, contact AO, Iris settings/profiles, and CI GLSL compilation plus vertex/fragment linking. This is not yet Ultra parity or a runtime-validated release. Current priority is advanced water effects, wet-surface response, remaining special geometry, material systems and reference parity. See [the project checkpoint](docs/PROJECT_CHECKPOINT.md), [Iris pipeline audit](docs/IRIS_PIPELINE_AUDIT.md) and [reference feature matrix](docs/REFERENCE_FEATURE_MATRIX.md). Feature preservation is mandatory: performance work must optimize implementation cost rather than silently remove visual capabilities.

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

The `gbuffers_water` program handles all translucent terrain (including water and stained glass), so the current implementation is described as a generic forward-lit translucent-surface baseline rather than a complete water renderer.

Water material handling now distinguishes water/water-cauldron from other translucent terrain using Iris `mc_Entity` and `block.properties`, and applies depth-dependent opacity from `depthtex1`. Advanced water effects and runtime validation remain pending.

Water handling now uses Iris' documented `mc_Entity` ID/fluid fields, opaque-only `depthtex1` and inverse-projection reconstruction for thickness. The water alpha threshold follows Iris `alphaTestRef`; depth opacity follows the Complementary reference's exponential thickness model. Advanced water effects and in-game verification remain outstanding.

Special geometry now includes dedicated armor-glint, beacon-beam and lightning overlay programs with deferred-normal bypass masks. Their blend/depth behavior still requires in-game validation.


The water baseline now retains Complementary's `alphaTest.gbuffers_water=GREATER 0.0001`, uses Iris `alphaTestRef`, applies reference-style square-root alpha shaping, and fetches opaque depth with exact-pixel `texelFetch`.

Weather now includes reference-guided rain/snow opacity and optional wind motion, while vanilla clouds have a dedicated fogged forward pass that bypasses deferred terrain lighting. Custom volumetric clouds remain pending.

Dedicated Iris textured, sky-textured and sky-basic programs are now present. They preserve unlit texture overlays, distinguish sun/moon stages, and build a lightweight sky gradient with deferred-normal bypass. Full atmospheric scattering and custom cloud systems remain pending.

Dedicated Iris sky-basic, sky-textured and textured-fallback programs now handle sky/horizon/stars/void, sun/moon textures, and unlit textured geometry. Their render-stage macros and celestial uniforms were checked against Iris documentation, and their deferred-validity masks are protected from blending. CI compiles the conditional render-stage branches; visual calibration and runtime validation remain outstanding.

Line geometry now has a dedicated Iris program that keeps selection/debug outlines crisp, fogs ordinary lines and bypasses deferred terrain lighting.

Translucent particles now receive forward celestial lighting, vanilla lightmap response, Iris fog and a single hardware-filtered shadow lookup. Specialized emissive and smoke/water particle effects remain pending.


The separate entity-translucency feature remains disabled due to the current Iris compatibility warning. Forward shader pairs are retained but inactive; CI enforces the safe configuration.