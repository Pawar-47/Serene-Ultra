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
- Three-band analytic water-normal waves anchored to absolute player/world XZ coordinates, transformed into view space with Iris `gbufferModelView`; wave speed uses integer cycles per Iris `frameTimeCounter` hour to avoid phase jumps at the documented timer wrap.
- Unbound-style base water tint retaining biome influence, plus animated one-sample `noisetex` colour variation with a wrap-safe periodic drift.
- Shoreline/shallow-surface foam estimated from opaque depth reconstructed through Iris `depthtex1` and `gbufferProjectionInverse`, converted back to player space with `gbufferModelViewInverse`; foam is restricted to top-facing water and attenuates the SSR contribution.
- A distinct underwater camera branch based on Iris `isEyeInWater`: reduces water-surface opacity, applies a cool tint after the base water colour, suppresses directional celestial lighting, and lowers the SSR contribution.
- Fresnel-weighted reflection blending with a bounded user strength.
- Forward lightmap/celestial/shadow/fog treatment.
- View-space and player-space normal orientation correction; refraction depth is fetched at an exact clamped texel and reconstructed using that texel's centre UV.

### Still missing or incomplete relative to Unbound

- Water parallax refinement remains unavailable: the generated 64x64 custom texture is tangent-normal-only and has constant alpha, so it does not provide a verified height field. Visual calibration of the new multi-scale normal field remains pending.
- More advanced water noise-colour variation and per-biome colour calibration. Serene currently uses a single-sample low-amplitude tint variation.
- More complete foam shaping/calibration. Serene now has a first depth-intersection foam approximation, but does not yet match the reference's complete surface/foam logic.
- Full Unbound water colour and underwater-specific response. Serene now has a first-pass base tint/noise treatment and a distinct underwater branch, but needs colour/lighting calibration and the full absorption model.
- Richer sky/cloud/world-space reflection fallback. Serene now blends valid SSR hits with Iris skyColor/fogColor horizon fallback, but does not yet reproduce Unbound's full cloud/world-space reflection path.
- More robust SSR refinement, edge handling, temporal stability and quality scaling.
- Full material dispatch for glass, stained glass, portal and other translucent surfaces.
- Broad IntegratedPBR+/resource-pack PBR material handling, including normal/roughness/smoothness maps, material masks and material-specific specular response.
- POM with parallax self-shadow, generated normals and coated-texture effects.
- Expanded terrain/entity material classification and material-specific emission/subsurface behaviour.

These are parity gaps, not approved omissions. Low-end optimisation must preserve each feature's visible contribution.

## 7. Implementation sequence

1. Complete the Iris water contract review and keep CI green before adding further effects.
2. Completed: implement animated multi-scale water normals with an original tileable 64x64 tangent-normal texture, three baseline samples and one optional very-large octave. Water POM is intentionally deferred because alpha is constant and not a verified height channel.
3. Completed at source level: water noise colour, foam, above-/underwater response, Beer-Lambert absorption and Unbound-style base colour are implemented; calibration against in-game scenes remains.
4. Add sky/environment reflection fallback and improve SSR search/refinement with an adaptive quality strategy; investigate WSR only after its Iris prerequisites and hardware cost are understood.
5. Build a general translucent-material classifier and independently implement glass, stained glass, portal and beacon responses.
6. Expand terrain/entity PBR classification, emission, roughness/smoothness, normal maps, generated normals, coated textures and POM.
7. Validate each change against Iris documentation first, then compile, run structural checks, load in Iris/Minecraft 26.3, compare scenes against Unbound and measure on the target Intel HD 5500 system.

**Validation status:** CI #1092 passed all shader compile/link stages, the water-normal PNG decode/alpha inspection, and structural validation. This is source/asset validation only, not Iris runtime proof, visual parity, or measured performance. Do not claim those until tested in-game.


## Analytic water-wave milestone — 2026-11-23
Serene now has three animated analytic wave bands in `gbuffers_water.fsh`. The waves use absolute player/world coordinates (`vPlayerPosition + cameraPosition`) so the pattern remains stable as the camera moves. The perturbed normal is transformed with Iris `gbufferModelView` for Fresnel/refraction/SSR while the player-space normal is used for lighting and shadowing. `WATER_WAVE_STRENGTH` and `WATER_WAVE_SPEED` are exposed in the Quality menu. Speed is expressed as an integer number of complete cycles per 3600-second `frameTimeCounter` interval, avoiding a phase discontinuity when Iris' documented timer wraps. This is an original low-bandwidth approximation of Unbound's animated multi-scale normal map; texture-driven normals, parallax refinement and calibrated wave appearance remain outstanding.


