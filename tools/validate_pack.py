#!/usr/bin/env python3
"""Structural checks for Serene Ultra. This is not a GLSL compiler."""
from pathlib import Path
import math
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SHADERS = ROOT / "shaders"
REQUIRED = (
    "shaders.properties",
    "gbuffers_terrain.vsh", "gbuffers_terrain.fsh",
    "gbuffers_entities.vsh", "gbuffers_entities.fsh",
    "gbuffers_hand.vsh", "gbuffers_hand.fsh",
    "gbuffers_particles.vsh", "gbuffers_particles.fsh",
    "gbuffers_particles_translucent.vsh", "gbuffers_particles_translucent.fsh",
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
    "gbuffers_entities_translucent": "gbuffers_entities",
    "gbuffers_block_translucent": "gbuffers_block",
    "gbuffers_particles": "gbuffers_textured_lit",
    "gbuffers_particles_translucent": "gbuffers_particles",
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
    if "particles.ordering=mixed" not in props:
        errors.append("Deferred packs must explicitly separate opaque and translucent particles with particles.ordering=mixed")
    if "endFlashShadows=true" not in props:
        errors.append("End flash shadows must follow Iris shadowLightPosition in the End")

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
             "gbuffers_particles.fsh", "gbuffers_particles_translucent.fsh"):
    source = sources.get(name, "")
    alpha_test_uses_ref = ("albedo.a < alphaTestRef" in source or "particle.a < alphaTestRef" in source)
    if "uniform float alphaTestRef" not in source or not alpha_test_uses_ref:
        errors.append(f"{name} must use Iris alphaTestRef for alpha discard")
hand_fragment = sources.get("gbuffers_hand.fsh", "")
if "uniform sampler2D lightmap" not in hand_fragment or "texture(lightmap" not in hand_fragment:
    errors.append("Hand shader must preserve the vanilla lightmap response")
entities = sources.get("gbuffers_entities.fsh", "")
if "uniform vec4 entityColor" not in entities or "mix(albedo.rgb, entityColor.rgb, entityColor.a)" not in entities:
    errors.append("Entity shader must apply Iris entityColor tint using its alpha blend factor")

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
for name in ("gbuffers_terrain.fsh", "gbuffers_entities.fsh", "gbuffers_hand.fsh",
             "gbuffers_particles.fsh", "gbuffers_particles_translucent.fsh"):
    source = sources.get(name, "")
    if "uniform sampler2D gtexture" not in source or "texture(gtexture" not in source:
        errors.append(f"{name} must sample the Iris block/entity atlas through gtexture")
if "#define SHADOW_ALPHA_CUTOFF " not in shadow_fragment:
    errors.append("Shadow alpha cutoff must be an active shader option")
if "const int shadowMapResolution" not in shadow_vertex or "const float shadowDistance" not in shadow_vertex:
    errors.append("Shadow pass must declare Iris shadowMapResolution and shadowDistance constants")
if "const float shadowDistanceRenderMul = 1.0;" not in shadow_vertex:
    errors.append("Shadow pass must enable Iris shadow-distance culling")
deferred_options = sources.get("deferred.fsh", "")
ao_strength_line = next((line for line in deferred_options.splitlines() if line.startswith("#define AO_STRENGTH ")), "")
if "0.65" not in ao_strength_line:
    errors.append("AO_STRENGTH option values must include the 0.65 profile preset")

for name in ("gbuffers_terrain.fsh", "gbuffers_entities.fsh", "gbuffers_particles.fsh"):
    source = sources.get(name, "")
    if "/* RENDERTARGETS: 0,1,2 */" not in source:
        errors.append(f"{name} must write albedo, lightmap and normal attachments")
    for output in ("outColor", "outLightmapData", "outEncodedNormal"):
        if output not in source:
            errors.append(f"{name} is missing G-buffer output {output}")
    if "uniform sampler2D lightmap" not in source or "texture(lightmap" not in source:
        errors.append(f"{name} must capture the vanilla colored lightmap")
    alpha_test_uses_ref = ("albedo.a < alphaTestRef" in source or "particle.a < alphaTestRef" in source)
    if "uniform float alphaTestRef" not in source or not alpha_test_uses_ref:
        errors.append(f"{name} must use Iris alphaTestRef instead of a hardcoded alpha cutoff")
    if "vLightmapCoord.y / (30.0 / 32.0) - (1.0 / 32.0)" not in source:
        errors.append(f"{name} must normalize Iris lightmap sky coordinates before storing the direct-light mask")

particles = sources.get("gbuffers_particles.fsh", "")
if "/* RENDERTARGETS: 0,1,2 */" not in particles:
    errors.append("Opaque particles must write color, lightmap and normal G-buffer attachments")
translucent_particles = sources.get("gbuffers_particles_translucent.fsh", "")
if "/* RENDERTARGETS: 0 */" not in translucent_particles:
    errors.append("Translucent particles must use a forward color-only output")
if "texture(lightmap" not in translucent_particles:
    errors.append("Translucent particles must preserve the vanilla lightmap response")

deferred = sources.get("deferred.fsh", "")
for token in ("/* RENDERTARGETS: 0 */", "sampler2D colortex0",
              "sampler2D colortex1", "sampler2D colortex2",
              "sampler2D depthtex0", "sampler2D depthtex2", "sampler2DShadow shadowtex0",
              "gbufferProjectionInverse", "shadowModelView", "shadowProjection",
              "sampleShadow", "vanillaAmbient", "lightData.a",
              "uniform bool hasSkylight", "uniform float endFlashIntensity", "celestialGate",
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
    errors.append("Deferred must write the lit scene to logical colortex0 through Iris buffer flipping")
if "copies colortex3 back to colortex0" in deferred:
    errors.append("Deferred source contains obsolete colortex3 copy-back commentary")
if "colortex3" in deferred:
    errors.append("Deferred still references obsolete colortex3 scene output")
for directive in (
    "flip.deferred.colortex0=true", "flip.composite.colortex0=true",
    "blend.gbuffers_water.colortex0=SRC_ALPHA ONE_MINUS_SRC_ALPHA ONE ONE_MINUS_SRC_ALPHA",
    "blend.gbuffers_weather.colortex0=SRC_ALPHA ONE_MINUS_SRC_ALPHA ONE ONE_MINUS_SRC_ALPHA",
    "blend.gbuffers_hand_water.colortex0=SRC_ALPHA ONE_MINUS_SRC_ALPHA ONE ONE_MINUS_SRC_ALPHA",
    "blend.gbuffers_particles_translucent.colortex0=SRC_ALPHA ONE_MINUS_SRC_ALPHA ONE ONE_MINUS_SRC_ALPHA",
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
