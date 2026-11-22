#!/usr/bin/env python3
"""Structural checks for Serene Ultra. This is not a GLSL compiler."""
from pathlib import Path
import math
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SHADERS = ROOT / "shaders"
REQUIRED = (
    "shaders.properties", "block.properties",
    "gbuffers_terrain.vsh", "gbuffers_terrain.fsh",
    "gbuffers_entities.vsh", "gbuffers_entities.fsh",
    "gbuffers_block.vsh", "gbuffers_block.fsh",
    "gbuffers_basic.vsh", "gbuffers_basic.fsh",
    "gbuffers_damagedblock.vsh", "gbuffers_damagedblock.fsh",
    "gbuffers_entities_translucent.vsh", "gbuffers_entities_translucent.fsh",
    "gbuffers_block_translucent.vsh", "gbuffers_block_translucent.fsh",
    "gbuffers_hand.vsh", "gbuffers_hand.fsh",
    "gbuffers_water.vsh", "gbuffers_water.fsh",
    "gbuffers_hand_water.vsh", "gbuffers_hand_water.fsh",
    "gbuffers_weather.vsh", "gbuffers_weather.fsh",
    "gbuffers_particles.vsh", "gbuffers_particles.fsh",
    "gbuffers_particles_translucent.vsh", "gbuffers_particles_translucent.fsh",
    "gbuffers_spidereyes.vsh", "gbuffers_spidereyes.fsh",
    "gbuffers_armor_glint.vsh", "gbuffers_armor_glint.fsh",
    "gbuffers_lightning.vsh", "gbuffers_lightning.fsh",
    "gbuffers_clouds.vsh", "gbuffers_clouds.fsh",
    "gbuffers_textured.vsh", "gbuffers_textured.fsh",
    "gbuffers_skytextured.vsh", "gbuffers_skytextured.fsh",
    "gbuffers_skybasic.vsh", "gbuffers_skybasic.fsh",
    "gbuffers_line.vsh", "gbuffers_line.fsh",
    "gbuffers_beaconbeam.vsh", "gbuffers_beaconbeam.fsh",
    "shadow.vsh", "shadow.fsh",
    "deferred.vsh", "deferred.fsh",
    "composite.vsh", "composite.fsh",
    "final.vsh", "final.fsh",
    "lang/en_us.lang",
)
errors = []

for rel in REQUIRED:
    path = SHADERS / rel
    if not path.is_file():
        errors.append(f"Missing required shaderpack file: shaders/{rel}")

sources = {}
for path in SHADERS.rglob("*"):
    if path.suffix not in {".vsh", ".fsh", ".csh", ".glsl"}:
        continue
    source = path.read_text(encoding="utf-8")
    sources[path.name] = source
    if not re.search(r"^\s*#version\s+330\b", source, re.MULTILINE):
        errors.append(f"{path.relative_to(ROOT)}: expected an explicit GLSL 330 version")
    if source.count("{") != source.count("}"):
        errors.append(f"{path.relative_to(ROOT)}: unbalanced brace count")
    uniform_names = re.findall(r"^\\s*uniform\\s+\\w+\\s+(\\w+)\\s*;", source, re.MULTILINE)
    duplicate_uniforms = sorted({name for name in uniform_names if uniform_names.count(name) > 1})
    if duplicate_uniforms:
        errors.append(f"{path.relative_to(ROOT)}: duplicate uniform declarations: {', '.join(duplicate_uniforms)}")

# Iris does not permit gbuffers programs to sample colortex0-3. They may
# write those attachments, but sampling them from geometry passes is invalid.
for path in SHADERS.rglob("gbuffers_*"):
    if path.suffix not in {".vsh", ".fsh", ".gsh"}:
        continue
    source = path.read_text(encoding="utf-8")
    if re.search(r"\buniform\s+sampler\w*\s+colortex[0-3]\b", source):
        errors.append(
            f"{path.relative_to(ROOT)}: Iris gbuffers programs cannot sample colortex0-3"
        )