## Unbound-style water colour update — 2026-11-23
The water pass now applies a dedicated Unbound-inspired base tint only to the water material ID, retaining alpha and blending behavior. The tint combines a stable blue base with a restrained biome vertex-colour contribution. A single Iris `noisetex` sample adds low-amplitude animated colour variation. The noise drift uses the same integer-cycle timer basis as the wave system so it does not jump when Iris' `frameTimeCounter` wraps. `WATER_COLOR_STRENGTH` and `WATER_NOISE_COLOR_STRENGTH` are exposed in the Quality menu. This is a first-pass colour treatment; underwater tint, absorption, foam, and reference visual calibration remain outstanding.


## Water foam milestone — 2026-11-23
The water pass now reconstructs the opaque scene position behind water using Iris `depthtex1` and `gbufferProjectionInverse`, transforms it to player space with `gbufferModelViewInverse`, and estimates the vertical intersection with the water surface. Foam is restricted to top-facing water near the top of the block, blended into the water albedo before lighting, and reduces SSR contribution in foamy pixels. `WATER_FOAM_STRENGTH` is exposed as a Quality-menu slider. This is a low-cost shoreline approximation; visual calibration, caustics and the full Unbound foam response remain outstanding.


### Foam calculation correction — 2026-11-23
The first implementation used a world-Y difference and a block-height gate. Source review showed this was not a robust shoreline signal: it could miss sloped shorelines and depended on the sign of the vertical offset. It was replaced with a shallow-water mask derived from the already reconstructed opaque-view thickness: `1.0 - smoothstep(0.035, 0.42, waterThickness)`, restricted to top-facing water. This avoids another texture sample and reuses the existing depth reconstruction. It remains a simple screen-space foam approximation; foam breakup, wave interaction and visual tuning against Unbound are still pending.


## Underwater water-surface response — 2026-11-23
The water pass now consumes Iris `isEyeInWater` (water state `1`) to select a separate underwater response. It softens water opacity, applies a cool surface tint after the Unbound-inspired base tint, removes direct celestial shading for water surfaces viewed underwater, and reduces the SSR contribution. `WATER_UNDERWATER_STRENGTH` is exposed as a Quality slider. This does not replace Minecraft's underwater fog and is not yet the full Unbound absorption/underwater colour model; validate with first-person underwater scenes.


## Glass and portal material dispatch — 2026-11-23
Added Iris `block.properties` IDs for clear glass, glass panes, all 16 stained-glass colours and panes, tinted glass, and nether portal. The dedicated `gbuffers_water` fragment stage now distinguishes these from water using the documented `mc_Entity.x` ID while retaining `mc_Entity.y` as the independent fluid discriminator. Clear/stained/tinted glass receive material-scaled Fresnel SSR using the existing opaque depth and half-resolution scene snapshot. Nether portal receives the Unbound-inspired warm nonlinear tint and self-emission, without atlas-crossing portal raymarch. The latter remains a deliberate feature gap; the full portal distortion/edge effect and glass-specific material/absorption response remain outstanding.


### Translucent ice dispatch — 2026-11-23
Added Iris ID `32004` for ice/frosted ice, matching the shared r5.10 material ID map. Ice now uses the shared Fresnel SSR path with its own reflection scale, separate from water absorption/refraction. This is a first-pass material response; ice-specific smoothness, thickness, tint and roughness calibration remain outstanding.


## Glossy opaque material milestone — 2026-11-23
The shared r5.10 material map identifies slime and honey blocks as special smooth materials. Serene now assigns them Iris `block.properties` IDs and packs a smoothness scalar into the existing G-buffer normal alpha, preserving the deferred-validity sentinel. Deferred uses that scalar for a sun/moon half-vector specular highlight, gated so ordinary surfaces do not pay the specular exponent cost. This is an original low-bandwidth first pass; full IPBR textures, per-material masks and the reference's full lighting response remain outstanding.


