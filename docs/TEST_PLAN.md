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
