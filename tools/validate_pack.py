#!/usr/bin/env python3
"""Structural checks for Serene Ultra. This is not a GLSL compiler."""
from pathlib import Path
import math
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SHADERS = ROOT / "shaders"
REQUIRED = (
    "shaders.properties", "block.properties", "entity.properties", "item.properties",
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
    "gbuffers_textured_lit.vsh", "gbuffers_textured_lit.fsh",
    "gbuffers_skytextured.vsh", "gbuffers_skytextured.fsh",
    "gbuffers_skybasic.vsh", "gbuffers_skybasic.fsh",
    "gbuffers_line.vsh", "gbuffers_line.fsh",
    "gbuffers_beaconbeam.vsh", "gbuffers_beaconbeam.fsh",
    "shadow.vsh", "shadow.fsh",
    "deferred.vsh", "deferred.fsh",
    "deferred1.vsh", "deferred1.fsh",
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
    uniform_names = re.findall(r"^\s*uniform\s+\w+\s+(\w+)\s*;", source, re.MULTILINE)
    duplicate_uniforms = sorted({name for name in uniform_names if uniform_names.count(name) > 1})
    if duplicate_uniforms:
        errors.append(f"{path.relative_to(ROOT)}: duplicate uniform declarations: {', '.join(duplicate_uniforms)}")

# Iris gbuffers read from and write to the main buffers. Sampling a
# different colortex attachment is allowed; sampling an attachment that the
# same gbuffers pass writes can create a read/write race condition.
for path in SHADERS.rglob("gbuffers_*.fsh"):
    source = path.read_text(encoding="utf-8")
    target_match = re.search(r"/\*\s*RENDERTARGETS:\s*([0-9,\s]+)\s*\*/", source)
    if target_match:
        write_targets = {int(value) for value in re.findall(r"\d+", target_match.group(1))}
    else:
        legacy_match = re.search(r"/\*\s*DRAWBUFFERS:\s*([0-9]+)\s*\*/", source)
        write_targets = {int(value) for value in legacy_match.group(1)} if legacy_match else set()
    sampled_targets = {
        int(value) for value in re.findall(
            r"\buniform\s+sampler\w*\s+colortex(\d+)\b", source
        )
    }
    conflicts = sorted(write_targets & sampled_targets)
    if conflicts:
        errors.append(
            f"{path.relative_to(ROOT)}: gbuffers pass samples and writes the same colortex attachment(s): "
            + ", ".join(f"colortex{value}" for value in conflicts)
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
    for option in ("SHADOW_ALPHA_CUTOFF", "AO_STRENGTH", "AO_RADIUS",
                   "WATER_REFRACTION_STRENGTH", "WATER_REFLECTION_STRENGTH",
                   "WATER_ABSORPTION_STRENGTH", "PORTAL_DISTORTION_STRENGTH", "OPAQUE_NORMAL_MAP_STRENGTH", "PBR_AO_STRENGTH", "MATERIAL_AO_STRENGTH", "MATERIAL_SSS_STRENGTH", "RAIN_PUDDLE_STRENGTH", "MATERIAL_WETNESS_STRENGTH", "PBR_REFLECTION_STRENGTH", "PBR_REFLECTION_QUALITY"):
        if option not in props:
            errors.append(f"{option} is not exposed in the Quality menu")
    slider_options_line = next((line for line in props.splitlines() if line.startswith("sliders = ")), "")
    for option in ("WATER_ABSORPTION_STRENGTH", "PORTAL_DISTORTION_STRENGTH", "OPAQUE_NORMAL_MAP_STRENGTH", "PBR_AO_STRENGTH", "MATERIAL_AO_STRENGTH", "MATERIAL_SSS_STRENGTH", "RAIN_PUDDLE_STRENGTH", "MATERIAL_WETNESS_STRENGTH"):
        if option not in slider_options_line:
            errors.append(f"{option} must be exposed as an Iris slider")
    if "separateAo=false" not in props:
        errors.append("G-buffer alpha remains smoothness; material AO must stay in colortex3.b while separateAo remains false")
    if "separateEntityDraws=true" not in props:
        errors.append("Iris translucent entity/block-entity passes require separateEntityDraws=true")
    if "iris.features.optional=ENTITY_TRANSLUCENT" not in props:
        errors.append("Query Iris ENTITY_TRANSLUCENT support through iris.features.optional")
    deferred_format_source = sources.get("deferred.fsh", "")
    if "const int colortex2Format = RGBA8;" not in deferred_format_source:
        errors.append("Iris colortex2 normal/smoothness target must use normalized RGBA8 to preserve bandwidth on low-end GPUs")
    if "const int colortex3Format = RGBA8;" not in deferred_format_source:
        errors.append("Iris colortex3 material target must declare RGBA8 for emission, reflectance, AO and SSS channels")
    if "format.colortex2=" in props or "format.colortex3=" in props or "colortex3Format=" in props:
        errors.append("Buffer formats must use Iris GLSL const directives, not shaders.properties key/value syntax")
    if "particles.ordering=mixed" not in props:
        errors.append("Deferred packs must explicitly separate opaque and translucent particles with particles.ordering=mixed")
    if ("size.buffer.colortex4=0.5 0.5" not in props
        or "flip.deferred1.colortex0=false" not in props
        or "flip.deferred1.colortex4=true" not in props):
        errors.append("Water refraction requires half-resolution colortex4, a deferred1 output flip, and no flip of its read-only colortex0 source")
    if "endFlashShadows=true" not in props:
        errors.append("End flash shadows must follow Iris shadowLightPosition in the End")
    if "rain.depth=false" not in props:
        errors.append("Weather must remain a post-deferred color-only path without depth writes")
    if "alphaTest.gbuffers_water=GREATER 0.0001" not in props:
        errors.append("Translucent water must use the reference-matched low alphaTestRef")
    if "WATER_FOG_MULT" not in props:
        errors.append("Water depth-opacity control must be exposed in the Quality menu")
water_fog_option = "#define WATER_FOG_MULT 100 // [25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100 110 120 130 140 150 160 170 180 190 200 220 240 260 280 300 325 350 375 400 425 450 475 500 550 600 650 700 750 800 850 900] Water depth opacity"
if water_fog_option not in sources.get("gbuffers_water.fsh", ""):
    errors.append("WATER_FOG_MULT must use the documented Iris numerical-option value-list syntax")
if "#define WAVING_RAIN // Animate rain and snow geometry" not in sources.get("gbuffers_weather.vsh", ""):
    errors.append("WAVING_RAIN must be declared as an Iris boolean option in the weather vertex shader")

    for program in ("gbuffers_beaconbeam", "gbuffers_clouds", "gbuffers_spidereyes", "gbuffers_skytextured"):
        if f"alphaTest.{program}=GREATER 0.0001" not in props:
            errors.append(f"{program} must use the low alpha threshold from the reference shader")
    for program in ("gbuffers_armor_glint", "gbuffers_beaconbeam", "gbuffers_lightning", "gbuffers_clouds", "gbuffers_spidereyes"):
        if f"blend.{program}.colortex2=off" not in props:
            errors.append(f"{program} must disable blending on the deferred-validity mask")
    if "WEATHER_TEX_OPACITY" not in props:
        errors.append("Weather particle opacity control must be exposed in the Quality menu")
weather_opacity_define = "#define WEATHER_TEX_OPACITY 100 // [25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100 110 120 130 140 150 160 170 180 190 200 220 240 260 280 300 325 350 375 400 425 450 475 500 550 600 650 700 750 800 850 900] Weather particle opacity"
for name in ("gbuffers_weather.fsh", "gbuffers_particles_translucent.fsh"):
    if weather_opacity_define not in sources.get(name, ""):
        errors.append(f"{name} must declare the identical Iris WEATHER_TEX_OPACITY option")
    if "PARTICLE_MATERIAL_FEATURES" not in props:
        errors.append("Complementary-guided particle material effects must be exposed in the Quality menu")
    if "option.PARTICLE_MATERIAL_FEATURES =" not in (SHADERS / "lang" / "en_us.lang").read_text(encoding="utf-8"):
        errors.append("Particle material effects option needs a user-facing label")

# Iris documents separateEntityDraws and ENTITY_TRANSLUCENT as the routing/query
# contract for the dedicated post-deferred translucent entity/block-entity programs.

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

for name in ("gbuffers_terrain.fsh", "gbuffers_entities.fsh", "gbuffers_block.fsh",
             "gbuffers_damagedblock.fsh", "gbuffers_hand.fsh",
             "gbuffers_particles.fsh", "gbuffers_spidereyes.fsh"):
    source = sources.get(name, "")
    alpha_test_uses_ref = ("albedo.a < alphaTestRef" in source or "particle.a < alphaTestRef" in source or
                           "emissiveColor.a < alphaTestRef" in source or "crackColor.a < alphaTestRef" in source)
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
    if "uniform sampler2D gtexture" not in source or not any(
        token in source for token in ("texture(gtexture", "textureGrad(gtexture")
    ):
        errors.append(f"{name} must sample the Iris block/entity atlas through gtexture")
if "#define SHADOW_ALPHA_CUTOFF " not in shadow_fragment:
    errors.append("Shadow alpha cutoff must be an active shader option")
if "uniform float alphaTestRef" not in shadow_fragment or "max(alphaTestRef, SHADOW_ALPHA_CUTOFF)" not in shadow_fragment:
    errors.append("Shadow cutouts must respect Iris alphaTestRef as well as the pack's cutoff control")
if "const int shadowMapResolution" not in shadow_vertex or "const float shadowDistance" not in shadow_vertex:
    errors.append("Shadow pass must declare Iris shadowMapResolution and shadowDistance constants")
if "const float shadowDistanceRenderMul = 1.0;" not in shadow_vertex:
    errors.append("Shadow pass must enable Iris shadow-distance culling")

for token in ("uniform mat4 shadowModelViewInverse", "in vec2 mc_Entity",
              "vShadowPlayerPosition = (shadowModelViewInverse * shadowViewPosition).xyz",
              "vShadowMaterialId = int(mc_Entity.x + 0.5)"):
    if token not in shadow_vertex:
        errors.append(f"Iris shadow material/position interface is missing component: {token}")
for token in ("/* RENDERTARGETS: 0 */", "shadowcolor0Format = RGBA8",
              "uniform ivec3 cameraPositionInt;", "uniform vec3 cameraPositionFract;",
              "uniform float frameTimeCounter", "getStableShadowWorldPosition",
              "mod(cameraOffset + cameraPositionFract + playerPosition, vec3(256.0))",
              "vShadowMaterialId == 32000", "calculateWaterCaustics",
              "float causticsStrength = WATER_CAUSTICS_STRENGTH * 0.01",
              "return clamp(1.0 + (causticPattern - 1.0) * causticsStrength, 0.0, 1.0)",
              "vec3 absoluteWorldPosition = getStableShadowWorldPosition(vShadowPlayerPosition)",
              "float caustic = calculateWaterCaustics(absoluteWorldPosition)",
              "outShadowColor = vec4(vec3(caustic * 0.82, caustic * 0.92, caustic), 0.12)",
              "outShadowColor = vec4(1.0, 1.0, 1.0, 0.0)",
              "vShadowMaterialId == 30008", "vShadowMaterialId == 32001", "vShadowMaterialId >= 31000 && vShadowMaterialId <= 31031",
              "vShadowMaterialId == 32001 && materialAlpha < 0.999",
              "vShadowMaterialId == 32008 || vShadowMaterialId == 32012",
              "vShadowMaterialId == 32004", "vShadowMaterialId == 30020"):
    if token not in shadow_fragment:
        errors.append(f"Iris shadowcolor water caustics path is missing component: {token}")
for token in ("shadowTranslucent=true", "blend.shadow.shadowcolor0=off", "flip.shadow.shadowcolor0=false"):
    if token not in props:
        errors.append(f"Iris translucent shadowcolor configuration is missing: {token}")

deferred_options = sources.get("deferred.fsh", "")

for token in ("uniform sampler2DShadow shadowtex1", "uniform sampler2D shadowcolor0",
              "float centerShadow0 = texture(shadowtex0", "float centerShadow1 = texture(shadowtex1",
              "vec4 casterColor = texture(shadowcolor0, shadowPosition.xy)",
              "vec3 translucentTransmission = casterColor.rgb * (1.0 - casterColor.a)",
              "return clamp(", "vec3 shadow = vec3(1.0)"):
    if token not in deferred_options:
        errors.append(f"Deferred translucent shadow transmission is missing component: {token}")

if "/* RENDERTARGETS: 0 */" not in deferred_options or "outOpaqueReflectionScene" in deferred_options:
    errors.append("Full-resolution deferred must write only colortex0; the half-resolution water copy belongs in deferred1")
deferred1 = sources.get("deferred1.fsh", "")
for token in ("/* RENDERTARGETS: 4 */", "uniform sampler2D colortex0",
              "uniform sampler2D depthtex0", "uniform sampler2D depthtex2",
              "validCount", "step(0.5, validCount)", "outOpaqueSceneCopy = vec4("):
    if token not in deferred1:
        errors.append(f"Half-resolution deferred1 scene copy is missing component: {token}")
if "size.buffer.colortex4=0.5 0.5" not in props:
    errors.append("Water scene-copy attachment must be half resolution")
if "flip.deferred.colortex4=false" not in props or "flip.deferred1.colortex4=true" not in props:
    errors.append("Only deferred1 may flip the half-resolution colortex4 scene copy")
ao_strength_line = next((line for line in deferred_options.splitlines() if line.startswith("#define AO_STRENGTH ")), "")
if "0.65" not in ao_strength_line:
    errors.append("AO_STRENGTH option values must include the 0.65 profile preset")

terrain_vertex = sources.get("gbuffers_terrain.vsh", "")
for token in ("in vec2 mc_Entity", "flat out int vMaterialId", "vMaterialId = int(mc_Entity.x + 0.5)"):
    if token not in terrain_vertex:
        errors.append(f"Terrain vertex stage is missing Iris mc_Entity material classification: {token}")
# POM uses Iris per-quad sprite bounds and tangent attributes. Keep the implementation
# bounded, opt-out for Ultra-Light, and atlas-safe for terrain.
pom_source = sources.get("gbuffers_terrain.fsh", "")
for token in ("textureGrad(normals, sampleUv, uvDx, uvDy)", "textureSize(normals, 0)",
              "for (int stepIndex = 0; stepIndex < POM_QUALITY; ++stepIndex)",
              "POM_DISTANCE", "POM_STRENGTH", "currentSurfaceDepth",
              "spriteBounds.xy + hitLocal * tileSize", "appliedOffset"):
    if token not in pom_source:
        errors.append(f"Shared POM implementation is missing component: {token}")
for name in ("gbuffers_terrain.vsh", "gbuffers_block.vsh"):
    source = sources.get(name, "")
    for token in ("in vec2 mc_midTexCoord", "flat out vec4 vTexCoordAM",
                  "out vec3 vTangentView", "cross(viewTangent, viewNormal)",
                  "vec4(mc_midTexCoord, 0.0, 1.0)"):
        if token not in source:
            errors.append(f"{name} is missing Iris sprite-safe POM input: {token}")
for name in ("gbuffers_terrain.fsh", "gbuffers_block.fsh"):
    source = sources.get(name, "")
    for token in ("flat in vec4 vTexCoordAM", "in vec3 vTangentView", "calculateParallaxUv(",
                  "textureGrad(gtexture, parallaxUv, uvDx, uvDy)",
                  "parallaxAlbedo.a >= alphaTestRef",
                  "textureGrad(specular, materialUv, uvDx, uvDy)"):
        if token not in source:
            errors.append(f"{name} is missing POM integration: {token}")
if "gl_FrontFacing && !signText && blockEntityId != 5025" not in sources.get("gbuffers_block.fsh", ""):
    errors.append("Block-entity POM must skip sign text and Nether portal surfaces")
entity_pom_source = sources.get("gbuffers_entities.fsh", "")
for token in ("#define POM_ENTITY_STRENGTH 0", "uniform int entityId;",
              "calculateParallaxUv(", "entityId != 50128 && entityId != 50132",
              "textureGrad(gtexture, parallaxUv, uvDx, uvDy)",
              "parallaxAlbedo.a >= alphaTestRef",
              "textureGrad(specular, materialUv, uvDx, uvDy)",
              "textureGrad(normals, materialUv, uvDx, uvDy)"):
    if token not in entity_pom_source:
        errors.append(f"Entity POM is missing bounded atlas-safe component: {token}")
entity_vertex_source = sources.get("gbuffers_entities.vsh", "")
for token in ("in vec2 mc_midTexCoord", "out vec3 vTangentView",
              "flat out vec4 vTexCoordAM", "at_tangent.w"):
    if token not in entity_vertex_source:
        errors.append(f"Entity vertex stage is missing POM input: {token}")
entity_properties = (SHADERS / "entity.properties").read_text(encoding="utf-8")
for token in ("entity.50128=minecraft:item_frame", "entity.50132=minecraft:glow_item_frame"):
    if token not in entity_properties:
        errors.append(f"Entity POM exclusion mapping is missing: {token}")
for option in ("POM_QUALITY", "POM_DISTANCE"):
    definitions = []
    for name in ("gbuffers_terrain.fsh", "gbuffers_block.fsh", "gbuffers_entities.fsh"):
        definitions.extend(line.strip() for line in sources.get(name, "").splitlines()
                           if line.startswith(f"#define {option} "))
    if len(set(definitions)) != 1:
        errors.append(f"{option} must be defined identically in terrain, block and entity shaders")
if "POM_ENTITY_STRENGTH" not in props or "POM_ENTITY_STRENGTH" not in slider_options_line:
    errors.append("POM_ENTITY_STRENGTH must be exposed as an Iris Quality slider")
if "POM_ENTITY_STRENGTH:0" not in props or "POM_ENTITY_STRENGTH:20" not in props:
    errors.append("Entity POM must remain disabled in low-end profiles and opt-in for Ultra/HDR")
if "option.POM_ENTITY_STRENGTH.comment =" not in (SHADERS / "lang" / "en_us.lang").read_text(encoding="utf-8"):
    errors.append("Entity POM strength requires a user-facing tooltip")
entity_shader = sources.get("gbuffers_entities.fsh", "")
if "//#define ENTITY_GN_AND_CT" not in entity_shader:
    errors.append("Entity generated normals/coating must be disabled by default")
if entity_shader.count("#ifdef ENTITY_GN_AND_CT") != 2:
    errors.append("ENTITY_GN_AND_CT must gate both generated normals and coated textures")
if "ENTITY_GN_AND_CT" not in props.split("screen.QUALITY =", 1)[-1].splitlines()[0]:
    errors.append("ENTITY_GN_AND_CT must be exposed in the Quality settings screen")
if "option.ENTITY_GN_AND_CT.comment =" not in (SHADERS / "lang" / "en_us.lang").read_text(encoding="utf-8"):
    errors.append("ENTITY_GN_AND_CT requires a user-facing tooltip")


for name in ("gbuffers_terrain.fsh", "gbuffers_block.fsh", "gbuffers_entities.fsh"):
    source = sources.get(name, "")
    for token in ("#define GENERATED_NORMAL_STRENGTH 25",
                  "hasExplicitNormal = any(greaterThan(abs(normalTexel.rg - vec2(0.5)), vec2(0.01)))",
                  "calculateGeneratedAlbedoNormal(", "textureSize(gtexture, 0)",
                  "textureGrad(gtexture, rightUv, uvDx, uvDy)",
                  "textureGrad(gtexture, leftUv, uvDx, uvDy)",
                  "textureGrad(gtexture, upUv, uvDx, uvDy)",
                  "textureGrad(gtexture, downUv, uvDx, uvDy)",
                  "GENERATED_NORMAL_STRENGTH) * 0.025",
                  "albedoDetail > 0.002",
                  "min(min(rightSample.a, leftSample.a), min(upSample.a, downSample.a))"):
        if token not in source:
            errors.append(f"{name} is missing atlas-safe generated-normal component: {token}")
for name in ("gbuffers_terrain.fsh", "gbuffers_block.fsh", "gbuffers_entities.fsh"):
    source = sources.get(name, "")
    for token in ("#define COATED_TEXTURE_STRENGTH 20",
                  "vec3 applyCoatedTexture(", "textureLod(noisetex, noiseCoord, 0.0)",
                  "float mipLevel = max(0.0, log2(max(texelFootprint, 1.0)))",
                  "COATED_TEXTURE_STRENGTH) * 0.0027",
                  "cameraPositionInt", "cameraPositionFract"):
        if token not in source:
            errors.append(f"{name} is missing coated-texture component: {token}")
for name in ("gbuffers_terrain.fsh", "gbuffers_entities.fsh"):
    source = sources.get(name, "")
    for token in ("pbrEmission < 0.01", "materialReflectance < 0.8",
                  "materialSmoothness < 0.85"):
        if token not in source:
            errors.append(f"{name} must exclude emissive/glossy PBR surfaces from coating: {token}")
if "fallbackEmissiveMaterial" not in sources.get("gbuffers_terrain.fsh", ""):
    errors.append("Terrain coating must skip built-in emissive material IDs")
block_coat_source = sources.get("gbuffers_block.fsh", "")
for token in ("pbrEmission < 0.01", "materialReflectance < 0.8",
              "materialCoatingFactor > 0.0", "if (!signText && blockEntityId != 5025 && albedo.a >= 0.999"):
    if token not in block_coat_source:
        errors.append(f"Block-entity coating is missing reference priority condition: {token}")
if "&& !hasMaterialSpecularMap &&" in block_coat_source:
    errors.append("Block-entity coating must remain available when a non-emissive PBR specular map is present")
for token in ("materialCoatingFactor = 0.66", "materialCoatingFactor = 0.2",
              "materialCoatingFactor = 0.33", "materialCoatingFactor = 0.77",
              "materialCoatingFactor = 0.5"):
    if token not in block_coat_source:
        errors.append(f"Block-entity material-specific coating factor is missing: {token}")
if "out vec3 vPlayerPosition;" not in sources.get("gbuffers_block.vsh", "") or "vPlayerPosition = (gbufferModelViewInverse * viewPosition).xyz;" not in sources.get("gbuffers_block.vsh", ""):
    errors.append("Block-entity vertex stage must provide stable player-relative position for coated texture noise")
for token in ("uniform int blockEntityId;", "uniform vec3 cameraPositionFract;",
              "fract(vPlayerPosition.y + cameraPositionFract.y)",
              "if (fractWorldPosY > 0.56 && fractWorldPosY < 0.57)",
              "gl_Position.z -= 0.0001"):
    if token not in sources.get("gbuffers_block.vsh", ""):
        errors.append(f"Block-entity chest seam correction is missing: {token}")

if "out vec3 vPlayerPosition;" not in sources.get("gbuffers_entities.vsh", "") or "vPlayerPosition = (gbufferModelViewInverse * viewPosition).xyz;" not in sources.get("gbuffers_entities.vsh", ""):
    errors.append("Entity vertex stage must provide stable player-relative position for coated texture noise")
if "in vec3 vPlayerPosition;" not in sources.get("gbuffers_entities.fsh", ""):
    errors.append("Entity fragment stage must receive player-relative position for coated texture noise")
if "in vec3 vPlayerPosition;" not in sources.get("gbuffers_block.fsh", ""):
    errors.append("Block-entity fragment stage must receive player-relative position for coated texture noise")
if "COATED_TEXTURE_STRENGTH" not in props or "COATED_TEXTURE_STRENGTH" not in slider_options_line:
    errors.append("COATED_TEXTURE_STRENGTH must be exposed as an Iris Quality slider")
if "COATED_TEXTURE_STRENGTH:0" not in props:
    errors.append("Ultra-Light profile must disable coated textures")
if "option.COATED_TEXTURE_STRENGTH.comment =" not in (SHADERS / "lang" / "en_us.lang").read_text(encoding="utf-8"):
    errors.append("Coated texture strength requires a user-facing tooltip")

if "GENERATED_NORMAL_STRENGTH" not in props or "GENERATED_NORMAL_STRENGTH" not in slider_options_line:
    errors.append("GENERATED_NORMAL_STRENGTH must be exposed as an Iris Quality slider")
if "GENERATED_NORMAL_STRENGTH:0" not in props:
    errors.append("Ultra-Light profile must disable generated normals")
if "option.GENERATED_NORMAL_STRENGTH.comment =" not in (SHADERS / "lang" / "en_us.lang").read_text(encoding="utf-8"):
    errors.append("Generated normal strength requires a user-facing tooltip")

for option in ("POM_STRENGTH", "POM_QUALITY", "POM_DISTANCE"):
    if option not in props or option not in slider_options_line:
        errors.append(f"{option} must be exposed as an Iris Quality slider")
if "POM_STRENGTH:0" not in props or "POM_QUALITY:4" not in props:
    errors.append("Ultra-Light profile must disable POM and use the minimum sample count")
if "option.POM_STRENGTH.comment =" not in (SHADERS / "lang" / "en_us.lang").read_text(encoding="utf-8"):
    errors.append("POM strength requires a user-facing tooltip")

terrain_fragment = sources.get("gbuffers_terrain.fsh", "")
for token in ("uniform sampler2D specular", "textureGrad(specular, materialUv, uvDx, uvDy)",
              "MC_TEXTURE_FORMAT_LAB_PBR", "pbrSpecular.r", "pbrSpecular.g",
              "pbrSpecular.a", "pbrSpecular.b", "materialSmoothness"):
    if token not in terrain_fragment:
        errors.append(f"Terrain PBR specular/emissive decode is missing component: {token}")
for token in ("flat in int vMaterialId", "emissionStrength", "materialAO", "materialSurfaceData", "outEmissionData = vec4(emissionStrength / 5.0, materialReflectance, materialAO, materialSurfaceData)"):
    if token not in terrain_fragment:
        errors.append(f"Terrain G-buffer is missing emissive material output: {token}")
for token in ("in vec3 vPlayerPosition", "uniform sampler2D noisetex",
              "uniform ivec3 cameraPositionInt", "uniform vec3 cameraPositionFract",
              "uniform float frameTimeCounter", "uniform float wetness", "uniform float rainStrength",
              "uniform float rainfall", "uniform int biome_precipitation", "biome_precipitation == 1",
              "#define RAIN_PUDDLE_STRENGTH 70", "#define MATERIAL_WETNESS_STRENGTH 100",
              "materialPorosity = clamp(labSurfaceCode / 64.0, 0.0, 1.0)",
              "float porousWetness = clamp(", "materialReflectance *= 1.0 - porousWetness * 0.45",
              "materialSmoothness *= 1.0 - porousWetness * 0.35",
              "puddleLightFactor", "puddleNormalFactor", "puddleForm",
              "float puddleTime = mod(frameTimeCounter, 60.0)",
              "materialPorosity", "puddleMask", "puddleSmoothness",
              "vec3 bitangent = normalize(cross(tangent, surfaceNormal))",
              "vMaterialId == 10009 || vMaterialId == 10011 || vMaterialId == 10129 || vMaterialId == 10137"):
    if token not in terrain_fragment:
        errors.append(f"Terrain rain-puddle path is missing component: {token}")
for token in ("out vec3 vPlayerPosition", "vPlayerPosition = (gbufferModelViewInverse * viewPosition).xyz"):
    if token not in terrain_vertex:
        errors.append(f"Terrain vertex stage is missing stable player-space position: {token}")

# LabPBR blue values 65-255 encode SSS only for non-metals. Metal IDs
# reserve this channel, so opaque entity/block-entity paths must clear it.
for name in ("gbuffers_entities.fsh", "gbuffers_block.fsh"):
    source = sources.get(name, "")
    metal_branch = re.search(
        r"else if \(labF0Code >= 230\.0\) \{([^}]*)\}", source
    )
    if not metal_branch or "materialSurfaceData = 0.0;" not in metal_branch.group(1):
        errors.append(f"{name} must clear reserved LabPBR blue-channel data for metals")

block_properties = (SHADERS / "block.properties").read_text(encoding="utf-8")
for token in ("block.30012=minecraft:slime_block", "block.30016=minecraft:honey_block",
              "block.32100=minecraft:glowstone", "block.32118=minecraft:lava",
              "block.5004=minecraft:oak_sign", "block.5025=minecraft:end_portal",
              "block.5008=minecraft:chest", "block.5012=minecraft:ender_chest",
              "block.5016=minecraft:shulker_box", "block.5020=minecraft:conduit",
              "block.5028=minecraft:bell", "block.5032=minecraft:copper_chest",
              "block.5036=minecraft:white_banner", "block.10548=minecraft:enchanting_table",
              "block.10009=leaves:waterlogged=false", "block.10011=leaves:waterlogged=true",
              "block.10129=farmland:moisture=0", "block.10137=farmland:moisture=7"):
    if token not in block_properties:
        errors.append(f"Missing emissive/block-entity ID mapping: {token}")

# Iris uses signed 16-bit IDs and each exact block-state identifier can map once.
mapped_blocks = {}
for line_number, raw_line in enumerate(block_properties.splitlines(), 1):
    mapping = re.match(r"^\s*block\.(-?\d+)\s*=\s*(.*?)\s*$", raw_line.split("#", 1)[0])
    if not mapping:
        continue
    numeric_id = int(mapping.group(1))
    if not -32768 <= numeric_id <= 32767:
        errors.append(f"block.properties line {line_number} uses out-of-range Iris ID {numeric_id}")
    for identifier in mapping.group(2).split():
        normalized = identifier if identifier.startswith("minecraft:") else "minecraft:" + identifier
        previous = mapped_blocks.get(normalized)
        if previous is not None and previous[0] != numeric_id:
            errors.append(f"Block identifier {normalized} is assigned to IDs {previous[0]} and {numeric_id}")
        else:
            mapped_blocks[normalized] = (numeric_id, line_number)

for token in (
    "minecraft:trapped_chest", "minecraft:ender_chest",
    "minecraft:white_shulker_box", "minecraft:dragon_head", "minecraft:black_bed",
    "minecraft:conduit", "minecraft:bell", "minecraft:copper_golem_statue",
    "minecraft:waxed_oxidized_copper_chest", "minecraft:black_wall_banner",
    "minecraft:enchanting_table",
):
    if token not in block_properties:
        errors.append(f"Complementary block-entity mapping is missing {token}")
block_entity_source = sources.get("gbuffers_block.fsh", "")
for token in (
    "blockEntityId == 5008", "blockEntityId == 5012", "blockEntityId == 5016",
    "blockEntityId == 5020", "blockEntityId == 5028", "blockEntityId == 5032",
    "blockEntityId == 5036", "blockEntityId == 10548",
    "vanillaLight = texture(lightmap, vec2(0.9, vLightmapCoord.y))",
    "albedo.r * 16.0", "emissionStrength = max(emissionStrength, 20.0)",
    "skipGeneratedNormals = signText || blockEntityId == 5036",
):
    if token not in block_entity_source:
        errors.append(f"Block-entity material dispatch is missing reference component: {token}")
if "minecraft:flowing_lava" in block_properties:
    errors.append("Remove legacy flowing_lava block ID; Minecraft 1.13+ uses minecraft:lava block states")

for name in ("gbuffers_terrain.fsh", "gbuffers_entities.fsh", "gbuffers_block.fsh", "gbuffers_particles.fsh", "gbuffers_textured_lit.fsh"):
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
    if "if (!gl_FrontFacing) surfaceNormal = -surfaceNormal;" not in source:
        errors.append(f"{name} must orient back-face normals before deferred lighting")
    if name not in ("gbuffers_terrain.fsh", "gbuffers_entities.fsh", "gbuffers_block.fsh", "gbuffers_particles.fsh", "gbuffers_textured_lit.fsh") and "outEmissionData = vec4(0.0)" not in source:
        errors.append(f"{name} must initialize the emissive attachment for non-emissive G-buffer materials")
if "float emissionStrength = 0.0;" not in sources.get("gbuffers_block.fsh", ""):
    errors.append("Block-entity emission must default to zero unless an emissive blockEntityId is detected")
for token in ("vMaterialId == 30012", "vMaterialId == 30016",
              "0.5 + 0.5 * materialSmoothness"):
    if token not in terrain_fragment:
        errors.append(f"Terrain smoothness packing is missing component: {token}")
for name in ("gbuffers_entities.fsh", "gbuffers_block.fsh", "gbuffers_particles.fsh", "gbuffers_textured_lit.fsh"):
    source = sources.get(name, "")
    if "outEncodedNormal = vec4(surfaceNormal * 0.5 + 0.5, 0.5 + 0.5 * materialSmoothness)" not in source and name == "gbuffers_entities.fsh":
        errors.append(f"{name} must encode valid zero-smoothness geometry as colortex2 alpha 0.5")
if "signText ? 0.0 : 0.5 + 0.5 * materialSmoothness" not in sources.get("gbuffers_block.fsh", ""):
    errors.append("Block-entity validity/smoothness alpha must keep sign text invalid and normal geometry at 0.5")
for name in ("gbuffers_terrain.fsh", "gbuffers_entities.fsh", "gbuffers_block.fsh"):
    source = sources.get(name, "")
    if "materialReflectance = labF0Code / 255.0;" not in source or "materialReflectance = 0.04;" not in source or "materialReflectance = 0.45;" in source:
        errors.append(f"{name} must store linear LabPBR F0 and use a 0.04 dielectric fallback")
for name in ("gbuffers_terrain.vsh", "gbuffers_entities.vsh", "gbuffers_block.vsh", "gbuffers_water.vsh"):
    vertex_source = sources.get(name, "")
    if "in vec4 at_tangent;" not in vertex_source or "at_tangent.w" not in vertex_source:
        errors.append(f"{name} must declare and use Iris at_tangent with handedness")

if sources.get("deferred.fsh", "").count("ambient *= materialAOFactor") != 1:
    errors.append("Material AO must be applied exactly once to deferred ambient")
if "ambient * materialAOFactor + direct" in sources.get("deferred.fsh", ""):
    errors.append("Material AO must not be applied twice in the final diffuse expression")
for name in ("gbuffers_entities.fsh", "gbuffers_block.fsh"):
    source = sources.get(name, "")
    for token in ("uniform sampler2D specular;",
                  "float materialSmoothness = clamp(pbrSpecular.r, 0.0, 1.0)",
                  "materialReflectance", "pbrEmission",
                  "outEmissionData = vec4("):
        if token not in source:
            errors.append(f"{name} is missing resource-pack PBR specular support: {token}")
    specular_sample = "textureGrad(specular, materialUv, uvDx, uvDy)" if name in ("gbuffers_block.fsh", "gbuffers_entities.fsh") else "texture(specular, vTexCoord)"
    if specular_sample not in source:
        errors.append(f"{name} must sample specular data at the active material UV")
for fragment_name in ("gbuffers_terrain.fsh", "gbuffers_entities.fsh", "gbuffers_block.fsh"):
    source = sources.get(fragment_name, "")
    normal_sample = "textureGrad(normals, materialUv, uvDx, uvDy)" if fragment_name in ("gbuffers_terrain.fsh", "gbuffers_block.fsh", "gbuffers_entities.fsh") else "texture(normals, vTexCoord)"
    if normal_sample not in source:
        errors.append(f"{fragment_name} must sample its PBR normal map at the active material UV")
for fragment_name in ("gbuffers_terrain.fsh", "gbuffers_entities.fsh", "gbuffers_block.fsh"):
    if "vanillaLight *= pow(max(materialAO" in sources.get(fragment_name, ""):
        errors.append(f"{fragment_name} must not bake PBR AO into the lightmap; deferred applies it to ambient only")
for vertex_name in ("gbuffers_terrain.vsh", "gbuffers_entities.vsh", "gbuffers_block.vsh"):
    source = sources.get(vertex_name, "")
    if source.count("in vec4 at_tangent;") != 1:
        errors.append(f"{vertex_name} must declare at_tangent exactly once")
    if source.count("vPlayerTangent = normalize") != 1:
        errors.append(f"{vertex_name} must transform the tangent exactly once")
    for token in ("in vec4 at_tangent;", "out vec3 vPlayerTangent;", "flat out float vTangentHandedness;",
                  "vPlayerTangent = normalize(mat3(gbufferModelViewInverse) * viewTangent)",
                  "vTangentHandedness = at_tangent.w < 0.0 ? -1.0 : 1.0"):
        if token not in source:
            errors.append(f"{vertex_name} is missing Iris tangent basis component: {token}")
for fragment_name in ("gbuffers_terrain.fsh", "gbuffers_entities.fsh", "gbuffers_block.fsh"):
    source = sources.get(fragment_name, "")
    for token in ("uniform sampler2D normals;", "in vec3 vPlayerTangent;", "flat in float vTangentHandedness;",
                  "calculateOpaquePbrNormal", "PBR_AO_STRENGTH", "normalTexel.b", "materialAO = mix(1.0, clamp(normalTexel.b, 0.0, 1.0)", 
                  "tangentNormal.z = sqrt(max(1.0 - dot(tangentNormal.xy, tangentNormal.xy), 0.0))",
                  "cross(tangent, geometricNormal)", "OPAQUE_NORMAL_MAP_STRENGTH"):
        if token not in source:
            errors.append(f"{fragment_name} is missing opaque PBR normal-map component: {token}")
if "surfaceNormal = calculateOpaquePbrNormal(surfaceNormal, materialUv, uvDx, uvDy, materialAO, hasExplicitNormal)" not in sources.get("gbuffers_terrain.fsh", ""):
    errors.append("Terrain must apply resource-pack tangent-space normal maps")
if "surfaceNormal = calculateOpaquePbrNormal(surfaceNormal, materialUv, uvDx, uvDy, materialAO, hasExplicitNormal)" not in sources.get("gbuffers_entities.fsh", ""):
    errors.append("Entities must apply resource-pack tangent-space normal maps")
if "if (!signText) surfaceNormal = calculateOpaquePbrNormal(surfaceNormal, materialUv, uvDx, uvDy, materialAO, hasExplicitNormal)" not in sources.get("gbuffers_block.fsh", ""):
    errors.append("Block entities must apply resource-pack normal maps without perturbing sign text")


for token in ("#define MATERIAL_AO_STRENGTH 100", "#define MATERIAL_SSS_STRENGTH 100",
              "float materialAO = clamp(emissionData.b, 0.0, 1.0)",
              "mix(1.0, materialAO, MATERIAL_AO_STRENGTH * 0.01)",
              "ambient *= materialAOFactor",
              "vec3 litLinear = albedoLinear * (ambient + direct)",
              "float materialSurfaceCode = floor(emissionData.a * 255.0 + 0.5)",
              "materialSSS = clamp((materialSurfaceCode - 65.0) / 190.0, 0.0, 1.0)",
              "mix(shadow, vec3(1.0), sssStrength * 0.65)"):
    if token not in sources.get("deferred.fsh", ""):
        errors.append(f"Deferred material AO/SSS path is missing: {token}")
for name in ("gbuffers_entities.fsh", "gbuffers_block.fsh"):
    source = sources.get(name, "")
    if "outEmissionData = vec4(pbrEmission, materialReflectance, materialAO, materialSurfaceData)" not in source and name == "gbuffers_entities.fsh":
        errors.append("Entity G-buffer must pack emission, reflectance, material AO and SSS data")
    if "outEmissionData = vec4(emissionStrength / 5.0, materialReflectance, materialAO, materialSurfaceData)" not in source and name == "gbuffers_block.fsh":
        errors.append("Block-entity G-buffer must pack emission, reflectance, material AO and SSS data")
for name in ("gbuffers_terrain.fsh", "gbuffers_entities.fsh", "gbuffers_block.fsh",
             "gbuffers_particles.fsh", "gbuffers_textured_lit.fsh"):
    if "outLightmapData = vec4(vanillaLight, skyLight);" not in sources.get(name, ""):
        errors.append(f"{name} must write vanilla lightmap RGB and sky-light factor to colortex1")

for name in ("gbuffers_terrain.fsh", "gbuffers_entities.fsh", "gbuffers_block.fsh"):
    source = sources.get(name, "")
    if source.find("float skyLight =") < 0 or source.find("outLightmapData = vec4(vanillaLight, skyLight)") < source.find("float skyLight ="):
        errors.append(f"{name} must initialize skyLight before writing the vanilla lightmap G-buffer")

for name in ("gbuffers_particles.fsh", "gbuffers_textured_lit.fsh"):
    if "outEmissionData = vec4(emissionStrength / 5.0, defaultReflectance, 1.0, 0.0)" not in sources.get(name, ""):
        errors.append(f"{name} must initialize neutral PBR reflectance/AO/SSS channels")

opaque_particles = sources.get("gbuffers_particles.fsh", "")
for token in ("PARTICLE_MATERIAL_FEATURES", "float(textureSize(gtexture, 0).x) < 1100.0",
              "emissionStrength = clamp(particle.r * 8.0, 1.6, 5.0)",
              "emissionStrength = 2.0", "suppressLightmap",
              "outEmissionData = vec4(emissionStrength / 5.0, defaultReflectance, 1.0, 0.0)"):
    if token not in opaque_particles:
        errors.append(f"Opaque particle emissive path is missing component: {token}")

particle_reference_tokens = (
    "float dotColor = dot(particle.rgb, particle.rgb)",
    "dotColor > 0.25 && particle.g < 0.5",
    "particle.b > particle.r * 1.1 && particle.r > 0.3",
    "particle.r > (particle.g + particle.b) * 3.0",
    "particle.r > 0.83 && particle.g > 0.23 && particle.b < 0.4",
    "particle.b *= 0.5",
    "particle.r *= 1.2"
)
for name in ("gbuffers_particles.fsh", "gbuffers_textured_lit.fsh"):
    source = sources.get(name, "")
    for token in particle_reference_tokens:
        if token not in source:
            errors.append(f"{name} diverges from the Complementary particle-emission reference: {token}")
    if "particleColorSum" in source or "particleTexture.r < 0.75" in source:
        errors.append(f"{name} contains the superseded broad grayscale-emission classifier")


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
water_vertex = (SHADERS / "gbuffers_water.vsh").read_text(encoding="utf-8")
for token in ("/* RENDERTARGETS: 0 */", "sampler2DShadow shadowtex0",
              "shadowModelView", "shadowProjection", "sampleTranslucentShadow",
              "uniform vec3 fogColor", "uniform float fogDensity", "calculateTranslucentFog",
              "texture(gtexture", "texture(lightmap", "depthtex1", "calculateWaterThickness",
              "uniform sampler2D colortex4", "texture(colortex4", "WATER_REFRACTION_STRENGTH",
              "WATER_REFLECTION_STRENGTH", "WATER_REFLECTION_QUALITY", "sampleTranslucentScreenReflection(",
              "WATER_FOG_MULT", "uniform float alphaTestRef",
              "translucentAlbedo.a < alphaTestRef", "vMaterialId == 32000",
              "opaqueDepth) * 2.0 - 1.0", "texelFetch(depthtex1, ivec2(gl_FragCoord.xy), 0)",
              "gl_FragCoord.xy / vec2(textureSize(depthtex1, 0))",
              "refractedScene.a >= 0.5", "texelFetch(depthtex1, refractedPixel, 0)",
              "if (isWater && dot(normalize(vViewPosition), viewNormal) > 0.0)",
              "translucentAlbedo.a = 0.98",
              "translucentAlbedo.a *= 0.75",
              "float waterAlpha = translucentAlbedo.a * (0.25 + 0.75 * waterFog)",
              "outColor = vec4(litColor, translucentAlbedo.a)"):
    if token not in water:
        errors.append(f"Forward translucent-terrain shader is missing Iris-compatible component: {token}")

for token in ("uniform sampler2D depthtex2", "uniform mat4 gbufferProjection",
              "uniform mat4 gbufferProjectionInverse", "WATER_REFLECTION_QUALITY",
              "sampleTranslucentScreenReflection(", "for (int refineStep = 0; refineStep < 2; ++refineStep)", "refineLow", "refineHigh", "i > 0 && sceneSample.a >= 0.5", "texelFetch(depthtex2, depthPixel, 0)",
              "texelFetch(colortex4, reflectionPixel, 0)",
              "float fresnel = 0.02 + 0.98 * pow(1.0 - nDotV, 5.0)",
              "float reflectionWeight = clamp(",
              "min(fresnel * 2.5, 0.85) * WATER_REFLECTION_STRENGTH",):
    if token not in water:
        errors.append(f"Water screen-space reflection path is missing component: {token}")
for token in ("uniform vec3 skyColor;", "vec3 sampleEnvironmentReflection(vec3 viewReflectionDirection)",
              "mix(fogColor, skyColor, skyBlend)", "float materialReflectionScale = isIce ? 0.55 : (isTintedGlass ? 0.65 : ((isClearGlass || isStainedGlass) ? 0.50 : 0.32))",
              "glassReflectionLinear = mix(",
              "glassEnvironmentLinear, glassScreenReflectionLinear, glassReflectionConfidence",
              "environmentReflectionLinear, screenReflectionLinear, reflectionConfidence"):
    if token not in water:
        errors.append(f"Translucent environment-reflection fallback is missing component: {token}")
if "uniform sampler2D colortex0" in water:
    errors.append("gbuffers_water must not sample colortex0 while writing colortex0")
for token in ("uniform sampler2DShadow shadowtex1", "uniform sampler2D shadowcolor0",
              "vec3 sampleTranslucentShadow(", "float centerShadow0 = texture(shadowtex0",
              "float centerShadow1 = texture(shadowtex1",
              "vec4 casterColor = texture(shadowcolor0, shadowPosition.xy)",
              "vec3 shadow = vec3(1.0)"):
    if token not in water:
        errors.append(f"Forward translucent colored-shadow path is missing component: {token}")
for token in ("WATER_ABSORPTION_STRENGTH", "waterThickness = calculateWaterThickness(opaqueViewPosition, opaqueDepth)",
              "float waterFogThickness = waterThickness * (WATER_FOG_MULT * 0.01)",
              "exp(-waterFogThickness * 0.075)",
              "vec3 absorptionCoefficient = vec3(0.12, 0.045, 0.018)",
              "vec3 transmission = exp(-absorptionCoefficient * waterThickness)",
              "waterAbsorptionTintLinear * (1.0 - transmission)"):
    if token not in water:
        errors.append(f"Unbound-guided depth absorption path is missing component: {token}")
for token in ("uniform int isEyeInWater", "bool cameraUnderwater = (isEyeInWater == 1)",
              "if ((isWater && cameraUnderwater) || isPortal) direct = vec3(0.0)",
              "(cameraUnderwater ? 0.5 : 1.0)", "WATER_UNDERWATER_STRENGTH"):
    if token not in water:
        errors.append(f"Unbound-guided underwater water response is missing component: {token}")
for token in ("WATER_FOAM_STRENGTH", "textureLod(noisetex, foamNoiseUV, 0.0)",
              "float foamThreshold = mix(0.06, 0.42, foamNoise * foamNoise)",
              "float shallowFoam = 1.0 - smoothstep(0.035, foamThreshold, waterThickness)",
              "waterFoamColor",
              "waterFoam = shallowFoam * (hasSkylight ? (0.4 + 0.25 * skyLight) : 0.6)",
              "(1.0 - waterFoam)"):
    if token not in water:
        errors.append(f"Unbound-guided water foam path is missing component: {token}")
for token in ("flat in vec2 vMidTexCoord", "flat in vec2 vTexHalfSize",
              "PORTAL_DISTORTION_STRENGTH", "frameTimeCounter * (6.28318530718 * 458.0 / 3600.0)",
              "textureSize(gtexture, 0)",
              "portalMinUV", "portalMaxUV", "textureLod(gtexture, portalUV, 0.0)"):
    if token not in water:
        errors.append(f"Atlas-safe portal distortion path is missing component: {token}")
for token in ("vMaterialId == 32008", "vMaterialId == 32001", "vMaterialId >= 31000 && vMaterialId <= 31031",
              "vMaterialId == 30008", "vMaterialId == 30020", "vMaterialId == 32004",
              "sampleTranslucentScreenReflection(", "GLASS_REFLECTION_STRENGTH",
              "PORTAL_EMISSION_STRENGTH", "float portalEmissionSignal = 0.0", "portalEmissionSignal = max(translucentAlbedo.r, 0.0)", "float portalEmission = isPortal"):
    if token not in water:
        errors.append(f"Unbound-guided translucent material path is missing component: {token}")
for token in ("block.30008=minecraft:tinted_glass", "block.30020=minecraft:nether_portal portal",
              "block.31000=minecraft:white_stained_glass", "block.31031=minecraft:black_stained_glass_pane",
              "block.32000=minecraft:water flowing_water",
              "block.32004=minecraft:ice minecraft:frosted_ice brittle_ice",
              "block.32008=minecraft:glass", "block.32012=minecraft:glass_pane",
              "block.5004=minecraft:oak_sign", "block.5025=minecraft:end_portal minecraft:end_gateway"):
    if token not in block_properties:
        errors.append(f"Missing Iris translucent material ID mapping: {token}")
if "uniform int isEyeInWater;" not in water:
    errors.append("Water pass must declare Iris isEyeInWater as int")

if "return 0.03125 * (stableWorldPosition.xz + stableWorldPosition.y * 2.0);" not in water:
    errors.append("Water noise coordinates must tile the 2560-block stable-world period exactly")
# The optional 0.05 octave must also land on an integer number of repeats at
# the camera-position wrap. This prevents a visible phase jump at the seam.
water_period = 2560.0 * 0.03125
for octave in (1.0, 4.0, 0.25, 0.05):
    repeats = water_period * octave
    if abs(repeats - round(repeats)) > 1e-6:
        errors.append(f"Water normal octave {octave} does not tile the stable-world period")
for wave_speed in (15, 30, 45, 60, 75, 90, 120):
    for wind_multiplier in (40.0, 80.0, 20.0, 20.0):
        wrapped_cycles = wave_speed * 0.01 * wind_multiplier
        if abs(wrapped_cycles - round(wrapped_cycles)) > 1e-6:
            errors.append(f"Water wind speed {wave_speed} causes a timer-wrap phase discontinuity")
for wave_scale in (50, 75, 100, 125, 150, 200):
    base_repeats = 2560.0 * 0.03125 * wave_scale * 0.01
    for octave in (1.0, 4.0, 0.25, 0.05):
        repeats = base_repeats * octave
        if abs(repeats - round(repeats)) > 1e-6:
            errors.append(f"Water wave scale {wave_scale} does not tile octave {octave}")

for token in ("uniform sampler2D noisetex", "calculateWaterBaseColor", "textureLod(noisetex, noiseUV, 0.0)",
              "vec3 baseColor = 0.375 * biomeTint", "WATER_COLOR_STRENGTH", "WATER_NOISE_COLOR_STRENGTH", "WATER_FOAM_STRENGTH", "WATER_UNDERWATER_STRENGTH", "WATER_ABSORPTION_STRENGTH", "GLASS_REFLECTION_STRENGTH", "PORTAL_EMISSION_STRENGTH", "PORTAL_DISTORTION_STRENGTH"):
    if token not in water:
        errors.append(f"Unbound-style water colour path is missing component: {token}")

for token in ("uniform sampler2D normals;", "calculateTranslucentNormalMap", "normalMapStrength * 0.01",
              "calculateTranslucentNormalMap(normal, GLASS_NORMAL_MAP_STRENGTH)",
              "else if (isClearGlass || isStainedGlass || isTintedGlass || isIce)",
              "texture(normals, vTexCoord)", "MC_TEXTURE_FORMAT_LAB_PBR",
              "vec4 normalTexel = texture(normals, vTexCoord)",
              "tangentNormal.z = sqrt(max(1.0 - dot(tangentNormal.xy, tangentNormal.xy), 0.0))",
              "tangentNormal.y = -tangentNormal.y", "cross(tangent, geometricNormal)",
              "vPlayerTangent", "vTangentHandedness", "at_tangent.w < 0.0 ? -1.0 : 1.0"):
    if token not in water and token not in water_vertex:
        errors.append(f"Water resource-pack normal-map path is missing component: {token}")
for token in ("uniform mat4 gbufferModelView;", "uniform ivec3 cameraPositionInt;",
              "uniform vec3 cameraPositionFract;", "uniform float frameTimeCounter",
              "getStableWaterWorldPosition", "cameraPositionInt % ivec3(2560)",
              "mod(vec3(cameraModulo), vec3(2560.0))",
              "cameraPositionFract + playerPosition", "calculateWaterWaveNormal",
              "uniform sampler2D waterNormalTex;",
              "waterNormalTex, waterCoord + wind, waterCoordDx, waterCoordDy",
              "waterCoord * 4.0 - wind * 2.0", "waterCoord * 0.25 - wind * 0.5",
              "float waveCycles = frameTimeCounter / 3600.0", "waveCycles * 40.0",
              "WATER_WAVE_SCALE <= 0",
              "#if WATER_WAVE_DETAIL > 0", "waterCoord * 0.05 - wind * 0.5",
              "geometricNormal + vec3(-slope.x * strength * faceSign",
              "waterNormalCoordDx = dFdx(vPlayerPosition.xz * waterNormalScale)",
              "viewNormal = normalize(mat3(gbufferModelView) * normal)"):
    if token not in water:
        errors.append(f"Unbound-guided multi-scale water normal path is missing component: {token}")
water_normal_path = SHADERS / "lib" / "textures" / "water-normal.png"
water_normal_meta = SHADERS / "lib" / "textures" / "water-normal.png.mcmeta"
if not water_normal_path.is_file() or not water_normal_meta.is_file():
    errors.append("Water normal custom texture and blur/wrap metadata must both exist")
if "customTexture.waterNormalTex = lib/textures/water-normal.png" not in props:
    errors.append("Iris customTexture binding for the water normal map is missing")
if "WATER_WAVE_DETAIL" not in props or "WATER_WAVE_DETAIL" not in props.split("sliders =", 1)[-1]:
    errors.append("Very-large water wave detail must be exposed as a Quality slider")
for profile in ("Ultra-Light", "Smooth"):
    profile_line = next((line for line in props.splitlines() if line.startswith(f"profile.{profile} =")), "")
    if "WATER_WAVE_DETAIL:0" not in profile_line:
        errors.append(f"{profile} must disable the extra very-large water-normal sample")
for profile in ("Ultra", "HDR", "Ultra-HDR"):
    profile_line = next((line for line in props.splitlines() if line.startswith(f"profile.{profile} =")), "")
    if "WATER_WAVE_DETAIL:1" not in profile_line:
        errors.append(f"{profile} must enable the optional very-large Unbound water-normal octave")
ultra_light_profile = next((line for line in props.splitlines() if line.startswith("profile.Ultra-Light =")), "")
smooth_profile = next((line for line in props.splitlines() if line.startswith("profile.Smooth =")), "")
ultra_profile = next((line for line in props.splitlines() if line.startswith("profile.Ultra =")), "")
for token in ("WATER_WAVE_STRENGTH:25", "WATER_WAVE_DETAIL:0", "WATER_CAUSTICS_STRENGTH:25",
              "WATER_FOAM_STRENGTH:25", "PBR_REFLECTION_STRENGTH:25", "PBR_REFLECTION_QUALITY:4",
              "AO_STRENGTH:0.40", "MATERIAL_SSS_STRENGTH:25"):
    if token not in ultra_light_profile:
        errors.append(f"Ultra-Light profile is missing low-cost setting: {token}")
for token in ("WATER_WAVE_STRENGTH:75", "WATER_WAVE_DETAIL:0", "WATER_CAUSTICS_STRENGTH:60",
              "WATER_FOAM_STRENGTH:60", "PBR_REFLECTION_STRENGTH:50", "AO_STRENGTH:0.55"):
    if token not in smooth_profile:
        errors.append(f"Smooth profile is missing balanced setting: {token}")
for token in ("WATER_WAVE_DETAIL:1", "POM_ENTITY_STRENGTH:20", "PBR_REFLECTION_QUALITY:8"):
    if token not in ultra_profile:
        errors.append(f"Ultra profile is missing high-quality setting: {token}")
if "option.WATER_WAVE_DETAIL.comment =" not in (SHADERS / "lang" / "en_us.lang").read_text(encoding="utf-8"):
    errors.append("Very-large water wave detail requires a user-facing tooltip")
if "cross(geometricNormal, tangent)" in water:
    errors.append("Water tangent basis must follow Iris at_tangent handedness: cross(tangent, normal)")
if "uniform vec3 cameraPosition;" in water:
    errors.append("Water waves must avoid Iris cameraPosition's 30,000-block wrap")
if "vec3 shadowNormal = normal;" not in water or "sampleTranslucentShadow(vPlayerPosition, shadowNormal, worldLightDirection)" not in water:
    errors.append("Water wave perturbation must not alter geometric shadow-map bias")
if "vec3 reflectionViewNormal = viewNormal;" not in water:
    errors.append("Water SSR must reuse the wave-perturbed view-space normal")
if "out vec3 vViewNormal" not in water_vertex or "vViewNormal = viewNormal" not in water_vertex:
    errors.append("Water vertex stage must output the Iris view-space normal used by Fresnel reflection")
water_options = ("WATER_REFLECTION_QUALITY", "WATER_REFRACTION_STRENGTH", "WATER_REFLECTION_STRENGTH",
                 "WATER_NORMAL_MAP_STRENGTH", "GLASS_NORMAL_MAP_STRENGTH", "WATER_WAVE_STRENGTH", "WATER_WAVE_SPEED", "WATER_WAVE_SCALE", "WATER_CAUSTICS_STRENGTH", "WATER_CAUSTICS_SCALE", "WATER_COLOR_STRENGTH", "WATER_NOISE_COLOR_STRENGTH")
lang = (SHADERS / "lang" / "en_us.lang").read_text(encoding="utf-8")
for option in water_options:
    if option not in props.split("screen.QUALITY =", 1)[-1].splitlines()[0]:
        errors.append(f"{option} must be exposed in the Iris Quality menu")
    if option not in props.split("sliders =", 1)[-1].splitlines()[0]:
        errors.append(f"{option} must be adjustable as an Iris slider")
    if f"option.{option} =" not in lang:
        errors.append(f"{option} needs a user-facing label")
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
              "blockEntityId == 5008", "blockEntityId == 5012", "blockEntityId == 5016", "blockEntityId == 5020",
              "blockEntityId == 5028", "blockEntityId == 5032", "blockEntityId == 5036",
              "blockEntityId == 10548", "hasMaterialSpecularMap", "skipGeneratedNormals",
              "materialSmoothness = enderChestFactor * 2.0",
              "if (pbrEmission < 0.01)",
              "if (blockEntityId == 5020)",
              "if (blockEntityId == 10548)",
              "vanillaLight = texture(lightmap, vec2(0.9, vLightmapCoord.y)).rgb",
              "emissionStrength = max(emissionStrength, albedo.r * 16.0)", "emissionStrength = max(emissionStrength, 20.0)",
              "albedo.rgb *= vec3(1.0, 0.25, 0.1)",
              "outEncodedNormal = vec4(surfaceNormal * 0.5 + 0.5, signText ? 0.0 : 0.5 + 0.5 * materialSmoothness)",
              "calculateBlockFog", "outEmissionData"):
    if token not in block_shader:
        errors.append(f"Block-entity shader is missing Iris blockEntityId component: {token}")
if block_shader.index("outLightmapData = vec4(vanillaLight, skyLight)") < block_shader.index("if (blockEntityId == 5020)"):
    errors.append("Block-entity lightmap output must be written after conduit lightmap boost")
if "float goldGreenSquared = albedo.g * albedo.g;" not in block_shader:
    errors.append("Bell gold smoothness must use the block-entity color.g squared reference mapping")
for token in ("materialCoatingFactor = 0.66", "materialCoatingFactor = 0.2",
              "materialCoatingFactor = 0.33", "materialCoatingFactor = 0.77",
              "materialCoatingFactor = 0.5", "!hasMaterialSpecularMap"):
    if token not in block_shader:
        errors.append(f"Block-entity material-specific coating is missing: {token}")
coating_call = block_shader.find("albedo.rgb = applyCoatedTexture")
coating_guard_start = block_shader.rfind("if (", 0, coating_call)
coating_guard = block_shader[coating_guard_start:coating_call] if coating_call >= 0 else ""
if "emissionStrength < 0.01" in coating_guard or "materialSmoothness < 0.85" in coating_guard:
    errors.append("Block-entity fallback coating must remain active for reference emissive ender chests and smooth mapped materials")
if "pbrEmission < 0.01" not in coating_guard:
    errors.append("Explicit PBR-map emission must retain priority over block-entity fallback coating")


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
              "uniform sampler2D noisetex", "textureLod(noisetex, gl_FragCoord.xy / 128.0, 0.0)",
              "WEATHER_TEX_OPACITY", "rainTexOpacity", "snowTexOpacity",
              "suppressLightmap", "PARTICLE_MATERIAL_FEATURES",
              "uniform float rainStrength", "hasSkylight && rainStrength > 0.001"):
    if token not in translucent_particles:
        errors.append(f"Translucent particle shader is missing forward lighting component: {token}")