## Beer-Lambert water absorption — 2026-11-23
The water pass now applies depth-dependent absorption to the refracted opaque-scene sample. It computes per-channel transmission as `exp(-absorptionCoefficient * waterThickness)` and blends the transmitted scene with the current water tint. Red attenuates faster than green, and green faster than blue, producing stronger blue tint with depth. The calculation is performed in linear colour space after the validated refraction sample and before the final refraction blend. `WATER_ABSORPTION_STRENGTH` is exposed in the Quality menu. This is a physically motivated first-pass approximation; coefficients and appearance still need in-game comparison against Unbound.


## Atlas-safe portal distortion — 2026-11-23
The portal material now uses Iris' documented `mc_midTexCoord` per-quad UV center. The water vertex stage forwards the transformed midpoint and per-quad half extents; the fragment stage clamps each of four animated portal texture taps to the current sprite bounds plus a one-texel inset. This prevents adjacent atlas tiles from bleeding into the distortion. Portal emission is calculated from the pre-tint texture signal, then the colour is given the nonlinear warm tint. This is a four-tap low-cost approximation, not the full Unbound eight-step portal raymarch/edge effect.


The analytic wave approximation now also exposes `WATER_WAVE_SCALE`, allowing spatial frequency to be tuned independently of strength and animation speed. This is a procedural substitute for the reference's multi-scale normal-map size controls.


## Colored translucent shadows and water caustics — 2026-11-23
Serene now follows Iris' transparent-shadow contract using `shadowtex0`, `shadowtex1` and `shadowcolor0`. The shadow pass stores material-specific transmission: animated analytic water caustics, neutral clear-glass transmission, stained-glass tint, darker tinted-glass transmission, blue ice tint and purple portal tint. Deferred combines the RGB transmission with four-tap opaque PCF. This mirrors the reference's colored-shadow/material behavior at a lower sample count and with original analytic caustic math; it is not a line-for-line reproduction of Unbound's water-normal caustic projection. Runtime validation and HD 5500 performance calibration remain outstanding.


## Water cauldron material dispatch — 2026-11-23
Added the shared r5.10 `block.10049` mapping for filled water cauldrons and remapped it to material ID `32001` in both water and shadow vertex stages, matching the reference's cauldron-water classification. ID 32001 now receives the same depth/refraction/absorption/foam/underwater water surface path and caustic shadow transmission as water, without relying on the normal fluid-render-type flag. Empty cauldrons are not mapped.


## oldPBR/LabPBR terrain material decode — 2026-11-23
Serene now uses Iris' `specular` atlas in `gbuffers_terrain`, `gbuffers_entities` and `gbuffers_block`. Smoothness is read from red for both formats. The LabPBR branch stores green as a normalized raw code; deferred uses the raw normalized value `code / 255.0` as dielectric F0 for codes 0–229 (code 229 is approximately 0.90) with 230–254 predefined metal IDs and 255 selecting albedo as F0. Serene currently treats the whole 230–255 range as albedo-tinted metal, while alpha is emissive with 255 treated as no emission. The oldPBR branch decodes green as metalness and blue as emissive. Material reflectance is packed into colortex3.g, emission in .r, material AO in .b and LabPBR porosity/SSS data in .a, so the material target is RGBA8. Terrain, entities and block entities also decode Iris `normals` atlas maps through their `at_tangent` basis. Deferred derives dielectric F0 or albedo-coloured metallic F0 and applies it to the smoothness-gated specular lobe. This is a compact first-pass PBR implementation; distinct LabPBR metal-ID reflectance presets, full Unbound IPBR handling, entity/block-entity wetness and runtime visual calibration remain outstanding; terrain porosity-driven darkening/reflectance loss and puddle suppression are implemented. SSS and tangent-space normal maps are implemented as approximations.


## LabPBR reserved metal-channel correction — 2026-11-23

The shaderLABS LabPBR 1.3 specification reserves specular-blue values for porosity (0–64) and subsurface scattering (65–255) on non-metal materials; metal IDs (green 230–255) do not use that blue-channel payload. Deferred already correctly converts non-metal SSS codes with `(code - 65) / 190`. Terrain already clears the blue-channel payload for metal IDs. The opaque entity and block-entity G-buffers now do the same before packing `colortex3.a`, preventing arbitrary/reserved metal blue values from creating false subsurface backlighting. The structural validator now guards both paths. This is a channel-validity correction, not a change to the existing SSS remap.


