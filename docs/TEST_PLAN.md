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