# Track Iris program coverage explicitly. Missing files use the documented
# fallback program; fallback coverage is not equivalent to a feature-specific
# material implementation. Keep these as visible warnings until the program
# families are implemented and runtime-tested.
IRIS_PROGRAM_FALLBACKS = {
    "gbuffers_water": "gbuffers_terrain",
    "gbuffers_weather": "gbuffers_textured_lit",
    "gbuffers_hand_water": "gbuffers_hand",
    "gbuffers_block": "gbuffers_terrain",
    "gbuffers_damagedblock": "gbuffers_terrain",
    "gbuffers_beaconbeam": "gbuffers_textured",
    "gbuffers_armor_glint": "gbuffers_textured",
    "gbuffers_clouds": "gbuffers_textured",
    "gbuffers_skybasic": "gbuffers_basic",
    "gbuffers_skytextured": "gbuffers_textured",
    "gbuffers_line": "gbuffers_basic",
    "gbuffers_textured_lit": "gbuffers_textured",
    "gbuffers_textured": "gbuffers_basic",
    "gbuffers_lightning": "gbuffers_entities",
    "gbuffers_entities_translucent": "gbuffers_entities",
    "gbuffers_block_translucent": "gbuffers_block",
    "gbuffers_particles": "gbuffers_textured_lit",
    "gbuffers_particles_translucent": "gbuffers_particles",
    "gbuffers_spidereyes": "gbuffers_textured",
    "gbuffers_terrain_solid": "gbuffers_terrain",
    "gbuffers_terrain_cutout": "gbuffers_terrain",
}
missing_iris_programs = {
    name: fallback
    for name, fallback in IRIS_PROGRAM_FALLBACKS.items()
    if not ((SHADERS / f"{name}.vsh").is_file()
            and (SHADERS / f"{name}.fsh").is_file())
}

audit = ROOT / "docs" / "REFERENCE_ULTRA_AUDIT.md"
if not audit.is_file():
    errors.append("Missing source-derived Ultra reference audit")
else:
    audit_text = audit.read_text(encoding="utf-8")
    for token in ("SHADOW_QUALITY", "COLORED_LIGHTING", "WORLD_SPACE_REFLECTIONS",
                  "WATER_REFLECT_QUALITY", "CLOUD_QUALITY", "RAIN_PUDDLES"):
        if token not in audit_text:
            errors.append(f"Reference audit is missing required setting: {token}")

props_path = SHADERS / "shaders.properties"
props = ""
if props_path.is_file():
    props = props_path.read_text(encoding="utf-8")
    for profile in ("Ultra-Light", "Smooth", "Ultra", "HDR", "Ultra-HDR"):
        if f"profile.{profile} =" not in props:
            errors.append(f"Missing shader profile: {profile}")
    for screen in ("screen = <profile>", "screen.QUALITY =", "screen.COLOR ="):
        if screen not in props:
            errors.append(f"Missing menu configuration: {screen}")
    for option in ("SHADOW_ALPHA_CUTOFF", "AO_STRENGTH", "AO_RADIUS"):
        if option not in props:
            errors.append(f"{option} is not exposed in the Quality menu")
    if "separateAo=false" not in props:
        errors.append("G-buffer alpha must remain material opacity; separateAo must be false until AO is explicitly packed")
    if "separateEntityDraws=false" not in props:
        errors.append("separateEntityDraws must remain explicitly disabled for current Iris compatibility")
    if "iris.features.optional=ENTITY_TRANSLUCENT" in props:
        errors.append("Do not request ENTITY_TRANSLUCENT while separateEntityDraws remains disabled")
    if "format.colortex2=RGBA16F" not in props or "format.colortex3=RGBA8" not in props:
        errors.append("G-buffer normal/emission targets must use the declared formats")
    if "particles.ordering=mixed" not in props:
        errors.append("Deferred packs must explicitly separate opaque and translucent particles with particles.ordering=mixed")
    if "endFlashShadows=true" not in props:
        errors.append("End flash shadows must follow Iris shadowLightPosition in the End")
    if "rain.depth=false" not in props:
        errors.append("Weather must remain a post-deferred color-only path without depth writes")
    if "alphaTest.gbuffers_water=GREATER 0.0001" not in props:
        errors.append("Translucent water must use the reference-matched low alphaTestRef")
    if "WATER_FOG_MULT" not in props:
        errors.append("Water depth-opacity control must be exposed in the Quality menu")
    for program in ("gbuffers_beaconbeam", "gbuffers_clouds", "gbuffers_spidereyes", "gbuffers_skytextured"):
        if f"alphaTest.{program}=GREATER 0.0001" not in props:
            errors.append(f"{program} must use the low alpha threshold from the reference shader")
    for program in ("gbuffers_armor_glint", "gbuffers_beaconbeam", "gbuffers_lightning", "gbuffers_clouds", "gbuffers_spidereyes"):
        if f"blend.{program}.colortex2=off" not in props:
            errors.append(f"{program} must disable blending on the deferred-validity mask")
    if "WEATHER_TEX_OPACITY" not in props:
        errors.append("Weather particle opacity control must be exposed in the Quality menu")
    if "PARTICLE_MATERIAL_FEATURES" not in props:
        errors.append("Complementary-guided particle material effects must be exposed in the Quality menu")
    if "option.PARTICLE_MATERIAL_FEATURES =" not in (SHADERS / "lang" / "en_us.lang").read_text(encoding="utf-8"):
        errors.append("Particle material effects option needs a user-facing label")

