# Shader Menu, Profiles and Color Controls

## User requirement
The shader must provide multiple user-selectable profiles and well-organized in-game settings screens. The menu takes inspiration from the supplied working reference shader's extensive menu, categories, labels and tooltips, while remaining an original Serene Ultra interface.

## Current profiles
These profiles are defined in `shaders/shaders.properties` and exposed through Iris' native profile selector:

| Profile | Current implemented preset behavior |
|---|---|
| Ultra-Light | 512 shadow map, 96 block shadow distance, neutral output |
| Smooth | 1024 shadow map, 128 block shadow distance, neutral output |
| Ultra | 2048 shadow map, 224 block shadow distance, neutral output |
| HDR | Ultra shadow settings with HDR-style tone mapping |
| Ultra-HDR | Ultra shadow settings with stronger highlight compression |

Important: profiles must never silently disable a reference Ultra feature. Lower profiles may tune sampling, resolution, shadow distance, filtering and reconstruction quality. Any feature-specific quality change must be explicit and documented. As new renderers land, each profile must configure their quality budgets consistently.

## Current menu screens
- Main screen: profile selector, Quality, Color.
- Quality: shadow-map resolution and shadow distance.
- Color: independent RGB channel gains, gamma, exposure, contrast, saturation and HDR tone-mapping mode.

The menu uses Iris-native `screen`, `sliders`, `profile.*` and `.lang` mechanisms. Labels and hover tooltips are localized in `shaders/lang/en_us.lang`.

## Color controls implemented
- Red, green and blue gain sliders.
- Gamma correction.
- Exposure in photographic stops.
- Contrast around a middle-gray pivot.
- Saturation.
- Neutral, HDR-style and Ultra-HDR-style tone mapping.

The HDR options are tone-mapping looks for the shader's current display output. They do not claim to activate true HDR output through the operating system, monitor, or Minecraft framebuffer.

## Future menu expansion
As each subsystem is implemented, add its controls to dedicated screens:
- Shadows and ambient occlusion.
- Lighting and colored lighting.
- Atmosphere, fog and clouds.
- Water, reflections and weather.
- Materials, POM, normals and emission.
- Anti-aliasing and temporal settings.
- Bloom and post-processing.
- Dimension and compatibility options.

Do not add decorative or non-functional controls. Every visible setting must affect a real implemented shader path and have a useful tooltip. Add profile mappings whenever new quality controls are introduced.


## Quality menu update — 2026-11-23
The Quality screen currently includes shadow-map resolution, shadow distance, shadow alpha cutoff, contact AO strength and contact AO radius. `AO_STRENGTH` now includes the 0.65 profile default in its Iris option value list so the profile value is a valid selectable option.