translucent_particle_vertex = sources.get("gbuffers_particles_translucent.vsh", "")
for token in ("gbufferModelViewInverse", "vPlayerPosition", "vPlayerNormal"):
    if token not in translucent_particle_vertex:
        errors.append(f"Translucent particle vertex stage is missing player-space lighting input: {token}")
textured_lit = sources.get("gbuffers_textured_lit.fsh", "")
for token in ("/* RENDERTARGETS: 0,1,2,3 */", "texture(gtexture", "texture(lightmap",
              "alphaTestRef", "outLightmapData", "outEncodedNormal",
              "outEmissionData = vec4(emissionStrength / 5.0, defaultReflectance, 1.0, 0.0)"):
    if token not in textured_lit:
        errors.append(f"Iris lit-texture fallback is missing G-buffer component: {token}")
for name in ("gbuffers_particles.fsh", "gbuffers_particles_translucent.fsh", "gbuffers_textured_lit.fsh"):
    if "#define PARTICLE_MATERIAL_FEATURES // Detect water, rain, snow, smoke and emissive particle textures" not in sources.get(name, ""):
        errors.append(f"{name} must declare the shared PARTICLE_MATERIAL_FEATURES boolean identically")
if "alphaTest.gbuffers_textured_lit=GREATER 0.01" not in props or "blend.gbuffers_textured_lit=off" not in props:
    errors.append("Iris lit-texture fallback must preserve the 0.01 alpha threshold and disable opaque G-buffer blending")