# Iris routes translucent entities and block entities through these dedicated
# programs when separateEntityDraws is enabled. Both pairs are required above.

# Iris shader constants are GLSL declarations, not shaders.properties keys.
all_glsl = "\n".join(sources.values())
for declaration in (
    "const bool shadowHardwareFiltering = true;",
    "const float shadowIntervalSize = 2.0;",
):
    if declaration not in all_glsl:
        errors.append(f"Missing Iris GLSL constant declaration: {declaration}")
if "shadowHardwareFiltering=" in props or "shadowIntervalSize=" in props:
    errors.append("Iris GLSL constants must not be declared as shaders.properties directives")

for name in ("gbuffers_terrain.fsh", "gbuffers_entities.fsh", "gbuffers_hand.fsh",
             "gbuffers_particles.fsh", "gbuffers_spidereyes.fsh"):
    source = sources.get(name, "")
    alpha_test_uses_ref = ("albedo.a < alphaTestRef" in source or "particle.a < alphaTestRef" in source or "emissiveColor.a < alphaTestRef" in source)
    if "uniform float alphaTestRef" not in source or not alpha_test_uses_ref:
        errors.append(f"{name} must use Iris alphaTestRef for alpha discard")
hand_fragment = sources.get("gbuffers_hand.fsh", "")
if "uniform sampler2D lightmap" not in hand_fragment or "texture(lightmap" not in hand_fragment:
    errors.append("Hand shader must preserve the vanilla lightmap response")
entities = sources.get("gbuffers_entities.fsh", "")
if "uniform vec4 entityColor" not in entities or "mix(entityAlbedoLinear, entityTintLinear, entityColor.a)" not in entities:
    errors.append("Entity shader must apply Iris entityColor tint in linear space using its alpha blend factor")

final = sources.get("final.fsh", "")
for option in ("RED_GAIN", "GREEN_GAIN", "BLUE_GAIN", "GAMMA", "EXPOSURE",
               "CONTRAST", "SATURATION", "HDR_LOOK"):
    if f"#define {option} " not in final:
        errors.append(f"Missing active color control: {option}")

shadow_vertex = sources.get("shadow.vsh", "")
shadow_fragment = sources.get("shadow.fsh", "")
for varying in ("vShadowTexCoord", "vShadowVertexColor"):
    if varying not in shadow_vertex or varying not in shadow_fragment:
        errors.append(f"Shadow alpha-test varying is missing or mismatched: {varying}")
if "uniform sampler2D gtexture" not in shadow_fragment or "texture(gtexture" not in shadow_fragment or "discard" not in shadow_fragment:
    errors.append("Shadow pass must use Iris gtexture and discard transparent texels")
for path in SHADERS.rglob("*.fsh"):
    source = path.read_text(encoding="utf-8")
    if re.search(r"\buniform\s+sampler\w*\s+texture\b", source):
        errors.append(f"{path.relative_to(ROOT)}: reserved texture sampler alias; use Iris gtexture or another valid sampler name")
