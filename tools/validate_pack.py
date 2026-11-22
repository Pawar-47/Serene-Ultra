#!/usr/bin/env python3
"""Structural checks for Serene Ultra. This is not a GLSL compiler."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SHADERS = ROOT / "shaders"
REQUIRED = (
    "shaders.properties",
    "gbuffers_terrain.vsh", "gbuffers_terrain.fsh",
    "gbuffers_entities.vsh", "gbuffers_entities.fsh",
    "gbuffers_hand.vsh", "gbuffers_hand.fsh",
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

# Keep missing post-deferred geometry paths visible in CI without failing the
# baseline while their dedicated implementations are still pending.
POST_DEFERRED_PROGRAMS = (
    "gbuffers_water", "gbuffers_weather", "gbuffers_hand_water",
)
missing_post_deferred = [
    name for name in POST_DEFERRED_PROGRAMS
    if not (SHADERS / f"{name}.fsh").is_file()
]

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
    if "shadowHardwareFiltering=true" not in props:
        errors.append("Deferred shadow comparison sampling requires shadowHardwareFiltering=true")

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
if "uniform sampler2D texture" not in shadow_fragment or "discard" not in shadow_fragment:
    errors.append("Shadow pass must sample the material texture and discard transparent texels")
if "#define SHADOW_ALPHA_CUTOFF " not in shadow_fragment:
    errors.append("Shadow alpha cutoff must be an active shader option")

for name in ("gbuffers_terrain.fsh", "gbuffers_entities.fsh"):
    source = sources.get(name, "")
    if "/* RENDERTARGETS: 0,1,2 */" not in source:
        errors.append(f"{name} must write albedo, lightmap and normal attachments")
    for output in ("outColor", "outLightmapData", "outEncodedNormal"):
        if output not in source:
            errors.append(f"{name} is missing G-buffer output {output}")
    if "uniform sampler2D lightmap" not in source or "texture2D(lightmap" not in source:
        errors.append(f"{name} must capture the vanilla colored lightmap")

deferred = sources.get("deferred.fsh", "")
for token in ("/* RENDERTARGETS: 3 */", "sampler2D colortex0",
              "sampler2D colortex1", "sampler2D colortex2",
              "sampler2D depthtex0", "sampler2DShadow shadowtex0",
              "gbufferProjectionInverse", "shadowModelView", "shadowProjection",
              "sampleShadow", "vanillaAmbient", "lightData.a",
              "sampleContactAO", "AO_STRENGTH", "AO_RADIUS",
              "sin(sunAngle * 6.28318530718)",
              "smoothstep(0.0, 0.30, solarElevation)"):
    if token not in deferred:
        errors.append(f"Deferred lighting is missing required component: {token}")
if "1.0 - smoothstep(0.45, 0.55, sunAngle)" in deferred:
    errors.append("Deferred day/night curve incorrectly treats Iris sunrise as full daylight")
if "outColor = scene;" not in deferred or "outColor = vec4(litColor, scene.a);" not in deferred:
    errors.append("Deferred pass must preserve uncovered pixels and output shaded pixels")

composite = sources.get("composite.fsh", "")
if "uniform sampler2D colortex3" not in composite:
    errors.append("Composite must read deferred output from colortex3")
if "/* RENDERTARGETS: 0 */" not in composite:
    errors.append("Composite must write the final scene back to colortex0")
if "texture(colortex3" not in composite and "texture2D(colortex3" not in composite:
    errors.append("Composite does not sample the deferred output")

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
if missing_post_deferred:
    print(
        "Iris coverage warning: dedicated post-deferred programs still pending: "
        + ", ".join(missing_post_deferred)
    )
print("Note: GLSL compilation and in-game Iris compatibility require runtime testing.")