## Unbound style-3 water parity correction — 2026-11-23
- Compared the supplied working shader archive's `shaders/lib/materials/specificMaterials/translucents/water.glsl`; its `WATER_STYLE == 3` branch is the Unbound implementation.
- Unbound style 3 prepares the biome/vertex tint with square-root colour and the multiplier `(1.0, 0.85, 0.8)`, then applies a `0.375` base multiplier. Serene previously mixed that tint 50/50 with the fixed Reimagined blue tint. The fixed tint has been removed from the Unbound path; `WATER_COLOR_STRENGTH` still controls blending with the atlas colour.
- Unbound style 3 sets above-water surface alpha to `0.98`, then applies depth opacity and Fresnel. Underwater it applies a separate `0.75` alpha reduction. Serene previously used the Reimagined-style square-root of sampled atlas alpha. The water pass now follows the Unbound branch.
- Cross-checked Minecraft 26.3 Vanilla-stock `core/terrain.fsh` (sampled atlas colour multiplied by vertex colour, then fog while preserving alpha), `core/terrain.vsh` (vertex colour multiplied by vanilla lightmap), and `include/fog.glsl` (fog affects RGB while preserving alpha). Those native inputs remain intact; the Unbound surface-alpha treatment is isolated to Iris' water program.
- Added validator assertions for the Unbound base tint and above-/underwater alpha branches.
- This is a source-parity correction, not a runtime-verified visual claim. Validate above-water, underwater, shore and transparent-boundary scenes in Iris.


## Bounded water SSR hit refinement — 2026-11-23
- Compared Serene's water SSR with Complementary Unbound's shared reflection method. Unbound's high-quality path uses a substantially larger coarse ray budget and a refinement phase; copying that sample count would be inappropriate for Intel HD 5500.
- Added a positive-to-negative view-space depth-crossing test to the water SSR ray marcher. A bracketed opaque hit receives exactly two binary refinement steps; the existing 4/6/8 coarse quality presets and 24-block maximum ray distance remain unchanged.
- Sky fallback, screen-edge fade, distance fade, invalid snapshot alpha rejection and the conservative first-sample-inside-geometry path are preserved.
- Extended structural validation to require the bounded two-step refinement loop.
- The extra depth/colour reads occur only after a candidate hit, rather than for every ray step. This is a source-level bounded-cost improvement; actual GPU cost, temporal stability and visual hit quality still require Iris runtime testing.


## Terrain POM first implementation — 2026-11-23
- Compared the supplied working shader's pomEffects.glsl and customMaterials.glsl against the Iris pipeline. The reference uses the normal atlas alpha height, tangent-space view direction, per-quad UV bounds and gradient-based atlas sampling; its 128+ default sample budget is not suitable for the low-end target.
- Implemented a bounded terrain-only POM path using 4/6/8 compile-time samples, a 32-block default fade distance, capped UV offset and a linear hit interpolation. POM reads the alpha height channel from either LabPBR or oldPBR normal maps and stays neutral on the Iris flat-normal fallback (alpha near 1).
- Iris mc_midTexCoord (vec2) is used to derive each quad's atlas rectangle. Every height lookup wraps within that sprite and clamps to a half-texel inset. at_tangent and its handedness produce the tangent-space view vector.
- Albedo, normal and specular atlases are sampled at the displaced UV. If the displaced albedo lookup would cross into a transparent texel, the original UV is retained to protect cutout silhouettes. The first pass is terrain only; block entities, self-shadowing and slope-normal reconstruction are not yet enabled.
- Ultra-Light disables POM. Smooth uses 4 steps and a shorter fade; Ultra/HDR use 6. These are quality presets, not proof of a performance gain on the target GPU.
- CI run #1050 (45108422197) passed all nine stages on commit 3d68fdf. This validates GLSL syntax, Iris macro branches, LabPBR compilation/linking and structural checks only. Runtime checks with real PBR resource packs and Minecraft 26.3 + Iris remain outstanding.


## Block-entity POM coverage — 2026-11-23
- Extended the same bounded sprite-safe POM path to Iris gbuffers_block (block entities), reusing the same LabPBR/oldPBR normals.a height convention, 4/6/8 steps, fade distance, displacement cap and cutout-alpha fallback.
- Block-entity vertex data now forwards mc_midTexCoord sprite bounds and tangent-space view direction from at_tangent. The displaced UV is used consistently for albedo, normal and specular maps.
- Sign text and Nether portal surfaces are explicitly excluded. The ordinary sign wood texture and other block-entity materials may use POM when their height atlas contains non-neutral data.
- POM remains terrain + block-entity only; entity models, self-shadowing, slope-normal reconstruction and runtime/target-GPU calibration remain outstanding.