for name in ("gbuffers_terrain.fsh", "gbuffers_entities.fsh", "gbuffers_block.fsh", "gbuffers_hand.fsh",
             "gbuffers_particles.fsh", "gbuffers_particles_translucent.fsh",
             "gbuffers_spidereyes.fsh", "gbuffers_damagedblock.fsh"):
    source = sources.get(name, "")
    if "uniform sampler2D gtexture" not in source or "texture(gtexture" not in source:
        errors.append(f"{name} must sample the Iris block/entity atlas through gtexture")
if "#define SHADOW_ALPHA_CUTOFF " not in shadow_fragment:
    errors.append("Shadow alpha cutoff must be an active shader option")
if "uniform float alphaTestRef" not in shadow_fragment or "max(alphaTestRef, SHADOW_ALPHA_CUTOFF)" not in shadow_fragment:
    errors.append("Shadow cutouts must respect Iris alphaTestRef as well as the pack's cutoff control")
if "const int shadowMapResolution" not in shadow_vertex or "const float shadowDistance" not in shadow_vertex:
    errors.append("Shadow pass must declare Iris shadowMapResolution and shadowDistance constants")
if "const float shadowDistanceRenderMul = 1.0;" not in shadow_vertex:
    errors.append("Shadow pass must enable Iris shadow-distance culling")
deferred_options = sources.get("deferred.fsh", "")
ao_strength_line = next((line for line in deferred_options.splitlines() if line.startswith("#define AO_STRENGTH ")), "")
if "0.65" not in ao_strength_line:
    errors.append("AO_STRENGTH option values must include the 0.65 profile preset")

terrain_vertex = sources.get("gbuffers_terrain.vsh", "")
for token in ("in vec2 mc_Entity", "flat out int vMaterialId", "vMaterialId = int(mc_Entity.x + 0.5)"):
    if token not in terrain_vertex:
        errors.append(f"Terrain vertex stage is missing Iris mc_Entity material classification: {token}")
terrain_fragment = sources.get("gbuffers_terrain.fsh", "")
for token in ("flat in int vMaterialId", "emissionStrength", "outEmissionData = vec4(albedo.rgb, emissionStrength / 5.0)"):
    if token not in terrain_fragment:
        errors.append(f"Terrain G-buffer is missing emissive material output: {token}")
block_properties = (SHADERS / "block.properties").read_text(encoding="utf-8")
for token in ("block.32100=minecraft:glowstone", "block.32118=minecraft:lava"):
    if token not in block_properties:
        errors.append(f"Missing emissive block ID mapping: {token}")

for name in ("gbuffers_terrain.fsh", "gbuffers_entities.fsh", "gbuffers_block.fsh", "gbuffers_particles.fsh"):
    source = sources.get(name, "")
    if "/* RENDERTARGETS: 0,1,2,3 */" not in source:
        errors.append(f"{name} must write albedo, lightmap, normal and emissive attachments")
    for output in ("outColor", "outLightmapData", "outEncodedNormal", "outEmissionData"):
        if output not in source:
            errors.append(f"{name} is missing G-buffer output {output}")
    if "uniform sampler2D lightmap" not in source or "texture(lightmap" not in source:
        errors.append(f"{name} must capture the vanilla colored lightmap")
    alpha_test_uses_ref = ("albedo.a < alphaTestRef" in source or "particle.a < alphaTestRef" in source)
    if "uniform float alphaTestRef" not in source or not alpha_test_uses_ref:
        errors.append(f"{name} must use Iris alphaTestRef instead of a hardcoded alpha cutoff")
    if "vLightmapCoord.y / (30.0 / 32.0) - (1.0 / 32.0)" not in source:
        errors.append(f"{name} must normalize Iris lightmap sky coordinates before storing the direct-light mask")
    if name != "gbuffers_terrain.fsh" and "outEmissionData = vec4(0.0)" not in source:
        errors.append(f"{name} must initialize the emissive attachment for non-emissive G-buffer materials")