particles = sources.get("gbuffers_particles.fsh", "")
if "/* RENDERTARGETS: 0,1,2,3 */" not in particles:
    errors.append("Opaque particles must write color, lightmap, normal and emissive G-buffer attachments")
translucent_particles = sources.get("gbuffers_particles_translucent.fsh", "")
if "/* RENDERTARGETS: 0 */" not in translucent_particles:
    errors.append("Translucent particles must use a forward color-only output")
if "texture(lightmap" not in translucent_particles:
    errors.append("Translucent particles must preserve the vanilla lightmap response")
if "if (!gl_FrontFacing) normal = -normal;" not in translucent_particles:
    errors.append("Translucent particles must flip back-face normals before forward lighting")
if "if (!gl_FrontFacing) {" not in water or "normal = -normal;" not in water or "viewNormal = -viewNormal;" not in water:
    errors.append("Translucent terrain must flip both player-space and view-space back-face normals before forward lighting")

deferred = sources.get("deferred.fsh", "")
for token in ("uniform sampler2DShadow shadowtex1", "uniform sampler2D shadowcolor0",
              "float centerShadow0 = texture(shadowtex0", "float centerShadow1 = texture(shadowtex1",
              "vec4 casterColor = texture(shadowcolor0, shadowPosition.xy)",
              "vec3 translucentTransmission = casterColor.rgb * (1.0 - casterColor.a)",
              "mix(opaqueVisibility, translucentVisibility, 1.0 - visibility)",
              "return clamp("):
    if token not in deferred:
        errors.append(f"Deferred translucent shadow transmission is missing component: {token}")

