# Runtime Test Plan

## Environment record
- Minecraft Java: 26.3
- Iris: record exact installed version
- Loader: record Fabric/NeoForge and version
- GPU: Intel HD Graphics 5500
- CPU: Intel Core i3-5005U
- RAM: 8 GB
- Graphics driver / OS: record exact versions
- Resolution / render distance / simulation distance: record

## Smoke tests
- [ ] Shader appears in Iris shader list.
- [ ] Shader applies without Iris error screen.
- [ ] World loads and terrain renders.
- [ ] Entities, hand and held items render.
- [ ] No missing/unbound sampler or GLSL compile errors.
- [ ] Shader reload succeeds.
- [ ] Overworld, Nether and End load.

## Visual parity scenes
- [ ] Clear midday / direct sunlight
- [ ] Sunrise and sunset
- [ ] Night / moonlight / stars
- [ ] Dense forest and foliage
- [ ] Water surface and underwater
- [ ] Rain and wet surfaces
- [ ] Caves and enclosed interiors
- [ ] Glass, stained glass and other translucent blocks
- [ ] Entities, mobs, particles and first-person hand
- [ ] Nether and End
- [ ] Weather and potion/night-vision effects

## Performance
Capture repeatable runs at fixed resolution and settings. Record average FPS, 1% low, frame-time distribution and scene conditions. Never compare different scenes or settings as if they were controlled tests.
undefined

Additional runtime checks:
- Verify leash and debug chunk-border overlays are fogged correctly and do not receive deferred surface lighting.
- Break blocks in sunlight, shade, caves and different resource packs; check crack texture alpha and that cracks inherit the underlying block lighting.
- Check all sign types (standing, wall and hanging) for correct text brightness, color and fog at distance.
- Check End portal and End gateway surfaces for the intended emissive contribution and ensure the mapping does not affect unrelated block entities.
- Verify opaque block entities still receive normal/lightmap/shadow/AO and translucent block entities use `gbuffers_block_translucent` after deferred.


## Iris 26.1 program-routing regression checks
- [ ] Confirm no `Failed to parse buffer blend! index = -1` popup on pack load; retain `logs/latest.log` if it occurs.
- [ ] Confirm dropped items use the `gbuffers_item` → `gbuffers_textured_lit` fallback and receive the expected lightmap/PBR response.
- [ ] Confirm glowing entities use the `gbuffers_entities_glowing` → `gbuffers_entities` fallback and preserve emissive/outline behavior.
- [ ] Confirm shadow solid/cutout/water/entity/block/lightning variants resolve through their documented Iris fallback programs without missing shader errors.
- [ ] Verify translucent entity and block-entity sorting with `separateEntityDraws=true`; do not assume the directive guarantees post-deferred routing on every Iris build.
- [ ] Verify terrain solid/cutout paths resolve through `gbuffers_terrain` and preserve alpha-tested foliage and block materials.
- [ ] Verify held item, dropped item, armor glint, spider eyes, beacon beam, lightning and clouds independently; shared fallback coverage is not visual parity.
- [ ] Re-test the same scene after shader reload and after a full game restart to distinguish stale shaderpack cache from source behavior.

- [ ] Verify falling rain/snow behavior with camera outside, underwater, in lava and inside powdered snow; confirm the `isEyeInWater == 3` suppression branch matches intended vanilla behavior.

- [ ] On the target Iris/Minecraft version, verify translucent living entities and translucent block entities actually enter `gbuffers_entities_translucent` and `gbuffers_block_translucent` with `separateEntityDraws=true`; confirm with a debug marker or temporary per-program output, then test glass entities, armor/item translucency and block-entity glass in the real pack.



## Minecraft 26.3 OIT / Iris transparency regression

**Purpose:** verify that Minecraft's native 26.3 OIT changes do not cause duplicate, missing or incorrectly blended geometry while the Iris shaderpack pipeline is active.

1. Record Minecraft 26.3 build, Iris version/build, Sodium version, OS, GPU and driver.
2. Load Serene Ultra and capture logs during shaderpack load/reload. Check for unsupported shader stages, missing attachments, framebuffer errors and OIT-related compile failures.
3. Test intersecting/overlapping water, clear glass, stained glass, ice, portals, translucent block entities, translucent entities, opaque and translucent particles, rain/snow, beacon beams and first-person hand-water.
4. Compare each scene with shaders disabled and with the working reference pack. Check depth ordering, alpha accumulation, water-mask edges, reflections/refraction, fog and whether any object is drawn twice or omitted.
5. Confirm the expected Iris routes are active: translucent terrain through `gbuffers_water`, translucent particles through `gbuffers_particles_translucent`, and water-mask handling through the Iris basic route.
6. Save the Iris log and screenshots. Mark this test complete only after the same scene passes after a shader reload and a full game restart.

Do not add vanilla `OIT_*` macros or native OIT attachment declarations to the shaderpack unless Iris documents and exposes those phases.