entity_translucent = sources.get("gbuffers_entities_translucent.fsh", "")
block_translucent = sources.get("gbuffers_block_translucent.fsh", "")
for name, source in (("gbuffers_entities_translucent", entity_translucent),
                     ("gbuffers_block_translucent", block_translucent)):
    for token in ("/* RENDERTARGETS: 0 */", "texture(gtexture", "texture(lightmap",
                  "sampler2DShadow shadowtex0", "shadowModelView", "shadowProjection",
                  "calculateForwardLighting", "calculateForwardFog", "outColor = vec4("):
        if token not in source:
            errors.append(f"{name} is missing forward translucent component: {token}")
    if "alphaTestRef" in source or "albedo.a <= 0.001" not in source:
        errors.append(f"{name} must preserve fractional alpha instead of applying cutout alphaTestRef")
    if re.search(r"\\buniform\\s+sampler\\w*\\s+colortex[0-3]\\b", source):
        errors.append(f"{name} must not sample colortex0-3 after deferred")
if "uniform vec4 entityColor" not in entity_translucent or "mix(albedoLinear, tintLinear, entityColor.a)" not in entity_translucent:
    errors.append("Translucent entity path must preserve Iris entityColor tint")
weather_vertex = sources.get("gbuffers_weather.vsh", "")
if "#define WAVING_RAIN" not in weather_vertex or "eyeBrightnessSmooth" not in weather_vertex or "rainStrength" not in weather_vertex:
    errors.append("Weather vertex path must implement the Iris-aware waving rain/snow option")
weather = sources.get("gbuffers_weather.fsh", "")
for token in ("/* RENDERTARGETS: 0 */", "texture(gtexture", "texture(lightmap",
              "fogColor", "fogStart", "fogEnd", "fogDensity", "fogMode", "fogShape",
              "uniform int isEyeInWater", "uniform float alphaTestRef",
              "WEATHER_TEX_OPACITY", "rainTexOpacity", "snowTexOpacity",
              "weatherColor.a < max(0.1, alphaTestRef)", "isEyeInWater == 3"):
    if token not in weather:
        errors.append(f"Forward weather shader is missing Iris fog/light component: {token}")
hand_water = sources.get("gbuffers_hand_water.fsh", "")
for token in ("/* RENDERTARGETS: 0 */", "texture(gtexture", "texture(lightmap",
              "fogColor", "fogDensity", "calculateHandWaterFog"):
    if token not in hand_water:
        errors.append(f"Hand-water shader is missing forward component: {token}")
water = sources.get("gbuffers_water.fsh", "")
water_vertex = sources.get("gbuffers_water.vsh", "")
for token in ("/* RENDERTARGETS: 0 */", "sampler2DShadow shadowtex0",
              "shadowModelView", "shadowProjection", "sampleTranslucentShadow",
              "uniform vec3 fogColor", "uniform float fogDensity", "calculateTranslucentFog",
              "texture(gtexture", "texture(lightmap", "depthtex1", "calculateWaterThickness",
              "WATER_FOG_MULT", "uniform float alphaTestRef",
              "translucentAlbedo.a < alphaTestRef", "vMaterialId == 32000",
              "opaqueDepth) * 2.0 - 1.0", "texelFetch(depthtex1, ivec2(gl_FragCoord.xy), 0)",
              "gl_FragCoord.xy / vec2(textureSize(depthtex1, 0))",
              "sqrt(max(translucentAlbedo.a, 0.0))",
              "outColor = vec4(litColor, translucentAlbedo.a)"):
    if token not in water:
        errors.append(f"Forward translucent-terrain shader is missing Iris-compatible component: {token}")
for token in ("in vec2 mc_Entity", "vMaterialId = int(mc_Entity.x + 0.5)", "vFluidRenderType = mc_Entity.y"):
    if token not in water_vertex:
        errors.append(f"Translucent-terrain vertex stage is missing Iris material attribute: {token}")
block_props = (SHADERS / "block.properties").read_text(encoding="utf-8") if (SHADERS / "block.properties").is_file() else ""
for token in ("block.32000=minecraft:water",):
    if token not in block_props:
        errors.append(f"Missing stable Iris block material mapping: {token}")
basic = sources.get("gbuffers_basic.fsh", "")
for token in ("/* RENDERTARGETS: 0,2 */", "fogColor", "fogMode", "fogShape",
              "outDeferredValidity = vec4(0.0)"):
    if token not in basic:
        errors.append(f"Basic overlay program is missing forward/fog component: {token}")
damaged = sources.get("gbuffers_damagedblock.fsh", "")
for token in ("/* RENDERTARGETS: 0 */", "texture(gtexture", "alphaTestRef",
              "crackColor.a < alphaTestRef", "crackColor.rgb *= vVertexColor.rgb"):
    if token not in damaged:
        errors.append(f"Damaged-block overlay is missing Iris alpha/color component: {token}")