for token in ("/* RENDERTARGETS: 0 */", "sampler2D colortex0",
              "sampler2D colortex1", "sampler2D colortex2", "sampler2D colortex3",
              "texture(colortex3, vTexCoord)", "emissionData.r * 5.0",
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
for token in ("materialSmoothness = clamp((normalData.a - 0.5) * 2.0, 0.0, 1.0)",
              "MATERIAL_SPECULAR_STRENGTH", "float roughness = max(1.0 - materialSmoothness, 0.08)",
              "float distribution = alphaSquared", "float geometryV =", "float geometryL =",
              "vec3 fresnel = specularColor + (1.0 - specularColor) * fresnelFactor",
              "vec3 specularBRDF =", "direct * specularBRDF",
              "specularContribution /= (1.0 + 0.125 * specularContribution)",
              "nDotL > 0.001 && celestialGate > 0.001",
              "normalize(mat3(gbufferModelViewInverse) * normalize(-viewPosition))",
              "halfVectorLengthSquared > 0.000001", "inversesqrt(halfVectorLengthSquared)",
              "vec4 emissionData = texture(colortex3, vTexCoord)",
              "materialReflectance = clamp(emissionData.g, 0.0, 1.0)",
              "MC_TEXTURE_FORMAT_LAB_PBR", "materialReflectance >= (230.0 / 255.0)",
              "float labDielectricF0 = materialReflectance",
              "vec3(labDielectricF0)",
              "mix(vec3(0.04), albedoLinear, materialReflectance)"):
    if token not in deferred:
        errors.append(f"Deferred material specular path is missing component: {token}")

deferred1 = sources.get("deferred1.fsh", "")
deferred1_vertex = sources.get("deferred1.vsh", "")
for token in ("/* RENDERTARGETS: 4 */", "uniform sampler2D colortex0",
              "texelFetch(colortex0", "outOpaqueSceneCopy"):
    if token not in deferred1:
        errors.append(f"Deferred1 water scene-copy pass is missing component: {token}")
if "out vec2 vTexCoord" not in deferred1_vertex or "gl_Position = ftransform()" not in deferred1_vertex:
    errors.append("Deferred1 scene-copy vertex stage is incomplete")
for option in ("WATER_REFRACTION_STRENGTH", "WATER_REFLECTION_STRENGTH"):
    if f"#define {option} " not in water:
        errors.append(f"Water shader is missing the {option} numeric option")

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
if "texelFetch(colortex0" not in composite and "texture(colortex0" not in composite and "texture2D(colortex0" not in composite:
    errors.append("Composite does not preserve the accumulated scene")
for token in ("uniform sampler2D colortex2", "uniform sampler2D colortex3",
              "uniform sampler2D colortex4", "uniform sampler2D depthtex0",
              "uniform sampler2D depthtex2", "uniform mat4 gbufferProjectionInverse",
              "uniform mat4 gbufferModelViewInverse", "PBR_REFLECTION_STRENGTH",
              "PBR_REFLECTION_QUALITY", "sampleOpaqueScreenReflection",
              "sampleOpaqueEnvironmentReflection", "normalData.a <= 0.525",
              "abs(currentDepthAll - depth) > 0.000001",
              "sceneSample.a < 0.5", "textureSize(colortex4, 0)",
              "MC_TEXTURE_FORMAT_LAB_PBR", "materialReflectance >= (230.0 / 255.0)",
              "vec3 fresnelColor = f0Color + (1.0 - f0Color) * fresnelFactor",
              "vec3 reflectionWeight = clamp(",
              "outColor = vec4(pow(max(resultLinear, vec3(0.0)), vec3(1.0 / 2.2)), sceneColor.a)"):
    if token not in composite:
        errors.append(f"Opaque PBR reflection composite is missing: {token}")
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
    "blend.gbuffers_entities_translucent.colortex0=SRC_ALPHA ONE_MINUS_SRC_ALPHA ONE ONE_MINUS_SRC_ALPHA",
    "blend.gbuffers_block_translucent.colortex0=SRC_ALPHA ONE_MINUS_SRC_ALPHA ONE ONE_MINUS_SRC_ALPHA",
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
    for option in ("AO_STRENGTH", "AO_RADIUS", "WATER_REFRACTION_STRENGTH", "WATER_REFLECTION_STRENGTH"):
        if f"option.{option} =" not in lang or f"option.{option}.comment =" not in lang:
            errors.append(f"Missing user-facing label or tooltip for {option}")

brief = ROOT / "PROJECT_BRIEF.md"
if not brief.is_file():
    errors.append("Missing cumulative PROJECT_BRIEF.md")

workflow_text = (ROOT / ".github" / "workflows" / "validate.yml").read_text(encoding="utf-8")
if "Compile opt-in entity POM branches" not in workflow_text or "POM_ENTITY_STRENGTH 20" not in workflow_text:
    errors.append("CI must compile both opt-in entity POM variants")
if "MC_TEXTURE_FORMAT_LAB_PBR 1" not in workflow_text:
    errors.append("CI must compile entity POM with the LabPBR format branch")
if "ENTITY_GN_AND_CT" not in workflow_text:
    errors.append("CI must compile the opt-in entity generated-normal/coating branch")
if "Compile opt-in Unbound water wave detail" not in workflow_text or "WATER_WAVE_DETAIL 1" not in workflow_text:
    errors.append("CI must compile the optional fourth Unbound water-normal octave")
if "Inspect water normal alpha-height channel" not in workflow_text or "alpha.getextrema()" not in workflow_text:
    errors.append("CI must inspect water-normal alpha data before water POM is considered")


for option in ("GENERATED_NORMAL_STRENGTH", "COATED_TEXTURE_STRENGTH"):
    definitions = []
    for name in ("gbuffers_terrain.fsh", "gbuffers_block.fsh", "gbuffers_entities.fsh"):
        definitions.extend(line.strip() for line in sources.get(name, "").splitlines()
                           if line.startswith(f"#define {option} "))
    if len(set(definitions)) != 1:
        errors.append(f"{option} must be defined identically in terrain, block and entity shaders")


if "compile_labpbr_pair hand shaders/gbuffers_hand.vsh shaders/gbuffers_hand.fsh" not in workflow_text:
    errors.append("CI must compile the first-person hand PBR path with LabPBR enabled")
item_properties = (SHADERS / "item.properties").read_text(encoding="utf-8") if (SHADERS / "item.properties").is_file() else ""
for token in ("item.45012=iron_shovel", "item.45016=golden_shovel", "item.45020=diamond_shovel",
              "item.45024=netherite_shovel", "item.44094=glowstone_dust", "item.44096=nether_star"):
    if token not in item_properties:
        errors.append(f"Missing Iris held-item ID mapping: {token}")

# Iris item IDs are unsigned 16-bit values; each exact item/trim identifier
# must map to one numeric ID only.
mapped_items = {}
for line_number, raw_line in enumerate(item_properties.splitlines(), 1):
    mapping = re.match(r"^\s*item\.(\d+)\s*=\s*(.*?)\s*$", raw_line.split("#", 1)[0])
    if not mapping:
        continue
    numeric_id = int(mapping.group(1))
    if not 0 <= numeric_id <= 65535:
        errors.append(f"item.properties line {line_number} uses out-of-range Iris ID {numeric_id}")
    for identifier in mapping.group(2).split():
        normalized = identifier if identifier.startswith("minecraft:") else "minecraft:" + identifier
        previous = mapped_items.get(normalized)
        if previous is not None and previous[0] != numeric_id:
            errors.append(f"Item identifier {normalized} is assigned to IDs {previous[0]} and {numeric_id}")
        else:
            mapped_items[normalized] = (numeric_id, line_number)
hand_shader = sources.get("gbuffers_hand.fsh", "")
for token in ("#define HAND_PBR_STRENGTH 100", "uniform int currentRenderedItemId",
              "uniform sampler2D normals", "uniform sampler2D specular", "uniform vec3 shadowLightPosition",
              "textureGrad(normals", "textureGrad(specular", "MC_TEXTURE_FORMAT_LAB_PBR",
              "currentRenderedItemId == 45012", "currentRenderedItemId == 44094",
              "outColor = albedo"):
    if token not in hand_shader:
        errors.append(f"Hand PBR path is missing component: {token}")
hand_vertex = sources.get("gbuffers_hand.vsh", "")
for token in ("in vec4 at_tangent;", "cross(viewTangent, viewNormal) * tangentHandedness",
              "vViewBitangent = normalize(bitangentCandidate)"):
    if token not in hand_vertex:
        errors.append(f"Hand PBR tangent basis is missing Iris component: {token}")
hand_props = (SHADERS / "shaders.properties").read_text(encoding="utf-8")
hand_lang = (SHADERS / "lang" / "en_us.lang").read_text(encoding="utf-8")
if "HAND_PBR_STRENGTH" not in hand_props.split("sliders =", 1)[-1]:
    errors.append("Held-item PBR strength must be exposed as a slider")
if "option.HAND_PBR_STRENGTH.comment =" not in hand_lang:
    errors.append("Held-item PBR strength requires a user-facing tooltip")
for profile, value in (("Ultra-Light", "0"), ("Smooth", "50"), ("Ultra", "100")):
    line = next((line for line in hand_props.splitlines() if line.startswith(f"profile.{profile} =")), "")
    if f"HAND_PBR_STRENGTH:{value}" not in line:
        errors.append(f"{profile} has incorrect held-item PBR strength")

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
if "separateEntityDraws=true" in props and "iris.features.optional=ENTITY_TRANSLUCENT" in props:
    print("Iris translucent entity routing: separateEntityDraws enabled; ENTITY_TRANSLUCENT support queried as optional feature.")
print("Note: GLSL compilation and in-game Iris compatibility require runtime testing.")
