# Complementary Unbound — Water and Material Reference Audit

**Audit date:** 2026-11-23  
**Upstream source:** [ComplementaryDevelopment/ComplementaryReimagined](https://github.com/ComplementaryDevelopment/ComplementaryReimagined)  
**Pinned upstream revision:** `e10d27dec5acfb18509fdcc3cda704152dc2f7df` (r5.10)  
**Official style explanation:** [Complementary Shaders](https://www.complementary.dev/shaders/)

## 1. Revised reference hierarchy

This audit implements the user's updated direction. Complementary Unbound is now the primary visual/material reference for water and the broader material system. The references retain distinct responsibilities:

1. **Iris documentation — implementation contract.** Check every program, render order, uniform, attribute, buffer, blend state, alpha test, option and resource binding before writing or changing code.
2. **Minecraft Java 26.3 Vanilla-stock archive — native engine behavior.** Establish Minecraft's original vertex inputs, texture/lightmap behavior, fog, depth, translucent geometry and post-processing assumptions.
3. **Complementary Unbound — primary visual/material reference.** Use its Unbound water style and material handling as the feature/quality target.
4. **Supplied working Complementary Reimagined archive — proven implementation reference.** Retain it for line-by-line guidance on an already working Iris shaderpack and for cross-checking common implementation patterns. It is not discarded or treated as an inferior source.
5. **Serene Ultra — implementation source of truth.** Write original code for Iris and the Intel HD 5500 target. Do not copy upstream code/assets or redistribute them.

## 2. Important upstream clarification

Complementary Unbound is not a separate rendering codebase from Complementary Reimagined. The official site describes two visual-style presets within the same shader family: Unbound defaults to a more realistic/fantasy presentation; Reimagined defaults to preserving Minecraft's visual identity. The user can customize settings across either style.

The upstream language file confirms the water-style mapping:

- `WATER_STYLE_DEFINE=-1`: Set by Visual Style
- `WATER_STYLE_DEFINE=1`: Reimagined
- `WATER_STYLE_DEFINE=2`: Reimagined + Waves
- `WATER_STYLE_DEFINE=3`: Unbound

Therefore, the correct source audit is the official r5.10 codebase with the Unbound water branch (`WATER_STYLE == 3`) traced through its shared material and reflection helpers. The repo name containing “Reimagined” does not mean the Unbound implementation is absent.

## 3. Unbound water source map

| Upstream source | What it establishes |
|---|---|
| `shaders/program/gbuffers_water.glsl` | Full translucent-terrain program; water material dispatch, lighting, fog, reflection orchestration and buffer outputs |
| `shaders/lib/materials/specificMaterials/translucents/water.glsl` | Unbound water colour, normals, animated detail, depth opacity, foam, Fresnel and highlights |
| `shaders/lib/materials/materialHandling/translucentMaterials.glsl` | Routes water, glass, stained glass, portals and other translucent materials |
| `shaders/lib/materials/materialHandling/translucentIPBR.glsl` | PBR-aware handling for glass and other translucent materials |
| `shaders/lib/materials/materialMethods/refraction.glsl` | Noise-driven refraction with depth validation and rejection of invalid offsets |
| `shaders/lib/materials/materialMethods/reflections.glsl` | Screen-space ray-marched reflections, fallback reflection modes and world-space reflection integration |
| `shaders/lib/materials/materialMethods/reflectionBackground.glsl` | Sky/environment reflection contribution and optional sky effects |
| `shaders/lib/materials/materialMethods/worldSpaceRef.glsl` | World-space voxel reflection path and material-aware reflected lighting |
| `shaders/world0/gbuffers_water.vsh/.fsh` | Overworld-specific entry points and feature defines |

### 3.1 Unbound water feature behaviour

The `WATER_STYLE == 3` branch in `specificMaterials/translucents/water.glsl` establishes the following visual/technical targets:

- **Water appearance:** Unbound uses a deliberate water base colour treatment rather than simply preserving the vanilla texture's RGB.
- **Animated surface normals:** World-position-based water coordinates move with time/wind. The Unbound path samples multiple normal scales, combines their weighted detail and transforms the result through the water tangent basis.
- **Parallax/detail refinement:** Higher-quality water material paths refine sampling coordinates before evaluating normal detail.
- **Noise colour variation:** The water colour can receive low-cost animated noise modulation.
- **Depth-based opacity/absorption:** Opaque scene depth is reconstructed to estimate water thickness. The depth term controls water alpha/visibility, rather than using one fixed transparency everywhere.
- **Foam:** Surface water can receive foam based on the water surface orientation, height/depth relationship and noise threshold.
- **Fresnel and specular:** Grazing-angle response, high smoothness and normal-dependent highlights shape the water surface.
- **Underwater handling:** The underwater branch changes directional shading, reflectivity and water colour/alpha response rather than reusing the above-water formula unchanged.
- **Reflection hierarchy:** The reflection system supports screen-space ray marching, background/sky reflection and optional world-space reflections. The medium/high SSR path uses a substantially more refined search than Serene's current low-step baseline.

The shared reflection code documents a ray-marched path with 38 coarse samples and 10 refinement steps in its high-quality branch. This is a reference quality target, not a requirement to copy that expensive sample count literally. Serene must preserve the visible feature while using an appropriate adaptive/temporal/resolution strategy for Intel HD 5500.

### 3.2 Translucent material dispatch

The reference does not treat every translucent surface as water. Its material dispatch separates:

- Water and water cauldrons
- Glass and stained glass
- Nether portals
- Beacon beams
- Other special translucent materials

Material-specific alpha, Fresnel, smoothness, reflection and emission behaviour is applied after classification. Serene's `gbuffers_water` must therefore keep non-water translucent terrain on a safe generic forward path and must not apply water-only refraction/absorption to glass or portals.

## 4. Broader Unbound material-system reference map

| Upstream source | Feature family to audit and independently implement |
|---|---|
| `materialHandling/terrainMaterials.glsl` | Terrain material dispatch, foliage/subsurface treatment, material-specific emission and surface response |
| `materialHandling/terrainIPBR.glsl` | Integrated PBR terrain classification, smoothness/specular/emission/material masks |
| `materialHandling/entityIPBR.glsl` | Entity/item material classification and emissive/smoothness response |
| `materialHandling/deferredIPBR.glsl` | Deferred Fresnel/material-mask reflection handling |
| `materialHandling/customMaterials.glsl` | Resource-pack PBR maps, parallax, normal maps, emission and material masks |
| `materialMethods/pomEffects.glsl` | Parallax occlusion mapping, height traversal, parallax self-shadow and slope normals |
| `materialMethods/generatedNormals.glsl` | Generated normals derived from local albedo variation |
| `materialMethods/coatedTextures.glsl` | Noise-driven surface coating/texture variation |
| `specificMaterials/terrain/leaves.glsl` | Leaf-specific roughness, Fresnel and subsurface behaviour |
| `specificMaterials/translucents/glass.glsl` | Glass smoothness, Fresnel, opacity and reflection tuning |
| `specificMaterials/translucents/stainedGlass.glsl` | Stained-glass translucency and reflection treatment |
| `specificMaterials/translucents/netherPortal.glsl` | Portal emission and special visual treatment |

The upstream `en_US.lang` also identifies IntegratedPBR+, resource-pack PBR, normal-map strength, generated normals, coated textures, POM quality/depth, water style, foam, refraction, reflection quality and world-space reflections as separate controls. These are useful feature-inventory anchors; they must not be copied blindly into Serene's menu before the corresponding Iris-safe implementation exists.

## 5. Iris contract cross-check before implementation

The following current Iris documentation pages were consulted for the water pipeline:

- [gbuffers programs and translucent rendering](https://shaders.properties/current/reference/programs/gbuffers/)
- [program ordering and separateEntityDraws](https://shaders.properties/current/reference/shadersproperties/ordering/)
- [depthtex semantics](https://shaders.properties/current/reference/buffers/depthtex/)
- [rendering directives: alphaTest, blend, flip and size.buffer](https://shaders.properties/current/reference/shadersproperties/rendering/)
- [matrix uniforms](https://shaders.properties/current/reference/uniforms/matrices/)
- [rendering uniforms, including alphaTestRef and fog](https://shaders.properties/current/reference/uniforms/rendering/)
- [world and weather uniforms](https://shaders.properties/current/reference/uniforms/world/)
- [Iris feature flags](https://shaders.properties/current/reference/shadersproperties/flags/)

Key constraints applied to Serene:

- Iris routes translucent terrain (including water) through `gbuffers_water`, with `gbuffers_terrain` as its fallback.
- The deferred pass runs before the normal post-deferred translucent gbuffers. A `deferred1` composite-style pass can create a separate scene snapshot before those translucent programs execute.
- `depthtex1` excludes transparent geometry and first contains meaningful data in deferred. `depthtex2` excludes both transparent and hand geometry; `depthtex0` includes all geometry.
- Composite-style passes read the main buffer and write the alternate buffer, then flip by default. Gbuffers passes do not share that safe read/write model.
- A resized `colortex` buffer cannot be written by a gbuffers pass; it must be produced by a composite-style pass.
- Use Iris `alphaTestRef` and explicit per-program/per-buffer blend directives where appropriate.
- Never sample `colortex0` in `gbuffers_water` while writing `colortex0`. The separate `colortex4` snapshot is used for refraction/reflection instead.
- Water normal orientation must be validated in both view and player spaces; Iris' water geometry can require the same kind of normal-orientation workaround used by the upstream reference.

## 6. Serene Ultra status against the Unbound reference

### Implemented foundation

- Dedicated Iris `gbuffers_water` vertex/fragment program.
- Water-only classification using the Iris `mc_Entity` block ID and fluid-render-type fields.
- Generic forward lighting for non-water translucent terrain.
- Opaque-depth thickness reconstruction using `depthtex1`.
- Half-resolution opaque-scene snapshot in `colortex4`, produced by `deferred1` before translucent rendering.
- Depth-validity masking using `depthtex0` versus `depthtex2` so first-person hand/translucent pixels do not contaminate the scene copy.
- Screen-space refraction with depth rejection and scene-snapshot validity checks.
- Screen-space water reflection using full-resolution `depthtex2` and correctly scaled/clamped half-resolution `colortex4` coordinates.
- Fresnel-weighted reflection blending with a bounded user strength.
- Forward lightmap/celestial/shadow/fog treatment.
- View-space and player-space normal orientation correction; refraction depth is fetched at an exact clamped texel and reconstructed using that texel's centre UV.

### Still missing or incomplete relative to Unbound

- Animated multi-scale water normals and configurable wave speed/scale/bumpiness.
- Water noise-colour variation.
- Surface foam.
- Full Unbound water colour and underwater-specific response.
- Sky/environment reflection fallback when SSR misses, plus optional world-space reflections.
- More robust SSR refinement, edge handling, temporal stability and quality scaling.
- Full material dispatch for glass, stained glass, portal and other translucent surfaces.
- Broad IntegratedPBR+/resource-pack PBR material handling, including normal/roughness/smoothness maps, material masks and material-specific specular response.
- POM with parallax self-shadow, generated normals and coated-texture effects.
- Expanded terrain/entity material classification and material-specific emission/subsurface behaviour.

These are parity gaps, not approved omissions. Low-end optimisation must preserve each feature's visible contribution.

## 7. Implementation sequence

1. Complete the Iris water contract review and keep CI green before adding further effects.
2. Implement animated multi-scale water normals using Iris-supported texture/resource bindings and a bounded low-end sampling budget.
3. Add water noise colour, foam, above-/underwater response and Unbound-style water colour treatment.
4. Add sky/environment reflection fallback and improve SSR search/refinement with an adaptive quality strategy; investigate WSR only after its Iris prerequisites and hardware cost are understood.
5. Build a general translucent-material classifier and independently implement glass, stained glass, portal and beacon responses.
6. Expand terrain/entity PBR classification, emission, roughness/smoothness, normal maps, generated normals, coated textures and POM.
7. Validate each change against Iris documentation first, then compile, run structural checks, load in Iris/Minecraft 26.3, compare scenes against Unbound and measure on the target Intel HD 5500 system.

**Validation status:** Current water source and structural validator compile/link successfully in CI at the recorded checkpoint, but this is not Iris runtime proof, visual parity, or measured performance. Do not claim those until tested in-game.