block_shader = sources.get("gbuffers_block.fsh", "")
for token in ("/* RENDERTARGETS: 0,1,2,3 */", "uniform int blockEntityId",
              "blockEntityId == 5004", "blockEntityId == 5025",
              "outEncodedNormal = vec4(normalize(vPlayerNormal) * 0.5 + 0.5, signText ? 0.0 : 1.0)",
              "calculateBlockFog", "outEmissionData"):
    if token not in block_shader:
        errors.append(f"Block-entity shader is missing Iris blockEntityId component: {token}")
line_overlay = sources.get("gbuffers_line.fsh", "")
for token in ("/* RENDERTARGETS: 0,2 */", "MC_RENDER_STAGE_OUTLINE", "MC_RENDER_STAGE_DEBUG",
              "fogColor", "fogDensity", "outDeferredValidity = vec4(0.0)"):
    if token not in line_overlay:
        errors.append(f"Line overlay is missing Iris render-stage component: {token}")
sky_basic = sources.get("gbuffers_skybasic.fsh", "")
sky_basic_vertex = sources.get("gbuffers_skybasic.vsh", "")
for token in ("/* RENDERTARGETS: 0,2 */", "MC_RENDER_STAGE_SKY", "MC_RENDER_STAGE_SUNSET",
              "MC_RENDER_STAGE_STARS", "MC_RENDER_STAGE_VOID", "skyColor", "fogColor",
              "gbufferProjectionInverse", "outDeferredValidity = vec4(0.0)"):
    if token not in sky_basic and token not in sky_basic_vertex:
        errors.append(f"Sky-basic program is missing Iris sky-stage component: {token}")
sky_textured = sources.get("gbuffers_skytextured.fsh", "")
for token in ("/* RENDERTARGETS: 0,2 */", "MC_RENDER_STAGE_SUN", "MC_RENDER_STAGE_MOON",
              "alphaTestRef", "sunPosition", "moonPosition", "isEyeInWater", "outDeferredValidity = vec4(0.0)"):
    if token not in sky_textured:
        errors.append(f"Sky-texture program is missing Iris stage/material handling: {token}")
textured = sources.get("gbuffers_textured.fsh", "")
for token in ("/* RENDERTARGETS: 0,2 */", "texture(gtexture", "alphaTestRef",
              "fogColor", "fogDensity", "fogMode", "fogShape",
              "outDeferredValidity = vec4(0.0)"):
    if token not in textured:
        errors.append(f"Textured fallback is missing Iris overlay component: {token}")
clouds = sources.get("gbuffers_clouds.fsh", "")
for token in ("/* RENDERTARGETS: 0,2 */", "isEyeInWater != 0", "fogColor",
              "fogDensity", "fogMode", "fogShape", "outDeferredValidity = vec4(0.0)"):
    if token not in clouds:
        errors.append(f"Cloud overlay is missing Iris forward component: {token}")
for name in ("gbuffers_lightning.fsh", "gbuffers_beaconbeam.fsh"):
    overlay = sources.get(name, "")
    for token in ("/* RENDERTARGETS: 0,2 */", "outDeferredValidity = vec4(0.0)",
                  "fogColor", "fogDensity", "fogMode", "fogShape"):
        if token not in overlay:
            errors.append(f"{name} is missing forward-overlay component: {token}")
armor_glint = sources.get("gbuffers_armor_glint.fsh", "")
for token in ("/* RENDERTARGETS: 0,2 */", "texture(gtexture", "glintColor.rgb *= vVertexColor.a",
              "outDeferredValidity = vec4(0.0)", "discard"):
    if token not in armor_glint:
        errors.append(f"Armor-glint overlay is missing deferred-bypass component: {token}")
spidereyes = sources.get("gbuffers_spidereyes.fsh", "")
if "/* RENDERTARGETS: 0,2 */" not in spidereyes or "outDeferredValidity = vec4(0.0)" not in spidereyes:
    errors.append("Spider-eye pass must preserve emissive pixels from deferred lighting")
