# Supplied Ultra Reference — Source-Derived Audit

This audit is derived from the user's supplied `Good working shader.zip`, not from copied shader source. The pack identifies itself as Complementary Reimagined. Its license is not being imported into Serene Ultra; this document is a factual feature/configuration inventory only.

## Exact Ultra profile settings

The supplied `shaders/shaders.properties` defines this Ultra profile:

| Setting | Ultra value | Meaning to preserve |
|---|---:|---|
| `SHADOW_QUALITY` | 2 | High-quality shadow path |
| `shadowDistance` | 224.0 | Long shadow draw distance |
| `WATER_REFLECT_QUALITY` | 2 | Water reflection quality tier |
| `BLOCK_REFLECT_QUALITY` | 3 | Highest listed block-reflection tier |
| `LIGHTSHAFT_QUALI_DEFINE` | 2 | High light-shaft quality tier |
| `SSAO_QUALI_DEFINE` | 2 | SSAO quality tier |
| `FXAA_DEFINE` | 1 | FXAA enabled |
| `DETAIL_QUALITY` | 3 | Highest listed detail tier |
| `CLOUD_QUALITY` | 3 | Highest listed cloud tier |
| `ANISOTROPIC_FILTER` | 8 | 8x anisotropic filtering |
| `COLORED_LIGHTING` | 256 | Colored-light voxel volume tier |
| `WORLD_SPACE_REFLECTIONS` | 1 | World-space reflections enabled |
| `ENTITY_SHADOW` | 1 | Entity shadows enabled |
| `RAIN_PUDDLES` | 2 | Puddle system enabled at tier 2 |

This is the mandatory reference profile. Do not confuse the separate `COMPLEMENTARY` profile with `ULTRA`: COMPLEMENTARY raises shadow quality to 3, shadow distance to 256, light shafts to 3 and colored lighting to 512.

## Program inventory

The archive contains 37 distinct GLSL program names in the shared program definitions and/or dimension program trees:

```text
clrwl_gbuffers
clrwl_gbuffers_damagedblock
clrwl_gbuffers_translucent
clrwl_shadow
composite
composite1
composite3
composite4
composite5
composite6
composite7
deferred1
dh_terrain
dh_water
final
gbuffers_armor_glint
gbuffers_basic
gbuffers_beaconbeam
gbuffers_block
gbuffers_block_translucent
gbuffers_clouds
gbuffers_damagedblock
gbuffers_entities
gbuffers_entities_glowing
gbuffers_entities_translucent
gbuffers_hand
gbuffers_lightning
gbuffers_line
gbuffers_skybasic
gbuffers_skytextured
gbuffers_spidereyes
gbuffers_terrain
gbuffers_textured
gbuffers_water
gbuffers_weather
shadow
shadowcomp
```

Each of the three dimension folders `world0`, `world-1`, and `world1` contains 76 files, including dimension-specific copies/overrides of the render programs and Voxy/Distant Horizons integration points. Serene must cover the Overworld, Nether and End separately where their rendering behavior differs.

## Shared library inventory

The reference contains 166 files under `shaders/lib`. Major subsystems include:

- Antialiasing: FXAA, TAA and jitter.
- Atmosphere: sky, stars, End stars, aurora, nebulae, rainbows, Nether storms, clouds, volumetric light, End beams and fog.
- Color systems: sky, clouds, moon phase, ambient/direct light, block light and color multipliers.
- Lighting: GGX, shadow sampling, held lighting, smooth lighting, main lighting, minimum lighting and cloud shadows.
- Materials: terrain/entity/block-entity/translucent/IPBR handling, custom materials, deferred material passes and specific material handlers.
- Material methods: POM, refraction, reflections, world-space reflections, reflection blur, anisotropic filtering, generated normals, coated textures, connected glass, custom emission, waving blocks, snowy-world behavior and translucent tweaks.
- Voxelization: colored-light voxelization, puddle voxelization, reflection voxelization, voxel handling, player/block SSBO buffers and special handling for carpets, campfires, farmland, cutout faces and half blocks.
- Miscellaneous: pixelation, outlines, lens flare, distant-light bokeh, hand sway, light-level display and color-coded programs.
- Text rendering and user-facing diagnostics for unsupported/incorrect configurations.

## User-configurable Ultra controls discovered

The shader's settings screens expose additional controls beyond the 14 profile assignments. These must be included in the full feature inventory and not lost during implementation:

### Materials and surface detail
- POM depth, quality and distance; cutout POM; POM lighting mode.
- Normal-map strength, generated-normal multiplier and resolution.
- Coated textures and custom emission intensity.
- Anisotropic filtering.
- Specific-material behavior for stone, wood/planks, leaves, snow, ores/metals, candles, lava, coral, portals, glass, stained glass, beacon beams, signs, lightning, tridents and entity/item frames.

### Water, reflections and weather response
- Water style and caustic style; water color and underwater color.
- Water alpha, fog, refraction and refraction intensity.
- Vertex water waves, water bump scales, speed/size, noise coloring and foam.
- Water and block reflection quality.
- World-space reflection mode, player reflection and reflection quality controls.
- Rain puddles, puddle voxelization, rain/wetness and cloud shadows.
- Improved rain, rain texture opacity and special-biome weather.

### Lighting and shadows
- Shadow smoothing, shadow quality/distance, entity/player shadows and leaf-shadow optimization.
- SSAO and vanilla AO strengths.
- Ambient multiplier and cave lighting.
- Time/weather/dimension-specific light and atmosphere color multipliers.
- Blocklight intensity/curve, held-light mode and flickering.
- Colored dynamic lighting, colored-light saturation and colored-light fog.
- Pixelated shadows, blocklight, AO, cloud shadows and pixel scale.
- Moon-phase influence on light, atmosphere and reflections.

### Atmosphere, sky and clouds
- Cloud styles including Reimagined and Unbound variants; cloud altitude, speed, closed-area checks, shadows and colors.
- Sky/atmosphere color multipliers for morning, noon, night, rain, Nether and End.
- Fog distance, altitude, cave/border fog, atmospheric fog and colored-light fog.
- Light shafts with behavior and time/weather/water intensity controls.
- Sun/moon style, angle, horizon behavior and rain behavior.
- Night stars, nebulae, aurora, rainbows, End stars, End beams/flashes and Nether storms.

### Camera and post-processing
- Tonemapping exposure, contrast, saturation, vibrance, dark desaturation and white-path controls.
- Color grading matrix.
- Bloom enable/strength/smoothing.
- World blur and depth-of-field focus/intensity.
- Distant-light bokeh, vignette, image sharpening, underwater distortion, chromatic aberration, motion blur and lens flare.
- TAA, jitter, temporal smoothing/movement filtering, FXAA and their interaction.

### World, UI and utility effects
- Dimension-specific behavior for Overworld, Nether and End.
- Night-vision/potion/eye-brightness behavior, water overlays and weather.
- Connected-glass effect, portal-edge effect, outlines and selection outline.
- Show light levels, reduced close particles, less lava fog, snowy-world behavior, hand sway and glowing colored particles.
- Text-rendered diagnostics and compatibility warnings.
- Distant Horizons and Voxy integration points (optional compatibility, not a required baseline dependency).

## Render targets and special capabilities

The archive uses multiple color attachments, including `colortex0–8`, `colortex12–14`, and `colortex18–19`. It also declares custom noise/cloud-water textures, custom uniforms/variables, Iris optional features, SSBOs, image load/store resources and integer 3D image volumes for colored lighting and world-space reflections.

Ultra colored lighting uses a 256 × 128 × 256 voxel dimension in the profile's configuration path. World-space reflection resources and LOD volumes are also configured. These resource costs are important to the Intel HD 5500 redesign: the visible lighting/reflection contribution must be preserved through an alternative resource strategy if the original buffer approach is too costly or unsupported, not simply switched off.

## Inventory counts

- 446 files in the supplied archive (excluding macOS metadata).
- 437 files in its `shaders/` directory.
- 166 shared library files.
- 37 distinct GLSL program names.
- 76 files in each of `world0`, `world-1`, and `world1`.

## Implementation and verification policy

1. Convert every bullet and every Ultra profile value above into a tracked implementation/test item.
2. Mark a feature complete only when the Serene implementation exists and passes a visual test against the same reference scene.
3. If a feature needs a different algorithm for Intel HD 5500, document the substitute and demonstrate that the visible result remains acceptably close.
4. Keep all visual features available in the Ultra profile. Sampling/resolution/temporal quality may be adjusted only as explicit controls, not hidden feature removal.
5. Validate shader compilation and in-game behavior on the target machine before publishing a playable release.