## POM terrain + block-entity validation — 2026-11-23
- CI run #1054 (45108839328) passed all nine stages on commit fe4a10a after removing a duplicated interface block introduced during the block-entity extension.
- Both terrain and block-entity programs compile and link with the same Iris mc_midTexCoord/at_tangent POM varyings. Structural validation confirms atlas bounds, bounded sampling, cutout fallback, and sign-text/portal exclusions.
- Tuned the depth control mapping to give the low-end 20/35 presets a more visible displacement while retaining a 0.20 UV-offset cap and 4/6/8 sample limit. This is a source-level calibration only; real resource-pack appearance and Intel HD 5500 cost still need runtime checks.
- POM remains unavailable for generic entity models and held items; their stable per-object exclusions are not yet mapped in this pack. Self-shadowing and slope-normal reconstruction also remain pending.


## Generated normals + coated textures validation — 2026-11-23
- Terrain and block entities now have four-tap albedo-gradient generated normals, gated by screen-space albedo contrast and skipped when explicit normal-map XY detail is present. Cutout/partial-alpha neighbour samples reject generated-normal synthesis.
- Terrain and block entities also have optional stable noise coating. Noise is keyed by sprite-atlas centre and floored world-cell position, then attenuated for bright materials and distant/mipmapped surfaces.
- Run #1058 (45109244596) passed all nine stages for generated normals. Run #1060 (45109448675) passed all nine stages for coated textures and the corrected uniform declarations.
- Source-level validation only: visual material response, atlas seams, oldPBR/LabPBR pack compatibility and Intel HD 5500 GPU cost still require Minecraft 26.3 + Iris runtime testing.
- Remaining reference gaps include generic entity/held-item POM, POM self-shadowing, slope-normal reconstruction and runtime calibration.


## Entity-model POM extension — 2026-11-23
- Added opt-in LabPBR/oldPBR height mapping to the opaque entity G-buffer. The entity vertex stage now forwards Iris mc_midTexCoord atlas bounds and at_tangent-derived view direction.
- Entity POM uses the same bounded 4/6/8-step intersection, 32-block maximum fade, 0.20 UV displacement cap and cutout-alpha fallback as terrain/block entities. Item frames and glow item frames are excluded through explicit entity.properties mappings (50128 and 50132).
- POM_ENTITY_STRENGTH defaults to 0 and is disabled in Ultra-Light/Smooth; Ultra/HDR opt in at 20 to protect low-end performance. Generic translucent entities and held items are not covered.
- CI #1065 (45110274115) compiled and linked all shader variants but failed structural validation because the validator still expected pre-POM implicit normal/specular sampling and the old normal-function signature. The source compiled; the validator has now been updated to recognise explicit textureGrad sampling and entity POM exclusions. Re-run CI before marking this extension validated.


- Iris option compatibility: POM_QUALITY and POM_DISTANCE are shared options across terrain, block and entity shaders and must have identical definitions in each file. The entity shader's option comment/value declaration is aligned with the terrain/block definitions and guarded by a validator regression check.


## Entity-model generated normals + coated textures — 2026-11-23
- Extended the optional generated-normal and coated-texture paths to opaque entity models. The entity G-buffer now forwards player-relative position for stable world-cell noise and reuses mc_midTexCoord sprite bounds and the at_tangent basis.
- Generated normals run only when no explicit normal-map XY detail exists, on opaque texels with visible albedo contrast. Coated texture noise skips item frames/glow item frames, transparent texels, emissive materials and high-F0/high-smoothness surfaces.
- POM_ENTITY_STRENGTH remains separately opt-in; entity POM is disabled in Ultra-Light/Smooth and enabled only in Ultra/HDR. Generic translucent entities and held items remain outside this pass.
- This extends source coverage; runtime resource-pack compatibility, entity-specific visual checks and GPU cost remain unverified.