if "fogColor" not in spidereyes or "calculateEyeFog" not in spidereyes:
    errors.append("Spider-eye pass must preserve Iris fog while bypassing deferred lighting")
clouds = sources.get("gbuffers_clouds.fsh", "")
for token in ("uniform float alphaTestRef", "texture(gtexture", "vec4(vec3(1.0), vVertexColor.a)",
              "cloudColor.a < alphaTestRef", "outDeferredValidity = vec4(0.0)"):
    if token not in clouds:
        errors.append(f"Cloud shader is missing Iris/reference component: {token}")
translucent_particles = sources.get("gbuffers_particles_translucent.fsh", "")
if "particle.a < 0.01" not in translucent_particles or "alphaTestRef" in translucent_particles:
    errors.append("Translucent particles must preserve fractional alpha instead of applying cutout alphaTestRef")
for token in ("fogColor", "fogStart", "fogEnd", "fogDensity", "fogMode", "fogShape", "calculateParticleFog",
              "uniform sampler2D noisetex", "textureSize(noisetex", "texelFetch(noisetex",
              "WEATHER_TEX_OPACITY", "rainTexOpacity", "snowTexOpacity",
              "suppressLightmap", "PARTICLE_MATERIAL_FEATURES",
              "uniform float rainStrength", "hasSkylight && rainStrength > 0.001"):
    if token not in translucent_particles:
        errors.append(f"Translucent particle shader is missing forward lighting component: {token}")
translucent_particle_vertex = sources.get("gbuffers_particles_translucent.vsh", "")
for token in ("gbufferModelViewInverse", "vPlayerPosition", "vPlayerNormal"):
    if token not in translucent_particle_vertex:
        errors.append(f"Translucent particle vertex stage is missing player-space lighting input: {token}")
particles = sources.get("gbuffers_particles.fsh", "")
if "/* RENDERTARGETS: 0,1,2,3 */" not in particles:
    errors.append("Opaque particles must write color, lightmap, normal and emissive G-buffer attachments")
translucent_particles = sources.get("gbuffers_particles_translucent.fsh", "")
if "/* RENDERTARGETS: 0 */" not in translucent_particles:
    errors.append("Translucent particles must use a forward color-only output")
if "texture(lightmap" not in translucent_particles:
    errors.append("Translucent particles must preserve the vanilla lightmap response")

deferred = sources.get("deferred.fsh", "")
for token in ("/* RENDERTARGETS: 0 */", "sampler2D colortex0",
              "sampler2D colortex1", "sampler2D colortex2", "sampler2D colortex3",
              "texture(colortex3, vTexCoord)", "emissionData.a * 5.0",
              "sampler2D depthtex0", "sampler2D depthtex2", "sampler2DShadow shadowtex0",
              "gbufferProjectionInverse", "shadowModelView", "shadowProjection",
              "sampleShadow", "vanillaAmbient", "lightData.a",
              "uniform bool hasSkylight", "uniform float endFlashIntensity", "celestialGate",
              "uniform vec3 fogColor", "uniform float fogDensity", "fogMode", "fogShape", "calculateFogFactor",
              "sampleContactAO", "AO_STRENGTH", "AO_RADIUS",
              "sin(sunAngle * 6.28318530718)",
              "smoothstep(0.0, 0.30, solarElevation)"):
    if token not in deferred:
        errors.append(f"Deferred lighting is missing required component: {token}")
if "abs(sceneDepth - opaqueWorldDepth) > 0.000001" not in deferred:
    errors.append("Deferred must mask hand/translucent pixels by comparing depthtex0 with depthtex2")
if "vec3(vTexCoord, opaqueWorldDepth)" not in deferred:
    errors.append("Deferred must reconstruct world position from depthtex2")

if "1.0 - smoothstep(0.45, 0.55, sunAngle)" in deferred:
    errors.append("Deferred day/night curve incorrectly treats Iris sunrise as full daylight")
# Numerically guard the documented Iris sunAngle cycle: dawn=0, noon=0.25,
# sunset=0.5 and midnight=0.75. The daylight envelope must be continuous.
def smoothstep01(x):
    t = max(0.0, min(1.0, x))
    return t * t * (3.0 - 2.0 * t)