## Entity material-feature coverage + CI expansion — 2026-11-23
- Run #1068 (45110765737) passed all nine stages after generated normals and coated textures were extended to opaque entity models. Entity item frames/glow item frames are explicitly excluded.
- Added a dedicated CI step that compiles and links the opt-in entity POM branch twice: oldPBR and LabPBR, both with POM_ENTITY_STRENGTH forced to 20. The default entity profile remains POM-off to protect low-end GPUs; this test ensures the optional code path cannot silently rot.
- Structural validation now requires the CI opt-in POM variants. This is a test-coverage improvement, not a runtime visual verification.


## Unbound water octave and phase continuity — 2026-11-23
- The 0.05 very-large normal octave is optional and adds one sample only in higher quality profiles. The three-scale baseline remains unchanged for low-cost profiles.
- Stable water coordinates use a 2560-block period; every configured wave-scale preset yields integer repeats across the 1.0, 4.0, 0.25 and 0.05 octaves. Wind multipliers are checked against all configured speed presets to prevent a visible jump at Iris' 3600-second timer wrap.
- Water parallax is not enabled because the custom normal texture's alpha height encoding has not yet been verified. This avoids silently sampling an undefined height channel.


## Low-end and high-quality profile calibration — 2026-11-23
- Rebalanced Ultra-Light and Smooth presets across water, reflections, material specular/SSS/AO, glass and portal effects. Ultra-Light keeps features available but lowers sample counts/strengths; it uses 4-step water/opaque SSR, 25% wave/foam/caustics, reduced refraction/reflection, and disables POM/generated normals/coating. Smooth uses intermediate strengths and 6-step water SSR.
- Ultra/HDR retain higher-quality water and material settings and enable the optional fourth very-large water-normal scale. WATER_WAVE_DETAIL is a checkbox with an explicit one-extra-texture-sample tooltip.
- Water caustics are implemented in the shadow pass through WATER_CAUSTICS_STRENGTH/SCALE and translucent shadow-colour output; these profile values tune that existing path.
- This is preset-level performance intent, not measured FPS. Target-device profiling on Intel HD 5500 remains required.


## Block-entity material-dispatch refinements — 2026-11-23
- Reference factors are now applied per block entity rather than uniformly: chest/ender chest 0.66, shulker/head/bed 0.2, bell gold 0.33, bell stone 0.77, copper 0.5, banner 0.2. Explicit PBR specular maps keep priority.
- Conduit output order matters: update vanillaLight first, then write outLightmapData. Preserve reference emission response at albedo.r * 16 for blue/wind pixels and 20.0 for red-eye pixels. Bell gold smoothness uses color.g squared; stone uses color.g to the fourth power times two.


## Chest seam reference parity — 2026-11-23
- Complementary's gbuffers_block vertex path applies a 0.0001 clip-space depth bias to chest block entities when fract(worldY) is between 0.56 and 0.57. Serene now mirrors this correction for blockEntityId 5008.
- The world-Y fraction is reconstructed from player-relative position plus Iris cameraPositionFract, avoiding loss of precision from a large absolute camera-position float.


## Texture-driven Unbound-style water normals — 2026-11-23
The analytic wave substitute has been superseded by an original tileable 64x64 tangent-normal texture bound as Iris customTexture.waterNormalTex. The fragment path samples medium, small and large scales; an optional fourth very-large octave is enabled only in Ultra/HDR profiles. Stable player/world coordinates use a 2560-block wrap period so every octave tiles without a phase jump. The texture's alpha is constant 255, so it is not a height map; water POM remains disabled. CI #1084 successfully decoded the replacement PNG and confirmed its constant alpha, and #1092 passed the full compile/link/structure matrix after the held-item material fallback update. Runtime water appearance and Intel HD 5500 cost still require in-game testing.


## Glass/ice environment reflection quality fallback
Glass and ice retain Fresnel-weighted sky/horizon environment reflections when `WATER_REFLECTION_QUALITY=0`. Higher tiers continue to use screen-space hits with environment fallback for misses; the zero-quality branch directly uses the shared environment helper and does not sample SSR depth/color buffers.


### Flowing-water-only shoreline foam — 2026-11-23
Complementary Unbound's water material code gates shoreline foam to material ID 32000 (actual fluid water). Serene now keeps the shared `isWater` surface treatment for fluid water and water cauldrons, but uses a separate `isFluidWater` predicate for foam generation and composition. Water cauldrons therefore retain depth/refraction/absorption/underwater response without receiving shoreline foam. Structural regression checks cover both gates; runtime validation remains pending.


### Near-camera glass response — 2026-11-23
The supplied Complementary reference's `materialMethods/translucentTweaks.glsl` fades glass reflection toward zero inside 1.8 blocks and slightly reduces opacity inside 4 blocks. Serene now mirrors that close-range response for clear/stained/tinted glass using `length(vViewPosition)`: reflection uses `smoothstep(0.3, 1.8, distance)`, and alpha blends toward alpha-squared with a maximum 0.5 weight at the camera. It reuses the existing position varying and adds no texture samples. Runtime visual calibration remains pending.


## Unbound ice highlight response — 2026-11-23
- The supplied Complementary reference's translucent IPBR dispatch derives ice smoothness from the cube of the texture green channel, scales the highlight with the squared green-channel response, and uses a 0.7 reflection multiplier.
- Serene previously gave ice only the shared Fresnel reflection path; it had no direct specular highlight. Added a bounded Blinn-Phong highlight using the existing geometric/PBR normal, view vector, celestial light and translucent shadow result. Smoothness controls an 8–128 exponent; the reference-inspired green-channel highlight multiplier and 0.7 scale are retained.
- The implementation is ice-only and adds arithmetic but no texture samples, loops, render targets or new varyings. It remains subject to in-game appearance/performance calibration.


### Ice direct-highlight angular attenuation — 2026-11-23
A follow-up review against Unbound's GGX implementation found its direct highlight includes an explicit light-facing term. Serene's lightweight Blinn approximation now multiplies the ice highlight by the existing world-space (N\cdot L) term as well, preventing a bright specular response at grazing/back-facing light angles. This is arithmetic-only and adds no sampling.


### Clear-glass pane alpha edge guard — 2026-11-23
- Complementary's translucent material dispatch includes a narrow guard for clear glass panes: discard only fragments with alpha below 0.001 whose surface normal is nearly horizontal (|N·up| > 0.95), preventing CTM/Opti connected-pane edge artifacts.
- Serene now mirrors that exact material-specific condition using its existing player-space geometric normal. This is deliberately limited to clear glass panes (ID 32012); stained-glass panes have a separate reference path and are not affected. The existing general Iris alpha test remains in place.
- No voxel-neighbor/connected-glass behavior is claimed or added; the reference's optional connected-glass volume processing remains out of scope until Serene has a supported voxel-volume data source.


### Stained/tinted glass material response — 2026-11-23
- The supplied Unbound translucent IPBR dispatch assigns stained glass smoothness 0.5, direct-highlight multiplier 1.5, and reflection multiplier 1.0. Tinted glass uses reflection multiplier 1.0. Clear glass retains its distinct 0.5 reflection multiplier; ice uses 0.7.
- Serene now adds a low-cost medium-sharp direct highlight to stained glass using existing view/geometric normals, celestial direction, shadow and N·L. Reflection weights are adjusted to the reference material multipliers: stained/tinted 1.0, clear 0.5, ice 0.7.
- This is an arithmetic-only approximation of Unbound's GGX response, not a claim of identical BRDF. No additional texture samples, loops or render targets. Visual tuning and performance profiling remain pending.


### Clear-glass direct highlight — 2026-11-23
- Unbound's clear-glass branch uses smoothness 1.0 and a direct-highlight multiplier of 3.5 when the minimum sampled alpha is above 0.001. Stained glass instead uses smoothness 0.5 and multiplier 1.5.
- Serene now distinguishes clear glass from stained glass in the forward translucent lighting path. Clear glass receives a sharper exponent-128 Blinn approximation gated by its existing sampled alpha product, celestial visibility and N·L; stained glass retains its medium exponent-32 approximation. Both reuse existing vectors and shadowing, adding no texture samples or render targets.
- This follows the reference's material split while remaining a low-cost approximation rather than an identical GGX implementation. Runtime visual tuning remains pending.


### Tinted-glass grazing opacity — 2026-11-23
- Complementary Unbound's default tinted-glass path adjusts opacity as alpha^(1-Fresnel), making the pane more opaque toward grazing angles while retaining its Fresnel reflection response.
- Serene now applies the same alpha curve to tinted glass using the existing view normal and camera vector, with the same camera-facing normal orientation used by its reflection path. The change is arithmetic-only and adds no texture reads.
- Optional Unbound mirror-tint modes are not copied; the default material behavior is the reference target. Runtime opacity calibration remains pending.