for phase, expected in ((0.0, 0.0), (0.25, 1.0), (0.5, 0.0), (0.75, 0.0)):
    elevation = math.sin(phase * 2.0 * math.pi)
    daylight = smoothstep01(elevation / 0.30)
    if abs(daylight - expected) > 1e-6:
        errors.append(f"Iris daylight cycle regression at sunAngle={phase}")
if "outColor = scene;" not in deferred or "outColor = vec4(litColor, scene.a);" not in deferred:
    errors.append("Deferred pass must preserve uncovered pixels and output shaded pixels")

composite = sources.get("composite.fsh", "")
if "uniform sampler2D colortex0" not in composite:
    errors.append("Composite must preserve the accumulated scene from colortex0")
if "/* RENDERTARGETS: 0 */" not in composite:
    errors.append("Composite must write the final scene back to colortex0")
if "texture(colortex0" not in composite and "texture2D(colortex0" not in composite:
    errors.append("Composite does not preserve the accumulated scene")
if "/* RENDERTARGETS: 3 */" in deferred:
    errors.append("Deferred must read, not write, the emissive colortex3 buffer")
if "copies colortex3 back to colortex0" in deferred:
    errors.append("Deferred source contains obsolete colortex3 copy-back commentary")
if "colortex3" not in deferred:
    errors.append("Deferred must sample the emissive G-buffer before fogging the final lit scene")
for directive in (
    "flip.deferred.colortex0=true", "flip.composite.colortex0=true",
    "flip.deferred.colortex3=false",
    "blend.gbuffers_terrain.colortex3=off",
    "blend.gbuffers_entities.colortex3=off",
    "blend.gbuffers_particles.colortex3=off",
    "blend.gbuffers_block.colortex1=off",
    "blend.gbuffers_block.colortex2=off",
    "blend.gbuffers_block.colortex3=off",
    "blend.gbuffers_basic.colortex2=off",
    "alphaTest.gbuffers_damagedblock=GREATER 0.004",
    "blend.gbuffers_water.colortex0=SRC_ALPHA ONE_MINUS_SRC_ALPHA ONE ONE_MINUS_SRC_ALPHA",
    "blend.gbuffers_weather.colortex0=SRC_ALPHA ONE_MINUS_SRC_ALPHA ONE ONE_MINUS_SRC_ALPHA",
    "blend.gbuffers_hand_water.colortex0=SRC_ALPHA ONE_MINUS_SRC_ALPHA ONE ONE_MINUS_SRC_ALPHA",
    "blend.gbuffers_particles_translucent.colortex0=SRC_ALPHA ONE_MINUS_SRC_ALPHA ONE ONE_MINUS_SRC_ALPHA",
    "blend.gbuffers_spidereyes.colortex2=off",
    "blend.gbuffers_armor_glint.colortex2=off",
    "blend.gbuffers_lightning.colortex2=off",
    "blend.gbuffers_beaconbeam.colortex2=off",
    "blend.gbuffers_clouds.colortex2=off",
    "blend.gbuffers_textured.colortex2=off",
    "blend.gbuffers_skytextured.colortex2=off",
    "blend.gbuffers_skybasic.colortex2=off",
    "blend.gbuffers_line.colortex2=off",
):
    if directive not in props:
        errors.append(f"Missing Iris translucent-scene pipeline directive: {directive}")

lang_path = SHADERS / "lang" / "en_us.lang"
if lang_path.is_file():
    lang = lang_path.read_text(encoding="utf-8")
    for option in ("AO_STRENGTH", "AO_RADIUS"):
        if f"option.{option} =" not in lang or f"option.{option}.comment =" not in lang:
            errors.append(f"Missing user-facing label or tooltip for {option}")

brief = ROOT / "PROJECT_BRIEF.md"
if not brief.is_file():
    errors.append("Missing cumulative PROJECT_BRIEF.md")

if errors:
    print("Serene Ultra structural validation FAILED:")
    for error in errors:
        print(f" - {error}")
    sys.exit(1)

print("Serene Ultra structural validation passed.")
if missing_iris_programs:
    print("Iris program coverage warnings (dedicated vertex+fragment pair missing):")
    for name, fallback in missing_iris_programs.items():
        print(f" - {name}: Iris fallback -> {fallback}")
print("Note: GLSL compilation and in-game Iris compatibility require runtime testing.")
